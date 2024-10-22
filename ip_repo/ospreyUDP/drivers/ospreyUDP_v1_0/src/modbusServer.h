/*
 * MIT License
 *
 * Copyright (c) 2021 Osprey DCS
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
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
 * Simple MODBUS server
 */
#ifndef _MODBUS_OSPREY_UDP_H_
#define _MODBUS_OSPREY_UDP_H_
#include <stdint.h>

#define MODBUS_EXCEPTION_ILLEGAL_FUNCTION       1
#define MODBUS_EXCEPTION_ILLEGAL_ADDRESS        2
#define MODBUS_EXCEPTION_ILLEGAL_VALUE          3

int modbusServerUDPinit(int port);
void modbusServerSetDebugFunction(int (*prfunc)(const char *fmt, ...));
/* Application-supplied callback routines */
int modbusServerCallbackCode3(int regBase, int regCount, uint16_t *reg);
int modbusServerCallbackCode16(int regBase, int regCount, const uint16_t *reg);

#endif /* _MODBUS_OSPREY_UDP_H_ */
