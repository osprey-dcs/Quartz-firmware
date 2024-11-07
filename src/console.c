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
 * Serial/UDP console I/O
 */

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <xuartlite_l.h>
#include <xparameters.h>
#include <ospreyUDP.h>
#include "ad7768.h"
#include "bootFlash.h"
#include "clockAdjust.h"
#include "console.h"
#include "eyescan.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mpsLocal.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"

/*
 * Startup message replay
 */
#define STARTUP_LOG_SIZE 2000
static char startupLog[STARTUP_LOG_SIZE];
static int startupActive = 1;
static int startupLogIndex;

/*
 * Special modes
 */
static void (*modalHandler)(int argc, char **argv);

/*
 * UDP console
 */
#define UDP_TX_BUFSIZE      500
#define LINE_CAPACITY       200
#define CONSOLE_UDP_PORT    55002
static struct {
    int               isActive;
    ospreyUDPendpoint endpoint;
    uint32_t          fromAddr;
    int               fromPort;
    char              txBuf[UDP_TX_BUFSIZE];
    int               txCount;
    char              rxBuf[LINE_CAPACITY];
    int               rxCount;
    int               rxIndex;
    uint32_t          usAtFirstTx;
} udpConsole;

static void
drainUDP(void)
{
    ospreyUDPsendto(udpConsole.endpoint, udpConsole.fromAddr,
                     udpConsole.fromPort, udpConsole.txBuf, udpConsole.txCount);
    udpConsole.txCount = 0;
}

void
outbyte(char c)
{
    if (startupActive && (c != '\r')) {
        startupLog[startupLogIndex++] = c;
        if (startupLogIndex == STARTUP_LOG_SIZE) {
            startupActive = 0;
        }
    }
    if (c == '\n') {
        outbyte('\r');
    }
    XUartLite_SendByte(STDOUT_BASEADDRESS, c);
    if (udpConsole.isActive) {
        if (udpConsole.txCount == 0) {
            udpConsole.usAtFirstTx = microsecondsSinceBoot();
        }
        udpConsole.txBuf[udpConsole.txCount++] = c;
        if (udpConsole.txCount == UDP_TX_BUFSIZE) {
            drainUDP();
        }
    }
}

static void
consoleCallback(ospreyUDPendpoint endpoint, uint32_t fromAddr, int fromPort,
                                                    const char *buf, int length)
{
    int len, nFree;
    if (!udpConsole.isActive) {
        udpConsole.txCount = 0;
        udpConsole.rxCount = 0;
        udpConsole.rxIndex = 0;
        udpConsole.isActive = 1;
    }
    else if (udpConsole.rxIndex >= udpConsole.rxCount) {
        udpConsole.rxCount = 0;
        udpConsole.rxIndex = 0;
    }
    else if (udpConsole.rxIndex != 0) {
        int unread = udpConsole.rxCount - udpConsole.rxIndex;
        memmove(udpConsole.rxBuf, &udpConsole.rxBuf[udpConsole.rxIndex],unread);
        udpConsole.rxCount = unread;
        udpConsole.rxIndex = 0;
    }
    udpConsole.fromAddr = fromAddr;
    udpConsole.fromPort = fromPort;
    nFree = LINE_CAPACITY - udpConsole.rxCount;
    len = length;
    if (len > nFree) {
        len = nFree;
    }
    memcpy(&udpConsole.rxBuf[udpConsole.rxCount], buf, len);
    udpConsole.rxCount += len;
}

static int
getInt(const char *str, int base, int *result)
{
    long l;
    char *endp;
    l = strtol(str, &endp, base);
    if ((endp == str)
    || (l < INT_MIN)
    || (l > INT_MAX)
    || (*endp != '\0')) {
        printf("Bad integer argument\n");
        return 0;
    }
    *result = l;
    return 1;
}

static int
yesOrNo(int argc, char **argv)
{
    if (argc == 1) {
        if ((strcasecmp(argv[0], "y") == 0)
         || (strcasecmp(argv[0], "yes") == 0)) {
            return 1;
        }
        if ((strcasecmp(argv[0], "n") == 0)
         || (strcasecmp(argv[0], "no") == 0)) {
            return 0;
        }
    }
    printf("Yes or no? ");
    return -1;
}

