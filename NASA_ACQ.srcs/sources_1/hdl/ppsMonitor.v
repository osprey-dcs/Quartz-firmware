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
 * Monitor quality of PPS signal.
 */
`default_nettype none
module ppsMonitor #(
    parameter DEBOUNCE_NS = 5000
    ) (
    input  wire        fixedClk200,
    input  wire        pps_a,
    output wire [31:0] status);

localparam VALUE_WIDTH = 12;
localparam FILTER_LOG2_ALPHA = 6;
localparam CLK_RATE = 200000000;

localparam COUNTER_MAX = (CLK_RATE / 10) * 12;
localparam COUNTER_WIDTH = $clog2(COUNTER_MAX+1) + 1;
reg [COUNTER_WIDTH-1:0] intervalCounter = 0, interval = 0;
wire intervalCounterOverflow = intervalCounter[COUNTER_WIDTH-1];
wire intervalOverflow = interval[COUNTER_WIDTH-1];

reg signed [COUNTER_WIDTH-1:0] change;
wire [COUNTER_WIDTH-1:0] absChange = change;
wire [COUNTER_WIDTH-1:0] limit = {{COUNTER_WIDTH-VALUE_WIDTH{1'b0}},
                                                           {VALUE_WIDTH{1'b1}}};

localparam FILTER_WIDTH = FILTER_LOG2_ALPHA + VALUE_WIDTH;
reg [FILTER_WIDTH-1:0] filter;

assign status = { {32-FILTER_WIDTH{1'b0}}, filter };

(*ASYNC_REG="true"*) reg pps_m = 0;
reg pps = 0;

localparam DEBOUNCE_TICKS = (DEBOUNCE_NS * (CLK_RATE/1000) + 999999) /
                                                                        1000000;
localparam DEBOUNCE_RELOAD = DEBOUNCE_TICKS - 2;
localparam DEBOUNCE_COUNTER_WIDTH = $clog2(DEBOUNCE_RELOAD+1) + 1;
reg [DEBOUNCE_COUNTER_WIDTH-1:0] debounceCounter = DEBOUNCE_RELOAD;
wire debounceDone = debounceCounter[DEBOUNCE_COUNTER_WIDTH-1];
reg debounceDone_d = 0;
reg debounced = 0, debounced_d = 0;
reg [2:0] state;

/*
 * Sample and debounce PPS signal.
 * Measure interval between rising edges
 */
always @(posedge fixedClk200) begin
    pps_m <= pps_a;
    pps   <= pps_m;

    if (pps) begin
        debounced <= 1;
        debounceCounter <= DEBOUNCE_RELOAD;
    end
    else begin
        if (!debounceDone) begin
            debounceCounter <= debounceCounter - 1;
        end
        if (debounceDone && !debounceDone_d) begin
            debounced <= 0;
        end
    end
    debounceDone_d <= debounceDone;
    debounced_d <= debounced;

    if (debounced && !debounced_d) begin
        intervalCounter <= 1;
        interval <= intervalCounter;
        if (!intervalOverflow && !intervalCounterOverflow) begin
            change <= intervalCounter - interval;
            state <= 1;
        end
    end
    else begin
        state <= state << 1;
        if (!intervalCounterOverflow) begin
            intervalCounter <= intervalCounter + 1;
        end
    end

    if (state[0]) begin
        if (change < 0) change <= -change;
    end
    if (state[1]) begin
        if (absChange > limit) change <= limit;
    end
    if (state[2]) begin
        filter <= filter -
                  (filter >> FILTER_LOG2_ALPHA) +
                  {{FILTER_LOG2_ALPHA{1'b0}}, change[VALUE_WIDTH-1:0]};
    end
end
endmodule
`default_nettype wire
