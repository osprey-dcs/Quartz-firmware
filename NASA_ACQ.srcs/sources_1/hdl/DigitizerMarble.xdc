############################## Marble FMC1 ##############################

# FMC1 LA00 -- FMC1 G6/G7
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS25} [get_ports {AD7768_DRDY[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS25} [get_ports {AD7768_DCLK[1]}]

# FMC1 LA01 -- FMC1 D8/D9
#set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[1]}]
#set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[1]}]

# FMC1 LA02 -- FMC1 H7/H8
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[8]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[9]}]

# FMC1 LA03 -- FMC1 G9/G10
#set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[3]}]
#set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[3]}]

# FMC1 LA04 -- FMC1 H10/H11
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[10]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[11]}]

# FMC1 LA05 -- FMC1 D11/D12
#set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[5]}]
#set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[5]}]

# FMC1 LA06 -- FMC1 C10/C11
#set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[6]}]
#set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[6]}]

# FMC1 LA07 -- FMC1 H13/H14
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[12]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[13]}]

# FMC1 LA08 -- FMC1 G12/G13
#set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[8]}]
#set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[8]}]

# FMC1 LA09 -- FMC1 D14/D15
#set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[9]}]
#set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[9]}]

# FMC1 LA10 -- FMC1 C14/C15
#set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[10]}]
#set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[10]}]

# FMC1 LA11 -- FMC1 H16/H17
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[14]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[15]}]

# FMC1 LA12 -- FMC1 G15/G16
#set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[12]}]
#set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[12]}]

# FMC1 LA13 -- FMC1 D17/D18
#set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[13]}]
#set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[13]}]

# FMC1 LA14 -- FMC1 C18/C19
#set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[14]}]
#set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[14]}]

# FMC1 LA15 -- FMC1 H19/H20
set_property PACKAGE_PIN J15 [get_ports {AD7768_SDO[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {AD7768_SDO[1]}]
set_property PULLUP true [get_ports {AD7768_SDO[1]}]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS25} [get_ports {AD7768_CS_n[1]}]

# FMC1 LA16 -- FMC1 G18/G19
#set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[16]}]
#set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[16]}]

# FMC1 LA17 -- FMC1 D20/D21
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_RESET_n]
set_property -dict {PACKAGE_PIN W25 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_CLK]

# FMC1 LA18 -- FMC1 C22/C23
#set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[18]}]
#set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[18]}]

# FMC1 LA19 -- FMC1 H22/H23
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[0]}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[1]}]

# FMC1 LA20 -- FMC1 G21/G22
#set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[20]}]
#set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[20]}]

# FMC1 LA21 -- FMC1 H25/H26
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[2]}]
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[3]}]

# FMC1 LA22 -- FMC1 G24/G25
#set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[22]}]
#set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[22]}]

# FMC1 LA23 -- FMC1 D23/D24
set_property -dict {PACKAGE_PIN AC23 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_DOUT]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_DIN]

# FMC1 LA24 -- FMC1 H28/H29
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[4]}]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[5]}]

# FMC1 LA25 -- FMC1 G27/G28
#set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[25]}]
#set_property -dict {PACKAGE_PIN G9  IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[25]}]

# FMC1 LA26 -- FMC1 D26/D27
#set_property -dict {PACKAGE_PIN E13 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[26]}]
#set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[26]}]

# FMC1 LA27 -- FMC1 C26/C27
#set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[27]}]
#set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[27]}]

# FMC1 LA28 -- FMC1 H31/H32
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[6]}]
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[7]}]

# FMC1 LA29 -- FMC1 G30/G31
#set_property -dict {PACKAGE_PIN F9 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_P[29]}]
#set_property -dict {PACKAGE_PIN F8 IOSTANDARD LVCMOS25} [get_ports {FMC1_LA_N[29]}]

