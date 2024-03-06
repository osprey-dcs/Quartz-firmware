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
 * MGT clock crosspoint switch (ADN4600)
 */
#include <stdio.h>
#include <stdint.h>
#include "iicFPGA.h"
#include "mgtClkSwitch.h"
#include "util.h"

#define REG_XPT_RESET   0x00
#define REG_XPT_CONFIG  0x40
#define REG_XPT_UPDATE  0x41
#define REG_TX0_CONFIG  0xC0

static int
setReg(int reg, int value)
{
    uint8_t cbuf[2];
    cbuf[0] = reg;
    cbuf[1] = value;
    if (iicFPGAwrite(IIC_FPGA_IDX_MGT_CLK_CROSSPOINT, cbuf, 2) != 2) {
        return -1;
    }
    return 0;
}

static int
getReg(int reg)
{
    uint8_t cbuf[1];
    if (iicFPGAread(IIC_FPGA_IDX_MGT_CLK_CROSSPOINT, reg, cbuf, 1) != 1) {
        return -1;
    }
    return cbuf[0];
}

static void
xptConnect(int outputIndex, int inputIndex)
{
    setReg(REG_XPT_CONFIG, ((inputIndex & 0x7) << 4) | (outputIndex & 0x7));
}

static void
outputEnable(int outputIndex, int enable)
{
    setReg(REG_TX0_CONFIG + (8 * outputIndex), enable ? 0x20 : 0x00);
}

void
mgtClkSwitchInit(void)
{
    int output, input;

    setReg(REG_XPT_RESET, 0x1);
    microsecondSpin(10);
    setReg(REG_XPT_RESET, 0x0);
    for (output = 0 ; output < 8 ; output++) {
        switch (output) {
        default:
            input = -1;
            break;

        case MGT_CLK_SWITCH_OUTPUT_MGTCLK0: /* Bank 116 REFCLK0 */
            input = MGT_CLK_SWITCH_INPUT_FPGA_REF_CLK0; /* 125 MHz VCXO */
            break;
        }
        if (input >= 0) {
            xptConnect(output, input);
            outputEnable(output, 1);
        }
        else {
            outputEnable(output, 0);
        }
    }
    setReg(REG_XPT_UPDATE, 0x1);
}

void
mgtClkSwitchShow(void)
{
    int i;
    static const uint8_t reg[] = {
        0x40, 0x41,
        0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
        0x58, 0x59, 0x5A, 0x5B,
        0x80, 0x88, 0x90, 0x98, 0xA0, 0xA8, 0xB0, 0xB8,
        0xC0, 0xC8, 0xD0, 0xD8, 0xE0, 0xE8, 0xF0, 0xF8,
        0x23, 0x83, 0x84, 0x85, 0x8B, 0x8C, 0x8D,
        0x83, 0x84, 0x85, 0x8B, 0x8C, 0x8D,
        0x93, 0x94, 0x95, 0x9B, 0x9C, 0x9D,
        0xA3, 0xA4, 0xA5, 0xAB, 0xAC, 0xAD,
        0xC1, 0xC2, 0xC3, 0xC9, 0xCA, 0xCB,
        0xD1, 0xD2, 0xD3, 0xD9, 0xDA, 0xDB,
        0xE1, 0xE2, 0xE3, 0xE9, 0xEA, 0xEB,
        0xF1, 0xF2, 0xF3, 0xF9, 0xFA, 0xFB };
    for (i = 0 ; i < sizeof reg ; i++) {
        printf("%02X %02X\n", reg[i], getReg(reg[i]));
    }
}
