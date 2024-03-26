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

#include <stdio.h>
#include <stdint.h>
#include <xil_io.h>
#include "acq.h"
#include "fastDataStream.h"
#include "gpio.h"
#include "nasaAcqProtocol.h"
#include "ospreyUDP.h"
#include "util.h"

/*
 * Fast data source
 */
#define FAST_DATA_PORT (NASA_ACQ_UDP_PORT+1)

/*
 * Create server
 */
static uint32_t whenSubscribed;
static void
callback(ospreyUDPendpoint endpoint,
                  uint32_t farAddress, int farPort, const char *buf, int length)
{
    whenSubscribed = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    static int oldFarAddress;
    static int oldFarPort;
    if ((farAddress != oldFarAddress)
     || (farPort != oldFarPort)) {
        printf("Fast data subscriber %d.%d.%d.%d:%d at %d.\n",
                                                      (farAddress >> 24) & 0xFF,
                                                      (farAddress >> 16) & 0xFF,
                                                      (farAddress >>  8) & 0xFF,
                                                      (farAddress      ) & 0xFF,
                                                      farPort, whenSubscribed);
        oldFarAddress = farAddress;
        oldFarPort = farPort;
        ospreyUDPregisterFastSubscriber(farAddress, FAST_DATA_PORT, farPort);
    }
    acqSubscriptionChange(1);
}

void
fastDataInit(void)
{
    if (ospreyUDPregisterEndpoint(FAST_DATA_PORT, callback) == NULL) {
        printf("Can't register fast data publisher UDP endpoint!\n");
    }
}

/* FIXME -- should we have a 'Crank' routine here to unsubscribe after a while? */
