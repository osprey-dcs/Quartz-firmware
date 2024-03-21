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
 *
 * Note that only the rising edge of the output is timed to the rising edge
 * of the input.  The falling edge of the output is delayed from the falling
 * edge of the input to allow for debouncing.
 */
`default_nettype none
module hwPPSselect #(
    parameter CLK_RATE    = -1,
    parameter DEBOUNCE_NS = 1000,
    parameter DEBUG       = "false"
    ) (
    input  wire                             sysClk,
    input  wire                             sysCsrStrobe,
    input  wire                      [31:0] sysGPIO_OUT,
    (*MARK_DEBUG=DEBUG*) output wire [31:0] sysStatus,
    (*MARK_DEBUG=DEBUG*) input  wire        pmodPPS_a,
    (*MARK_DEBUG=DEBUG*) input  wire        quartzPPS_a,
    (*MARK_DEBUG=DEBUG*) output wire        hwPPS_a,
    (*MARK_DEBUG=DEBUG*) output wire        hwOrFallbackPPS_a);

localparam PPS_RELOAD         = CLK_RATE - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_RELOAD+1) + 1;
reg [PPS_COUNTER_WIDTH-1:0] localCounter = PPS_RELOAD;
wire localPPSstrobe = localCounter[PPS_COUNTER_WIDTH-1];
reg [5:0] localStretch = 0;
wire localPPS = localStretch[5];

wire pmodDebounced_n, quartzDebounced_n;
wire pmodValid, quartzValid;
reg usePMOD = 0, useQuartz = 0;

assign hwPPS_a = useQuartz ? !quartzDebounced_n :
                                               (usePMOD ? !pmodDebounced_n : 0);
assign hwOrFallbackPPS_a = (useQuartz || usePMOD) ? hwPPS_a : localPPS;

/*
 * Watch for changes in PPS status
 */
reg pmodValid_d = 0, quartzValid_d = 0;
reg pmodValidCOS = 0, quartzValidCOS = 0;
always @(posedge sysClk) begin
    quartzValid_d <= quartzValid;
    if (quartzValid_d  != quartzValid) begin
        quartzValidCOS <= 1;
    end
    else if (sysCsrStrobe && sysGPIO_OUT[8]) begin
        quartzValidCOS <= 0;
    end
    pmodValid_d <= pmodValid;
    if (pmodValid_d  != pmodValid) begin
        pmodValidCOS <= 1;
    end
    else if (sysCsrStrobe && sysGPIO_OUT[9]) begin
        pmodValidCOS <= 0;
    end
end
assign sysStatus = { 22'b0, pmodValidCOS, quartzValidCOS,
                             4'b0, usePMOD, pmodValid, useQuartz, quartzValid };
 
isPPSvalid_ #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(DEBOUNCE_NS),
    .DEBUG(DEBUG))
  isQuartzValid (
    .clk(sysClk),
    .pps_a(quartzPPS_a),
    .ppsDebounced_n(quartzDebounced_n),
    .ppsIsValid(quartzValid));

isPPSvalid_ #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(DEBOUNCE_NS),
    .DEBUG(DEBUG))
  isPMODvalid (
    .clk(sysClk),
    .pps_a(pmodPPS_a),
    .ppsDebounced_n(pmodDebounced_n),
    .ppsIsValid(pmodValid));

always @(posedge sysClk) begin
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

/*
 * Debounce and confirm validity of PPS signal.
 * Negative logic on output to ensure the absolute minimum
 * number of LUTs between the input and output signals.
 */
module isPPSvalid_ #(
    parameter CLK_RATE    = -1,
    parameter DEBOUNCE_NS = -1,
    parameter DEBUG       = "false"
    ) (
    input  wire clk,
    input  wire pps_a,
    output wire ppsDebounced_n,
    output reg  ppsIsValid = 0);

localparam DEBOUNCE_TICKS = (DEBOUNCE_NS * (CLK_RATE/1000) + 999999) / 1000000;
localparam DEBOUNCE_RELOAD = DEBOUNCE_TICKS - 2;
localparam DEBOUNCE_COUNTER_WIDTH = $clog2(DEBOUNCE_RELOAD+1) + 1;
reg [DEBOUNCE_COUNTER_WIDTH-1:0] debounceCounter = DEBOUNCE_RELOAD;
wire debounceDone = debounceCounter[DEBOUNCE_COUNTER_WIDTH-1];
(*MARK_DEBUG=DEBUG*) reg debounceDone_d = 0;

localparam PPS_TOOSLOW_RELOAD = ((CLK_RATE / 100) * 101) - 2;
localparam PPS_TOOFAST_RELOAD = ((CLK_RATE / 100) * 99) - 2;
localparam PPS_RELOAD         = CLK_RATE - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_TOOSLOW_RELOAD+1) + 1;

reg [PPS_COUNTER_WIDTH-1:0] tooSlowCounter = PPS_TOOSLOW_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooSlow = tooSlowCounter[PPS_COUNTER_WIDTH-1];
reg [PPS_COUNTER_WIDTH-1:0] tooFastCounter = PPS_TOOFAST_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooFast = !tooFastCounter[PPS_COUNTER_WIDTH-1];

wire pps_na = ~pps_a;
(*ASYNC_REG="true"*) reg ppsDebounced_nr = 1;
always @(posedge clk or posedge pps_a) begin
    if (pps_a) begin
        ppsDebounced_nr <= 0;
    end
    else begin
        if (debounceDone && !debounceDone_d) begin
            ppsDebounced_nr <= 1;
        end
    end
end
assign ppsDebounced_n = ppsDebounced_nr;

(*ASYNC_REG="TRUE"*) reg pps_m = 0;
reg pps = 0;
(*ASYNC_REG="TRUE"*) reg debounce_m = 0;
reg debounce = 0, debounce_d = 0;
always @(posedge clk) begin
    pps_m <= pps_a;
    pps   <= pps_m;
    debounceDone_d <= debounceDone;
    if (pps) begin
        debounceCounter <= DEBOUNCE_RELOAD;
    end
    else if (!debounceDone) begin
        debounceCounter <= debounceCounter - 1;
    end

    debounce_m <= !ppsDebounced_nr;
    debounce   <= debounce_m;
    debounce_d <= debounce;
    debounceDone_d <= debounceDone;
    if (debounce && !debounce_d) begin
        if (!tooFast && !tooSlow) begin
            ppsIsValid <= 1;
        end
        else begin
            ppsIsValid <= 0;
        end
        tooSlowCounter <= PPS_TOOSLOW_RELOAD;
        tooFastCounter <= PPS_TOOFAST_RELOAD;
    end
    else begin
        if (tooFast) begin
            tooFastCounter <= tooFastCounter - 1;
        end
        if (tooSlow) begin
            ppsIsValid <= 0;
        end
        else begin
            tooSlowCounter <= tooSlowCounter - 1;
        end
    end
end
endmodule
`default_nettype wire
