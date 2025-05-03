/*
 * MIT License
 *
 * Copyright (c) 2025 Osprey DCS
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
 * Instantiate all multi-gigabit transceivers and the code associated with them.
 * MGT streams:
 *      evrXXXX   -- Event receiver in
 *      evfXXXX   -- Event fanout in
 *      evsXXXX   -- Event source (generator or fanout) out
 *      mpsXXXX   -- Machine protection out (EVR MGT)
 *      mpfXXXX   -- Merged Machine protection out (EVF MGT)
 *
 * Fibers:
 *  1 (QSFP1-1), All nodes
 *          Event stream in, local MPS status out.
 *          For leaf notes this is the only fiber.
 *
 *  2 (QSFP1-2), Event generator node
 *          Merged MPS status from event fanout in, event stream out.
 *  2 (QSFP1-2), Event fanout nodes
 *          Event stream from generator in, event stream out.
 *
 *  3-8 (QSFP1-3:4, QSFP2-1:4), Event generator and event fanout nodes
 *          MPS status in, event stream out.
 */
`default_nettype none
module fiberLinks #(
    parameter MGT_COUNT          = 1,
    parameter MGT_DATA_WIDTH     = 16,
    parameter MGT_BYTE_COUNT     = (MGT_DATA_WIDTH + 7) / 8,
    parameter MPS_OUTPUT_COUNT   = 8,
    parameter TIMESTAMP_WIDTH    = 64,
    parameter EVR_ACQ_START_CODE = 1,
    parameter EVR_ACQ_STOP_CODE  = 1,
    parameter EVR_MPS_CLEAR_CODE = 1,
    parameter SYS_CLK_RATE       = 100000000,
    parameter EVG_CLK_RATE       = 125000000,
    parameter DEBUG_MGT          = "false",
    parameter DEBUG_EVR          = "false",
    parameter DEBUG_EVF          = "false",
    parameter DEBUG_EVG          = "false",
    parameter DEBUG_MPS          = "false",
    parameter DEBUG              = "false"
    ) (
                         input  wire                       sysClk,
    (*MARK_DEBUG=DEBUG*) input  wire                       sysMgtCsrStrobe,
    (*MARK_DEBUG=DEBUG*) input  wire                [31:0] sysGPIO_OUT,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysMgtStatus,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysLinkStatus,
    (*MARK_DEBUG=DEBUG*) output reg  [TIMESTAMP_WIDTH-1:0] sysTimestamp,
                         input  wire                       isEVG,

                         input  wire                       sysMPSmergeStrobe,
                         output wire                [31:0] sysMPSmergeStatus,

                         output wire                       evrRxClk,
    (*MARK_DEBUG=DEBUG*) output wire                       evrPPSmarker,
                         output wire                       evrRxStartACQstrobe,
                         output wire                       evrRxStopACQstrobe,
                         output wire                       evrRxClearMPSstrobe,
                         output wire                       evfRxClk,

                         output wire                         mgtTxClk,
                         input  wire    [MGT_DATA_WIDTH-1:0] evgTxChars,
                         input  wire    [MGT_BYTE_COUNT-1:0] evgTxCharIsK,
                         input  wire    [MGT_DATA_WIDTH-1:0] mpsTxChars,
                         input  wire                         mpsTxCharIsK,
                         output wire [MPS_OUTPUT_COUNT-1:0 ] mpsTrippedOutputs,

                         input  wire                       acqClk,
    (*MARK_DEBUG=DEBUG*) output reg  [TIMESTAMP_WIDTH-1:0] acqTimestamp,
    (*MARK_DEBUG=DEBUG*) output reg                        acqPPSstrobe,

    input  wire                 gtRefClkP,
    input  wire                 gtRefClkN,
    input  wire [MGT_COUNT-1:0] rxP,
    input  wire [MGT_COUNT-1:0] rxN,
    output wire [MGT_COUNT-1:0] txP,
    output wire [MGT_COUNT-1:0] txN);

///////////////////////////////////////////////////////////////////////////////
// Forward reference to MGT receivers
wire [63:0] evrRxTimestamp;
wire                                       [MGT_COUNT-1:0] mgtRxClks;
(*MARK_DEBUG=DEBUG*) wire [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars;
(*MARK_DEBUG=DEBUG*) wire                  [MGT_COUNT-1:0] mgtRxCharIsK;
(*MARK_DEBUG=DEBUG*) wire                  [MGT_COUNT-1:0] mgtRxLinkUp;

assign                    evrRxClk = mgtRxClks[0];
wire                      evrRxLinkUp = mgtRxLinkUp[0];
wire                      evrRxCharIsK = mgtRxCharIsK[0];
wire [MGT_DATA_WIDTH-1:0] evrRxChars =
                                   mgtRxChars[0*MGT_DATA_WIDTH+:MGT_DATA_WIDTH];
wire                      evrTimestampValid;

assign                    evfRxClk = mgtRxClks[1];
wire                      evfRxLinkUp = mgtRxLinkUp[1];
wire                      evfRxCharIsK = mgtRxCharIsK[1];
wire [MGT_DATA_WIDTH-1:0] evfRxChars =
                                   mgtRxChars[1*MGT_DATA_WIDTH+:MGT_DATA_WIDTH];

// Lots of different clock domains, but races unimportant
assign sysLinkStatus = { evrTimestampValid,
                         {32-1-MGT_COUNT{1'b0}},
                         mgtRxLinkUp};

///////////////////////////////////////////////////////////////////////////////
// Instantiate the tiny event receiver
wire [TIMESTAMP_WIDTH-1:0] evrTimestamp;
wire                       evrPPSstrobe;
wire               [126:1] evrStrobes;
tinyEVR #(
    .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
    .DEBUG(DEBUG_EVR))
  tinyEVR_i (
    .evrRxClk(evrRxClk),
    .evrRxWord(evrRxChars & {MGT_DATA_WIDTH{evrRxLinkUp}}),
    .evrCharIsK({evrRxCharIsK, 1'b0}),
    .ppsMarker(evrPPSstrobe),
    .timestampValid(evrTimestampValid),
    .timestamp(evrTimestamp),
    .distributedDataBus(),
    .evStrobe(evrStrobes));
assign evrRxStartACQstrobe = evrStrobes[EVR_ACQ_START_CODE];
assign evrRxStopACQstrobe  = evrStrobes[EVR_ACQ_STOP_CODE];
assign evrRxClearMPSstrobe = evrStrobes[EVR_MPS_CLEAR_CODE];

// Stretch PPS strobe to marker sure to be seen in other clock domains
localparam PPS_STRETCH_COUNTER_WIDTH = 5;
(*MARK_DEBUG=DEBUG_EVR*) reg [PPS_STRETCH_COUNTER_WIDTH-1:0]
                                                       evrPPSstretchCounter = 0;
assign evrPPSmarker = evrPPSstretchCounter[PPS_STRETCH_COUNTER_WIDTH-1];
always @(posedge evrRxClk) begin
    if (evrPPSstrobe) begin
        evrPPSstretchCounter <= {PPS_STRETCH_COUNTER_WIDTH{1'b1}};
    end
    else if (evrPPSmarker) begin
        evrPPSstretchCounter <= evrPPSstretchCounter - 1;
    end
end

// Get received values into appropriate clock domains
(*ASYNC_REG="true"*) reg sysPPSmarker_m = 0, acqPPSmarker_m = 0;
reg sysPPSmarker = 0, sysPPSmarker_d = 0;
reg acqPPSmarker = 0, acqPPSmarker_d = 0;
always @(posedge sysClk) begin
    sysPPSmarker_m <= evrPPSmarker;
    sysPPSmarker   <= sysPPSmarker_m;
    sysPPSmarker_d <= sysPPSmarker;
    if (sysPPSmarker && !sysPPSmarker_d) begin
        sysTimestamp[32+:32] <= evrTimestamp[32+:32];
        sysTimestamp[0+:32] <= 0;
    end
    else begin
        sysTimestamp[0+:32] <= sysTimestamp[0+:32] + 1;
    end
end
always @(posedge acqClk) begin
    acqPPSmarker_m <= evrPPSmarker;
    acqPPSmarker   <= acqPPSmarker_m;
    acqPPSmarker_d <= acqPPSmarker;
    if (acqPPSmarker && !acqPPSmarker_d) begin
        /* evrTimestamp seconds known to be stable */
        acqTimestamp[32+:32] <= evrTimestamp[32+:32];
        acqTimestamp[0+:32] <= 0;
        acqPPSstrobe <= 1;
    end
    else begin
        acqTimestamp[0+:32] <= acqTimestamp[0+:32] + 1;
        acqPPSstrobe <= 0;
    end
end

///////////////////////////////////////////////////////////////////////////////
// Select event source
(*ASYNC_REG="true"*) reg mgtIsEVG_m;
reg mgtIsEVG;
wire [MGT_DATA_WIDTH-1:0] mpfTxChars;
wire                      mpfTxCharIsK;
wire [MGT_DATA_WIDTH-1:0] evfTxChars;
wire                      evfTxCharIsK;
wire [MGT_DATA_WIDTH-1:0] evsTxChars;
wire [MGT_BYTE_COUNT-1:0] evsTxCharIsK;
always @(posedge mgtTxClk) begin
    mgtIsEVG_m <= isEVG;
    mgtIsEVG   <= mgtIsEVG_m;
end
assign evsTxChars =   mgtIsEVG ? evgTxChars   : evfTxChars;
assign evsTxCharIsK = mgtIsEVG ? evgTxCharIsK : {evfTxCharIsK, 1'b0};
assign mpsTrippedOutputs = isEVG ? mpfTxChars[0+:MPS_OUTPUT_COUNT]
                                 : mpsTxChars[0+:MPS_OUTPUT_COUNT];

///////////////////////////////////////////////////////////////////////////////
// Instantiate the multi gigabit transceivers
mgtWrapper #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .DEBUG(DEBUG_MGT))
  mgtWrapper_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysMgtCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysMgtStatus),
    .gtRefClkP(gtRefClkP),
    .gtRefClkN(gtRefClkN),
    .gtRefClkDiv2(),
    .rxP(rxP),
    .rxN(rxN),
    .txP(txP),
    .txN(txN),
    .mgtRxClks(mgtRxClks),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtRxChars(mgtRxChars),
    .mgtRxCharIsK(mgtRxCharIsK),
    .mgtTxClk(mgtTxClk),
    .mgtIsEVG(mgtIsEVG),
    .mpsTxChars(mpsTxChars),
    .mpsTxCharIsK(mpsTxCharIsK),
    .mpfTxChars(mpfTxChars),
    .mpfTxCharIsK(mpfTxCharIsK),
    .evsTxChars(evsTxChars),
    .evsTxCharIsK(evsTxCharIsK));

///////////////////////////////////////////////////////////////////////////////
// Measure clocks
wire [29:0] measuredFrequency;
wire measuredUsingInteralAcqMarker;
reg [2:0] frequencyChannelSelect = 0;
///////////////////////////////////////////////////////////////////////////////
// Minimal event fanout
wire pad;
evf #(.DEBUG(DEBUG_EVF))
  evf_i (
    .rxClk(evfRxClk),
    .rxLinkUp(evfRxLinkUp && !isEVG),
    .rxChars(evfRxChars),
    .rxCharIsK({evfRxCharIsK, 1'b0}),
    .txClk(mgtTxClk),
    .txChars(evfTxChars),
    .txCharIsK({evfTxCharIsK, pad}));

///////////////////////////////////////////////////////////////////////////////
// Merge MPS uplinks
mpsMerge #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MPS_OUTPUT_COUNT(MPS_OUTPUT_COUNT),
    .DEBUG(DEBUG_MPS))
  mpsMerge_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysMPSmergeStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysMPSmergeStatus),
    .sysIsEVG(isEVG),
    .mgtRxChars(mgtRxChars),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtTxClk(mgtTxClk),
    .mpfTxChars(mpfTxChars),
    .mpfTxCharIsK(mpfTxCharIsK));

endmodule
`default_nettype wire
