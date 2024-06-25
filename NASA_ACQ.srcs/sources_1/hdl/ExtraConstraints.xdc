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
connect_debug_port u_ila_0/clk [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxClks[0]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 64 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[0]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[1]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[2]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[3]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[4]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[5]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[6]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[7]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[8]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[9]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[10]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[11]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[12]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[13]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[14]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[15]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[16]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[17]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[18]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[19]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[20]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[21]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[22]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[23]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[24]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[25]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[26]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[27]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[28]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[29]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[30]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[31]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[32]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[33]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[34]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[35]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[36]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[37]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[38]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[39]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[40]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[41]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[42]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[43]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[44]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[45]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[46]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[47]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[48]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[49]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[50]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[51]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[52]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[53]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[54]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[55]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[56]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[57]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[58]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[59]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[60]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[61]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[62]} {fiberLinks/tinyEVR_i/tinyEVRcommon/timestamp[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {fiberLinks/tinyEVR_i/evrCharIsK[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 5 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {fiberLinks/evrPPSstretchCounter[0]} {fiberLinks/evrPPSstretchCounter[1]} {fiberLinks/evrPPSstretchCounter[2]} {fiberLinks/evrPPSstretchCounter[3]} {fiberLinks/evrPPSstretchCounter[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {fiberLinks/tinyEVR_i/evrRxWord[0]} {fiberLinks/tinyEVR_i/evrRxWord[1]} {fiberLinks/tinyEVR_i/evrRxWord[2]} {fiberLinks/tinyEVR_i/evrRxWord[3]} {fiberLinks/tinyEVR_i/evrRxWord[4]} {fiberLinks/tinyEVR_i/evrRxWord[5]} {fiberLinks/tinyEVR_i/evrRxWord[6]} {fiberLinks/tinyEVR_i/evrRxWord[7]} {fiberLinks/tinyEVR_i/evrRxWord[8]} {fiberLinks/tinyEVR_i/evrRxWord[9]} {fiberLinks/tinyEVR_i/evrRxWord[10]} {fiberLinks/tinyEVR_i/evrRxWord[11]} {fiberLinks/tinyEVR_i/evrRxWord[12]} {fiberLinks/tinyEVR_i/evrRxWord[13]} {fiberLinks/tinyEVR_i/evrRxWord[14]} {fiberLinks/tinyEVR_i/evrRxWord[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list fiberLinks/tinyEVR_i/tinyEVRcommon/ppsMarker]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list fiberLinks/tinyEVR_i/tinyEVRcommon/timestampValid]]
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
connect_debug_port u_ila_1/clk [get_nets [list fiberLinks/mgtWrapper_i/mgtTxClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 9 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/mpsTxChars[7]} {fiberLinks/mgtWrapper_i/mpsTxChars[8]} {fiberLinks/mgtWrapper_i/mpsTxChars[9]} {fiberLinks/mgtWrapper_i/mpsTxChars[10]} {fiberLinks/mgtWrapper_i/mpsTxChars[11]} {fiberLinks/mgtWrapper_i/mpsTxChars[12]} {fiberLinks/mgtWrapper_i/mpsTxChars[13]} {fiberLinks/mgtWrapper_i/mpsTxChars[14]} {fiberLinks/mgtWrapper_i/mpsTxChars[15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 16 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/evsTxChars[0]} {fiberLinks/mgtWrapper_i/evsTxChars[1]} {fiberLinks/mgtWrapper_i/evsTxChars[2]} {fiberLinks/mgtWrapper_i/evsTxChars[3]} {fiberLinks/mgtWrapper_i/evsTxChars[4]} {fiberLinks/mgtWrapper_i/evsTxChars[5]} {fiberLinks/mgtWrapper_i/evsTxChars[6]} {fiberLinks/mgtWrapper_i/evsTxChars[7]} {fiberLinks/mgtWrapper_i/evsTxChars[8]} {fiberLinks/mgtWrapper_i/evsTxChars[9]} {fiberLinks/mgtWrapper_i/evsTxChars[10]} {fiberLinks/mgtWrapper_i/evsTxChars[11]} {fiberLinks/mgtWrapper_i/evsTxChars[12]} {fiberLinks/mgtWrapper_i/evsTxChars[13]} {fiberLinks/mgtWrapper_i/evsTxChars[14]} {fiberLinks/mgtWrapper_i/evsTxChars[15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list fiberLinks/mgtWrapper_i/evsTxCharIsK]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list fiberLinks/mgtWrapper_i/mpsTxCharIsK]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets evgClk]
