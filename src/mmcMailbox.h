/*
 * Communicate with microcontroller
 */

#ifndef _MMC_MAILBOX_H_
#define _MMC_MAILBOX_H_

#include <stdint.h>

void mmcMailboxInit(void);
void mmcMailboxWrite(unsigned int address, int valud);
int mmcMailboxRead(unsigned int address);
uint32_t mmcMailboxFetchSysmon(int index);

#endif /* _MMC_MAILBOX_H_ */
