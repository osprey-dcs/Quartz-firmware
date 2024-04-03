/*
 * Communicate with microcontroller
 */
#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include "gpio.h"
#include "mmcMailbox.h"
#include "systemParameters.h"
#include "util.h"

#define MMC_MAILBOX_CAPACITY    (1 << 11)

#define CSR_WRITE_ENABLE    (1UL << 31)
#define CSR_ADDR_SHIFT      16
#define CSR_NETCONFIG_SHIFT 8
#define CSR_DATA_MASK       0xFF

struct networkConfig networkConfig;

/*
 * Mailboxes
 *
 * Page 2, location 0 controls MGT4-7 routing:
 *    MUX3   MUX2   MUX1      MGT4         MGT5         MGT6         MGT7
 *      0      0      0     FCM2-DP0     FMC2-DP1     FMC2-DP2     FMC1-DP1
 *      0      0      1     FCM2-DP0     FMC2-DP1     FMC1-DP0     FMC1-DP1
 *      0      1      0     FCM2-DP0     FMC2-DP1     FMC2-DP2     FMC2-DP3
 *      0      1      1     FCM2-DP0     FMC2-DP1     FMC1-DP0     FMC2-DP3
 *      1      X      X    QSFP2:4/9    QSFP2:1/12   QSFP2:2/11   QSFP2:3/10
 *
 * Tile 115-0 -- MGT_[RT]X_4 -- MGT_[RT]X_4_FMC2 -- FMC2-DP0
 *                           or MGT_[RT]X_4_QSFP -- QSFP2_[RT]X_3 -- QSFP:3/10
 *
 * Tile 115-1 -- MGT_[RT]X_5 -- MGT_[RT]X_5_FMC2 -- FMC2-DP1
 *                           or MGT_[RT]X_5_QSFP -- QSFP2_[RT]X_0 -- QSFP:1/12
 *
 * Tile 115-2 -- MGT_[RT]X_6 -- MGT_[RT]X_6_FMC -- MGT_[RT]X_6_FMC2 -- FMC2-DP2
 *                                              or MGT_[RT]X_6_FMC1 -- FMC1-DP0
 *                           or MGT_[RT]X_6_QSFP -- QSFP2_[RT]X_1 -- QSFP:2/11
 *
 * Tile 115-3 -- MGT_[RT]X_7 -- MGT_[RT]X_7_FMC -- MGT_[RT]X_7_FMC1 -- FMC1-DP1
 *                                              or MGT_[RT]X_7_FMC2 -- FMC2-DP3
 *                           or MGT_[RT]X_7_QSFP -- QSFP2_[RT]X_2 -- QSFP:4/9
 *
 * QSFP:x/y specify fibers x and y on the 'squid'.
 *
 * Bank 115-[0-3] are X0Y[0-3]
 * Bank 116-[0-3] are X0Y[4-7]
 *
 * QSFP1 is J17, QSFP2 is J8.
 */
#define MADDR_MGT_CONFIG    0x20  /* Page 2, location 0 */
#define MADDR_U29_TEMP      0x34
#define MADDR_U28_TEMP      0x36
#define MADDR_MMC_BUILD     0x3C

/*
 * Page 2, location 0 controls MGT4-7 routing and FMC power.
 *   4 pairs of bits: High bit enables configuration bit update.
 *                    Low bit is new state or "no change" if high bit clear.
 */
# define MGT_CONFIG_SET_MUX3       0xC0
# define MGT_CONFIG_CLR_MUX3       0x80
# define MGT_CONFIG_SET_MUX2       0x30
# define MGT_CONFIG_CLR_MUX2       0x20
# define MGT_CONFIG_SET_MUX1       0x0C
# define MGT_CONFIG_CLR_MUX1       0x08
# define MGT_CONFIG_SET_FMC        0x03
# define MGT_CONFIG_CLR_FMC        0x02
/* MGT6:FMC1-DP0, MGT4:FMC2-DP0, FMC on */
# define MGT_CONFIG_FMC (MGT_CONFIG_CLR_MUX3 | MGT_CONFIG_SET_MUX2 | \
                         MGT_CONFIG_SET_MUX1 | MGT_CONFIG_SET_FMC)
/* MGT6:QSFP2:2/11, MGT4:QSFP2:3/10, FMC on */
# define MGT_CONFIG_QSFP (MGT_CONFIG_SET_MUX3 | MGT_CONFIG_SET_FMC)

