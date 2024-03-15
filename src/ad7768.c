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
#include "ad7768.h"
#include "clockAdjust.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_OP_CHIP_PINS      (0x1<<30)
# define OP_CHIP_PINS_START_ALIGNMENT   0x100
# define OP_CHIP_PINS_CONTROL_RESET     0x2
# define OP_CHIP_PINS_ASSERT_RESET      0x1
# define OP_CHIP_PINS_CONTROL_FAKE_ADC  0x4
# define OP_CHIP_PINS_ASSERT_FAKE_ADC   0x8
#define CSR_W_OP_SPI_TRANSFER   (0x2<<30)
# define OP_SPI_CS_MASK                 (((1<<CFG_AD7768_CHIP_COUNT)-1)<<16)
#define CSR_R_SPI_ACTIVE        0x80000000
#define CSR_R_ALIGNMENT_ACTIVE  0x40000000
#define CSR_R_CHIPS_ALIGNED     0x20000000
#define CSR_R_SPI_READ_MASK     0xFFFF

#define CSR_SPI_DATA_MASK 0xFFFF

#define CSR_WRITE(v) GPIO_WRITE(GPIO_IDX_AD7768_CSR, (v))
#define CSR_READ()   GPIO_READ(GPIO_IDX_AD7768_CSR)

#define MCLK_CSR_W_32p000   0x0
#define MCLK_CSR_W_25p600   0x1
#define MCLK_CSR_W_20p480   0x2
#define MCLK_CSR_W_16p384   0x3

#define CHAN_MODE_DEC_32    0x00
#define CHAN_MODE_DEC_64    0x01
#define CHAN_MODE_DEC_128   0x02
#define CHAN_MODE_DEC_256   0x03
#define CHAN_MODE_DEC_512   0x04
#define CHAN_MODE_DEC_1024  0x05
#define CHAN_MODE_SINC_FILT 0x08

#define POWER_MODE_MCLK_DIV_4   0x03
#define POWER_MODE_MCLK_DIV_8   0x02
#define POWER_MODE_MCLK_DIV_32  0x00
#define POWER_MODE_LVDS         0x08
#define POWER_MODE_FAST         0x30

struct downSampleInfo {
    uint8_t divisor;
    uint8_t mclkSelect;
    uint8_t channelMode;
    uint8_t powerMode;
};
static const struct downSampleInfo downSampleTable[] = {
 {   1, MCLK_CSR_W_32p000, CHAN_MODE_DEC_32,   POWER_MODE_MCLK_DIV_4 },
 {   5, MCLK_CSR_W_25p600, CHAN_MODE_DEC_128,  POWER_MODE_MCLK_DIV_4 },
 {  25, MCLK_CSR_W_20p480, CHAN_MODE_DEC_512,  POWER_MODE_MCLK_DIV_4 },
 {  50, MCLK_CSR_W_20p480, CHAN_MODE_DEC_1024, POWER_MODE_MCLK_DIV_4 },
 { 250, MCLK_CSR_W_16p384, CHAN_MODE_DEC_512,  POWER_MODE_MCLK_DIV_32 },
};

static void
awaitCompletion(void)
{
    while (CSR_READ() & CSR_R_SPI_ACTIVE) continue;
}

static void
broadcastReg(int reg, int value)
{
    CSR_WRITE(CSR_W_OP_SPI_TRANSFER | OP_SPI_CS_MASK |
                                        ((reg << 8) & 0xFF00) | (value & 0XFF));
    awaitCompletion();
}

static void
writeReg(int chip, int reg, int value)
{
    CSR_WRITE(CSR_W_OP_SPI_TRANSFER | ((0x10000<<chip) & OP_SPI_CS_MASK) |
                                        ((reg << 8) & 0xFF00) | (value & 0XFF));
    awaitCompletion();
}

static int
readReg(int chip, int reg)
{
    uint32_t csr = CSR_W_OP_SPI_TRANSFER | ((0x10000<<chip) & OP_SPI_CS_MASK) |
                                                 0x8000 | ((reg << 8) & 0x7F00);
    CSR_WRITE(csr);
    awaitCompletion();
    CSR_WRITE(csr);
    awaitCompletion();
    return (CSR_READ() & CSR_SPI_DATA_MASK);
}

void
ad7768DumpReg(void)
{
    int chip, reg;
    printf("  ");
    for (reg = 0 ; reg <= 0x14 ; reg++) {
        if ((reg >= 0x0B) && (reg <= 0x0D)) continue;
        printf(" %02X", reg);
    }
    printf("\n");
    for (chip = 0 ; chip < CFG_AD7768_CHIP_COUNT ; chip++) {
        printf("%d:", chip);
        for (reg = 0 ; reg <= 0x14 ; reg++) {
            if ((reg >= 0x0B) && (reg <= 0x0D)) continue;
            printf(" %02X", readReg(chip, reg));
        }
        printf("\n");
    }
}

