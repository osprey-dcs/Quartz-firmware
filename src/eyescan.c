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
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
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
 * Perform a GTX transceiver eye scan
 *
 * This code is based on the example provided in Xilinx application note
 * XAPP743, "Eye Scan with MicroBlaze Processor MCS Application Note".
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "eyescan.h"
#include "gpio.h"
#include "mgt.h"
#include "util.h"

/*
 * Prescale sample counter
 * Sample count saturates at (2^16-1) * (2^(1+ES_PRESCALE)) samples
 * Two acquistion sequences at each point, so number of samples per point are:
 *     Fast: (2^16-1) * 2^(1+1) * 2 =    524,280
 *     Slow: (2^16-1) * 2^(1+6) * 2 = 16,776,960
 * At a line rate of 6.25 Gb/s (6.4 ns per sample) a slow acquisition
 * takes about 107 milliseconds at each point.
 */
#define ES_PRESCALE_FAST    1
#define ES_PRESCALE_SLOW    6

#if EYESCAN_TRANSCEIVER_WIDTH == 40
# define DRP_REG_ES_SDATA_MASK0_VALUE   0x0000
# define DRP_REG_ES_SDATA_MASK1_VALUE   0x0000
#elif EYESCAN_TRANSCEIVER_WIDTH == 20
# define DRP_REG_ES_SDATA_MASK0_VALUE   0xFFFF
# define DRP_REG_ES_SDATA_MASK1_VALUE   0x000F
#else
# error "Invalid EYESCAN_TRANSCEIVER_WIDTH value"
#endif

/*
 * Plot size
 */
#define HSTEPS_PER_QUADRANT 32
#define VRANGE              128
#define VSTEPS_PER_QUADRANT 16
#define VSTRIDE             (VRANGE / VSTEPS_PER_QUADRANT)

/*
 * Special 'mgt' indices
 */
#define MGT_IDX_STEP    -1
#define MGT_IDX_CANCEL  -2

#define DRP_REG_ES_QUAL_MASK0     0x031
#define DRP_REG_ES_QUAL_MASK1     0x032
#define DRP_REG_ES_QUAL_MASK2     0x033
#define DRP_REG_ES_QUAL_MASK3     0x034
#define DRP_REG_ES_QUAL_MASK4     0x035
#define DRP_REG_ES_SDATA_MASK0    0x036
#define DRP_REG_ES_SDATA_MASK1    0x037
#define DRP_REG_ES_SDATA_MASK2    0x038
#define DRP_REG_ES_SDATA_MASK3    0x039
#define DRP_REG_ES_SDATA_MASK4    0x03A
#define DRP_REG_ES_PS_VOFF        0x03B
#define DRP_REG_ES_HORZ_OFFSET    0x03C
#define DRP_REG_ES_CSR            0x03D
#define DRP_REG_ES_ERROR_COUNT    0x14F
#define DRP_REG_ES_SAMPLE_COUNT   0x150
#define DRP_REG_ES_STATUS         0x151
#define DRP_REG_PMA_RSV2          0x082
#define DRP_REG_TXOUT_RXOUT_DIV   0x088

#define ES_CSR_CONTROL_RUN      0x01
#define ES_CSR_CONTROL_ARM      0x02
#define ES_CSR_CONTROL_TRIG0    0x04
#define ES_CSR_CONTROL_TRIG1    0x08
#define ES_CSR_CONTROL_TRIG2    0x10
#define ES_CSR_CONTROL_TRIG3    0x20
#define ES_CSR_EYE_SCAN_EN      0x100
#define ES_CSR_ERRDET_EN        0x200

#define ES_STATUS_DONE          0x1
#define ES_STATUS_STATE_MASK    0xE
#define ES_STATUS_STATE_WAIT    0x0
#define ES_STATUS_STATE_RESET   0x2
#define ES_STATUS_STATE_END     0x4
#define ES_STATUS_STATE_COUNT   0x6
#define ES_STATUS_STATE_READ    0x8
#define ES_STATUS_STATE_ARMED   0xA

