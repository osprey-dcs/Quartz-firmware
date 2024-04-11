/*
 * MIT License
 *
 * Copyright (c) 2024 Osprey DCS
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

/*
 * Fast data acquisition
 */
#include <stdio.h>
#include <stdlib.h>
#include <xparameters.h>
#include "acq.h"
#include "ad7768.h"
#include "clockAdjust.h"
#include "gpio.h"
#include "inputCoupling.h"
#include "util.h"

#define BYTES_PER_ADC (((CFG_AD7768_WIDTH) + 7) / 8)

#define CSR_R_ACQ_ENABLED           0x80000000
#define CSR_R_ACQ_ACTIVE            0x40000000
#define CSR_R_SUBSCRIBER_PRESENT    0x40000000
#define CSR_R_SEND_OVERRUN          0x8000
#define CSR_R_ADC_OVERRUN           0x4000
#define CSR_R_ACQCLK_UNLOCKED       0x1

#define BYTECOUNT_W_SUBSCRIBER_PRESENT  0x80000000
#define BYTECOUNT_W_SUBSCRIBER_ABSENT   0x40000000
#define BYTECOUNT_W_CALIBRATION_VALID   0x2000000
#define BYTECOUNT_W_CALIBRATION_INVALID 0x1000000
#define BYTECOUNT_W_SET_BYTECOUNT       0x10000

#define THRESHOLD_CSR_SELECT_LOLO   0x00000000
#define THRESHOLD_CSR_SELECT_LO     0x40000000
#define THRESHOLD_CSR_SELECT_HI     0x80000000
#define THRESHOLD_CSR_SELECT_HIHI   0xC0000000
#define THRESHOLD_CSR_VALUE_MASK    0xFFFFFF

#if ((CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP) > 32)
# error "Code needs some rework to handle that many ADC channels"
#endif

struct pkHeader {
    uint32_t    magic;
    uint32_t    bodyLength;
    uint32_t    status;
    uint32_t    active;
    uint32_t    seqHi;
    uint32_t    seqLo;
    uint32_t    seconds;
    uint32_t    ticks;
    uint32_t    limitExcursions[4];
};

static uint32_t activeChannels = 0xFF;

static void
acqSetActiveChannels(void)
{
    int samplesPerPacket, byteCount;
    uint32_t active = activeChannels, countActive;
    int adcsPerSample = 0;
    /*
     * Always provide at least *some* data in the fast stream.
     */
    if (active == 0) active = 1;

    /*
     * Kernighan's method to count number of active channels
     */
    countActive = active;
    while (countActive) {
        countActive &= (countActive - 1);
        adcsPerSample++;
    }
    samplesPerPacket = (CFG_UDP_PACKET_CAPACITY - sizeof(struct pkHeader))
                                              / (adcsPerSample * BYTES_PER_ADC);
    byteCount = samplesPerPacket * adcsPerSample * BYTES_PER_ADC;
    if (debugFlags & DEBUGFLAG_ACQ) {
        printf("adcsPerSample:%d samplesPerPacket:%d byteCount:%d\n",
                                    adcsPerSample, samplesPerPacket, byteCount);
    }
    GPIO_WRITE(GPIO_IDX_BUILD_PACKET_BITMAP, active);
    GPIO_WRITE(GPIO_IDX_BUILD_PACKET_BYTECOUNT, BYTECOUNT_W_SET_BYTECOUNT |
                                                                     byteCount);
}

void
acqInit(void)
{
    int i;
    int hihi = (1 << (CFG_AD7768_WIDTH - 1)) - 1;
    int hi = (((1 << 23) - 1) * 9) / 10;
    for (i = 0 ; (i < CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP) ; i++) {
        acqSetLOLOthreshold(i, -hihi);
        acqSetLOthreshold  (i, -hi);
        acqSetHIthreshold  (i, hi);
        acqSetHIHIthreshold(i, hihi);
    }
    acqSetActiveChannels();
}

void
acqSetActive(int channel, int active)
{
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return;
    }
    if (active) {
        activeChannels |= (1UL << channel);
    }
    else {
        activeChannels &= ~(1UL << channel);
    }
    acqSetActiveChannels();
}

int
acqGetActive(int channel)
{
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
    }
    return ((activeChannels & (1UL << channel)) != 0);
}

void
acqSetCoupling(int channel, int dcCoupled)
{
    uint32_t csr, b;
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return;
    }
    b = 1UL << channel;
    csr = GPIO_READ(GPIO_IDX_INPUT_COUPLING_CSR);
    if (dcCoupled) {
        csr |= b;
    }
    else {
        csr &= ~b;
    }
    GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_CSR, csr);
    inputCouplingSet(channel, dcCoupled);
}

int
acqGetCoupling(int channel)
{
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
    }
    return ((GPIO_READ(GPIO_IDX_INPUT_COUPLING_CSR) & (1UL << channel)) != 0);
}

void
acqSubscriptionChange(int subscriberPresent)
{
    GPIO_WRITE(GPIO_IDX_BUILD_PACKET_BYTECOUNT, subscriberPresent ?
                                                BYTECOUNT_W_SUBSCRIBER_PRESENT :
                                                BYTECOUNT_W_SUBSCRIBER_ABSENT);
}

void
acqSetCalibrationValidity(int isCalibrated)
{
    GPIO_WRITE(GPIO_IDX_BUILD_PACKET_BYTECOUNT, isCalibrated ?
                                               BYTECOUNT_W_CALIBRATION_VALID :
                                               BYTECOUNT_W_CALIBRATION_INVALID);
}

uint32_t
acqFetchSysmon(int offset)
{
    switch (offset) {
    case 0: return GPIO_READ(GPIO_IDX_BUILD_PACKET_STATUS);
    case 1: return GPIO_READ(GPIO_IDX_BUILD_PACKET_BITMAP);
    case 2: return GPIO_READ(GPIO_IDX_INPUT_COUPLING_CSR);
    default: return 0;
    }
}

static void
setThreshold(uint32_t select, int channel, int threshold)
{
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return;
    }
    GPIO_WRITE(GPIO_IDX_ADC_THRESHOLDS, select | (channel << 24) |
                                        (threshold & THRESHOLD_CSR_VALUE_MASK));
}

void
acqSetLOLOthreshold(int channel, int threshold)
{
    setThreshold(THRESHOLD_CSR_SELECT_LOLO, channel, threshold);
}

void
acqSetLOthreshold(int channel, int threshold)
{
    setThreshold(THRESHOLD_CSR_SELECT_LO, channel, threshold);
}

void
acqSetHIthreshold(int channel, int threshold)
{
    setThreshold(THRESHOLD_CSR_SELECT_HI, channel, threshold);
}

void
acqSetHIHIthreshold(int channel, int threshold)
{
    setThreshold(THRESHOLD_CSR_SELECT_HIHI, channel, threshold);
}

uint32_t
acqGetLimitExcursions(int type)
{
    GPIO_WRITE(GPIO_IDX_ADC_EXCURSIONS, type);
    microsecondSpin(1);
    return GPIO_READ(GPIO_IDX_ADC_EXCURSIONS);
}
