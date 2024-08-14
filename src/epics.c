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
 * Communicate with EPICS IOC using LBNL FEED protocol
 */
#include <stdio.h>
#include <ospreyUDP.h>
#include "acq.h"
#include "ad7768.h"
#include "ad7768recorder.h"
#include "amc7823.h"
#include "calibration.h"
#include "clockAdjust.h"
#include "epics.h"
#include "evg.h"
#include "gpio.h"
#include "iicFPGA.h"
#include "mgt.h"
#include "mmcMailbox.h"
#include "mpsLocal.h"
#include "mpsMerge.h"
#include "softwareBuildDate.h"
#include "systemParameters.h"
#include "util.h"
#include "xadc.h"

#define LEEP_UDP_PORT 50006
#define ETHERNET_UDP_PAYLOAD_CAPACITY   1472
#define LEEP_BYTES_TO_REG(b) (((b) - 8) / 8)
#define LEEP_REG_TO_BYTES(r) (((r) * 8) + 8)
#define LEEP_REG_CAPACITY LEEP_BYTES_TO_REG(ETHERNET_UDP_PAYLOAD_CAPACITY)
#define LEEP_BITS_READ      0x10000000
#define LEEP_ADDRESS_MASK   0x00FFFFFF

struct LEEPheader{
    char headerChars[8];
};
struct LEEPreg {
    uint32_t bits_addr;
    uint32_t value;
};
struct LEEPpacket {
    struct LEEPheader header;
    struct LEEPreg    regs[LEEP_REG_CAPACITY];
};

#define CHANNEL_COUNT ((CFG_AD7768_CHIP_COUNT) * (CFG_AD7768_ADC_PER_CHIP))
#define REG_POWERUP_STATE                   10
#define REG_FIRMWARE_BUILD_DATE             20
#define REG_SOFTWARE_BUILD_DATE             21
#define REG_CALIBRATION_DATE                22
#define REG_CALIBRATION_STATUS              23
#define REG_FPGA_REBOOT                     30
#define REG_SECONDS_SINCE_BOOT              40
#define REG_FMC1_SERIAL_NUMBER              50
#define REG_FMC2_SERIAL_NUMBER              51
#define REG_AD7768_RECORDER                 60
#define REG_AD7768_STATUSES                 65
#define REG_MPS_CLEAR                       70
#define REG_MPS_MERGE_TRIPPED               71
#define REG_MPS_MERGE_REQUIRED              72
#define REG_ACQ_ENABLE                      80
#define REG_SAMPLING_RATE                   81
#define REG_RESET_ADCS                      82
#define REG_SET_VCXO_DAC                    83
#define REG_GET_LOLO                        90
#define REG_GET_LO                          91
#define REG_GET_HI                          92
#define REG_GET_HIHI                        93
#define REG_SYSMON_BASE                     100
#define SYSMON_SIZE                         300
#define REG_ACQ_CHAN_ACTIVE_BASE            400
#define REG_ACQ_CHAN_COUPLING_BASE          500
#define REG_CALIB_CHAN_OFFSET_BASE          800
#define REG_CALIB_CHAN_GAIN_BASE            900
#define REG_LOLO_THRESHOLD_BASE             1000
#define REG_LO_THRESHOLD_BASE               1032
#define REG_HI_THRESHOLD_BASE               1064
#define REG_HIHI_THRESHOLD_BASE             1096
#define REG_MPS_LOLO_BITMAP_BASE            1200
#define REG_MPS_LO_BITMAP_BASE              1216
#define REG_MPS_HI_BITMAP_BASE              1232
#define REG_MPS_HIHI_BITMAP_BASE            1248
#define REG_MPS_DISCRETE_BITMAP_BASE        1264
#define REG_MPS_DISCRETE_GOOD_BASE          1280
#define REG_MPS_FIRST_FAULT_LOLO_BASE       1296
#define REG_MPS_FIRST_FAULT_LO_BASE         1312
#define REG_MPS_FIRST_FAULT_HI_BASE         1328
#define REG_MPS_FIRST_FAULT_HIHI_BASE       1344
#define REG_MPS_FIRST_FAULT_DISCRETE_BASE   1360
#define REG_MPS_FIRST_FAULT_SECONDS_BASE    1376
#define REG_MPS_FIRST_FAULT_TICKS_BASE      1392
#define REG_MPS_STATUS_BASE                 1408
#define REG_AD7768_HEADERS_BASE             1440
#define REG_JSON_ROM_BASE                   0x800

#define MATCH(addr, base, size) (((addr)>=(base)) && ((addr)<((base)+(size))))

