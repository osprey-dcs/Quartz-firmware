# Vivado-generated constraints (ChipScope, etc.)












create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list bd_i/clk_wiz_4/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 18 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {ad7768/ppsDrdyTicks[0]} {ad7768/ppsDrdyTicks[1]} {ad7768/ppsDrdyTicks[2]} {ad7768/ppsDrdyTicks[3]} {ad7768/ppsDrdyTicks[4]} {ad7768/ppsDrdyTicks[5]} {ad7768/ppsDrdyTicks[6]} {ad7768/ppsDrdyTicks[7]} {ad7768/ppsDrdyTicks[8]} {ad7768/ppsDrdyTicks[9]} {ad7768/ppsDrdyTicks[10]} {ad7768/ppsDrdyTicks[11]} {ad7768/ppsDrdyTicks[12]} {ad7768/ppsDrdyTicks[13]} {ad7768/ppsDrdyTicks[14]} {ad7768/ppsDrdyTicks[15]} {ad7768/ppsDrdyTicks[16]} {ad7768/ppsDrdyTicks[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 3 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {ad7768/drdyState[0]} {ad7768/drdyState[1]} {ad7768/drdyState[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {ad7768/drdySkewPattern[0]} {ad7768/drdySkewPattern[1]} {ad7768/drdySkewPattern[2]} {ad7768/drdySkewPattern[3]} {ad7768/drdySkewPattern[4]} {ad7768/drdySkewPattern[5]} {ad7768/drdySkewPattern[6]} {ad7768/drdySkewPattern[7]} {ad7768/drdySkewPattern[8]} {ad7768/drdySkewPattern[9]} {ad7768/drdySkewPattern[10]} {ad7768/drdySkewPattern[11]} {ad7768/drdySkewPattern[12]} {ad7768/drdySkewPattern[13]} {ad7768/drdySkewPattern[14]} {ad7768/drdySkewPattern[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 4 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {ad7768/drdy[0]} {ad7768/drdy[1]} {ad7768/drdy[2]} {ad7768/drdy[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list ad7768/drdyAligned]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets acqClk]
