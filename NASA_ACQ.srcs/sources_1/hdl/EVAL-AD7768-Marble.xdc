# Constraints for EVAL-AD7768 connected to Marble FMC1

set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVDS_25} [get_ports AD7768_MCLK_P]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCDS_25} [get_ports AD7768_MCLK_N]

# DCLK -- FMC1 H4 -- FMC1_CLK0_M2C_P
set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVCMOS25} [get_ports AD7768_DCLK]

# DRDY -- FMC1 G6 -- FMC1_LA00_P
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS25} [get_ports AD7768_DRDY]

# DOUT0 -- FMC1 G7 -- FMC1_LA00_N
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[0]}]

# DOUT1 -- FMC1 C11 -- FMC1_LA06_N
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[1]}]

# DOUT2 -- FMC1 H7 -- FMC1_LA02_P
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[2]}]

# DOUT3 -- FMC1 H8 -- FMC1_LA02_N
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[3]}]

# DOUT4 -- FMC1 G12 -- FMC1_LA08_P
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[4]}]

# DOUT5 -- FMC1 G13 -- FMC1_LA08_N
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[5]}]

# DOUT6 -- FMC1 D14 -- FMC1_LA09_P
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[6]}]

# DOUT7 -- FMC1 D15 -- FMC1_LA09_N
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[7]}]

# START* -- FMC1 G10 -- FMC1_LA03_N
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS25} [get_ports AD7768_START_n]

# SYNC_IN* -- FMC1 H10 -- FMC1_LA04_P -- By default tied to SYNC_IN through SL5
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS25} [get_ports AD7768_SYNC_IN_n]

# SYNC_OUT -- FMC1 D12 -- FMC1_LA05_N
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS25} [get_ports AD7768_SYNC_OUT_n]

# SCLK -- FMC1 D8 -- FMC1_LA01_P
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS25} [get_ports AD7768_SCLK]

# CS* -- FMC1 D11 -- FMC1_LA05_P
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS25} [get_ports AD7768_CS_n]

# SDI -- FMC1 H11 -- FMC1_LA04_N
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS25} [get_ports AD7768_SDI]

# SDO -- FMC1 G9 -- FMC1_LA03_P
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS25} [get_ports AD7768_SDO]

# RESET* -- FMC1 C10 -- FMC1_LA06_P
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS25} [get_ports AD7768_RESET_n]

# The AD7768 is strapped for SPI operation so the following are GPIO pins.
# MODE_0 -- FMC1 C15 -- FMC1_LA10_N
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS25} [get_ports {AD7768_MODE[0]}]

# MODE_1 -- FMC1 H13 -- FMC1_LA07_P
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS25} [get_ports {AD7768_MODE[1]}]

# MODE_2 -- FMC1 H14 -- FMC1_LA07_N
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS25} [get_ports {AD7768_MODE[2]}]

# MODE_3 -- FMC1 H16 -- FMC1_LA11_P
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS25} [get_ports {AD7768_MODE[3]}]

# FILTER_0 -- FMC1 C14 -- FMC1_LA10_P
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS25} [get_ports AD7768_FILTER]





