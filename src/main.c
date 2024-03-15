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

#include <stdio.h>
#include <ospreyUDP.h>
#include "ad7768.h"
#include "amc7823.h"
#include "acq.h"
#include "bootFlash.h"
#include "clockAdjust.h"
#include "console.h"
#include "epics.h"
#include "evg.h"
#include "fastDataStream.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "inputCoupling.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mmcMailbox.h"
#include "platform.h"
#include "softwareBuildDate.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"
#include "xadc.h"

int
main()
{
    init_platform();
    printf("Firmware build date: %u\n", GPIO_READ(GPIO_IDX_FIRMWARE_DATE));
    printf("Software build date: %u\n", SOFTWARE_BUILD_DATE);
    bootFlashInit(XPAR_MARBLEBOOTFLASH_S_AXI_LITE_BASEADDR);
    mmcMailboxInit();
    systemParametersInit();
    ospreyUDPregisterInterface(XPAR_OSPREYUDP_S_AXI_LITE_BASEADDR,
                               networkConfig.ipv4address,
                               systemParameters.gateway,
                               systemParameters.netmask,
                               networkConfig.macAddress);
    xadcInit();
    iicFPGAinit();
    consoleInit();
    mgtClkSwitchInit();
    acqInit();
    evgInit();
    mgtInit();
    epicsInit();
    tftpInit();
    clockAdjustInit();
    ad7768Init();
    amc7823Init();
    inputCouplingInit();
    fastDataInit();
    for (;;) {
        mgtCrank();
        evgCrank();
        consoleCrank();
        ospreyUDPcrank();
        ad7768Crank();
        inputCouplingCrank();
    }
    return 0;
}
