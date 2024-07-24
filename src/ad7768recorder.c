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
 * AD7768 24-bit Delta/Sigma ADC
 */

#include <stdio.h>
#include <xparameters.h>
#include "ad7768recorder.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_START         0x80000000
#define CSR_R_ACTIVE        0x80000000
#define CSR_ADDRESS_SHIFT   (2*(CFG_AD7768_CHIP_COUNT))
#define CSR_DATA_MASK       ((1 << (2*(CFG_AD7768_CHIP_COUNT))) - 1)

#if ((CFG_AD7768_DRDY_RECORDER_SAMPLE_COUNT & \
                                (CFG_AD7768_DRDY_RECORDER_SAMPLE_COUNT-1)) != 0)
# error "CFG_AD7768_DRDY_RECORDER_SAMPLE_COUNT must be a power of two!"
#endif

void
ad7768recorderStart(void)
{
    GPIO_WRITE(GPIO_IDX_AD7768_RECORDER_CSR, CSR_W_START);
}

int
ad7768recorderIsBusy(void)
{
    return ((GPIO_READ(GPIO_IDX_AD7768_RECORDER_CSR) & CSR_R_ACTIVE) != 0);
}

int
ad7768recorderRead(unsigned int offset, unsigned int n, char *cbuf)
{
    int i;
    unsigned int base;
    uint32_t csr = GPIO_READ(GPIO_IDX_AD7768_RECORDER_CSR);

    if (csr & CSR_R_ACTIVE) {
        return -1;
    }
    base = (csr>>CSR_ADDRESS_SHIFT) & (CFG_AD7768_DRDY_RECORDER_SAMPLE_COUNT-1);
    for (i = 0 ; i < n ; i++) {
        unsigned int address = (base + offset + i) &
                                      (CFG_AD7768_DRDY_RECORDER_SAMPLE_COUNT-1);
        GPIO_WRITE(GPIO_IDX_AD7768_RECORDER_CSR, address);
        *cbuf++ = GPIO_READ(GPIO_IDX_AD7768_RECORDER_CSR) & CSR_DATA_MASK;
    }
    return n;
}
