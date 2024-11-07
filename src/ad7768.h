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

/*
 * AD7768 24-bit Delta/Sigma ADC
 */

#ifndef _AD7768_H_
#define _AD7768_H_

void ad7768Init(void);
void ad7768Reset(int reset);
void ad7768EnableFMC(void);
int ad7768IsReset(void);
void ad7768Crank(void);
void ad7768DumpReg(void);
void ad7768StartAlignment(void);
int ad7768SetOfst(int channel, int offset);
int ad7768SetGain(int channel, int gain);
void ad7768SetSamplingRate(int rate);

uint32_t ad7768FetchSysmon(int index);
uint32_t ad7768GetHeader(int index);
uint32_t ad7768GetStatuses(void);
uint32_t ad7768FetchMCLKrate(void);

void ad7768ShowAlignment(void);
void ad7768TestRAM(void);

#endif /* _AD7768_H_ */
