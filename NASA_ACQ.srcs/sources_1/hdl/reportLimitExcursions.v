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

/*
 * Stretch ADC values beyond thresholds to user-visible range
 */
`default_nettype none
module reportLimitExcursions #(
    parameter INPUT_COUNT = 4 * 32,
    parameter DEBUG       = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

                        input  wire                   acqClk,
    (*MARK_DEBUG=DEBUG*)input  wire [INPUT_COUNT-1:0] acqLimitExcursions,
    (*MARK_DEBUG=DEBUG*)input  wire                   acqLimitExcursionsTVALID);

//////////////////////////////////////////////////////////////////////////////
// System clock domain

localparam MUXSEL_WIDTH = $clog2(INPUT_COUNT / 32);

/* Used in acquisition clock domain, but known to be stable */
(*MARK_DEBUG=DEBUG*) reg [MUXSEL_WIDTH-1:0] muxSel = 0;

/* Set in acquisition clock domain, but known to be stable */
(*MARK_DEBUG=DEBUG*) reg [31:0] muxOut;
assign sysStatus = muxOut;

reg sysReadoutToggle = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        /*
         * The LOLO limit excursions are in the most significant
         * bits of acqLimitExcursions so invert the address so
         * that LOLO is selected when 2'b00 is written,
         * LO when 2'b01 is written and so on.
         */
        muxSel <= ~sysGPIO_OUT[MUXSEL_WIDTH-1:0];
        sysReadoutToggle <= !sysReadoutToggle;
    end
end

//////////////////////////////////////////////////////////////////////////////
// Acquisition clock domain

(*ASYNC_REG="true"*) reg acqReadoutToggle_m = 0;
reg acqReadoutToggle = 0, acqReadoutToggle_d = 0;
(*MARK_DEBUG=DEBUG*) reg acqReadoutStrobe = 0;

(*MARK_DEBUG=DEBUG*) reg [INPUT_COUNT-1:0] latch = 0;

always @(posedge acqClk) begin
    acqReadoutToggle_m <= sysReadoutToggle;
    acqReadoutToggle   <= acqReadoutToggle_m;
    acqReadoutToggle_d <= acqReadoutToggle;
    acqReadoutStrobe <= (acqReadoutToggle != acqReadoutToggle_d);
    if (acqReadoutStrobe) begin
        muxOut <= latch[muxSel*32+:32];
        if (acqLimitExcursionsTVALID) begin
            latch[muxSel*32+:32] <= acqLimitExcursions[muxSel*32+:32];
        end
        else begin
            latch[muxSel*32+:32] <= 0;
        end
    end
    else if (acqLimitExcursionsTVALID) begin
        latch <= latch | acqLimitExcursions;
    end
end

endmodule
`default_nettype wire
