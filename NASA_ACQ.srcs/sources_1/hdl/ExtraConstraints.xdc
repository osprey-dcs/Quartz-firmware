# Vivado-generated constraints (ChipScope, etc.)





create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list evr/mgtWrapper_i/MGT_i/inst/gt_usrclk_source/gt0_rxusrclk_out]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 5 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {evr/tinyEVR_i/tinyEVRcommon/bitsLeft[0]} {evr/tinyEVR_i/tinyEVRcommon/bitsLeft[1]} {evr/tinyEVR_i/tinyEVRcommon/bitsLeft[2]} {evr/tinyEVR_i/tinyEVRcommon/bitsLeft[3]} {evr/tinyEVR_i/tinyEVRcommon/bitsLeft[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 2 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {evr/tinyEVR_i/tinyEVRcommon/evrCharIsK[0]} {evr/tinyEVR_i/tinyEVRcommon/evrCharIsK[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[0]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[1]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[2]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[3]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[4]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[5]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[6]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[7]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[8]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[9]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[10]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[11]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[12]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[13]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[14]} {evr/tinyEVR_i/tinyEVRcommon/evrRxWord[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {evr/tinyEVR_i/evrCharIsK[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 8 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {evr/tinyEVR_i/distributedDataBus[0]} {evr/tinyEVR_i/distributedDataBus[1]} {evr/tinyEVR_i/distributedDataBus[2]} {evr/tinyEVR_i/distributedDataBus[3]} {evr/tinyEVR_i/distributedDataBus[4]} {evr/tinyEVR_i/distributedDataBus[5]} {evr/tinyEVR_i/distributedDataBus[6]} {evr/tinyEVR_i/distributedDataBus[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 16 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {evr/tinyEVR_i/evrRxWord[0]} {evr/tinyEVR_i/evrRxWord[1]} {evr/tinyEVR_i/evrRxWord[2]} {evr/tinyEVR_i/evrRxWord[3]} {evr/tinyEVR_i/evrRxWord[4]} {evr/tinyEVR_i/evrRxWord[5]} {evr/tinyEVR_i/evrRxWord[6]} {evr/tinyEVR_i/evrRxWord[7]} {evr/tinyEVR_i/evrRxWord[8]} {evr/tinyEVR_i/evrRxWord[9]} {evr/tinyEVR_i/evrRxWord[10]} {evr/tinyEVR_i/evrRxWord[11]} {evr/tinyEVR_i/evrRxWord[12]} {evr/tinyEVR_i/evrRxWord[13]} {evr/tinyEVR_i/evrRxWord[14]} {evr/tinyEVR_i/evrRxWord[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 64 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {evr/tinyEVR_i/timestamp[0]} {evr/tinyEVR_i/timestamp[1]} {evr/tinyEVR_i/timestamp[2]} {evr/tinyEVR_i/timestamp[3]} {evr/tinyEVR_i/timestamp[4]} {evr/tinyEVR_i/timestamp[5]} {evr/tinyEVR_i/timestamp[6]} {evr/tinyEVR_i/timestamp[7]} {evr/tinyEVR_i/timestamp[8]} {evr/tinyEVR_i/timestamp[9]} {evr/tinyEVR_i/timestamp[10]} {evr/tinyEVR_i/timestamp[11]} {evr/tinyEVR_i/timestamp[12]} {evr/tinyEVR_i/timestamp[13]} {evr/tinyEVR_i/timestamp[14]} {evr/tinyEVR_i/timestamp[15]} {evr/tinyEVR_i/timestamp[16]} {evr/tinyEVR_i/timestamp[17]} {evr/tinyEVR_i/timestamp[18]} {evr/tinyEVR_i/timestamp[19]} {evr/tinyEVR_i/timestamp[20]} {evr/tinyEVR_i/timestamp[21]} {evr/tinyEVR_i/timestamp[22]} {evr/tinyEVR_i/timestamp[23]} {evr/tinyEVR_i/timestamp[24]} {evr/tinyEVR_i/timestamp[25]} {evr/tinyEVR_i/timestamp[26]} {evr/tinyEVR_i/timestamp[27]} {evr/tinyEVR_i/timestamp[28]} {evr/tinyEVR_i/timestamp[29]} {evr/tinyEVR_i/timestamp[30]} {evr/tinyEVR_i/timestamp[31]} {evr/tinyEVR_i/timestamp[32]} {evr/tinyEVR_i/timestamp[33]} {evr/tinyEVR_i/timestamp[34]} {evr/tinyEVR_i/timestamp[35]} {evr/tinyEVR_i/timestamp[36]} {evr/tinyEVR_i/timestamp[37]} {evr/tinyEVR_i/timestamp[38]} {evr/tinyEVR_i/timestamp[39]} {evr/tinyEVR_i/timestamp[40]} {evr/tinyEVR_i/timestamp[41]} {evr/tinyEVR_i/timestamp[42]} {evr/tinyEVR_i/timestamp[43]} {evr/tinyEVR_i/timestamp[44]} {evr/tinyEVR_i/timestamp[45]} {evr/tinyEVR_i/timestamp[46]} {evr/tinyEVR_i/timestamp[47]} {evr/tinyEVR_i/timestamp[48]} {evr/tinyEVR_i/timestamp[49]} {evr/tinyEVR_i/timestamp[50]} {evr/tinyEVR_i/timestamp[51]} {evr/tinyEVR_i/timestamp[52]} {evr/tinyEVR_i/timestamp[53]} {evr/tinyEVR_i/timestamp[54]} {evr/tinyEVR_i/timestamp[55]} {evr/tinyEVR_i/timestamp[56]} {evr/tinyEVR_i/timestamp[57]} {evr/tinyEVR_i/timestamp[58]} {evr/tinyEVR_i/timestamp[59]} {evr/tinyEVR_i/timestamp[60]} {evr/tinyEVR_i/timestamp[61]} {evr/tinyEVR_i/timestamp[62]} {evr/tinyEVR_i/timestamp[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 5 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {evr/evrPPSstretchCounter[0]} {evr/evrPPSstretchCounter[1]} {evr/evrPPSstretchCounter[2]} {evr/evrPPSstretchCounter[3]} {evr/evrPPSstretchCounter[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list evr/tinyEVR_i/tinyEVRcommon/enoughBits]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list evr/tinyEVR_i/ppsMarker]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list evr/tinyEVR_i/tinyEVRcommon/ppsMarker]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list evr/tinyEVR_i/timestampValid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list evr/tinyEVR_i/tinyEVRcommon/timestampValid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list evr/tinyEVR_i/tinyEVRcommon/tooManyBits]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list evr/mgtWrapper_i/MGT_i/inst/gt_usrclk_source/gt0_txusrclk_out]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {evr/tinyEVG/secondsReg[0]} {evr/tinyEVG/secondsReg[1]} {evr/tinyEVG/secondsReg[2]} {evr/tinyEVG/secondsReg[3]} {evr/tinyEVG/secondsReg[4]} {evr/tinyEVG/secondsReg[5]} {evr/tinyEVG/secondsReg[6]} {evr/tinyEVG/secondsReg[7]} {evr/tinyEVG/secondsReg[8]} {evr/tinyEVG/secondsReg[9]} {evr/tinyEVG/secondsReg[10]} {evr/tinyEVG/secondsReg[11]} {evr/tinyEVG/secondsReg[12]} {evr/tinyEVG/secondsReg[13]} {evr/tinyEVG/secondsReg[14]} {evr/tinyEVG/secondsReg[15]} {evr/tinyEVG/secondsReg[16]} {evr/tinyEVG/secondsReg[17]} {evr/tinyEVG/secondsReg[18]} {evr/tinyEVG/secondsReg[19]} {evr/tinyEVG/secondsReg[20]} {evr/tinyEVG/secondsReg[21]} {evr/tinyEVG/secondsReg[22]} {evr/tinyEVG/secondsReg[23]} {evr/tinyEVG/secondsReg[24]} {evr/tinyEVG/secondsReg[25]} {evr/tinyEVG/secondsReg[26]} {evr/tinyEVG/secondsReg[27]} {evr/tinyEVG/secondsReg[28]} {evr/tinyEVG/secondsReg[29]} {evr/tinyEVG/secondsReg[30]} {evr/tinyEVG/secondsReg[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 28 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {evr/ppsTooFastCounter[0]} {evr/ppsTooFastCounter[1]} {evr/ppsTooFastCounter[2]} {evr/ppsTooFastCounter[3]} {evr/ppsTooFastCounter[4]} {evr/ppsTooFastCounter[5]} {evr/ppsTooFastCounter[6]} {evr/ppsTooFastCounter[7]} {evr/ppsTooFastCounter[8]} {evr/ppsTooFastCounter[9]} {evr/ppsTooFastCounter[10]} {evr/ppsTooFastCounter[11]} {evr/ppsTooFastCounter[12]} {evr/ppsTooFastCounter[13]} {evr/ppsTooFastCounter[14]} {evr/ppsTooFastCounter[15]} {evr/ppsTooFastCounter[16]} {evr/ppsTooFastCounter[17]} {evr/ppsTooFastCounter[18]} {evr/ppsTooFastCounter[19]} {evr/ppsTooFastCounter[20]} {evr/ppsTooFastCounter[21]} {evr/ppsTooFastCounter[22]} {evr/ppsTooFastCounter[23]} {evr/ppsTooFastCounter[24]} {evr/ppsTooFastCounter[25]} {evr/ppsTooFastCounter[26]} {evr/ppsTooFastCounter[27]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 28 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {evr/ppsTooSlowCounter[0]} {evr/ppsTooSlowCounter[1]} {evr/ppsTooSlowCounter[2]} {evr/ppsTooSlowCounter[3]} {evr/ppsTooSlowCounter[4]} {evr/ppsTooSlowCounter[5]} {evr/ppsTooSlowCounter[6]} {evr/ppsTooSlowCounter[7]} {evr/ppsTooSlowCounter[8]} {evr/ppsTooSlowCounter[9]} {evr/ppsTooSlowCounter[10]} {evr/ppsTooSlowCounter[11]} {evr/ppsTooSlowCounter[12]} {evr/ppsTooSlowCounter[13]} {evr/ppsTooSlowCounter[14]} {evr/ppsTooSlowCounter[15]} {evr/ppsTooSlowCounter[16]} {evr/ppsTooSlowCounter[17]} {evr/ppsTooSlowCounter[18]} {evr/ppsTooSlowCounter[19]} {evr/ppsTooSlowCounter[20]} {evr/ppsTooSlowCounter[21]} {evr/ppsTooSlowCounter[22]} {evr/ppsTooSlowCounter[23]} {evr/ppsTooSlowCounter[24]} {evr/ppsTooSlowCounter[25]} {evr/ppsTooSlowCounter[26]} {evr/ppsTooSlowCounter[27]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list evr/tinyEVG/haveSeconds]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list evr/tinyEVG/ppsPending]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list evr/ppsValid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 1 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list evr/secondsValid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
set_property port_width 1 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list evr/tinyEVG/sentSeconds]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_1_gt0_txusrclk_out]
