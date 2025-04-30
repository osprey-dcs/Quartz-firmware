/*
 * MIT License
 *
 * Copyright (c) 2025 Osprey DCS
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
 * Basic MRF-compatible event generator
 * Assume only one per processor
 */
#include <stdio.h>
#include <xil_io.h>
#include <xparameters.h>
#include "ospreyEVG.h"

#define REG_OFFSET_CSR                (0*4)
#define REG_OFFSET_CLK_RATE           (1*4)
#define REG_OFFSET_SECONDS            (2*4)
#define REG_OFFSET_HEARTBEAT_DIVISOR  (3*4)
#define REG_OFFSET_HW_TRIGGER_CONFIG  (4*4)
#define REG_OFFSET_SW_TRIGGER         (5*4)
#define REG_OFFSET_SEQUENCER          (6*4)
#define REG_OFFSET_TIMER_CONFIG_BASE  (16*4)

#define CLK_RATE_PPS_TOGGLE 0x80000000
#define CLK_RATE_RATE_MASK  0x7FFFFFFF

#define SEQ_OP_CONTROL        (0x0U<<30)
#define SEQ_OP_LATCH_DELAY    (0x1U<<30)
#define SEQ_OP_WRITE_RAM      (0x2U<<30)
#define SEQ_VALUE_MASK        0xFFFFFFF
#define SEQ_CONTROL_ARM       0x1
#define SEQ_CONTROL_CANCEL    0x2
#define SEQ_CONTROL_TRIGGER   0x4

struct evgInfo {
    uint32_t baseAddr;
    short    timerCount;
    short    hwTriggerCount;
};
static struct evgInfo evgInfo;

int
ospreyEVGInit(uint32_t baseAddress)
{
    uint32_t csr;
    if (!baseAddress) return -1;
    evgInfo.baseAddr = baseAddress;
    csr = ospreyEVGStatus();
    evgInfo.timerCount = (csr & OSPREY_EVG_TIMER_COUNT_MASK) >>
                                                   OSPREY_EVG_TIMER_COUNT_SHIFT;
    evgInfo.hwTriggerCount = (csr & OSPREY_EVG_HW_TRIG_COUNT_MASK) >>
                                                 OSPREY_EVG_HW_TRIG_COUNT_SHIFT;
    return 0;
}

int
ospreyEVGStatus(void)
{
    if (!evgInfo.baseAddr) return -1;
    return Xil_In32(evgInfo.baseAddr + REG_OFFSET_CSR);
}

int
ospreyEVGGetPPStoggle(void)
{
    if (!evgInfo.baseAddr) return -1;
    return ((Xil_In32(evgInfo.baseAddr + REG_OFFSET_CLK_RATE) &
                                                    CLK_RATE_PPS_TOGGLE) != 0);
}

int
ospreyEVGSetSeconds(uint32_t posixSeconds)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SECONDS, posixSeconds);
    return 0;
}

int
ospreyEVGSetHeartbeatDivisor(uint32_t divisor)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_HEARTBEAT_DIVISOR, divisor);
    return 0;
}

int
ospreyEVGSetTimerEvent(int index, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((evCode <= 0) || (evCode > 255)) return -2;
    if ((index < 0) || (index >= evgInfo.timerCount)) return -3;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_TIMER_CONFIG_BASE + (index<<3) + 0,
                                                                        evCode);
    return 0;
}

int
ospreyEVGSetTimerDivisor(int index, uint32_t divisor)
{
    if (!evgInfo.baseAddr) return -1;
    if ((index < 0) || (index >= evgInfo.timerCount)) return -3;
    if (divisor <= 1) divisor = ~0UL;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_TIMER_CONFIG_BASE + (index<<3) + 4,
                                                                   divisor - 2);
    return 0;
}

int
ospreyEVGSetHwTriggerEvent(int index, int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((evCode <= 0) || (evCode > 255)) return -2;
    if ((index < 0) || (index >= (evgInfo.hwTriggerCount * 2))) return -3;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_HW_TRIGGER_CONFIG, (index << 8) |
                                                                       evCode);
    return 0;
}

int
ospreyEVGSendSoftwareEvent(int evCode)
{
    if (!evgInfo.baseAddr) return -1;
    if ((evCode <= 0) || (evCode > 255)) return -2;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SW_TRIGGER, evCode);
    return 0;
}

int
ospreyEVGSequencerArm(void)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SEQUENCER, SEQ_OP_CONTROL |
                                                       SEQ_CONTROL_ARM);
    return 0;
}

int
ospreyEVGSequencerCancel(void)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SEQUENCER, SEQ_OP_CONTROL |
                                                       SEQ_CONTROL_CANCEL);
    return 0;
}

int
ospreyEVGSequencerTrigger(void)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SEQUENCER, SEQ_OP_CONTROL |
                                                       SEQ_CONTROL_TRIGGER);
    return 0;
}

int
ospreyEVGSequencerLatchDelay(int delay)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SEQUENCER, SEQ_OP_LATCH_DELAY |
                                                      (delay & SEQ_VALUE_MASK));
    return 0;
}

int
ospreyEVGSequencerWrite(int address_event)
{
    if (!evgInfo.baseAddr) return -1;
    Xil_Out32(evgInfo.baseAddr + REG_OFFSET_SEQUENCER, SEQ_OP_WRITE_RAM |
                                              (address_event & SEQ_VALUE_MASK));
    return 0;
}
