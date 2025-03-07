# RGMII Rx
set_property -dict {PACKAGE_PIN E11 IOSTANDARD LVCMOS25} [get_ports RGMII_RX_CLK]
set_property -dict {PACKAGE_PIN J11 IOSTANDARD LVCMOS25 IOB TRUE} [get_ports RGMII_RX_CTRL]
set_property -dict {PACKAGE_PIN J10 IOSTANDARD LVCMOS25 IOB TRUE} [get_ports {RGMII_RXD[0]}]
set_property -dict {PACKAGE_PIN J8 IOSTANDARD LVCMOS25 IOB TRUE} [get_ports {RGMII_RXD[1]}]
set_property -dict {PACKAGE_PIN H8 IOSTANDARD LVCMOS25 IOB TRUE} [get_ports {RGMII_RXD[2]}]
set_property -dict {PACKAGE_PIN H9 IOSTANDARD LVCMOS25 IOB TRUE} [get_ports {RGMII_RXD[3]}]
create_clock -period 8.000 -name rx_clk [get_ports RGMII_RX_CLK]

# RGMII Tx
set_property -dict {PACKAGE_PIN F10 IOSTANDARD LVCMOS25 IOB TRUE SLEW FAST} [get_ports RGMII_TX_CLK]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS25 IOB TRUE SLEW FAST} [get_ports RGMII_TX_CTRL]
set_property -dict {PACKAGE_PIN H11 IOSTANDARD LVCMOS25 IOB TRUE SLEW FAST} [get_ports {RGMII_TXD[0]}]
set_property -dict {PACKAGE_PIN H12 IOSTANDARD LVCMOS25 IOB TRUE SLEW FAST} [get_ports {RGMII_TXD[1]}]
set_property -dict {PACKAGE_PIN D8 IOSTANDARD LVCMOS25 IOB TRUE SLEW FAST} [get_ports {RGMII_TXD[2]}]
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS25 IOB TRUE SLEW FAST} [get_ports {RGMII_TXD[3]}]

# Other PHY I/O
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS25} [get_ports RGMII_PHY_RESET_n]

# QSPI Boot Flash
set_property -dict {PACKAGE_PIN C23 IOSTANDARD LVCMOS25} [get_ports BOOT_CS_B]
set_property -dict {PACKAGE_PIN B24 IOSTANDARD LVCMOS25} [get_ports BOOT_MOSI]
set_property -dict {PACKAGE_PIN A25 IOSTANDARD LVCMOS25} [get_ports BOOT_MISO]

# Board I2C switch
set_property PACKAGE_PIN B16 [get_ports I2C_FPGA_SCL]
set_property IOSTANDARD LVCMOS25 [get_ports I2C_FPGA_SCL]
set_property PULLUP true [get_ports I2C_FPGA_SCL]
set_property PACKAGE_PIN A17 [get_ports I2C_FPGA_SDA]
set_property IOSTANDARD LVCMOS25 [get_ports I2C_FPGA_SDA]
set_property PULLUP true [get_ports I2C_FPGA_SDA]
set_property PACKAGE_PIN B19 [get_ports I2C_FPGA_SW_RSTn]
set_property IOSTANDARD LVCMOS25 [get_ports I2C_FPGA_SW_RSTn]
set_property PULLUP true [get_ports I2C_FPGA_SW_RSTn]

# SPI from microcontroller
set_property -dict {PACKAGE_PIN AE21 IOSTANDARD LVCMOS25} [get_ports FPGA_SCLK]
set_property -dict {PACKAGE_PIN AD21 IOSTANDARD LVCMOS25} [get_ports FPGA_CSB]
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS25} [get_ports FPGA_MOSI]
set_property -dict {PACKAGE_PIN AC21 IOSTANDARD LVCMOS25} [get_ports FPGA_MISO]

# PMOD1 -- J12
set_property -dict {PACKAGE_PIN C24 IOSTANDARD LVCMOS25} [get_ports PMOD1_0]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS25} [get_ports PMOD1_1]
set_property -dict {PACKAGE_PIN L23 IOSTANDARD LVCMOS25} [get_ports PMOD1_2]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS25} [get_ports PMOD1_3]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS25} [get_ports PMOD1_4]
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS25} [get_ports PMOD1_5]
set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVCMOS25} [get_ports PMOD1_6]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS25} [get_ports PMOD1_7]

