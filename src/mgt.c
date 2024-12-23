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
#define CSR_W_DRP_ADDR_SHIFT    16
#define CSR_RW_DRP_DATA_MASK    0xFFFF
#define CSR_W_SEL_MASK          (0x7 << CSR_W_SEL_SHIFT)
#define CSR_W_POWERDOWN_ENABLE  0x400000
#define CSR_W_RXSLIDE_ENABLE    0x200000
#define CSR_W_RESET_ENABLE      0x100000
#define CSR_W_TX_SOFT_RESET     0x80000
#define CSR_W_RX_SOFT_RESET     0x40000
#define CSR_W_TX_RESET          0x20000

#define CSR_R_DRP_BUSY          0x80000000
#define CSR_R_QPLL1_LOCKED      0x8000000
#define CSR_R_QPLL1_REFCLK_LOST 0x4000000
#define CSR_R_QPLL0_LOCKED      0x2000000
#define CSR_R_QPLL0_REFCLK_LOST 0x1000000
#define CSR_R_TX_RESET_DONE     0x80000
#define CSR_R_RX_RESET_DONE     0x40000
#define CSR_R_RX_FSM_RESET_DONE 0x20000
#define CSR_R_TX_FSM_RESET_DONE 0x10000

#define PLLS_LOCKED (CSR_R_QPLL1_LOCKED | CSR_R_QPLL0_LOCKED)

/*
 * For now, start by assuming that all lanes are active
 */
static uint32_t activeLanes = ((1UL << CFG_MGT_COUNT) - 1);

void
mgtShowStatus(void)
{
    int mgtIndex;
    uint32_t csr;
    for(mgtIndex = 0 ; mgtIndex < CFG_MGT_COUNT ; mgtIndex++) {
        GPIO_WRITE(GPIO_IDX_MGT_CSR, mgtIndex << CSR_W_SEL_SHIFT);
        csr = GPIO_READ(GPIO_IDX_MGT_CSR);
        printf("MGT %d: %04X:%04X\n", mgtIndex, csr >> 16, csr & 0xFFFF);
    }
}

void
mgtInit(void)
{
    uint32_t csr;
    uint32_t then = microsecondsSinceBoot();
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
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RESET_ENABLE | CSR_W_TX_SOFT_RESET |
                                                      CSR_W_RX_SOFT_RESET);
    microsecondSpin(1);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RESET_ENABLE);
    eyescanInit();

    /*
     * Must reset PMA after enabling eye scan hardware
     */
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RESET_ENABLE | ((1UL<<CFG_MGT_COUNT)-1));
    microsecondSpin(1);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RESET_ENABLE);
}

/*
 * Must use receiver manual alignment since automatic alignment results in a
 * one receiver clock uncertainty in the timing of the received data.
 * RXSLIDE can't be used since that again results in the uncertainty.
 * The solution is simple, but crude.  Keep resetting the receiver until
 * it happens to start up with the correct bit alignment.
 */
void
mgtCrank(void)
{
    unsigned int isUp;
    static unsigned int wasUp = ~0;
    uint32_t now = microsecondsSinceBoot();
    static uint32_t then;

    if ((now - then) < 100000) {
        return;
    }
    isUp = GPIO_READ(GPIO_IDX_LINK_STATUS) & activeLanes;
    if ((debugFlags & DEBUGFLAG_MGT) && (isUp != wasUp)) {
        printf("MGT links up: %X\n", isUp);
    }
    if ((isUp & activeLanes) != activeLanes) {
        unsigned int isDown = ~isUp & activeLanes;
        GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RESET_ENABLE | isDown);
        microsecondSpin(2);
        GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_RESET_ENABLE);
    }
    wasUp = isUp;
    then = now;
}

uint32_t
mgtFetchSysmon(int index)
{
    switch (index) {
    case 0: return GPIO_READ(GPIO_IDX_LINK_STATUS);
    default: return 0;
    }
}

void
mgtSetActiveLanes(uint32_t active)
{
    uint32_t idleLanes;
    /*
     * First channel (EVR) is always active
     */
    activeLanes = (active | 0x1) & ((1UL << CFG_MGT_COUNT) - 1);
    idleLanes = ~activeLanes & ((1UL << CFG_MGT_COUNT) - 1);
    GPIO_WRITE(GPIO_IDX_MGT_CSR, CSR_W_POWERDOWN_ENABLE | idleLanes);
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
