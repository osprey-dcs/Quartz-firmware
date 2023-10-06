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
connect_debug_port u_ila_0/clk [get_nets [list bd_i/clk_wiz_1/inst/sysClk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {evr/sysEVGstatus[0]} {evr/sysEVGstatus[1]} {evr/sysEVGstatus[2]} {evr/sysEVGstatus[3]} {evr/sysEVGstatus[4]} {evr/sysEVGstatus[5]} {evr/sysEVGstatus[6]} {evr/sysEVGstatus[7]} {evr/sysEVGstatus[8]} {evr/sysEVGstatus[9]} {evr/sysEVGstatus[10]} {evr/sysEVGstatus[11]} {evr/sysEVGstatus[12]} {evr/sysEVGstatus[13]} {evr/sysEVGstatus[14]} {evr/sysEVGstatus[15]} {evr/sysEVGstatus[16]} {evr/sysEVGstatus[17]} {evr/sysEVGstatus[18]} {evr/sysEVGstatus[19]} {evr/sysEVGstatus[20]} {evr/sysEVGstatus[21]} {evr/sysEVGstatus[22]} {evr/sysEVGstatus[23]} {evr/sysEVGstatus[24]} {evr/sysEVGstatus[25]} {evr/sysEVGstatus[26]} {evr/sysEVGstatus[27]} {evr/sysEVGstatus[28]} {evr/sysEVGstatus[29]} {evr/sysEVGstatus[30]} {evr/sysEVGstatus[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {evr/sysLinkStatus[0]} {evr/sysLinkStatus[1]} {evr/sysLinkStatus[2]} {evr/sysLinkStatus[3]} {evr/sysLinkStatus[4]} {evr/sysLinkStatus[5]} {evr/sysLinkStatus[6]} {evr/sysLinkStatus[7]} {evr/sysLinkStatus[8]} {evr/sysLinkStatus[9]} {evr/sysLinkStatus[10]} {evr/sysLinkStatus[11]} {evr/sysLinkStatus[12]} {evr/sysLinkStatus[13]} {evr/sysLinkStatus[14]} {evr/sysLinkStatus[15]} {evr/sysLinkStatus[16]} {evr/sysLinkStatus[17]} {evr/sysLinkStatus[18]} {evr/sysLinkStatus[19]} {evr/sysLinkStatus[20]} {evr/sysLinkStatus[21]} {evr/sysLinkStatus[22]} {evr/sysLinkStatus[23]} {evr/sysLinkStatus[24]} {evr/sysLinkStatus[25]} {evr/sysLinkStatus[26]} {evr/sysLinkStatus[27]} {evr/sysLinkStatus[28]} {evr/sysLinkStatus[29]} {evr/sysLinkStatus[30]} {evr/sysLinkStatus[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {evr/sysStatus[0]} {evr/sysStatus[1]} {evr/sysStatus[2]} {evr/sysStatus[3]} {evr/sysStatus[4]} {evr/sysStatus[5]} {evr/sysStatus[6]} {evr/sysStatus[7]} {evr/sysStatus[8]} {evr/sysStatus[9]} {evr/sysStatus[10]} {evr/sysStatus[11]} {evr/sysStatus[12]} {evr/sysStatus[13]} {evr/sysStatus[14]} {evr/sysStatus[15]} {evr/sysStatus[16]} {evr/sysStatus[17]} {evr/sysStatus[18]} {evr/sysStatus[19]} {evr/sysStatus[20]} {evr/sysStatus[21]} {evr/sysStatus[22]} {evr/sysStatus[23]} {evr/sysStatus[24]} {evr/sysStatus[25]} {evr/sysStatus[26]} {evr/sysStatus[27]} {evr/sysStatus[28]} {evr/sysStatus[29]} {evr/sysStatus[30]} {evr/sysStatus[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list evr/mgtWrapper_i/pmareset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list evr/mgtWrapper_i/rxreset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list evr/mgtWrapper_i/soft_reset_rx]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list evr/mgtWrapper_i/soft_reset_tx]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list evr/sysCsrStrobe]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list evr/sysEVGsetTimeStrobe]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list evr/mgtWrapper_i/txreset]]
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
connect_debug_port u_ila_1/probe0 [get_nets [list {evr/txCharIsK[0]} {evr/txCharIsK[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 15 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {evr/txChars[0]} {evr/txChars[1]} {evr/txChars[2]} {evr/txChars[3]} {evr/txChars[5]} {evr/txChars[6]} {evr/txChars[7]} {evr/txChars[8]} {evr/txChars[9]} {evr/txChars[10]} {evr/txChars[11]} {evr/txChars[12]} {evr/txChars[13]} {evr/txChars[14]} {evr/txChars[15]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_1_mgtTxClk]
