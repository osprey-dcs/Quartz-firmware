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
 * Count number of rising edges
 */
`default_nettype none
module countRisingEdges (
    input  wire        clk,
    input  wire        signal_a,
    output wire [31:0] status);

(*ASYNC_REG="true"*) reg signal_m = 0;
reg signal = 0, signal_d = 0;
reg  [30:0] risingEdgeCount = 0;

always @(posedge clk) begin
    signal_m  <= signal_a;
    signal    <= signal_m;
    signal_d  <= signal;
    if (signal && !signal_d) begin
        risingEdgeCount <= risingEdgeCount + 1;
    end
end

assign status = { signal, risingEdgeCount };

endmodule
`default_nettype wire