static void
cmdBOOT(int argc, char **argv)
{
    static int useAlternate;
    if (modalHandler) {
        int y = yesOrNo(argc, argv);
        if (y < 0) {
            return;
        }
        if (y) {
            resetFPGA(useAlternate);
            printf("Reset failed!\n");
        }
        modalHandler = NULL;
        return;
    }
    if ((argc >= 2) && (strcmp(argv[1], "-a") == 0)) {
        useAlternate = 1;
        argc--;
        argv++;
    }
    else {
        useAlternate = 0;
    }
    if (argc > 2) {
        printf("Bad argument.\n");
        return;
    }
    printf("Reboot%s? ", useAlternate ? " Alternate" : "");
    modalHandler = cmdBOOT;
}

static void
cmdDEBUG(int argc, char **argv)
{
    int isStartup = 0;
    if (modalHandler) {
        int y = yesOrNo(argc, argv);
        if (y < 0) {
            return;
        }
        if (y) {
            bootFlashBulkEraseChip();
        }
        modalHandler = NULL;
        return;
    }
    if ((argc >= 2) && (strcmp(argv[1], "-s") == 0)) {
        isStartup = 1;
        argc--;
        argv++;
    }
    if (argc > 2) {
        printf("Too many arguments.\n");
        return;
    }
    if (argc == 2) {
        char *endp;
        long l = strtol(argv[1], &endp, 16);
        if ((endp == argv[1]) || (*endp != '\0')) {
            printf("Bad hexadecimal value.\n");
            return;
        }
        if (isStartup) {
            if (l != systemParameters.startupDebugFlags) {
                systemParameters.startupDebugFlags = l;
                systemParametersStash();
            }
        }
        else {
            if (l == 0x7DEADB00) {
                printf("Bulk erase flash memory? ");
                modalHandler = cmdDEBUG;
                return;
            }
            debugFlags = l;
            tftpSetVerbose((debugFlags & DEBUGFLAG_TFTP) != 0);
        }
    }
    if (isStartup) {
        printf("Startup debug flags 0x%X\n",systemParameters.startupDebugFlags);
    }
    else {
        printf("Debug flags 0x%X\n", debugFlags);
    }

    /*
     * Single-shot commands
     */
    if (debugFlags & DEBUGFLAG_FLASH_SHOW) {
        bootFlashShowStatus();
        debugFlags &= ~DEBUGFLAG_FLASH_SHOW;
    }
    if (debugFlags & DEBUGFLAG_IIC_FPGA_SCAN) {
        iicFPGAscan();
        debugFlags &= ~DEBUGFLAG_IIC_FPGA_SCAN;
    }
    if (debugFlags & DEBUGFLAG_MGTSTATUSSHOW) {
        mgtShowStatus();
        debugFlags &= ~DEBUGFLAG_MGTSTATUSSHOW;
    }
    if (debugFlags & DEBUGFLAG_MGTCLKSWITCHSHOW) {
        mgtClkSwitchShow();
        debugFlags &= ~DEBUGFLAG_MGTCLKSWITCHSHOW;
    }
    if (debugFlags & DEBUGFLAG_DUMP_AD7768_REG) {
        ad7768DumpReg();
        debugFlags &= ~DEBUGFLAG_DUMP_AD7768_REG;
    }
    if (debugFlags & DEBUGFLAG_START_AD7768_ALIGN) {
        ad7768StartAlignment();
        debugFlags &= ~DEBUGFLAG_START_AD7768_ALIGN;
    }
    if (debugFlags & DEBUGFLAG_TEST_AD7768_RAM) {
        ad7768TestRAM();
        debugFlags &= ~DEBUGFLAG_TEST_AD7768_RAM;
    }
    if (debugFlags & DEBUGFLAG_DUMP_MPS_REG) {
        mpsLocalDumpReg();
        debugFlags &= ~DEBUGFLAG_DUMP_MPS_REG;
    }
}

static void
cmdFMON(int argc, char **argv)
{
    int i;
    uint32_t csr, rate;
    static const char *names[] = { "System",
                                   "Acquisition",
                                   "EVG",
                                   "EVR",
                                   "EVF",
                                   "AD7768 MCLK" };
    for (i = 0 ; i < sizeof names / sizeof names[0] ; i++) {
        printf("%17s clock: ", names[i]);
        if (i < ((sizeof names / sizeof names[0]) - 1)) {
            GPIO_WRITE(GPIO_IDX_FREQUENCY_COUNTERS, i);
            csr = GPIO_READ(GPIO_IDX_FREQUENCY_COUNTERS);
            rate = csr & 0x3FFFFFFF;
        }
        else {
            rate = ad7768FetchMCLKrate();
        }
        if (csr & 0x80000000) {
            /* Lower accuracy with internal PPS marker */
            rate /= 1000;
            printf("%3d.%03d\n", rate / 1000, rate % 1000);
        }
        else {
            printf("%3d.%06d\n", rate / 1000000, rate % 1000000);
        }
    }
}

