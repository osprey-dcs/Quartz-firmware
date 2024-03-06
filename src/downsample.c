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
 * Downsample acquired data to desired sampling rate
 */
#include <stdio.h>
#include <xparameters.h>
#include "ad7768.h"
#include "downsample.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_SET_DOWNSAMPLE    (1<<31)
#define CSR_W_SET_ALPHA         (1<<30)
#define CSR_W_DATA_MASK         0x0FFFFFFF

#define DOWNSAMPLE_MAX      1023
#define ALPHA_UNITY_GAIN    (1 << 17)

void
downsampleInit(void)
{
    downsampleSetAlpha(ALPHA_UNITY_GAIN);
    downsampleSetDownsample(1);
}

void
downsampleSetAlpha(int alpha)
{
    if (alpha > ALPHA_UNITY_GAIN) alpha = ALPHA_UNITY_GAIN;
    if (alpha < 1) alpha = 1;
    GPIO_WRITE(GPIO_IDX_DOWNSAMPLE_CSR, CSR_W_SET_ALPHA |
                                                    (alpha & CSR_W_DATA_MASK));
}

void
downsampleSetDownsample(int divisor)
{
    static int oldDivisor = -1;
    if (divisor > DOWNSAMPLE_MAX) divisor = DOWNSAMPLE_MAX;
    if (divisor < 1) divisor = 1;
    if (divisor != oldDivisor) {
        GPIO_WRITE(GPIO_IDX_DOWNSAMPLE_CSR, CSR_W_SET_DOWNSAMPLE |
                                                   (divisor & CSR_W_DATA_MASK));
        ad7768StartAlignment();
        oldDivisor = divisor;
    }
}
