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
 * Eight transmitter lanes, one receiver lane.
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

    input  wire                 refClkP,
    input  wire                 refClkN,
input  wire                 refClkFOOP,
input  wire                 refClkFOON,
    input  wire [MGT_COUNT-1:0] rxP,
    input  wire [MGT_COUNT-1:0] rxN,
    output wire [MGT_COUNT-1:0] txP,
    output wire [MGT_COUNT-1:0] txN,

    output wire                                               mgtRxClk,
    (*MARK_DEBUG=DEBUG*) output wire     [MGT_DATA_WIDTH-1:0] mgtRxChars,
    (*MARK_DEBUG=DEBUG*) output wire [(MGT_DATA_WIDTH/8)-1:0] mgtRxIsK,
    (*MARK_DEBUG=DEBUG*) output wire                          mgtLinkUp,
    output wire                                               mgtTxClk,
    (*MARK_DEBUG=DEBUG*) input  wire     [MGT_DATA_WIDTH-1:0] mgtTxChars,
    (*MARK_DEBUG=DEBUG*) input  wire [(MGT_DATA_WIDTH/8)-1:0] mgtTxIsK);

(*MARK_DEBUG=DEBUG*)reg tog5 = 0 ; always @(posedge mgtTxClk) begin tog5 <= !tog5; end // FIXME
localparam MGT_STATUS_WIDTH = 4;
localparam MGT_SEL_WIDTH = MGT_COUNT > 1 ? $clog2(MGT_COUNT) : 1;
localparam MGT_BYTE_COUNT = MGT_DATA_WIDTH / 8;

localparam DRP_ADDR_WIDTH = 9;
localparam DRP_DATA_WIDTH = 16;
wire [MGT_SEL_WIDTH-1:0] sysMGTsel = sysGPIO_OUT[30-:MGT_SEL_WIDTH];
reg [MGT_SEL_WIDTH-1:0] mgtSel;
wire [MGT_STATUS_WIDTH-1:0] mgtStatus[0:MGT_COUNT-1];
reg  [MGT_STATUS_WIDTH-1:0] mgtStatusMux;
// Attachment points for internal logic analyzer
genvar i;
generate
for (i = 0 ; i < MGT_COUNT ; i = i + 1) begin : mgtStat
    (*MARK_DEBUG=DEBUG*) wire [MGT_STATUS_WIDTH-1:0] status = mgtStatus[i];
end
endgenerate

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
(*MARK_DEBUG=DEBUG*) wire [MGT_DATA_WIDTH-1:0] rxDataOut;
(*MARK_DEBUG=DEBUG*) wire [MGT_BYTE_COUNT-1:0] rxCharIsKOut;
(*MARK_DEBUG=DEBUG*) wire [MGT_BYTE_COUNT-1:0] rxNotInTableOut;
(*MARK_DEBUG=DEBUG*) reg [4:0] syncCount = 0;
wire linkUp = syncCount[4];
reg [MGT_DATA_WIDTH-1:0] rxChars_d;
reg [MGT_BYTE_COUNT-1:0] rxIsK;

