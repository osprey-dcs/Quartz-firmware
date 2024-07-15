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
 * Fast data acquisition
 */
#ifndef _ACQ_H_
#define _ACQ_H_

void acqInit(void);
void acqSetActive(int channel, int active);
int acqGetActive(int channel);
void acqSetCoupling(int channel, int dcCoupled);
int acqGetCoupling(int channel);
void acqSubscriptionChange(int subscriberPresent);
uint32_t acqFetchSysmon(int offset);
void acqSetLOLOthreshold(int channel, int threshold);
void acqSetLOthreshold(int channel, int threshold);
void acqSetHIthreshold(int channel, int threshold);
void acqSetHIHIthreshold(int channel, int threshold);
int acqGetLOLOthreshold(int channel);
int acqGetLOthreshold(int channel);
int acqGetHIthreshold(int channel);
int acqGetHIHIthreshold(int channel);
void acqSetCalibrationValidity(int isCalibrated);
uint32_t acqGetLimitExcursions(int type);

#endif /* _ACQ_H_ */