# FMC1 LA30 -- FMC1 H34/H35
set_property PACKAGE_PIN B12 [get_ports {AD7768_SDO[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {AD7768_SDO[0]}]
set_property PULLUP true [get_ports {AD7768_SDO[0]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS25} [get_ports AD7768_SDI]

# FMC1 LA31 -- FMC1 G33/G34
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS25} [get_ports AD7768_START_n]
set_property -dict {PACKAGE_PIN A12 IOSTANDARD LVCMOS25} [get_ports AD7768_RESET_n]

# FMC1 LA32 -- FMC1 H37/H38
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS25} [get_ports AD7768_SCLK]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS25} [get_ports {AD7768_CS_n[0]}]

# FMC1 LA33 -- FMC1 G36/G37
set_property -dict {PACKAGE_PIN B10 IOSTANDARD LVCMOS25} [get_ports {AD7768_DRDY[0]}]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS25} [get_ports {AD7768_DCLK[0]}]


############################## Marble FMC1 ##############################

# FMC2 LA00 -- FMC2 G6/G7
#set_property -dict {PACKAGE_PIN Y22  IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[0]}]
#set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[0]}]

# FMC2 LA01 -- FMC2 D8/D9
set_property PACKAGE_PIN AA23 [get_ports HARDWARE_PPS]
set_property IOSTANDARD LVCMOS25 [get_ports HARDWARE_PPS]
set_property PULLUP true [get_ports HARDWARE_PPS]
set_property -dict {PACKAGE_PIN AB24 IOSTANDARD LVCMOS25} [get_ports MCLKfanoutValid]

# FMC2 LA02 -- FMC2 H7/H8
set_property -dict {PACKAGE_PIN AE22 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[24]}]
set_property -dict {PACKAGE_PIN AF22 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[25]}]

# FMC2 LA03 -- FMC2 G9/G10
set_property -dict {PACKAGE_PIN AD26 IOSTANDARD LVCMOS25} [get_ports AMC7823_SPI_DOUT]
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_FLAGS_n]

# FMC2 LA04 -- FMC2 H10/H11
set_property -dict {PACKAGE_PIN V21 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[26]}]
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[27]}]

# FMC2 LA05 -- FMC2 D11/D12
#set_property -dict {PACKAGE_PIN AB26 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[5]}]
#set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[5]}]

# FMC2 LA06 -- FMC2 C10/C11
#set_property -dict {PACKAGE_PIN AD23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[6]}]
#set_property -dict {PACKAGE_PIN AD24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[6]}]

# FMC2 LA07 -- FMC2 H13/H14
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[28]}]
set_property -dict {PACKAGE_PIN AC22 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[29]}]

# FMC2 LA08 -- FMC2 G12/G13
set_property -dict {PACKAGE_PIN AC23 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_DOUT]
set_property -dict {PACKAGE_PIN AC24 IOSTANDARD LVCMOS25} [get_ports AMC7823_SPI_CLK]

# FMC2 LA09 -- FMC2 D14/D15
#set_property -dict {PACKAGE_PIN U26 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[9]}]
#set_property -dict {PACKAGE_PIN V26 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[9]}]

# FMC2 LA10 -- FMC2 C14/C15
#set_property -dict {PACKAGE_PIN AE23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[10]}]
#set_property -dict {PACKAGE_PIN AF23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[10]}]

# FMC2 LA11 -- FMC2 H16/H17
set_property -dict {PACKAGE_PIN W23 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[30]}]
set_property -dict {PACKAGE_PIN W24 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[31]}]

# FMC2 LA12 -- FMC2 G15/G16
set_property -dict {PACKAGE_PIN AA25 IOSTANDARD LVCMOS25} [get_ports AMC7823_SPI_DIN]
set_property -dict {PACKAGE_PIN AB25 IOSTANDARD LVCMOS25} [get_ports AMC7823_SPI_CS_n]

# FMC2 LA13 -- FMC2 D17/D18
#set_property -dict {PACKAGE_PIN V23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[13]}]
#set_property -dict {PACKAGE_PIN V24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[13]}]

