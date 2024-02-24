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
 * Test bench for fake Quartz AD7768 ADC
 */
`timescale 1ns/1ps
`default_nettype none

module fakeQuartzAD7768_tb;

localparam ADC_CHIP_COUNT = 1;
localparam ADC_PER_CHIP   = 8;
localparam ADC_WIDTH      = 24;


reg MCLK = 0;
wire                [ADC_CHIP_COUNT-1:0] adcDCLK;
wire                [ADC_CHIP_COUNT-1:0] adcDRDY;
wire [(ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0] adcDOUT;

// Instantiate device under test
fakeQuartzAD7768 #(
    .ADC_CHIP_COUNT(ADC_CHIP_COUNT),
    .ADC_PER_CHIP(ADC_PER_CHIP),
    .ADC_WIDTH(ADC_WIDTH))
  fakeQuartzAD7768 (
    .MCLK(MCLK),
    .adcDCLK(adcDCLK),
    .adcDRDY(adcDRDY),
    .adcDOUT(adcDOUT));

// Generate clock
always begin #15.625 MCLK = !MCLK; end

initial
begin
    $dumpfile("fakeQuartzAD7768_tb.fst");
    $dumpvars(0, fakeQuartzAD7768_tb);

    #30000;
    $finish;
end

endmodule
