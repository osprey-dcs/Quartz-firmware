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
 * Simple logic analyzer recording of AD7768 DCLK and DRDY lines.
 * Trigger is rising edge of first DRDY line or lines.
 * No pretrigger samples, but we know that the sample before the first must
 * have all DRDY lines low
 */
`default_nettype none
module ad7768recorder #(
    parameter ADC_CHIP_COUNT = 1,
    parameter SAMPLE_COUNT   = 131072,
    parameter DEBUG          = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input  wire                      acqClk,
    input  wire [ADC_CHIP_COUNT-1:0] adcDCLK_a,
    input  wire [ADC_CHIP_COUNT-1:0] adcDRDY_a);

localparam ADDRESS_WIDTH = $clog2(SAMPLE_COUNT);

//
// Simple dual-port RAM
//
reg [(2*ADC_CHIP_COUNT)-1:0] dpram [0:SAMPLE_COUNT-1];

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain
///////////////////////////////////////////////////////////////////////////////

reg sysStartAcquisitionToggle = 0;
reg [ADDRESS_WIDTH-1:0] sysReadAddress;
reg [(2*ADC_CHIP_COUNT)-1:0] sysReadQ;

always @(posedge sysClk) begin
    sysReadQ <= dpram[sysReadAddress];
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[31]) begin
            sysStartAcquisitionToggle <= !sysStartAcquisitionToggle;
        end
        sysReadAddress <= sysGPIO_OUT[ADDRESS_WIDTH-1:0];
    end
end

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock (acqClk) domain
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Get asynchronous DCLK and DRDY into acquisition clock domain.
// Use delayed synchronized value to sample first DRDY and all data lines.
(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] dclk_m = 0, drdy_m = 0;
(*MARK_DEBUG=DEBUG*) reg [ADC_CHIP_COUNT-1:0] drdy = 0, dclk = 0;

always @(posedge acqClk) begin
    dclk_m <= adcDCLK_a;
    dclk   <= dclk_m;
    drdy_m <= adcDRDY_a;
    drdy   <= drdy_m;
end

// Waveform recorder
localparam [2:0] ST_STATE_IDLE         = 2'd0,
                 ST_STATE_AWAIT_LOW    = 2'd1,
                 ST_STATE_AWAIT_RISING = 2'd2,
                 ST_STATE_ACTIVE       = 2'd3;
(*MARK_DEBUG=DEBUG*) reg [1:0] acqState = ST_STATE_IDLE;
reg acqAcquisitionActive = 0;
reg [ADDRESS_WIDTH-1:0] acqWriteAddress = 0;

(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] acqStartAcquisitionToggle_m = 0;
reg acqStartAcquisitionToggle = 0, acqStartAcquisitionMatch = 0;

always @(posedge acqClk) begin
    acqStartAcquisitionToggle_m <= sysStartAcquisitionToggle;
    acqStartAcquisitionToggle   <= acqStartAcquisitionToggle_m;
    if (acqAcquisitionActive) begin
        dpram[acqWriteAddress] <= {dclk, drdy};
    end

    case (acqState)
    ST_STATE_IDLE: begin
        acqWriteAddress <= 0;
        if (acqStartAcquisitionToggle != acqStartAcquisitionMatch) begin
            acqStartAcquisitionMatch <= acqStartAcquisitionToggle;
            acqAcquisitionActive <= 1;
            acqState <= ST_STATE_AWAIT_LOW;
        end
    end
    ST_STATE_AWAIT_LOW: begin
        if (drdy == 0) begin
            acqState <= ST_STATE_AWAIT_RISING;
        end
    end
    ST_STATE_AWAIT_RISING: begin
        if (drdy != 0) begin
            acqWriteAddress <= acqWriteAddress + 1;
            acqState <= ST_STATE_ACTIVE;
        end
    end
    ST_STATE_ACTIVE: begin
        acqWriteAddress <= acqWriteAddress + 1;
        if (acqWriteAddress == {ADDRESS_WIDTH{1'b1}}) begin
            acqAcquisitionActive <= 0;
            acqState <= ST_STATE_IDLE;
        end
    end
    default: ;
    endcase
end

// Some values in acquisition clock domain, but races unimportant
assign sysStatus = { acqAcquisitionActive,
                     {32-1-(2*ADC_CHIP_COUNT){1'b0}},
                     sysReadQ };

endmodule
`default_nettype wire
