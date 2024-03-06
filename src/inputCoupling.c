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
 * AC/DC coupling
 * NOT thread-safe
 */
#include <stdio.h>
#include <stdlib.h>
#include <xparameters.h>
#include "inputCoupling.h"
#include "gpio.h"
#include "util.h"

#define APPLY_MICROSECONDS  20000
#define PAUSE_MICROSECONDS  10000
#define MAX_SIMULTANEOUS    4

#define CSR_R_BUSY      0x1
#define CSR_R_FAULT     0x2

#define CHANNEL_COUNT ((CFG_AD7768_CHIP_COUNT) * (CFG_AD7768_ADC_PER_CHIP))
#define CMDTABLE_SIZE CHANNEL_COUNT

#define CMD_DC           0x80
#define CMD_CHANNEL_MASK 0x7F

static unsigned char cmdTable[CMDTABLE_SIZE];
static int head = 0, tail = 0;

static void
apply(int i, int set)
{
    uint32_t b = (1UL << i);
    uint32_t then;
    if (set) {
        GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_CLR, 0);
        GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_SET_START, b);
    }
    else {
        GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_CLR, b);
        GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_SET_START, 0);
    }
    then = microsecondsSinceBoot();
    while ((microsecondsSinceBoot() - then) < APPLY_MICROSECONDS) continue;
    if (GPIO_READ(GPIO_IDX_INPUT_COUPLING_SET_START) & CSR_R_FAULT) {
        printf("Warning -- Relay %d %s failed!\n", i, set ? "SET" : "RESET");
    }
    GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_CLR, 0);
    GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_SET_START, 0);
    then = microsecondsSinceBoot();
    while ((microsecondsSinceBoot() - then) < PAUSE_MICROSECONDS) continue;
}

void
inputCouplingInit(void)
{
    int i;
    /*
     * Exercise all relays to try to prevent contact sticking
     */
    if (debugFlags & DEBUGFLAG_NO_RELAY_EXERCISE) return;
    for (i = 0 ; i < CHANNEL_COUNT ; i++) {
        apply(i, 1);
        apply(i, 0);
    }
}

void
inputCouplingSet(int channel, int dcCoupled)
{
    int newHead = (head == (CMDTABLE_SIZE - 1)) ? 0 : head + 1;
    int cmd;
    while (newHead == tail) {
        inputCouplingCrank();
    }
    cmd = channel;
    if (dcCoupled) cmd |= CMD_DC;
    cmdTable[head] = cmd;
    head = newHead;
}

void
inputCouplingCrank(void)
{
    static enum state {ST_IDLE, ST_APPLY, ST_PAUSE} state = ST_IDLE;
    static uint32_t then;

    switch (state) {
    case ST_IDLE:
        if (tail != head) {
            int cmdCount = 0;
            uint32_t setBits = 0, clrBits = 0;
            while ((tail != head) && (cmdCount < MAX_SIMULTANEOUS)) {
                int cmd = cmdTable[tail];
                int set = cmd & CMD_DC;
                int channel = cmd & CMD_CHANNEL_MASK;
                uint32_t bit = 1UL << channel;
                if (set) {
                    setBits |= bit;
                    clrBits &= ~bit;
                }
                else {
                    setBits &= ~bit;
                    clrBits |= bit;
                }
                tail = (tail == (CMDTABLE_SIZE - 1)) ? 0 : tail + 1;
                cmdCount++;
            }
            if (debugFlags & DEBUGFLAG_INPUT_COUPLING) {
                printf("Coupling");
                if (clrBits) printf(" CLR:%08X", clrBits);
                if (setBits) printf(" SET:%08X", setBits);
                printf("\n");
            }
            GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_CLR, clrBits);
            GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_SET_START, setBits);
            then = microsecondsSinceBoot();
            state = ST_APPLY;
        }
        break;
    
    case ST_APPLY:
        if ((microsecondsSinceBoot() - then) >= APPLY_MICROSECONDS) {
            GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_CLR, 0);
            GPIO_WRITE(GPIO_IDX_INPUT_COUPLING_SET_START, 0);
            then = microsecondsSinceBoot();
            state = ST_PAUSE;
        }
        break;

    case ST_PAUSE:
        if ((microsecondsSinceBoot() - then) >= PAUSE_MICROSECONDS) {
            state = ST_IDLE;
        }
        break;
    }
}
