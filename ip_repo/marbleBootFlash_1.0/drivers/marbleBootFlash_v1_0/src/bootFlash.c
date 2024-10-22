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
 * Rudimentary bit-bash interface to small subset of SPI flash commands.
 */
#include <stdio.h>
#include <xil_io.h>
#include "bootFlash.h"

#define CSR_RW_CLK     0x1
#define CSR_RW_CS_B    0x2
#define CSR_RW_MOSI    0x4
#define CSR_R_MISO     0x8
#define CSR_READ()   Xil_In32(csrAddress)
#define CSR_WRITE(v) Xil_Out32(csrAddress, (v))

#define MiB(x) ((x)*1024*1024)
#define KiB(x) ((x)*1024)

#define FLASH_SIZE      MiB(16)
#define FLASH_PAGE_SIZE 256
static int flashLoSectorCount;
static int flashLoSectorSize;
static int flashHiSectorSize;
static uint32_t csrAddress;

/*
 * Command bytes
 */
#define CMD_RDID        0x9F
#define CMD_RDCR        0x35
#define CMD_RDSR        0x05
#define CMD_CLSR        0x30
#define CMD_BRRD        0x16
#define CMD_WREN        0x06
#define CMD_WRR         0x01
#define CMD_SE          0xD8
#define CMD_P4E         0x20
#define CMD_BE          0x60
#define CMD_PP          0x02
#define CMD_READ        0x03
#define CMD_ERSP        0x75
#define CMD_PGSP        0x85
#define CMD_PGSP        0x85
#define CMD_RESET       0xF0
#define CMD_ASPRD       0x2B
#define CMD_DYBRD       0xE0

/*
 * Diagnostics
 */
static char verbose;
static char confirmErase;
static char confirmWrite;
void
bootFlashSetVerbose(int verboseFlag)
{
    verbose = verboseFlag;
}
void
bootFlashEnableEraseConfirmation(int enable)
{
    confirmErase = (enable != 0);
}
void
bootFlashEnableWriteConfirmation(int enable)
{
    confirmWrite = (enable != 0);
}

/*
 * Transfer data to/from boot flash.
 */
static void
bootFlashTxRx(const uint8_t *txBuf, uint32_t txLen,
                   uint8_t *rxBuf, uint32_t rxLen)
{
    CSR_WRITE(0);
    if (verbose) {
        xil_printf("bootFlash Tx");
    }
    while (txLen--) {
        int w = *txBuf++;
        int b;
        if (verbose) {
            xil_printf(" %02X", w);
        }
        for (b = 0x80 ; b != 0 ; b >>= 1) {
            uint32_t mosi = (w & b) ? CSR_RW_MOSI : 0;
            CSR_WRITE(mosi);
            CSR_WRITE(mosi | CSR_RW_CLK);
        }
    }
    if ((rxBuf == NULL) && (rxLen != 0)) {
        return;
    }
    if (rxLen) {
        if (verbose) {
            xil_printf(" Rx");
        }
        while (rxLen) {
            int r = 0;
            int b;
            for (b = 0x80 ; b != 0 ; b >>= 1) {
                CSR_WRITE(CSR_RW_CLK);
                CSR_WRITE(0);
                /*
                 * Assume that there is sufficient time between
                 * the write above and the read below for the
                 * data from the flash memory to stabilize.
                 * If this turns out to be an invalid assumption add a
                 * second CSR_WRITE(0) before issuing the CSR_READ().
                 */
                if (CSR_READ() & CSR_R_MISO) {
                    r |= b;
                }
            }
            rxLen--;
            *rxBuf++ = r;
            if (verbose) {
                xil_printf(" %02X", r);
            }
        }
    }
    else {
        CSR_WRITE(0);
    }
    CSR_WRITE(CSR_RW_CS_B);
    if (verbose) {
        xil_printf("\r\n");
    }
}

static int
bootFlashReadConfiguration(void)
{
    uint8_t txBuf[1];
    uint8_t rxBuf[1];
    txBuf[0] = CMD_RDCR;
    bootFlashTxRx(txBuf, 1, rxBuf, 1);
    return rxBuf[0];
}

static int
bootFlashReadStatus(void)
{
    uint8_t txBuf[1];
    uint8_t rxBuf[1];
    txBuf[0] = CMD_RDSR;
    bootFlashTxRx(txBuf, 1, rxBuf, 1);
    return rxBuf[0];
}

static void
bootFlashWriteEnable(void)
{
    int sr;
    uint8_t txBuf[1];
    txBuf[0] = CMD_WREN;
    bootFlashTxRx(txBuf, 1, NULL, 0);
    sr = bootFlashReadStatus();
    if ((sr & 0x2) == 0) {
        xil_printf("WARNING -- Boot flash SR:%02X after WREN.\r\n", sr);
    }
}

