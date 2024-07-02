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
connect_debug_port u_ila_0/clk [get_nets [list fiberLinks/mgtWrapper_i/mgtTxClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/evsTxChars[0]} {fiberLinks/mgtWrapper_i/evsTxChars[1]} {fiberLinks/mgtWrapper_i/evsTxChars[2]} {fiberLinks/mgtWrapper_i/evsTxChars[3]} {fiberLinks/mgtWrapper_i/evsTxChars[4]} {fiberLinks/mgtWrapper_i/evsTxChars[5]} {fiberLinks/mgtWrapper_i/evsTxChars[6]} {fiberLinks/mgtWrapper_i/evsTxChars[7]} {fiberLinks/mgtWrapper_i/evsTxChars[8]} {fiberLinks/mgtWrapper_i/evsTxChars[9]} {fiberLinks/mgtWrapper_i/evsTxChars[10]} {fiberLinks/mgtWrapper_i/evsTxChars[11]} {fiberLinks/mgtWrapper_i/evsTxChars[12]} {fiberLinks/mgtWrapper_i/evsTxChars[13]} {fiberLinks/mgtWrapper_i/evsTxChars[14]} {fiberLinks/mgtWrapper_i/evsTxChars[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 9 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/mpfTxChars[7]} {fiberLinks/mgtWrapper_i/mpfTxChars[8]} {fiberLinks/mgtWrapper_i/mpfTxChars[9]} {fiberLinks/mgtWrapper_i/mpfTxChars[10]} {fiberLinks/mgtWrapper_i/mpfTxChars[11]} {fiberLinks/mgtWrapper_i/mpfTxChars[12]} {fiberLinks/mgtWrapper_i/mpfTxChars[13]} {fiberLinks/mgtWrapper_i/mpfTxChars[14]} {fiberLinks/mgtWrapper_i/mpfTxChars[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 9 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/mpsTxChars[7]} {fiberLinks/mgtWrapper_i/mpsTxChars[8]} {fiberLinks/mgtWrapper_i/mpsTxChars[9]} {fiberLinks/mgtWrapper_i/mpsTxChars[10]} {fiberLinks/mgtWrapper_i/mpsTxChars[11]} {fiberLinks/mgtWrapper_i/mpsTxChars[12]} {fiberLinks/mgtWrapper_i/mpsTxChars[13]} {fiberLinks/mgtWrapper_i/mpsTxChars[14]} {fiberLinks/mgtWrapper_i/mpsTxChars[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list fiberLinks/mgtWrapper_i/evsTxCharIsK]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list fiberLinks/mgtWrapper_i/mgtIsEVG]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list fiberLinks/mgtWrapper_i/mpfTxCharIsK]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list fiberLinks/mgtWrapper_i/mpsTxCharIsK]]
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
connect_debug_port u_ila_1/clk [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxClks[0]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 1 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxCharIsK[0]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 1 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxLinkUp[0]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 16 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxChars[0]} {fiberLinks/mgtWrapper_i/mgtRxChars[1]} {fiberLinks/mgtWrapper_i/mgtRxChars[2]} {fiberLinks/mgtWrapper_i/mgtRxChars[3]} {fiberLinks/mgtWrapper_i/mgtRxChars[4]} {fiberLinks/mgtWrapper_i/mgtRxChars[5]} {fiberLinks/mgtWrapper_i/mgtRxChars[6]} {fiberLinks/mgtWrapper_i/mgtRxChars[7]} {fiberLinks/mgtWrapper_i/mgtRxChars[8]} {fiberLinks/mgtWrapper_i/mgtRxChars[9]} {fiberLinks/mgtWrapper_i/mgtRxChars[10]} {fiberLinks/mgtWrapper_i/mgtRxChars[11]} {fiberLinks/mgtWrapper_i/mgtRxChars[12]} {fiberLinks/mgtWrapper_i/mgtRxChars[13]} {fiberLinks/mgtWrapper_i/mgtRxChars[14]} {fiberLinks/mgtWrapper_i/mgtRxChars[15]}]]
create_debug_core u_ila_2 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_2]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_2]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_2]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_2]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_2]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_2]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_2]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_2]
set_property port_width 1 [get_debug_ports u_ila_2/clk]
connect_debug_port u_ila_2/clk [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxClks[1]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe0]
set_property port_width 1 [get_debug_ports u_ila_2/probe0]
connect_debug_port u_ila_2/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxCharIsK[1]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe1]
set_property port_width 1 [get_debug_ports u_ila_2/probe1]
connect_debug_port u_ila_2/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxLinkUp[1]}]]
create_debug_port u_ila_2 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_2/probe2]
set_property port_width 16 [get_debug_ports u_ila_2/probe2]
connect_debug_port u_ila_2/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxChars[16]} {fiberLinks/mgtWrapper_i/mgtRxChars[17]} {fiberLinks/mgtWrapper_i/mgtRxChars[18]} {fiberLinks/mgtWrapper_i/mgtRxChars[19]} {fiberLinks/mgtWrapper_i/mgtRxChars[20]} {fiberLinks/mgtWrapper_i/mgtRxChars[21]} {fiberLinks/mgtWrapper_i/mgtRxChars[22]} {fiberLinks/mgtWrapper_i/mgtRxChars[23]} {fiberLinks/mgtWrapper_i/mgtRxChars[24]} {fiberLinks/mgtWrapper_i/mgtRxChars[25]} {fiberLinks/mgtWrapper_i/mgtRxChars[26]} {fiberLinks/mgtWrapper_i/mgtRxChars[27]} {fiberLinks/mgtWrapper_i/mgtRxChars[28]} {fiberLinks/mgtWrapper_i/mgtRxChars[29]} {fiberLinks/mgtWrapper_i/mgtRxChars[30]} {fiberLinks/mgtWrapper_i/mgtRxChars[31]}]]
create_debug_core u_ila_3 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_3]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_3]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_3]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_3]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_3]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_3]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_3]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_3]
set_property port_width 1 [get_debug_ports u_ila_3/clk]
connect_debug_port u_ila_3/clk [get_nets [list {fiberLinks/mgtWrapper_i/perLane[2].rxclk_bufg_n_0}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe0]
set_property port_width 1 [get_debug_ports u_ila_3/probe0]
connect_debug_port u_ila_3/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxCharIsK[2]}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe1]
set_property port_width 1 [get_debug_ports u_ila_3/probe1]
connect_debug_port u_ila_3/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxLinkUp[2]}]]
create_debug_port u_ila_3 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_3/probe2]
set_property port_width 16 [get_debug_ports u_ila_3/probe2]
connect_debug_port u_ila_3/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxChars[32]} {fiberLinks/mgtWrapper_i/mgtRxChars[33]} {fiberLinks/mgtWrapper_i/mgtRxChars[34]} {fiberLinks/mgtWrapper_i/mgtRxChars[35]} {fiberLinks/mgtWrapper_i/mgtRxChars[36]} {fiberLinks/mgtWrapper_i/mgtRxChars[37]} {fiberLinks/mgtWrapper_i/mgtRxChars[38]} {fiberLinks/mgtWrapper_i/mgtRxChars[39]} {fiberLinks/mgtWrapper_i/mgtRxChars[40]} {fiberLinks/mgtWrapper_i/mgtRxChars[41]} {fiberLinks/mgtWrapper_i/mgtRxChars[42]} {fiberLinks/mgtWrapper_i/mgtRxChars[43]} {fiberLinks/mgtWrapper_i/mgtRxChars[44]} {fiberLinks/mgtWrapper_i/mgtRxChars[45]} {fiberLinks/mgtWrapper_i/mgtRxChars[46]} {fiberLinks/mgtWrapper_i/mgtRxChars[47]}]]
create_debug_core u_ila_4 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_4]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_4]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_4]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_4]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_4]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_4]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_4]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_4]
set_property port_width 1 [get_debug_ports u_ila_4/clk]
connect_debug_port u_ila_4/clk [get_nets [list {fiberLinks/mgtWrapper_i/perLane[3].rxclk_bufg_n_0}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_4/probe0]
set_property port_width 1 [get_debug_ports u_ila_4/probe0]
connect_debug_port u_ila_4/probe0 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxCharIsK[3]}]]
create_debug_port u_ila_4 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_4/probe1]
set_property port_width 1 [get_debug_ports u_ila_4/probe1]
connect_debug_port u_ila_4/probe1 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxLinkUp[3]}]]
create_debug_port u_ila_4 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_4/probe2]
set_property port_width 16 [get_debug_ports u_ila_4/probe2]
connect_debug_port u_ila_4/probe2 [get_nets [list {fiberLinks/mgtWrapper_i/mgtRxChars[48]} {fiberLinks/mgtWrapper_i/mgtRxChars[49]} {fiberLinks/mgtWrapper_i/mgtRxChars[50]} {fiberLinks/mgtWrapper_i/mgtRxChars[51]} {fiberLinks/mgtWrapper_i/mgtRxChars[52]} {fiberLinks/mgtWrapper_i/mgtRxChars[53]} {fiberLinks/mgtWrapper_i/mgtRxChars[54]} {fiberLinks/mgtWrapper_i/mgtRxChars[55]} {fiberLinks/mgtWrapper_i/mgtRxChars[56]} {fiberLinks/mgtWrapper_i/mgtRxChars[57]} {fiberLinks/mgtWrapper_i/mgtRxChars[58]} {fiberLinks/mgtWrapper_i/mgtRxChars[59]} {fiberLinks/mgtWrapper_i/mgtRxChars[60]} {fiberLinks/mgtWrapper_i/mgtRxChars[61]} {fiberLinks/mgtWrapper_i/mgtRxChars[62]} {fiberLinks/mgtWrapper_i/mgtRxChars[63]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_4_perLane[3].rxclk_bufg_n_0]
