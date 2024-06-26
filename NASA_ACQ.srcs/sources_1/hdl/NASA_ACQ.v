/*
 * MIT License
 *
 * Copyright (c) 2023 Osprey DCS
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * Top level module
 */
`default_nettype none
module NASA_ACQ #(
    `include "gpio.v"
    parameter DEBUG = "false"
    ) (
    input  wire DDR_REF_CLK_P,
    input  wire DDR_REF_CLK_N,
    input  wire MGTREFCLK0_116_P,
    input  wire MGTREFCLK0_116_N,
    input  wire CLK20_VCXO,
    output wire VCXO_EN,

    output wire BOOT_CS_B,
    output wire BOOT_MOSI,
    input  wire BOOT_MISO,

    input  wire FPGA_TxD,
    output wire FPGA_RxD,

    inout  wire I2C_FPGA_SCL,
    inout  wire I2C_FPGA_SDA,
    output wire I2C_FPGA_SW_RSTn,

    input  wire FPGA_SCLK,
    input  wire FPGA_CSB,
    input  wire FPGA_MOSI,
    output wire FPGA_MISO,

    output wire WR_DAC_SCLK_T,
    output wire WR_DAC_DIN_T,
    output wire WR_DAC1_SYNC_Tn,
    output wire WR_DAC2_SYNC_Tn,

    input  wire       RGMII_RX_CLK,
    input  wire       RGMII_RX_CTRL,
    input  wire [3:0] RGMII_RXD,
    output wire       RGMII_TX_CLK,
    output wire       RGMII_TX_CTRL,
    output wire [3:0] RGMII_TXD,
    output wire       RGMII_PHY_RESET_n,

    input  wire [CFG_MGT_COUNT-1:0] QSFP_RX_P,
    input  wire [CFG_MGT_COUNT-1:0] QSFP_RX_N,
    output wire [CFG_MGT_COUNT-1:0] QSFP_TX_P,
    output wire [CFG_MGT_COUNT-1:0] QSFP_TX_N,

    output wire PMOD1_0,
    output wire PMOD1_1,
    output wire PMOD1_2,
    output wire PMOD1_3,
    output wire PMOD1_4,
    input  wire PMOD1_5,
    input  wire PMOD1_6,
    input  wire PMOD1_7,

    input  wire PMOD2_0,
    input  wire PMOD2_1,
    input  wire PMOD2_2,
    input  wire PMOD2_3,  // PMOD-GPS PPS
    input  wire PMOD2_4,
    input  wire PMOD2_5,
    input  wire PMOD2_6,
    input  wire PMOD2_7,

    // Osprey Quad AD7768 FMC Digitizer
    output wire                                 AD7768_MCLK_P,
    output wire                                 AD7768_MCLK_N,
    output wire                                 AD7768_RESET_n,
    output wire                                 AD7768_SCLK,
    output wire     [CFG_AD7768_CHIP_COUNT-1:0] AD7768_CS_n,
    output wire                                 AD7768_SDI,
    input  wire     [CFG_AD7768_CHIP_COUNT-1:0] AD7768_SDO,
    input  wire     [CFG_AD7768_CHIP_COUNT-1:0] AD7768_DCLK,
    input  wire     [CFG_AD7768_CHIP_COUNT-1:0] AD7768_DRDY,
    input  wire [(CFG_AD7768_CHIP_COUNT *
                  CFG_AD7768_ADC_PER_CHIP)-1:0] AD7768_DOUT,
    output wire                                 AD7768_START_n,
    input  wire                                 AD7768_SYNC_IN_n,
    input  wire                                 AD7768_SYNC_OUT_n,

    output wire                                 COIL_CONTROL_SPI_CLK,
    output wire                                 COIL_CONTROL_SPI_CS_n,
    input  wire                                 COIL_CONTROL_SPI_DOUT,
    output wire                                 COIL_CONTROL_SPI_DIN,
    output wire                                 COIL_CONTROL_RESET_n,
    input  wire                                 COIL_CONTROL_FLAGS_n,

    output wire                                  AMC7823_SPI_CLK,
    output wire                                  AMC7823_SPI_CS_n,
    input  wire                                  AMC7823_SPI_DOUT,
    output wire                                  AMC7823_SPI_DIN,

    input  wire                                 MCLKfanoutValid,
    input  wire                                 HARDWARE_PPS
    );