static int powerUpFlag = 1;

static void
writeReg(int address, uint32_t value)
{
    switch(address) {
    case REG_POWERUP_STATE:     if (value == 0)   powerUpFlag = 0;       return;
    case REG_FPGA_REBOOT:       if (value == 100) resetFPGA(0);          return;
    case REG_ACQ_ENABLE:        if (isEVG())      evgAcqControl(value);  return;
    case REG_SAMPLING_RATE:     ad7768SetSamplingRate(value);            return;
    case REG_RESET_ADCS:        if (value == 40)  ad7768Reset();         return;
    case REG_SET_VCXO_DAC:      clockAdjustSet(value);                   return;
    case REG_AD7768_RECORDER:   ad7768recorderStart();                   return;
    case REG_MPS_CLEAR: if(isEVG()) evgSendEvent(CFG_EVR_MPS_CLEAR_CODE);return;
    case REG_MPS_MERGE_REQUIRED:mpsMergeSetRequiredLinks(value);         return;
    }
    if (MATCH(address, REG_ACQ_CHAN_ACTIVE_BASE, CHANNEL_COUNT)) {
        acqSetActive(address - REG_ACQ_CHAN_ACTIVE_BASE, value);
        return;
    }
    if (MATCH(address, REG_ACQ_CHAN_COUPLING_BASE, CHANNEL_COUNT)) {
        acqSetCoupling(address - REG_ACQ_CHAN_COUPLING_BASE, value);
        return;
    }
    if (MATCH(address, REG_LOLO_THRESHOLD_BASE, CHANNEL_COUNT)) {
        acqSetLOLOthreshold(address - REG_LOLO_THRESHOLD_BASE, value);
        return;
    }
    if (MATCH(address, REG_LO_THRESHOLD_BASE, CHANNEL_COUNT)) {
        acqSetLOthreshold(address - REG_LO_THRESHOLD_BASE, value);
        return;
    }
    if (MATCH(address, REG_HI_THRESHOLD_BASE, CHANNEL_COUNT)) {
        acqSetHIthreshold(address - REG_HI_THRESHOLD_BASE, value);
        return;
    }
    if (MATCH(address, REG_HIHI_THRESHOLD_BASE, CHANNEL_COUNT)) {
        acqSetHIHIthreshold(address - REG_HIHI_THRESHOLD_BASE, value);
        return;
    }
    if (MATCH(address, REG_MPS_LOLO_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        mpsLocalSetLOLObitmap(address - REG_MPS_LOLO_BITMAP_BASE, value);
        return;
    }
    if (MATCH(address, REG_MPS_LO_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        mpsLocalSetLObitmap(address - REG_MPS_LO_BITMAP_BASE, value);
        return;
    }
    if (MATCH(address, REG_MPS_HI_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        mpsLocalSetHIbitmap(address - REG_MPS_HI_BITMAP_BASE, value);
        return;
    }
    if (MATCH(address, REG_MPS_HIHI_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        mpsLocalSetHIHIbitmap(address - REG_MPS_HIHI_BITMAP_BASE, value);
        return;
    }
    if (MATCH(address, REG_MPS_DISCRETE_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        mpsLocalSetDiscreteBitmap(address - REG_MPS_DISCRETE_BITMAP_BASE,value);
        return;
    }
    if (MATCH(address, REG_MPS_DISCRETE_GOOD_BASE, CFG_MPS_OUTPUT_COUNT)) {
        mpsLocalSetDiscreteGoodState(address-REG_MPS_DISCRETE_GOOD_BASE,value);
        return;
    }
}

static uint32_t
readReg(int address)
{
    /*
     * Generic LEEP registers
     * The baseRegs initializer puts the string in network byte order.
     */
    union LEEPbaseRegs { char u_c[16]; uint32_t u_l[4]; };
    static const union LEEPbaseRegs baseRegs = {.u_c = "Hello World!\r\n\r\n"};
#   include "JSONrom.h"
    switch(address) {
    case 0: return ntohl(baseRegs.u_l[0]);
    case 1: return ntohl(baseRegs.u_l[1]);
    case 2: return ntohl(baseRegs.u_l[2]);
    case 3: return ntohl(baseRegs.u_l[3]);
    default:
        if ((address >= REG_JSON_ROM_BASE)
         && (address < (REG_JSON_ROM_BASE + ((sizeof config_romx / 2))))) {
            return config_romx[address-REG_JSON_ROM_BASE];
        }
        break;
    }

    /*
     * Application-specific registers
     */
    switch(address) {
    case REG_POWERUP_STATE:       return powerUpFlag;
    case REG_FIRMWARE_BUILD_DATE: return GPIO_READ(GPIO_IDX_FIRMWARE_DATE);
    case REG_SOFTWARE_BUILD_DATE: return SOFTWARE_BUILD_DATE;
    case REG_CALIBRATION_DATE:    return calibrationDate();
    case REG_CALIBRATION_STATUS:  return calibrationStatus();
    case REG_SECONDS_SINCE_BOOT:  return GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    case REG_FMC1_SERIAL_NUMBER:  return iicFPGAgetSerialNumber(0);
    case REG_FMC2_SERIAL_NUMBER:  return iicFPGAgetSerialNumber(1);
    case REG_AD7768_RECORDER:     return ad7768recorderIsBusy();
    case REG_AD7768_STATUSES:    return ad7768GetStatuses();
    case REG_MPS_MERGE_TRIPPED:   return mpsMergeGetTripped();
    case REG_MPS_MERGE_REQUIRED:  return mpsMergeGetRequiredLinks();
    }
    if (MATCH(address, REG_SYSMON_BASE, SYSMON_SIZE)) {
        int offset = address - REG_SYSMON_BASE;
        int bank = offset & 0xE0;
        int index = offset & 0x1F;
        switch (bank) {
        case 0x00:  return xadcFetchSysmon(index);
        case 0x20:  return mmcMailboxFetchSysmon(index);
        case 0x40:  return iicFPGAfetchSysmon(index);
        case 0x60:  return amc7823FetchSysmon(index);
        case 0x80:  return acqFetchSysmon(index);
        case 0xA0:  return clockAdjustFetchSysmon(index);
        case 0xC0:  return ad7768FetchSysmon(index);
        case 0xE0:  return mgtFetchSysmon(index);
        }
        return 0;
    }
    if (MATCH(address, REG_ACQ_CHAN_ACTIVE_BASE, SYSMON_SIZE)) {
        return acqGetActive(address - REG_ACQ_CHAN_ACTIVE_BASE);
    }
    if (MATCH(address, REG_ACQ_CHAN_COUPLING_BASE, CHANNEL_COUNT)) {
        return acqGetCoupling(address - REG_ACQ_CHAN_COUPLING_BASE);
    }
    if (MATCH(address, REG_GET_LOLO, 4)) {
        return acqGetLimitExcursions(address - REG_GET_LOLO);
    }
    if (MATCH(address, REG_CALIB_CHAN_OFFSET_BASE, CHANNEL_COUNT)) {
        return ad7768GetOfst(address - REG_CALIB_CHAN_OFFSET_BASE);
    }
    if (MATCH(address, REG_CALIB_CHAN_GAIN_BASE, CHANNEL_COUNT)) {
        return ad7768GetGain(address - REG_CALIB_CHAN_GAIN_BASE);
    }
    if (MATCH(address, REG_LOLO_THRESHOLD_BASE, CHANNEL_COUNT)) {
        return acqGetLOLOthreshold(address - REG_LOLO_THRESHOLD_BASE);
    }
    if (MATCH(address, REG_LO_THRESHOLD_BASE, CHANNEL_COUNT)) {
        return acqGetLOthreshold(address - REG_LO_THRESHOLD_BASE);
    }
    if (MATCH(address, REG_HI_THRESHOLD_BASE, CHANNEL_COUNT)) {
        return acqGetHIthreshold(address - REG_HI_THRESHOLD_BASE);
    }
    if (MATCH(address, REG_HIHI_THRESHOLD_BASE, CHANNEL_COUNT)) {
        return acqGetHIHIthreshold(address - REG_HIHI_THRESHOLD_BASE);
    }
    if (MATCH(address, REG_MPS_LOLO_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetLOLObitmap(address - REG_MPS_LOLO_BITMAP_BASE);
    }
    if (MATCH(address, REG_MPS_LO_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetLObitmap(address - REG_MPS_LO_BITMAP_BASE);
    }
    if (MATCH(address, REG_MPS_HI_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetHIbitmap(address - REG_MPS_HI_BITMAP_BASE);
    }
    if (MATCH(address, REG_MPS_HIHI_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetHIHIbitmap(address - REG_MPS_HIHI_BITMAP_BASE);
    }
    if (MATCH(address, REG_MPS_DISCRETE_BITMAP_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetDiscreteBitmap(address-REG_MPS_DISCRETE_BITMAP_BASE);
    }
    if (MATCH(address, REG_MPS_DISCRETE_GOOD_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetDiscreteGoodState(address-REG_MPS_DISCRETE_GOOD_BASE);
    }
    if (MATCH(address, REG_MPS_FIRST_FAULT_LOLO_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetFirstFaultLOLO(address-REG_MPS_FIRST_FAULT_LOLO_BASE);
    }
    if (MATCH(address, REG_MPS_FIRST_FAULT_LO_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetFirstFaultLO(address-REG_MPS_FIRST_FAULT_LO_BASE);
    }
    if (MATCH(address, REG_MPS_FIRST_FAULT_HI_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetFirstFaultHI(address-REG_MPS_FIRST_FAULT_HI_BASE);
    }
    if (MATCH(address, REG_MPS_FIRST_FAULT_HIHI_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetFirstFaultHIHI(address-REG_MPS_FIRST_FAULT_HIHI_BASE);
    }
    if (MATCH(address,REG_MPS_FIRST_FAULT_DISCRETE_BASE,CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetFirstFaultDiscrete(address -
                                             REG_MPS_FIRST_FAULT_DISCRETE_BASE);
    }
    if (MATCH(address, REG_MPS_FIRST_FAULT_TICKS_BASE,CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetFirstFaultTicks(address -
                                                REG_MPS_FIRST_FAULT_TICKS_BASE);
    }
    if (MATCH(address, REG_MPS_STATUS_BASE, CFG_MPS_OUTPUT_COUNT)) {
        return mpsLocalGetStatus(address - REG_MPS_STATUS_BASE);
    }
    if (MATCH(address, REG_AD7768_HEADERS_BASE, CHANNEL_COUNT)) {
        return ad7768GetHeader(address - REG_AD7768_HEADERS_BASE);
    }
    return 0;
}

/*
 * Handle an incoming packet
 */
static void
epicsHandler(ospreyUDPendpoint endpoint, uint32_t farAddress, int farPort,
                                                    const char *buf, int length)
{
    int i, regCount;
    struct LEEPpacket const *cmdp = (struct LEEPpacket const *)buf;
    struct LEEPreg const *cmdReg = &cmdp->regs[0];
    static struct LEEPpacket reply;
    struct LEEPreg *replyReg = &reply.regs[0];

    if (debugFlags & DEBUGFLAG_EPICS) {
        printf("LEEP %d from %d.%d.%d.%d:%d", length, (farAddress >> 24) & 0xFF,
                                                      (farAddress >> 16) & 0xFF,
                                                      (farAddress >>  8) & 0xFF,
                                                      (farAddress      ) & 0xFF,
                                                      farPort);
    }

    /*
     * Ignore packets that are clearly invalid
     */
    if ((length < LEEP_REG_TO_BYTES(1))
     || (length > LEEP_REG_TO_BYTES(LEEP_REG_CAPACITY))
     || (length != LEEP_REG_TO_BYTES((regCount = LEEP_BYTES_TO_REG(length))))) {
        if (debugFlags & DEBUGFLAG_EPICS) {
            printf("\n");
        }
        return;
    }
    reply.header = cmdp->header;

    /*
     * Process each register in turn
     */
    for (i = 0 ; i < regCount ; i++, cmdReg++, replyReg++) {
        uint32_t bits_addr = ntohl(cmdReg->bits_addr);
        uint32_t r;
        replyReg->bits_addr = cmdReg->bits_addr;
        if (bits_addr & LEEP_BITS_READ) {
            r = readReg(bits_addr & LEEP_ADDRESS_MASK);
            replyReg->value = htonl(r);
            if ((debugFlags & DEBUGFLAG_EPICS) && (i < 2)) {
                printf(" %d:%08Xr%08X", i, bits_addr, r);
            }
        }
        else {
            r = ntohl(cmdReg->value);
            if ((debugFlags & DEBUGFLAG_EPICS) && (i < 2)) {
                printf(" %d:%08Xw%08X", i, bits_addr, r);
            }
            writeReg(bits_addr & LEEP_ADDRESS_MASK, r);
            replyReg->value = cmdReg->value;
        }
    }
    if (debugFlags & DEBUGFLAG_EPICS) {
        printf("\n");
    }

    /*
     * Send the reply
     */
    ospreyUDPsendto(endpoint, farAddress, farPort, (char *)&reply, length);
}

/*
 * Create server
 */
void
epicsInit(void)
{
    if (ospreyUDPregisterEndpoint(LEEP_UDP_PORT, epicsHandler) == NULL) {
        printf("Can't register EPICS I/O UDP endpoint!\n");
    }
}
