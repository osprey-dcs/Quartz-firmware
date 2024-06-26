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
 * Local machine protection support
 */

#ifndef _MPS_LOCAL_H_
#define _MPS_LOCAL_H_

void mpsLocalInit(void);
void mpsLocalDumpReg(void);

void mpsLocalSetLOLObitmap(int outputIndex, uint32_t map);
void mpsLocalSetLObitmap(int outputIndex, uint32_t map);
void mpsLocalSetHIbitmap(int outputIndex, uint32_t map);
void mpsLocalSetHIHIbitmap(int outputIndex, uint32_t map);
void mpsLocalSetDiscreteBitmap(int outputIndex, uint32_t map);
void mpsLocalSetDiscreteGoodState(int outputIndex, uint32_t goodState);

uint32_t mpsLocalIsTripped(int outputIndex);
uint32_t mpsLocalGetLOLObitmap(int outputIndex);
uint32_t mpsLocalGetLObitmap(int outputIndex);
uint32_t mpsLocalGetHIbitmap(int outputIndex);
uint32_t mpsLocalGetHIHIbitmap(int outputIndex);
uint32_t mpsLocalGetDiscreteBitmap(int outputIndex);
uint32_t mpsLocalGetDiscreteGoodState(int outputIndex);
uint32_t mpsLocalGetFirstFaultLOLO(int outputIndex);
uint32_t mpsLocalGetFirstFaultLO(int outputIndex);
uint32_t mpsLocalGetFirstFaultHI(int outputIndex);
uint32_t mpsLocalGetFirstFaultHIHI(int outputIndex);
uint32_t mpsLocalGetFirstFaultDiscrete(int outputIndex);
uint32_t mpsLocalGetFirstFaultSeconds(int outputIndex);
uint32_t mpsLocalGetFirstFaultTicks(int outputIndex);

uint32_t mpsLocalFetchSysmon(int index);

#endif /* _MPS_LOCAL_H_ */
