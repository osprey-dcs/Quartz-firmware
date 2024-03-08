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
    static enum { ST_IDLE,
                  ST_START_ALIGN,
                  ST_AWAIT_FIRST_ALIGNMENT,
                  ST_AWAIT_SECOND_ALIGNMENT } state = ST_IDLE;
    if (startAlignment) {
        printf("AD7768 alignment from step %d\n", state);
        if (state == ST_IDLE) state = ST_START_ALIGN;
        return;
    }
    switch (state) {
    case ST_IDLE:
        break;

    case ST_START_ALIGN:
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
    ad7768StartAlignment();
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

static void
showEVRclocks(const char *msg, int n)
{
    printf("%s AD7768 DRDY (EVR clocks): %d\n", msg, n);
}

void
ad7768ShowPPSalignment(void)
{
    uint32_t csr = GPIO_READ(GPIO_IDX_AD7768_AUX_STATUS);
    showEVRclocks("PPS Event to", csr >> 16);
    showEVRclocks("Skew between", csr & 0xFFFF);
}
