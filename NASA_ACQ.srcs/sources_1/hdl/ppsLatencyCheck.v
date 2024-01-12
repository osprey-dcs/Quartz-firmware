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
 * Measure time between hardware PPS and EVR PPS event.
 */
`default_nettype none
module ppsLatencyCheck #(
    parameter CLK_RATE = 100000000
    ) (
    input  wire        clk,
    output wire [31:0] latency,
    input  wire        hwPPS_a,
    input  wire        evrPPSmarker_a);

localparam MAX_LATENCY_USEC = 2;

localparam LATENCY_COUNTER_MAX = ((CLK_RATE / 1000) * MAX_LATENCY_USEC) / 1000;
localparam LATENCY_COUNTER_WIDTH = $clog2(LATENCY_COUNTER_MAX+1) + 1;
reg [LATENCY_COUNTER_WIDTH-1:0] latencyCounter = 0, latencyValue = ~0;
wire latencyCounterOverflow = latencyCounter[LATENCY_COUNTER_WIDTH-1];
reg active = 0;
reg statusToggle = 0;

(*ASYNC_REG="true"*) reg hwPPS_m = 0;
reg hwPPS = 0, hwPPS_d = 0;
(*ASYNC_REG="true"*) reg evrPPSmarker_m = 0;
reg evrPPSmarker = 0, evrPPSmarker_d = 0;

/*
 * Top bit is overflow indicator
 * Next bit toggle on update
 */
assign latency = { latencyValue[LATENCY_COUNTER_WIDTH-1], statusToggle,
                   {32-1-LATENCY_COUNTER_WIDTH{1'b0}},
                   latencyValue[0+:LATENCY_COUNTER_WIDTH-1] };

always @(posedge clk) begin
    hwPPS_m <= hwPPS_a;
    hwPPS   <= hwPPS_m;
    hwPPS_d <= hwPPS;
    evrPPSmarker_m <= evrPPSmarker_a;
    evrPPSmarker   <= evrPPSmarker_m;
    evrPPSmarker_d <= evrPPSmarker;
    if (active) begin
        latencyCounter <= latencyCounter + 1;
        if (latencyCounterOverflow || (evrPPSmarker && !evrPPSmarker_d)) begin
            latencyValue <= latencyCounter;
            statusToggle <= !statusToggle;
            active <= 0;
        end
    end
    else begin
        latencyCounter <= 1;
        if (hwPPS && !hwPPS_d) begin
            active <= 1;
        end
    end
end
endmodule
`default_nettype wire
