/*
 * MIT License
 *
 * Copyright (c) 2024 Osprey DCS
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
 * Generate and select the approprate MCLK and SYNC to send to the AD7768s.
 */
`default_nettype none
module mclkSelect #(
    parameter SYSCLK_RATE = 100000000,
    parameter DEBUG       = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input  wire        acqClk,
    input  wire        acqPPSstrobe,

                         input  wire clk32p768,
                         input  wire clk40p96,
                         input  wire clk51p2,
                         input  wire clk64,
    (*MARK_DEBUG=DEBUG*) output wire MCLK,
    (*MARK_DEBUG=DEBUG*) output wire SYNC_n);

localparam CLOCK_COUNT = 4;
localparam SLOWEST_CLOCK = 32768000;
localparam CLOCK_MUXSEL_WIDTH = $clog2(CLOCK_COUNT);

(*MARK_DEBUG=DEBUG*) reg [CLOCK_COUNT-1:0] activeClock = 0;
(*MARK_DEBUG=DEBUG*) reg sysSyncRequestToggle = 0;
wire [CLOCK_COUNT-1:0] syncAcknowledgeToggles;
(*ASYNC_REG="true"*) reg [CLOCK_COUNT-1:0] sysSyncAcknowledgeToggles_m = 0;
(*MARK_DEBUG=DEBUG*) reg [CLOCK_COUNT-1:0] sysSyncAcknowledgeToggles = 0;
(*MARK_DEBUG=DEBUG*) reg sysSyncBusy = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[CLOCK_COUNT]) begin
            activeClock <= sysGPIO_OUT[CLOCK_COUNT-1:0];
        end
        if (sysGPIO_OUT[31]) begin
            sysSyncRequestToggle <= !sysSyncRequestToggle;
        end
    end
    sysSyncAcknowledgeToggles_m <= syncAcknowledgeToggles;
    sysSyncAcknowledgeToggles   <= sysSyncAcknowledgeToggles_m;
    sysSyncBusy <=
             (sysSyncAcknowledgeToggles != {CLOCK_COUNT{sysSyncRequestToggle}});
end

/*
 * Measure clock rate
 * Result is in acquisition clock domain, but processor readout
 * knows this and reads the value until it is stable.
 */
localparam MCLK_RATE_WIDTH = 28;
(*ASYNC_REG="true"*) reg mclk_m;
reg mclk_d0, mclk_d1, mclkRising;
reg [MCLK_RATE_WIDTH-1:0] mclkCounter, mclkRate;
reg [3:0] acqPPScounter = 0;
wire acqPPSstretch = acqPPScounter[3];
always @(posedge acqClk) begin
    mclk_m  <= MCLK;
    mclk_d0 <= mclk_m;
    mclk_d1 <= mclk_d0;
    mclkRising <= (mclk_d0 && !mclk_d1);
    if (acqPPSstrobe) begin
        mclkRate <= mclkCounter;
        if (mclkRising) begin
            mclkCounter <= 1;
        end
        else begin
            mclkCounter <= 0;
        end
        acqPPScounter <= ~0;
    end
    else begin
        if (mclkRising) begin
            mclkCounter <= mclkCounter +1 ;
        end
        if (acqPPSstretch) begin
            acqPPScounter <= acqPPScounter - 1;
        end
    end
end
assign sysStatus = { sysSyncBusy, {32-1-MCLK_RATE_WIDTH{1'b0}}, mclkRate };

/*
 * Generate the clocks and select the desired one
 */
(*MARK_DEBUG=DEBUG*) wire clk16p384, clk20p48, clk25p6, clk32;
assign MCLK = |{ clk16p384, clk20p48, clk25p6, clk32 };

(*MARK_DEBUG=DEBUG*) wire sync16p384, sync20p48, sync25p6, sync32;
assign SYNC_n = ~(|{ sync16p384, sync20p48, sync25p6, sync32 });

mclkSelectClockGen #(.DEBUG(DEBUG)) mclkSelectClockGen32 (
    .clkIn(clk64),
    .en_a(activeClock[0]),
    .ppsMarker_a(acqPPSstretch),
    .syncRequestToggle_a(sysSyncRequestToggle),
    .syncAcknowledgeToggle(syncAcknowledgeToggles[0]),
    .clkOut(clk32),
    .sync(sync32));
mclkSelectClockGen #(.DEBUG(DEBUG)) mclkSelectClockGen25p6 (
    .clkIn(clk51p2),
    .en_a(activeClock[1]),
    .ppsMarker_a(acqPPSstretch),
    .syncRequestToggle_a(sysSyncRequestToggle),
    .syncAcknowledgeToggle(syncAcknowledgeToggles[1]),
    .clkOut(clk25p6),
    .sync(sync25p6));
mclkSelectClockGen #(.DEBUG(DEBUG)) mclkSelectClockGen20p48 (
    .clkIn(clk40p96),
    .en_a(activeClock[2]),
    .ppsMarker_a(acqPPSstretch),
    .syncRequestToggle_a(sysSyncRequestToggle),
    .syncAcknowledgeToggle(syncAcknowledgeToggles[2]),
    .clkOut(clk20p48),
    .sync(sync20p48));
mclkSelectClockGen #(.DEBUG(DEBUG)) mclkSelectClockGen16p384 (
    .clkIn(clk32p768),
    .en_a(activeClock[3]),
    .ppsMarker_a(acqPPSstretch),
    .syncRequestToggle_a(sysSyncRequestToggle),
    .syncAcknowledgeToggle(syncAcknowledgeToggles[3]),
    .clkOut(clk16p384),
    .sync(sync16p384));
endmodule

module mclkSelectClockGen #(
    parameter DEBUG = "false"
    ) (
    input  wire clkIn,
    input  wire en_a,
    input  wire ppsMarker_a,
    input  wire syncRequestToggle_a,
    output reg  syncAcknowledgeToggle = 0,
    output reg  clkOut = 0,
    output reg  sync = 0);

(*ASYNC_REG="true"*) reg en_m = 0;
(*MARK_DEBUG=DEBUG*) reg en = 0;

(*ASYNC_REG="true"*) reg ppsMarker_m = 0;
(*MARK_DEBUG=DEBUG*) reg ppsMarker = 0, ppsMarker_d = 0;

(*ASYNC_REG="true"*) reg syncRequestToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg syncRequestToggle = 0;

localparam ST_IDLE       = 2'd0,
           ST_AWAIT_PPS  = 2'd1,
           ST_AWAIT_MCLK = 2'd2,
           ST_DONE       = 2'd3;
(*MARK_DEBUG=DEBUG*) reg [1:0] state = ST_IDLE;

always @(posedge clkIn) begin
    en_m <= en_a;
    en   <= en_m;
    if (en) begin
        clkOut <= ~clkOut;
    end
    else begin
        clkOut <= 0;
    end

    ppsMarker_m <= ppsMarker_a;
    ppsMarker   <= ppsMarker_m;
    ppsMarker_d <= ppsMarker;

    syncRequestToggle_m <= syncRequestToggle_a;
    syncRequestToggle   <= syncRequestToggle_m;

    case (state)
    ST_IDLE: begin
        sync <= 0;
        if (syncRequestToggle != syncAcknowledgeToggle) begin
            state <= ST_AWAIT_PPS;
        end
    end
    ST_AWAIT_PPS: begin
        if (!en) begin
            state <= ST_DONE;
        end
        else if (ppsMarker && !ppsMarker_d) begin
            state <= ST_AWAIT_MCLK;
        end
    end
    ST_AWAIT_MCLK: begin
        if (!en) begin
            state <= ST_DONE;
        end
        else if (clkOut) begin
            sync <= 1;
            state <= ST_DONE;
        end
    end
    ST_DONE: begin
        syncAcknowledgeToggle <= syncRequestToggle;
        state <= ST_IDLE;
    end
    default: ;
    endcase

end
endmodule
`default_nettype wire
