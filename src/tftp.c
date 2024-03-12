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
 * Trivial File Transfer Protocol Server (RFC 1350)
 * This implementation accepts block numbers that roll over to 0 or to 1. 
 */
#include <stdio.h>
#include <string.h>
#include <ospreyUDP.h>
#include "ffs.h"
#include "tftp.h"

#define TFTP_PORT 69

#define TFTP_BLOCKSIZE  512

#define TFTP_OPCODE_RRQ   1
#define TFTP_OPCODE_WRQ   2
#define TFTP_OPCODE_DATA  3
#define TFTP_OPCODE_ACK   4
#define TFTP_OPCODE_ERROR 5

#define TFTP_ERROR_ACCESS_VIOLATION 2

static int debugFlag = 0;
static uint16_t xbuf[2 + (TFTP_BLOCKSIZE / sizeof(uint16_t))];
#define htons(x) __builtin_bswap16(x)
#define ntohs(x) __builtin_bswap16(x)

/*
 * Send error reply
 */
static void
replyERR(ospreyUDPendpoint endpoint, uint32_t fromAddr, uint16_t fromPort,
                                                                const char *msg)
{
    int l = (2 * sizeof (uint16_t)) + strlen(msg) + 1;
    if (debugFlag) {
        xil_printf("Reply error -- %s\r\n", msg);
    }
    xbuf[0] = htons(TFTP_OPCODE_ERROR);
    xbuf[1] = htons(TFTP_ERROR_ACCESS_VIOLATION);
    strcpy((char *)&xbuf[2], msg);
    ospreyUDPsendto(endpoint, fromAddr, fromPort, (char *)xbuf, l);
}

/*
 * Send success reply
 */
static void
replyACK(ospreyUDPendpoint endpoint, uint32_t fromAddr, uint16_t fromPort,
                                                                      int block)
{
    int l = 2 * sizeof (uint16_t);
    xbuf[0] = htons(TFTP_OPCODE_ACK);
    xbuf[1] = htons(block);
    ospreyUDPsendto(endpoint, fromAddr, fromPort, (char *)xbuf, l);
}

/*
 * Send data packet
 */
static int
sendBlock(ospreyUDPendpoint endpoint, int32_t fromAddr, uint16_t fromPort,
                                                             int block, FIL *fp)
{
    int n;
    unsigned int l;
    static int prevCount;

    if (fp == NULL) {
        n = prevCount;
    }
    else {
        UINT nRead;
        FRESULT fr = f_read(fp, &xbuf[2], TFTP_BLOCKSIZE, &nRead);
        if (fr != FR_OK) {
            replyERR(endpoint, fromAddr, fromPort, ffsErrorString(fr));
            return 0;
        }
        n = nRead;
    }
    prevCount = n;
    l = (2 * sizeof(uint16_t)) + n;
    xbuf[0] = htons(TFTP_OPCODE_DATA);
    xbuf[1] = htons(block);
    ospreyUDPsendto(endpoint, fromAddr, fromPort, (char *)xbuf, l);
    return n;
}

/*
 * Handle an incoming packet
 */
