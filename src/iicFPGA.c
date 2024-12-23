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

#include <stdio.h>
#include <xparameters.h>
#include <xiic.h>
#include "ad7768.h"
#include "bootFlash.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "util.h"

/*
 * 2 values per INA219, 2 values per QSFP, 1 value per QSFP channel
 */
#define SYSMON_BUF_CAPACITY ((2*3) + (2*2) + (1*4*2))

#define IIC_MUX_ADDRESS 0x70

/*
 * IIC devices
 * This table may be modified at run-time and thus can't be 'const'.
 */
static struct iicMap {
    char    muxValue;
    char    address7;
} iicMap[] = {
    { 0x01, 0x50 }, // FMC1 EEPROM
    { 0x02, 0x50 }, // FMC2 EEPROM
    { 0x04, 0x48 }, // ADN4600 MGT clock multiplexer
    { 0x08, 0x50 }, // SO-DIMM
    { 0x10, 0x50 }, // QSFP 1
    { 0x20, 0x50 }, // QSFP 2
    { 0x40, 0x21 }, // PCA9555 port expander, U39
    { 0x40, 0x22 }, // PCA9555 port expander, U34
    { 0x40, 0x40 }, // INA219 power monitor, U17
    { 0x40, 0x41 }, // INA219 power monitor, U32
    { 0x40, 0x42 }, // INA219 power monitor, U57
    { 0x40, 0x77 }, // SI570 clock generator
};

#define FMC_COUNT 2
static uint32_t serialNumber[FMC_COUNT];
static uint32_t partNumber[FMC_COUNT];

static int
setMux(unsigned char c)
{
    static unsigned char activeMUX = 0;
    if (c != activeMUX) {
        if (XIic_DynSend(XPAR_IIC_FPGA_BASEADDR, IIC_MUX_ADDRESS, &c, 1,
                                                              XIIC_STOP) != 1) {
            activeMUX = 0;
            return 0;
        }
        activeMUX = c;
    }
    return 1;
}

/*
 * The 'isPresent' routine and the EEPROM write-completion polling suffer
 * from the Xilinx driver requirement that at least one byte be written.
 *
 * Presence detection or write-completion polling should consist of:
 *      START DeviceAddress(write) ACK/NAK STOP
 * This happens when no device is present or the EEPROM is busy (NAK).
 * However, when a device is present or the EEPROM is finished (ACK) the
 * following appears on the bus:
 *      START DeviceAddress(write) ACK FirsByte ACK/NAK STOP
 *
 * Thus this code depends upon IIC devices accepting (i.e. ignoring) a
 * single byte of write data following the Device Address.
 * The IIC MUX does not ignore the byte and thus requires special handling.
 */
static int
isPresent(int muxVal, int addr7)
{
    unsigned char c = (addr7 == IIC_MUX_ADDRESS) ? muxVal :  0;

    if (!setMux(muxVal)
     || (XIic_DynSend(XPAR_IIC_FPGA_BASEADDR, addr7, &c, 1, XIIC_STOP) != 1)) {
        return 0;
    }
    return 1;
}

