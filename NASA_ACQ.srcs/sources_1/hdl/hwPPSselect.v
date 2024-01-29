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
 * Choose hardware PPS source.
 * Use PMOD-GPS if present, otherwise use Quartz HARDWARE_PPS.
 */
`default_nettype none
module hwPPSselect #(
    parameter CLK_RATE = 100000000
    ) (
    input  wire clk,
    input  wire pmodPPS_a,
    input  wire quartzPPS_a,
    output wire hwPPS_a);

localparam PPS_TOOSLOW_RELOAD = ((CLK_RATE / 100) * 101) - 2;
localparam PPS_TOOFAST_RELOAD = ((CLK_RATE / 100) * 99) - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_TOOSLOW_RELOAD+1) + 1;

reg [PPS_COUNTER_WIDTH-1:0] pmodTooSlowCounter = PPS_TOOSLOW_RELOAD;
wire pmodTooSlow = pmodTooSlowCounter[PPS_COUNTER_WIDTH-1];
reg [PPS_COUNTER_WIDTH-1:0] pmodTooFastCounter = PPS_TOOFAST_RELOAD;
wire pmodTooFast = !pmodTooFastCounter[PPS_COUNTER_WIDTH-1];
reg pmodPPSvalid = 0;
assign hwPPS_a = pmodPPSvalid ? pmodPPS_a : quartzPPS_a;

(*ASYNC_REG="TRUE"*) reg pmodPPS_m = 0;
reg pmodPPS = 0, pmodPPS_d = 0;

always @(posedge clk) begin
    pmodPPS_m <= pmodPPS_a;
    pmodPPS   <= pmodPPS_m;
    pmodPPS_d <= pmodPPS;
    if (pmodPPS && !pmodPPS_d) begin
        if (!pmodTooFast && !pmodTooSlow) begin
            pmodPPSvalid <= 1;
        end
        else begin
            pmodPPSvalid <= 0;
        end
        pmodTooSlowCounter <= PPS_TOOSLOW_RELOAD;
        pmodTooFastCounter <= PPS_TOOFAST_RELOAD;
    end
    else begin
        if (pmodTooFast) begin
            pmodTooFastCounter <= pmodTooFastCounter - 1;
        end
        if (pmodTooSlow) begin
            pmodPPSvalid <= 0;
        end
        else begin
            pmodTooSlowCounter <= pmodTooSlowCounter - 1;
        end
    end
end
endmodule
`default_nettype wire
