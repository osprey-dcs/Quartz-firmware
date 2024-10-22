
/***************************** Include Files *******************************/
#include "axi_lite_generic_reg.h"
#include "xparameters.h"
#include "stdio.h"
#include "xil_io.h"

XStatus AXI_LITE_GENERIC_REG_Reg_SelfTest(void * baseaddr_p)
{
    *(volatile unsigned int *)baseaddr_p;
	return XST_SUCCESS;
}