#define ES_PS_VOFF_PRESCALE_MASK  0xF800
#define ES_PS_VOFF_PRESCALE_SHIFT 11
#define ES_PS_VOFF_VOFFSET_MASK   0x1FF

static enum eyescanFormat {
    FMT_ASCII_ART,
    FMT_NUMERIC,
    FMT_RAW
} eyescanFormat;
static const char *mgtNames[] = EYESCAN_CHANNEL_NAMES;
#define EYESCAN_CHANNEL_COUNT (sizeof mgtNames / sizeof mgtNames[0])

static void
drpRMW(int mgtIndex, int drpAddress, int mask, int bits)
{
    int r;
    r = mgtDRPread(mgtIndex, drpAddress);
    if (r < 0) return;
    r = (r & ~mask) | (bits & mask);
    mgtDRPwrite(mgtIndex, drpAddress, r);
}

static void
drpSET(int mgtIndex, int drpAddress, int bits)
{
    drpRMW(mgtIndex, drpAddress, bits, bits);
}

static void
drpCLR(int mgtIndex, int drpAddress, int bits)
{
    drpRMW(mgtIndex, drpAddress, bits, 0);
}

static void
drpShowReg(uint32_t mgt, const char *msg)
{
    int i;
    static const uint16_t regMap[] = {
        DRP_REG_ES_QUAL_MASK0,  DRP_REG_ES_QUAL_MASK1,  DRP_REG_ES_QUAL_MASK2,
        DRP_REG_ES_QUAL_MASK3,  DRP_REG_ES_QUAL_MASK4,  DRP_REG_ES_SDATA_MASK0,
        DRP_REG_ES_SDATA_MASK1, DRP_REG_ES_SDATA_MASK2, DRP_REG_ES_SDATA_MASK3,
        DRP_REG_ES_SDATA_MASK4, DRP_REG_ES_PS_VOFF,     DRP_REG_ES_HORZ_OFFSET,
        DRP_REG_ES_CSR,         DRP_REG_ES_ERROR_COUNT, DRP_REG_ES_SAMPLE_COUNT,
        DRP_REG_ES_STATUS, DRP_REG_PMA_RSV2, DRP_REG_TXOUT_RXOUT_DIV };
    printf("\nEYE SCAN REGISTERS AT %d (%s):\n", mgt, msg);
    for (i = 0 ; i < (sizeof regMap / sizeof regMap[0]) ; i++) {
        int reg = mgtDRPread(mgt, regMap[i]);
        if (reg < 0) {
            printf("  %03X: <DRP lockup>\n", regMap[i]);
        }
        else {
            printf("  %03X: %04X\n", regMap[i], reg);
        }
    }
}

/*
 * Eye scan initialization may change the value of PMA_RSV2[5].
 * This means that a subsequent PMA reset is required.
 */
void
eyescanInit(void)
{
    int mgt, r;

    for (mgt = 0 ; mgt < EYESCAN_CHANNEL_COUNT ; mgt++) {
        /* Enable eye scan if necessary. PMA_RSV2[5] */
        if ((mgtDRPread(mgt, DRP_REG_PMA_RSV2) & (1U << 5)) == 0) {
            drpSET(mgt, DRP_REG_PMA_RSV2, 1U << 5);
        }

        /* Enable statistical eye scan */
        drpSET(mgt, DRP_REG_ES_CSR, ES_CSR_EYE_SCAN_EN | ES_CSR_ERRDET_EN);

        /* Enable all bits in ES_QUAL_MASK (count all bits) */
        for (r = DRP_REG_ES_QUAL_MASK0 ; r <= DRP_REG_ES_QUAL_MASK4 ; r++) {
            mgtDRPwrite(mgt, r, 0xFFFF);
        }

        /* Set 80 bit ES_SDATA_MASK to check 40 or 20 bit data */
        mgtDRPwrite(mgt, DRP_REG_ES_SDATA_MASK0, DRP_REG_ES_SDATA_MASK0_VALUE);
        mgtDRPwrite(mgt, DRP_REG_ES_SDATA_MASK1, DRP_REG_ES_SDATA_MASK1_VALUE);
        mgtDRPwrite(mgt, DRP_REG_ES_SDATA_MASK2, 0xFF00);
        mgtDRPwrite(mgt, DRP_REG_ES_SDATA_MASK3, 0xFFFF);
        mgtDRPwrite(mgt, DRP_REG_ES_SDATA_MASK4, 0xFFFF);
    }
}

