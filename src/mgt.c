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

/*
 * Multi-Gigabit Transceiver control
 */

#include <stdio.h>
#include <xparameters.h>
#include "eyescan.h"
#include "gpio.h"
#include "mgt.h"
#include "util.h"

#define CSR_W_DRP_ENABLE        0x80000000
#define CSR_W_DRP_WRITE         0x40000000
#define CSR_W_SEL_SHIFT         27
#define CSR_W_SEL_MASK          (0x7 << CSR_W_SEL_SHIFT)
#define CSR_W_TX_SOFT_RESET     0x10
#define CSR_W_RX_SOFT_RESET     0x8
#define CSR_W_TX_RESET          0x4
#define CSR_W_RX_RESET          0x2
#define CSR_W_PMA_RESET         0x1

#define CSR_R_DRP_BUSY          0x80000000
#define CSR_R_QPLL1_LOCKED      0x20000000
#define CSR_R_QPLL0_LOCKED      0x10000000
#define CSR_R_QPLL1_REFCLK_LOST 0x8000000
#define CSR_R_QPLL0_REFCLK_LOST 0x4000000
#define CSR_R_TX_RESET_DONE     0x80000
#define CSR_R_RX_RESET_DONE     0x40000
#define CSR_R_RX_FSM_RESET_DONE 0x20000
#define CSR_R_TX_FSM_RESET_DONE 0x10000
#define PLLS_LOCKED   (CSR_R_QPLL1_LOCKED | CSR_R_QPLL0_LOCKED)
#define STATUS_GOOD   (CSR_R_QPLL1_LOCKED      | \
                       CSR_R_QPLL0_LOCKED      | \
                       CSR_R_TX_RESET_DONE     | \
                       CSR_R_RX_RESET_DONE     | \
                       CSR_R_RX_FSM_RESET_DONE | \
                       CSR_R_TX_FSM_RESET_DONE)
#define TX_ONLY_STATUS_GOOD   (CSR_R_QPLL1_LOCKED      | \
                               CSR_R_QPLL0_LOCKED      | \
                               CSR_R_TX_RESET_DONE     | \
                               CSR_R_TX_FSM_RESET_DONE)

#define CSR_W_DRP_ADDR_SHIFT    16
#define CSR_RW_DRP_DATA_MASK    0xFFFF

static void
showStatus(void)
{
    int mgtIndex;
    uint32_t csr;
    for(mgtIndex = 0 ; mgtIndex < CFG_MGT_COUNT ; mgtIndex++) {
        GPIO_WRITE(GPIO_IDX_MGT_CSR, mgtIndex << CSR_W_SEL_SHIFT);
        csr = GPIO_READ(GPIO_IDX_MGT_CSR);
        printf("%d: %04X:%04X\n", mgtIndex, csr >> 16, csr & 0xFFFF);
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, 5 << CSR_W_SEL_SHIFT);
}

void
mgtInit(void)
{
    uint32_t then;
    uint32_t csr;
    int mgtIndex;
    int mgtMap = (1UL << CFG_MGT_COUNT) - 1;

    then = microsecondsSinceBoot();
    for (;;) {
        csr = GPIO_READ(GPIO_IDX_MGT_CSR);
        if ((csr & PLLS_LOCKED) == PLLS_LOCKED) {
            break;
        }
        if ((microsecondsSinceBoot() - then) > 1000000) {
            printf("Warning -- QPLL Unlocked: %08X\n", csr);
            break;
        }
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, /*CSR_W_TX_RESET | CSR_W_RX_RESET | */CSR_W_RX_SOFT_RESET | CSR_W_TX_SOFT_RESET);
    microsecondSpin(1);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, 0);
    mgtIndex = 0;
    while (mgtMap) {
        int mgtBit = 1UL << mgtIndex;
        if (mgtMap & mgtBit) {
            uint32_t good = (mgtIndex < CFG_MGT_RX_COUNT) ? STATUS_GOOD 
                                                          : TX_ONLY_STATUS_GOOD;
            then = microsecondsSinceBoot();
            for (;;) {
                csr = GPIO_READ(GPIO_IDX_MGT_CSR);
                if ((csr & good) == good) {
                    if (debugFlags & DEBUGFLAG_MGT) {
                        printf("MGT %d reset.\n", mgtIndex);
                    }
                    mgtMap &= ~mgtBit;
                    break;
                }
                if ((microsecondsSinceBoot() - then) > 200000) {
                    printf("Warning -- Reset Incomplete(%d:%X):%X\n", mgtIndex,
                                                                   mgtMap, csr);
                    mgtMap &= ~mgtBit;
                    break;
                }
            }
        }
        mgtIndex++;
    }
    showStatus();
    eyescanInit();

    /*
     * Must reset PMA after enabling eye scan hardware
     */
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_PMA_RESET);
    microsecondSpin(2);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, 0);
    microsecondSpin(100);
}

/*
 * Only way to align receiver is to keep resetting it until
 * it comes up at the right framing.
 */
void
mgtCrank(void)
{
    uint32_t csr = GPIO_READ(GPIO_IDX_LINK_STATUS);
    static int aligning;
    static int wasUp;
    static uint32_t whenReset;
    if (csr & 0x1) {
        aligning = 0;
        if (!wasUp) {
            printf("MGT EVR link up.\n");
            wasUp = 1;
        }
    }
    else {
        wasUp = 0;
        if (!aligning || ((microsecondsSinceBoot() - whenReset) > 10000)) {
            GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RX_RESET);
            microsecondSpin(1);
            GPIO_WRITE(GPIO_IDX_MGT_CSR, 0);
            whenReset = microsecondsSinceBoot();
            aligning = 1;
        }
    }
}

uint32_t *
mgtFetchSysmon(uint32_t *buf)
{
    *buf++ = GPIO_READ(GPIO_IDX_LINK_STATUS);
    return buf;
}

void
mgtDRPwrite(int mgtIndex, int drpAddress, int value)
{
    if ((mgtIndex < 0) || (mgtIndex >= CFG_MGT_COUNT)) {
        return;
    }
    if (debugFlags & DEBUGFLAG_MGT) {
        printf("MGT %d %03X <- %04X\n", mgtIndex, drpAddress, value);
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_DRP_ENABLE | CSR_W_DRP_WRITE |
                                        (mgtIndex << CSR_W_SEL_SHIFT) |
                                        (drpAddress << CSR_W_DRP_ADDR_SHIFT) |
                                        (value & CSR_RW_DRP_DATA_MASK));
    while (GPIO_READ(GPIO_IDX_MGT_CSR) & CSR_R_DRP_BUSY) continue;
}

int
mgtDRPread(int mgtIndex, int drpAddress)
{
    uint32_t csr;
    if ((mgtIndex < 0) || (mgtIndex >= CFG_MGT_COUNT)) {
        return -1;
    }
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_DRP_ENABLE |
                                        (mgtIndex << CSR_W_SEL_SHIFT) |
                                        (drpAddress << CSR_W_DRP_ADDR_SHIFT));
    while ((csr = GPIO_READ(GPIO_IDX_MGT_CSR)) & CSR_R_DRP_BUSY) continue;
    if (debugFlags & DEBUGFLAG_MGT) {
        printf("MGT %d %03X -> %04X\n", mgtIndex, drpAddress,
                                                    csr & CSR_RW_DRP_DATA_MASK);
    }
    return csr & CSR_RW_DRP_DATA_MASK;
}