static void
cmdLOG(int argc, char **argv)
{
    int i;
    int c = 0;
    for (i = 0 ; i < startupLogIndex ; i++) {
        char c = startupLog[i];
        outbyte(c);
    }
    if (c != '\n') {
        outbyte('\n');
    }
}

static int
parseIPv4(const char *cp, uint32_t *ipv4Address, int *networkWidth)
{
    int i = 0;
    uint32_t addr = 0;
    int width = 24;
    char *endp;

    for (;;) {
        long l = strtol(cp, &endp, 10);
        if ((l < 0) || (l > 255)) {
            break;
        }
        addr = (addr << 8) | l;
        cp = endp;
        if ((l == 0) && (i == 0) && (*cp == '\0')) {
            break;
        }
        if (++i == 4) {
            if (networkWidth && (*cp == '/')) {
                l = strtol(cp+1, &endp, 10);
                if ((l < 0) || (l > 30)) {
                    break;
                }
                width = l;
                cp = endp;
            }
            break;
        }
        if ((*cp == '\0')
         || (*(cp+1) == '\0')
         || (*cp != '.')) {
            cp = "!";
            break;
        }
        cp++;
    }
    if (*cp) {
        printf("Invalid IPv4 address.\n");
        return 0;
    }
    *ipv4Address = addr;
    if (networkWidth) {
        *networkWidth = width;
    }
    return 1;
}

static void
cmdGW(int argc, char **argv)
{
    static int width;
    static uint32_t netmask, gateway;
    if (modalHandler) {
        int y = yesOrNo(argc, argv);
        if (y < 0) {
            return;
        }
        if (y) {
            systemParameters.netmask = netmask;
            systemParameters.gateway = gateway;
            systemParametersStash();
        }
        modalHandler = NULL;
        return;
    }
    if (argc > 1) {
        if (argc > 2) {
            printf("Too many arguments.\n");
            return;
        }
        gateway = 0;
        if (!parseIPv4(argv[1], &gateway, &width)) {
            return;
        }
        netmask = ~(uint32_t)0 << (32 - width);
    }
    else {
        netmask = systemParameters.netmask;
        gateway = systemParameters.gateway;
    }
    showIPv4address("netmask", netmask);
    showIPv4address("gateway", gateway);
    if (argc > 1) {
        printf("Save network configuration in flash memory? ");
        modalHandler = cmdGW;
    }
}

static void
cmdNTP(int argc, char **argv)
{
    static uint32_t ntpServer;
    if (modalHandler) {
        int y = yesOrNo(argc, argv);
        if (y < 0) {
            return;
        }
        if (y) {
            systemParameters.ntpServer = ntpServer;
            systemParametersStash();
        }
        modalHandler = NULL;
        return;
    }
    if (argc > 1) {
        if (argc > 2) {
            printf("Too many arguments.\n");
            return;
        }
        if (!parseIPv4(argv[1], &ntpServer, NULL)) {
            return;
        }
    }
    else {
        ntpServer = systemParameters.ntpServer;
    }
    if (ntpServer == 0) {
        printf("No NTP server.\n");
    }
    else {
        showIPv4address("NTP server", ntpServer);
    }
    if (argc > 1) {
        printf("Save NTP configuration in flash memory? ");
        modalHandler = cmdNTP;
    }
}

static void
cmdPPS(int argc, char **argv)
{
    uint32_t csr;
    if (argc != 1) {
        printf("Bad argument");
        return;
    }
    csr = GPIO_READ(GPIO_IDX_PPS_LATENCY);
    printf("HW->PPS Event Latency: ");
    if (csr & 0x80000000) {
        printf("Overrun\n");
    }
    else {
        printf("%d ns\n", (csr & 0xFFFF) * (1000000000 / CFG_SYSCLK_RATE));
    }
    ad7768ShowAlignment();
    clockAdjustShow();
}

static void
cmdREG(int argc, char **argv)
{
    int first = 0, n = 1;
    int i;
    uint32_t v;
    if (argc >= 2) {
        if (!getInt(argv[1], 0, &first)) {
            return;
        }
        if (argc >= 3) {
            if (!getInt(argv[2], 0, &n)) {
                return;
            }
        }
    }
    if ((first < 0)
     || (n <= 0)
     || (first >= GPIO_IDX_COUNT)
     || ((GPIO_IDX_COUNT - n) < first)) {
        printf("Argument out of range\n");
        return;
    }
    for (i = first ; i < (first + n) ; i++) {
        v = GPIO_READ(i);
        printf("%3d:%11d %04X:%04X\n",i,(int)v,(int)(v >> 16),(int)(v & 0xFFFF));
    }
}

