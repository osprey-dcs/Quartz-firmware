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
 * Read XADC system monitor */
#include <stdio.h>
#include <xil_io.h>
#include <xparameters.h>
#include "xadc.h"
#include "util.h"

#define In32(offset)    Xil_In32(XPAR_XADC_BASEADDR+(offset))
#define Out32(offset,v) Xil_Out32(XPAR_XADC_BASEADDR+(offset), v)

#define R_SOFT_RESET    0x000 /* Reset XADC */
#define R_TEMP          0x200 /* On-chip Temperature */
#define R_VCCINT        0x204 /* FPGA VCCINT */
#define R_VCCAUX        0x208 /* FPGA VCCAUX */
#define R_VBRAM         0x218 /* FPGA VBRAM */
#define R_CFR0          0x300 /* Configuration Register 0 */
#define R_CFR1          0x304 /* Configuration Register 1 */
#define R_CFR2          0x308 /* Configuration Register 2 */
#define R_SEQ00         0x320 /* Seq Reg 00 -- Channel Selection */
#define R_SEQ01         0x324 /* Seq Reg 01 -- Channel Selection */
#define R_SEQ02         0x328 /* Seq Reg 02 -- Average Enable */
#define R_SEQ03         0x32C /* Seq Reg 03 -- Average Enable */
#define R_SEQ04         0x330 /* Seq Reg 04 -- Input Mode Select */
#define R_SEQ05         0x334 /* Seq Reg 05 -- Input Mode Select */
#define R_SEQ06         0x338 /* Seq Reg 06 -- Acquisition Time Select */
#define R_SEQ07         0x33C /* Seq Reg 07 -- Acquisition Time Select */

void
xadcInit(void)
{
    Out32(R_SOFT_RESET, 0x000A);
    microsecondSpin(20000);
}

uint32_t *
xadcFetchSysmon(uint32_t *buf)
{
    *buf++ = In32(R_TEMP);
    *buf++ = In32(R_VCCINT);
    *buf++ = In32(R_VCCAUX);
    *buf++ = In32(R_VBRAM);
    return buf;
}

/*
 * Return FPGA temperature in units of 0.1 degree C
 * Avoid floating point arithmetic
 */
int
xadcGetFPGAtemp(void)
{
    return ((In32(R_TEMP) * 5040) >> 16) - 2732;
}
