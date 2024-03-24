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
 * Generate and select the approprate clock to send to the ADC MCLK
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

    (*MARK_DEBUG=DEBUG*) input  wire clk32p768,
    (*MARK_DEBUG=DEBUG*) input  wire clk40p96,
    (*MARK_DEBUG=DEBUG*) input  wire clk51p2,
    (*MARK_DEBUG=DEBUG*) input  wire clk64,
    (*MARK_DEBUG=DEBUG*) output wire MCLK,
                         output wire MCLK_BUFG);

localparam CLOCK_COUNT = 4;
localparam SLOWEST_CLOCK = 32768000;
localparam CLOCK_MUXSEL_WIDTH = $clog2(CLOCK_COUNT);

/*
 * Delay for at least 3 cycles of slowest clock.
 * This ensures glitch-freee transitions between clocks.
 */
localparam DELAY_TICKS = (SYSCLK_RATE+(SLOWEST_CLOCK/3)-1)/(SLOWEST_CLOCK/3);
localparam DELAY_LOAD = DELAY_TICKS - 2;
localparam DELAY_COUNTER_WIDTH = $clog2(DELAY_LOAD+1) + 1;
reg [DELAY_COUNTER_WIDTH-1:0] delayCounter = DELAY_LOAD;
wire delayCounterDone = delayCounter [DELAY_COUNTER_WIDTH-1];

(*MARK_DEBUG=DEBUG*) reg [CLOCK_COUNT-1:0] activeClock = 0, newClock = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        newClock <= 1 << sysGPIO_OUT[CLOCK_MUXSEL_WIDTH-1:0];
        activeClock <= 0;
        delayCounter <= DELAY_LOAD;
    end
    else if (!delayCounterDone) begin
        delayCounter <= delayCounter - 1;
    end
    else begin
        activeClock <= newClock;
    end
end
assign sysStatus = { {32-CLOCK_COUNT{1'b0}}, activeClock };

wire clk16p384, clk20p48, clk25p6, clk32;
assign MCLK = |{ clk16p384, clk20p48, clk25p6, clk32 };
BUFG BUFG_MCLK (.I(MCLK), .O(MCLK_BUFG));

mclkSelectClockGen mclkSelectClockGen32 (
    .clkIn(clk64),
    .en_a(activeClock[0]),
    .clkOut(clk32));
mclkSelectClockGen mclkSelectClockGen25p6 (
    .clkIn(clk51p2),
    .en_a(activeClock[1]),
    .clkOut(clk25p6));
mclkSelectClockGen mclkSelectClockGen20p48 (
    .clkIn(clk40p96),
    .en_a(activeClock[2]),
    .clkOut(clk20p48));
mclkSelectClockGen mclkSelectClockGen16p384 (
    .clkIn(clk32p768),
    .en_a(activeClock[3]),
    .clkOut(clk16p384));
endmodule

module mclkSelectClockGen (
    input  wire clkIn,
    input  wire en_a,
    output reg  clkOut = 0);

(*ASYNC_REG="true"*) reg en_m;
reg en;
always @(posedge clkIn) begin
    en_m <= en_a;
    en   <= en_m;
    if (en) begin
        clkOut <= ~clkOut;
    end
    else begin
        clkOut <= 0;
    end
end
endmodule
`default_nettype wire