static void
hBorder(int mgt)
{
    int i, j;
    const char *name = NULL;
    int nameLen = 0;
    if ((unsigned int)mgt < EYESCAN_CHANNEL_COUNT) {
        name = mgtNames[mgt];
        nameLen = strlen(name);
    }
    for (i = 0 ; i < 2 ; i++) {
        printf("+");
        for (j = 0 ; j < HSTEPS_PER_QUADRANT ; j++) {
            char c = '-';
            if ((i == 0) && (j >= 3) && (j < (nameLen + 3))) {
                c = name[j-3];
            }
            printf("%c", c);
        }
    }
    printf("+\n");
}

/*
 * Map log2err(errorCount) onto grey scale or alphanumberic value.
 * Special cases for 0 which is the only value that maps to ' ' and for
 * full scale error (131070) which is the only value that maps to '@'.
 */
static int
plotChar(int errorCount)
{
    int i, c;

    if (errorCount <= 0)           c = ' ';
    else if (errorCount >= 131070) c = '@';
    else {
        int log2err = 31 - __builtin_clz(errorCount);
        if (eyescanFormat == FMT_NUMERIC) {
            c = (log2err <= 9) ? '0' + log2err : 'A' - 10 + log2err;
        }
        else {
            i = 1 + ((log2err * 8) / 18);
            c = " .:-=?*#%@"[i];
        }
    }
    return c;
}

static int
eyescanStep(int mgt)
{
    static int eyescanActive, eyescanAcquiring, eyescanMGT;
    static int hRange, hStride;
    static int hOffset, vOffset, utFlag;
    static int errorCount;
    static uint32_t whenStarted;

    if ((mgt >= 0) && !eyescanActive) {
        hRange = 32 << (mgtDRPread(mgt, DRP_REG_TXOUT_RXOUT_DIV) & 0x7);
        hStride = hRange / HSTEPS_PER_QUADRANT;
        hOffset = -hRange;
        vOffset = VRANGE;
        utFlag = 0;
        errorCount = 0;
        eyescanMGT = mgt;
        eyescanAcquiring = 0;
        eyescanActive = 1;
        hBorder(mgt);
        return 1;
    }
    if (eyescanActive) {
        if (mgt == MGT_IDX_CANCEL) {
            drpCLR(eyescanMGT, DRP_REG_ES_CSR, ES_CSR_CONTROL_RUN);
            printf("\n");
            eyescanActive = 0;
            return 0;
        }
        if (eyescanAcquiring) {
            int status = mgtDRPread(eyescanMGT, DRP_REG_ES_STATUS);
            if ((status & ES_STATUS_DONE)
             || ((microsecondsSinceBoot() - whenStarted) > 20000000)) {
                drpCLR(eyescanMGT, DRP_REG_ES_CSR, ES_CSR_CONTROL_RUN);
                eyescanAcquiring = 0;
                if (status == (ES_STATUS_STATE_END | ES_STATUS_DONE)) {
                    char border = vOffset == 0 ? '+' : '|';
                    errorCount += mgtDRPread(eyescanMGT, DRP_REG_ES_ERROR_COUNT);
                    utFlag = !utFlag;
                    if (!utFlag) {
                        if (eyescanFormat == FMT_RAW) {
                            printf(" %6d", errorCount);
                            border = ' ';
                        }
                        else {
                            char c;
                            if (hOffset == -hRange) {
                                printf("%c", border);
                            }
                            if ((errorCount==0) && (hOffset==0) && (vOffset==0))
                                c = '+';
                            else
                                c = plotChar(errorCount);
                            printf("%c", c);
                        }
                        errorCount = 0;
                        hOffset += hStride;
                        if (hOffset > hRange) {
                            if (eyescanFormat != FMT_RAW) {
                                printf("%c", border);
                            }
                            printf("\n");
                            hOffset = -hRange;
                            vOffset -= VSTRIDE;
                        }
                    }
                }
                else {
                    printf("\nScan failure -- status:%04X", status);
                    drpShowReg(eyescanMGT, "SCAN FAILURE");
                    eyescanActive = 0;
                }
            }
        }
        else if (vOffset < -VRANGE) {
            hBorder(mgt);
            eyescanActive = 0;
        }
        else {
            int vSign, vAbs;
            if (vOffset < 0) {
                vAbs = -vOffset;
                vSign = 1 << 7;
            }
            else {
                vAbs = vOffset;
                vSign = 0;
            }
            if (vAbs > 127) vAbs = 127;
            drpRMW(eyescanMGT, DRP_REG_ES_PS_VOFF, ES_PS_VOFF_VOFFSET_MASK,
                                        (utFlag ? (1 << 8) : 0) | vSign | vAbs);
            mgtDRPwrite(eyescanMGT, DRP_REG_ES_HORZ_OFFSET, hOffset & 0xFFF);
            drpSET(eyescanMGT, DRP_REG_ES_CSR, ES_CSR_CONTROL_RUN);
            whenStarted = microsecondsSinceBoot();
            eyescanAcquiring = 1;
        }
    }
    return eyescanActive;
}

