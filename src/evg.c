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
 * Event generator time source (NTP client)
 */
#include <stdio.h>
#include <ospreyUDP.h>
#include "evg.h"
#include "gpio.h"
#include "systemParameters.h"
#include "util.h"

#define CSR_R_PPS_TOGGLE        0x80000000
#define CSR_R_EVG_ACTIVE        0x4
#define CSR_R_SECONDS_VALID     0x2
#define CSR_R_PPS_VALID         0x1

#define PPS_CSR_PMOD_COS        0x200
#define PPS_CSR_QUARTZ_COS      0x100
#define PPS_CSR_USE_PMOD        0x8
#define PPS_CSR_PMOD_VALID      0x4
#define PPS_CSR_QUARTZ_VALID    0x2
#define PPS_CSR_USE_QUARTZ      0x1

#define ACQ_CSR_RW_ENABLE       0x1

#define STARTUP_PAUSE (4 * 1000000)

#define NTP_POSIX_OFFSET 2208988800UL /* 1970 - 1900 in seconds */
#define NTP_PORT 123

/*
 * NTP packet
 * Use 8 bit arrays for multi-byte values to avoid endian issues
 */
#define NTP_FLAGS_LI_MASK       0xC0
#define NTP_FLAGS_LI_SHIFT      6
#define NTP_FLAGS_VERSION_MASK  0x38
#define NTP_FLAGS_VERSION_SHIFT 3
#define NTP_FLAGS_MODE_MASK     0x07
#define NTP_FLAGS_MODE_SHIFT    0
#define NTP_VERSION_3           (3 << NTP_FLAGS_VERSION_SHIFT)
#define NTP_MODE_CLIENT         (3 << NTP_FLAGS_MODE_SHIFT)
typedef struct ntpTimestamp {
    uint8_t secondsSinceEpoch[4];
    uint8_t fraction[4];
} ntpTimestamp;
struct ntpPacket {
    uint8_t      flags;
    uint8_t      stratum;
    uint8_t      poll;
    int8_t       precision;
    uint8_t      rootDelay[4];
    uint8_t      rootDispersion[4];
    uint8_t      referenceClockIdentifier[4];
    ntpTimestamp referenceTimestamp;
    ntpTimestamp originateTimestamp;
    ntpTimestamp receiveTimestamp;
    ntpTimestamp transmitTimestamp;
};

struct evgTime {
    uint32_t posixSeconds;
    uint32_t fraction;
};
static struct evgTime evgTime;
static uint32_t usecWhenQueried;
static ospreyUDPendpoint endpoint;

static void
ntpToEVG(struct evgTime *evgt, ntpTimestamp *t)
{
    evgt->posixSeconds = ((t->secondsSinceEpoch[0] << 24) |
                          (t->secondsSinceEpoch[1] << 16) |
                          (t->secondsSinceEpoch[2] <<  8) |
                           t->secondsSinceEpoch[3]) - NTP_POSIX_OFFSET;
    evgt->fraction = (t->fraction[0] << 24) |
                     (t->fraction[1] << 16) |
                     (t->fraction[2] <<  8) |
                      t->fraction[3];
}

static void
showTimestamp(const char *name, ntpTimestamp *t)
{
    struct evgTime evg;
    ntpToEVG(&evg, t);
    printf("%10s: %u %u\n", name, evg.posixSeconds, evg.fraction);
}

static void
showPacket(struct ntpPacket *ntp)
{
    printf("LI:%d VERS:%d MODE:%d STRATUM:%d POLL:%d PRECISION:%d\n",
                     ntp->flags >> 6, (ntp->flags >> 3) & 0x7, ntp->flags & 0x7,
                     ntp->stratum, ntp->poll, ntp->precision);
    showTimestamp("Reference", &ntp->referenceTimestamp);
    showTimestamp("Originate", &ntp->originateTimestamp);
    showTimestamp("Receive", &ntp->receiveTimestamp);
    showTimestamp("Transmit", &ntp->transmitTimestamp);
}

