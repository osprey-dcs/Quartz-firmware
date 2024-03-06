/*
 * MIT License
 *
 * Copyright (c) 2023 Osprey DCS
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
#define BYTECOUNT_W_SET_BYTECOUNT       0x10000

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
    acqSetActiveChannels();
}

int
acqSetActive(int channel, int active)
{
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
    }
    if (active) {
        activeChannels |= (1UL << channel);
    }
    else {
        activeChannels &= ~(1UL << channel);
    }
    acqSetActiveChannels();
    return 0;
}

int
acqSetCoupling(int channel, int dcCoupled)
{
    uint32_t csr, b;
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
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
    return 0;
}

void
acqSubscriptionChange(int subscriberPresent)
{
    GPIO_WRITE(GPIO_IDX_BUILD_PACKET_BYTECOUNT, subscriberPresent ?
                                                BYTECOUNT_W_SUBSCRIBER_PRESENT :
                                                BYTECOUNT_W_SUBSCRIBER_ABSENT);
}

uint32_t *
acqFetchSysmon(uint32_t *buf)
{
    *buf++ = GPIO_READ(GPIO_IDX_BUILD_PACKET_STATUS);
    *buf++ = GPIO_READ(GPIO_IDX_BUILD_PACKET_BITMAP);
    *buf++ = GPIO_READ(GPIO_IDX_INPUT_COUPLING_CSR);
    return buf;
}
