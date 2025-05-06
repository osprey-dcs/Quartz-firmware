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
 * Wrapper around tinyEVG event generator
 *
 * From Axi-Lite example without additional cycle of read latency
 *        WREADY is the write strobe.
 *        (RVALID && RREADY) is the read strobe.
 *
 * Based on the excellent tutorials by Dan Gisselquist.
 *                              https://zipcpu.com/blog/2020/03/08/easyaxil.html
 *
 * Nets with names beginning with 's_' or 'sys'
 * are in the system (AXI) clock domain.
 */

`default_nettype none

module ospreyEVG_v1_0 #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter EVGCLK_FREQUENCY   = 125000000,
    parameter TIMER_COUNT        = 2,
    parameter HW_TRIGGER_COUNT   = 4,
    parameter SEQRAM_ADDR_WIDTH  = 12,
    parameter DEBUG              = "false",
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_ADDR_WIDTH = 7,
    parameter C_S_AXI_DATA_WIDTH = 32
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    input  wire                          evgClk,
    input  wire                          ppsMarker_a,
    input  wire   [HW_TRIGGER_COUNT-1:0] hwTriggers_a,
    input  wire                    [7:0] distributedBus,
    output wire                   [15:0] evgTxChars,
    output wire                    [1:0] evgTxCharIsK,

    ////////////////////// AXI-Lite Boilerplate Ports ///////////////////
    input  wire                          s_axi_aclk,
    input  wire                          s_axi_aresetn,

    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready = 1,
    input  wire                    [2:0] s_axi_arprot,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg                           s_axi_rvalid = 0,
    input  wire                          s_axi_rready,
    output wire                    [1:0] s_axi_rresp,

    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
    input  wire                    [2:0] s_axi_awprot,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready = 0,
    input  wire                    [3:0] s_axi_wstrb,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    output reg                           s_axi_bvalid = 0,
    input  wire                          s_axi_bready,
    output wire                    [1:0] s_axi_bresp);

/*
 * Static outputs -- success always
 */
assign s_axi_rresp = 2'b00;
assign s_axi_bresp = 2'b00;

/*
 * Read side
 */
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1;
        s_axi_rvalid <= 0;
    end
    else if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid <= 1;
        s_axi_arready <= 0;
    end
    else if (s_axi_rready) begin
        s_axi_rvalid <= 0;
        s_axi_arready <= 1;
    end
end

/*
 * Write side
 */
assign s_axi_awready = s_axi_wready;
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_wready <= 0;
    end
    else begin
        s_axi_wready <= !s_axi_wready && s_axi_awvalid && s_axi_wvalid &&
                                                (!s_axi_bvalid || s_axi_bready);
    end
    if (!s_axi_aresetn) begin
        s_axi_bvalid <= 0;
    end
    else if (s_axi_wready) begin
        s_axi_bvalid <= 1;
    end
    else if (s_axi_bready) begin
        s_axi_bvalid <= 0;
    end

end
//////////////////////// End of AXI-Lite Boilerplate ////////////////////////

//////////////////////////////////////////////////////////////////////////////

/*
 * One for table-driven event (highest-priority), one for each
 * timer-driven event, two for each hardware trigger (rising/falling),
 * one for software-driven event (lowest-priority).
 */
localparam EVCHAIN_LENGTH = 1 + TIMER_COUNT + (2 * HW_TRIGGER_COUNT) + 1;
genvar i, j;

//
// AXI component (system clock domain)
//

// Parse addresses
localparam REGSEL_WIDTH = 5;
wire [REGSEL_WIDTH-1:0] s_wRegIndex = s_axi_awaddr[2+:REGSEL_WIDTH];
wire [REGSEL_WIDTH-1:0] s_rRegIndex = s_axi_araddr[2+:REGSEL_WIDTH];
localparam REG_IDX_CSR               = 5'd0;
localparam REG_IDX_CLK_RATE          = 5'd1;
localparam REG_IDX_SECONDS           = 5'd2;
localparam REG_IDX_HEARTBEAT_DIVISOR = 5'd3;
localparam REG_IDX_HW_TRIGGER_CONFIG = 5'd4;
localparam REG_IDX_SW_TRIGGER        = 5'd5;
localparam REG_IDX_SEQUENCER         = 5'd6;
localparam REG_IDX_TIMER_CONFIG_BASE = 5'd16;

/*
 * Clock-crossing support
 */
reg sysSetSecondsToggle = 0;
reg [31:0] sysPosixSeconds;

reg sysSetHeartbeatDivisorToggle = 0;

if ((TIMER_COUNT < 2) || (TIMER_COUNT > 8)) begin
    Invalid_TIMER_COUNT();
end
reg [TIMER_COUNT-1:0] sysTimerConfigToggle = 0, sysTimerReloadToggle = 0;
localparam TIMERSEL_WIDTH = $clog2(TIMER_COUNT);
wire timerReloadSel = s_axi_awaddr[2];
wire [TIMERSEL_WIDTH-1:0] timerSel = s_axi_awaddr[3+:TIMERSEL_WIDTH];

reg [(2*HW_TRIGGER_COUNT)-1:0] sysHwUpdateToggle = 0;
localparam HWSEL_WIDTH = $clog2(2*HW_TRIGGER_COUNT);
wire [HWSEL_WIDTH-1:0] hwSel = s_axi_wdata[8+:HWSEL_WIDTH];

reg sysSwTriggerToggle = 0;

reg [31:0] sysWriteData;
reg [31:0] sysReadData;
assign s_axi_rdata = sysReadData;

/*
 * Forward references to some EVG clock values.
 * No need for fancy clock-crossing logic since the
 * processor knows that races are possible.
 */
(*MARK_DEBUG=DEBUG*) reg evgPPSvalid = 0;
(*MARK_DEBUG=DEBUG*) reg evgSecondsValid = 0;
(*MARK_DEBUG=DEBUG*) reg evgPPStoggle = 0;
(*MARK_DEBUG=DEBUG*) reg [31:0] evgPosixSeconds = 0;
(*MARK_DEBUG=DEBUG*) reg [31:0] evgClkStatus;
wire [31:0] sequencerStatus;

// Status registers
wire [3:0] timerCount   = TIMER_COUNT;
wire [3:0] triggerCount = HW_TRIGGER_COUNT;
wire [31:0] sysStatus = { {32-1-4-4-4-8{1'b0}},
                          evgPPStoggle,
                          sequencerStatus[3:0],
                          timerCount,
                          triggerCount,
                          {6{1'b0}}, evgSecondsValid, evgPPSvalid };

always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
    end
    else begin
        /*
         * Control (write) operations
         */
        if (s_axi_wready) begin
        sysWriteData <= s_axi_wdata;
        if (s_wRegIndex & REG_IDX_TIMER_CONFIG_BASE) begin
            if (timerReloadSel) begin
               sysTimerReloadToggle[timerSel]<=!sysTimerReloadToggle[timerSel];
            end
            else begin
               sysTimerConfigToggle[timerSel]<=!sysTimerConfigToggle[timerSel];
            end
        end
        else case (s_wRegIndex)
        REG_IDX_SECONDS: begin
            sysPosixSeconds <= s_axi_wdata;
            sysSetSecondsToggle <= !sysSetSecondsToggle;
        end
        REG_IDX_HEARTBEAT_DIVISOR: begin
            sysSetHeartbeatDivisorToggle <= !sysSetHeartbeatDivisorToggle;
        end
        REG_IDX_HW_TRIGGER_CONFIG: begin
            sysHwUpdateToggle[hwSel] <= !sysHwUpdateToggle[hwSel];
        end
        REG_IDX_SW_TRIGGER: begin
            sysSwTriggerToggle <= !sysSwTriggerToggle;
        end
        default: ;
        endcase
        end

        /*
         * Readback operations
         */
        case (s_rRegIndex)
        REG_IDX_CSR:       sysReadData <= sysStatus;
        REG_IDX_CLK_RATE:  sysReadData <= evgClkStatus;
        REG_IDX_SECONDS:   sysReadData <= evgPosixSeconds;
        default:           sysReadData <= 0;
        endcase
    end
end
//////////////////////////////////////////////////////////////////////////////
//
// Event generator (MGT transmitter) clock domain
//

/*
 * PPS handling
 */
(*ASYNC_REG="true"*) reg evgPPSmarker_m = 0;
(*MARK_DEBUG=DEBUG*) reg evgPPSmarker = 0, evgPPSmarker_d = 0;
wire evgPPSrising = (evgPPSmarker && !evgPPSmarker_d);

// Validate PPS
localparam PPS_TOO_FAST_RELOAD = ((EVGCLK_FREQUENCY / 100) * 99) - 1;
localparam PPS_TOO_SLOW_RELOAD = ((EVGCLK_FREQUENCY / 100) * 101) - 1;
localparam PPS_TOO_FAST_WIDTH = $clog2(PPS_TOO_FAST_RELOAD+1) + 1;
localparam PPS_TOO_SLOW_WIDTH = $clog2(PPS_TOO_FAST_RELOAD+1) + 1;
(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_FAST_WIDTH-1:0] evgPPStooFastCounter =
                                                            PPS_TOO_FAST_RELOAD;
wire evgPPStooFast = !evgPPStooFastCounter[PPS_TOO_FAST_WIDTH-1];
(*MARK_DEBUG=DEBUG*) reg [PPS_TOO_SLOW_WIDTH-1:0] evgPPStooSlowCounter =
                                                            PPS_TOO_SLOW_RELOAD;
wire evgPPStooSlow = evgPPStooSlowCounter[PPS_TOO_SLOW_WIDTH-1];
reg [PPS_TOO_SLOW_WIDTH-1:0] evgClkRateCounter = 0;

always @(posedge evgClk) begin
    evgPPSmarker_m <= ppsMarker_a;
    evgPPSmarker   <= evgPPSmarker_m;
    evgPPSmarker_d <= evgPPSmarker;
    if (evgPPSrising) begin
        evgPPStoggle <= !evgPPStoggle;
        evgPPStooFastCounter <= PPS_TOO_FAST_RELOAD;
        evgPPStooSlowCounter <= PPS_TOO_SLOW_RELOAD;
        evgClkRateCounter <= 1;
        if (evgPPStooFast || evgPPStooSlow) begin
            evgPPSvalid <= 0;
        end
        else begin
            evgPPSvalid <= 1;
            evgClkStatus <= {!evgClkStatus[31],
                             {32-1-PPS_TOO_SLOW_WIDTH{1'b0}},
                             evgClkRateCounter};
        end
    end
    else begin
        evgClkRateCounter <= evgClkRateCounter + 1;
        if (evgPPStooFast) begin
            evgPPStooFastCounter <= evgPPStooFastCounter - 1;
        end
        if (evgPPStooSlow) begin
            evgPPSvalid <= 0;
        end
        else begin
            evgPPStooSlowCounter <= evgPPStooSlowCounter - 1;
        end
    end
end

/*
 * Time-of-day updates in evgClk domain
 */
(*ASYNC_REG="true"*) reg evgSetSecondsToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg evgSetSecondsToggle = 0, evgSetSecondsToggle_d = 0;
always @(posedge evgClk) begin
    evgSetSecondsToggle_m <= sysSetSecondsToggle;
    evgSetSecondsToggle   <= evgSetSecondsToggle_m;
    evgSetSecondsToggle_d <= evgSetSecondsToggle;
    if (evgPPSvalid) begin
        if (evgSetSecondsToggle != evgSetSecondsToggle_d) begin
            evgSecondsValid <= 1;
        end
    end
    else begin
        evgSecondsValid <= 0;
    end
end

/*
 * Heartbeat generation
 */
(*ASYNC_REG="true"*) reg evgSetHeartbeatDivisorToggle_m = 0;
reg evgSetHeartbeatDivisorToggle = 0, evgSetHeartbeatDivisorToggle_d = 0;
reg evgHeartbeatEnable;
reg [31:0] evgHeartbeatLoad = 0;
reg [32:0] evgHeartbeatCounter = 0;
(*MARK_DEBUG=DEBUG*) wire evgHeartbeatRequest = evgHeartbeatCounter[32];
always @(posedge evgClk) begin
    evgSetHeartbeatDivisorToggle_m <= sysSetHeartbeatDivisorToggle;
    evgSetHeartbeatDivisorToggle   <= evgSetHeartbeatDivisorToggle_m;
    evgSetHeartbeatDivisorToggle_d <= evgSetHeartbeatDivisorToggle;
    if (evgSetHeartbeatDivisorToggle != evgSetHeartbeatDivisorToggle_d) begin
        evgHeartbeatLoad <= sysWriteData - 2;
        if (sysWriteData < 1024) begin
            evgHeartbeatEnable <= 0;
        end
        else begin
            evgHeartbeatEnable <= 1;
        end
    end
    if (evgHeartbeatEnable) begin
        if (evgHeartbeatRequest) begin
            evgHeartbeatCounter <= { 1'b0, evgHeartbeatLoad };
        end
        else begin
            evgHeartbeatCounter <= evgHeartbeatCounter - 1;
        end
    end
    else begin
        evgHeartbeatCounter <= 0;
    end
end

/*
 * Table-driven events
 */
wire        sequencerEventStrobe;
wire  [7:0] sequencerEventCode;
ospreyEVGsequencer #(
    .SEQRAM_ADDR_WIDTH(SEQRAM_ADDR_WIDTH),
    .DEBUG(DEBUG))
  ospreyEVGsequencer (
    .sysClk(s_axi_aclk),
    .sysWriteData(s_axi_wdata),
    .sysWriteStrobe(s_axi_wready && (s_wRegIndex == REG_IDX_SEQUENCER)),
    .sysStatus(sequencerStatus),
    .evgClk(evgClk),
    .trigger(1'b0),
    .eventCode(sequencerEventCode),
    .eventCodeTVALID(sequencerEventStrobe));

/*
 * Timer-initated events
 */
(*MARK_DEBUG=DEBUG*) reg  [TIMER_COUNT-1:0] timerTriggerEnables = 0;
(*MARK_DEBUG=DEBUG*) wire [TIMER_COUNT-1:0] timerTriggerStrobes;
(*MARK_DEBUG=DEBUG*) reg  [(TIMER_COUNT*8)-1:0] timerEventCodes = 0;
generate
for (i = 0 ; i < TIMER_COUNT ; i = i + 1) begin : timerRequester
    (*ASYNC_REG="true"*) reg timerConfigToggle_m = 0;
(*MARK_DEBUG=DEBUG*)
    reg timerConfigToggle = 0, timerConfigToggle_d;
    (*ASYNC_REG="true"*) reg timerReloadToggle_m = 0;
(*MARK_DEBUG=DEBUG*)
    reg timerReloadToggle = 0, timerReloadToggle_d;
    reg [31:0] timerReload = ~0;
(*MARK_DEBUG=DEBUG*)
    reg [32:0] timer = 0;
    wire timerDone = timer[32];
    always @(posedge evgClk) begin
        timerConfigToggle_m <= sysTimerConfigToggle[i];
        timerConfigToggle   <= timerConfigToggle_m;
        timerConfigToggle_d <= timerConfigToggle;
        if (timerConfigToggle != timerConfigToggle_d) begin
            timerTriggerEnables[i] <= (sysWriteData[7:0] != 0);
            timerEventCodes[i*8+:8] <= sysWriteData[7:0];
        end
        timerReloadToggle_m <= sysTimerReloadToggle[i];
        timerReloadToggle   <= timerReloadToggle_m;
        timerReloadToggle_d <= timerReloadToggle;
        if (timerReloadToggle != timerReloadToggle_d) begin
            timerReload <= sysWriteData;
        end
        if (!timerTriggerEnables[i] || timerDone) begin
            timer <= {1'b0, timerReload};
        end
        else begin
            timer <= timer - 1;
        end
    end
    assign timerTriggerStrobes[i] = timerDone;
end
endgenerate

/*
 * Hardware-initated events
 */
(*MARK_DEBUG=DEBUG*) reg [(2*HW_TRIGGER_COUNT)-1:0] hwTriggerEnables = 0;
(*MARK_DEBUG=DEBUG*) reg [(2*HW_TRIGGER_COUNT)-1:0] hwTriggerStrobes = 0;
(*MARK_DEBUG=DEBUG*) reg [(2*HW_TRIGGER_COUNT*8)-1:0] hwEventCodes = 0;
generate
for (i = 0 ; i < HW_TRIGGER_COUNT ; i = i + 1) begin : hwRequester
    (*ASYNC_REG="true"*) reg hwTrigger_m = 0;
    reg hwTrigger = 0, hwTrigger_d = 0;
    always @(posedge evgClk) begin
        hwTrigger_m <= hwTriggers_a[i];
        hwTrigger   <= hwTrigger_m;
        hwTrigger_d <= hwTrigger;
        hwTriggerStrobes[(i*2)+0] <= hwTrigger && !hwTrigger_d;
        hwTriggerStrobes[(i*2)+1] <= !hwTrigger && hwTrigger_d;
    end
    for (j = 0 ; j < 2 ; j = j + 1) begin : hwEdge
        (*ASYNC_REG="true"*) reg hwUpdateToggle_m = 0;
        reg hwUpdateToggle = 0, hwUpdateToggle_d;
        always @(posedge evgClk) begin
            hwUpdateToggle_m <= sysHwUpdateToggle[(i*2)+j];
            hwUpdateToggle   <= hwUpdateToggle_m;
            hwUpdateToggle_d <= hwUpdateToggle;
            if (hwUpdateToggle != hwUpdateToggle_d) begin
                hwTriggerEnables[(i*2)+j] <= (sysWriteData[7:0] != 0);
                hwEventCodes[((i*2)+j)*8+:8] <= sysWriteData[7:0];
            end
        end
    end
end
endgenerate

/*
 * Software-initiated events
 */
(*ASYNC_REG="true"*) reg swTriggerToggle_m = 0;
reg swTriggerToggle = 0, swTriggerToggle_d = 0;
reg swTriggerStrobe = 0;
reg [7:0] swEventCode = 8'b0;
always @(posedge evgClk) begin
    swTriggerToggle_m <= sysSwTriggerToggle;
    swTriggerToggle   <= swTriggerToggle_m;
    swTriggerToggle_d <= swTriggerToggle;
    if (swTriggerToggle != swTriggerToggle_d) begin
        swEventCode <= sysWriteData[7:0];
        swTriggerStrobe <= 1;
    end
    else begin
        swTriggerStrobe <= 0;
    end
end

/*
 * Priority-encoded chain of event requesters.
 * Table-driven and software-driven event sources are always enabled.
 */
wire [EVCHAIN_LENGTH-1:0]  enables = { 1'b1,
                                       hwTriggerEnables,
                                       timerTriggerEnables,
                                       1'b1 };
wire [EVCHAIN_LENGTH-1:0] triggers = { swTriggerStrobe,
                                       hwTriggerStrobes,
                                       timerTriggerStrobes,
                                       sequencerEventStrobe };
wire [(EVCHAIN_LENGTH*8)-1:0] evCodes = { swEventCode,
                                          hwEventCodes,
                                          timerEventCodes,
                                          sequencerEventCode };
wire           [EVCHAIN_LENGTH:0] pendingChain;
wire [((EVCHAIN_LENGTH+1)*8)-1:0] eventChain;

// Head of chains
assign pendingChain[0] = 0;
assign eventChain[0+:8] = 0;

// Extract value to be sent to transmitter
(*MARK_DEBUG=DEBUG*) wire eventRequest = pendingChain[EVCHAIN_LENGTH];
(*MARK_DEBUG=DEBUG*) wire [7:0] eventCode = eventChain[EVCHAIN_LENGTH*8+:8];

/*
 * Instantiate the event requesters
 * The first ospreyEVGeventSource instantiated (corresponding to the
 * least-signficant entries in the 'enables', 'trigger' and 'evCodes
 * nets) has the highest priority.
 */
generate
for (i = 0 ; i < EVCHAIN_LENGTH ; i = i + 1) begin : eventRequester
  ospreyEVGeventSource ospreyEVGeventSource_i (
    .clk(evgClk),
    .enable(enables[i]),
    .triggerStrobe(triggers[i]),
    .code(evCodes[i*8+:8]),
    .evPendingIn(pendingChain[i]),
    .evCodeIn(eventChain[i*8+:8]),
    .evPendingOut(pendingChain[i+1]),
    .evCodeOut(eventChain[(i+1)*8+:8]));
end
endgenerate

/*
 * Distributed bus
 * Allow for asynchronous inputs
 */
(*ASYNC_REG="true"*) reg [7:0] distributedBus_m;
reg [7:0] evgDistributedBus;
always @(posedge evgClk) begin
    distributedBus_m  <= distributedBus;
    evgDistributedBus <= distributedBus_m;
end

/*
 * Instantiate the tiny event generator that does the real work
 */
localparam DISTRIBUTED_BUFFER_ADDRESS_WIDTH = 10;
tinyEVG #(
    .DISTRIBUTED_BUFFER_ADDRESS_WIDTH(DISTRIBUTED_BUFFER_ADDRESS_WIDTH),
    .DEBUG(DEBUG))
  tinyEVG_i (
    .evgTxClk(evgClk),
    .evgTxWord(evgTxChars),
    .evgTxIsK(evgTxCharIsK),
    .eventCode(eventCode),
    .eventStrobe(eventRequest),
    .heartbeatRequest(evgHeartbeatRequest),
    .ppsStrobe(evgPPSrising),
    .secondsStrobe(evgSetSecondsToggle != evgSetSecondsToggle_d),
    .seconds(sysPosixSeconds),
    .distributedBus(evgDistributedBus),
    .sysClk(1'b0),
    .sysWriteStrobe(1'b0),
    .sysAddress({DISTRIBUTED_BUFFER_ADDRESS_WIDTH{1'b0}}),
    .sysData(8'h00),
    .sysSendStrobe(1'b0),
    .sysBusy());

endmodule

/*
 * Single event source.
 * These are linked together in one big priority-encoded list.
 */
module ospreyEVGeventSource (
    input  wire          clk,
    input  wire          enable,
    input  wire          triggerStrobe,
    input  wire    [7:0] code,
    input  wire          evPendingIn,
    input  wire    [7:0] evCodeIn,
    output wire          evPendingOut,
    output wire    [7:0] evCodeOut);

reg       myRequest = 0;
reg [7:0] myEvent;

assign evPendingOut = evPendingIn || myRequest;
assign evCodeOut = evPendingIn ? evCodeIn : myEvent;

always @(posedge clk) begin
    if (enable) begin
        if (triggerStrobe) begin
            myRequest <= 1;
            myEvent <= code;
        end
        else if (!evPendingIn) begin
            myRequest <= 0;
        end
    end
    else begin
        myRequest <= 0;
    end
end
endmodule
`default_nettype wire