/*
 * Search for and execute command
 */
static void
findCommand(int argc, char **argv)
{
    int i, l;
    int match = -1;
    static const struct {
        const char *const name;
        const void (*fp)(int argc, char **argv);
        const char *const description;
    } cmdTable[] = {
        { "boot",  cmdBOOT,   "Reboot FPGA"                           },
        { "debug", cmdDEBUG,  "Set/show debugging flags"              },
        { "eye",   eyescanCommand, "Scan MGT and produce eye diagram" },
        { "fmon",  cmdFMON,   "Show frequency counters",              },
        { "gw",    cmdGW,     "Set network gateway",                  },
        { "help",  NULL,      "Show commands"                         },
        { "log",   cmdLOG,    "Replay startup log messages"           },
        { "ntp",   cmdNTP,    "Set NTP server information"            },
        { "pps",   cmdPPS,    "Show HW->EVR PPS latency"              },
        { "reg",   cmdREG,    "Show GPIO register(s)"                 },
    };
    if ((argc == 0) || ((l = strlen(argv[0])) == 0)) {
        return;
    }
    for (i = 0 ; i < (sizeof cmdTable / sizeof cmdTable[0]) ; i++) {
        if (strncmp(argv[0], cmdTable[i].name, l) == 0) {
            if (match >= 0) {
                printf("Ambiguous command\n");
                return;
            }
            match = i;
        }
    }
    if (!strcmp(argv[0], "?") || ((match >= 0) && cmdTable[match].fp == NULL)) {
        printf("Commands:\n");
        for (i = 0 ; i < (sizeof cmdTable / sizeof cmdTable[0]) ; i++) {
            printf("%8s -- %s\n", cmdTable[i].name, cmdTable[i].description);
        }
        return;
    }
    if (match < 0) {
        printf("Unknown command\n");
        return;
    }
    (*cmdTable[match].fp)(argc, argv);
}

/*
 * Process a line of input
 */
static void
processLine(char *line)
{
    int argc = 0;
    char *argv[10];
    char *lasts;
    for (;;) {
        char *ap = strtok_r(line, " ", &lasts);
        argv[argc] = ap;
        if (ap == NULL) {
            break;
        }
        if (++argc >= (sizeof argv / sizeof argv[0])) {
            printf("Too many arguments\n");
            return;
        }
        line = NULL;
    }
    if (modalHandler) {
        (*modalHandler)(argc, argv);
    }
    else {
        findCommand(argc, argv);
    }
}

/*
 * Console I/O state machine
 */
void
consoleCrank(void)
{
    int c;
    static char line[LINE_CAPACITY];
    static int lineIndex;

    eyescanCrank(0);
    if (udpConsole.isActive && udpConsole.txCount
     && ((microsecondsSinceBoot() - udpConsole.usAtFirstTx) > 50000)) {
        drainUDP();
    }
    if (!XUartLite_IsReceiveEmpty(STDOUT_BASEADDRESS)) {
        udpConsole.isActive = 0;
        c = (unsigned char)XUartLite_RecvByte(STDOUT_BASEADDRESS);
    }
    else {
        if (!udpConsole.isActive || (udpConsole.rxIndex >= udpConsole.rxCount)){
            return;
        }
        c = (unsigned char)udpConsole.rxBuf[udpConsole.rxIndex++];
    }
    eyescanCrank(1);
    switch (c) {
    case '\t':   c = ' ';    break;
    case '\r':   c = '\n';   break;
    case '\177': c = '\b';   break;
    }
    startupActive = 0;
    if ((c >= ' ') && (c <= '~')) {
        outbyte(c);
        if (lineIndex < (LINE_CAPACITY - 1)) {
            line[lineIndex++] = c;
        }
    }
    else {
        switch (c) {
        case '\b':
            if (lineIndex) {
                lineIndex--;
                outbyte('\b');
                outbyte(' ');
                outbyte('\b');
            }
            break;
        case '\n':
            outbyte('\n');
            line[lineIndex] = '\0';
            processLine(line);
            lineIndex = 0;
            break;
        }
    }
}

void
consoleInit(void)
{
    udpConsole.endpoint = ospreyUDPregisterEndpoint(CONSOLE_UDP_PORT,
                                                               consoleCallback);
    if (udpConsole.endpoint == NULL) {
        printf("Can't register console UDP!\n");
    }
}
