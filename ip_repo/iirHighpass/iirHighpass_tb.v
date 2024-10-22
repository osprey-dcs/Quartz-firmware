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

`timescale 1ns/1ns

module iirHighpass_tb;

parameter DATA_WIDTH        = 24;
parameter FILTER_LOG2_ALPHA = 4;

reg  clk = 0;
reg  inTVALID = 0;
reg  signed [DATA_WIDTH-1:0] inTDATA = {DATA_WIDTH{1'bx}};
wire outTVALID;
wire signed [DATA_WIDTH-1:0] outTDATA;

iirHighpass #(.TDATA_WIDTH(DATA_WIDTH),
          .LOG2_ALPHA(FILTER_LOG2_ALPHA))
  iirHighpass (
    .clk(clk),
    .S_TVALID(inTVALID),
    .S_TDATA(inTDATA),
    .M_TVALID(outTVALID),
    .M_TDATA(outTDATA));

always begin
    #5 clk <= !clk;
end

wire [DATA_WIDTH-1:0] zero = {DATA_WIDTH{1'b0}};
wire [DATA_WIDTH-1:0] fullPos = { 1'b0, {DATA_WIDTH-1{1'b1}} };
wire [DATA_WIDTH-1:0] fullNeg = { 1'b1, {DATA_WIDTH-1{1'b0}} };

integer logFD;
reg signed [DATA_WIDTH-1:0] inTDATAold;
always @(posedge clk) begin
    if (inTVALID) inTDATAold <= inTDATA;
    if (outTVALID) $fdisplay(logFD, "%d %d", inTDATAold, outTDATA);
end

initial
begin
    $dumpfile("iirHighpass_tb.lxt");
    $dumpvars(0, iirHighpass_tb);
    logFD = $fopen("log.dat", "w");

    #100 ;
    @(posedge clk) begin
        inTVALID <= 1;
        inTDATA <= zero;
    end
    #1000 ; @(posedge clk) inTDATA <= fullPos;
    #1000 ; @(posedge clk) inTDATA <= fullNeg;
    #1000 ; @(posedge clk) inTDATA <= zero;
    #1000 ; @(posedge clk) inTDATA <= 1000000;
    #1000 ; @(posedge clk) inTDATA <= -1000000;
    #1000 ; @(posedge clk) inTDATA <= zero;
    #1000 ; @(posedge clk) inTDATA <= fullNeg;
    #1000 ; @(posedge clk) inTDATA <= fullPos;
    #1000 ; @(posedge clk) inTDATA <= zero;
    #1000 ; $finish;
end

endmodule
