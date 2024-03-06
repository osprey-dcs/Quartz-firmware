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
 * Non-volatile system parameters
 */

#ifndef _SYSTEM_PARAMETERS_H_
#define _SYSTEM_PARAMETERS_H_

#include <stdint.h>

/*
 * Stored in bootstrap flash memory
 */
struct systemParameters {
    unsigned int startupDebugFlags;
    uint32_t     netmask;
    uint32_t     gateway;
    uint32_t     ntpServer;
    unsigned int checksum;
};
extern struct systemParameters systemParameters;

/*
 * Obtained from microcontroller
 */
struct networkConfig {
    unsigned char macAddress[6];
    uint32_t      ipv4address;
};
extern struct networkConfig networkConfig;

void systemParametersInit(void);
void systemParametersStash(void);

#endif /* _SYSTEM_PARAMETERS_H_ */
