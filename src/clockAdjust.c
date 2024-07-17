/*
 * MIT License
 *
 * Copyright (c) 2022 Osprey DCS
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <stdio.h>
#include "clockAdjust.h"
#include "evg.h"
#include "gpio.h"
#include "systemParameters.h"
#include "util.h"

/*
 * Low pass filter time constant(seconds): (1 << FILTER_SHIFT) 
 */
#define FILTER_SHIFT 5

#define CSR_W_ENABLE            0x80000000
#define CSR_W_DISABLE           0x40000000
#define CSR_W_SET_DAC           0x20000000
#define CSR_W_ENABLE_JITTER     0x10000000
#define CSR_W_DISABLE_JITTER    0x08000000
#define CSR_W_DAC_MASK          0xFFFF
#define CSR_R_LOCKED            0x80000000
#define CSR_R_PPS_TOGGLE        0x40000000
#define CSR_R_PPS_ENABLED       0x20000000
#define CSR_R_JITTER_ENABLED    0x10000000
#define CSR_R_JITTER_ISLOW      0x8000000
#define CSR_R_PHASE_ERROR_MASK  0xFFFFFF
#define CSR_R_PHASE_ERROR_SIGN  0x800000

#define AUX_R_STATE_MASK        0x70000
#define AUX_R_STATE_SHIFT       16
#define AUX_R_DAC_MASK          0xFFFF

#define HW_INTERVAL_R_PPS_VALID         0x80000000
#define HW_INTERVAL_R_PPS_TOGGLE        0x40000000
#define HW_INTERVAL_R_SECONDARY_VALID   0x20000000
#define HW_INTERVAL_R_PRIMARY_VALID     0x10000000
#define HW_INTERVAL_STATUS_MASK         0xF0000000
#define HW_INTERVAL_IS_EVG              0x08000000
#define HW_JITTER_R_JITTER_MASK         0x000FFFFF

void
clockAdjustInit(void)
{
    GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_SET_DAC | 0);
    microsecondSpin(100);
    GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_ENABLE);
}

uint32_t
clockAdjustFetchSysmon(int index)
{
    switch (index) {
    case 0: return fetchRegister(GPIO_IDX_ACQCLK_PLL_CSR);
    case 1: return (fetchRegister(GPIO_IDX_ACQCLK_HW_INTERVAL) &
                                                        HW_INTERVAL_STATUS_MASK)
               | (isEVG() ? HW_INTERVAL_IS_EVG : 0)
               | (((fetchRegister(GPIO_IDX_ACQCLK_HW_JITTER) * 5) / 8)
                                                     & HW_JITTER_R_JITTER_MASK);
    case 2: return fetchRegister(GPIO_IDX_PPS_LATENCY);
    }
    return 0;
}

int
clockAdjustIsLocked(void)
{
    return ((GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR) & CSR_R_LOCKED) != 0);
}

static void
clockAdjustReport(uint32_t csr)
{
    uint32_t aux = fetchRegister(GPIO_IDX_ACQCLK_PLL_AUX_STATUS);
    uint32_t hwPPS = fetchRegister(GPIO_IDX_ACQCLK_HW_INTERVAL);
    uint32_t ppsJitter_ns = fetchRegister(GPIO_IDX_ACQCLK_HW_JITTER) * 5 / 8;
    printf("PLL ");
    if (csr & CSR_R_PPS_ENABLED) {
        int phaseError;
        phaseError = csr & CSR_R_PHASE_ERROR_MASK;
        if (phaseError & CSR_R_PHASE_ERROR_SIGN) {
            phaseError -= CSR_R_PHASE_ERROR_SIGN << 1;
        }
        printf("%slocked. State:%X Phase diff:%d",
                                  (csr & CSR_R_LOCKED) ? "" : "un",
                                  (aux & AUX_R_STATE_MASK) >> AUX_R_STATE_SHIFT,
                                  phaseError);
    }
    else {
        printf("disabled.");
    }
    printf(" DAC:%d PPS ", (int16_t)(aux & AUX_R_DAC_MASK));
    if (hwPPS & HW_INTERVAL_R_PPS_VALID) {
        printf("Jitter:%dns HW:%d", ppsJitter_ns,
                                              hwPPS & ~HW_INTERVAL_STATUS_MASK);
    }
    else {
        print("Invalid");
    }
    printf("\n");
}

void
clockAdjustCrank(void)
{
    uint32_t csr = GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR);
    static uint32_t ocsr, firstTime = 1;
    if (firstTime) {
        firstTime = 0;
    }
    else if (((csr ^ ocsr) & CSR_R_PPS_TOGGLE) != 0) {
        if (debugFlags & DEBUGFLAG_ENABLE_PPS_JITTER) {
            if (!(csr & CSR_R_JITTER_ENABLED)) {
                GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_ENABLE_JITTER);
            }
        }
        else {
            if (csr & CSR_R_JITTER_ENABLED) {
                GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_DISABLE_JITTER);
            }
        }
        if (debugFlags & DEBUGFLAG_CLOCKADJUST_SHOW)  {
            microsecondSpin(10);
            clockAdjustReport(csr);
        }
    }
    ocsr = csr;
}

void
clockAdjustSet(int dacValue)
{
    if (dacValue == 0) {
        GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_ENABLE);
    }
    else {
        uint32_t csr = GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR);
        if (csr & CSR_R_PPS_ENABLED) {
            GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_DISABLE);
            microsecondSpin(30);
        }
        GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_SET_DAC |
                                                   (dacValue & CSR_W_DAC_MASK));
    }
}

static void
ppsPresenceReport(const char *type, int present, const char *end)
{
    printf("%s PPS %ssent.%s", type, present ? "pre" : "ab", end);
}

void
clockAdjustShow(void)
{
    uint32_t hwPPS = fetchRegister(GPIO_IDX_ACQCLK_HW_INTERVAL);
    ppsPresenceReport("Primary", hwPPS & HW_INTERVAL_R_PRIMARY_VALID, "  ");
    ppsPresenceReport("Secondary", hwPPS & HW_INTERVAL_R_SECONDARY_VALID, "\n");
    clockAdjustReport(fetchRegister(GPIO_IDX_ACQCLK_PLL_CSR));
}
