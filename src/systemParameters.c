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
 * Non-volatile system parameters
 */

#include <stdio.h>
#include <xparameters.h>
#include "ffs.h"
#include "gpio.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"

#define SYSPARAM_NAME "SYSPARAM.DAT"

struct systemParameters systemParameters;

static unsigned int
checksum(void)
{
    unsigned int sum = 0xA3529523;
    unsigned int *ip = (unsigned int *)&systemParameters;
    int n = sizeof(systemParameters)/sizeof(*ip);
    unsigned int svChecksum = systemParameters.checksum;
    int i;
    systemParameters.checksum = 0;
    for (i = 0 ; i < n ; i++) {
        sum += *ip++ + i;
    }
    if (sum == 0) {
        sum = 1;
    }
    systemParameters.checksum = svChecksum;
    return sum;
}

void
systemParametersInit(void)
{
    static FIL fil;
    FRESULT fr = FR_NOT_ENABLED;
    const char *name = SYSPARAM_NAME;

    if (ffsCheckMount()) {
        if ((fr = f_open(&fil, name, FA_READ)) == FR_OK) {
            unsigned int nWant = sizeof systemParameters;
            unsigned int nRead;
            fr = f_read(&fil, &systemParameters, nWant, &nRead);
            if (fr == FR_OK) {
                if (nRead != nWant) {
                    printf("Read only %u of %u from %s\n", nRead, nWant, name);
                    fr = FR_INVALID_OBJECT;
                }
                else if (systemParameters.checksum != checksum()) {
                    printf("Checksum mismatch in %s\n", name);
                    fr = FR_INVALID_OBJECT;
                }
            }
            else {
                printf("Can't read \"%s\": %s\n", name, ffsErrorString(fr));
            }
            f_close(&fil);
        }
        else {
            printf("Can't open \"%s\": %s\n", name, ffsErrorString(fr));
        }
        ffsUnmount();
    }
    if (fr != FR_OK) {
        printf("Assigning default parameters:\n");
        systemParameters.startupDebugFlags = DEBUGFLAG_NO_RELAY_EXERCISE;
        systemParameters.netmask = 0xFFFFFF00;
        systemParameters.gateway = (networkConfig.ipv4address &
                                                  systemParameters.netmask) | 1;
        systemParameters.ntpServer = 0;
    }
    showIPv4address("netmask", systemParameters.netmask);
    showIPv4address("gateway", systemParameters.gateway);
    if (systemParameters.ntpServer) {
        showIPv4address("NTP server", systemParameters.ntpServer);
    }
    else {
        printf(" No NTP server.\n");
    }
    debugFlags = systemParameters.startupDebugFlags;
    tftpSetVerbose((debugFlags & DEBUGFLAG_TFTP) != 0);
}

void
systemParametersStash(void)
{
    static FIL fil;
    FRESULT fr = FR_NOT_ENABLED;
    const char *name = SYSPARAM_NAME;

    if (ffsCheckMount()) {
        if ((fr = f_open(&fil, name, FA_CREATE_ALWAYS | FA_WRITE)) == FR_OK) {
            unsigned int nWrite = sizeof systemParameters;
            unsigned int nWritten;
            systemParameters.checksum = checksum();
            fr = f_write(&fil, &systemParameters, nWrite, &nWritten);
            if ((fr != FR_OK)
             || (nWritten != nWrite)) {
                printf("Can't write \"%s\": %s\n", name, ffsErrorString(fr));
            }
            f_close(&fil);
        }
        else {
            printf("Can't create \"%s\": %s\n", name, ffsErrorString(fr));
        }
        ffsUnmount();
    }
}
