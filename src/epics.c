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
 * Communicate with EPICS IOC
 */
#include <stdio.h>
#include <ospreyUDP.h>
#include "acq.h"
#include "ad7768.h"
#include "amc7823.h"
#include "clockAdjust.h"
#include "downsample.h"
#include "epics.h"
#include "evg.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "iocFPGAprotocol.h"
#include "nasaAcqProtocol.h"
#include "softwareBuildDate.h"
#include "systemParameters.h"
#include "util.h"
#include "xadc.h"

#define CHANNEL_COUNT ((CFG_AD7768_CHIP_COUNT) * (CFG_AD7768_ADC_PER_CHIP))

/*
 * Read system monitors from all subsystems
 */
static int
sysmon(uint32_t *buf)
{
    uint32_t *base = buf;

    *buf++ = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    buf = xadcFetchSysmon(buf);
    buf = iicFPGAfetchSysmon(buf);
    buf = amc7823FetchSysmon(buf);
    buf = acqFetchSysmon(buf);
    buf = clockAdjustFetchSysmon(buf);
    *buf++ = GPIO_READ(GPIO_IDX_AD7768_AUX_STATUS);
    *buf++ = GPIO_READ(GPIO_IDX_PPS_STATUS);
    return buf - base;
}

/*
 * Crank the reboot state machine
 */
static void
crankReboot(int value)
{
    static int match = 1;
    if (value == match) {
        if (match == 10000) {
            resetFPGA(0);
        }
        match *= 100;
    }
    else if (value == 1) {
        match = 100;
    }
    else {
        match = 1;
    }
}

/*
 * Process a command from the IOC
 * Return value is reply argument count, or -1 if no reply is to be sent
 */
static int
processCommand(const struct fpgaIOCpacket *cmd, struct fpgaIOCpacket *reply, int argc)
{
    static int isPowerup = 1;
    switch (cmd->msgID) {
    case FPGA_IOC_MSGID_GENERIC:
        if (argc != 2) {
            return -1;
        }
        switch(cmd->args[0]) {
        case FPGA_IOC_CMD_REBOOT:
            crankReboot(cmd->args[1]);
            return 0;

        case FPGA_IOC_CMD_CLR_POWERUP:
            isPowerup = 0;
            return 0;

        case FPGA_IOC_CMD_ACQ_ENABLE:
            if (isEVG()) {
                evgAcqControl(cmd->args[1]);
                return 0;
            } return -1;

        case FPGA_IOC_CMD_DOWNSAMPLE_RATIO:
            downsampleSetDownsample(cmd->args[1]);
            return 0;

        case FPGA_IOC_CMD_DOWNSAMPLE_ALPHA:
            downsampleSetAlpha(cmd->args[1]);
            return 0;
        }
        if ((cmd->args[0] >= FPGA_IOC_CMD_CHAN_ACTIVE)
         && (cmd->args[0] < (FPGA_IOC_CMD_CHAN_ACTIVE + CHANNEL_COUNT))) {
            acqSetActive(cmd->args[0]-FPGA_IOC_CMD_CHAN_ACTIVE, cmd->args[1]);
            return 0;
        }
        if ((cmd->args[0] >= FPGA_IOC_CMD_CHAN_COUPLING)
         && (cmd->args[0] < (FPGA_IOC_CMD_CHAN_COUPLING + CHANNEL_COUNT))) {
            acqSetCoupling(cmd->args[0]-FPGA_IOC_CMD_CHAN_COUPLING,
                                                                  cmd->args[1]);
            return 0;
        }
        if ((cmd->args[0] >= FPGA_IOC_CMD_CHAN_CALIB_OFST)
         && (cmd->args[0] < (FPGA_IOC_CMD_CHAN_CALIB_OFST + CHANNEL_COUNT))) {
            ad7768SetOfst(cmd->args[0]-FPGA_IOC_CMD_CHAN_CALIB_OFST,
                                                                  cmd->args[1]);
            return 0;
        }
        if ((cmd->args[0] >= FPGA_IOC_CMD_CHAN_CALIB_GAIN)
         && (cmd->args[0] < (FPGA_IOC_CMD_CHAN_CALIB_GAIN + CHANNEL_COUNT))) {
            ad7768SetGain(cmd->args[0]-FPGA_IOC_CMD_CHAN_CALIB_GAIN,
                                                                  cmd->args[1]);
            return 0;
        }
        break;

    case FPGA_IOC_MSGID_READ_SYSMON:
        reply->args[0] = isPowerup;
        return sysmon(&reply->args[1]) + 1;

    case FPGA_IOC_MSGID_GET_BUILD_DATES:
        /*
         * Provide dummy 'nsec' values
         */
        reply->args[0] = GPIO_READ(GPIO_IDX_FIRMWARE_DATE);
        reply->args[1] = 0;
        reply->args[2] = SOFTWARE_BUILD_DATE;
        reply->args[3] = 0;
        return 4;
    }
    return -1;
}