///////////////////////////////////////////////////////////////////////////////
// Static outputs
assign VCXO_EN = 1'b1;
assign WR_DAC2_SYNC_Tn = 1'b1;

///////////////////////////////////////////////////////////////////////////////
// Clocks
wire sysClk, acqClk, fixedClk200, evrRxClk, evfRxClk, evgClk;
wire clk32, clk32p768, clk40p96, clk51p2, clk64, mclk;
wire refClk125;
IBUFGDS DDR_REF_CLK_BUF(.I(DDR_REF_CLK_P), .IB(DDR_REF_CLK_N), .O(refClk125));

///////////////////////////////////////////////////////////////////////////////
// General-purpose I/O register glue
wire [31:0] GPIO_OUT;
wire [GPIO_IDX_COUNT-1:0] GPIO_STROBES;
wire [31:0] GPIO_IN [0:GPIO_IDX_COUNT-1];
wire [(GPIO_IDX_COUNT*32)-1:0] GPIO_IN_FLATTENED;
genvar i;
generate
for (i = 0 ; i < GPIO_IDX_COUNT ; i = i + 1) begin
    assign GPIO_IN_FLATTENED[i*32+:32] = GPIO_IN[i];
end
endgenerate

`include "firmwareBuildDate.v"
assign GPIO_IN[GPIO_IDX_FIRMWARE_DATE] = FIRMWARE_BUILD_DATE;

///////////////////////////////////////////////////////////////////////////////
// Keep track of elapsed time
wire microsecondStrobe;
sysClkCounters #(.CLK_RATE(CFG_SYSCLK_RATE), .DEBUG("false"))
 sysClkCounters (
    .clk(sysClk),
    .usecStrobe(microsecondStrobe),
    .microsecondsSinceBoot(GPIO_IN[GPIO_IDX_MICROSECONDS_SINCE_BOOT]),
    .secondsSinceBoot(GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT]));

///////////////////////////////////////////////////////////////////////////////
// Lock clock to PPS marker
// DAC1 adjusts the 125 MHz MGT reference, DDR reference, and system clocks.
// DAC2 adjusts the 20 MHz system clock.
// If event generator sync to hardware PPS marker, otherwise the event.
wire isEVG, hwPPSvalid, ppsMarker, evrPPSmarker;
marbleClockSync #(
    .CLK_RATE(CFG_ACQCLK_RATE),
    .DAC_COUNTS_PER_HZ(CFG_MARBLE_VCXO_COUNTS_PER_HZ),
    .DEBUG("false"))
  marbleClockSync (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_ACQCLK_PLL_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_ACQCLK_PLL_CSR]),
    .sysAuxStatus(GPIO_IN[GPIO_IDX_ACQCLK_PLL_AUX_STATUS]),
    .sysHwInterval(GPIO_IN[GPIO_IDX_ACQCLK_HW_INTERVAL]),
    .sysPPSjitter(GPIO_IN[GPIO_IDX_ACQCLK_HW_JITTER]),
    .stableClk200(fixedClk200),
    .clk(acqClk),
    .ppsPrimary_a(isEVG ? HARDWARE_PPS : evrPPSmarker),
    .ppsSecondary_a(isEVG ? PMOD2_3 : 1'b0),
    .isOffsetBinary(1'b0),
    .hwPPSvalid(hwPPSvalid),
    .ppsStrobe(),
    .ppsMarker(ppsMarker),
    .ppsToggle(),
    .SPI_CLK(WR_DAC_SCLK_T),
    .SPI_SYNCn(WR_DAC1_SYNC_Tn),
    .SPI_SDI(WR_DAC_DIN_T));

///////////////////////////////////////////////////////////////////////////////
// Basic MRF-comptatible event receiver, generator, and fanout.
// Machine protection data transfer.
localparam TIMESTAMP_WIDTH = 64;
wire [TIMESTAMP_WIDTH-1:0] sysTimestamp, acqTimestamp;
wire acqPPSstrobe;
wire evrRxStartACQstrobe, evrRxStopACQstrobe, evrRxClearMPSstrobe;
wire  [7:0] evgTxCode;
wire        evgTxCodeValid;
wire [15:0] mpsTxChars;
wire        mpsTxCharIsK;
fiberLinks #(
    .MGT_COUNT(CFG_MGT_COUNT),
    .MGT_DATA_WIDTH(16),
    .MPS_OUTPUT_COUNT(CFG_MPS_OUTPUT_COUNT),
    .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
    .EVR_ACQ_START_CODE(CFG_EVR_ACQ_START_CODE),
    .EVR_ACQ_STOP_CODE(CFG_EVR_ACQ_STOP_CODE),
    .EVR_MPS_CLEAR_CODE(CFG_EVR_MPS_CLEAR_CODE),
    .DEBUG("false"),
    .DEBUG_MGT("true"),
    .DEBUG_EVR("true"),
    .DEBUG_EVF("false"),
    .DEBUG_EVG("false"))
  fiberLinks (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_MGT_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_MGT_CSR]),
    .sysLinkStatus(GPIO_IN[GPIO_IDX_LINK_STATUS]),
    .sysEVGsetTimeStrobe(GPIO_STROBES[GPIO_IDX_EVG_CSR]),
    .sysMPSmergeStrobe(GPIO_STROBES[GPIO_IDX_MPS_MERGE_CSR]),
    .sysMPSmergeStatus(GPIO_IN[GPIO_IDX_MPS_MERGE_CSR]),
    .sysEVGstatus(GPIO_IN[GPIO_IDX_EVG_CSR]),
    .evrRxClk(evrRxClk),
    .evrRxStartACQstrobe(evrRxStartACQstrobe),
    .evrRxStopACQstrobe(evrRxStopACQstrobe),
    .evrRxClearMPSstrobe(evrRxClearMPSstrobe),
    .evfRxClk(evfRxClk),
    .ppsValid(hwPPSvalid),
    .hwPPSmarker_a(ppsMarker),
    .evrPPSmarker(evrPPSmarker),
    .isEVG(isEVG),
    .mgtTxClk(evgClk),
    .evgTxCode(evgTxCode),
    .evgTxCodeValid(evgTxCodeValid),
    .mpsTxChars(mpsTxChars),
    .mpsTxCharIsK(mpsTxCharIsK),
    .sysTimestamp(sysTimestamp),
    .acqClk(acqClk),
    .acqTimestamp(acqTimestamp),
    .acqPPSstrobe(acqPPSstrobe),
    .gtRefClkP(MGTREFCLK0_116_P),
    .gtRefClkN(MGTREFCLK0_116_N),
    .rxP(QSFP_RX_P),
    .rxN(QSFP_RX_N),
    .txP(QSFP_TX_P),
    .txN(QSFP_TX_N));
assign GPIO_IN[GPIO_IDX_SYS_TIMESTAMP_SECONDS] = sysTimestamp[32+:32];
assign GPIO_IN[GPIO_IDX_SYS_TIMESTAMP_TICKS]   = sysTimestamp[0+:32];

///////////////////////////////////////////////////////////////////////////////
// Measure interval between hardware and event receiver PPS markers
// Useful only for event generator node.
ppsLatencyCheck #(.CLK_RATE(CFG_SYSCLK_RATE))
  ppsLatencyCheck (
    .clk(sysClk),
    .latency(GPIO_IN[GPIO_IDX_PPS_LATENCY]),
    .hwPPS_a(ppsMarker),
    .evrPPSmarker_a(evrPPSmarker));

///////////////////////////////////////////////////////////////////////////////
// Measure clocks
wire [29:0] measuredFrequency;
wire measuredUsingInteralAcqMarker;
reg [2:0] frequencyChannelSelect = 0;
frequencyCounters #(
    .CLOCKS_PER_ACQUISITION(CFG_SYSCLK_RATE),
    .CHANNEL_COUNT(5))
  frequencyCounters (
    .clk(sysClk),
    .measuredClocks({ evfRxClk,
                      evrRxClk,
                      evgClk,
                      acqClk,
                      sysClk }),
    .acqMarker_a(hwPPSvalid && ppsMarker),
    .useInternalAcqMarker(measuredUsingInteralAcqMarker),
    .channelSelect(frequencyChannelSelect),
    .frequency(measuredFrequency));

always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_FREQUENCY_COUNTERS]) begin
        frequencyChannelSelect <= GPIO_OUT[2:0];
    end
end
assign GPIO_IN[GPIO_IDX_FREQUENCY_COUNTERS] = { measuredUsingInteralAcqMarker,
                                                      1'b0, measuredFrequency };

//////////////////////////////////////////////////////////////////////////////
// Drive boot flash SCLK from block design FLASH_SPI_sclk after initialization.
wire BOOT_SCLK, startupEOS;
STARTUPE2 aspiClkPin
     (.CLK(1'b0),
      .GSR(1'b0),
      .GTS(1'b0),
      .KEYCLEARB(1'b1),
      .PACK(1'b0),
      .PREQ(),
      .USRCCLKO(BOOT_SCLK),
      .USRCCLKTS(1'b0),
      .USRDONEO(1'b0),
      .USRDONETS(1'b1),
      .CFGCLK(),
      .CFGMCLK(),
      .EOS(startupEOS));

///////////////////////////////////////////////////////////////////////////////
// FPGA I2C
wire i2c_fpga_scl_o, i2c_fpga_scl_i, i2c_fpga_scl_t;
wire i2c_fpga_sda_o, i2c_fpga_sda_i, i2c_fpga_sda_t;
IOBUF i2c_fpga_scl_iobuf (.I(i2c_fpga_scl_o),
                          .O(i2c_fpga_scl_i),
                          .T(i2c_fpga_scl_t),
                          .IO(I2C_FPGA_SCL));
IOBUF i2c_fpga_sda_iobuf (.I(i2c_fpga_sda_o),
                          .O(i2c_fpga_sda_i),
                          .T(i2c_fpga_sda_t),
                          .IO(I2C_FPGA_SDA));

///////////////////////////////////////////////////////////////////////////////
// Microcontroller I/O
mmcIO #(.DEBUG("false"))
  mmcIO (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_MMC_IO]),
    .GPIO_OUT(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_MMC_IO]),
    .MMC_SCLK(FPGA_SCLK),
    .MMC_CSB(FPGA_CSB),
    .MMC_MOSI(FPGA_MOSI),
    .MMC_MISO(FPGA_MISO));

///////////////////////////////////////////////////////////////////////////////
// AMC7832 FMC Monitoring
amc7823SPI #(.CLK_RATE(CFG_SYSCLK_RATE))
  amc7823SPI (
    .clk(sysClk),
    .GPIO_OUT(GPIO_OUT),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_DIGITIZER_AMC7823]),
    .status(GPIO_IN[GPIO_IDX_DIGITIZER_AMC7823]),
    .SPI_CLK(AMC7823_SPI_CLK),
    .SPI_CS_n(AMC7823_SPI_CS_n),
    .SPI_DOUT(AMC7823_SPI_DOUT),
    .SPI_DIN(AMC7823_SPI_DIN));

///////////////////////////////////////////////////////////////////////////////
// AD7768 FMC ADC
wire ad7768Strobe;
wire [(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP*CFG_AD7768_WIDTH)-1:0]
                                                                     ad7768Data;
wire [(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP*8)-1:0] ad7768Headers;

// Analog input numbers do not map directly to DOUT lines (!!!).
// Untangle them here.
wire [(CFG_AD7768_CHIP_COUNT * CFG_AD7768_ADC_PER_CHIP)-1:0] AD7768_DOUT_MAPPED;
quartzMapDOUT #(
    .AD7768_CHIP_COUNT(CFG_AD7768_CHIP_COUNT),
    .ADC_PER_CHIP(CFG_AD7768_ADC_PER_CHIP))
  quartzMapDOUT(
    .DOUT_RAW(AD7768_DOUT),
    .DOUT_MAPPED(AD7768_DOUT_MAPPED));

ad7768 #(
    .ADC_CHIP_COUNT(CFG_AD7768_CHIP_COUNT),
    .ADC_PER_CHIP(CFG_AD7768_ADC_PER_CHIP),
    .ADC_WIDTH(CFG_AD7768_WIDTH),
    .SYSCLK_RATE(CFG_SYSCLK_RATE),
    .ACQ_CLK_RATE(CFG_ACQCLK_RATE),
    .MCLK_MAX_RATE(CFG_MCLK_MAX_RATE),
    .DEBUG_DRDY("false"),
    .DEBUG_ALIGN("false"),
    .DEBUG_ACQ("false"),
    .DEBUG_PINS("false"),
    .DEBUG_SPI("false"))
  ad7768 (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_AD7768_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_AD7768_CSR]),
    .sysDRDYstatus(GPIO_IN[GPIO_IDX_AD7768_DRDY_STATUS]),
    .sysDRDYhistory(GPIO_IN[GPIO_IDX_AD7768_DRDY_HISTORY]),
    .sysAlignCount(GPIO_IN[GPIO_IDX_AD7768_ALIGN_COUNT]),
    .clk32(clk32),
    .acqClk(acqClk),
    .acqPPSstrobe(acqPPSstrobe),
    .acqStrobe(ad7768Strobe),
    .acqData(ad7768Data),
    .acqHeaders(ad7768Headers),
    .adcSCLK(AD7768_SCLK),
    .adcCSn(AD7768_CS_n),
    .adcSDI(AD7768_SDI),
    .adcSDO(AD7768_SDO),
    .adcDCLK_a(AD7768_DCLK),
    .adcDRDY_a(AD7768_DRDY),
    .adcDOUT_a(AD7768_DOUT_MAPPED),
    .adcSTARTn(AD7768_START_n),
    .adcRESETn(AD7768_RESET_n));

assign PMOD1_0 = AD7768_DCLK[0];
assign PMOD1_1 = AD7768_DRDY[0];
assign PMOD1_2 = acqStrobe;
assign PMOD1_3 = acqPPSstrobe;
assign PMOD1_4 = AD7768_START_n;

// Need different MCLK values to get the sampling rates we need.
mclkSelect #(.DEBUG("false"))
  mclkSelect (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_MCLK_SELECT_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .mclkRate(GPIO_IN[GPIO_IDX_MCLK_SELECT_CSR]),
    .acqClk(acqClk),
    .acqPPSstrobe(acqPPSstrobe),
    .clk32p768(clk32p768),
    .clk40p96(clk40p96),
    .clk51p2(clk51p2),
    .clk64(clk64),
    .MCLK(mclk));
OBUFDS AD7768_MCLK_OBUF(.I(mclk), .O(AD7768_MCLK_P), .OB(AD7768_MCLK_N));

///////////////////////////////////////////////////////////////////////////////
// AC/DC coupling
wire coupledDataStrobe;
wire [(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP*CFG_AD7768_WIDTH)-1:0]
                                                                   coupledData;
inputCoupling #(
    .CHANNEL_COUNT(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP),
    .DATA_WIDTH(CFG_AD7768_WIDTH),
    .DEBUG("false"))
  inputCoupling_i (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_INPUT_COUPLING_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_INPUT_COUPLING_CSR]),
    .clk(acqClk),
    .inTDATA(ad7768Data),
    .inTVALID(ad7768Strobe),
    .outTDATA(coupledData),
    .outTVALID(coupledDataStrobe));

coilDriverSPI #(.CLK_RATE(CFG_SYSCLK_RATE))
  coilDriveSPI (
    .clk(sysClk),
    .GPIO_OUT(GPIO_OUT),
    .clrStrobe(GPIO_STROBES[GPIO_IDX_INPUT_COUPLING_CLR]),
    .setStrobeAndStart(GPIO_STROBES[GPIO_IDX_INPUT_COUPLING_SET_START]),
    .status(GPIO_IN[GPIO_IDX_INPUT_COUPLING_SET_START]),
    .SPI_CLK(COIL_CONTROL_SPI_CLK),
    .SPI_CS_n(COIL_CONTROL_SPI_CS_n),
    .SPI_DOUT(COIL_CONTROL_SPI_DOUT),
    .SPI_DIN(COIL_CONTROL_SPI_DIN),
    .COIL_CONTROL_RESET_n(COIL_CONTROL_RESET_n),
    .COIL_CONTROL_FLAGS_n(COIL_CONTROL_FLAGS_n));

///////////////////////////////////////////////////////////////////////////////
// Downsample
wire acqEnableAcquisition;
wire acqStrobe;
wire [(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP*CFG_AD7768_WIDTH)-1:0]
                                                                        acqData;
`ifdef notdef
rateSelect #(
    .CHANNEL_COUNT(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP),
    .DATA_WIDTH(CFG_AD7768_WIDTH),
    .DEBUG("false"))
  rateSelect (
    .sysClk(sysClk),
    .sysRateStrobe(GPIO_STROBES[GPIO_IDX_RATE_SELECT_CSR]),
    .sysFilterStrobe5(GPIO_STROBES[GPIO_IDX_DOWNSAMPLE_5_CSR]),
    .sysFilterStrobe2(GPIO_STROBES[GPIO_IDX_DOWNSAMPLE_2_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .acqClk(acqClk),
    .acqEnabled(acqEnableAcquisition),
    .S_TDATA(coupledData),
    .S_TVALID(coupledDataStrobe),
    .M_TDATA(acqData),
    .M_TVALID(acqStrobe));
`else
assign acqData = coupledData;
assign acqStrobe = coupledDataStrobe;
`endif

///////////////////////////////////////////////////////////////////////////////
// Build packet
wire [7:0] unbufPK_TDATA;
wire unbufPK_TVALID, unbufPK_TLAST, unbufPK_TREADY;
wire [(4*CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP)-1:0] acqLimitExcursions;
buildPacket #(
    .ADC_CHIP_COUNT(CFG_AD7768_CHIP_COUNT),
    .ADC_PER_CHIP(CFG_AD7768_ADC_PER_CHIP),
    .ADC_WIDTH(CFG_AD7768_WIDTH),
    .UDP_PACKET_CAPACITY(CFG_UDP_PACKET_CAPACITY),
    .ACQ_CLK_RATE(CFG_ACQCLK_RATE),
    .DEBUG("false"),
    .DEBUG_MERGE_LIMITS("false"),
    .DEBUG_REPORT_LIMITS("false"))
  buildPacket (
    .sysClk(sysClk),
    .sysActiveBitmapStrobe(GPIO_STROBES[GPIO_IDX_BUILD_PACKET_BITMAP]),
    .sysByteCountStrobe(GPIO_STROBES[GPIO_IDX_BUILD_PACKET_BYTECOUNT]),
    .sysThresholdStrobe(GPIO_STROBES[GPIO_IDX_ADC_THRESHOLDS]),
    .sysLimitExcursionStrobe(GPIO_STROBES[GPIO_IDX_ADC_EXCURSIONS]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_BUILD_PACKET_STATUS]),
    .sysActiveRbk(GPIO_IN[GPIO_IDX_BUILD_PACKET_BITMAP]),
    .sysByteCountRbk(GPIO_IN[GPIO_IDX_BUILD_PACKET_BYTECOUNT]),
    .sysLimitExcursions(GPIO_IN[GPIO_IDX_ADC_EXCURSIONS]),
    .sysTimeValid(GPIO_IN[GPIO_IDX_LINK_STATUS][31]),
    .acqClk(acqClk),
    .acqStrobe(acqStrobe),
    .acqData(acqData),
    .acqLimitExcursions(acqLimitExcursions),
    .acqSeconds(acqTimestamp[63:32]),
    .acqTicks(acqTimestamp[31:0]),
    .acqClkLocked(GPIO_IN[GPIO_IDX_ACQCLK_PLL_CSR][31]),
    .acqEnableAcquisition(acqEnableAcquisition),
    .M_TVALID(unbufPK_TVALID),
    .M_TLAST(unbufPK_TLAST),
    .M_TDATA(unbufPK_TDATA),
    .M_TREADY(unbufPK_TREADY));

