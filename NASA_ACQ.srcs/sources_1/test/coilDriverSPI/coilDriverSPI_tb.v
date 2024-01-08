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
 * Test bench for SPI link to MAX4896 relay drivers.
 */
`timescale 1ns/1ns
`default_nettype none

module coilDriverSPI_tb;

parameter CLK_RATE = 100000000;
 
reg         clk = 0;
reg         setStrobeAndStart = 0;
reg         clrStrobe = 0;
reg  [31:0] GPIO_OUT = {32{1'bx}};
wire [31:0] status;
wire busy = status[0];

wire SPI_CLK;
wire SPI_CSn;
wire SPI_DIN;
wire SPI_DOUT;

coilDriverSPI #(.CLK_RATE(CLK_RATE)) 
  coilDriveSPI (
    .clk(clk),
    .GPIO_OUT(GPIO_OUT),
    .clrStrobe(clrStrobe),
    .setStrobeAndStart(setStrobeAndStart),
    .status(status),
    .SPI_CLK(SPI_CLK),
    .SPI_CSn(SPI_CSn),
    .SPI_DOUT(SPI_DOUT),
    .SPI_DIN(SPI_DIN));

always begin #5 clk = !clk; end

reg  [63:0] shiftReg;
always @(posedge SPI_CLK) begin
    if (!SPI_CSn) begin
        shiftReg <= {shiftReg[62:0], SPI_DIN};
    end
end
assign SPI_DOUT = shiftReg[63];

reg good = 1;
initial
begin
    $dumpfile("coilDriverSPI_tb.fst");
    $dumpvars(0, coilDriverSPI_tb);

    #300 ;
    runTest(32'h12345678, 32'h9ABCDEF0);
    #300 ;
    $display("=== %s ===", good ? "PASS" : "FAIL");
    $finish;
end

task runTest;
    input [31:0] hi;
    input [31:0] lo;
    begin
    @(posedge clk) begin
        GPIO_OUT <= hi;
        clrStrobe <= 1;
    end
    @(posedge clk) begin
        GPIO_OUT <= lo;
        clrStrobe <= 0;
        setStrobeAndStart <= 1;
    end
    @(posedge clk) begin
        GPIO_OUT <= {32{1'bx}};
        setStrobeAndStart <= 0;
    end
    @(posedge clk) ;
    @(posedge clk) ;
    while (busy) begin
        @(posedge clk) ;
    end
    $write("%16X %8X %8X   ", shiftReg, hi, lo);
    if (shiftReg == {hi, lo}) begin
        $display("PASS");
    end
    else begin
        $display("FAIL");
        good = 0;
    end
    end
endtask
endmodule
