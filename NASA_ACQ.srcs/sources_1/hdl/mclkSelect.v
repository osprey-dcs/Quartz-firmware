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
 * Select the approprate clock to send to the ADC MCLK
 */
`default_nettype none
module mclkSelect #(
    parameter DEBUG = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    (*MARK_DEBUG=DEBUG*) input  wire clk32,
    (*MARK_DEBUG=DEBUG*) input  wire clk25p6,
    (*MARK_DEBUG=DEBUG*) input  wire clk20p48,
    (*MARK_DEBUG=DEBUG*) input  wire clk16p384,
    (*MARK_DEBUG=DEBUG*) output wire MCLK);

localparam MUXSEL_WIDTH = 2;
(*MARK_DEBUG=DEBUG*) reg [MUXSEL_WIDTH-1:0] muxSel;
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        muxSel <= sysGPIO_OUT[MUXSEL_WIDTH-1:0];
    end
end
assign sysStatus = { {32-MUXSEL_WIDTH{1'b0}}, muxSel };

assign MCLK = (muxSel == 1) ? clk25p6   :
              (muxSel == 2) ? clk20p48  :
              (muxSel == 3) ? clk16p384 :
                              clk32;
endmodule
`default_nettype wire
