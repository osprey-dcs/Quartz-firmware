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
    output reg  [31:0] mclkRate,

    input  wire        acqClk,
    input  wire        acqPPSstrobe,

    (*MARK_DEBUG=DEBUG*) input  wire clk32p768,
    (*MARK_DEBUG=DEBUG*) input  wire clk40p96,
    (*MARK_DEBUG=DEBUG*) input  wire clk51p2,
    (*MARK_DEBUG=DEBUG*) input  wire clk64,
    (*MARK_DEBUG=DEBUG*) output wire MCLK);

localparam CLOCK_COUNT = 4;
localparam SLOWEST_CLOCK = 32768000;
localparam CLOCK_MUXSEL_WIDTH = $clog2(CLOCK_COUNT);

(*MARK_DEBUG=DEBUG*) reg [CLOCK_COUNT-1:0] activeClock = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        activeClock <= sysGPIO_OUT[CLOCK_COUNT-1:0];
    end
end

/*
 * Measure clock rate
 * Result is in acquisition clock domain, but processor readout
 * knows this and reads the value until it is stable.
 */
(*ASYNC_REG="true"*) reg mclk_m;
reg mclk_d0, mclk_d1, mclkRising;
reg [31:0] mclkCounter;
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
    end
    else if (mclkRising) begin
        mclkCounter <= mclkCounter +1 ;
    end
end

/*
 * Generate the clocks and select the desired one
 */
wire clk16p384, clk20p48, clk25p6, clk32;
assign MCLK = |{ clk16p384, clk20p48, clk25p6, clk32 };

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
