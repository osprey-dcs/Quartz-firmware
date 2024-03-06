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
 * FPGA/IOC communication
 */

#ifndef _FPGA_IOC_PROTOCOL_H_
#define _FPGA_IOC_PROTOCOL_H_

#include <stdint.h>

#define FPGA_IOC_ARG_CAPACITY 360

#define FPGA_IOC_PACKET_SIZE_TO_ARGC(s) (((s)/sizeof(uint32_t))-2) 
#define FPGA_IOC_ARGC_TO_PACKET_SIZE(a) (((a)+2)*sizeof(uint32_t)) 
#define FPGA_IOC_LENGTH_TO_ARGC(s) ((s)/sizeof(uint32_t)) 
#define FPGA_IOC_ARGC_TO_LENGTH(a) ((a)*sizeof(uint32_t)) 

struct fpgaIOCpacket {
    char        P;
    char        S;
    uint16_t    msgID;
    uint32_t    length;
    uint32_t    args[FPGA_IOC_ARG_CAPACITY];
};

#define FPGA_IOC_MSGID_GENERIC      16951
#define FPGA_IOC_MSGID_READ_SYSMON  16952

#endif /* _FPGA_IOC_PROTOCOL_H_ */