static void
showIPMI(int device)
{
    uint8_t cbuf[128];
    char strBuf[64];
    int i, field;
    int offset, length;
    int index = device - IIC_FPGA_IDX_FMC1_EEPROM;
    uint8_t sum;
    int hardwareMatches = 1;
    if (iicFPGAeepromRead(device, 0, sizeof cbuf, cbuf) != sizeof cbuf) {
        printf("WARNING -- Can't read FMC EEPROM.\n");
        return;
    }
    for (i = 0, sum = 0 ; i < 8 ; i++) {
        sum += cbuf[i];
    }
    if (sum != 0) {
        printf("WARNING -- FMC EEPROM checksum fault.\n");
        return;
    }
    if (cbuf[3] == 0) {
        printf("WARNING -- FMC EEPROM has no board information.\n");
        return;
    }
    offset = cbuf[3] * 8;
    if ((cbuf[offset] != 0x01)
     || ((length = cbuf[offset+1] * 8) == 0)
     || ((offset + length) > sizeof cbuf)) {
        printf("WARNING -- FMC EEPROM has bad board information.\n");
        return;
    }
    offset += 6;    /* Skip over language and date/time */
    for (field = 0 ; field < 4 ; field++) {
        uint8_t type_length = cbuf[offset];
        int fieldLength;
        const char *cp;
        int32_t number = 0;
        if (((type_length & 0xC0) != 0xC0)
         || (((fieldLength = (type_length & 0x3F)) + offset) > length)) {
            printf("WARNING -- FMC EEPROM has bad board information.\n");
            return;
        }
        switch (field) {
        case 0: cp = "Manufacturer";        break;
        case 1: cp = "Name";                break;
        case 2: cp = "Serial Number";       break;
        case 3: cp = "Part Number";         break;
        }
        printf("%15s: ", cp);
        offset++;
        i = 0;
        while (fieldLength--) {
            char c = cbuf[offset++];
            printf("%c", c);
            if (i < 63) {
                strBuf[i++] = c;
            }
            if ((c >= '0') && (c <= '9')) {
                number = (number * 10) + (c - '0');
            }
        }
        strBuf[i] = '\0';
        printf("\n");
        if ((index >= 0) && (index < FMC_COUNT)) {
            switch (field) {
            case 0:
                if (strcmp(strBuf, "Osprey") != 0) {
                    hardwareMatches = 0;
                    criticalWarning("Unexpected manufacturer ID");
                }
                break;
            case 1:
                if (strcmp(strBuf, "Quartz") != 0) {
                    hardwareMatches = 0;
                    criticalWarning("Unexpected name");
                }
                break;
            case 2:
                serialNumber[index] = number;
                break;
            case 3:
                if (strncasecmp(strBuf, "v2", 2) != 0) {
                    hardwareMatches = 0;
                    criticalWarning("Firmware requires Quartz V2");
                    number = -number;
                }
                partNumber[index] = number;
                break;
            }
        }
    }
    if (hardwareMatches) {
        ad7768EnableFMC();
    }
}

uint32_t
iicFPGAgetSerialNumber(int index)
{
    if ((index < 0) || (index >= FMC_COUNT)) {
        return -1;
    }
    return serialNumber[index];
}

uint32_t
iicFPGAgetPartNumber(int index)
{
    if ((index < 0) || (index >= FMC_COUNT)) {
        return -1;
    }
    return partNumber[index];
}

void
iicFPGAinit(void)
{
    int i;
    uint32_t whenStarted;
    unsigned char cbuf[3];
    if (XIic_DynInit(XPAR_IIC_FPGA_BASEADDR) != XST_SUCCESS) {
        printf("XIic_DynInit failed!");
        return;
    }
    /* Remove reset */
    XIic_WriteReg(XPAR_IIC_FPGA_BASEADDR, XIIC_GPO_REG_OFFSET, 0x1);
    whenStarted = microsecondsSinceBoot();
    while ((XIic_ReadReg(XPAR_IIC_FPGA_BASEADDR, XIIC_SR_REG_OFFSET) &
                                                (XIIC_SR_RX_FIFO_EMPTY_MASK |
                                                 XIIC_SR_TX_FIFO_EMPTY_MASK |
                                                 XIIC_SR_BUS_BUSY_MASK)) !=
                                                 (XIIC_SR_RX_FIFO_EMPTY_MASK |
                                                  XIIC_SR_TX_FIFO_EMPTY_MASK)) {
        if ((microsecondsSinceBoot() - whenStarted) > 1000000) {
            printf("iicInit -- Not ready");
            return;
        }
    }

    /*
     * Assert both ModSelL lines.
     */
    cbuf[0] = 0x06;
    cbuf[1] = 0x3F;
    cbuf[2] = 0x3F;
    iicFPGAwrite(IIC_FPGA_IDX_PCA9555_U34, cbuf, 3);
    cbuf[0] = 0x02;
    cbuf[1] = 0x7F;
    cbuf[2] = 0x7F;
    iicFPGAwrite(IIC_FPGA_IDX_PCA9555_U34, cbuf, 3);

    /*
     * Check QSFP presence
     */
    iicFPGAread(IIC_FPGA_IDX_PCA9555_U34, 0, cbuf, 2);
    for (i = 0 ; i < 2 ; i++) {
        /*
         * Turn on all transmitters.
         */
        static const unsigned char txBuf[2] = { 86, 0x00 };
        if (((cbuf[i] & 0x20) != 0)
         || (iicFPGAwrite(IIC_FPGA_IDX_QSFP1+i, txBuf, 2) != 2)) {
            printf("QSFP%d not present (U34 P%d:%02X)!\n", i+1, i, cbuf[i]);
            iicMap[IIC_FPGA_IDX_QSFP1+i].address7 = 0;
        }
    }

    /*
     * Find FMC EEPROMs
     * The address can vary which is why the iicMap table can't be 'const'.
     */
    for (i = 0 ; i < FMC_COUNT ; i++) {
        int a;
        iicMap[IIC_FPGA_IDX_FMC1_EEPROM+i].address7 = 0;
        for (a = 0x50 ; a <= 0x57 ; a++) {
            if (isPresent(iicMap[IIC_FPGA_IDX_FMC1_EEPROM+i].muxValue, a)) {
                iicMap[IIC_FPGA_IDX_FMC1_EEPROM+i].address7 = a;
                printf("FMC%d EEPROM at 0x%2x:\n", i + 1, a);
                showIPMI(i);
                break;
            }
        }
    }

    /*
     * Check boot flash write-protect switch
     */
    if (iicFPGAread(IIC_FPGA_IDX_PCA9555_U39, 0, cbuf, 2) != 2) {
        printf("Can't read from U39!\n");
    }
    else {
        printf("Boot flash write %sed.\n", (cbuf[0]&0x80)?"enabl":"protect");
        if ((cbuf[0] & 0x80) == 0) {
            bootFlashProtectGolden();
        }
    }
}