static void
bootFlashClearStatusRegister(void)
{
    uint8_t txBuf[1];
    txBuf[0] = CMD_CLSR;
    bootFlashTxRx(txBuf, 1, NULL, 0);
}

void
bootFlashInit(uint32_t baseAddress)
{
    int i;
    uint8_t txBuf[3];
    uint8_t rxBuf[80];

    /*
     * Set up hardware access
     */
    if (baseAddress == 0) {
        return;
    }
    csrAddress = baseAddress;

    /*
     * Toggle STARTUPE2 primitive USRCCLKO since the primitive eats
     * the first three clocks after initialization. (!!!)
     * See UG470 STARTUPE2 documentation for details.
     */
    for (i = 0 ; i < 3 ; i++) {
        CSR_WRITE(CSR_RW_CS_B | CSR_RW_CLK);
        CSR_WRITE(CSR_RW_CS_B | 0);
    }

    /*
     * Reset flash
     */
    txBuf[0] = CMD_RESET;
    bootFlashTxRx(txBuf, 1, NULL, 0);

    /*
     * Wait for reset completion
     */
    txBuf[0] = CMD_RDID;
    i = 0;
    for (;;) {
        bootFlashTxRx(txBuf, 1, rxBuf, 1);
        if (rxBuf[0] != 0xFF) break;
        if (++i == 1000) break;
    }

    /*
     * 4k sectors at top?
     */
    if (bootFlashReadConfiguration() & 0x04) {
        flashLoSectorCount = 254;
        flashLoSectorSize = KiB(64);
        flashHiSectorSize = KiB(4);
    }
    else {
        flashLoSectorCount = 32;
        flashLoSectorSize = KiB(4);
        flashHiSectorSize = KiB(64);
    }
    bootFlashShowStatus();
}

int
bootFlashRead(uint32_t address, uint32_t length, void *buf)
{
    uint8_t txBuf[4];
    if (csrAddress == 0) {
        return -1;
    }
    txBuf[0] = CMD_READ;
    txBuf[1] = address >> 16;
    txBuf[2] = address >> 8;
    txBuf[3] = address;
    bootFlashTxRx(txBuf, 4, buf, length);
    return length;
}

static int
bootFlashCheck(uint32_t address, uint32_t length, const uint8_t *wBuf)
{
    uint8_t rBuf[256];
    int i, nRead;
    while (length) {
        if (length > sizeof rBuf) {
            nRead = sizeof rBuf;
        }
        else {
            nRead = length;
        }
        if (bootFlashRead(address, nRead, rBuf) != nRead) {
            xil_printf("bootFlash read %d@%06X failed.\r\n", nRead, address);
            return -1;
        }
        for (i = 0 ; i < nRead ; i++) {
            if (rBuf[i] != (wBuf ? wBuf[i] : 0xFF)) {
                xil_printf("bootFlash %s %06X failed!\r\n",
                                         wBuf ? "write" : "erase", address + i);
                return -1;
            }
        }
        address += nRead;
        length -= nRead;
        if (wBuf) wBuf += nRead;
    }
    return 0;
}

/* 
 * The following function imposes some constraints on how it is invoked.
 *  - The first write to a sector must begin at the first address of the sector.
 *  - Writes must not span a sector boundary.
 */
