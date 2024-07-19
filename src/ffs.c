/*
 * MIT License
 *
 * Copyright (c) 2022 Osprey DCS
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
 * Simple wrapper around bootstrap flash I/O routines.
 * Provides API matching our wrapper around the Xilinx FFS
 * library and the salient routines of the library itself.
 * Extremely basic, only a single "file" at a time can be open.
 */

#include <stdio.h>
#include <stdint.h>
#include "ad7768recorder.h"
#include "bootFlash.h"
#include "config.h"
#include "ffs.h"
#include "iicFPGA.h"
#include "util.h"

#define MiB(x) ((x)*1024*1024)
#define KiB(x) ((x)*1024)
#define IS_EEPROM   0x80000000
#define IS_SPECIAL  0x40000000
#define IS_READONLY 0x20000000
#define IS_ASCII    0x10000000
#define BASE_MASK   0x0FFFFFFF

#define SPECIAL_AD7768_DRDY     0

struct fileInfo {
    const char *name;
    uint32_t    base;
    uint32_t    length;
};
/* Assume that largest sector in flash is no larger than 64 KiB. */
static const struct fileInfo fileTable[] = {
    { "BOOT.bin",         0,                                          MiB(7) },
    { "BOOT_A.bin",       CFG_ALT_BOOT_IMAGE_OFFSET,                  MiB(6) },
    { "SYSPARAM.dat",     MiB(15),                                    KiB(4) },
    { "Calibration.csv",  IS_ASCII|(MiB(15)+KiB(64)),                 KiB(4) },
    { "FullFlash.bin",    0,                                         MiB(16) },
    { "QSFP1_EEPROM.bin", IS_EEPROM|IS_READONLY|IIC_FPGA_IDX_QSFP1,      256 },
    { "QSFP2_EEPROM.bin", IS_EEPROM|IS_READONLY|IIC_FPGA_IDX_QSFP2,      256 },
    { "FMC1_EEPROM.bin",  IS_EEPROM|IIC_FPGA_IDX_FMC1_EEPROM,            256 },
    { "FMC2_EEPROM.bin",  IS_EEPROM|IIC_FPGA_IDX_FMC2_EEPROM,            256 },
    { "FMC2_EEPROM.bin",  IS_EEPROM|IIC_FPGA_IDX_FMC2_EEPROM,            256 },
    { "AD7768_DRDY.bin",  IS_SPECIAL|IS_READONLY|SPECIAL_AD7768_DRDY, 
                                       CFG_AD7768_DRDY_RECORDER_SAMPLE_COUNT }};

static uint32_t offset = UINT32_MAX;
static int activeMode;

int
f_open(FIL *fp, const char *name, int mode)
{
    int i;
    /*
     * Be paranoid
     */
    bootFlashEnableEraseConfirmation(1);
    bootFlashEnableWriteConfirmation(1);
    if (offset != UINT32_MAX) {
        return FR_NOT_READY;
    }
    for (i = 0 ; i < sizeof fileTable / sizeof fileTable[0] ; i ++) {
        if (strcasecmp(name, fileTable[i].name) == 0) {
            offset = 0;
            *fp = &fileTable[i];
            if ((mode == FA_WRITE) && (fileTable[i].base & IS_READONLY)) {
                return FR_ERR;
            }
            activeMode = mode;
            return FR_OK;
        }
    }
    return FR_NO_FILE;
}

FRESULT
f_read(FIL *fp, void *cbuf, unsigned int n, unsigned int *nread)
{
    const struct fileInfo *f;
    unsigned int nleft, l;
    if ((offset == UINT32_MAX) || (activeMode != FA_READ)) {
        return FR_ERR;
    }
    f = *fp;
    nleft = f->length - offset;
    if (nleft < n) {
        n = nleft;
    }
    if (n != 0) {
        if (f->base & IS_SPECIAL) {
            switch(f->base & BASE_MASK) {
            case SPECIAL_AD7768_DRDY:
                if (ad7768recorderRead(offset, n, cbuf) != n) {
                    return FR_ERR;
                }
                break;
            default:
                return FR_ERR;
            }
        }
        else if (f->base & IS_EEPROM) {
            unsigned int device = f->base & BASE_MASK;
            if (iicFPGAeepromRead(device, offset, n, cbuf) != n) {
                return FR_ERR;
            }
        }
        else {
            if (bootFlashRead((f->base + offset) & BASE_MASK, n, cbuf) != n) {
                return FR_ERR;
            }
        }
    }
    if ((f->base & IS_ASCII)
     && ((l = strnlen(cbuf, n)) < n)) {
        *nread = l;
        offset = f->length;
    }
    else {
        *nread = n;
        offset += n;
    }
    return FR_OK;
}

FRESULT
f_write(FIL *fp, const void *cbuf, unsigned int n, unsigned int *nwritten)
{
    const struct fileInfo *f;
    unsigned int nleft;
    *nwritten = 0;
    if ((offset == UINT32_MAX) || !(activeMode & FA_WRITE)) {
        return FR_ERR;
    }
    f = *fp;
    nleft = f->length - offset;
    if (nleft < n) {
        n = nleft;
    }
    if (n != 0) {
        if (f->base & IS_EEPROM) {
            unsigned int device = f->base & BASE_MASK;
            if (iicFPGAeepromWrite(device, offset, n, cbuf) != n) {
                return FR_ERR;
            }
        }
        else {
            if (bootFlashWrite((f->base + offset) & BASE_MASK, n, cbuf) != n) {
                return FR_ERR;
            }
        }
    }
    *nwritten = n;
    offset += n;
    return FR_OK;
}

FRESULT
f_close(FIL *fp)
{
    const struct fileInfo *f;
    if (offset == UINT32_MAX) {
        return FR_ERR;
    }
    f = *fp;
    if (f->base & IS_ASCII) {
        unsigned int nw;
        f_write(fp, "", 1, &nw);
    }
    offset = UINT32_MAX;
    return FR_OK;
}

const char *
ffsErrorString(int code) {
    switch (code) {
    case FR_OK:         return "";
    case FR_NOT_READY:  return "Busy";
    case FR_NO_FILE:    return "No file";
    case FR_ERR:        return "I/O error";
    default:            return "?";
    }
}

int ffsCheckMount(void) { return 1; }
void ffsUnmount(void) { return; }
