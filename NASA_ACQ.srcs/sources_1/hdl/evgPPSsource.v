/*
 * MIT License
 *
 * Copyright (c) 2025 Osprey DCS
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
 * Create event generator PPS marker
 * Use hardware marker if valid.
 */
`default_nettype none
module evgPPSsource #(
    parameter CLK_RATE = 100000000
    ) (
    input  wire        clk,
    input  wire        csrStrobe,
    input  wire [31:0] GPIO_OUT,
    output wire [31:0] status,

    input  wire        hwPPSvalid_a,
    input  wire        hwPPSmarker_a,
    output wire        evgPPSmarker_a);

reg enableLocalPPS = 0;

localparam DUMMY_PPS_RELOAD = CLK_RATE - 2;
localparam DUMMY_PPS_WIDTH = $clog2(DUMMY_PPS_RELOAD+1) + 1;
reg [DUMMY_PPS_WIDTH-1:0] localPPScounter = DUMMY_PPS_RELOAD;
reg [3:0] localPPSstretch = 0;
wire localPPSmarker = localPPSstretch[3];

always @(posedge clk) begin
    if (csrStrobe) begin
        if (GPIO_OUT[0]) begin
            enableLocalPPS <= 1;
        end
        else if (GPIO_OUT[1]) begin
            enableLocalPPS <= 0;
        end
    end
    if (enableLocalPPS) begin
        if (localPPScounter[DUMMY_PPS_WIDTH-1]) begin
            localPPScounter <= DUMMY_PPS_RELOAD;
            localPPSstretch <= ~0;
        end
        else begin
            localPPScounter <= localPPScounter - 1;
            if (localPPSmarker) begin
                localPPSstretch <= localPPSstretch - 1;
            end
        end
    end
    else begin
        localPPScounter <= DUMMY_PPS_RELOAD;
        localPPSstretch <= 0;
    end
end
assign status = { {31{1'b0}}, enableLocalPPS };
assign evgPPSmarker_a = hwPPSvalid_a ? hwPPSmarker_a :
                                       (enableLocalPPS ? localPPSmarker : 1'b0);
endmodule
`default_nettype wire