# PMOD2 -- J13
set_property -dict {PACKAGE_PIN AE7 IOSTANDARD LVCMOS15} [get_ports PMOD2_0]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS15} [get_ports PMOD2_1]
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS15} [get_ports PMOD2_2]
set_property -dict {PACKAGE_PIN AF7 IOSTANDARD LVCMOS15} [get_ports PMOD2_3]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS15} [get_ports PMOD2_4]
set_property -dict {PACKAGE_PIN AA8 IOSTANDARD LVCMOS15} [get_ports PMOD2_5]
set_property -dict {PACKAGE_PIN Y8 IOSTANDARD LVCMOS15} [get_ports PMOD2_6]
set_property -dict {PACKAGE_PIN W9 IOSTANDARD LVCMOS15} [get_ports PMOD2_7]

# VCXO adjust
# DAC 1 affects DDR_REF_CLK and MGT clock crosspoint input 2 (FPGA_REF_CLK0)
# DAC 2 affects CLK20_VCXO2
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS15} [get_ports WR_DAC_SCLK_T]
set_property -dict {PACKAGE_PIN Y10 IOSTANDARD LVCMOS15} [get_ports WR_DAC_DIN_T]
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS15} [get_ports WR_DAC1_SYNC_Tn]
set_property -dict {PACKAGE_PIN Y11 IOSTANDARD LVCMOS15} [get_ports WR_DAC2_SYNC_Tn]

# 125 MHz from U20
set_property -dict {PACKAGE_PIN AC9 IOSTANDARD DIFF_SSTL15} [get_ports DDR_REF_CLK_P]
set_property -dict {PACKAGE_PIN AD9 IOSTANDARD DIFF_SSTL15} [get_ports DDR_REF_CLK_N]
create_clock -period 8.000 -name ddr_ref_clk [get_ports DDR_REF_CLK_P]

# 20 MHz from Y3
set_property -dict {PACKAGE_PIN W11 IOSTANDARD LVCMOS15} [get_ports CLK20_VCXO]
#create_clock -period 50.000 -name clk20_vcxo [get_ports CLK20_VCXO]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets CLK20_VCXO]
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS15} [get_ports VCXO_EN]

# UART to USB
# TxD and RxD directions are from the perspective of the USB/UART chip.
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS25} [get_ports FPGA_TxD]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS25} [get_ports FPGA_RxD]

