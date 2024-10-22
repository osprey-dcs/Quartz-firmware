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
 * First-order IIR highpass filter
 *
 *                  (Z - 1)
 *        Y = ------------------- * X
 *            Z*(1+(1/alpha)) - 1
 *
 *        alpha = Tau / Tsamp
 *
 * One cycle latency
 *
 * Transitions beyond rails are properly clipped:
 *    'diff' is one bit wider than sum
 *    output is clipped to rails
 */

module iirHighpass #(
    parameter TDATA_WIDTH = 16,
    parameter LOG2_ALPHA  = 10
    ) (
    input  wire                          clk,
    input  wire signed [TDATA_WIDTH-1:0] S_TDATA,
    input  wire                          S_TVALID,
    output reg  signed [TDATA_WIDTH-1:0] M_TDATA,
    output reg                           M_TVALID);

localparam SUM_WIDTH  = TDATA_WIDTH + LOG2_ALPHA;
localparam DIFF_WIDTH = SUM_WIDTH + 1;

wire signed [DIFF_WIDTH-1:0] x =
            {S_TDATA[TDATA_WIDTH-1], S_TDATA, {DIFF_WIDTH-TDATA_WIDTH-1{1'b0}}};
reg   signed [TDATA_WIDTH-1:0] y = 0;

reg  signed  [SUM_WIDTH-1:0] sum = 0;
wire signed [DIFF_WIDTH-1:0] diff = x - {sum[SUM_WIDTH-1], sum};

always @(posedge clk)
begin
    if (S_TVALID) begin
        sum <= sum + { {LOG2_ALPHA-1{diff[DIFF_WIDTH-1]}},
                                                diff[DIFF_WIDTH-1:LOG2_ALPHA] };
        /* Clip result */
        case(diff[DIFF_WIDTH-1-:2])
        2'b01:   M_TDATA <= { 1'b0, {TDATA_WIDTH-1{1'b1}} };
        2'b10:   M_TDATA <= { 1'b1, {TDATA_WIDTH-1{1'b0}} };
        default: M_TDATA <= diff[DIFF_WIDTH-2-:TDATA_WIDTH];
        endcase
        M_TVALID <= 1;
    end
    else begin
        M_TVALID <= 0;
    end
end

endmodule
