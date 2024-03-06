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
 * AMC7823 Analog Monitoring and Control Circuit
 * Digitizer slow monitors
 */

#include <stdio.h>
#include <xparameters.h>
#include "amc7823.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_ASSERT_CS_N   0x40000000
#define CSR_W_DEASSERT_CS_N 0x60000000
#define CSR_R_BUSY          0x80000000
#define CSR_RW_REG_MASK     0xFFFF
#define CSR_R_ADC_DATA_MASK 0xFFF
#define CSR_R_ADC_REG_MASK  0xF000
#define CSR_R_ADC_REG_SHIFT 12

#define CSR_WRITE(v) GPIO_WRITE(GPIO_IDX_DIGITIZER_AMC7823, (v))
#define CSR_READ()   GPIO_READ(GPIO_IDX_DIGITIZER_AMC7823)

static int
amc7823ReadReg(int address)
{
    uint32_t csr;
    int page = (address >> 8) & 0x3;
    address &= 0x1F;
    CSR_WRITE(CSR_W_ASSERT_CS_N);
    CSR_WRITE(((1<<15) | (page<<12) | (address<<6)) << 16);
    while ((csr = CSR_READ()) & CSR_R_BUSY) continue;
    CSR_WRITE(CSR_W_DEASSERT_CS_N);
    return (csr & CSR_RW_REG_MASK);
}

static void
amc7823WriteReg(int address, int value)
{
    int page = (address >> 8) & 0x3;
    address &= 0x1F;
    CSR_WRITE(CSR_W_ASSERT_CS_N);
    CSR_WRITE((((page<<12) | (address<<6)) << 16) | (value & CSR_RW_REG_MASK));
    while (CSR_READ() & CSR_R_BUSY) continue;
    CSR_WRITE(CSR_W_DEASSERT_CS_N);
}

void
amc7823Init(void)
{
    int r;
    amc7823WriteReg(0x10C, 0xBB30); /* Reset */
    if ((r = amc7823ReadReg(0x11E)) != 0xE000) {
        printf("Warning -- AMC7823 ID:%04X expect E000\n", r);
    }
    amc7823WriteReg(0x109, 0x00FF); /* 2.5V for all DACs */
    amc7823WriteReg(0x10A, 0x0000); /* 1.25V reference */
    amc7823WriteReg(0x10B, 0x8080); /* Continuous conversion, all channels */
    amc7823WriteReg(0x00A, 0xFFDF); /* GPIO lines I/O, GPIO5 low (D1 lit) */
    amc7823WriteReg(0x10D, 0xFFA0); /* Power-up all but current source */
}

uint32_t *
amc7823FetchSysmon(uint32_t *buf)
{
    int i;
    /* Request registers 0 through 8, inclusive */
    uint32_t w = ((1 << 15) | (0 << 6) | 8) << 16;
    CSR_WRITE(CSR_W_ASSERT_CS_N);
    for (i = 0 ; i < 5 ; i++) {
        uint32_t csr;
        CSR_WRITE(w);
        w = 0;
        while ((csr = CSR_READ()) & CSR_R_BUSY) continue;
        /*
         * The first time through the least signficant 16 bits contain
         * the contents of register 0.  The second time through the most
         * significant 16 bits contain the contents of register 1, and the
         * least significant 16 bits the contents of register 2, and so on.
         * 12 bits per value, so the BUSY bit doesn't conflict with data.
         */
        if (i != 0) {
            *buf++ = (csr >> 16) & CSR_R_ADC_DATA_MASK;
        }
        *buf++ = csr & CSR_R_ADC_DATA_MASK;
    }
    CSR_WRITE(CSR_W_DEASSERT_CS_N);
    return buf;
}
