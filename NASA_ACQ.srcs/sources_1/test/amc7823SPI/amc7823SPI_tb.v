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
 * Test bench for SPI link to AMC7823 Analog Monitoring and Control Circuit
 */
`timescale 1ns/1ns
`default_nettype none

module amc7823SPI_tb;

parameter CLK_RATE = 100000000;
 
reg         clk = 0;
reg         csrStrobe = 0;
reg  [31:0] GPIO_OUT = {32{1'bx}};
wire [31:0] status;
wire [15:0] readReg    = status[0+:16];
wire [11:0] readDataLo = status[0+:12];
wire [11:0] readDataHi = status[16+:12];
wire        busy       = status[31];

wire SPI_CLK;
wire SPI_CS_n;
wire SPI_DIN;
reg  SPI_DOUT;

amc7823SPI #(.CLK_RATE(CLK_RATE)) 
  amc7823SPI (
    .clk(clk),
    .GPIO_OUT(GPIO_OUT),
    .csrStrobe(csrStrobe),
    .status(status),
    .SPI_CLK(SPI_CLK),
    .SPI_CS_n(SPI_CS_n),
    .SPI_DOUT(SPI_DOUT),
    .SPI_DIN(SPI_DIN));

always begin #5 clk = !clk; end

reg  [31:0] shiftReg;
always @(posedge SPI_CLK) begin
    if (!SPI_CS_n) begin
        shiftReg <= {shiftReg[0+:31], 1'bx};
        SPI_DOUT <= shiftReg[31];
    end
end
reg dout = 1'bx;
always @(negedge SPI_CLK) begin
    if (!SPI_CS_n) begin
        shiftReg[0] = SPI_DIN;
    end
end

always @(negedge SPI_CS_n) begin
    shiftReg <= {{16{1'bz}}, 16'h0987};
end
always @(posedge SPI_CS_n) begin
    SPI_DOUT <= 1'bz;
end

reg good = 1;
initial
begin
    $dumpfile("amc7823SPI_tb.fst");
    $dumpvars(0, amc7823SPI_tb);

    #300 ;
    writeCsr(32'h40000000);
    #20
    writeCsr(32'h12345678);
    while(busy) #10;
    writeCsr(32'h60000000);
    #20
    $write("%8X %8X   ", shiftReg, status);
    #300 ;
    if ((readDataLo != 12'h987) || (shiftReg != 32'h12345678)) good = 0;
    $display("=== %s ===", good ? "PASS" : "FAIL");
    $finish;
end

task writeCsr;
    input [31:0] w;
    begin
    @(posedge clk) begin
        GPIO_OUT <= w;
        csrStrobe <= 1;
    end
    @(posedge clk) begin
        GPIO_OUT <= {32{1'bx}};
        csrStrobe <= 0;
    end
    @(posedge clk) ;
    end
endtask
endmodule
