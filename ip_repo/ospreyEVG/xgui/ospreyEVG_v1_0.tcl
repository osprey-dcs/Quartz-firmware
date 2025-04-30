# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_BASEADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_HIGHADDR" -parent ${Page_0}

  set DEBUG [ipgui::add_param $IPINST -name "DEBUG"]
  set_property tooltip {Enable MARK_DEBUG attribute on some nets} ${DEBUG}
  set EVGCLK_FREQUENCY [ipgui::add_param $IPINST -name "EVGCLK_FREQUENCY" -show_range false]
  set_property tooltip {Frequency of MGT transmitter clock} ${EVGCLK_FREQUENCY}
  set HW_TRIGGER_COUNT [ipgui::add_param $IPINST -name "HW_TRIGGER_COUNT"]
  set_property tooltip {Number of hardware trigger inputs} ${HW_TRIGGER_COUNT}
  set TIMER_COUNT [ipgui::add_param $IPINST -name "TIMER_COUNT"]
  set_property tooltip {TIMER_COUNT} ${TIMER_COUNT}

}

proc update_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to update DEBUG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBUG { PARAM_VALUE.DEBUG } {
	# Procedure called to validate DEBUG
	return true
}

proc update_PARAM_VALUE.EVGCLK_FREQUENCY { PARAM_VALUE.EVGCLK_FREQUENCY } {
	# Procedure called to update EVGCLK_FREQUENCY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.EVGCLK_FREQUENCY { PARAM_VALUE.EVGCLK_FREQUENCY } {
	# Procedure called to validate EVGCLK_FREQUENCY
	return true
}

proc update_PARAM_VALUE.HW_TRIGGER_COUNT { PARAM_VALUE.HW_TRIGGER_COUNT } {
	# Procedure called to update HW_TRIGGER_COUNT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HW_TRIGGER_COUNT { PARAM_VALUE.HW_TRIGGER_COUNT } {
	# Procedure called to validate HW_TRIGGER_COUNT
	return true
}

proc update_PARAM_VALUE.SEQRAM_ADDR_WIDTH { PARAM_VALUE.SEQRAM_ADDR_WIDTH } {
	# Procedure called to update SEQRAM_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SEQRAM_ADDR_WIDTH { PARAM_VALUE.SEQRAM_ADDR_WIDTH } {
	# Procedure called to validate SEQRAM_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.TIMER_COUNT { PARAM_VALUE.TIMER_COUNT } {
	# Procedure called to update TIMER_COUNT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIMER_COUNT { PARAM_VALUE.TIMER_COUNT } {
	# Procedure called to validate TIMER_COUNT
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_BASEADDR { PARAM_VALUE.C_S_AXI_BASEADDR } {
	# Procedure called to update C_S_AXI_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_BASEADDR { PARAM_VALUE.C_S_AXI_BASEADDR } {
	# Procedure called to validate C_S_AXI_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_S_AXI_HIGHADDR { PARAM_VALUE.C_S_AXI_HIGHADDR } {
	# Procedure called to update C_S_AXI_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_HIGHADDR { PARAM_VALUE.C_S_AXI_HIGHADDR } {
	# Procedure called to validate C_S_AXI_HIGHADDR
	return true
}


proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.DEBUG { MODELPARAM_VALUE.DEBUG PARAM_VALUE.DEBUG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBUG}] ${MODELPARAM_VALUE.DEBUG}
}

proc update_MODELPARAM_VALUE.EVGCLK_FREQUENCY { MODELPARAM_VALUE.EVGCLK_FREQUENCY PARAM_VALUE.EVGCLK_FREQUENCY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.EVGCLK_FREQUENCY}] ${MODELPARAM_VALUE.EVGCLK_FREQUENCY}
}

proc update_MODELPARAM_VALUE.HW_TRIGGER_COUNT { MODELPARAM_VALUE.HW_TRIGGER_COUNT PARAM_VALUE.HW_TRIGGER_COUNT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HW_TRIGGER_COUNT}] ${MODELPARAM_VALUE.HW_TRIGGER_COUNT}
}

proc update_MODELPARAM_VALUE.TIMER_COUNT { MODELPARAM_VALUE.TIMER_COUNT PARAM_VALUE.TIMER_COUNT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIMER_COUNT}] ${MODELPARAM_VALUE.TIMER_COUNT}
}

proc update_MODELPARAM_VALUE.SEQRAM_ADDR_WIDTH { MODELPARAM_VALUE.SEQRAM_ADDR_WIDTH PARAM_VALUE.SEQRAM_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SEQRAM_ADDR_WIDTH}] ${MODELPARAM_VALUE.SEQRAM_ADDR_WIDTH}
}

