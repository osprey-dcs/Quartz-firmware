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
 * Merge and forward MPS System trip status from multiple receivers.
 */
`default_nettype none
module mpsMerge #(
    parameter MGT_COUNT        = -1,
    parameter MGT_DATA_WIDTH   = -1,
    parameter MPS_OUTPUT_COUNT = -1
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    input  wire        sysIsEVG,

    input  wire [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars,
    input  wire                  [MGT_COUNT-1:0] mgtRxLinkUp,

    input  wire                     mgtTxClk,
    output reg [MGT_DATA_WIDTH-1:0] mpfTxChars,
    output reg                      mpfTxCharIsK);

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg [MGT_COUNT-1:0] linkImportant = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        linkImportant <= sysGPIO_OUT[0+:MGT_COUNT] &
                         {{MGT_COUNT-2{1'b1}}, sysIsEVG, 1'b0};
    end
end

///////////////////////////////////////////////////////////////////////////////
// Combinatorial merge
// "To iterate is human, to recurse, divine." -- Attributed to L Peter Deutsch

function [MPS_OUTPUT_COUNT-1:0] merge;
    input            [MPS_OUTPUT_COUNT-1:0] linkImportant;
    input                   [MGT_COUNT-1:0] mgtRxLinkUp;
    input  [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars;
    input                             [7:0] i;
    merge = (i == 0) ? 0 :
             (({MPS_OUTPUT_COUNT{linkImportant[i]}} &
                       (mgtRxChars[(i*MGT_DATA_WIDTH)+8+:MPS_OUTPUT_COUNT] |
                                     {MPS_OUTPUT_COUNT{!mgtRxLinkUp[i]}})) |
                            merge(linkImportant, mgtRxLinkUp, mgtRxChars, i-1));
endfunction

wire [MPS_OUTPUT_COUNT-1:0] mpsTripped_a =
                     merge(linkImportant, mgtRxLinkUp, mgtRxChars, MGT_COUNT-1);

///////////////////////////////////////////////////////////////////////////////
// MGT transmit clock domain
reg [2:0] mpfTxPhase = 0;
(*ASYNC_REG="true"*)  reg [MPS_OUTPUT_COUNT-1:0] mpsTripped_m;
reg [MPS_OUTPUT_COUNT-1:0] mpsTripped;
always @(posedge mgtTxClk) begin
    mpsTripped_m <= mpsTripped_a;
    mpsTripped   <= mpsTripped_m;
    mpfTxChars[8+:MPS_OUTPUT_COUNT] <= mpsTripped;
    if (mpfTxPhase[2]) begin
        mpfTxPhase <= 1;
        mpfTxChars[0+:8] <= 8'hBC;
        mpfTxCharIsK <= 1;
    end
    else begin
        mpfTxPhase <= mpfTxPhase + 1;
        mpfTxChars[0+:8] <= 8'h00;
        mpfTxCharIsK <= 0;
    end
end

///////////////////////////////////////////////////////////////////////////////
// System clock domain
assign sysStatus = { {16-MPS_OUTPUT_COUNT{1'b0}}, mpsTripped_a,
                     {16-MGT_COUNT{1'b0}}, linkImportant };
endmodule
`default_nettype wire
