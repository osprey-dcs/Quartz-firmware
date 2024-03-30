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
#define CSR_R_SPI_READ_MASK     0xFFFF

#define DRDY_STATUS_MISALIGNED          0x80000000
#define DRDY_STATUS_PPS_LATENCY_MASK    0xFFFFF

#define DRDY_HISTORY_STATE_MASK          0xC0000000
#define DRDY_HISTORY_STATE_SHIFT         30
#define DRDY_HISTORY_LOGIC_MASK          0xFFF

#define CSR_SPI_DATA_MASK 0xFFFF

#define CSR_WRITE(v) GPIO_WRITE(GPIO_IDX_AD7768_CSR, (v))
#define CSR_READ()   GPIO_READ(GPIO_IDX_AD7768_CSR)

#define RESTORE_VALUE 0x70000000

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

#define POWER_MODE_MCLK_DIV_4   0x33
#define POWER_MODE_MCLK_DIV_8   0x22
#define POWER_MODE_MCLK_DIV_32  0x00
#define POWER_MODE_LVDS         0x08

struct downSampleInfo {
    int     rate;
    uint8_t mclkSelect;
    uint8_t channelMode;
    uint8_t powerMode;
};

static struct downSampleInfo const *
downsampleInfo(int rate)
{
    /*
     * Table is small, linear search is fine.
     */
    int i;
    static const struct downSampleInfo downSampleTable[] = {
      { 250000, MCLK_CSR_W_32p000, CHAN_MODE_DEC_32,   POWER_MODE_MCLK_DIV_4 },
      {  50000, MCLK_CSR_W_25p600, CHAN_MODE_DEC_128,  POWER_MODE_MCLK_DIV_4 },
      {  10000, MCLK_CSR_W_20p480, CHAN_MODE_DEC_512,  POWER_MODE_MCLK_DIV_4 },
      {   5000, MCLK_CSR_W_20p480, CHAN_MODE_DEC_1024, POWER_MODE_MCLK_DIV_4 },
      {   1000, MCLK_CSR_W_16p384, CHAN_MODE_DEC_512,  POWER_MODE_MCLK_DIV_32 },
    };
    static struct downSampleInfo const * dpOld = &downSampleTable[4];
    if (rate <= 0) {
        return dpOld;
    }
    for (i = 0 ; i < (sizeof downSampleTable/sizeof downSampleTable[0]) ; i++) {
        struct downSampleInfo const * const dp = &downSampleTable[i];
        if (dp->rate == rate) {
            if (debugFlags & DEBUGFLAG_ACQ) {
                printf("Rate:%d mclkSel:%d, chanMode:%02X, MCLK_DIV:%02x\n",
                      dp->rate, dp->mclkSelect, dp->channelMode, dp->powerMode);
            }
            dpOld = dp;
            return dp;
        }
    }
    printf("CRITICAL WARNING -- %d samples/second not supported.\n", rate);
    dpOld = NULL;
    return NULL;
}

static void
awaitCompletion(void)
{
    while (CSR_READ() & CSR_R_SPI_ACTIVE) continue;
}

static void
broadcastReg(int reg, int value)
{
    if (debugFlags & DEBUGFLAG_SHOW_AD7768_UPDATES) {
        printf("AD7768 broadcast %02X<-%02X\n", reg, value);
    }
    CSR_WRITE(CSR_W_OP_SPI_TRANSFER | OP_SPI_CS_MASK |
                                        ((reg << 8) & 0xFF00) | (value & 0XFF));
    awaitCompletion();
}

static void
writeReg(int chip, int reg, int value)
{
    if (debugFlags & DEBUGFLAG_SHOW_AD7768_UPDATES) {
        printf("AD7768:%d %02X<-%02X\n", chip, reg, value);
    }
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
    for (reg = 0 ; reg <= 0x59 ; reg++) {
        if ((reg >= 0x0B) && (reg <= 0x0D)) continue;
        if ((reg >= 0x15) && (reg <= 0x1D)) continue;
        printf(" %02X:", reg);
        for (chip = 0 ; chip < CFG_AD7768_CHIP_COUNT ; chip++) {
            printf(" %02X", readReg(chip, reg));
        }
        printf("\n");
    }
}

void
ad7768StartAlignment(void)
{
    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_START_ALIGNMENT);
}

