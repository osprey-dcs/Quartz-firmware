# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_S_AXI_LITE_BASEADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_LITE_HIGHADDR" -parent ${Page_0}

  set ENABLE_ICMP_ECHO [ipgui::add_param $IPINST -name "ENABLE_ICMP_ECHO"]
  set_property tooltip {Enable ICMP ECHO (ping)} ${ENABLE_ICMP_ECHO}
  set DEBUG_ICMP [ipgui::add_param $IPINST -name "DEBUG_ICMP"]
  set_property tooltip {Enable MARK_DEBUG for ICMP ECHO nets} ${DEBUG_ICMP}
  set DEBUG_AXI [ipgui::add_param $IPINST -name "DEBUG_AXI"]
  set_property tooltip {Set MARK_DEBUG attribute on AXI-related nets} ${DEBUG_AXI}
  set DEBUG_RX [ipgui::add_param $IPINST -name "DEBUG_RX"]
  set_property tooltip {Enable MARK_DEBUG attribute for receiver state machine nets} ${DEBUG_RX}
  set DEBUG_RX_UDP [ipgui::add_param $IPINST -name "DEBUG_RX_UDP"]
  set_property tooltip {Enable MARK_DEBUG attribute for receiver UDP nets} ${DEBUG_RX_UDP}
  set DEBUG_TX [ipgui::add_param $IPINST -name "DEBUG_TX"]
  set_property tooltip {Enable MARK_DEBUG attribute for transmitter state machine nets} ${DEBUG_TX}
  set DEBUG_TX_UDP [ipgui::add_param $IPINST -name "DEBUG_TX_UDP"]
  set_property tooltip {Enable MARK_DEBUG attribute for transmitter UDP nets} ${DEBUG_TX_UDP}
  set DEBUG_TX_MAC [ipgui::add_param $IPINST -name "DEBUG_TX_MAC"]
  set_property tooltip {Enable MARK_DEBUG attribute for transmitter MAC nets} ${DEBUG_TX_MAC}
  ipgui::add_param $IPINST -name "DEBUG_TX_FAST"
  set DEBUG_RX_MAC [ipgui::add_param $IPINST -name "DEBUG_RX_MAC"]
  set_property tooltip {Enable MARK_DEBUG attribute for receiver MAC nets} ${DEBUG_RX_MAC}
  set RX_FIFO_DEPTH [ipgui::add_param $IPINST -name "RX_FIFO_DEPTH" -widget comboBox]
  set_property tooltip {Number of bytes in FIFO from PHY} ${RX_FIFO_DEPTH}

}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DEBUG_AXI { PARAM_VALUE.DEBUG_AXI } {
	# Procedure called to update DEBUG_AXI when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_AXI { PARAM_VALUE.DEBUG_AXI } {
	# Procedure called to validate DEBUG_AXI
	return true
}

proc update_PARAM_VALUE.DEBUG_ICMP { PARAM_VALUE.DEBUG_ICMP } {
	# Procedure called to update DEBUG_ICMP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_ICMP { PARAM_VALUE.DEBUG_ICMP } {
	# Procedure called to validate DEBUG_ICMP
	return true
}

proc update_PARAM_VALUE.DEBUG_RX { PARAM_VALUE.DEBUG_RX } {
	# Procedure called to update DEBUG_RX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_RX { PARAM_VALUE.DEBUG_RX } {
	# Procedure called to validate DEBUG_RX
	return true
}

proc update_PARAM_VALUE.DEBUG_RX_MAC { PARAM_VALUE.DEBUG_RX_MAC } {
	# Procedure called to update DEBUG_RX_MAC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_RX_MAC { PARAM_VALUE.DEBUG_RX_MAC } {
	# Procedure called to validate DEBUG_RX_MAC
	return true
}

proc update_PARAM_VALUE.DEBUG_RX_UDP { PARAM_VALUE.DEBUG_RX_UDP } {
	# Procedure called to update DEBUG_RX_UDP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_RX_UDP { PARAM_VALUE.DEBUG_RX_UDP } {
	# Procedure called to validate DEBUG_RX_UDP
	return true
}

proc update_PARAM_VALUE.DEBUG_TX { PARAM_VALUE.DEBUG_TX } {
	# Procedure called to update DEBUG_TX when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_TX { PARAM_VALUE.DEBUG_TX } {
	# Procedure called to validate DEBUG_TX
	return true
}

proc update_PARAM_VALUE.DEBUG_TX_MAC { PARAM_VALUE.DEBUG_TX_MAC } {
	# Procedure called to update DEBUG_TX_MAC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_TX_MAC { PARAM_VALUE.DEBUG_TX_MAC } {
	# Procedure called to validate DEBUG_TX_MAC
	return true
}

proc update_PARAM_VALUE.DEBUG_TX_UDP { PARAM_VALUE.DEBUG_TX_UDP } {
	# Procedure called to update DEBUG_TX_UDP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_TX_UDP { PARAM_VALUE.DEBUG_TX_UDP } {
	# Procedure called to validate DEBUG_TX_UDP
	return true
}