static void
callback(ospreyUDPendpoint endpoint, uint32_t farAddress, int farPort,
                                                    const char *buf, int length)
{
    struct ntpPacket *ntp = (struct ntpPacket *)buf;
    uint32_t interval = microsecondsSinceBoot() - usecWhenQueried;
    if ((length >= sizeof(*ntp))
     && (evgTime.posixSeconds == 0)) {
        if (interval > 100000) {
            printf("NTP round trip %u us\n", interval);
        }
        ntpToEVG(&evgTime, &ntp->transmitTimestamp);
    }
    if (debugFlags & DEBUGFLAG_EVG) {
        printf("Received NTP %d, %u us\n", length, interval);
        if (length >= sizeof(*ntp)) {
            showPacket(ntp);
        }
    }
}

static struct ntpPacket query;
void
ntpQuery(void)
{
    uint32_t secondsSinceBoot = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    evgTime.posixSeconds = 0;
    query.flags   = NTP_VERSION_3 | NTP_MODE_CLIENT,
    query.stratum = 16, /* Unsynchronized */
    query.poll    = 3,  /* 8 second interval */
    query.originateTimestamp.secondsSinceEpoch[0] = secondsSinceBoot>>24;
    query.originateTimestamp.secondsSinceEpoch[1] = secondsSinceBoot>>16;
    query.originateTimestamp.secondsSinceEpoch[2] = secondsSinceBoot>>8;
    query.originateTimestamp.secondsSinceEpoch[3] = secondsSinceBoot;
    usecWhenQueried = microsecondsSinceBoot();
    ospreyUDPsendto(endpoint, systemParameters.ntpServer, NTP_PORT,
                                                   (char*)&query, sizeof query);
}

/*
 * Event generator state machine
 */
static enum evgState {
    evgStart,
    evgDelay,
    evgAwaitPPS,
    evgAwaitNTP,
    evgPause,
    evgSynced,
    evgBeginResync } evgState = evgStart;

void
evgInit(void)
{
    uint32_t then;
    if (systemParameters.ntpServer == 0) {
        printf("NTP Server not specified -- event generator disabled.\n");
        return;
    }
    endpoint = ospreyUDPregisterEndpoint(NTP_PORT, callback);
    if (endpoint == NULL) {
        printf("CRITICAL WARNING -- CAN'T CREATE NTP CLIENT!\n");
    }

    /*
     * Indicate that this is an EVG node
     */
    GPIO_WRITE(GPIO_IDX_EVG_CSR, 0);

    /*
     * See if HW PPS marker is present
     */
    then = microsecondsSinceBoot();
    for (;;) {
        uint32_t csr = GPIO_READ(GPIO_IDX_PPS_STATUS);
        if ((csr & (PPS_CSR_USE_PMOD | PPS_CSR_USE_QUARTZ)) != 0) {
            break;
        }
        if ((microsecondsSinceBoot() - then) > 4000000) {
            printf("CRITICAL WARNING -- NO HARDWARE PPS.\n");
            break;
        }
    }

    /*
     * Clear change-of-state status
     */
    GPIO_WRITE(GPIO_IDX_PPS_STATUS, PPS_CSR_QUARTZ_COS | PPS_CSR_PMOD_COS);
    evgShow();
}

void
evgAcqControl(int enable)
{
    GPIO_WRITE(GPIO_IDX_EVG_ACQ_CSR, enable ?  ACQ_CSR_RW_ENABLE : 0);
}

void
evgResync(void)
{
    evgState = evgBeginResync;
}

int
evgStatus(void)
{
    return (evgState << 16) | (GPIO_READ(GPIO_IDX_EVG_CSR) & 0xFFFF);
}