## DDR3 SODIMM
#set_property -dict {PACKAGE_PIN AC8 IOSTANDARD SSTL15} [get_ports {DDR3_addr[0]}]
#set_property -dict {PACKAGE_PIN AB10 IOSTANDARD SSTL15} [get_ports {DDR3_addr[1]}]
#set_property -dict {PACKAGE_PIN AA9 IOSTANDARD SSTL15} [get_ports {DDR3_addr[2]}]
#set_property -dict {PACKAGE_PIN AA10 IOSTANDARD SSTL15} [get_ports {DDR3_addr[3]}]
#set_property -dict {PACKAGE_PIN AD10 IOSTANDARD SSTL15} [get_ports {DDR3_addr[4]}]
#set_property -dict {PACKAGE_PIN AC12 IOSTANDARD SSTL15} [get_ports {DDR3_addr[5]}]
#set_property -dict {PACKAGE_PIN AB11 IOSTANDARD SSTL15} [get_ports {DDR3_addr[6]}]
#set_property -dict {PACKAGE_PIN AC11 IOSTANDARD SSTL15} [get_ports {DDR3_addr[7]}]
#set_property -dict {PACKAGE_PIN AF13 IOSTANDARD SSTL15} [get_ports {DDR3_addr[8]}]
#set_property -dict {PACKAGE_PIN AE13 IOSTANDARD SSTL15} [get_ports {DDR3_addr[9]}]
#set_property -dict {PACKAGE_PIN AE10 IOSTANDARD SSTL15} [get_ports {DDR3_addr[10]}]
#set_property -dict {PACKAGE_PIN AD11 IOSTANDARD SSTL15} [get_ports {DDR3_addr[11]}]
#set_property -dict {PACKAGE_PIN AA12 IOSTANDARD SSTL15} [get_ports {DDR3_addr[12]}]
#set_property -dict {PACKAGE_PIN AE8 IOSTANDARD SSTL15} [get_ports {DDR3_addr[13]}]
#set_property -dict {PACKAGE_PIN AB12 IOSTANDARD SSTL15} [get_ports {DDR3_addr[14]}]
#set_property -dict {PACKAGE_PIN AD13 IOSTANDARD SSTL15} [get_ports {DDR3_addr[15]}]
#set_property -dict {PACKAGE_PIN AF10 IOSTANDARD SSTL15} [get_ports {DDR3_ba[0]}]
#set_property -dict {PACKAGE_PIN AD8 IOSTANDARD SSTL15} [get_ports {DDR3_ba[1]}]
#set_property -dict {PACKAGE_PIN AC13 IOSTANDARD SSTL15} [get_ports {DDR3_ba[2]}]
#set_property -dict {PACKAGE_PIN AF8 IOSTANDARD SSTL15} [get_ports DDR3_cas_n]
#set_property -dict {PACKAGE_PIN AA13 IOSTANDARD SSTL15} [get_ports DDR3_cke]
#set_property -dict {PACKAGE_PIN AF12 IOSTANDARD DIFF_SSTL15} [get_ports DDR3_ck_n]
#set_property -dict {PACKAGE_PIN AE12 IOSTANDARD DIFF_SSTL15} [get_ports DDR3_ck_p]
#set_property -dict {PACKAGE_PIN AC7 IOSTANDARD SSTL15} [get_ports DDR3_cs_n]
#set_property -dict {PACKAGE_PIN AF17 IOSTANDARD SSTL15} [get_ports {DDR3_dm[0]}]
#set_property -dict {PACKAGE_PIN W15 IOSTANDARD SSTL15} [get_ports {DDR3_dm[1]}]
#set_property -dict {PACKAGE_PIN AC19 IOSTANDARD SSTL15} [get_ports {DDR3_dm[2]}]
#set_property -dict {PACKAGE_PIN AA15 IOSTANDARD SSTL15} [get_ports {DDR3_dm[3]}]
#set_property -dict {PACKAGE_PIN AC3 IOSTANDARD SSTL15} [get_ports {DDR3_dm[4]}]
#set_property -dict {PACKAGE_PIN AD4 IOSTANDARD SSTL15} [get_ports {DDR3_dm[5]}]
#set_property -dict {PACKAGE_PIN W1 IOSTANDARD SSTL15} [get_ports {DDR3_dm[6]}]
#set_property -dict {PACKAGE_PIN U7 IOSTANDARD SSTL15} [get_ports {DDR3_dm[7]}]
#set_property -dict {PACKAGE_PIN AF20 IOSTANDARD SSTL15} [get_ports {DDR3_dq[0]}]
#set_property -dict {PACKAGE_PIN AF19 IOSTANDARD SSTL15} [get_ports {DDR3_dq[1]}]
#set_property -dict {PACKAGE_PIN AE17 IOSTANDARD SSTL15} [get_ports {DDR3_dq[2]}]
#set_property -dict {PACKAGE_PIN AE15 IOSTANDARD SSTL15} [get_ports {DDR3_dq[3]}]
#set_property -dict {PACKAGE_PIN AD16 IOSTANDARD SSTL15} [get_ports {DDR3_dq[4]}]
#set_property -dict {PACKAGE_PIN AD15 IOSTANDARD SSTL15} [get_ports {DDR3_dq[5]}]
#set_property -dict {PACKAGE_PIN AF15 IOSTANDARD SSTL15} [get_ports {DDR3_dq[6]}]
#set_property -dict {PACKAGE_PIN AF14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[7]}]
#set_property -dict {PACKAGE_PIN V17 IOSTANDARD SSTL15} [get_ports {DDR3_dq[8]}]
#set_property -dict {PACKAGE_PIN Y17 IOSTANDARD SSTL15} [get_ports {DDR3_dq[9]}]
#set_property -dict {PACKAGE_PIN V18 IOSTANDARD SSTL15} [get_ports {DDR3_dq[10]}]
#set_property -dict {PACKAGE_PIN V19 IOSTANDARD SSTL15} [get_ports {DDR3_dq[11]}]
#set_property -dict {PACKAGE_PIN V16 IOSTANDARD SSTL15} [get_ports {DDR3_dq[12]}]
#set_property -dict {PACKAGE_PIN W16 IOSTANDARD SSTL15} [get_ports {DDR3_dq[13]}]
#set_property -dict {PACKAGE_PIN V14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[14]}]
#set_property -dict {PACKAGE_PIN W14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[15]}]
#set_property -dict {PACKAGE_PIN AA20 IOSTANDARD SSTL15} [get_ports {DDR3_dq[16]}]
#set_property -dict {PACKAGE_PIN AD19 IOSTANDARD SSTL15} [get_ports {DDR3_dq[17]}]
#set_property -dict {PACKAGE_PIN AB17 IOSTANDARD SSTL15} [get_ports {DDR3_dq[18]}]
#set_property -dict {PACKAGE_PIN AC17 IOSTANDARD SSTL15} [get_ports {DDR3_dq[19]}]
#set_property -dict {PACKAGE_PIN AA19 IOSTANDARD SSTL15} [get_ports {DDR3_dq[20]}]
#set_property -dict {PACKAGE_PIN AB19 IOSTANDARD SSTL15} [get_ports {DDR3_dq[21]}]
#set_property -dict {PACKAGE_PIN AD18 IOSTANDARD SSTL15} [get_ports {DDR3_dq[22]}]
#set_property -dict {PACKAGE_PIN AC18 IOSTANDARD SSTL15} [get_ports {DDR3_dq[23]}]
#set_property -dict {PACKAGE_PIN AA18 IOSTANDARD SSTL15} [get_ports {DDR3_dq[24]}]
#set_property -dict {PACKAGE_PIN AB16 IOSTANDARD SSTL15} [get_ports {DDR3_dq[25]}]
#set_property -dict {PACKAGE_PIN AA14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[26]}]
#set_property -dict {PACKAGE_PIN AD14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[27]}]
#set_property -dict {PACKAGE_PIN AB15 IOSTANDARD SSTL15} [get_ports {DDR3_dq[28]}]
#set_property -dict {PACKAGE_PIN AA17 IOSTANDARD SSTL15} [get_ports {DDR3_dq[29]}]
#set_property -dict {PACKAGE_PIN AC14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[30]}]
#set_property -dict {PACKAGE_PIN AB14 IOSTANDARD SSTL15} [get_ports {DDR3_dq[31]}]
#set_property -dict {PACKAGE_PIN AD6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[32]}]
#set_property -dict {PACKAGE_PIN AB6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[33]}]
#set_property -dict {PACKAGE_PIN Y6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[34]}]
#set_property -dict {PACKAGE_PIN AC4 IOSTANDARD SSTL15} [get_ports {DDR3_dq[35]}]
#set_property -dict {PACKAGE_PIN AC6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[36]}]
#set_property -dict {PACKAGE_PIN AB4 IOSTANDARD SSTL15} [get_ports {DDR3_dq[37]}]
#set_property -dict {PACKAGE_PIN AA4 IOSTANDARD SSTL15} [get_ports {DDR3_dq[38]}]
#set_property -dict {PACKAGE_PIN Y5 IOSTANDARD SSTL15} [get_ports {DDR3_dq[39]}]
#set_property -dict {PACKAGE_PIN AF2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[40]}]
#set_property -dict {PACKAGE_PIN AE2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[41]}]
#set_property -dict {PACKAGE_PIN AE1 IOSTANDARD SSTL15} [get_ports {DDR3_dq[42]}]
#set_property -dict {PACKAGE_PIN AD1 IOSTANDARD SSTL15} [get_ports {DDR3_dq[43]}]
#set_property -dict {PACKAGE_PIN AE5 IOSTANDARD SSTL15} [get_ports {DDR3_dq[44]}]
#set_property -dict {PACKAGE_PIN AE6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[45]}]
#set_property -dict {PACKAGE_PIN AF3 IOSTANDARD SSTL15} [get_ports {DDR3_dq[46]}]
#set_property -dict {PACKAGE_PIN AE3 IOSTANDARD SSTL15} [get_ports {DDR3_dq[47]}]
#set_property -dict {PACKAGE_PIN AA3 IOSTANDARD SSTL15} [get_ports {DDR3_dq[48]}]
#set_property -dict {PACKAGE_PIN AC2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[49]}]
#set_property -dict {PACKAGE_PIN V2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[50]}]
#set_property -dict {PACKAGE_PIN V1 IOSTANDARD SSTL15} [get_ports {DDR3_dq[51]}]
#set_property -dict {PACKAGE_PIN AB2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[52]}]
#set_property -dict {PACKAGE_PIN Y3 IOSTANDARD SSTL15} [get_ports {DDR3_dq[53]}]
#set_property -dict {PACKAGE_PIN Y2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[54]}]
#set_property -dict {PACKAGE_PIN Y1 IOSTANDARD SSTL15} [get_ports {DDR3_dq[55]}]
#set_property -dict {PACKAGE_PIN W3 IOSTANDARD SSTL15} [get_ports {DDR3_dq[56]}]
#set_property -dict {PACKAGE_PIN V4 IOSTANDARD SSTL15} [get_ports {DDR3_dq[57]}]
#set_property -dict {PACKAGE_PIN U2 IOSTANDARD SSTL15} [get_ports {DDR3_dq[58]}]
#set_property -dict {PACKAGE_PIN U1 IOSTANDARD SSTL15} [get_ports {DDR3_dq[59]}]
#set_property -dict {PACKAGE_PIN V6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[60]}]
#set_property -dict {PACKAGE_PIN V3 IOSTANDARD SSTL15} [get_ports {DDR3_dq[61]}]
#set_property -dict {PACKAGE_PIN U6 IOSTANDARD SSTL15} [get_ports {DDR3_dq[62]}]
#set_property -dict {PACKAGE_PIN U5 IOSTANDARD SSTL15} [get_ports {DDR3_dq[63]}]
#set_property -dict {PACKAGE_PIN AF18 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[0]}]
#set_property -dict {PACKAGE_PIN AE18 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[0]}]
#set_property -dict {PACKAGE_PIN W19 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[1]}]
#set_property -dict {PACKAGE_PIN W18 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[1]}]
#set_property -dict {PACKAGE_PIN AE20 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[2]}]
#set_property -dict {PACKAGE_PIN AD20 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[2]}]
#set_property -dict {PACKAGE_PIN Y16 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[3]}]
#set_property -dict {PACKAGE_PIN Y15 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[3]}]
#set_property -dict {PACKAGE_PIN AB5 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[4]}]
#set_property -dict {PACKAGE_PIN AA5 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[4]}]
#set_property -dict {PACKAGE_PIN AF4 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[5]}]
#set_property -dict {PACKAGE_PIN AF5 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[5]}]
#set_property -dict {PACKAGE_PIN AC1 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[6]}]
#set_property -dict {PACKAGE_PIN AB1 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[6]}]
#set_property -dict {PACKAGE_PIN W5 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_n[7]}]
#set_property -dict {PACKAGE_PIN W6 IOSTANDARD DIFF_SSTL15} [get_ports {DDR3_dqs_p[7]}]
#set_property -dict {PACKAGE_PIN AB9 IOSTANDARD SSTL15} [get_ports DDR3_odt]
#set_property -dict {PACKAGE_PIN AB7 IOSTANDARD SSTL15} [get_ports DDR3_ras_n]
#set_property -dict {PACKAGE_PIN Y12 IOSTANDARD SSTL15} [get_ports DDR3_rst_n]
#set_property -dict {PACKAGE_PIN AF9 IOSTANDARD SSTL15} [get_ports DDR3_we_n]
#set_property -dict {PACKAGE_PIN AD3 IOSTANDARD LVCMOS33} [get_ports VREF_DDR3]
#set_property -dict {PACKAGE_PIN AE11 IOSTANDARD LVCMOS33} [get_ports VREF_DDR3]
#set_property -dict {PACKAGE_PIN AE16 IOSTANDARD LVCMOS33} [get_ports VREF_DDR3]
#set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVCMOS33} [get_ports VREF_DDR3]
#set_property -dict {PACKAGE_PIN W8 IOSTANDARD LVCMOS33} [get_ports VREF_DDR3]
#set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports VREF_DDR3]

