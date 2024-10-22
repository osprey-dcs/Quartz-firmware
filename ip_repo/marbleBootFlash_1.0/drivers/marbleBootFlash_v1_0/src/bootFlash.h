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
 * Bootstrap flash memory
 */

#ifndef _BOOT_FLASH_H_
#define _BOOT_FLASH_H_

#include <stdint.h>

extern int bootFlashConfirmErase;
extern int bootFlashConfirmWrite;

void bootFlashInit(uint32_t baseAddress);
int bootFlashRead(uint32_t address, uint32_t length, void *buf);
int bootFlashWrite(uint32_t address, uint32_t length, const void *buf);
void bootFlashShowStatus(void);
void bootFlashBulkEraseChip(void);
void bootFlashSetVerbose(int verboseFlag);
void bootFlashEnableEraseConfirmation(int enable);
void bootFlashEnableWriteConfirmation(int enable);
void bootFlashProtectGolden(void);

#endif /* _BOOT_FLASH_H_ */
