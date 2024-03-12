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

#ifndef _UTIL_H_
#define _UTIL_H_

#include "xil_printf.h"
#define printf xil_printf

/*
 * Control diagnostic output
 */
#define DEBUGFLAG_EPICS                 0x1
#define DEBUGFLAG_TFTP                  0x2
#define DEBUGFLAG_MGT                   0x4
#define DEBUGFLAG_EVG                   0x8
#define DEBUGFLAG_ACQ                   0x20
#define DEBUGFLAG_INPUT_COUPLING        0x40
#define DEBUGFLAG_NO_RELAY_EXERCISE     0x80
#define DEBUGFLAG_FLASH_SHOW            0x200
#define DEBUGFLAG_IIC_FPGA_SCAN         0x400
#define DEBUGFLAG_ETHERNET              0x1000
#define DEBUGFLAG_DUMP_AD7768_REG       0x2000
#define DEBUGFLAG_USE_FAKE_AD7768       0x8000
#define DEBUGFLAG_MGTCLKSWITCHSHOW     0x20000
#define DEBUGFLAG_START_AD7768_ALIGN    0x40000
#define DEBUGFLAG_CLOCKADJUST_STEP      0x80000
extern int debugFlags;

#define ntohl(x) __builtin_bswap32(x)
#define htonl(x) __builtin_bswap32(x)
#define ntohs(x) __builtin_bswap16(x)
#define htons(x) __builtin_bswap16(x)

void microsecondSpin(int microseconds);
void showIPv4address(const char *name, uint32_t address);
void resetFPGA(int bootAlternateImage);

#endif /* _UTIL_H_ */