// Provide some elastic buffering to fast data stream
wire [7:0] PK_TDATA;
wire PK_TVALID, PK_TLAST, PK_TREADY;
fastDataFIFO fastDataFIFO (
  .s_axis_aresetn(1'b1),
  .s_axis_aclk(acqClk),
  .s_axis_tvalid(unbufPK_TVALID),
  .s_axis_tready(unbufPK_TREADY),
  .s_axis_tdata(unbufPK_TDATA),
  .s_axis_tlast(unbufPK_TLAST),
  .m_axis_tvalid(PK_TVALID),
  .m_axis_tready(PK_TREADY),
  .m_axis_tdata(PK_TDATA),
  .m_axis_tlast(PK_TLAST));

///////////////////////////////////////////////////////////////////////////////
// Event generator side of acquisition control
evgAcqControl #(
    .EVCODE_ACQ_START(CFG_EVR_ACQ_START_CODE),
    .EVCODE_ACQ_STOP(CFG_EVR_ACQ_STOP_CODE),
    .EVG_CLK_RATE(CFG_EVG_CLK_RATE),
    .DEBUG("false"))
  evgAcqControl (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_EVG_ACQ_CSR]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_EVG_ACQ_CSR]),
    .evgClk(evgClk),
    .evgEventCode(evgTxCode),
    .evgEventCodeValid(evgTxCodeValid),
    .acqClk(acqClk),
    .acqStrobe(ad7768Strobe));

