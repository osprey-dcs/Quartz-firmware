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
 * IIC to components attatched to FPGA
 */
#ifndef _IIC_FPGA_H_
#define _IIC_FPGA_H_
#include <stdint.h>

#define IIC_FPGA_IDX_FMC1_EEPROM        0
#define IIC_FPGA_IDX_FMC2_EEPROM        1
#define IIC_FPGA_IDX_MGT_CLK_CROSSPOINT 2
#define IIC_FPGA_IDX_SODIMM             3
#define IIC_FPGA_IDX_QSFP1              4
#define IIC_FPGA_IDX_QSFP2              5
#define IIC_FPGA_IDX_PCA9555_U39        6
#define IIC_FPGA_IDX_PCA9555_U34        7
#define IIC_FPGA_IDX_INA219_0           8
#define IIC_FPGA_IDX_INA219_1           9
#define IIC_FPGA_IDX_INA219_2          10
#define IIC_FPGA_IDX_SI570             11

void iicFPGAinit(void);
int iicFPGAwrite(int idx, const unsigned char *buf, int count);
int iicFPGAread(int idx, int subaddress, unsigned char *buf, int count);
int iicFPGAeepromRead(int idx, uint32_t address, uint32_t length, void *buf);
int iicFPGAeepromWrite(int idx, uint32_t address, uint32_t length,
                                                               const void *buf);
uint32_t iicFPGAfetchSysmon(int index);
void iicFPGAscan(void);

#endif /* _IIC_FPGA_H_ */
