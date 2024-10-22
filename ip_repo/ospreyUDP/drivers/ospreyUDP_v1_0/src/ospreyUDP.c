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

#include <stdio.h>
#include <stdint.h>
#include <xil_io.h>
#include "ospreyUDP.h"

#define SEND_CHECK_LIMIT    500000

#define CSR_R_RESET             0x40000000
#define CSR_R_TX_BUSY           0x20000000
#define CSR_R_RX_FULL           0x10000000
#define CSR_R_TX_OVERRUN        0x2000000
#define CSR_R_RX_IRQ_ENABLE     0x1000000
#define CSR_R_SPEED_MASK        0x300000
#define CSR_R_PKADDR_MASK       0x7FFF
#define CSR_W_REMOVE_RESET      0x80000000
#define CSR_W_APPLY_RESET       0x40000000
#define CSR_W_START_TRANSMISION 0x20000000
#define CSR_W_FINISH_RECEPTION  0x10000000
#define CSR_W_CLR_RX_IRQ_ENABLE 0x2000000
#define CSR_W_SET_RX_IRQ_ENABLE 0x1000000

#define REG_CSR               0
#define REG_DATA              4
#define REG_ADDR              8
#define REG_PORTS            12
#define REG_LENGTH           16
#define REG_MAC_LO           20
#define REG_MAC_HI           24
#define REG_LOCAL            28
#define REG_GATEWAY          32
#define REG_NETMASK          36
#define REG_FAST_DESTINATION 40
#define REG_FAST_PORTS       44
#define REG_READ(ip,reg)    Xil_In32(ip->baseAddress+(reg))
#define REG_WRITE(ip,reg,v) Xil_Out32(ip->baseAddress+(reg),(v))
#define CSR_READ(ip)    REG_READ(ip, REG_CSR)
#define CSR_WRITE(ip,v) REG_WRITE(ip, REG_CSR, (v))

#if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
# define OSPREY_UDP_INTERFACE_ARG int interface,
#else
# define OSPREY_UDP_INTERFACE_ARG
#endif

struct interface {
    uint32_t         baseAddress;
    struct endpoint *eHead;
};
static struct interface interfaces[OSPREY_UDP_INTERFACE_CAPACITY];
static int interfaceCount = 0;

struct endpoint {
    struct endpoint  *next;
    ospreyUDPcallback callback;
    uint16_t          nearPort;
    #if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
    uint16_t          interface;
    #endif
};
static struct endpoint *eFree;

static void
resetHardware(struct interface *ip)
{
    volatile int d;
    CSR_WRITE(ip, CSR_W_APPLY_RESET);
    for (d = 0 ; d < 10 ; d++) continue;
    CSR_WRITE(ip, CSR_W_REMOVE_RESET);
    for (d = 0 ; d < 10 ; d++) continue;
}

int
ospreyUDPregisterInterface(uint32_t baseAddress,
                       uint32_t address, uint32_t gateway, uint32_t netmask,
                       uint8_t mac[6])
{
    struct interface *ip;
    if (interfaceCount == 0) {
        static struct endpoint endpoints[OSPREY_UDP_ENDPOINT_CAPACITY];
        int i;
        for (i = 0 ; i < OSPREY_UDP_ENDPOINT_CAPACITY ; i++) {
            endpoints[i].next = eFree;
            eFree = &endpoints[i];
        }
    }
    else if (interfaceCount >= OSPREY_UDP_INTERFACE_CAPACITY) {
        return -1;
    }
    ip = &interfaces[interfaceCount];
    ip->baseAddress = baseAddress;
    resetHardware(ip);
    REG_WRITE(ip, REG_MAC_LO, (mac[2]<<24)|(mac[3]<<16)|(mac[4]<<8)|mac[5]);
    REG_WRITE(ip, REG_MAC_HI, (mac[0]<<8)|mac[1]);
    REG_WRITE(ip, REG_LOCAL, address);
    REG_WRITE(ip, REG_GATEWAY, gateway);
    REG_WRITE(ip, REG_NETMASK, netmask);
    return interfaceCount++;
}