void
mmcMailboxWrite(unsigned int address, int value)
{
    if (address < MMC_MAILBOX_CAPACITY) {
        GPIO_WRITE(GPIO_IDX_MMC_IO, (address << CSR_ADDR_SHIFT) |
                                    CSR_WRITE_ENABLE | (value & CSR_DATA_MASK));
    }
}

void
mmcMailboxWriteAndWait(unsigned int address, int value)
{
    uint32_t then;
    int v;
    mmcMailboxWrite(address, value);
    then = microsecondsSinceBoot();
    while (((v = GPIO_READ(GPIO_IDX_MMC_IO) & CSR_DATA_MASK)) == value) {
        if ((microsecondsSinceBoot() - then) > 5000000) {
            printf("mmcMailboxWriteAndWait(%02X@%02x) timeout!\n", v, address);
            return;
        }
    }
}

static int
mmcMailboxSetReadAddress(unsigned int address)
{
    if (address < MMC_MAILBOX_CAPACITY) {
        GPIO_WRITE(GPIO_IDX_MMC_IO, (address << CSR_ADDR_SHIFT));
        return 0;
    }
    else {
        return -1;
    }
}

int
mmcMailboxRead(unsigned int address)
{
    if (mmcMailboxSetReadAddress(address) < 0) return -1;
    return GPIO_READ(GPIO_IDX_MMC_IO) & CSR_DATA_MASK;
}

int
mmcNetworkConfiguration(unsigned int address)
{
    if (mmcMailboxSetReadAddress(address) < 0) return -1;
    return (GPIO_READ(GPIO_IDX_MMC_IO) >> CSR_NETCONFIG_SHIFT) & CSR_DATA_MASK;
}

static int
mmcMailboxRead16(unsigned int address)
{
    uint32_t vOld = 0x10000; /* Ensure mismatch the first time through */
    for (;;) {
        uint32_t v = (mmcMailboxRead(address) << 8) | mmcMailboxRead(address+1);
        if (v == vOld) return (int16_t)v;
        vOld = v;
    }
}

static void
showLM75temperature(int id, int address)
{
    int v = mmcMailboxRead16(address);
    printf("  U%d: %d.%d C\n", id, v / 2, (v & 0x1) * 5);
}

static void
showMMCfirmware(void)
{
    int i;
    printf("  Firmware: ");
    for (i = 0 ; i < 4 ; i++) {
        int c = mmcMailboxRead(MADDR_MMC_BUILD + i);
        printf("%02X", c);
    }
    printf("\n");
}

static void
fetchNetworkConfig(void)
{
    int i;
    char sep = ' ';
    printf("  MAC address:");
    for (i = 0 ; i < 6 ; i++) {
        int v = mmcNetworkConfiguration(i);
        networkConfig.macAddress[i] = v;
        printf("%c%02X", sep, v);
        sep = ':';
    }
    printf("\n");
    networkConfig.ipv4address = 0;
    for (i = 0 ; i < 4 ; i++) {
        int v = mmcNetworkConfiguration(i + 6);
        networkConfig.ipv4address = (networkConfig.ipv4address << 8) | v; 
    }
    showIPv4address("address", networkConfig.ipv4address);
}

void
mmcMailboxInit(void)
{
    uint32_t then;
    then = microsecondsSinceBoot();
    while (mmcMailboxRead16(MADDR_U28_TEMP) == 0) {
        if ((microsecondsSinceBoot() - then) > 5000000) {
            printf("Can't communicate with microcontroller!\n");
            networkConfig.ipv4address = (192 << 24) |
                                        (168 << 16) |
                                        ( 19 <<  8) |
                                         254;
            networkConfig.macAddress[0] = 0x02;
            networkConfig.macAddress[1] = 0xB0;
            networkConfig.macAddress[2] = 0xBD;
            networkConfig.macAddress[3] = 0x03;
            networkConfig.macAddress[4] = 0x04;
            networkConfig.macAddress[5] = 0x05;
            return;
        }
    }
    printf("Microcontroller:\n");
    showLM75temperature(28, MADDR_U28_TEMP);
    showLM75temperature(29, MADDR_U29_TEMP);
    showMMCfirmware();
    mmcMailboxWriteAndWait(MADDR_MGT_CONFIG, MGT_CONFIG_QSFP);
    fetchNetworkConfig();
}

uint32_t
mmcMailboxFetchSysmon(int index)
{
    switch (index) {
    case 0: return mmcMailboxRead16(MADDR_U29_TEMP) << 16;
    case 1: return mmcMailboxRead16(MADDR_U28_TEMP) & 0xFFFF;
    }
    return 0;
}
