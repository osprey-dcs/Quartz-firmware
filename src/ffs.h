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
 * Dummy filesystem in boot flash
 */

#ifndef _FFS_H_
#define _FFS_H_

typedef const void *FIL;
typedef int FRESULT;
typedef unsigned int UINT;

#define FA_READ             0x0
#define FA_WRITE            0x1
#define FA_CREATE_ALWAYS    0x2

#define FR_OK               0
#define FR_NOT_READY        1
#define FR_NO_FILE          2
#define FR_ERR              3
#define FR_NOT_ENABLED      4
#define FR_INVALID_OBJECT   5

int ffsCheckMount(void);
void ffsUnmount(void);
FRESULT f_open(FIL *fp, const char *name, int mode);
FRESULT f_read(FIL *fp, void *cbuf, unsigned int n, unsigned int *nread);
FRESULT f_write(FIL *fp, const void *cbuf, unsigned int n, unsigned int *nwritten);
FRESULT f_close(FIL *fp);
const char *ffsErrorString(int code);

#endif /* _FFS_H_ */
