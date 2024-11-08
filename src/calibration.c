/*
 * MIT License
 *
 * Copyright (c) 2024 Osprey DCS
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
 * Calibration factors
 */

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include "ad7768.h"
#include "config.h"
#include "gpio.h"
#include "calibration.h"
#include "util.h"

#define CHANNEL_COUNT ((CFG_AD7768_CHIP_COUNT) * (CFG_AD7768_ADC_PER_CHIP))
#define MAGIC 0x3789ECF6

/*
 * EEPROM IIC 7-bit address
 */
#define EEPROM_ADDRESS7 0x57

struct calEEPROM {
    uint32_t magic;
    uint32_t calibrationDate;
    uint8_t  offsets[3*CHANNEL_COUNT];
    uint8_t  gains[3*CHANNEL_COUNT];
    uint32_t checksum;
};

enum statusCodes {
    S_VALID,
    S_UNREAD,
    S_READ_FAULT,
    S_BAD_MAGIC,
    S_BAD_CHECKSUM,
    S_WRITE_FAULT
};

static int32_t status = S_UNREAD;
static uint32_t calibrationDate;
static int32_t offsets[CHANNEL_COUNT];
static int32_t gains[CHANNEL_COUNT];
static int hasChanged;
static const char name[] = "Calibration.bin";

/*
 * Back ported from QuartzV2.
 * Option to use the Marble flash to act as the QuartzV2 on-board EEPROM.
 */
#include "ffs.h"
int
readEEPROM(int address, unsigned int length, void *buf)
{
#ifdef CONFIG_CALIBRATION_IN_MARBLE
    FIL fil;
    FRESULT fr;
    unsigned int nRead;

    if ((fr = f_open(&fil, name, FA_READ)) != FR_OK) {
        status = S_READ_FAULT;
        return -1;
    }
    fr = f_read(&fil, buf, length, &nRead);
    f_close(&fil);
    if ((fr != FR_OK)
     || (nRead != length)) {
        status = S_READ_FAULT;
        return -1;
    }
    return length;
#else
    return -1;
#endif
}

int
writeEEPROM(int address, unsigned int length, const void *buf)
{
#ifdef CONFIG_CALIBRATION_IN_MARBLE
    FIL fil;
    FRESULT fr;
    unsigned int nWritten;

    if ((fr = f_open(&fil, name, FA_CREATE_ALWAYS | FA_WRITE)) != FR_OK) {
        status = S_WRITE_FAULT;
        return -1;
    }
    fr = f_write(&fil, buf, length, &nWritten);
    f_close(&fil);
    if ((fr != FR_OK)
     || (nWritten != length)) {
        status = S_WRITE_FAULT;
        return -1;
    }
    return length;
#else
    return -1;
#endif
}

static int32_t *
getAddr(int index)
{
    if (index < 0) return NULL;
    if (index < CHANNEL_COUNT) return &offsets[index];
    index -= CHANNEL_COUNT;
    if (index < CHANNEL_COUNT) return &gains[index];
    index -= CHANNEL_COUNT;
    switch (index) {
    case 0: return (int32_t *)&calibrationDate;
    case 1: return &status;
    default: return NULL;
    }
}

void
calibrationSetValue(int index, int value)
{
    int32_t i32Value, *vp;
    static uint32_t unwrittenOffsets = ~0;
    static uint32_t unwrittenGains = ~0;
    if ((vp = getAddr(index)) == NULL) return;
    if (index < CHANNEL_COUNT) {
        if (value < -1000000) {
            value = -1000000;
        }
        if (value > 1000000) {
            value = 1000000;
        }
        ad7768SetOfst(index, value);
        unwrittenOffsets &= ~((uint32_t)1 << index);
    }
    else if (index < (2 * CHANNEL_COUNT)) {
        if (value < -50000) {
            value = -50000;
        }
        if (value > 50000) {
            value = 50000;
        }
        ad7768SetGain(index - CHANNEL_COUNT, value);
        unwrittenGains &= ~((uint32_t)1 << (index - CHANNEL_COUNT));
    }
    else {
        if (debugFlags & DEBUGFLAG_CALIBRATION) {
            printf("CAL[%d] = %d\n", index, value);
        }
    }
    i32Value = (int32_t)value;
    if (i32Value != *vp) {
        *vp = i32Value;
        hasChanged = 1;
    }
    if ((unwrittenOffsets == 0) && (unwrittenGains == 0)) {
        status = S_VALID;
    }
}

int
calibrationGetValue(int index)
{
    int32_t *vp;
    if ((vp = getAddr(index)) == NULL) return 0;
    return *vp;
}

int
calibrationStatus(void)
{
    return status;
}

static void
pack(uint8_t *cp, uint32_t value)
{
    cp[0] = value >> 16;
    cp[1] = value >> 8;
    cp[2] = value;
}

void
calibrationWrite(void)
{
    if (hasChanged) {
        int i;
        struct calEEPROM buf;
        uint32_t checksum = 0, *lp;
        if (debugFlags & DEBUGFLAG_CALIBRATION) {
            printf("Write calibration EEPROM.\n");
        }
        buf.magic = MAGIC;
        buf.calibrationDate = calibrationDate;
        for (i = 0 ; i < CHANNEL_COUNT ; i++) {
            pack(&buf.offsets[3*i], offsets[i]);
            pack(&buf.gains[3*i], gains[i]);
        }
        lp = (uint32_t *)&buf;
        while (lp < &buf.checksum) {
            checksum += *lp++;
        }
        buf.checksum = checksum;
        if (writeEEPROM(0, sizeof buf, &buf) == sizeof buf) {
            status = S_VALID;
        }
        else {
            printf("Calibration EEPROM write failed!\n");
            status = S_WRITE_FAULT;
        }
        hasChanged = 0;
    }
}

static int
unpack(const uint8_t *cp)
{
    uint32_t value = (cp[0] << 16) | (cp[1] << 8) | cp[2];
    if (value & 0x800000) value |= 0xFF000000;
    return value;
}

int
calibrationInit(void)
{
    int i;
    struct calEEPROM buf;
    uint32_t checksum = 0, *lp;
    if (readEEPROM(0, sizeof buf, &buf) != sizeof buf) {
        printf("Calibration fault -- EEPROM read error.\n");
        status = S_READ_FAULT;
        return 0;
    }
    if (buf.magic != MAGIC) {
        printf("Calibration fault -- Bad magic number.\n");
        status = S_BAD_MAGIC;
        return 0;
    }
    lp = (uint32_t *)&buf;
    while (lp < &buf.checksum) {
        checksum += *lp++;
    }
    if (checksum != buf.checksum) {
        printf("Calibration fault -- Bad checksum.\n");
        status = S_BAD_CHECKSUM;
        return 0;
    }
    calibrationDate = buf.calibrationDate;
    if (debugFlags & DEBUGFLAG_CALIBRATION) {
        printf("Calibration date: %u\n", calibrationDate);
    }
    for (i = 0 ; i < CHANNEL_COUNT ; i++) {
        offsets[i] = unpack(&buf.offsets[3*i]);
        gains[i] = unpack(&buf.gains[3*i]);
    }
    return 1;
}

void
calibrationApply(void)
{
    int i;
    for (i = 0 ; i < CHANNEL_COUNT ; i++) {
        ad7768SetOfst(i, offsets[i]);
        ad7768SetGain(i, gains[i]);
    }
}
