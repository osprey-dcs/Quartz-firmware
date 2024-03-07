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
 * Wrap tiny event receiver and multi-gigabit transceiver
 * FIXME: The event forwarding is good only for distributing time stamps
 *        and acquisition alignment to just a little better than 100 ns.
 */
`default_nettype none
module eventSystem #(
    parameter CFG_EVG_CLK_RATE   = 1,
    parameter MGT_COUNT          = 1,
    parameter EVG_CLK_RATE       = 1,
    parameter TIMESTAMP_WIDTH    = 64,
    parameter EVR_ACQ_START_CODE = 1,
    parameter EVR_ACQ_STOP_CODE  = 1,
    parameter DEBUG_MGT          = "false",
    parameter DEBUG_EVR          = "false",
    parameter DEBUG_EVF          = "false",
    parameter DEBUG_EVG          = "false",
    parameter DEBUG              = "false"
    ) (
                         input  wire                       sysClk,
    (*MARK_DEBUG=DEBUG*) input  wire                       sysCsrStrobe,
    (*MARK_DEBUG=DEBUG*) input  wire                [31:0] sysGPIO_OUT,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysStatus,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysLinkStatus,
    (*MARK_DEBUG=DEBUG*) output reg  [TIMESTAMP_WIDTH-1:0] sysTimestamp,

                         output wire                       evrRxClk,
    (*MARK_DEBUG=DEBUG_EVR*)output wire                    evrRxStartACQstrobe,
    (*MARK_DEBUG=DEBUG_EVR*)output wire                    evrRxStopACQstrobe,
                         output wire                       evfRxClk,
    (*MARK_DEBUG=DEBUG*) input  wire                       sysEVGsetTimeStrobe,
    (*MARK_DEBUG=DEBUG*) output wire                [31:0] sysEVGstatus,

    (*MARK_DEBUG=DEBUG*) input  wire                       hwPPSmarker_a,
    (*MARK_DEBUG=DEBUG*) output wire                       evrPPSmarker,
                         output reg                        isEVG = 0,

                         output wire                       mgtTxClk,
                         input  wire                 [7:0] evgTxCode,
                         input  wire                       evgTxCodeValid,

                         input  wire                       acqClk,
    (*MARK_DEBUG=DEBUG*) output reg  [TIMESTAMP_WIDTH-1:0] acqTimestamp,
    (*MARK_DEBUG=DEBUG*) output reg                        acqPPSstrobe,

    input  wire                 gtRefClk,
    input  wire [MGT_COUNT-1:0] rxP,
    input  wire [MGT_COUNT-1:0] rxN,
    output wire [MGT_COUNT-1:0] txP,
    output wire [MGT_COUNT-1:0] txN);

localparam MGT_DATA_WIDTH = 16;
localparam MGT_BYTE_COUNT = (MGT_DATA_WIDTH + 7) / 8;

wire [MGT_DATA_WIDTH-1:0] txChars;
wire [MGT_BYTE_COUNT-1:0] txCharIsK;
wire [MGT_DATA_WIDTH-1:0] evrRxChars, evfRxChars;
wire [MGT_BYTE_COUNT-1:0] evrRxCharIsK, evfRxCharIsK;

wire evrRxPPSmarker = 0;
wire [63:0] evrRxTimestamp;
wire evrRxLinkUp, evfRxLinkUp;
wire evrTimestampValid;
assign sysLinkStatus = { evrTimestampValid, {29{1'b0}}, evfRxLinkUp, evrRxLinkUp};

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
    .evrCharIsK(evrRxCharIsK),
    .ppsMarker(evrPPSstrobe),
    .timestampValid(evrTimestampValid),
    .timestamp(evrTimestamp),
    .distributedDataBus(),
    .evStrobe(evrStrobes));
assign evrRxStartACQstrobe = evrStrobes[EVR_ACQ_START_CODE];
assign evrRxStopACQstrobe  = evrStrobes[EVR_ACQ_STOP_CODE];

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
// Instantiate the multi gigabit transceiver
mgtWrapper #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(16),
    .DEBUG(DEBUG_MGT))
  mgtWrapper_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .gtRefClk(gtRefClk),
    .rxP(rxP),
    .rxN(rxN),
    .txP(txP),
    .txN(txN),
    .evrRxClk(evrRxClk),
    .evrRxLinkUp(evrRxLinkUp),
    .evrRxChars(evrRxChars),
    .evrRxCharIsK(evrRxCharIsK),
    .evfRxClk(evfRxClk),
    .evfRxLinkUp(evfRxLinkUp),
    .evfRxChars(evfRxChars),
    .evfRxCharIsK(evfRxCharIsK),
    .mgtTxClk(mgtTxClk),
    .mgtTxChars(txChars),
    .mgtTxIsK(txCharIsK));

///////////////////////////////////////////////////////////////////////////////
// Minimal event generator
// Heartbeat and PPS events only.
localparam EVG_PPS_TOOSLOW_RELOAD = ((EVG_CLK_RATE / 100) * 101) - 2;
localparam EVG_PPS_TOOFAST_RELOAD = ((EVG_CLK_RATE / 100) * 99) - 2;
localparam EVG_PPS_COUNTER_WIDTH = $clog2(EVG_PPS_TOOSLOW_RELOAD+1) + 1;
(*MARK_DEBUG=DEBUG_EVG*)
reg [EVG_PPS_COUNTER_WIDTH-1:0] ppsTooSlowCounter = EVG_PPS_TOOSLOW_RELOAD;
wire ppsTooSlow = ppsTooSlowCounter[EVG_PPS_COUNTER_WIDTH-1];
(*MARK_DEBUG=DEBUG_EVG*)
reg [EVG_PPS_COUNTER_WIDTH-1:0] ppsTooFastCounter = EVG_PPS_TOOFAST_RELOAD;
wire ppsTooFast = !ppsTooFastCounter[EVG_PPS_COUNTER_WIDTH-1];
(*MARK_DEBUG=DEBUG_EVG*) reg ppsValid = 0, secondsValid = 0;

reg sysEVG_PPStoggle = 0;
assign sysEVGstatus = {sysEVG_PPStoggle, {28{1'b0}},
                       isEVG, secondsValid, ppsValid};
localparam HEARTBEAT_INTERVAL= 124800000;
localparam HEARTBEAT_RELOAD = HEARTBEAT_INTERVAL - 2;
localparam HEARTBEAT_COUNTER_WIDTH = $clog2(HEARTBEAT_RELOAD+1)+1;
reg [HEARTBEAT_COUNTER_WIDTH-1:0] heartbeatCounter = HEARTBEAT_RELOAD;
wire heartbeatCounterDone = heartbeatCounter[HEARTBEAT_COUNTER_WIDTH-1];
reg sysSecondsToggle = 0;
reg [31:0] sysSeconds;
(*ASYNC_REG="true"*) reg evgSecondsToggle_m = 0;
reg evgSecondsToggle = 0, evgSecondsToggle_d = 0;
(*ASYNC_REG="true"*) reg evgPPSmarker_m = 0;
reg evgPPSmarker = 0, evgPPSmarker_d = 0;
always @(posedge sysClk) begin
    if (sysEVGsetTimeStrobe) begin
        isEVG <= 1;
        if (sysGPIO_OUT != 0) begin
            sysSeconds <= sysGPIO_OUT;
            sysSecondsToggle <= !sysSecondsToggle;
        end
    end
end
always @(posedge mgtTxClk) begin
    if (heartbeatCounterDone) begin
        heartbeatCounter <= HEARTBEAT_RELOAD;
    end
    else begin
        heartbeatCounter <= heartbeatCounter - 1;
    end
    evgSecondsToggle_m <= sysSecondsToggle;
    evgSecondsToggle   <= evgSecondsToggle_m;
    evgSecondsToggle_d <= evgSecondsToggle;
    if (ppsValid) begin
        if (evgSecondsToggle != evgSecondsToggle_d) begin
            secondsValid <= 1;
        end
    end
    else begin
        secondsValid <= 0;
    end
    evgPPSmarker_m <= hwPPSmarker_a;
    evgPPSmarker   <= evgPPSmarker_m;
    evgPPSmarker_d <= evgPPSmarker;
    if (evgPPSmarker && !evgPPSmarker_d) begin
        sysEVG_PPStoggle <= !sysEVG_PPStoggle;
        if (!ppsTooFast && !ppsTooSlow) begin
            ppsValid <= 1;
        end
        else begin
            ppsValid <= 0;
        end
        ppsTooSlowCounter <= EVG_PPS_TOOSLOW_RELOAD;
        ppsTooFastCounter <= EVG_PPS_TOOFAST_RELOAD;
    end
    else begin
        if (ppsTooFast) begin
            ppsTooFastCounter <= ppsTooFastCounter - 1;
        end
        if (ppsTooSlow) begin
            ppsValid <= 0;
        end
        else begin
            ppsTooSlowCounter <= ppsTooSlowCounter - 1;
        end
    end
end
wire [MGT_DATA_WIDTH-1:0] evgTxChars;
wire [MGT_BYTE_COUNT-1:0] evgTxCharIsK;
tinyEVG #(.DEBUG(DEBUG_EVG))
  tinyEVG (
    .evgTxClk(mgtTxClk),
    .evgTxWord(evgTxChars),
    .evgTxIsK(evgTxCharIsK),
    .eventCode(evgTxCode),
    .eventStrobe(evgTxCodeValid),
    .heartbeatRequest(heartbeatCounterDone),
    .ppsStrobe(evgPPSmarker && !evgPPSmarker_d),
    .secondsStrobe(evgSecondsToggle != evgSecondsToggle_d),
    .seconds(sysSeconds),
    .distributedBus(8'h00),
    .sysClk(sysClk),
    .sysSendStrobe(1'b0),
    .sysWriteStrobe(1'b0),
    .sysWriteAddress(11'h000),
    .sysWriteData(8'h00),
    .sysBufferBusy());

///////////////////////////////////////////////////////////////////////////////
// Minimal event fanout
wire [MGT_DATA_WIDTH-1:0] evfTxChars;
wire [MGT_BYTE_COUNT-1:0] evfTxCharIsK;
evf #(.DEBUG(DEBUG_EVF))
  evf_i (
    .rxClk(evfRxClk),
    .rxLinkUp(evfRxLinkUp && !isEVG),
    .rxChars(evfRxChars),
    .rxCharIsK(evfRxCharIsK),
    .txClk(mgtTxClk),
    .txChars(evfTxChars),
    .txCharIsK(evfTxCharIsK));

///////////////////////////////////////////////////////////////////////////////
// Select event source
(*ASYNC_REG="true"*) reg txIsEVG_m;
reg txIsEVG;
always @(posedge mgtTxClk) begin
    txIsEVG_m <= isEVG;
    txIsEVG   <= txIsEVG_m;
end
assign txChars = txIsEVG ? evgTxChars : evfTxChars;
assign txCharIsK = txIsEVG ? evgTxCharIsK : evfTxCharIsK;

endmodule
`default_nettype wire