///////////////////////////////////////////////////////////////////////////////
// Event receiver side of acquisition control
evrAcqControl #(.DEBUG("false"))
  evrAcqControl (
    .evrClk(evrRxClk),
    .evrRxStartACQstrobe(evrRxStartACQstrobe),
    .evrRxStopACQstrobe(evrRxStopACQstrobe),
    .acqClk(acqClk),
    .acqEnableAcquisition(acqEnableAcquisition));

///////////////////////////////////////////////////////////////////////////////
// MPS
mpsLocal #(
    .MPS_OUTPUT_COUNT(CFG_MPS_OUTPUT_COUNT),
    .MPS_INPUT_COUNT(CFG_MPS_INPUT_COUNT),
    .ADC_COUNT(CFG_AD7768_CHIP_COUNT*CFG_AD7768_ADC_PER_CHIP),
    .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
    .DEBUG(DEBUG))
  mpsLocal_i (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_MPS_CSR]),
    .sysDataStrobe(GPIO_STROBES[GPIO_IDX_MPS_DATA]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_MPS_CSR]),
    .sysData(GPIO_IN[GPIO_IDX_MPS_DATA]),
    .evrClk(evrRxClk),
    .evrClearMPSstrobe(evrRxClearMPSstrobe),
    .acqClk(acqClk),
    .acqLimitExcursions(acqLimitExcursions),
    .acqLimitExcursionsTVALID(acqStrobe),
    .acqTimestamp(acqTimestamp),
    .mpsInputStates_a({PMOD2_7,PMOD2_6,PMOD2_5,PMOD2_4,PMOD2_3,PMOD2_2,PMOD2_1,PMOD2_0}), // FIXME -- how will interlock inputs be handed for real?
    .mgtTxClk(evgClk),
    .mpsTxChars(mpsTxChars),
    .mpsTxCharIsK(mpsTxCharIsK));

