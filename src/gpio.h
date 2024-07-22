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
#define GPIO_IDX_ACQCLK_HW_INTERVAL        13 // VCXO clocks between HW strobes
#define GPIO_IDX_ACQCLK_HW_JITTER          14 // HW_INTERVAL jitter
#define GPIO_IDX_AD7768_CSR                15 // AD7768 ADC control/status
#define GPIO_IDX_AD7768_DRDY_STATUS        16 // AD7768 DRDY alignment status
#define GPIO_IDX_AD7768_DRDY_HISTORY       17 // AD7768 DRDY logic analyzer
#define GPIO_IDX_AD7768_ALIGN_COUNT        18 // AD7768 (re)alignment count
#define GPIO_IDX_INPUT_COUPLING_CSR        19 // Firmware AC/DC coupling
#define GPIO_IDX_MCLK_SELECT_CSR           20 // ADC MCLK selection CSR
#define GPIO_IDX_BUILD_PACKET_STATUS       21 // Packet builder status (R)
#define GPIO_IDX_BUILD_PACKET_BITMAP       22 // Packet builder active channels
#define GPIO_IDX_BUILD_PACKET_BYTECOUNT    23 // Packet builder packet size
#define GPIO_IDX_ADC_THRESHOLDS            24 // ADC limits (W)
#define GPIO_IDX_ADC_EXCURSIONS            25 // ADC excursions beyond threshold
#define GPIO_IDX_INPUT_COUPLING_CLR        26 // Input coupling RESET coils (AC)
#define GPIO_IDX_INPUT_COUPLING_SET_START  27 // SET coils (DC) and start SPI
#define GPIO_IDX_DIGITIZER_AMC7823         28 // Digitizer slow monitors
#define GPIO_IDX_PPS_LATENCY               29 // HW to EVR PPS interval
#define GPIO_IDX_MPS_CSR                   30 // Machine protection CSR
#define GPIO_IDX_MPS_DATA                  31 // Machine protection data
#define GPIO_IDX_MPS_MERGE_CSR             32 // MPS merge/forward CSR
#define GPIO_IDX_AD7768_RECORDER_CSR       33 // AD7768 DCLK/DRDY recorder

#define GPIO_IDX_MCLK_FANOUT_ERROR_COUNT    40
#define GPIO_IDX_MCLK_CLK32P00_ERROR_COUNT  41
#define GPIO_IDX_MCLK_CLK25P60_ERROR_COUNT  42
#define GPIO_IDX_MCLK_CLK20P48_ERROR_COUNT  43

#define GPIO_IDX_COUNT                     64 // Number of GPIO registers

#define GPIO_READ(r) Xil_In32(XPAR_GENERIC_REG_BASEADDR+((r)*4))
#define GPIO_WRITE(r,v) Xil_Out32(XPAR_GENERIC_REG_BASEADDR+((r)*4),(v))

#define microsecondsSinceBoot() GPIO_READ(GPIO_IDX_MICROSECONDS_SINCE_BOOT)

#include "config.h"

#endif /* _GPIO_H_ */
