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

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include "gpio.h"
#include "util.h"

int debugFlags;

void
microsecondSpin(int microseconds)
{
    uint32_t then = microsecondsSinceBoot();
    while ((microsecondsSinceBoot() - then) <= microseconds) continue;
}

/*
 * Fetch register from some other clock domain
 */
uint32_t
fetchRegister(int idx)
{
    uint32_t ocsr, csr;
    int passesLeft = 10;
    ocsr = GPIO_READ(idx);
    for (;;) {
        csr = GPIO_READ(idx);
        if ((csr == ocsr) || (--passesLeft == 0)) {
            return csr;
        }
        ocsr = csr;
    }
}

void
showIPv4address(const char *name, uint32_t address)
{
    int i;
    char sep = ' ';
    printf(" IPv4 %s:", name);
    for (i = 24 ; i >= 0 ; i -= 8) {
        int v = (address >> i) & 0xFF;
        printf("%c%d", sep, v);
        sep = '.';
    }
    printf("\n");
}

/*
 * Write to the ICAP instance to force a warm reboot
 * Command sequence from UG470
 */
static void
writeICAP(int value)
{
    Xil_Out32(XPAR_HWICAP_BASEADDR+0x100, value); /* Write FIFO */
}
void
resetFPGA(int bootAlternateImage)
{
    uint32_t wbstar = bootAlternateImage ? CFG_ALT_BOOT_IMAGE_OFFSET
                                         : 0x00000000;
    printf("====== FPGA REBOOT (WBSTAR=%06X) ======\n\n", wbstar);
    microsecondSpin(50000);
    writeICAP(0xFFFFFFFF); /* Dummy word */
    writeICAP(0xAA995566); /* Sync word */
    writeICAP(0x20000000); /* Type 1 NO-OP */
    writeICAP(0x30020001); /* Type 1 write 1 to Warm Boot STart Address Reg */
    writeICAP(wbstar);     /* Warm boot start addr */
    writeICAP(0x20000000); /* Type 1 NO-OP */
    writeICAP(0x30008001); /* Type 1 write 1 to CMD */
    writeICAP(0x0000000F); /* IPROG command */
    writeICAP(0x20000000); /* Type 1 NO-OP */
    microsecondSpin(1000);
    Xil_Out32(XPAR_HWICAP_BASEADDR+0x10C, 0x1);   /* Initiate WRITE */
    microsecondSpin(1000000);
    printf("====== FPGA REBOOT FAILED ======\n\n");
}
