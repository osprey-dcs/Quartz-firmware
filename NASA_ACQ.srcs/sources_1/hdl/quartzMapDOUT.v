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
 * Untangle the mapping between analog inputs and ADC DOUT lines.
 */
`default_nettype none
module quartzMapDOUT #(
    parameter AD7768_CHIP_COUNT = -1,
    parameter ADC_PER_CHIP      = -1
    ) (
    input  wire [(AD7768_CHIP_COUNT * ADC_PER_CHIP)-1:0] DOUT_RAW,
    output wire [(AD7768_CHIP_COUNT * ADC_PER_CHIP)-1:0] DOUT_MAPPED);

localparam CHANNEL_COUNT = AD7768_CHIP_COUNT * ADC_PER_CHIP;

genvar i;
generate
for (i = 0 ; i < CHANNEL_COUNT ; i = i + 8) begin : mapDOUT
    assign DOUT_MAPPED[i+0] = DOUT_RAW[i+3];
    assign DOUT_MAPPED[i+1] = DOUT_RAW[i+2];
    assign DOUT_MAPPED[i+2] = DOUT_RAW[i+1];
    assign DOUT_MAPPED[i+3] = DOUT_RAW[i+0];
    assign DOUT_MAPPED[i+4] = DOUT_RAW[i+4];
    assign DOUT_MAPPED[i+5] = DOUT_RAW[i+5];
    assign DOUT_MAPPED[i+6] = DOUT_RAW[i+6];
    assign DOUT_MAPPED[i+7] = DOUT_RAW[i+7];
end
endgenerate
endmodule
`default_nettype wire