proc update_PARAM_VALUE.ENABLE_ICMP_ECHO { PARAM_VALUE.ENABLE_ICMP_ECHO } {
	# Procedure called to update ENABLE_ICMP_ECHO when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_ICMP_ECHO { PARAM_VALUE.ENABLE_ICMP_ECHO } {
	# Procedure called to validate ENABLE_ICMP_ECHO
	return true
}

proc update_PARAM_VALUE.PKBUF_CAPACITY { PARAM_VALUE.PKBUF_CAPACITY } {
	# Procedure called to update PKBUF_CAPACITY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PKBUF_CAPACITY { PARAM_VALUE.PKBUF_CAPACITY } {
	# Procedure called to validate PKBUF_CAPACITY
	return true
}

proc update_PARAM_VALUE.RX_FIFO_DEPTH { PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to update RX_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RX_FIFO_DEPTH { PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to validate RX_FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.DEBUG_TX_FAST { PARAM_VALUE.DEBUG_TX_FAST } {
	# Procedure called to update DEBUG_TX_FAST when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG_TX_FAST { PARAM_VALUE.DEBUG_TX_FAST } {
	# Procedure called to validate DEBUG_TX_FAST
	return true
}

proc update_PARAM_VALUE.C_S_AXI_LITE_BASEADDR { PARAM_VALUE.C_S_AXI_LITE_BASEADDR } {
	# Procedure called to update C_S_AXI_LITE_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_LITE_BASEADDR { PARAM_VALUE.C_S_AXI_LITE_BASEADDR } {
	# Procedure called to validate C_S_AXI_LITE_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_S_AXI_LITE_HIGHADDR { PARAM_VALUE.C_S_AXI_LITE_HIGHADDR } {
	# Procedure called to update C_S_AXI_LITE_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_LITE_HIGHADDR { PARAM_VALUE.C_S_AXI_LITE_HIGHADDR } {
	# Procedure called to validate C_S_AXI_LITE_HIGHADDR
	return true
}


proc update_MODELPARAM_VALUE.PKBUF_CAPACITY { MODELPARAM_VALUE.PKBUF_CAPACITY PARAM_VALUE.PKBUF_CAPACITY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PKBUF_CAPACITY}] ${MODELPARAM_VALUE.PKBUF_CAPACITY}
}

proc update_MODELPARAM_VALUE.DEBUG_AXI { MODELPARAM_VALUE.DEBUG_AXI PARAM_VALUE.DEBUG_AXI } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_AXI}] ${MODELPARAM_VALUE.DEBUG_AXI}
}

proc update_MODELPARAM_VALUE.DEBUG_RX { MODELPARAM_VALUE.DEBUG_RX PARAM_VALUE.DEBUG_RX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_RX}] ${MODELPARAM_VALUE.DEBUG_RX}
}

proc update_MODELPARAM_VALUE.DEBUG_RX_UDP { MODELPARAM_VALUE.DEBUG_RX_UDP PARAM_VALUE.DEBUG_RX_UDP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_RX_UDP}] ${MODELPARAM_VALUE.DEBUG_RX_UDP}
}

proc update_MODELPARAM_VALUE.DEBUG_TX { MODELPARAM_VALUE.DEBUG_TX PARAM_VALUE.DEBUG_TX } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_TX}] ${MODELPARAM_VALUE.DEBUG_TX}
}

proc update_MODELPARAM_VALUE.DEBUG_TX_UDP { MODELPARAM_VALUE.DEBUG_TX_UDP PARAM_VALUE.DEBUG_TX_UDP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_TX_UDP}] ${MODELPARAM_VALUE.DEBUG_TX_UDP}
}

proc update_MODELPARAM_VALUE.DEBUG_TX_MAC { MODELPARAM_VALUE.DEBUG_TX_MAC PARAM_VALUE.DEBUG_TX_MAC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_TX_MAC}] ${MODELPARAM_VALUE.DEBUG_TX_MAC}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.ENABLE_ICMP_ECHO { MODELPARAM_VALUE.ENABLE_ICMP_ECHO PARAM_VALUE.ENABLE_ICMP_ECHO } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_ICMP_ECHO}] ${MODELPARAM_VALUE.ENABLE_ICMP_ECHO}
}

proc update_MODELPARAM_VALUE.DEBUG_ICMP { MODELPARAM_VALUE.DEBUG_ICMP PARAM_VALUE.DEBUG_ICMP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_ICMP}] ${MODELPARAM_VALUE.DEBUG_ICMP}
}

proc update_MODELPARAM_VALUE.DEBUG_TX_FAST { MODELPARAM_VALUE.DEBUG_TX_FAST PARAM_VALUE.DEBUG_TX_FAST } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_TX_FAST}] ${MODELPARAM_VALUE.DEBUG_TX_FAST}
}

proc update_MODELPARAM_VALUE.DEBUG_RX_MAC { MODELPARAM_VALUE.DEBUG_RX_MAC PARAM_VALUE.DEBUG_RX_MAC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG_RX_MAC}] ${MODELPARAM_VALUE.DEBUG_RX_MAC}
}

proc update_MODELPARAM_VALUE.RX_FIFO_DEPTH { MODELPARAM_VALUE.RX_FIFO_DEPTH PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RX_FIFO_DEPTH}] ${MODELPARAM_VALUE.RX_FIFO_DEPTH}
}