# Transceivers
# QSFP2-2 (Fibers 3/10), Bank 115 MGT 1, X0Y0
set_property -dict {PACKAGE_PIN R4} [get_ports {QSFP_RX_P[6]}]
set_property -dict {PACKAGE_PIN R3} [get_ports {QSFP_RX_N[6]}]
set_property -dict {PACKAGE_PIN P2} [get_ports {QSFP_TX_P[6]}]
set_property -dict {PACKAGE_PIN P1} [get_ports {QSFP_TX_N[6]}]
# QSFP2-0 (Fibers 1/12), Bank 115 MGT 2, X0Y1
set_property -dict {PACKAGE_PIN N4} [get_ports {QSFP_RX_P[4]}]
set_property -dict {PACKAGE_PIN N3} [get_ports {QSFP_RX_N[4]}]
set_property -dict {PACKAGE_PIN M2} [get_ports {QSFP_TX_P[4]}]
set_property -dict {PACKAGE_PIN M1} [get_ports {QSFP_TX_N[4]}]
# QSFP2-1 (Fibers 2/11), Bank 115 MGT 3, X0Y2
set_property -dict {PACKAGE_PIN L4} [get_ports {QSFP_RX_P[5]}]
set_property -dict {PACKAGE_PIN L3} [get_ports {QSFP_RX_N[5]}]
set_property -dict {PACKAGE_PIN K2} [get_ports {QSFP_TX_P[5]}]
set_property -dict {PACKAGE_PIN K1} [get_ports {QSFP_TX_N[5]}]
# QSFP2-3 (Fibers 4/9), Bank 115 MGT 0, X0Y3
set_property -dict {PACKAGE_PIN J4} [get_ports {QSFP_RX_P[7]}]
set_property -dict {PACKAGE_PIN J3} [get_ports {QSFP_RX_N[7]}]
set_property -dict {PACKAGE_PIN H2} [get_ports {QSFP_TX_P[7]}]
set_property -dict {PACKAGE_PIN H1} [get_ports {QSFP_TX_N[7]}]
# Bank 115, reference clock 0
#set_property -dict {PACKAGE_PIN H6} [get_ports MGTREFCLK0_115_P]
#set_property -dict {PACKAGE_PIN H5} [get_ports MGTREFCLK0_115_N]
#create_clock -period 8.000 -name MGT_REFCLK2 [get_ports MGTREFCLK0_115_P]
# Bank 115, reference clock 1
#set_property -dict {PACKAGE_PIN K6} [get_ports MGTREFCLK1_115_P]
#set_property -dict {PACKAGE_PIN K5} [get_ports MGTREFCLK1_115_N]
#create_clock -period 8.000 -name MGT_REFCLK3 [get_ports MGTREFCLK1_115_P]
# QSFP1-2 (Fibers 3/10), Bank 116 MGT 0, X0Y4
set_property -dict {PACKAGE_PIN G4} [get_ports {QSFP_RX_P[2]}]
set_property -dict {PACKAGE_PIN G3} [get_ports {QSFP_RX_N[2]}]
set_property -dict {PACKAGE_PIN F2} [get_ports {QSFP_TX_P[2]}]
set_property -dict {PACKAGE_PIN F1} [get_ports {QSFP_TX_N[2]}]
# QSFP1-0 (Fibers 1/12), Bank 116 MGT 1, X0Y5
set_property -dict {PACKAGE_PIN E4} [get_ports {QSFP_RX_P[0]}]
set_property -dict {PACKAGE_PIN E3} [get_ports {QSFP_RX_N[0]}]
set_property -dict {PACKAGE_PIN D2} [get_ports {QSFP_TX_P[0]}]
set_property -dict {PACKAGE_PIN D1} [get_ports {QSFP_TX_N[0]}]
# QSFP1-1 (Fibers 2/11), Bank 116 MGT 2, X0Y6
set_property -dict {PACKAGE_PIN C4} [get_ports {QSFP_RX_P[1]}]
set_property -dict {PACKAGE_PIN C3} [get_ports {QSFP_RX_N[1]}]
set_property -dict {PACKAGE_PIN B2} [get_ports {QSFP_TX_P[1]}]
set_property -dict {PACKAGE_PIN B1} [get_ports {QSFP_TX_N[1]}]
# QSFP1-3 (Fibers 4/9), Bank 116 MGT 3, X0Y7
set_property -dict {PACKAGE_PIN B6} [get_ports {QSFP_RX_P[3]}]
set_property -dict {PACKAGE_PIN B5} [get_ports {QSFP_RX_N[3]}]
set_property -dict {PACKAGE_PIN A4} [get_ports {QSFP_TX_P[3]}]
set_property -dict {PACKAGE_PIN A3} [get_ports {QSFP_TX_N[3]}]
# Bank 116, reference clock 0
set_property -dict {PACKAGE_PIN D6} [get_ports MGTREFCLK0_116_P]
set_property -dict {PACKAGE_PIN D5} [get_ports MGTREFCLK0_116_N]
create_clock -period 8.000 -name MGT_REFCLK0 [get_ports MGTREFCLK0_116_P]
# Bank 116, reference clock 1
#set_property -dict {PACKAGE_PIN F6} [get_ports MGTREFCLK1_116_P]
#set_property -dict {PACKAGE_PIN F5} [get_ports MGTREFCLK1_116_N]
#create_clock -period 8.000 -name MGT_REFCLK1 [get_ports MGTREFCLK1_116_P]

# Miscellaneous
# Bank 0 setup
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Compress image
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]










