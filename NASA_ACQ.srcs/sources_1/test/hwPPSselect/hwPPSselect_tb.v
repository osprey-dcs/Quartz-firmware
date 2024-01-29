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
 * Test bench for hardware PPS selection
 */
`timescale 1us/1us
`default_nettype none

module hwPPSselect_tb;

parameter CLK_RATE = 10000;

reg clk = 0;
reg PMOD2_3 = 0;
reg HARDWARE_PPS = 0;
wire hwPPS_a;

// Instantiate device under test
hwPPSselect #(.CLK_RATE(CLK_RATE))
  hwPPSselect (
    .clk(clk),
    .pmodPPS_a(PMOD2_3),
    .quartzPPS_a(HARDWARE_PPS),
    .hwPPS_a(hwPPS_a));

always begin #50 clk = !clk; end
always begin
    #10000 ;
    while(1) begin
         #10000 HARDWARE_PPS = 0;
        #990000 if (!PMOD_ACTIVE) HARDWARE_PPS = 1;
    end
end
reg PMOD_ACTIVE = 0;
always begin
    #200000 ;
    while(1) begin
         #10000 PMOD2_3 = 0;
        #990000 if (PMOD_ACTIVE) PMOD2_3 = 1;
    end
end


initial
begin
    $dumpfile("hwPPSselect_tb.fst");
    $dumpvars(0, hwPPSselect_tb);

    #4000000 ;
    PMOD_ACTIVE = 1;
    #4000000 ;
    $finish;
end

endmodule