static int
muxForIDX(unsigned int idx)
{
    if (idx >= (sizeof iicMap / sizeof iicMap[0])) return 0;
    return setMux(iicMap[idx].muxValue);
}

int
iicFPGAwrite(int idx, const unsigned char *buf, int count)
{
    int address7;
    if (!muxForIDX(idx) || ((address7 = iicMap[idx].address7) == 0)) return -1;
    address7 = iicMap[idx].address7;
    return XIic_DynSend(XPAR_IIC_FPGA_BASEADDR, address7, (unsigned char *)buf,
                                                              count, XIIC_STOP);
}

int
iicFPGAread(int idx, int subaddress, unsigned char *buf, int count)
{
    int address7;
    /*
     * XIIC dynamic operation can read at most 255 bytes
     */
    if (!muxForIDX(idx)
     || ((address7 = iicMap[idx].address7) == 0)
     || (count >= 256)) {
        return -1;
    }
    if (subaddress >= 0) {
        unsigned char c = subaddress;
        if (XIic_DynSend(XPAR_IIC_FPGA_BASEADDR, address7, &c, 1,
                                                    XIIC_REPEATED_START) != 1) {
            return -1;
        }
    }
    return XIic_DynRecv(XPAR_IIC_FPGA_BASEADDR, address7, buf, count);
}

/*
 * Read n bytes from EEPROM
 */
int
iicFPGAeepromRead(int idx, uint32_t address, uint32_t length, void *buf)
{
    int nLeft = length;
    int address7;
    int addressBytes;
    unsigned char *cp = buf;
    unsigned char cbuf[2];

    if (!muxForIDX(idx) || ((address7 = iicMap[idx].address7) == 0)) return -1;
    while (nLeft) {
        int nReq = nLeft;
        /*
         * QSFP 'EEPROM' reads are limited to 128 bytes.
         */
        if (nReq >= 128) nReq = 128;
        if (address7 >= 0x54) {
            addressBytes = 2;
            cbuf[0] = address >> 8;
            cbuf[1] = address;
        }
        else {
            addressBytes = 1;
            cbuf[0] = address;
        }
        if (XIic_DynSend(XPAR_IIC_FPGA_BASEADDR, address7, cbuf, addressBytes,
                                         XIIC_REPEATED_START) != addressBytes) {
            break;
        }
        if (iicFPGAread(idx, -1, cp, nReq) != nReq) {
            break;
        }
        cp += nReq;
        address += nReq;
        nLeft -= nReq;
    }
    return length - nLeft;
}

/*
 * Write n bytes to EEPROM
 */
