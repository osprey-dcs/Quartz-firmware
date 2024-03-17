# Don't check timing across clock boundaries
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt5_MGT_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks rx_clk] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt5_MGT_i/gtxe2_i/TXOUTCLK]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks rx_clk]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_4/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt6_MGT_i/gtxe2_i/RXOUTCLK] -to [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt5_MGT_i/gtxe2_i/TXOUTCLK]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt5_MGT_i/gtxe2_i/TXOUTCLK]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt6_MGT_i/gtxe2_i/RXOUTCLK]
set_false_path -from [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt5_MGT_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt5_MGT_i/gtxe2_i/TXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks eventSystem/mgtWrapper_i/MGT_i/inst/MGT_i/gt6_MGT_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins gtRefClkBuf/ODIV2]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_3/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins bd_i/clk_wiz_2/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0]]
