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
 * General-purpose I/O registers
 * Use to generate Verilog parameter statements -- all GPIO_IDX
 * macros must be base ten constants.
 */

#ifndef _GPIO_H_
#define _GPIO_H_

#include <xil_io.h>

#define GPIO_IDX_FIRMWARE_DATE              0 // Firmware build POSIX date (R)
#define GPIO_IDX_MICROSECONDS_SINCE_BOOT    1 // 1 MHz counter (R)
#define GPIO_IDX_SECONDS_SINCE_BOOT         2 // 1 Hz counter (R)
#define GPIO_IDX_SYS_TIMESTAMP_SECONDS      3 // Time of day from EVR
#define GPIO_IDX_SYS_TIMESTAMP_TICKS        4 // Time of day from EVR
#define GPIO_IDX_MMC_IO                     5 // Microcontroller communication
#define GPIO_IDX_MGT_CSR                    6 // Multi-gigabit transeiver CSR
#define GPIO_IDX_LINK_STATUS                7 // MGT link status
#define GPIO_IDX_EVG_CSR                    8 // Event generator seconds/status
#define GPIO_IDX_EVG_ACQ_CSR                9 // Event generator acq ctrl/status
#define GPIO_IDX_FREQUENCY_COUNTERS        10 // Multi-input frequency counters
#define GPIO_IDX_ACQCLK_PLL_CSR            11 // VCXO clock adjust status
#define GPIO_IDX_ACQCLK_PLL_AUX_STATUS     12 // More VCXO clock adjust status
#define GPIO_IDX_AD7768_CSR                13 // AD7768 ADC control/status
#define GPIO_IDX_AD7768_DRDY_STATUS        14 // AD7768 DRDY alignment status
#define GPIO_IDX_AD7768_DRDY_HISTORY       15 // AD7768 DRDY logic analyzer
#define GPIO_IDX_AD7768_ALIGN_COUNT        16 // AD7768 (re)alignment count
#define GPIO_IDX_INPUT_COUPLING_CSR        17 // Firmware AC/DC coupling
#define GPIO_IDX_MCLK_SELECT_CSR           18 // ADC MCLK selection CSR
#define GPIO_IDX_BUILD_PACKET_STATUS       19 // Packet builder status (R)
#define GPIO_IDX_BUILD_PACKET_BITMAP       20 // Packet builder active channels
#define GPIO_IDX_BUILD_PACKET_BYTECOUNT    21 // Packet builder packet size
#define GPIO_IDX_INPUT_COUPLING_CLR        22 // Input coupling RESET coils (AC)
#define GPIO_IDX_INPUT_COUPLING_SET_START  23 // SET coils (DC) and start SPI
#define GPIO_IDX_DIGITIZER_AMC7823         24 // Digitizer slow monitors
#define GPIO_IDX_PPS_LATENCY               25 // HW to EVR PPS interval
#define GPIO_IDX_PPS_STATUS                26 // Hardware PPS status
#define GPIO_IDX_PPS_JITTER                27 // Average PPS jitter

#define GPIO_IDX_COUNT                     32 // Number of GPIO registers

#define GPIO_READ(r) Xil_In32(XPAR_GENERIC_REG_BASEADDR+((r)*4))
#define GPIO_WRITE(r,v) Xil_Out32(XPAR_GENERIC_REG_BASEADDR+((r)*4),(v))

#define microsecondsSinceBoot() GPIO_READ(GPIO_IDX_MICROSECONDS_SINCE_BOOT)

#include "config.h"

#endif /* _GPIO_H_ */