void
ad7768Reset(void)
{
    int i;
    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_CONTROL_RESET |
                                                     OP_CHIP_PINS_ASSERT_RESET);
    microsecondSpin(10);
    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_CONTROL_RESET);
    microsecondSpin(10000);
    for (i = 0 ; i<(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP) ; i++) {
        ad7768SetOfst(i, RESTORE_VALUE);
        ad7768SetGain(i, RESTORE_VALUE);
    }
    ad7768SetSamplingRate(0);
    return;
}
void
ad7768Init(void)
{
    int i;
    CSR_WRITE(CSR_W_OP_CHIP_PINS | OP_CHIP_PINS_CONTROL_FAKE_ADC |
                                    ((debugFlags & DEBUGFLAG_USE_FAKE_AD7768) ?
                                                 OP_CHIP_PINS_ASSERT_FAKE_ADC :
                                                 0));
    ad7768Reset();
    for (i = 0 ; i < CFG_AD7768_CHIP_COUNT ; i++) {
        int r = readReg(i, 0x0A);
        if (r != 0x06) {
            printf("AD7768 %d: Warning -- unexpected revision %02X.\n", i, r);
        }
    }
}

int
ad7768SetOfst(int channel, int offset)
{
    int i, chip, reg;
    static int offsets[CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP];
    if ((channel < 0)
     || (channel >= (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP))) {
        return -1;
    }
    if (offset == RESTORE_VALUE) offset = offsets[channel];
    chip = channel / CFG_AD7768_ADC_PER_CHIP;
    reg  = ((channel % CFG_AD7768_ADC_PER_CHIP) * 3) + 0x20;
    for (i = 0 ; i < 3 ; i++) {
        writeReg(chip, reg, offset & 0xFF);
        offset >>= 8;
        reg--;
    }
    offsets[channel] = offset;
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
    static int gains[CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP];
    if (gain == RESTORE_VALUE) gain = gains[channel];
    chip = channel / CFG_AD7768_ADC_PER_CHIP;
    reg  = ((channel % CFG_AD7768_ADC_PER_CHIP) * 3) + 0x338;
    gain += 0x555555;
    for (i = 0 ; i < 3 ; i++) {
        writeReg(chip, reg, gain & 0xFF);
        gain >>= 8;
        reg--;
    }
    gains[channel] = gain;
    return 0;
}

int
ad7768SetSamplingRate(int rate)
{
    struct downSampleInfo const *dp = downsampleInfo(rate);
    if (dp == NULL) return -1;

    // Select hardware clock
    GPIO_WRITE(GPIO_IDX_MCLK_SELECT_CSR, dp->mclkSelect);

    // Mode A: Wideband, Decimate by N
    broadcastReg(0x01, dp->channelMode);

    // Mode B: Sinc5, Decimate by 32
    broadcastReg(0x02, 0x08);

    // Fast mode, LVDS, MCLK divide by N
    broadcastReg(0x04, POWER_MODE_LVDS | dp->powerMode);

    // No CRC, DCLK_DIV=4
    broadcastReg(0x07, 0x01);

    // All channels in Mode A
    broadcastReg(0x03, 0x00);

    // Align ADCs
    ad7768StartAlignment();
    return 0;
}

uint32_t *
ad7768FetchSysmon(uint32_t *buf)
{
    *buf++ = fetchRegister(GPIO_IDX_AD7768_DRDY_STATUS);
    *buf++ = fetchRegister(GPIO_IDX_AD7768_ALIGN_COUNT);
    return buf;
}

void
ad7768ShowAlignment(void)
{
    int i;
    uint32_t status, history;
    status = fetchRegister(GPIO_IDX_AD7768_DRDY_STATUS);
    history = fetchRegister(GPIO_IDX_AD7768_DRDY_HISTORY);
    printf("DRDY %sligned.  PPS Event->DRDY:%d.  ",
                                 status & DRDY_STATUS_MISALIGNED ? "Misa" : "A",
                                 status & DRDY_STATUS_PPS_LATENCY_MASK);
    printf("DRDY History:%03X  State:%d\n",
                                     history & DRDY_HISTORY_LOGIC_MASK,
                                     (history & DRDY_HISTORY_STATE_MASK) >>
                                                      DRDY_HISTORY_STATE_SHIFT);
    printf("Alignment Count: %d\n", fetchRegister(GPIO_IDX_AD7768_ALIGN_COUNT));
    for (i = 0 ; i < CFG_AD7768_CHIP_COUNT ; i++) {
        int r;
        r = readReg(i, 0x09);
        if (r != 0) printf("AD7768[%d] R9:%02X\n", i, r);
    }
}