static void
tftpHandler(ospreyUDPendpoint endpoint, uint32_t fromAddr, int fromPort,
                                                   const char *cbuf, int length)
{
    uint8_t *cp = (uint8_t *)cbuf;
    int opcode;
    int ackBlock = -1;
    static uint16_t prevBlock;
    static int prevSend;
    FRESULT fr;
    static FIL fil, *fp;

    if (debugFlag) {
        xil_printf("TFTP %3d from %d.%d.%d.%d:%d  %02X%02X %02X%02X\r\n",
                                                 length,
                                                 (int)((fromAddr >> 24) & 0xFF),
                                                 (int)((fromAddr >> 16) & 0xFF),
                                                 (int)((fromAddr >>  8) & 0xFF),
                                                 (int)((fromAddr      ) & 0xFF),
                                                 fromPort,
                                                 cp[0], cp[1], cp[2], cp[3]);
    }

    /*
     * Ignore packets that are a bad size or have obviously bad opcodes
     */
    if ((length < 4) || (length > sizeof xbuf) || (cp[0] != 0)) {
        return;
    }
    opcode = cp[1];
    if ((opcode == TFTP_OPCODE_RRQ)
     || (opcode == TFTP_OPCODE_WRQ)) {
        char *name = (char *)cp + 2, *mode = NULL;
        int nullCount = 0, i = 2;
        prevBlock = 0;
        while (i < length) {
            if (cp[i++] == '\0') {
                nullCount++;
                if (nullCount == 1)
                    mode = (char *)cp + i;
                if (nullCount == 2) {
                    if (debugFlag)
                        xil_printf("NAME:%s  MODE:%s\r\n", name, mode);
                    if (strcasecmp(mode, "octet") != 0) {
                        replyERR(endpoint, fromAddr, fromPort, "Bad Type");
                    }
                    else {
                        if (fp) {
                            f_close(fp);
                            fp = NULL;
                        }
                        if (ffsCheckMount()) {
                            fr = f_open(&fil, name, (opcode==TFTP_OPCODE_RRQ) ?
                                                   FA_READ :
                                                   FA_WRITE | FA_CREATE_ALWAYS);
                            if (fr == FR_OK) {
                                ackBlock = 0;
                                fp = &fil;
                            }
                            else {
                                const char *msg = ffsErrorString(fr);
                                replyERR(endpoint, fromAddr, fromPort, msg);
                            }
                        }
                        else {
                            replyERR(endpoint, fromAddr, fromPort, "No card");
                        }
                    }
                    break;
                }
            }
        }
        if ((ackBlock == 0) && (opcode == TFTP_OPCODE_RRQ)) {
            ackBlock = -1;
            prevBlock = 1;
            prevSend = sendBlock(endpoint, fromAddr, fromPort, prevBlock, fp);
            if (prevSend != TFTP_BLOCKSIZE) {
                f_close(fp);
                fp = NULL;
            }
        }
    }
    else if (opcode == TFTP_OPCODE_DATA) {
        int block = (cp[2] << 8) | cp[3];
        if (block == prevBlock) {
            ackBlock = block;
        }
        else if ((block == (prevBlock + 1))
              || ((prevBlock == 65535) && ((block == 0) || (block == 1)))) {
            int nBytes = length - (2 * sizeof(uint16_t));
            prevBlock = block;
            ackBlock = block;
            if (nBytes > 0) {
                UINT nWritten;
                fr = f_write(fp, (char *)(cp+4), nBytes, &nWritten);
                if ((fr != FR_OK) || (nWritten != nBytes)) {
                    ackBlock = -1;
                    replyERR(endpoint, fromAddr, fromPort, ffsErrorString(fr));
                }
            }
            if (fp && (nBytes < TFTP_BLOCKSIZE)) { 
                fr = f_close(fp);
                ffsUnmount();
                fp = NULL;
                if (fr != FR_OK) {
                    ackBlock = -1;
                    replyERR(endpoint, fromAddr, fromPort, ffsErrorString(fr));
                }
            }
        }
    }
    else if (opcode == TFTP_OPCODE_ACK) {
        int block = (cp[2] << 8) | cp[3];
        if (block == prevBlock) {
            if (fp != NULL) {
                prevBlock++;
                prevSend=sendBlock(endpoint, fromAddr, fromPort, prevBlock, fp);
                if (prevSend != TFTP_BLOCKSIZE) {
                    f_close(fp);
                    fp = NULL;
                }
            }
        }
        else {
            prevSend=sendBlock(endpoint,fromAddr,fromPort,prevBlock,NULL);
        }
    }
    if (ackBlock >= 0) {
        replyACK(endpoint, fromAddr, fromPort, ackBlock);
    }
}

/*
 * Control diagnostic messages
 */
void
tftpSetVerbose(int verboseFlag)
{
    debugFlag = (verboseFlag != 0);
}

/*
 * Create server
 */
void
tftpInit(void)
{
    if (ospreyUDPregisterEndpoint(TFTP_PORT, tftpHandler) == NULL) {
        printf("Can't register TFDTP UDP!\n");
    }
}