static void
ad7768step(int startAlignment)
{
    static int alignmentRequested = 0;
    static int clockAdjustWasLocked = 0;
    static enum { ST_IDLE,
                  ST_START_ALIGN,
                  ST_AWAIT_FIRST_ALIGNMENT,
                  ST_AWAIT_SECOND_ALIGNMENT } state = ST_IDLE;
    /*
     * Request alignment on demand
     */
    if (startAlignment) {
        alignmentRequested = 1;
        return;
    }

    /*
     * Request alignment when clock locks
     */
    if (clockAdjustIsLocked()) {
        if (!clockAdjustWasLocked ) {
            clockAdjustWasLocked = 1;
            alignmentRequested = 1;
        }
    }
    else {
        clockAdjustWasLocked = 0;
    }

    /*
     * ADC alignment state machine
     */
    switch (state) {
    case ST_IDLE:
        if (alignmentRequested) {
            alignmentRequested = 0;
            state = ST_START_ALIGN;
        }
        break;

    case ST_START_ALIGN:
        printf("AD7768 alignment started.\n");
        CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_START_ALIGNMENT);
        state = ST_AWAIT_FIRST_ALIGNMENT;
        break;

    case ST_AWAIT_FIRST_ALIGNMENT:
        if (!(CSR_READ() & CSR_R_ALIGNMENT_ACTIVE)) {
            CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_START_ALIGNMENT);
            state = ST_AWAIT_SECOND_ALIGNMENT;
        }
        break;

    case ST_AWAIT_SECOND_ALIGNMENT:
        if (!(CSR_READ() & CSR_R_ALIGNMENT_ACTIVE)) {
            state = ST_IDLE;
        }
        break;
    }
}

void
ad7768StartAlignment(void)
{
    ad7768step(1);
}

void
ad7768Crank(void)
{
    ad7768step(0);
}

void
ad7768Init(void)
{
    int i;

    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_CONTROL_RESET |
                                   OP_CHIP_PINS_ASSERT_RESET);
    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_CONTROL_FAKE_ADC |
                                   ((debugFlags & DEBUGFLAG_USE_FAKE_AD7768) ?
                                                OP_CHIP_PINS_ASSERT_FAKE_ADC :
                                                0));
    microsecondSpin(10);
    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_CONTROL_RESET);
    microsecondSpin(50000);
    for (i = 0 ; i < CFG_AD7768_CHIP_COUNT ; i++) {
        int r = readReg(i, 0x0A);
        if (r != 0x06) {
            printf("AD7768 %d: Warning -- unexpected revision %02X.\n", i, r);
        }
    }
    broadcastReg(0x01, 0x00); // Mode A: Wideband, Decimate by 32
    broadcastReg(0x02, 0x08); // Mode B: Sinc5, Decimate by 32
    broadcastReg(0x04, 0x3B); // Fast mode, LVDS, MCLK_DIV=4
    broadcastReg(0x07, 0x01); // No CRC, DCLK_DIV=4
    broadcastReg(0x03, 0x00); // All channels in Mode A
    ad7768SetSamplingDivisor(1);
}

int
ad7768SetOfst(int channel, int offset)
{
    int i, chip, reg;
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
    }
    chip = channel / CFG_AD7768_ADC_PER_CHIP;
    reg  = ((channel % CFG_AD7768_ADC_PER_CHIP) * 3) + 0x20;
    for (i = 0 ; i < 3 ; i++) {
        writeReg(chip, reg, offset & 0xFF);
        offset >>= 8;
        reg--;
    }
    return 0;
}

int
ad7768SetGain(int channel, int gain)
{
    int i, chip, reg;
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
    }
    chip = channel / CFG_AD7768_ADC_PER_CHIP;
    reg  = ((channel % CFG_AD7768_ADC_PER_CHIP) * 3) + 0x338;
    gain += 0x555555;
    for (i = 0 ; i < 3 ; i++) {
        writeReg(chip, reg, gain & 0xFF);
        gain >>= 8;
        reg--;
    }
    return 0;
}

int
ad7768SetSamplingDivisor(int divisor)
{
    int i;
    for (i = 0 ; i < (sizeof downSampleTable/sizeof downSampleTable[0]) ; i++) {
        struct downSampleInfo const * const dp = &downSampleTable[i];
        if (dp->divisor == divisor) {
            if (debugFlags & DEBUGFLAG_ACQ) {
                printf("Divisor:%d mclkSel:%d, chanMode:%02X, MCLK_DIV:%02x\n",
                   dp->divisor, dp->mclkSelect, dp->channelMode, dp->powerMode);
            }
            GPIO_WRITE(GPIO_IDX_MCLK_SELECT_CSR, dp->mclkSelect);

            // Mode A: Wideband, Decimate by N
            broadcastReg(0x01, dp->channelMode);

            // Fast mode, LVDS, MCLK divide by N
            broadcastReg(0x04, POWER_MODE_FAST|POWER_MODE_LVDS|dp->powerMode);

            // Check that clock is good
            for (i = 0 ; i < CFG_AD7768_CHIP_COUNT ; i++) {
                uint8_t r = readReg(i, 0x09);
                if (r != 0) printf("AD7768[%d] R9:%02X\n", i, r);
            }
            ad7768StartAlignment();
            return 0;
        }
    }
    printf("AD77689 sampling divisor %d not supported.\n", divisor);
    return -1;
}

static void
showEVRclocks(const char *msg, int n)
{
    printf("%s AD7768 DRDY (EVR clocks): %d\n", msg, n);
}

uint32_t *
ad7768FetchSysmon(uint32_t *buf)
{
    *buf++ = GPIO_READ(GPIO_IDX_AD7768_AUX_STATUS);
    return buf;
}

void
ad7768ShowPPSalignment(void)
{
    int i;
    uint32_t csr = GPIO_READ(GPIO_IDX_AD7768_AUX_STATUS);
    showEVRclocks("PPS Event to", csr >> 12);
    showEVRclocks("Skew between", csr & 0xFFF);
    printf("DRDY History: %08X\n", GPIO_READ(GPIO_IDX_AD7768_DRDY_HISTORY));
    for (i = 0 ; i < CFG_AD7768_CHIP_COUNT ; i++) {
        int r;
        r = readReg(i, 0x09);
        if (r != 0) printf("AD7768[%d] R9:%02X\n", i, r);
    }
}