always @(posedge mgtRxClk) begin
    rxChars_d <= rxDataOut;
    rxIsK <= rxCharIsKOut;
    if ((rxNotInTableOut != 0)
     || (rxCharIsKOut[MGT_BYTE_COUNT-1:1] != 0)
     || (rxCharIsKOut[0] && (rxDataOut[7:0] != 8'hBC))) begin
        syncCount <= 0;
    end
    else if (!linkUp && rxCharIsKOut[0]) begin
        syncCount <= syncCount + 1;
    end
end
assign mgtRxChars = rxChars_d;
assign mgtRxIsK = rxIsK;
assign mgtLinkUp = linkUp;

/*
 * Buffer the receiver and transmitter clocks
 */
wire txoutclk_out, rxoutclk_out;
BUFG txoutclk_bufg(.I(txoutclk_out), .O(mgtTxClk));
BUFG rxoutclk_bufg(.I(rxoutclk_out), .O(mgtRxClk));

/*
 * Get reference clock
 */
wire bank116MgtRefClk;
IBUFDS_GTE2 ibufds_gte2 (
    .O    (bank116MgtRefClk),
    .ODIV2(),
    .CEB  (1'b0),
    .I    (refClkP),
    .IB   (refClkN));

wire bank115MgtRefClk; IBUFDS_GTE2 ibufds115_gte2 ( .O    (bank115MgtRefClk), .ODIV2(), .CEB  (1'b0), .I    (refClkFOOP), .IB   (refClkFOON));

/*
 * Instantiate the MGT common blocks.
 * Common block code was extracted from example design.
 */
wire gt0_qplllock_in;
wire gt0_qpllrefclklost_in;
wire gt0_qpllreset_out;
wire gt0_qplloutclk_in;
wire gt0_qplloutrefclk_in;

// Bank 116, clock from bank 116 (North) RefClk0
MGT_common #(
   .WRAPPER_SIM_GTRESET_SPEEDUP("TRUE"),
   .SIM_QPLLREFCLK_SEL(3'b001))
  common0_i (
    .QPLLREFCLKSEL_IN(3'b001),
    .GTREFCLK0_IN(bank116MgtRefClk),
    .GTREFCLK1_IN(1'b0),
    .QPLLLOCK_OUT(gt0_qplllock_in),
    .QPLLLOCKDETCLK_IN(sysClk),
    .QPLLOUTCLK_OUT(gt0_qplloutclk_in),
    .QPLLOUTREFCLK_OUT(gt0_qplloutrefclk_in),
    .QPLLREFCLKLOST_OUT(gt0_qpllrefclklost_in),
    .QPLLRESET_IN(gt0_qpllreset_out));

wire gt1_qplllock_in = gt0_qplllock_in;
wire gt1_qpllreset_out= gt0_qpllreset_out;
wire gt1_qpllrefclklost_in = gt0_qpllrefclklost_in;
assign sysStatus = { busy,
                     gt1_qplllock_in, gt0_qplllock_in,
                     gt1_qpllreset_out, gt0_qpllreset_out,
                     gt1_qpllrefclklost_in, gt0_qpllrefclklost_in,
                     {32-7-MGT_STATUS_WIDTH-DRP_DATA_WIDTH{1'b0}},
                     mgtStatusMux, drpDOmux };

/*
 * Instantiate all the transceivers
 */
MGT MGT_i (
    .sysclk_in(sysClk),                  // input wire sysclk_in
    .soft_reset_tx_in(soft_reset_tx),    // input wire soft_reset_tx_in
    .soft_reset_rx_in(soft_reset_rx),    // input wire soft_reset_rx_in
    .dont_reset_on_data_error_in(1'b1),  // input wire dont_reset_on_data_error_in
    .gt0_tx_fsm_reset_done_out(mgtStatus[0][0]), // output wire gt0_tx_fsm_reset_done_out
    .gt0_rx_fsm_reset_done_out(mgtStatus[0][1]), // output wire gt0_rx_fsm_reset_done_out
    .gt0_data_valid_in(1'b1),                    // input wire gt0_data_valid_in


    //GT5  (X0Y5)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt0_drpaddr_in                 (drpADDR),   // input wire [8:0] gt0_drpaddr_in
    .gt0_drpclk_in                  (sysClk),    // input wire gt0_drpclk_in
    .gt0_drpdi_in                   (drpDI),     // input wire [15:0] gt0_drpdi_in
    .gt0_drpdo_out                  (drpDO[0]),  // output wire [15:0] gt0_drpdo_out
    .gt0_drpen_in                   (drpEN[0]),  // input wire gt0_drpen_in
    .gt0_drprdy_out                 (drpRDY[0]), // output wire gt0_drprdy_out
    .gt0_drpwe_in                   (drpWE[0]),  // input wire gt0_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt0_dmonitorout_out            (), // output wire [7:0] gt0_dmonitorout_out
    //------------------- RX Initialization and Reset Ports --------------------
    .gt0_eyescanreset_in            (1'b0), // input wire gt0_eyescanreset_in
    .gt0_rxuserrdy_in               (1'b1), // input wire gt0_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt0_eyescandataerror_out       (),     // output wire gt0_eyescandataerror_out
    .gt0_eyescantrigger_in          (1'b0), // input wire gt0_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt0_rxusrclk_in                (mgtRxClk), // input wire gt0_rxusrclk_in
    .gt0_rxusrclk2_in               (mgtRxClk), // input wire gt0_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt0_rxdata_out                 (rxDataOut), // output wire [15:0] gt0_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt0_rxdisperr_out              (), // output wire [1:0] gt0_rxdisperr_out
    .gt0_rxnotintable_out           (rxNotInTableOut), // output wire [1:0] gt0_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt0_gtxrxp_in                  (rxP[0]), // input wire gt0_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt0_gtxrxn_in                  (rxN[0]), // input wire gt0_gtxrxn_in
    //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
    .gt0_rxphmonitor_out            (), // output wire [4:0] gt0_rxphmonitor_out
    .gt0_rxphslipmonitor_out        (), // output wire [4:0] gt0_rxphslipmonitor_out
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt0_rxdfelpmreset_in           (1'b0),  // input wire gt0_rxdfelpmreset_in
    .gt0_rxmonitorout_out           (),      // output wire [6:0] gt0_rxmonitorout_out
    .gt0_rxmonitorsel_in            (2'b01), // input wire [1:0] gt0_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt0_rxoutclk_out               (rxoutclk_out), // output wire gt0_rxoutclk_out
    .gt0_rxoutclkfabric_out         (), // output wire gt0_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt0_gtrxreset_in               (rxreset),  // input wire gt0_gtrxreset_in
    .gt0_rxpmareset_in              (pmareset), // input wire gt0_rxpmareset_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt0_rxcharisk_out              (rxCharIsKOut), // output wire [1:0] gt0_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt0_rxresetdone_out            (mgtStatus[0][2]), // output wire gt0_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt0_gttxreset_in               (txreset), // input wire gt0_gttxreset_in
    .gt0_txuserrdy_in               (1'b1),    // input wire gt0_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt0_txusrclk_in                (mgtTxClk), // input wire gt0_txusrclk_in
    .gt0_txusrclk2_in               (mgtTxClk), // input wire gt0_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt0_txdata_in                  (mgtTxChars), // input wire [15:0] gt0_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt0_gtxtxn_out                 (txN[0]), // output wire gt0_gtxtxn_out
    .gt0_gtxtxp_out                 (txP[0]), // output wire gt0_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt0_txoutclk_out               (txoutclk_out), // output wire gt0_txoutclk_out
    .gt0_txoutclkfabric_out         (), // output wire gt0_txoutclkfabric_out
    .gt0_txoutclkpcs_out            (), // output wire gt0_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt0_txcharisk_in               (mgtTxIsK), // input wire [1:0] gt0_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt0_txresetdone_out            (mgtStatus[0][3]), // output wire gt0_txresetdone_out

    //____________________________COMMON PORTS________________________________
    .gt0_qplllock_in(gt0_qplllock_in),             // input wire gt0_qplllock_in
    .gt0_qpllrefclklost_in(gt0_qpllrefclklost_in), // input wire gt0_qpllrefclklost_in
    .gt0_qpllreset_out(gt0_qpllreset_out),         // output wire gt0_qpllreset_out
    .gt0_qplloutclk_in(gt0_qplloutclk_in),         // input wire gt0_qplloutclk_in
    .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in)    // input wire gt0_qplloutrefclk_in
);

endmodule
`default_nettype wire
