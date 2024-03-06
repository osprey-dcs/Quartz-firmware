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
#ifndef _MGTCLKSWITCH_H_
#define _MGTCLKSWITCH_H_

#define MGT_CLK_SWITCH_OUTPUT_MGTCLK0 0
#define MGT_CLK_SWITCH_OUTPUT_MGTCLK1 1
#define MGT_CLK_SWITCH_OUTPUT_MGTCLK2 4
#define MGT_CLK_SWITCH_OUTPUT_MGTCLK3 5

#define MGT_CLK_SWITCH_INPUT_EXT0_CLK       0
#define MGT_CLK_SWITCH_INPUT_EXT1_CLK       1
#define MGT_CLK_SWITCH_INPUT_FPGA_REF_CLK0  2
#define MGT_CLK_SWITCH_INPUT_SI570_CLK      3
#define MGT_CLK_SWITCH_INPUT_FMC1_GBTCLK0   4
#define MGT_CLK_SWITCH_INPUT_FMC1_GBTCLK1   5
#define MGT_CLK_SWITCH_INPUT_FMC2_GBTCLK0   6
#define MGT_CLK_SWITCH_INPUT_FMC2_GBTCLK1   7

void mgtClkSwitchInit(void);
void mgtClkSwitchShow(void);

#endif /* _MGTCLKSWITCH_H_ */
