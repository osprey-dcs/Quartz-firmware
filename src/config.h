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

/*
 * System configuration
 * Used to generate Verilog parameter statements -- all CFG_ macros
 * must be base ten constants or valid C/Verilog espressions.
 */

#ifndef _CONFIG_H_
#define _CONFIG_H_

/*
 * System clock
 */
#define CFG_SYSCLK_RATE 100000000

/*
 * Acquisition and network clock
 */
#define CFG_ACQCLK_RATE 125000000

/*
 * Marble system clock VCXO
 */
#define CFG_MARBLE_VCXO_COUNTS_PER_HZ   35

/*
 * Multi-gigabit transceivers
 */
#define CFG_MGT_COUNT       8
#define CFG_MGT_RX_COUNT    1
#define CFG_EVG_CLK_RATE    125000000

/*
 * AD7768 master clock
 */
#define CFG_MCLK_RATE   32000000

/*
 * FMC AD7768 ADCs
 */
#define CFG_AD7768_CHIP_COUNT   4
#define CFG_AD7768_ADC_PER_CHIP 8
#define CFG_AD7768_WIDTH        24

/*
 * Ethernet packet capacity (1500) - IP header size (20) - UDP header size (8)
 */
#define CFG_UDP_PACKET_CAPACITY 1472

/*
 * Location of alternate boot image in flash memory
 */
#define CFG_ALT_BOOT_IMAGE_OFFSET   (8*1024*1024)

/*
 * Event receiver codes
 */
#define CFG_EVR_ACQ_STOP_CODE  96
#define CFG_EVR_ACQ_START_CODE 97

#endif /* _CONFIG_H_ */
