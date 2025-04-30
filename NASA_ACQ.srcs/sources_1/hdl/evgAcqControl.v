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
 * Change acquisition enable at gap between acquired samples.
 */
`default_nettype none
module evgAcqControl (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output reg         isEVG = 0,

    input  wire        acqClk,
    input  wire        acqStrobe,
    output reg         acqEnabled = 0);

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg sysAcqEnabled = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[31]) isEVG <= 1;
        sysAcqEnabled <= sysGPIO_OUT[0];
    end
end
assign sysStatus = { isEVG, {30{1'b0}}, sysAcqEnabled };

///////////////////////////////////////////////////////////////////////////////
// ACQ clock domain
// Add a little delay after acquisition before changing acquisition status.
localparam DELAY_COUNTER_WIDTH = 7;
reg [DELAY_COUNTER_WIDTH-1:0] delay = 0;
wire delaying = delay[DELAY_COUNTER_WIDTH-1];
reg delaying_d = 1;

(*ASYNC_REG="true"*) reg acqEnabled_m;
always @(posedge acqClk) begin
    acqEnabled_m <= sysAcqEnabled;
    delaying_d <= delaying;
    if (acqStrobe) begin
        delay <= ~0;
    end
    else if (delaying) begin
        delay <= delay - 1;
    end
    else if (delaying_d) begin
        acqEnabled <= acqEnabled_m;
    end
end
endmodule
`default_nettype wire
