

proc generate {drv_handle} {
	xdefine_include_file $drv_handle "xparameters.h" "ospreyUDP" "NUM_INSTANCES" "DEVICE_ID"  "C_S_AXI_LITE_BASEADDR" "C_S_AXI_LITE_HIGHADDR"
}
