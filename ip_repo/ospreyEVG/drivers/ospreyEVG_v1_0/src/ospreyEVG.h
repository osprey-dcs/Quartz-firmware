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

#ifndef _OSPREYEVG_H_
#define _OSPREYEVG_H_

/*
 * Basic MRF-compatible event generator
 */

#include <stdint.h>

#define OSPREY_EVG_STATUS_PPS_TOGGLE        0x100000
#define OSPREY_EVG_STATUS_SEQUENCER_ACTIVE  0x20000
#define OSPREY_EVG_STATUS_SEQUENCER_ARMED   0x10000
#define OSPREY_EVG_TIMER_COUNT_MASK         0xF000
#define OSPREY_EVG_TIMER_COUNT_SHIFT        12
#define OSPREY_EVG_HW_TRIG_COUNT_MASK       0xF00
#define OSPREY_EVG_HW_TRIG_COUNT_SHIFT      8
#define OSPREY_EVG_STATUS_TIME_VALID        0x02
#define OSPREY_EVG_STATUS_PPS_VALID         0x01

int ospreyEVGInit(uint32_t baseAddress);
int ospreyEVGStatus(void);
int ospreyEVGGetPPStoggle(void);
int ospreyEVGSetSeconds(uint32_t posixSeconds);
int ospreyEVGSetHeartbeatDivisor(uint32_t divisor);
int ospreyEVGSetTimerEvent(int index, int evCode);
int ospreyEVGSetTimerDivisor(int index, uint32_t divisor);
int ospreyEVGSetHwTriggerEvent(int index, int evCode);
int ospreyEVGSendSoftwareEvent(int evCode);
int ospreyEVGSequencerArm(void);
int ospreyEVGSequencerCancel(void);
int ospreyEVGSequencerTrigger(void);
int ospreyEVGSequencerLatchDelay(int delay);
int ospreyEVGSequencerWrite(int address_event);

#endif /* _OSPREYEVG_H_ */
