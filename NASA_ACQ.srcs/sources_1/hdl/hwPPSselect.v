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
 * Use Quartz HARDWARE_PPS if present,
 * otherwise use PMOD-GPS PPS if present,
 * otherwise use local clock.
 */
`default_nettype none
module hwPPSselect #(
    parameter CLK_RATE = 100000000,
    parameter DEBUG    = "false"
    ) (
    input  wire                             clk,
    (*MARK_DEBUG=DEBUG*) input  wire        pmodPPS_a,
    (*MARK_DEBUG=DEBUG*) input  wire        quartzPPS_a,
    (*MARK_DEBUG=DEBUG*) output wire        hwPPS_a,
    (*MARK_DEBUG=DEBUG*) output wire        hwOrFallbackPPS_a,
    (*MARK_DEBUG=DEBUG*) output wire [31:0] status);

localparam PPS_RELOAD         = CLK_RATE - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_RELOAD+1) + 1;
reg [PPS_COUNTER_WIDTH-1:0] localCounter = PPS_RELOAD;
wire localPPSstrobe = localCounter[PPS_COUNTER_WIDTH-1];
reg [5:0] localStretch = 0;
wire localPPS = localStretch[5];

wire pmodValid, quartzValid;
reg usePMOD = 0, useQuartz = 0;

assign status = { 28'b0, usePMOD, pmodValid, useQuartz, quartzValid };
assign hwPPS_a = useQuartz ? quartzPPS_a : (usePMOD ? pmodPPS_a : 0);
assign hwOrFallbackPPS_a = (useQuartz || (usePMOD) ? hwPPS_a : localPPS);

isPPSvalid_ #(.CLK_RATE(CLK_RATE), .DEBUG(DEBUG))
  isQuartzValid (
    .clk(clk),
    .pps_a(quartzPPS_a),
    .ppsValid(quartzValid));

isPPSvalid_ #(.CLK_RATE(CLK_RATE), .DEBUG(DEBUG))
  isPMODvalid (
    .clk(clk),
    .pps_a(pmodPPS_a),
    .ppsValid(pmodValid));

always @(posedge clk) begin
    if (localPPSstrobe) begin
        localCounter <= PPS_RELOAD;
        localStretch <= ~0;
        /*
         * Limit chance of two closely spaced PPS markers when changing
         * source by changing source only at local PPS times.
         */
        if (quartzValid) begin
            useQuartz <= 1;
            usePMOD <= 0;
        end
        else if (pmodValid) begin
            useQuartz <= 0;
            usePMOD <= 1;
        end
        else begin
            useQuartz <= 0;
            usePMOD <= 0;
        end
    end
    else begin
        localCounter <= localCounter - 1;
        if (localPPS) begin
            localStretch <= localStretch - 1;
        end
    end
end
endmodule

module isPPSvalid_ #(
    parameter CLK_RATE = 100000000,
    parameter DEBUG    = "false"
    ) (
    input  wire clk,
    input  wire pps_a,
    output reg  ppsValid = 0);

localparam PPS_TOOSLOW_RELOAD = ((CLK_RATE / 100) * 101) - 2;
localparam PPS_TOOFAST_RELOAD = ((CLK_RATE / 100) * 99) - 2;
localparam PPS_RELOAD         = CLK_RATE - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_TOOSLOW_RELOAD+1) + 1;

reg [PPS_COUNTER_WIDTH-1:0] tooSlowCounter = PPS_TOOSLOW_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooSlow = tooSlowCounter[PPS_COUNTER_WIDTH-1];
reg [PPS_COUNTER_WIDTH-1:0] tooFastCounter = PPS_TOOFAST_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooFast = !tooFastCounter[PPS_COUNTER_WIDTH-1];
(*ASYNC_REG="TRUE"*) reg pps_m = 0;
reg pps = 0, pps_d = 0;

always @(posedge clk) begin
    pps_m <= pps_a;
    pps   <= pps_m;
    pps_d <= pps;
    if (pps && !pps_d) begin
        if (!tooFast && !tooSlow) begin
            ppsValid <= 1;
        end
        else begin
            ppsValid <= 0;
        end
        tooSlowCounter <= PPS_TOOSLOW_RELOAD;
        tooFastCounter <= PPS_TOOFAST_RELOAD;
    end
    else begin
        if (tooFast) begin
            tooFastCounter <= tooFastCounter - 1;
        end
        if (tooSlow) begin
            ppsValid <= 0;
        end
        else begin
            tooSlowCounter <= tooSlowCounter - 1;
        end
    end
end
endmodule
`default_nettype wire
