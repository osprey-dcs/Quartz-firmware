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
 * Keep track of elapsed time
 */
`default_nettype none
module sysClkCounters #(
    parameter CLK_RATE = 100000000,
    parameter DEBUG    = "false"
    ) (
    input wire clk,
    (*mark_debug=DEBUG*) output wire       usecStrobe,
    (*mark_debug=DEBUG*) output reg [31:0] microsecondsSinceBoot = 0,
    (*mark_debug=DEBUG*) output reg [31:0] secondsSinceBoot = 0);

localparam TICK_COUNTER_RELOAD = (CLK_RATE / 1000000) - 2;
localparam TICK_COUNTER_WIDTH = $clog2(TICK_COUNTER_RELOAD+1) + 1;
(*mark_debug=DEBUG*)
reg [TICK_COUNTER_WIDTH-1:0] tickCounter = TICK_COUNTER_RELOAD;
assign usecStrobe = tickCounter[TICK_COUNTER_WIDTH-1];

localparam USEC_COUNTER_RELOAD = 1000000 - 2;
localparam USEC_COUNTER_WIDTH = $clog2(USEC_COUNTER_RELOAD+1) + 1;
(*mark_debug=DEBUG*)
reg [USEC_COUNTER_WIDTH-1:0] usecCounter = USEC_COUNTER_RELOAD;
wire usecOverflow = usecCounter[USEC_COUNTER_WIDTH-1];

always @(posedge clk) begin
    if (usecStrobe) begin
        tickCounter <= TICK_COUNTER_RELOAD;
        microsecondsSinceBoot <= microsecondsSinceBoot + 1;
        if (usecOverflow) begin
            usecCounter <= USEC_COUNTER_RELOAD;
            secondsSinceBoot <= secondsSinceBoot + 1;
        end
        else begin
            usecCounter <= usecCounter - 1;
        end
    end
    else begin
        tickCounter <= tickCounter - 1;
    end
end
endmodule
`default_nettype wire
