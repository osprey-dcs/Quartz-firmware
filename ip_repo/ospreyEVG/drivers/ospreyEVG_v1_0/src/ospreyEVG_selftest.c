#include "ospreyEVG.h"
#include "stdio.h"
#include "xil_io.h"

XStatus OSPREYEVR_Reg_SelfTest(void * baseaddr_p)
{
    unsigned int csr = *(volatile unsigned int *)baseaddr_p;
    int triggerCount = (csr & 0x0F0) >> 4;
    int timerCount   = (csr & 0xF00) >> 8;
    if ((triggerCount < 2)
     || (triggerCount > 12)
     || (timerCount < 2)
     || (timerCount > 8)) return XST_FAILURE;
	return XST_SUCCESS;
}
