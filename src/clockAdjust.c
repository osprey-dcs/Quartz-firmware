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
#include "util.h"

#define CSR_W_ENABLE            0x80000000
#define CSR_W_SET_DAC           0x40000000
#define CSR_W_DAC_MASK          0xFFFF
#define CSR_R_LOCKED            0x80000000
#define CSR_R_PPS_TOGGLE        0x40000000
#define CSR_R_PPS_ENABLED       0x20000000
#define CSR_R_PHASE_ERROR_MASK  0xFFFFFFF
#define CSR_R_PHASE_ERROR_SIGN  0x8000000

#define AUX_R_STATE_MASK        0xF0000
#define AUX_R_STATE_SHIFT       16
#define AUX_R_DAC_MASK          0xFFFF

void
clockAdjustInit(void)
{
    GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_SET_DAC | 0);
    microsecondSpin(10);
    GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_ENABLE);
    if (debugFlags & DEBUGFLAG_CLOCKADJUST_STEP) {
        clockAdjustShow(30);
        debugFlags &= ~DEBUGFLAG_CLOCKADJUST_STEP;
    }
}

uint32_t *
clockAdjustFetchSysmon(uint32_t *buf)
{
    *buf++ = GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR);
    return buf;
}

int
clockAdjustIsLocked(void)
{
    return ((GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR) & CSR_R_LOCKED) != 0);
}
    
void
clockAdjustShow(int count)
{
    uint32_t csr, ocsr, aux;
    if (count <= 0) count = 1;
    if (count > 30) count = 30;
    csr = GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR);
    for (;;) {
        uint32_t then = microsecondsSinceBoot();
        int phaseError;
        aux = GPIO_READ(GPIO_IDX_ACQCLK_PLL_AUX_STATUS);
        phaseError = csr & CSR_R_PHASE_ERROR_MASK;
        if (phaseError & CSR_R_PHASE_ERROR_SIGN) {
            phaseError -= CSR_R_PHASE_ERROR_SIGN << 1;
        }
        printf("Clock adjustment %sabled  State:%X  DAC:%d  Phase error:%d",
                                  csr & CSR_R_PPS_ENABLED ? "en" : "dis",
                                  (aux & AUX_R_STATE_MASK) >> AUX_R_STATE_SHIFT,
                                  (int16_t)(aux & AUX_R_DAC_MASK),
                                  phaseError);
        if (!(csr & CSR_R_LOCKED)){
            printf(" -- UNLOCKED!");
        }
        printf("\n");
        if (--count <= 0) break;
        ocsr = csr;
        while ((((csr = GPIO_READ(GPIO_IDX_ACQCLK_PLL_CSR)) ^ ocsr) &
                                                       CSR_R_PPS_TOGGLE) == 0) {
            if ((microsecondsSinceBoot() - then) > 1200000) {
                break;
            }
        }
    }
    evgShow();
}

void
clockAdjustStep(void)
{
    static const int16_t dac[] = {-24576, -5000, 0, 5000, 24576, 0};
    static int idx;
    switch (idx) {
    case 0:
        /*
         * Put VCXO into open-loop control
         */
        GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, 0);
        while((GPIO_READ(GPIO_IDX_ACQCLK_PLL_AUX_STATUS)&AUX_R_STATE_MASK)!=0) {
            continue;
        }
        /* Fall through to default case */
    default:
        GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_SET_DAC |
                                                   (dac[idx] & CSR_W_DAC_MASK));
        idx++;
        break;

    case sizeof dac / sizeof dac[0]:
        idx = 0;
        GPIO_WRITE(GPIO_IDX_ACQCLK_PLL_CSR, CSR_W_ENABLE);
        break;
    }
    microsecondSpin(2);
    clockAdjustShow(0);
}