int
bootFlashWrite(uint32_t address, uint32_t length, const void *buf)
{
    uint32_t nLeft = length;
    const uint8_t *txPtr = buf;
    uint8_t txBuf[4];
    volatile int timeout;
    uint32_t sectorSize =
                (address < (uint32_t)(flashLoSectorSize * flashLoSectorCount)) ?
                                          flashLoSectorSize : flashHiSectorSize;

    if (csrAddress == 0) {
        return -1;
    }
    while (nLeft) {
        int sr;
        int wrCount = (nLeft < FLASH_PAGE_SIZE) ? nLeft : FLASH_PAGE_SIZE;
        if ((address % sectorSize) == 0) {
            int pass = 0;
            for (;;) {
                if (++pass >= 3) {
                    return -1;
                }
                bootFlashWriteEnable();
                txBuf[0] = (sectorSize == KiB(4)) ? CMD_P4E : CMD_SE;
                txBuf[1] = address >> 16;
                txBuf[2] = address >> 8;
                txBuf[3] = address;
                bootFlashTxRx(txBuf, 4, NULL, 0);
                timeout = 0;
                while (((sr = bootFlashReadStatus()) & 0x21) != 0) {
                    if (sr & 0x20) {
                        xil_printf("Erase(0x%X) failed. SR: %02X\r\n", address,
                                                                            sr);
                        bootFlashClearStatusRegister();
                        return -1;
                    }
                    if (++timeout >= 2000000) {
                        txBuf[0] = CMD_ERSP;
                        bootFlashTxRx(txBuf, 1, NULL, 0);
                        xil_printf("Erase(0x%X) didn't complete. SR:%02X\r\n",
                                                                   address, sr);
                        bootFlashClearStatusRegister();
                        return -1;
                    }
                }
                if (confirmErase) {
                    if (bootFlashCheck(address, sectorSize, NULL) < 0) {
                        continue;
                    }
                }
                break;
            }
        }
        bootFlashWriteEnable();
        txBuf[0] = CMD_PP;
        txBuf[1] = address >> 16;
        txBuf[2] = address >> 8;
        txBuf[3] = address;
        bootFlashTxRx(txBuf, 4, NULL, 0x1);
        bootFlashTxRx(txPtr, wrCount, NULL, 0);
        timeout = 0;
        while (((sr = bootFlashReadStatus()) & 0x41) != 0) {
            if (sr & 0x40) {
                xil_printf("Program(0x%X) failed. SR: %02X\r\n", address, sr);
                bootFlashClearStatusRegister();
                return -1;
            }
            if (++timeout >= 1000000) {
                xil_printf("Program(0x%X) didn't complete. SR:%02X\r\n",
                                                                   address, sr);
                txBuf[0] = CMD_PGSP;
                bootFlashTxRx(txBuf, 1, NULL, 0);
                bootFlashClearStatusRegister();
                return -1;
            }
        }
        if (confirmWrite) {
            if (bootFlashCheck(address, wrCount, txPtr) < 0) {
                return -1;
            }
        }
        txPtr += wrCount;
        address += wrCount;
        nLeft -= wrCount;
    }
    return length;
}

void
bootFlashShowStatus(void)
{
    int sr, cr;
    uint8_t txBuf[5];
    uint8_t rxBuf[80];
    if (csrAddress == 0) return;

    txBuf[0] = CMD_RDID;
    bootFlashTxRx(txBuf, 1, rxBuf, sizeof rxBuf);
    xil_printf("JEDEC ID: %02X %02X %02X\r\n", rxBuf[0], rxBuf[1], rxBuf[2]);
    if ((rxBuf[0x00] != 0x01)
     || (rxBuf[0x01] != 0x20)
     || (rxBuf[0x02] != 0x18)) {
        xil_printf("Warning -- JEDEC ID expect to be: %02X %02X %02X\r\n",
                                                  rxBuf[0], rxBuf[1], rxBuf[2]);
    }
    if (rxBuf[0x04] != 0x01) {
        xil_printf("Warning -- Unexpected sector architecture %02X\r\n",
                                                                   rxBuf[0x04]);
    }
    if (rxBuf[0x4C] != 0x03) {
        xil_printf("Warning -- Unexpected page size %02X\r\n", rxBuf[0x4C]);
    }

    sr = bootFlashReadStatus();
    cr = bootFlashReadConfiguration();
    xil_printf("Flash SR:%02X CR:%02X\r\n", sr, cr);
    if ((sr & 0x1C) != 0) {
        xil_printf("Block protection set (SR:%02X).", sr);
    }

    /*
     * Check that we're using 3-byte addressing
     */
    txBuf[0] = CMD_BRRD;
    bootFlashTxRx(txBuf, 1, rxBuf, 1);
    if (rxBuf[0] != 0) {
        xil_printf("Warning -- Flash BAR %02X\r\n", rxBuf[0]);
    }

    txBuf[0] = CMD_ASPRD;
    bootFlashTxRx(txBuf, 1, rxBuf, 2);
    xil_printf("ASPR: %02X%02X\r\n", rxBuf[1], rxBuf[0]);

    txBuf[0] = CMD_DYBRD;
    txBuf[1] = 0;
    txBuf[2] = 0;
    txBuf[3] = 0;
    bootFlashTxRx(txBuf, 5, rxBuf, 1);
    xil_printf("First DYBAR: %02X\r\n", rxBuf[0]);
}

void
bootFlashBulkEraseChip(void)
{
    uint8_t txBuf[1];
    bootFlashWriteEnable();
    txBuf[0] = CMD_BE;
    bootFlashTxRx(txBuf, 1, NULL, 0);
}

void
bootFlashProtectGolden(void)
{
    int sr = bootFlashReadStatus();
    uint8_t txBuf[2];
    if ((sr & 0x98) != 0x98) {
        bootFlashWriteEnable();
        txBuf[0] = CMD_WRR;
        txBuf[1] = 0x98;
        bootFlashTxRx(txBuf, 2, NULL, 0);
        sr = bootFlashReadStatus();
        if ((sr & 0x98) != 0x98) {
            xil_printf("WARNING -- Boot flash SR:%02X.\r\n", sr);
        }
    }
}
