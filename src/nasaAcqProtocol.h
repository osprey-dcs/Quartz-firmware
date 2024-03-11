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
 * IOC/FPGA communication -- application-specific
 */
#ifndef _NASA_ACQ_PROTOCOL_H_
#define _NASA_ACQ_PROTOCOL_H_

#define NASA_ACQ_MAGIC        0xA3593D25
#define NASA_ACQ_UDP_PORT     54398

#define FPGA_IOC_CMD_REBOOT             0
#define FPGA_IOC_CMD_CLR_POWERUP        1
#define FPGA_IOC_CMD_GET_HARDWARE_DATE  2
#define FPGA_IOC_CMD_GET_SOFTWARE_DATE  3
#define FPGA_IOC_CMD_ACQ_ENABLE         10
#define FPGA_IOC_CMD_DOWNSAMPLE_RATIO   20
#define FPGA_IOC_CMD_DOWNSAMPLE_ALPHA   21
#define FPGA_IOC_CMD_CHAN_ACTIVE        100
#define FPGA_IOC_CMD_CHAN_COUPLING      200
#define FPGA_IOC_CMD_CHAN_CALIB_OFST    300
#define FPGA_IOC_CMD_CHAN_CALIB_GAIN    400

#define FPGA_IOC_MSGID_GET_BUILD_DATES  16953

#endif /* _NASA_ACQ_PROTOCOL_H_ */
