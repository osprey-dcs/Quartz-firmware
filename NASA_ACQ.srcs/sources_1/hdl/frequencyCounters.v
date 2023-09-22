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
 * Multi-input frequency counter
 */
module frequencyCounters #(
    parameter CHANNEL_COUNT          = 2,
    parameter OUTPUT_WIDTH           = 30,
    parameter CLOCKS_PER_ACQUISITION = 100000000,
    parameter MUXSEL_WIDTH = (CHANNEL_COUNT==1) ? 1 : $clog2(CHANNEL_COUNT)
    ) (
    input                     clk,
    input [CHANNEL_COUNT-1:0] measuredClocks,
    input                     acqMarker_a,

    input      [MUXSEL_WIDTH-1:0] channelSelect,
    output                        useInternalAcqMarker,
    output reg [OUTPUT_WIDTH-1:0] frequency);

// Internal acquisition marker
localparam TICKS_RELOAD = CLOCKS_PER_ACQUISITION - 2;
localparam TICKS_WIDTH = $clog2(TICKS_RELOAD+1) + 1;
reg [TICKS_WIDTH-1:0] ticks = TICKS_RELOAD;
wire acqStrobeInternal = ticks[TICKS_WIDTH-1];

// Watchdog to confirm validity of external acquisition marker
localparam WATCHDOG_RELOAD = ((CLOCKS_PER_ACQUISITION / 10) * 11) - 2;
localparam WATCHDOG_WIDTH = $clog2(WATCHDOG_RELOAD+1) + 1;
reg [WATCHDOG_WIDTH-1:0] watchdog = ~0;
wire watchdogTimeout = watchdog[WATCHDOG_WIDTH-1];
assign useInternalAcqMarker = watchdogTimeout;

// Acquisition marker
(*ASYNC_REG="true"*) reg acqMarker_m;
reg acqMarker_d0, acqMarker_d1, acqStrobeExternal;
reg acqStrobe = 0, acqPhase = 0;

// Accumulate counts from selected channel
localparam GRAY_WIDTH = 4;
function [3:0] GrayToBinary (input [3:0] gray); begin
    GrayToBinary[3] = gray[3];
    GrayToBinary[2] = gray[3] ^ gray[2];
    GrayToBinary[1] = gray[3] ^ gray[2] ^ gray[1];
    GrayToBinary[0] = gray[3] ^ gray[2] ^ gray[1] ^ gray[0];
end
endfunction
reg [MUXSEL_WIDTH-1:0] acqSelect = 0;
(*ASYNC_REG="true"*) reg [(CHANNEL_COUNT*GRAY_WIDTH)-1:0] grays_m;
reg [GRAY_WIDTH-1:0] grayMux, binary_d0, binary_d1, diff;
reg [OUTPUT_WIDTH-1:0] accumulator;
reg [OUTPUT_WIDTH-1:0] frequencies [0:CHANNEL_COUNT-1];

// Code common to all channels
always @(posedge clk) begin
    // Maintain internal acquisition marker
    if (acqStrobeInternal) begin
        ticks <= TICKS_RELOAD;
    end
    else begin
        ticks <= ticks - 1;
    end

    // Sample asynchronous external acquisition marker
    acqMarker_m  <= acqMarker_a;
    acqMarker_d0 <= acqMarker_m;
    acqMarker_d1 <= acqMarker_d0;
    acqStrobeExternal <= acqMarker_d0 && !acqMarker_d1;

    // Maintain watchdog
    if (acqStrobeExternal) begin
        watchdog <= WATCHDOG_RELOAD;
    end
    else if (!watchdogTimeout) begin
        watchdog <= watchdog - 1;
    end

    // Generate acquisition marker strobe
    acqStrobe <= useInternalAcqMarker ? acqStrobeInternal : acqStrobeExternal;

    // Count measured clocks
    grayMux <= grays_m[acqSelect*GRAY_WIDTH+:GRAY_WIDTH];
    binary_d0 <= GrayToBinary(grayMux);
    binary_d1 <= binary_d0;
    diff <= binary_d0 - binary_d1;
    if (acqStrobe) begin
        accumulator <= diff;
        acqPhase <= !acqPhase;
        if (acqPhase) begin
            frequencies[acqSelect] <= accumulator;
            if (acqSelect == (CHANNEL_COUNT-1)) begin
                acqSelect <= 0;
            end
            else begin
                acqSelect <= acqSelect + 1;
            end
        end
    end
    else begin
        accumulator <= accumulator + diff;
    end

    // Emit selected value
    frequency <= frequencies[channelSelect];
end

// Per-channel code
function [3:0] BinaryToGray (input [3:0] binary);
    BinaryToGray = binary ^ {1'b0, binary[3:1]};
endfunction

genvar i;
generate
for (i = 0 ; i < CHANNEL_COUNT ; i = i + 1) begin

// Minimal 4 bit Gray counter updating at measured clock rate
reg [3:0] gray = 0;
always @(posedge measuredClocks[i]) begin
    gray <= BinaryToGray(GrayToBinary(gray) + 1);
end

// Get Gray counter to system clock domain
always @(posedge clk) begin
    grays_m[i*GRAY_WIDTH+:GRAY_WIDTH] <= gray;
end

end
endgenerate
endmodule