///////////////////////////////////////////////////////////////////////////////
// Delay data from PHY
wire [3:0] rgmiiDataDelayed;
wire       rgmiiCtrlDelayed;
ethernetRxDelay ethernetRxDelay_inst (
    .refClk200(fixedClk200),
    .rst(!RGMII_PHY_RESET_n),
    .phyDataIn({RGMII_RX_CTRL, RGMII_RXD}),
    .phyDataOut({rgmiiCtrlDelayed, rgmiiDataDelayed}));

///////////////////////////////////////////////////////////////////////////////
// Block design
bd bd_i (
    .refClk125(refClk125),
    .ext_reset_n(1'b1),
    .CLK20_VCXO(CLK20_VCXO),
    .startupEOS(startupEOS),

    .sysClk(sysClk),
    .clk125(acqClk),
    .fixedClk200(fixedClk200),
    .clk32(clk32),
    .clk32p768(clk32p768),
    .clk40p96(clk40p96),
    .clk51p2(clk51p2),
    .clk64(clk64),

    .FLASH_SPI_sclk(BOOT_SCLK),
    .FLASH_SPI_csb(BOOT_CS_B),
    .FLASH_SPI_si(BOOT_MISO),
    .FLASH_SPI_so(BOOT_MOSI),

    .i2c_fpga_scl_i(i2c_fpga_scl_i),
    .i2c_fpga_scl_o(i2c_fpga_scl_o),
    .i2c_fpga_scl_t(i2c_fpga_scl_t),
    .i2c_fpga_sda_i(i2c_fpga_sda_i),
    .i2c_fpga_sda_o(i2c_fpga_sda_o),
    .i2c_fpga_sda_t(i2c_fpga_sda_t),
    .i2c_fpga_gpo(I2C_FPGA_SW_RSTn),

    .RGMII_rxc(RGMII_RX_CLK),
    .RGMII_rd(rgmiiDataDelayed),
    .RGMII_rx_ctl(rgmiiCtrlDelayed),
    .RGMII_txc(RGMII_TX_CLK),
    .RGMII_td(RGMII_TXD),
    .RGMII_tx_ctl(RGMII_TX_CTRL),
    .phy_reset_n(RGMII_PHY_RESET_n),
    .fastTx_tdata(PK_TDATA),
    .fastTx_tlast(PK_TLAST),
    .fastTx_tready(PK_TREADY),
    .fastTx_tvalid(PK_TVALID),

    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBES(GPIO_STROBES),
    .GPIO_IN(GPIO_IN_FLATTENED),

    .console_rxd(FPGA_TxD),
    .console_txd(FPGA_RxD)
    );
endmodule
`default_nettype wire