ospreyUDPendpoint
ospreyUDPregisterEndpoint(OSPREY_UDP_INTERFACE_ARG int p, ospreyUDPcallback cb)
{
    struct interface *ip;
    struct endpoint *ep;
    if ((eFree == NULL)
    #if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
     || (interface < 0)
     || (interface >= interfaceCount)
     || (interfaces[interface].baseAddress == 0)
    #else
     || (interfaces[0].baseAddress == 0)
    #endif
     || (cb == NULL)
     || (p <= 0)
     || (p > 0xFFFF)) {
        return NULL;
    }
    ep = eFree;
    eFree = ep->next;
    ep->nearPort = p;
    ep->callback = cb;
    #if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
      ep->interface = interface;
      ip = &interfaces[ep->interface];
    #else
      ip = &interfaces[0];
    #endif
    ep->next = ip->eHead;
    ip->eHead = ep;
    return ep;
}

void
ospreyUDPsendto(ospreyUDPendpoint endpoint, uint32_t farAddress,
                                       int farPort, const char *buf, int length)
{
    struct endpoint *ep = (struct endpoint *)endpoint;
    unsigned int i;
    uint32_t *txp = (uint32_t *)buf;
    struct interface *ip =
    #if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
                            &interfaces[ep->interface];
    #else
                            &interfaces[0];
    #endif
    uint32_t csr = CSR_READ(ip);
    if (csr & CSR_R_TX_BUSY) {
        volatile int i = 0;
        while (CSR_READ(ip) & CSR_R_TX_BUSY)  {
            if (++i == SEND_CHECK_LIMIT) {
                xil_printf("NETWORK TRANSMISSION LOCKED UP!  "
                                                       "RESETTING HARDWARE.\n");
                resetHardware(ip);
                break;
            }
        }
    }
    REG_WRITE(ip, REG_ADDR, farAddress);
    REG_WRITE(ip, REG_PORTS, (ep->nearPort << 16) | farPort);
    REG_WRITE(ip, REG_LENGTH, length);
    CSR_WRITE(ip, 0);
    for (i = 0 ; i < ((length+sizeof(*txp)-1)/sizeof(*txp)) ; i++) {
        REG_WRITE(ip, REG_DATA, *txp++);
    }
    CSR_WRITE(ip, CSR_W_START_TRANSMISION);
}

int
ospreyUDPregisterFastSubscriber(OSPREY_UDP_INTERFACE_ARG
              uint32_t subscriberAddress, int publisherPort, int subscriberPort)
{
    struct interface *ip;
    #if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
      if ((interface < 0)
       || (interface >= interfaceCount)) {
        return -1;
      }
      ip = &interfaces[interface];
    #else
      ip = &interfaces[0];
    #endif
    if (ip->baseAddress == 0) {
        return -1;
    }
    REG_WRITE(ip, REG_FAST_DESTINATION, subscriberAddress);
    REG_WRITE(ip, REG_FAST_PORTS, (publisherPort<<16)|(subscriberPort&0xFFFF));
    return 0;
}

void
ospreyUDPcrank(void)
{
    struct interface *ip = &interfaces[0];
    static union {
        uint32_t l[(OSPREY_UDP_PACKET_CAPACITY+sizeof(uint32_t)-1)/
                                                              sizeof(uint32_t)];
        char     c[OSPREY_UDP_PACKET_CAPACITY];
    } rxbuf;

    #if (OSPREY_UDP_INTERFACE_CAPACITY > 1)
    for ( ; ip < &interfaces[interfaceCount] ; ip++)
    #endif
    {
        struct endpoint *ep;
        unsigned int i;
        int consumed;
        int nearPort, farPort;
        uint32_t csr = CSR_READ(ip);
        if (csr & CSR_R_RX_FULL) {
            uint32_t r = REG_READ(ip, REG_PORTS);
            farPort = r >> 16;
            nearPort = r & 0xFFFF;
            consumed = 0;
            for (ep = ip->eHead ; ep != NULL ; ep = ep->next) {
                unsigned int l;
                if ((nearPort == ep->nearPort)
                 && ((l=REG_READ(ip,REG_LENGTH))<=OSPREY_UDP_PACKET_CAPACITY)) {
                    uint32_t farAddr = REG_READ(ip, REG_ADDR);
                    uint32_t *rxp = rxp = rxbuf.l;
                    CSR_WRITE(ip, 0);
                    for (i = 0 ; i < ((l+sizeof(*rxp)-1)/sizeof(*rxp)) ; i++) {
                        *rxp++ = REG_READ(ip, REG_DATA);
                    }
                    CSR_WRITE(ip, CSR_W_FINISH_RECEPTION);
                    consumed = 1;
                    (*ep->callback)(ep, farAddr, farPort, rxbuf.c, l);
                    break;
                }
            }
            if (!consumed) {
                CSR_WRITE(ip, CSR_W_FINISH_RECEPTION);
            }
        }
    }
}
