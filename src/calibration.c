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
#include "ad7768.h"
#include "acq.h"
#include "config.h"
#include "ffs.h"
#include "calibration.h"
#include "util.h"

#define FILENAME "Calibration.csv"

#define ADC_COUNT (CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP)

enum statusCode { STATUS_VALID = 0,
                  STATUS_UNINITIALIZED,
                  STATUS_MOUNT_FAILED,
                  STATUS_OPEN_FAILED,
                  STATUS_READ_FAILED,
                  STATUS_EOF,
                  STATUS_CONTENTS_GARBLED,
                  STATUS_BAD_CHARACTER,
                  STATUS_BAD_NUMBER };
static enum statusCode status = STATUS_UNINITIALIZED;
static int lineNumber, columnNumber;
static uint32_t date;

static void
error(int code)
{
    const char *msg;
    switch(code) {
    default:                        msg = "Error";                  break;
    case STATUS_MOUNT_FAILED:       msg = "Mount failed";           break;
    case STATUS_OPEN_FAILED:        msg = "Open failed";            break;
    case STATUS_READ_FAILED:        msg = "Read failed";            break;
    case STATUS_EOF:                msg = "Unexpected end of file"; break;
    case STATUS_CONTENTS_GARBLED:   msg = "Syntax error";           break;
    case STATUS_BAD_CHARACTER:      msg = "Bad character";          break;
    case STATUS_BAD_NUMBER:         msg = "Bad number";             break;

    }
    printf("Calibration error line %d, column %d: %s\n", lineNumber,
                                                             columnNumber, msg);
    status = code;
}

void
calibrationUpdate(void)
{
    FIL fil;
    if (!ffsCheckMount()) {
        error(STATUS_MOUNT_FAILED);
        return;
    }
    if (f_open(&fil, FILENAME, FA_READ) == FR_OK) {
        unsigned int nBuf = 0, cIndex = 0;
        char cbuf[128];
        int inNumber = 0;
        int needNumber = 1;
        uint32_t number = 0;
        int neg = 0;
        int row = 1, col = 1;
        int awaitEOL = 0;
        lineNumber = 1;
        columnNumber = 0;
        for (;;) {
            char c;
            columnNumber++;
            if (cIndex >= nBuf) {
                if (f_read(&fil, cbuf, sizeof cbuf, &nBuf) != FR_OK) {
                    error(STATUS_READ_FAILED);
                    break;
                }
                if (nBuf == 0) {
                    error(STATUS_EOF);
                    break;
                }
                cIndex = 0;
            }
            c = cbuf[cIndex++];
            if ((c == '\n') || (c == ',')) {
                if (!awaitEOL) {
                    if (needNumber) {
                        error(STATUS_CONTENTS_GARBLED);
                        break;
                    }
                    if (row == 1) {
                        if (neg) {
                            error(STATUS_CONTENTS_GARBLED);
                            break;
                        }
                        date = number;
                        awaitEOL = 1;
                    }
                    else {
                        if (col == 1) {
                            if (number > 1000000) {
                                number = 1000000;
                            }
                            ad7768SetOfst((row-2), neg ? -number : number);
                        }
                        else {
                            int gain;
                            /*
                             * Scale from parts-per-million to ADC gain counts
                             *
                             *   PPM     Gain Counts
                             * ------- = -----------
                             * 1000000   (2^24) / 12
                             *
                             * Allow this to be done with 32-bit arithmetic
                             * by removing as many powers of 2 as possible
                             * and limiting range to 16 bits.
                             *     (5^6) = 15625
                             */
                            if (number > 50000) {
                                number = 50000;
                            }
                            gain = (uint32_t)((number << 16) + ((3*15625)/2)) /
                                                                      (3*15625);
                            ad7768SetGain((row-2), neg ? -gain : gain);
                            awaitEOL = 1;
                        }
                    }
                }
                if (c == '\n') {
                    if (row == (1 + ADC_COUNT)) {
                        status = STATUS_VALID;
                        break;
                    }
                    lineNumber++;
                    row++;
                    col = 1;
                    columnNumber = 0;
                    awaitEOL = 0;
                }
                else {
                    col++;
                }
                if (!awaitEOL) {
                    needNumber = 1;
                    inNumber = 0;
                    number = 0;
                    neg = 0;
                    continue;
                }
            }
            if (awaitEOL) {
                continue;
            }
            if ((c == ' ') || (c == '\t') || (c == '\r')) {
                inNumber = 0;
                continue;
            }
            if (c == '-') {
                if (!needNumber || neg) {
                    error(STATUS_BAD_NUMBER);
                    break;
                }
                neg = 1;
                continue;
            }
            if ((c < '0') || (c > '9')) {
                error(STATUS_BAD_CHARACTER);
                break;
            }
            if (!inNumber && !needNumber) {
                error(STATUS_CONTENTS_GARBLED);
                break;
            }
            if ((number > ((UINT32_MAX) / 10))
             || (c > ((UINT32_MAX) - (number * 10)))) {
                error(STATUS_BAD_NUMBER);
                break;
            }
            inNumber = 1;
            needNumber = 0;
            number = (number * 10) + (c - '0');
        }
        f_close(&fil);
    }
    else {
        error(STATUS_OPEN_FAILED);
    }
    ffsUnmount();
    if (debugFlags & DEBUGFLAG_CALIBRATION) {
        printf("Calibration update status %d.\n", status);
    }
    acqSetCalibrationValidity(status == 0);
}

uint32_t
calibrationDate(void)
{
    return date;
}

int
calibrationStatus(void)
{
    if (status == STATUS_VALID) return 0;
    return (status << 16) | lineNumber;
}