int
eyescanCrank(int cancel)
{
    int active;
    static int loopMGT = -1;
    if (cancel < 0) {
        loopMGT = 0;
        return 0;
    }
    active = eyescanStep(cancel ? MGT_IDX_CANCEL : MGT_IDX_STEP);
    if (!active && (loopMGT >= 0)) {
        if (cancel || (loopMGT == (EYESCAN_CHANNEL_COUNT - 1))) {
            loopMGT = -1;
        }
        else {
            active = eyescanStep(++loopMGT);
        }
    }
    return active;
}

void
eyescanCommand(int argc, char **argv)
{
    int i;
    enum eyescanFormat format = FMT_ASCII_ART;
    int mgt = 0;
    int prescale = ES_PRESCALE_FAST;
    int dumpRegisters = 0;

    for (i = 1 ; i < argc ; i++) {
        if (argv[i][0] == '-') {
            const char *cp = argv[i];
            do {
                switch (*++cp) {
                case 'd': dumpRegisters = 1;            break;
                case 'n': format = FMT_NUMERIC;         break;
                case 'r': format = FMT_RAW;             break;
                case 's': prescale = ES_PRESCALE_SLOW;  break;
                default:  printf("Invalid option\n");   return;
                }
            } while (cp[1] != '\0');
        }
        else {
            int c;
            if (strcmp(argv[i], "*") == 0) {
                mgt = 0;
                eyescanCrank(-1);
                break;
            }
            for (c = 0 ; ; c++) {
                if (c == EYESCAN_CHANNEL_COUNT) {
                    printf("Invalid MGT argument\n");
                    return;
                }
                if (strcasecmp(argv[i], mgtNames[c]) == 0) {
                    mgt = c;
                    break;
                }
            }
        }
    }
    if (dumpRegisters) {
        drpShowReg(mgt, mgtNames[mgt]);
        return;
    }
    drpRMW(mgt, DRP_REG_ES_PS_VOFF, ES_PS_VOFF_PRESCALE_MASK,
                                         prescale << ES_PS_VOFF_PRESCALE_SHIFT);
    eyescanFormat = format;
    eyescanStep(mgt);
    return;
}
