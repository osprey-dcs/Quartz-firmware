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
 * Merge MPS tripped status from downstream nodes
 */

#include <stdio.h>
#include <xparameters.h>
#include "evg.h"
#include "gpio.h"
#include "mpsMerge.h"
#include "systemParameters.h"
#include "util.h"

#define CSR_REQUIRED_MASK   0xFF
#define CSR_TRIPPED_MASK    0xFF0000
#define CSR_TRIPPED_SHIFT   16

void
mpsMergeSetRequiredLinks(uint32_t requiredLinks)
{
    requiredLinks &= ~(isEVG() ? 0x1 : 0x3);
    GPIO_WRITE(GPIO_IDX_MPS_MERGE_CSR, requiredLinks);
}

uint32_t
mpsMergeGetRequiredLinks(void)
{
    return GPIO_READ(GPIO_IDX_MPS_MERGE_CSR) & CSR_REQUIRED_MASK;
}

uint32_t
mpsMergeGetTripped(void)
{
    return (GPIO_READ(GPIO_IDX_MPS_MERGE_CSR) & CSR_TRIPPED_MASK)
                                                           >> CSR_TRIPPED_SHIFT;
}