/*
 * Handle an incoming packet
 */
static void
epicsHandler(ospreyUDPendpoint endpoint, uint32_t farAddress, int farPort,
                                                    const char *buf, int length)
{
    int replyArgc = -1;
    int i, n;
    uint32_t *argp;
    struct fpgaIOCpacket *cmdp = (struct fpgaIOCpacket *)buf;
    static struct fpgaIOCpacket reply = { .P='P', .S='S' };

    if (debugFlags & DEBUGFLAG_EPICS) {
        printf("EPICS %d from %u.%u.%u.%u:%d", length,
                                               (farAddress >> 24) & 0xFF,
                                               (farAddress >> 16) & 0xFF,
                                               (farAddress >>  8) & 0xFF,
                                               (farAddress      ) & 0xFF,
                                               farPort);
    }

    /*
     * Ignore packets that are clearly invalid
     */
    if ((length >= FPGA_IOC_ARGC_TO_PACKET_SIZE(0))
     && (length <= FPGA_IOC_ARGC_TO_PACKET_SIZE(FPGA_IOC_ARG_CAPACITY))
     && (cmdp->P == 'P')
     && (cmdp->S == 'S')) {
        n = FPGA_IOC_PACKET_SIZE_TO_ARGC(length);
        cmdp->length = ntohl(cmdp->length);
        if (cmdp->length == FPGA_IOC_ARGC_TO_LENGTH(n)) {
            cmdp->msgID = ntohs(cmdp->msgID);
            for (i = 0, argp = &cmdp->args[0] ; i < n ; i++, argp++) {
                *argp = ntohl(*argp);
            }
            if (debugFlags & DEBUGFLAG_EPICS) {
                int m = (n <= 4) ? n : 4;
                printf(" MSGID:%d", cmdp->msgID);
                for (i = 0 ; i < m ; i++) {
                    printf(" %d", cmdp->args[i]);
                }
            }
            replyArgc = processCommand(cmdp, &reply, n);
        }
    }

    /*
     * Send reply if required
     */
    if (replyArgc >= 0) {
        if (debugFlags & DEBUGFLAG_EPICS) {
            int m = (replyArgc <= 4) ? replyArgc : 4;
            printf(" ->");
            for (i = 0 ; i < m ; i++) {
                printf(" %d", reply.args[i]);
            }
        }
        reply.msgID = htons(cmdp->msgID);
        reply.length = htonl(FPGA_IOC_ARGC_TO_LENGTH(replyArgc));
        for (i = 0, argp = &reply.args[0] ; i < replyArgc ; i++, argp++) {
            *argp = htonl(*argp);
        }
        ospreyUDPsendto(endpoint, farAddress, farPort, (char *)&reply,
                                      FPGA_IOC_ARGC_TO_PACKET_SIZE(replyArgc));
    }
    if (debugFlags & DEBUGFLAG_EPICS) {
        printf("\n");
    }
}

/*
 * Create server
 */
void
epicsInit(void)
{
    if (ospreyUDPregisterEndpoint(NASA_ACQ_UDP_PORT, epicsHandler) == NULL) {
        printf("Can't register EPICS I/O UDP endpoint!\n");
    }
}
