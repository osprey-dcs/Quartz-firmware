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
 * Wrap wizard-generated Multi-Gigabit Transceivers
 * Eight transmitter lanes, two receiver lanes.
 */
`default_nettype none
module mgtWrapper #(
    parameter MGT_COUNT      = -1,
    parameter MGT_DATA_WIDTH = -1,
    parameter DEBUG          = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input  wire                 gtRefClk,
    input  wire [MGT_COUNT-1:0] rxP,
    input  wire [MGT_COUNT-1:0] rxN,
    output wire [MGT_COUNT-1:0] txP,
    output wire [MGT_COUNT-1:0] txN,

    output wire                                               evrRxClk,
    (*MARK_DEBUG=DEBUG*) output wire                          evrRxLinkUp,
    (*MARK_DEBUG=DEBUG*) output wire     [MGT_DATA_WIDTH-1:0] evrRxChars,
    (*MARK_DEBUG=DEBUG*) output wire [(MGT_DATA_WIDTH/8)-1:0] evrRxCharIsK,
    output wire                                               evfRxClk,
    (*MARK_DEBUG=DEBUG*) output wire                          evfRxLinkUp,
    (*MARK_DEBUG=DEBUG*) output wire     [MGT_DATA_WIDTH-1:0] evfRxChars,
    (*MARK_DEBUG=DEBUG*) output wire [(MGT_DATA_WIDTH/8)-1:0] evfRxCharIsK,
    output wire                                               mgtTxClk,
    (*MARK_DEBUG=DEBUG*) input  wire     [MGT_DATA_WIDTH-1:0] mgtTxChars,
    (*MARK_DEBUG=DEBUG*) input  wire [(MGT_DATA_WIDTH/8)-1:0] mgtTxIsK);

localparam MGT_STATUS_WIDTH = 4;
localparam MGT_SEL_WIDTH = MGT_COUNT > 1 ? $clog2(MGT_COUNT) : 1;
localparam MGT_BYTE_COUNT = MGT_DATA_WIDTH / 8;

localparam DRP_ADDR_WIDTH = 9;
localparam DRP_DATA_WIDTH = 16;
wire [MGT_SEL_WIDTH-1:0] sysMGTsel = sysGPIO_OUT[27+:MGT_SEL_WIDTH];
reg [MGT_SEL_WIDTH-1:0] mgtSel;
wire [MGT_STATUS_WIDTH-1:0] mgtStatus[0:MGT_COUNT-1];
reg  [MGT_STATUS_WIDTH-1:0] mgtStatusMux;
// Attachment points for internal logic analyzer
genvar i; generate for (i = 0 ; i < MGT_COUNT ; i = i + 1) begin : mgtStat
    (*MARK_DEBUG=DEBUG*) wire [MGT_STATUS_WIDTH-1:0] status = mgtStatus[i];
end endgenerate

/*
 * Dynamic reconfiguration port
 */
reg      [MGT_COUNT-1:0] drpEN = 0, drpWE = 0;
reg [DRP_ADDR_WIDTH-1:0] drpADDR;
reg [DRP_DATA_WIDTH-1:0] drpDI;
wire[DRP_DATA_WIDTH-1:0] drpDO [0:MGT_COUNT-1];
reg [DRP_DATA_WIDTH-1:0] drpDOmux = 0;
wire     [MGT_COUNT-1:0] drpRDY;
wire drpRDYmux = drpRDY[mgtSel];
reg busy = 0;

/*
 * Drive appropriate DRP or MGT control lines
 */
(*MARK_DEBUG=DEBUG*) reg pmareset = 0, rxreset = 0, txreset = 0;
(*MARK_DEBUG=DEBUG*) reg soft_reset_tx = 0, soft_reset_rx = 0;
always @(posedge sysClk) begin
    mgtStatusMux <= mgtStatus[mgtSel];
    if (busy) begin
        drpEN <= 0;
        drpWE <= 0;
        if (drpRDYmux) begin
            busy <= 0;
            drpDOmux <= drpDO[mgtSel];
        end
    end
    else if (sysCsrStrobe) begin
        mgtSel <= sysMGTsel;
        if (sysGPIO_OUT[31]) begin
            drpDI   <= sysGPIO_OUT[             0+:DRP_DATA_WIDTH];
            drpADDR <= sysGPIO_OUT[DRP_DATA_WIDTH+:DRP_ADDR_WIDTH];
            drpWE[sysMGTsel] <= sysGPIO_OUT[30];
            drpEN[sysMGTsel] <= 1;
            busy <= 1;
        end
        else begin
            pmareset             <= sysGPIO_OUT[0];
            rxreset              <= sysGPIO_OUT[1];
            txreset              <= sysGPIO_OUT[2];
            soft_reset_rx        <= sysGPIO_OUT[3];
            soft_reset_tx        <= sysGPIO_OUT[4];
        end
    end
end

/*
 * Check link validity
 */
(*MARK_DEBUG=DEBUG*) wire [MGT_DATA_WIDTH-1:0] evrRxData, evfRxData;
(*MARK_DEBUG=DEBUG*) wire [MGT_BYTE_COUNT-1:0] evrRxDataIsK, evfRxDataIsK;
(*MARK_DEBUG=DEBUG*) wire [MGT_BYTE_COUNT-1:0] evrRxNotInTable, evfRxNotInTable;
mgtLinkStatus #(
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MGT_BYTE_COUNT(MGT_BYTE_COUNT))
  evrLinkStatus (
    .clk(evrRxClk),
    .mgtData(evrRxData),
    .mgtDataIsK(evrRxDataIsK),
    .mgtNotInTable(evrRxNotInTable),
    .rxChars(evrRxChars),
    .rxCharIsK(evrRxCharIsK),
    .rxLinkUp(evrRxLinkUp));
mgtLinkStatus #(
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MGT_BYTE_COUNT(MGT_BYTE_COUNT))
  evfLinkStatus (
    .clk(evfRxClk),
    .mgtData(evfRxData),
    .mgtDataIsK(evfRxDataIsK),
    .mgtNotInTable(evfRxNotInTable),
    .rxChars(evfRxChars),
    .rxCharIsK(evfRxCharIsK),
    .rxLinkUp(evfRxLinkUp));

/*
 * Buffer the receiver and transmitter clocks
 */
wire txoutclk, rxoutclkEVR, rxoutclkEVF;
BUFG txoutclk_bufg(.I(txoutclk), .O(mgtTxClk));
BUFG rxoutclkEVR_bufg(.I(rxoutclkEVR), .O(evrRxClk));
BUFG rxoutclkEVF_bufg(.I(rxoutclkEVF), .O(evfRxClk));

/*
 * Instantiate the MGT common blocks.
 * Common block code (mgt_common.v) copied from example design.
 * Instantiation based on example design mgt_support.v.
 */
wire gt0_qplllock_in;
wire gt0_qpllrefclklost_in;
wire gt0_qpllreset_out;
wire gt0_qplloutclk_in;
wire gt0_qplloutrefclk_in;
wire gt1_qplllock_in;
wire gt1_qpllrefclklost_in;
wire gt1_qpllreset_out;
wire gt1_qplloutclk_in;
wire gt1_qplloutrefclk_in;

MGT_common # (
    .WRAPPER_SIM_GTRESET_SPEEDUP("TRUE"),
    .SIM_QPLLREFCLK_SEL(3'b001))
  common0_i (
    .QPLLREFCLKSEL_IN(3'b001),
    .GTREFCLK0_IN(gtRefClk),
    .GTREFCLK1_IN(1'b0),
    .QPLLLOCK_OUT(gt0_qplllock_in),
    .QPLLLOCKDETCLK_IN(sysClk),
    .QPLLOUTCLK_OUT(gt0_qplloutclk_in),
    .QPLLOUTREFCLK_OUT(gt0_qplloutrefclk_in),
    .QPLLREFCLKLOST_OUT(gt0_qpllrefclklost_in),
    .QPLLRESET_IN(gt0_qpllreset_out));
MGT_common # (
    .WRAPPER_SIM_GTRESET_SPEEDUP("TRUE"),
    .SIM_QPLLREFCLK_SEL(3'b001))
  common1_i (
    .QPLLREFCLKSEL_IN(3'b001),
    .GTREFCLK0_IN(gtRefClk),
    .GTREFCLK1_IN(1'b0),
    .QPLLLOCK_OUT(gt1_qplllock_in),
    .QPLLLOCKDETCLK_IN(sysClk),
    .QPLLOUTCLK_OUT(gt1_qplloutclk_in),
    .QPLLOUTREFCLK_OUT(gt1_qplloutrefclk_in),
    .QPLLREFCLKLOST_OUT(gt1_qpllrefclklost_in),
    .QPLLRESET_IN(gt1_qpllreset_out));

assign sysStatus = { busy,
                     1'b0,
                     gt1_qplllock_in, gt0_qplllock_in,
                     gt1_qpllrefclklost_in, gt0_qpllrefclklost_in,
                     {32-6-MGT_STATUS_WIDTH-DRP_DATA_WIDTH{1'b0}},
                     mgtStatusMux, drpDOmux };

/*
 * Instantiate all the transceivers
 */
MGT MGT_i (
    .sysclk_in(sysClk),                  // input wire sysclk_in
    .soft_reset_tx_in(soft_reset_tx),    // input wire soft_reset_tx_in
    .soft_reset_rx_in(soft_reset_rx),    // input wire soft_reset_rx_in
    .dont_reset_on_data_error_in(1'b1),  // input wire dont_reset_on_data_error_in
    .gt0_tx_fsm_reset_done_out(mgtStatus[4][0]), // output wire gt0_tx_fsm_reset_done_out
    .gt0_rx_fsm_reset_done_out(mgtStatus[4][1]), // output wire gt0_rx_fsm_reset_done_out
    .gt0_data_valid_in(1'b1),                    // input wire gt0_data_valid_in
    .gt1_tx_fsm_reset_done_out(mgtStatus[5][0]), // output wire gt1_tx_fsm_reset_done_out
    .gt1_rx_fsm_reset_done_out(mgtStatus[5][1]), // output wire gt1_rx_fsm_reset_done_out
    .gt1_data_valid_in(1'b1),                    // input wire gt1_data_valid_in
    .gt2_tx_fsm_reset_done_out(mgtStatus[6][0]), // output wire gt2_tx_fsm_reset_done_out
    .gt2_rx_fsm_reset_done_out(mgtStatus[6][1]), // output wire gt2_rx_fsm_reset_done_out
    .gt2_data_valid_in(1'b1),                    // input wire gt2_data_valid_in
    .gt3_tx_fsm_reset_done_out(mgtStatus[7][0]), // output wire gt3_tx_fsm_reset_done_out
    .gt3_rx_fsm_reset_done_out(mgtStatus[7][1]), // output wire gt3_rx_fsm_reset_done_out
    .gt3_data_valid_in(1'b1),                    // input wire gt3_data_valid_in
    .gt4_tx_fsm_reset_done_out(mgtStatus[3][0]), // output wire gt4_tx_fsm_reset_done_out
    .gt4_rx_fsm_reset_done_out(mgtStatus[3][1]), // output wire gt4_rx_fsm_reset_done_out
    .gt4_data_valid_in(1'b1),                    // input wire gt4_data_valid_in
    .gt5_tx_fsm_reset_done_out(mgtStatus[0][0]), // output wire gt5_tx_fsm_reset_done_out
    .gt5_rx_fsm_reset_done_out(mgtStatus[0][1]), // output wire gt5_rx_fsm_reset_done_out
    .gt5_data_valid_in(1'b1),                    // input wire gt5_data_valid_in
    .gt6_tx_fsm_reset_done_out(mgtStatus[1][0]), // output wire gt6_tx_fsm_reset_done_out
    .gt6_rx_fsm_reset_done_out(mgtStatus[1][1]), // output wire gt6_rx_fsm_reset_done_out
    .gt6_data_valid_in(1'b1),                    // input wire gt6_data_valid_in
    .gt7_tx_fsm_reset_done_out(mgtStatus[2][0]), // output wire gt7_tx_fsm_reset_done_out
    .gt7_rx_fsm_reset_done_out(mgtStatus[2][1]), // output wire gt7_rx_fsm_reset_done_out
    .gt7_data_valid_in(1'b1),                    // input wire gt7_data_valid_in

    //_________________________________________________________________________
    //GT0  (X0Y0)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt0_drpaddr_in                 (drpADDR),   // input wire [8:0] gt0_drpaddr_in
    .gt0_drpclk_in                  (sysClk),    // input wire gt0_drpclk_in
    .gt0_drpdi_in                   (drpDI),     // input wire [15:0] gt0_drpdi_in
    .gt0_drpdo_out                  (drpDO[4]),  // output wire [15:0] gt0_drpdo_out
    .gt0_drpen_in                   (drpEN[4]),  // input wire gt0_drpen_in
    .gt0_drprdy_out                 (drpRDY[4]), // output wire gt0_drprdy_out
    .gt0_drpwe_in                   (drpWE[4]),  // input wire gt0_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt0_dmonitorout_out            (), // output wire [7:0] gt0_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt0_eyescanreset_in            (1'b0), // input wire gt0_eyescanreset_in
    .gt0_rxuserrdy_in               (1'b1), // input wire gt0_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt0_eyescandataerror_out       (),     // output wire gt0_eyescandataerror_out
    .gt0_eyescantrigger_in          (1'b0), // input wire gt0_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt0_rxusrclk_in                (1'b0), // input wire gt0_rxusrclk_in
    .gt0_rxusrclk2_in               (1'b0), // input wire gt0_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt0_rxdata_out                 (), // output wire [15:0] gt0_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt0_rxdisperr_out              (), // output wire [1:0] gt0_rxdisperr_out
    .gt0_rxnotintable_out           (), // output wire [1:0] gt0_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt0_gtxrxp_in                  (rxP[4]), // input wire gt0_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt0_gtxrxn_in                  (rxN[4]), // input wire gt0_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt0_rxdfelpmreset_in           (1'b0),  // input wire gt0_rxdfelpmreset_in
    .gt0_rxmonitorout_out           (),      // output wire [6:0] gt0_rxmonitorout_out
    .gt0_rxmonitorsel_in            (2'b01), // input wire [1:0] gt0_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt0_rxoutclk_out               (), // output wire gt0_rxoutclk_out
    .gt0_rxoutclkfabric_out         (), // output wire gt0_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt0_gtrxreset_in               (rxreset),  // input wire gt0_gtrxreset_in
    .gt0_rxpmareset_in              (pmareset), // input wire gt0_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt0_rxcharisk_out              (), // output wire [1:0] gt0_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt0_rxresetdone_out            (mgtStatus[4][2]), // output wire gt0_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt0_gttxreset_in               (txreset), // input wire gt0_gttxreset_in
    .gt0_txuserrdy_in               (gt0_qplllock_in),    // input wire gt0_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt0_txusrclk_in                (mgtTxClk), // input wire gt0_txusrclk_in
    .gt0_txusrclk2_in               (mgtTxClk), // input wire gt0_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt0_txdata_in                  (mgtTxChars), // input wire [15:0] gt0_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt0_gtxtxn_out                 (txN[4]), // output wire gt0_gtxtxn_out
    .gt0_gtxtxp_out                 (txP[4]), // output wire gt0_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt0_txoutclk_out               (), // output wire gt0_txoutclk_out
    .gt0_txoutclkfabric_out         (), // output wire gt0_txoutclkfabric_out
    .gt0_txoutclkpcs_out            (), // output wire gt0_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt0_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt0_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt0_txresetdone_out            (mgtStatus[4][3]), // output wire gt0_txresetdone_out

    //GT1  (X0Y1)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt1_drpaddr_in                 (drpADDR),   // input wire [8:0] gt1_drpaddr_in
    .gt1_drpclk_in                  (sysClk),    // input wire gt1_drpclk_in
    .gt1_drpdi_in                   (drpDI),     // input wire [15:0] gt1_drpdi_in
    .gt1_drpdo_out                  (drpDO[5]),  // output wire [15:0] gt1_drpdo_out
    .gt1_drpen_in                   (drpEN[5]),  // input wire gt1_drpen_in
    .gt1_drprdy_out                 (drpRDY[5]), // output wire gt1_drprdy_out
    .gt1_drpwe_in                   (drpWE[5]),  // input wire gt1_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt1_dmonitorout_out            (), // output wire [7:0] gt1_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt1_eyescanreset_in            (1'b0),             // input wire gt1_eyescanreset_in
    .gt1_rxuserrdy_in               (1'b1), // input wire gt1_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt1_eyescandataerror_out       (),     // output wire gt1_eyescandataerror_out
    .gt1_eyescantrigger_in          (1'b0), // input wire gt1_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt1_rxusrclk_in                (1'b0), // input wire gt1_rxusrclk_in
    .gt1_rxusrclk2_in               (1'b0), // input wire gt1_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt1_rxdata_out                 (), // output wire [15:0] gt1_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt1_rxdisperr_out              (), // output wire [1:0] gt1_rxdisperr_out
    .gt1_rxnotintable_out           (), // output wire [1:0] gt1_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt1_gtxrxp_in                  (rxP[5]), // input wire gt1_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt1_gtxrxn_in                  (rxN[5]), // input wire gt1_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt1_rxdfelpmreset_in           (1'b0),  // input wire gt1_rxdfelpmreset_in
    .gt1_rxmonitorout_out           (),      // output wire [6:0] gt1_rxmonitorout_out
    .gt1_rxmonitorsel_in            (2'b01), // input wire [1:0] gt1_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt1_rxoutclk_out               (), // output wire gt1_rxoutclk_out
    .gt1_rxoutclkfabric_out         (), // output wire gt1_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt1_gtrxreset_in               (rxreset),  // input wire gt1_gtrxreset_in
    .gt1_rxpmareset_in              (pmareset), // input wire gt1_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt1_rxcharisk_out              (), // output wire [1:0] gt1_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt1_rxresetdone_out            (mgtStatus[5][2]), // output wire gt1_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt1_gttxreset_in               (txreset), // input wire gt1_gttxreset_in
    .gt1_txuserrdy_in               (gt0_qplllock_in),    // input wire gt1_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt1_txusrclk_in                (mgtTxClk), // input wire gt1_txusrclk_in
    .gt1_txusrclk2_in               (mgtTxClk), // input wire gt1_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt1_txdata_in                  (mgtTxChars), // input wire [15:0] gt1_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt1_gtxtxn_out                 (txN[5]), // output wire gt1_gtxtxn_out
    .gt1_gtxtxp_out                 (txP[5]), // output wire gt1_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt1_txoutclk_out               (), // output wire gt1_txoutclk_out
    .gt1_txoutclkfabric_out         (), // output wire gt1_txoutclkfabric_out
    .gt1_txoutclkpcs_out            (), // output wire gt1_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt1_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt1_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt1_txresetdone_out            (mgtStatus[5][3]), // output wire gt1_txresetdone_out

    //GT2  (X0Y2)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt2_drpaddr_in                 (drpADDR),   // input wire [8:0] gt2_drpaddr_in
    .gt2_drpclk_in                  (sysClk),    // input wire gt2_drpclk_in
    .gt2_drpdi_in                   (drpDI),     // input wire [15:0] gt2_drpdi_in
    .gt2_drpdo_out                  (drpDO[6]),  // output wire [15:0] gt2_drpdo_out
    .gt2_drpen_in                   (drpEN[6]),  // input wire gt2_drpen_in
    .gt2_drprdy_out                 (drpRDY[6]), // output wire gt2_drprdy_out
    .gt2_drpwe_in                   (drpWE[6]),  // input wire gt2_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt2_dmonitorout_out            (), // output wire [7:0] gt2_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt2_eyescanreset_in            (1'b0), // input wire gt2_eyescanreset_in
    .gt2_rxuserrdy_in               (1'b1), // input wire gt2_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt2_eyescandataerror_out       (),     // output wire gt2_eyescandataerror_out
    .gt2_eyescantrigger_in          (1'b0), // input wire gt2_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt2_rxusrclk_in                (1'b0), // input wire gt2_rxusrclk_in
    .gt2_rxusrclk2_in               (1'b0), // input wire gt2_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt2_rxdata_out                 (), // output wire [15:0] gt2_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt2_rxdisperr_out              (), // output wire [1:0] gt2_rxdisperr_out
    .gt2_rxnotintable_out           (), // output wire [1:0] gt2_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt2_gtxrxp_in                  (rxP[6]), // input wire gt2_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt2_gtxrxn_in                  (rxN[6]), // input wire gt2_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt2_rxdfelpmreset_in           (1'b0),  // input wire gt2_rxdfelpmreset_in
    .gt2_rxmonitorout_out           (),      // output wire [6:0] gt2_rxmonitorout_out
    .gt2_rxmonitorsel_in            (2'b01), // input wire [1:0] gt2_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt2_rxoutclk_out               (), // output wire gt2_rxoutclk_out
    .gt2_rxoutclkfabric_out         (), // output wire gt2_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt2_gtrxreset_in               (rxreset),  // input wire gt2_gtrxreset_in
    .gt2_rxpmareset_in              (pmareset), // input wire gt2_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt2_rxcharisk_out              (), // output wire [1:0] gt2_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt2_rxresetdone_out            (mgtStatus[6][2]), // output wire gt2_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt2_gttxreset_in               (txreset), // input wire gt2_gttxreset_in
    .gt2_txuserrdy_in               (gt0_qplllock_in),    // input wire gt2_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt2_txusrclk_in                (mgtTxClk), // input wire gt2_txusrclk_in
    .gt2_txusrclk2_in               (mgtTxClk), // input wire gt2_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt2_txdata_in                  (mgtTxChars), // input wire [15:0] gt2_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt2_gtxtxn_out                 (txN[6]), // output wire gt2_gtxtxn_out
    .gt2_gtxtxp_out                 (txP[6]), // output wire gt2_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt2_txoutclk_out               (), // output wire gt2_txoutclk_out
    .gt2_txoutclkfabric_out         (), // output wire gt2_txoutclkfabric_out
    .gt2_txoutclkpcs_out            (), // output wire gt2_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt2_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt2_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt2_txresetdone_out            (mgtStatus[6][3]), // output wire gt2_txresetdone_out

    //GT3  (X0Y3)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt3_drpaddr_in                 (drpADDR),   // input wire [8:0] gt3_drpaddr_in
    .gt3_drpclk_in                  (sysClk),    // input wire gt3_drpclk_in
    .gt3_drpdi_in                   (drpDI),     // input wire [15:0] gt3_drpdi_in
    .gt3_drpdo_out                  (drpDO[7]),  // output wire [15:0] gt3_drpdo_out
    .gt3_drpen_in                   (drpEN[7]),  // input wire gt3_drpen_in
    .gt3_drprdy_out                 (drpRDY[7]), // output wire gt3_drprdy_out
    .gt3_drpwe_in                   (drpWE[7]),  // input wire gt3_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt3_dmonitorout_out            (), // output wire [7:0] gt3_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt3_eyescanreset_in            (1'b0), // input wire gt3_eyescanreset_in
    .gt3_rxuserrdy_in               (1'b1), // input wire gt3_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt3_eyescandataerror_out       (),     // output wire gt3_eyescandataerror_out
    .gt3_eyescantrigger_in          (1'b0), // input wire gt3_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt3_rxusrclk_in                (1'b0), // input wire gt3_rxusrclk_in
    .gt3_rxusrclk2_in               (1'b0), // input wire gt3_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt3_rxdata_out                 (), // output wire [15:0] gt3_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt3_rxdisperr_out              (), // output wire [1:0] gt3_rxdisperr_out
    .gt3_rxnotintable_out           (), // output wire [1:0] gt3_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt3_gtxrxp_in                  (rxP[7]), // input wire gt3_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt3_gtxrxn_in                  (rxN[7]), // input wire gt3_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt3_rxdfelpmreset_in           (1'b0),  // input wire gt3_rxdfelpmreset_in
    .gt3_rxmonitorout_out           (),      // output wire [6:0] gt3_rxmonitorout_out
    .gt3_rxmonitorsel_in            (2'b01), // input wire [1:0] gt3_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt3_rxoutclk_out               (), // output wire gt3_rxoutclk_out
    .gt3_rxoutclkfabric_out         (), // output wire gt3_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt3_gtrxreset_in               (rxreset),  // input wire gt3_gtrxreset_in
    .gt3_rxpmareset_in              (pmareset), // input wire gt3_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt3_rxcharisk_out              (), // output wire [1:0] gt3_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt3_rxresetdone_out            (mgtStatus[7][2]), // output wire gt3_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt3_gttxreset_in               (txreset), // input wire gt3_gttxreset_in
    .gt3_txuserrdy_in               (gt0_qplllock_in),    // input wire gt3_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt3_txusrclk_in                (mgtTxClk), // input wire gt3_txusrclk_in
    .gt3_txusrclk2_in               (mgtTxClk), // input wire gt3_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt3_txdata_in                  (mgtTxChars), // input wire [15:0] gt3_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt3_gtxtxn_out                 (txN[7]), // output wire gt3_gtxtxn_out
    .gt3_gtxtxp_out                 (txP[7]), // output wire gt3_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt3_txoutclk_out               (), // output wire gt3_txoutclk_out
    .gt3_txoutclkfabric_out         (), // output wire gt3_txoutclkfabric_out
    .gt3_txoutclkpcs_out            (), // output wire gt3_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt3_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt3_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt3_txresetdone_out            (mgtStatus[7][3]), // output wire gt3_txresetdone_out

    //_________________________________________________________________________
    //GT4  (X0Y4)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt4_drpaddr_in                 (drpADDR),   // input wire [8:0] gt4_drpaddr_in
    .gt4_drpclk_in                  (sysClk),    // input wire gt4_drpclk_in
    .gt4_drpdi_in                   (drpDI),     // input wire [15:0] gt4_drpdi_in
    .gt4_drpdo_out                  (drpDO[3]),  // output wire [15:0] gt4_drpdo_out
    .gt4_drpen_in                   (drpEN[3]),  // input wire gt4_drpen_in
    .gt4_drprdy_out                 (drpRDY[3]), // output wire gt4_drprdy_out
    .gt4_drpwe_in                   (drpWE[3]),  // input wire gt4_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt4_dmonitorout_out            (), // output wire [7:0] gt4_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt4_eyescanreset_in            (1'b0), // input wire gt4_eyescanreset_in
    .gt4_rxuserrdy_in               (1'b1), // input wire gt4_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt4_eyescandataerror_out       (),     // output wire gt4_eyescandataerror_out
    .gt4_eyescantrigger_in          (1'b0), // input wire gt4_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt4_rxusrclk_in                (1'b0), // input wire gt4_rxusrclk_in
    .gt4_rxusrclk2_in               (1'b0), // input wire gt4_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt4_rxdata_out                 (), // output wire [15:0] gt4_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt4_rxdisperr_out              (), // output wire [1:0] gt4_rxdisperr_out
    .gt4_rxnotintable_out           (), // output wire [1:0] gt4_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt4_gtxrxp_in                  (rxP[3]), // input wire gt4_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt4_gtxrxn_in                  (rxN[3]), // input wire gt4_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt4_rxdfelpmreset_in           (1'b0),  // input wire gt4_rxdfelpmreset_in
    .gt4_rxmonitorout_out           (),      // output wire [6:0] gt4_rxmonitorout_out
    .gt4_rxmonitorsel_in            (2'b01), // input wire [1:0] gt4_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt4_rxoutclk_out               (), // output wire gt4_rxoutclk_out
    .gt4_rxoutclkfabric_out         (), // output wire gt4_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt4_gtrxreset_in               (rxreset),  // input wire gt4_gtrxreset_in
    .gt4_rxpmareset_in              (pmareset), // input wire gt4_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt4_rxcharisk_out              (), // output wire [1:0] gt4_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt4_rxresetdone_out            (mgtStatus[3][2]), // output wire gt4_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt4_gttxreset_in               (txreset), // input wire gt4_gttxreset_in
    .gt4_txuserrdy_in               (gt1_qplllock_in),    // input wire gt4_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt4_txusrclk_in                (mgtTxClk), // input wire gt4_txusrclk_in
    .gt4_txusrclk2_in               (mgtTxClk), // input wire gt4_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt4_txdata_in                  (mgtTxChars), // input wire [15:0] gt4_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt4_gtxtxn_out                 (txN[3]), // output wire gt4_gtxtxn_out
    .gt4_gtxtxp_out                 (txP[3]), // output wire gt4_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt4_txoutclk_out               (), // output wire gt4_txoutclk_out
    .gt4_txoutclkfabric_out         (), // output wire gt4_txoutclkfabric_out
    .gt4_txoutclkpcs_out            (), // output wire gt4_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt4_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt4_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt4_txresetdone_out            (mgtStatus[3][3]), // output wire gt4_txresetdone_out

    //GT5  (X0Y5)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt5_drpaddr_in                 (drpADDR),   // input wire [8:0] gt5_drpaddr_in
    .gt5_drpclk_in                  (sysClk),    // input wire gt5_drpclk_in
    .gt5_drpdi_in                   (drpDI),     // input wire [15:0] gt5_drpdi_in
    .gt5_drpdo_out                  (drpDO[0]),  // output wire [15:0] gt5_drpdo_out
    .gt5_drpen_in                   (drpEN[0]),  // input wire gt5_drpen_in
    .gt5_drprdy_out                 (drpRDY[0]), // output wire gt5_drprdy_out
    .gt5_drpwe_in                   (drpWE[0]),  // input wire gt5_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt5_dmonitorout_out            (), // output wire [7:0] gt5_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt5_eyescanreset_in            (1'b0), // input wire gt5_eyescanreset_in
    .gt5_rxuserrdy_in               (1'b1), // input wire gt5_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt5_eyescandataerror_out       (),     // output wire gt5_eyescandataerror_out
    .gt5_eyescantrigger_in          (1'b0), // input wire gt5_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt5_rxusrclk_in                (evrRxClk), // input wire gt5_rxusrclk_in
    .gt5_rxusrclk2_in               (evrRxClk), // input wire gt5_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt5_rxdata_out                 (evrRxData), // output wire [15:0] gt5_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt5_rxdisperr_out              (), // output wire [1:0] gt5_rxdisperr_out
    .gt5_rxnotintable_out           (evrRxNotInTable), // output wire [1:0] gt5_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt5_gtxrxp_in                  (rxP[0]), // input wire gt5_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt5_gtxrxn_in                  (rxN[0]), // input wire gt5_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt5_rxdfelpmreset_in           (1'b0),  // input wire gt5_rxdfelpmreset_in
    .gt5_rxmonitorout_out           (),      // output wire [6:0] gt5_rxmonitorout_out
    .gt5_rxmonitorsel_in            (2'b01), // input wire [1:0] gt5_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt5_rxoutclk_out               (rxoutclkEVR), // output wire gt5_rxoutclk_out
    .gt5_rxoutclkfabric_out         (),             // output wire gt5_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt5_gtrxreset_in               (rxreset),  // input wire gt5_gtrxreset_in
    .gt5_rxpmareset_in              (pmareset), // input wire gt5_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt5_rxcharisk_out              (evrRxDataIsK), // output wire [1:0] gt5_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt5_rxresetdone_out            (mgtStatus[0][2]), // output wire gt5_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt5_gttxreset_in               (txreset), // input wire gt5_gttxreset_in
    .gt5_txuserrdy_in               (gt1_qplllock_in),    // input wire gt5_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt5_txusrclk_in                (mgtTxClk), // input wire gt5_txusrclk_in
    .gt5_txusrclk2_in               (mgtTxClk), // input wire gt5_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt5_txdata_in                  (mgtTxChars), // input wire [15:0] gt5_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt5_gtxtxn_out                 (txN[0]), // output wire gt5_gtxtxn_out
    .gt5_gtxtxp_out                 (txP[0]), // output wire gt5_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt5_txoutclk_out               (txoutclk), // output wire gt5_txoutclk_out
    .gt5_txoutclkfabric_out         (),             // output wire gt5_txoutclkfabric_out
    .gt5_txoutclkpcs_out            (),             // output wire gt5_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt5_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt5_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt5_txresetdone_out            (mgtStatus[0][3]), // output wire gt5_txresetdone_out

    //GT6  (X0Y6)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt6_drpaddr_in                 (drpADDR),   // input wire [8:0] gt6_drpaddr_in
    .gt6_drpclk_in                  (sysClk),    // input wire gt6_drpclk_in
    .gt6_drpdi_in                   (drpDI),     // input wire [15:0] gt6_drpdi_in
    .gt6_drpdo_out                  (drpDO[1]),  // output wire [15:0] gt6_drpdo_out
    .gt6_drpen_in                   (drpEN[1]),  // input wire gt6_drpen_in
    .gt6_drprdy_out                 (drpRDY[1]), // output wire gt6_drprdy_out
    .gt6_drpwe_in                   (drpWE[1]),  // input wire gt6_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt6_dmonitorout_out            (), // output wire [7:0] gt6_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt6_eyescanreset_in            (1'b0), // input wire gt6_eyescanreset_in
    .gt6_rxuserrdy_in               (1'b1), // input wire gt6_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt6_eyescandataerror_out       (),     // output wire gt6_eyescandataerror_out
    .gt6_eyescantrigger_in          (1'b0), // input wire gt6_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt6_rxusrclk_in                (evfRxClk), // input wire gt6_rxusrclk_in
    .gt6_rxusrclk2_in               (evfRxClk), // input wire gt6_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt6_rxdata_out                 (evfRxData), // output wire [15:0] gt6_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt6_rxdisperr_out              (), // output wire [1:0] gt6_rxdisperr_out
    .gt6_rxnotintable_out           (evfRxNotInTable), // output wire [1:0] gt6_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt6_gtxrxp_in                  (rxP[1]), // input wire gt6_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt6_gtxrxn_in                  (rxN[1]), // input wire gt6_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt6_rxdfelpmreset_in           (1'b0),  // input wire gt6_rxdfelpmreset_in
    .gt6_rxmonitorout_out           (),      // output wire [6:0] gt6_rxmonitorout_out
    .gt6_rxmonitorsel_in            (2'b01), // input wire [1:0] gt6_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt6_rxoutclk_out               (rxoutclkEVF), // output wire gt6_rxoutclk_out
    .gt6_rxoutclkfabric_out         (), // output wire gt6_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt6_gtrxreset_in               (rxreset),  // input wire gt6_gtrxreset_in
    .gt6_rxpmareset_in              (pmareset), // input wire gt6_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt6_rxcharisk_out              (evfRxDataIsK), // output wire [1:0] gt6_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt6_rxresetdone_out            (mgtStatus[1][2]), // output wire gt6_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt6_gttxreset_in               (txreset), // input wire gt6_gttxreset_in
    .gt6_txuserrdy_in               (gt1_qplllock_in),    // input wire gt6_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt6_txusrclk_in                (mgtTxClk), // input wire gt6_txusrclk_in
    .gt6_txusrclk2_in               (mgtTxClk), // input wire gt6_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt6_txdata_in                  (mgtTxChars), // input wire [15:0] gt6_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt6_gtxtxn_out                 (txN[1]), // output wire gt6_gtxtxn_out
    .gt6_gtxtxp_out                 (txP[1]), // output wire gt6_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt6_txoutclk_out               (), // output wire gt6_txoutclk_out
    .gt6_txoutclkfabric_out         (), // output wire gt6_txoutclkfabric_out
    .gt6_txoutclkpcs_out            (), // output wire gt6_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt6_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt6_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt6_txresetdone_out            (mgtStatus[1][3]), // output wire gt6_txresetdone_out

    //GT7  (X0Y7)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt7_drpaddr_in                 (drpADDR),   // input wire [8:0] gt7_drpaddr_in
    .gt7_drpclk_in                  (sysClk),    // input wire gt7_drpclk_in
    .gt7_drpdi_in                   (drpDI),     // input wire [15:0] gt7_drpdi_in
    .gt7_drpdo_out                  (drpDO[2]),  // output wire [15:0] gt7_drpdo_out
    .gt7_drpen_in                   (drpEN[2]),  // input wire gt7_drpen_in
    .gt7_drprdy_out                 (drpRDY[2]), // output wire gt7_drprdy_out
    .gt7_drpwe_in                   (drpWE[2]),  // input wire gt7_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt7_dmonitorout_out            (), // output wire [7:0] gt7_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt7_eyescanreset_in            (1'b0), // input wire gt7_eyescanreset_in
    .gt7_rxuserrdy_in               (1'b1), // input wire gt7_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt7_eyescandataerror_out       (),     // output wire gt7_eyescandataerror_out
    .gt7_eyescantrigger_in          (1'b0), // input wire gt7_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt7_rxusrclk_in                (1'b0), // input wire gt7_rxusrclk_in
    .gt7_rxusrclk2_in               (1'b0), // input wire gt7_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt7_rxdata_out                 (), // output wire [15:0] gt7_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt7_rxdisperr_out              (), // output wire [1:0] gt7_rxdisperr_out
    .gt7_rxnotintable_out           (), // output wire [1:0] gt7_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt7_gtxrxp_in                  (rxP[2]), // input wire gt7_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt7_gtxrxn_in                  (rxN[2]), // input wire gt7_gtxrxn_in
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt7_rxdfelpmreset_in           (1'b0),  // input wire gt7_rxdfelpmreset_in
    .gt7_rxmonitorout_out           (),      // output wire [6:0] gt7_rxmonitorout_out
    .gt7_rxmonitorsel_in            (2'b01), // input wire [1:0] gt7_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt7_rxoutclk_out               (), // output wire gt7_rxoutclk_out
    .gt7_rxoutclkfabric_out         (), // output wire gt7_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt7_gtrxreset_in               (rxreset),  // input wire gt7_gtrxreset_in
    .gt7_rxpmareset_in              (pmareset), // input wire gt7_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt7_rxcharisk_out              (), // output wire [1:0] gt7_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt7_rxresetdone_out            (mgtStatus[2][2]), // output wire gt7_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt7_gttxreset_in               (txreset), // input wire gt7_gttxreset_in
    .gt7_txuserrdy_in               (gt1_qplllock_in),    // input wire gt7_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt7_txusrclk_in                (mgtTxClk), // input wire gt7_txusrclk_in
    .gt7_txusrclk2_in               (mgtTxClk), // input wire gt7_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt7_txdata_in                  (mgtTxChars), // input wire [15:0] gt7_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt7_gtxtxn_out                 (txN[2]), // output wire gt7_gtxtxn_out
    .gt7_gtxtxp_out                 (txP[2]), // output wire gt7_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt7_txoutclk_out               (), // output wire gt7_txoutclk_out
    .gt7_txoutclkfabric_out         (), // output wire gt7_txoutclkfabric_out
    .gt7_txoutclkpcs_out            (), // output wire gt7_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt7_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt7_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt7_txresetdone_out            (mgtStatus[2][3]), // output wire gt7_txresetdone_out

    //____________________________COMMON PORTS________________________________
    .gt0_qplllock_in(gt0_qplllock_in),             // input wire gt0_qplllock_in
    .gt0_qpllrefclklost_in(gt0_qpllrefclklost_in), // input wire gt0_qpllrefclklost_in
    .gt0_qpllreset_out(gt0_qpllreset_out),         // output wire gt0_qpllreset_out
    .gt0_qplloutclk_in(gt0_qplloutclk_in),         // input wire gt0_qplloutclk_in
    .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),   // input wire gt0_qplloutrefclk_in
    .gt1_qplllock_in(gt1_qplllock_in),             // input wire gt1_qplllock_in
    .gt1_qpllrefclklost_in(gt1_qpllrefclklost_in), // input wire gt1_qpllrefclklost_in
    .gt1_qpllreset_out(gt1_qpllreset_out),         // output wire gt1_qpllreset_out
    .gt1_qplloutclk_in(gt1_qplloutclk_in),         // input wire gt1_qplloutclk_in
    .gt1_qplloutrefclk_in(gt1_qplloutrefclk_in)    // input wire gt1_qplloutrefclk_in
);

endmodule

/*
 * Require a period of contiguous NULL/comma values to declare link valid.
 */
module mgtLinkStatus #(
    parameter MGT_DATA_WIDTH = -1,
    parameter MGT_BYTE_COUNT = -1
    ) (
    input  wire                       clk,
    input  wire  [MGT_DATA_WIDTH-1:0] mgtData,
    input  wire  [MGT_BYTE_COUNT-1:0] mgtDataIsK,
    input  wire  [MGT_BYTE_COUNT-1:0] mgtNotInTable,
    output reg   [MGT_DATA_WIDTH-1:0] rxChars,
    output reg   [MGT_BYTE_COUNT-1:0] rxCharIsK,
    output wire                       rxLinkUp);

localparam NULLS_REQUIRED = 8;

reg needComma = 1;
localparam NULL_COUNTER_LOAD = NULLS_REQUIRED - 1;
localparam NULL_COUNTER_WIDTH = $clog2(NULLS_REQUIRED + 1) + 1;
reg [NULL_COUNTER_WIDTH-1:0] nullsNeeded = NULL_COUNTER_LOAD;
assign rxLinkUp = nullsNeeded[NULL_COUNTER_WIDTH-1];

always @(posedge clk) begin
    rxChars <= mgtData;
    rxCharIsK <= mgtDataIsK;
    if ((mgtNotInTable != 0)
     || (mgtDataIsK[0] && (mgtData[7:0] != 8'hBC))) begin
        nullsNeeded <= NULL_COUNTER_LOAD;
        needComma <= 1;
    end
    else if (!rxLinkUp) begin
        if (mgtDataIsK[0] && (mgtData[7:0] == 8'hBC)) begin
            needComma <= 0;
        end
        else if (!needComma && !mgtDataIsK[0] && (mgtData[7:0] == 8'h00)) begin
            nullsNeeded <= nullsNeeded - 1;
        end
        else begin
            nullsNeeded <= NULL_COUNTER_LOAD;
        end
    end
end
endmodule
`default_nettype wire