int iicFPGAeepromWrite(int idx, uint32_t address, uint32_t length,
                                                                const void *buf)
{
    int address7;
    int addressBytes;
    /*
     * All devices should be able to handle a page size of 16, but things
     * lock up when I try that.  Perhaps there's an issue in the XIIC code
     * with writes larger than the transmitter FIFO?
     * The easy way out is just to limit the write size.
     */
    const int pageSize = 8;
    const unsigned char *cp = buf;
    unsigned char cbuf[2+pageSize];

    if (!muxForIDX(idx) || ((address7 = iicMap[idx].address7) == 0)) return -1;
    if (length) {
        int nRemaining = length;
        for (;;) {
            uint32_t then;
            int writeSize, nSend = nRemaining;
            if (address7 >= 0x54) {
                addressBytes = 2;
                cbuf[0] = address >> 8;
                cbuf[1] = address;
            }
            else {
                addressBytes = 1;
                cbuf[0] = address;
            }
            if (nSend > pageSize) nSend = pageSize;
            memcpy(&cbuf[addressBytes], cp, nSend);
            writeSize = addressBytes + nSend;
            if (iicFPGAwrite(idx, cbuf, writeSize) != writeSize) {
                return -1;
            }
            /*
             * Poll for completion
             */
            then = microsecondsSinceBoot();
            while (iicFPGAwrite(idx, cbuf, 1) != 1) {
                if ((microsecondsSinceBoot() - then) > 20000) {
                    printf("EEPROM write failed to complete.\n");
                    return -1;
                }
            }
            nRemaining -= nSend;
            if (nRemaining == 0) {
                break;
            }
            cp += nSend;
            address += nSend;
        }
    }
    return length;
}

uint32_t
iicFPGAfetchSysmon(int index)
{
    uint32_t now = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    static uint32_t whenScanned;
    static uint16_t sysmonBuf[SYSMON_BUF_CAPACITY];

    /*
     * Update at most every five seconds
     */
    if ((now - whenScanned) >= 5) {
        int i;
        uint16_t *sp = sysmonBuf;
        unsigned char cbuf[8];
        whenScanned = now;

        /*
         * INA219 power monitors
         */
        for (i = IIC_FPGA_IDX_INA219_0 ; i <= IIC_FPGA_IDX_INA219_2 ; i++) {
            int vBus = 0, vShunt = 0;
            if (iicFPGAread(i, 0x02, cbuf, 2) == 2) {
                vBus = (cbuf[0] << 5) | (cbuf[1] >> 3);
            }
            if (iicFPGAread(i, 0x01, cbuf, 2) == 2) {
                vShunt = (int16_t)((cbuf[0] << 8) | cbuf[1]);
            }
            *sp++ = vShunt;
            *sp++ = vBus;
        }

        /*
         * QSFP
         */
        for (i = IIC_FPGA_IDX_QSFP1 ; i <= IIC_FPGA_IDX_QSFP2 ; i++) {
            int r;
            uint16_t temp = 0;
            uint16_t vcc = 0;
            uint16_t rxPower[4] = {0, 0, 0, 0};
            if (iicMap[i].address7) {
                if (iicFPGAread(i, 22, cbuf, 6) == 6) {
                    temp = (cbuf[0] << 8) | cbuf[1];
                    vcc  = (cbuf[4] << 8) | cbuf[5];
                }
                if (iicFPGAread(i, 34, cbuf, 8) == 8) {
                    for (r = 0 ; r < 4 ; r++) {
                        rxPower[r] = (cbuf[(2*r)+0] << 8) | cbuf[(2*r)+1];
                    }
                }
            }
            else {
                temp = vcc = 0;
                for (r = 0 ; r < 4 ; r++) {
                    rxPower[r] = 0;
                }
            }
            *sp++ = temp;
            *sp++ = vcc;
            for (r = 0 ; r < 4 ; r++) {
                *sp++ = rxPower[r];
            }
        }
    }
    if ((index >= 0) && (index < SYSMON_BUF_CAPACITY)) {
        return sysmonBuf[index];
    }
    return 0;
}

/*
 * Scan I2C buses
 */
void
iicFPGAscan(void)
{
    int bus, a;
    printf("IIC Devices (7 bit addresses (hex))\n");
    for (bus = 0 ; bus < 8 ; bus++) {
        int first = 1;
        for (a = 1 ; a < 128 ; a++) {
            if (isPresent(1 << bus, a)) {
                if (first) {
                    printf("Bus %d:", bus);
                }
                printf("%s %02X", first ? "" : ",", a);
                first = 0;
            }
        }
        if (!first) {
            printf("\n");
        }
    }
}
