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
#include "bootFlash.h"
#include "config.h"
#include "ffs.h"
#include "iicFPGA.h"
#include "util.h"

#define MiB(x) ((x)*1024*1024)
#define KiB(x) ((x)*1024)
#define IS_EEPROM   0x80000000
#define IS_READONLY 0x40000000
#define DEVICE_MASK 0x3FFFFFFF

struct fileInfo {
    const char *name;
    uint32_t    base;
    uint32_t    length;
};
/* Assume that largest sector in flash is no larger than 64 KiB. */
static const struct fileInfo fileTable[] = {
    { "BOOT.bin",         0,                                MiB(6), },
    { "BOOT_A.bin",       CFG_ALT_BOOT_IMAGE_OFFSET,        MiB(6), },
    { "SYSPARAM.dat",     MiB(15),                          KiB(4), },
    { "FullFlash.bin",    0,                               MiB(16), },
    { "QSFP1_EEPROM.bin", IS_EEPROM|IS_READONLY|
                                      IIC_FPGA_IDX_QSFP1,      256, },
    { "QSFP2_EEPROM.bin", IS_EEPROM|IS_READONLY|
                                      IIC_FPGA_IDX_QSFP2,      256, },
    { "FMC1_EEPROM.bin",  IS_EEPROM|IIC_FPGA_IDX_FMC1_EEPROM,  256, },
    { "FMC2_EEPROM.bin",  IS_EEPROM|IIC_FPGA_IDX_FMC2_EEPROM,  256, } };

static uint32_t offset = UINT32_MAX;
static int activeMode;

int
f_open(FIL *fp, const char *name, int mode)
{
    int i;
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
    unsigned int nleft;
    if ((offset == UINT32_MAX) || (activeMode != FA_READ)) {
        return FR_ERR;
    }
    f = *fp;
    nleft = f->length - offset;
    if (nleft < n) {
        n = nleft;
    }
    if (n != 0) {
        if (f->base & IS_EEPROM) {
            unsigned int device = f->base & DEVICE_MASK;
            if (iicFPGAeepromRead(device, offset, n, cbuf) != n) {
                return FR_ERR;
            }
        }
        else {
            if (bootFlashRead(f->base + offset, n, cbuf) != n) {
                return FR_ERR;
            }
        }
    }
    *nread = n;
    offset += n;
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
            unsigned int device = f->base & DEVICE_MASK;
            if (iicFPGAeepromWrite(device, offset, n, cbuf) != n) {
                return FR_ERR;
            }
        }
        else {
            if (bootFlashWrite(f->base + offset, n, cbuf) != n) {
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
    if (offset == UINT32_MAX) {
        return FR_ERR;
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
