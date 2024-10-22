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

#ifndef _OSPREY_UDP_H_
#define _OSPREY_UDP_H_

#include <stdint.h>

#ifndef OSPREY_UDP_INTERFACE_CAPACITY
# define OSPREY_UDP_INTERFACE_CAPACITY  1
#endif
#ifndef OSPREY_UDP_ENDPOINT_CAPACITY
# define OSPREY_UDP_ENDPOINT_CAPACITY   5
#endif
#ifndef OSPREY_UDP_PACKET_CAPACITY
# define OSPREY_UDP_PACKET_CAPACITY 1472
#endif

#if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
# define OSPREY_UDP_INTERFACE_ARG int interface,
#else
# define OSPREY_UDP_INTERFACE_ARG
#endif

typedef void *ospreyUDPendpoint;
typedef void (*ospreyUDPcallback)(ospreyUDPendpoint endpoint,
                                               uint32_t farAddress, int farPort,
                                               const char *buf, int length);

int ospreyUDPregisterInterface(uint32_t baseAddress,
                           uint32_t address, uint32_t gateway, uint32_t netmask,
                           uint8_t macAddress[6]);

ospreyUDPendpoint ospreyUDPregisterEndpoint(OSPREY_UDP_INTERFACE_ARG int port,
                                                    ospreyUDPcallback callback);

void ospreyUDPsendto(ospreyUDPendpoint endpoint,
                                               uint32_t farAddress, int farPort,
                                               const char *buf, int length);

int ospreyUDPregisterFastSubscriber(OSPREY_UDP_INTERFACE_ARG
             uint32_t subscriberAddress, int publisherPort, int subscriberPort);

void ospreyUDPcrank(void);

#endif /* _OSPREY_UDP_H_ */
