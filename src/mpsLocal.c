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
 * Local machine protection support
 */

#include <stdio.h>
#include <xparameters.h>
#include "gpio.h"
#include "mpsLocal.h"
#include "util.h"

#define CSR_MPS_OUTPUT_SEL_MASK         0x07
#define CSR_MPS_REG_SEL_MASK            0x0F00
#define CSR_MPS_REG_SEL_SHIFT           8
# define CSR_REG_HIHI_BITMAP            0x0000
# define CSR_REG_HI_BITMAP              0x0100
# define CSR_REG_LO_BITMAP              0x0200
# define CSR_REG_LOLO_BITMAP            0x0300
# define CSR_REG_DISCRETE_BITMAP        0x0400
# define CSR_REG_DISCRETE_GOOD_STATE    0x0500
# define CSR_REG_FIRST_FAULT_HIHI       0x0600
# define CSR_REG_FIRST_FAULT_HI         0x0700
# define CSR_REG_FIRST_FAULT_LO         0x0800
# define CSR_REG_FIRST_FAULT_LOLO       0x0900
# define CSR_REG_FIRST_FAULT_DISCRETE   0x0A00
# define CSR_REG_FIRST_FAULT_SECONDS    0x0B00
# define CSR_REG_FIRST_FAULT_TICKS      0x0C00
# define CSR_REG_TRIPPED                0x0D00

#define CSR_WRITE(x)  GPIO_WRITE(GPIO_IDX_MPS_CSR, (x))
#define CSR_READ()    GPIO_READ(GPIO_IDX_MPS_CSR)
#define DATA_WRITE(x) GPIO_WRITE(GPIO_IDX_MPS_DATA, (x))
#define DATA_READ()   GPIO_READ(GPIO_IDX_MPS_DATA)

void
mpsLocalInit(void)
{
}

static uint32_t
getReg(int regSel, int outputIndex)
{
    uint32_t sel = (regSel & CSR_MPS_REG_SEL_MASK) |
                                        (outputIndex & CSR_MPS_OUTPUT_SEL_MASK);
    CSR_WRITE(sel);
    return DATA_READ();
}

static void
setReg(int regSel, int outputIndex, uint32_t value)
{
    uint32_t sel = (regSel & CSR_MPS_REG_SEL_MASK) |
                                        (outputIndex & CSR_MPS_OUTPUT_SEL_MASK);
    CSR_WRITE(sel);
    DATA_WRITE(value);
}

void
mpsLocalDumpReg(void)
{
    int o;
    for (o = 0 ; o < CFG_MPS_OUTPUT_COUNT ; o++) {
        int r;
        uint32_t v = getReg(CSR_REG_TRIPPED, o);
        static const char * const names[] = {
            "Check HIHI",
            "Check HI",
            "Check LO",
            "Check LOLO",
            "Check Digital",
            "GOOD state",
            "First Fault HIHI",
            "First Fault HI",
            "First Fault LO",
            "First Fault LOLO",
            "First Fault Digital",
            "First Fault Seconds",
            "First Fault Ticks",
            "Status" };
        printf("Output %d:%sripped\n", o + 1, (v & 0x1) ? "T" : " Not T");
        for (r = 0 ; r < sizeof names / sizeof names[0] ; r++) {
            v = getReg((r << CSR_MPS_REG_SEL_SHIFT), o);
            printf("%24s: %04X:%04X\n", names[r], (v >> 16), v & 0xFFFF);
        }
    }
}

void
mpsLocalSetImportantBitmap(int mapSelect, int outputIndex, uint32_t map)
{
}

void
mpsLocalSetLOLObitmap(int outputIndex, uint32_t map)
{
    setReg(CSR_REG_LOLO_BITMAP, outputIndex, map);
}

void
mpsLocalSetLObitmap(int outputIndex, uint32_t map)
{
    setReg(CSR_REG_LO_BITMAP, outputIndex, map);
}

void
mpsLocalSetHIbitmap(int outputIndex, uint32_t map)
{
    setReg(CSR_REG_HI_BITMAP, outputIndex, map);
}

void
mpsLocalSetHIHIbitmap(int outputIndex, uint32_t map)
{
    setReg(CSR_REG_HIHI_BITMAP, outputIndex, map);
}

void
mpsLocalSetDiscreteBitmap(int outputIndex, uint32_t map)
{
    setReg(CSR_REG_DISCRETE_BITMAP, outputIndex, map);
}

void
mpsLocalSetDiscreteGoodState(int outputIndex, uint32_t goodState)
{
    setReg(CSR_REG_DISCRETE_GOOD_STATE, outputIndex, goodState);
}

uint32_t
mpsLocalIsTripped(int outputIndex)
{
    return getReg(CSR_REG_TRIPPED, outputIndex);
}

uint32_t
mpsLocalGetLOLObitmap(int outputIndex)
{
    return getReg(CSR_REG_LOLO_BITMAP, outputIndex);
}

uint32_t
mpsLocalGetLObitmap(int outputIndex)
{
    return getReg(CSR_REG_LO_BITMAP, outputIndex);
}

uint32_t
mpsLocalGetHIbitmap(int outputIndex)
{
    return getReg(CSR_REG_HI_BITMAP, outputIndex);
}

uint32_t
mpsLocalGetHIHIbitmap(int outputIndex)
{
    return getReg(CSR_REG_HIHI_BITMAP, outputIndex);
}

uint32_t
mpsLocalGetDiscreteBitmap(int outputIndex)
{
    return getReg(CSR_REG_DISCRETE_BITMAP, outputIndex);
}

uint32_t
mpsLocalGetDiscreteGoodState(int outputIndex)
{
    return getReg(CSR_REG_DISCRETE_GOOD_STATE, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultLOLO(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_LOLO, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultLO(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_LO, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultHI(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_HI, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultHIHI(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_HIHI, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultDiscrete(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_DISCRETE, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultSeconds(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_SECONDS, outputIndex);
}

uint32_t
mpsLocalGetFirstFaultTicks(int outputIndex)
{
    return getReg(CSR_REG_FIRST_FAULT_TICKS, outputIndex);
}


uint32_t
mpsLocalFetchSysmon(int index)
{
    return 0;
}
