/*
 * MIT License
 *
 * Copyright (c) 2021 Osprey DCS
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
 * Simple MODBUS server
 */

/*
 * Packet/Frame format
 * Multi-byte values are big-endian.
 * Length Value     Description
 *    2   Nonce     Echoed to allow client to identify response.
 *    2   Protocol  Must be 0.
 *    2   Size      Number of remaining bytes, including address and function.
 *    1   Unit      Slave address (ignored, but echoed).
 *    1   Function  MODBUS function code (this server supports 3, 6 and 16).
 *    n             Data
 */

#include <stdio.h>
#include <ospreyUDP.h>
#include "modbusServer.h"

#define MODBUS_DEFAULT_UDP_PORT 502

#define MAX_REGCOUNT    127

#define FC_READ_HOLDING_REGISTERS            3
#define FC_WRITE_SINGLE_HOLDING_REGISTER     6
#define FC_WRITE_MULTIPLE_HOLDING_REGISTERS 16

#define U8COUNT_TO_PKSIZE(d)   ((d)+8)
#define PKSIZE_TO_HSIZE(p)     ((p)-6)

static int (*diagOut)(const char *fmt, ...);
static uint8_t replyBuf[8+2+(MAX_REGCOUNT*2)];

void
modbusServerSetDebugFunction(int (*prfunc)(const char *fmt, ...))
{
    diagOut = prfunc;
}

static int
replyEcho4(const uint8_t *cmd)
{
    replyBuf[7] = cmd[7];
    replyBuf[8] = cmd[8];
    replyBuf[9] = cmd[9];
    replyBuf[10] = cmd[10];
    replyBuf[11] = cmd[11];
    return 12;
}

static int
replyError(const uint8_t *cmd, int errorCode)
{
    replyBuf[7] = 0x80 | cmd[7];
    replyBuf[8] = errorCode;
    return 9;
}

static int
replyData(const uint8_t *cmd, uint16_t *regp)
{
    int regCount = cmd[11]; /* regCount known to be <= MAX_REGCOUNT */
    uint16_t *endp = regp + regCount;
    int j = 9;
    replyBuf[7] = cmd[7];
    replyBuf[8] = regCount * 2;
    while (regp != endp) {
        int r = *regp++;
        replyBuf[j++] = r >> 8;
        replyBuf[j++] = r;
    }
    return j;
}

static void
modbusCallback(ospreyUDPendpoint endpoint, uint32_t farAddress, int farPort,
                                           const char *buf, int length)
{
    const uint8_t *cmd = (const uint8_t *)buf;
    static int replyLen;

    if (diagOut) {
        (*diagOut)("modbusCallback: %d far %d.%d.%d.%d:%d\r\n",
                                               length,
                                               (int)((farAddress >> 24) & 0xFF),
                                               (int)((farAddress >> 16) & 0xFF),
                                               (int)((farAddress >>  8) & 0xFF),
                                               (int)((farAddress      ) & 0xFF),
                                               farPort);
    }
    if ((length >= U8COUNT_TO_PKSIZE(3))
     && (cmd[2] == '\0')
     && (cmd[3] == '\0')
     && (((cmd[4]<<8) | cmd[5]) == PKSIZE_TO_HSIZE(length))) {
        if ((replyLen == 0)
         || (cmd[0] != replyBuf[0])
         || (cmd[1] != replyBuf[1])) {
            uint16_t *regp = (uint16_t *)&replyBuf[10];
            int hSize;
            replyLen = 0;
            if (diagOut) {
                 (*diagOut)("modbusCallback: Transaction ID:%d  Function:%d\r\n",
                                                (cmd[0] << 8) | cmd[1], cmd[7]);
            }
            switch(cmd[7]) {
            case FC_READ_HOLDING_REGISTERS:
                if (length == U8COUNT_TO_PKSIZE(4)) {
                    int regBase = (cmd[8] << 8) | cmd[9];
                    int regCount = (cmd[10] << 8) | cmd[11];
                    if ((regCount != 0) && (regCount <= MAX_REGCOUNT)) {
                        if (modbusServerCallbackCode3(regBase, regCount, regp) == 0)
                            replyLen = replyData(cmd, regp);
                        else
                            replyLen = replyError(cmd, MODBUS_EXCEPTION_ILLEGAL_ADDRESS);
                    }
                }
                break;

            case FC_WRITE_SINGLE_HOLDING_REGISTER:
                if (length == U8COUNT_TO_PKSIZE(4)) {
                    int regNum = (cmd[8] << 8) | cmd[9];
                    regp[0] = (cmd[10] << 8) | cmd[11];
                    if (modbusServerCallbackCode16(regNum, 1, regp) == 0)
                        replyLen = replyEcho4(cmd);
                    else
                        replyLen = replyError(cmd, MODBUS_EXCEPTION_ILLEGAL_ADDRESS);
                }
                break;

            case FC_WRITE_MULTIPLE_HOLDING_REGISTERS:
                if (length >= U8COUNT_TO_PKSIZE(7)) {
                    int regBase = (cmd[8] << 8) | cmd[9];
                    int regCount = (cmd[10] << 8) | cmd[11];
                    int bCount = cmd[12];
                    if ((length == U8COUNT_TO_PKSIZE(5 + bCount))
                     && (regCount <= MAX_REGCOUNT)
                     && (bCount == (regCount * 2))) {
                        int i, j;
                        for (i = 0, j = 13 ; i < regCount ; i++) {
                            int r;
                            r = cmd[j++] << 8;
                            r |= cmd[j++];
                            regp[i] = r;
                        }
                        if (modbusServerCallbackCode16(regBase, regCount, regp) == 0)
                            replyLen = replyEcho4(cmd);
                        else
                            replyLen = replyError(cmd, MODBUS_EXCEPTION_ILLEGAL_ADDRESS);
                    }
                    else {
                        replyLen = replyError(cmd, MODBUS_EXCEPTION_ILLEGAL_ADDRESS);
                    }
                }
                break;

            default:
                replyLen = replyError(cmd, MODBUS_EXCEPTION_ILLEGAL_FUNCTION);
                break;
            }
            hSize = PKSIZE_TO_HSIZE(replyLen);
            replyBuf[0] = cmd[0];
            replyBuf[1] = cmd[1];
            replyBuf[2] = 0;
            replyBuf[3] = 0;
            replyBuf[4] = hSize >> 8;
            replyBuf[5] = hSize;
            replyBuf[6] = cmd[6];
        }
        if (replyLen) {
            if (diagOut) {
                 (*diagOut)("modbusCallback: Reply %d.\r\n", replyLen);
            }
            ospreyUDPsendto(endpoint, farAddress, farPort, (char *)replyBuf, replyLen);
        }
    }
}

int
modbusServerUDPinit(int port)
{
    if (port <= 0) port = MODBUS_DEFAULT_UDP_PORT;
    return (ospreyUDPregisterEndpoint(port, modbusCallback) == NULL) ? -1 : 0;
}
