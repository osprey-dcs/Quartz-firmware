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
connect_debug_port u_ila_0/clk [get_nets [list evr/mgtWrapper_i/mgtRxClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {evr/mgtWrapper_i/mgtRxChars[0]} {evr/mgtWrapper_i/mgtRxChars[1]} {evr/mgtWrapper_i/mgtRxChars[2]} {evr/mgtWrapper_i/mgtRxChars[3]} {evr/mgtWrapper_i/mgtRxChars[4]} {evr/mgtWrapper_i/mgtRxChars[5]} {evr/mgtWrapper_i/mgtRxChars[6]} {evr/mgtWrapper_i/mgtRxChars[7]} {evr/mgtWrapper_i/mgtRxChars[8]} {evr/mgtWrapper_i/mgtRxChars[9]} {evr/mgtWrapper_i/mgtRxChars[10]} {evr/mgtWrapper_i/mgtRxChars[11]} {evr/mgtWrapper_i/mgtRxChars[12]} {evr/mgtWrapper_i/mgtRxChars[13]} {evr/mgtWrapper_i/mgtRxChars[14]} {evr/mgtWrapper_i/mgtRxChars[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 5 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {evr/mgtWrapper_i/syncCount[0]} {evr/mgtWrapper_i/syncCount[1]} {evr/mgtWrapper_i/syncCount[2]} {evr/mgtWrapper_i/syncCount[3]} {evr/mgtWrapper_i/syncCount[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {evr/mgtWrapper_i/rxNotInTableOut[0]} {evr/mgtWrapper_i/rxNotInTableOut[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {evr/mgtWrapper_i/rxCharIsKOut[0]} {evr/mgtWrapper_i/rxCharIsKOut[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list evr/mgtWrapper_i/mgtLinkUp]]
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
connect_debug_port u_ila_1/clk [get_nets [list evr/mgtWrapper_i/mgtTxClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 2 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {evr/mgtWrapper_i/mgtTxIsK[0]} {evr/mgtWrapper_i/mgtTxIsK[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 8 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {evr/txChars[0]} {evr/txChars[1]} {evr/txChars[2]} {evr/txChars[3]} {evr/txChars[4]} {evr/txChars[5]} {evr/txChars[6]} {evr/txChars[7]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 2 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {evr/txCharIsK[0]} {evr/txCharIsK[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list evr/evgPPSmarker_a]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_1_mgtTxClk]