void
evgCrank(void)
{
    uint32_t csr = GPIO_READ(GPIO_IDX_EVG_CSR);
    enum evgState oldState = evgState;
    static uint32_t csrOld;
    static uint32_t then;
    static int beenHere, subsequentPPScheck, reportedMissingPPS;

    if (endpoint == NULL) return;
    if (!beenHere) {
        csrOld = csr;
        beenHere = 1;
    }
    switch (evgState) {
    case evgStart:
        // Issue an an initial query to get the ARP out of the way
        ntpQuery();
        then = microsecondsSinceBoot();
        evgState = evgDelay;
        break;

    case evgDelay:
        if ((microsecondsSinceBoot() - then) > STARTUP_PAUSE){
            then = microsecondsSinceBoot();
            evgState = evgAwaitPPS;
        }
        break;

    case evgBeginResync:
        reportedMissingPPS = 0;
        then = microsecondsSinceBoot();
        evgState = evgAwaitPPS;
        break;

    case evgAwaitPPS:
        if ((csr & CSR_R_PPS_VALID)
         && (((csr ^ csrOld) & CSR_R_PPS_TOGGLE) != 0)) {
            subsequentPPScheck = 1;
            if (reportedMissingPPS) {
                printf("PPS present, continuing with synchronization.\n");
                reportedMissingPPS = 0;
            }
            ntpQuery();
            then = microsecondsSinceBoot();
            evgState = evgAwaitNTP;
        }
        else if ((microsecondsSinceBoot() - then) >
                                     (subsequentPPScheck ? 1000000 : 3100000)) {
            subsequentPPScheck = 1;
            then = microsecondsSinceBoot();
            if (!reportedMissingPPS++) {
                printf("Warning -- invalid PPS.\n");
            }
            if ((reportedMissingPPS % 60) == 0) {
                printf("Still no PPS (%08X).\n", csr);
            }
        }
        break;

    case evgAwaitNTP:
        if (evgTime.posixSeconds) {
            GPIO_WRITE(GPIO_IDX_EVG_CSR, evgTime.posixSeconds);
            printf("Time %u:%u after %u us\n", evgTime.posixSeconds,
                                               evgTime.fraction,
                                               microsecondsSinceBoot()-then);
            if (evgTime.fraction > (1UL << 30)) {
                printf("Warning -- PPS marker to NTP second %d ms.\n",
                                       ((evgTime.fraction >> 10) * 1000) >> 22);
            }
            evgState = evgSynced;
            break;
        }
        else if ((microsecondsSinceBoot() - then) > 800000) {
            printf("Warning -- No response from NTP server.\n");
            evgState = evgPause;
        }
        break;

    case evgPause:
        if ((microsecondsSinceBoot() - then) > ((1<<query.poll) * 1000000)) {
            then = microsecondsSinceBoot();
            evgState = evgAwaitPPS;
        }
        break;

    case evgSynced:
        if ((csr & CSR_R_SECONDS_VALID) == 0) {
            printf("Warning -- Lost PPS\n");
            evgState = evgBeginResync;
        }
        break;
    }
    csrOld = csr;
    if ((debugFlags & DEBUGFLAG_EVG) && (evgState != oldState)) {
        printf("EVG State %d\n", evgState);
    }
}

void
evgShow(void)
{
    uint32_t csr = GPIO_READ(GPIO_IDX_PPS_STATUS);
    if (csr & PPS_CSR_QUARTZ_VALID) printf("Quartz PPS present. ");
    if (csr & PPS_CSR_USE_QUARTZ)   printf("Use Quartz PPS. ");
    if (csr & PPS_CSR_PMOD_VALID)   printf("PMOD PPS present. ");
    if (csr & PPS_CSR_USE_PMOD)     printf("Use PMOD PPS. ");
    if (csr & (PPS_CSR_USE_PMOD   |
               PPS_CSR_PMOD_VALID |
               PPS_CSR_USE_QUARTZ |
               PPS_CSR_QUARTZ_VALID)) printf("\n");
    if (csr & PPS_CSR_QUARTZ_COS) {
        printf("Quartz PPS present change-of-state.\n");
        GPIO_WRITE(GPIO_IDX_PPS_STATUS, PPS_CSR_QUARTZ_COS);
    }
    if (csr & PPS_CSR_PMOD_COS) {
        printf("PMOD PPS present change-of-state.\n");
        GPIO_WRITE(GPIO_IDX_PPS_STATUS, PPS_CSR_PMOD_COS);
    }
}