# FMC2 LA14 -- FMC2 C18/C19
#set_property -dict {PACKAGE_PIN U24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[14]}]
#set_property -dict {PACKAGE_PIN U25 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[14]}]

# FMC2 LA15 -- FMC2 H19/H20
set_property PACKAGE_PIN U22 [get_ports {AD7768_SDO[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {AD7768_SDO[3]}]
set_property PULLUP true [get_ports {AD7768_SDO[3]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS25} [get_ports {AD7768_CS_n[3]}]

# FMC2 LA16 -- FMC2 G18/G19
set_property -dict {PACKAGE_PIN W25 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_CLK]
set_property -dict {PACKAGE_PIN W26 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_CS_n]

# FMC2 LA17 -- FMC2 D20/D21
#set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[17]}]
#set_property -dict {PACKAGE_PIN F23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[17]}]

# FMC2 LA18 -- FMC2 C22/C23
#set_property -dict {PACKAGE_PIN G24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[18]}]
#set_property -dict {PACKAGE_PIN F24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[18]}]

# FMC2 LA19 -- FMC2 H22/H23
set_property -dict {PACKAGE_PIN K23 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[16]}]
set_property -dict {PACKAGE_PIN J23 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[17]}]

# FMC2 LA20 -- FMC2 G21/G22
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_RESET_n]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS25} [get_ports COIL_CONTROL_SPI_DIN]

# FMC2 LA21 -- FMC2 H25/H26
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[18]}]
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[19]}]

# FMC2 LA22 -- FMC2 G24/G25
set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS25} [get_ports {AD7768_DRDY[2]}]
set_property -dict {PACKAGE_PIN D25 IOSTANDARD LVCMOS25} [get_ports {AD7768_DCLK[2]}]

# FMC2 LA23 -- FMC2 D23/D24
#set_property -dict {PACKAGE_PIN H23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[23]}]
#set_property -dict {PACKAGE_PIN H24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[23]}]

# FMC2 LA24 -- FMC2 H28/H29
set_property -dict {PACKAGE_PIN J24 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[20]}]
set_property -dict {PACKAGE_PIN J25 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[21]}]

# FMC2 LA25 -- FMC2 G27/G28
#set_property -dict {PACKAGE_PIN D23 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[25]}]
#set_property -dict {PACKAGE_PIN D24 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[25]}]

# FMC2 LA26 -- FMC2 D26/D27
#set_property -dict {PACKAGE_PIN F25 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[26]}]
#set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[26]}]

# FMC2 LA27 -- FMC2 C26/C27
#set_property -dict {PACKAGE_PIN H21 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[27]}]
#set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[27]}]

# FMC2 LA28 -- FMC2 H31/H32
set_property -dict {PACKAGE_PIN G25 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[22]}]
set_property -dict {PACKAGE_PIN G26 IOSTANDARD LVCMOS25} [get_ports {AD7768_DOUT[23]}]

# FMC2 LA29 -- FMC2 G30/G31
set_property -dict {PACKAGE_PIN J26 IOSTANDARD LVCMOS25} [get_ports {AD7768_DRDY[3]}]
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS25} [get_ports {AD7768_DCLK[3]}]

# FMC2 LA30 -- FMC2 H34/H35
set_property PACKAGE_PIN D26 [get_ports {AD7768_SDO[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {AD7768_SDO[2]}]
set_property PULLUP true [get_ports {AD7768_SDO[2]}]
set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVCMOS25} [get_ports {AD7768_CS_n[2]}]

# FMC2 LA31 -- FMC2 G33/G34
#set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[31]}]
#set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_N[31]}]

# FMC2 LA32 -- FMC2 H37/H38
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVDS_25} [get_ports AD7768_MCLK_P]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVDS_25} [get_ports AD7768_MCLK_N]

# FMC2 LA33 -- FMC2 G36/G37
#set_property -dict {PACKAGE_PIN C21 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[33]}]
#set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS25} [get_ports {FMC2_LA_P[33]}]

