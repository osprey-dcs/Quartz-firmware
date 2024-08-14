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
 * Trigger on misalignment of DRDY lines.
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
    input  wire                      adcMCLK_a,
    input  wire [ADC_CHIP_COUNT-1:0] adcDCLK_a,
    input  wire [ADC_CHIP_COUNT-1:0] adcDRDY_a,
    
    output wire                      acqDCLKshifted,
    output wire                      acqMisalignedMarker);

localparam DATA_WIDTH         = 1 + (2 * ADC_CHIP_COUNT);
localparam ADDRESS_WIDTH      = $clog2(SAMPLE_COUNT);
localparam POST_TRIGGER_COUNT = SAMPLE_COUNT / 8;
localparam TRIGGER_THRESHOLD  = 3;

//
// Simple dual-port RAM
//
reg [DATA_WIDTH-1:0] dpram [0:SAMPLE_COUNT-1];

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain
///////////////////////////////////////////////////////////////////////////////

reg sysArmToggle = 0;
reg [ADDRESS_WIDTH-1:0] sysReadAddress;
reg [DATA_WIDTH-1:0] sysReadQ;

always @(posedge sysClk) begin
    sysReadQ <= dpram[sysReadAddress];
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[31]) begin
            sysArmToggle <= !sysArmToggle;
        end
        sysReadAddress <= sysGPIO_OUT[ADDRESS_WIDTH-1:0];
    end
end

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock (acqClk) domain
///////////////////////////////////////////////////////////////////////////////

// Get asynchronous DCLK and DRDY into acquisition clock domain.
// Use delayed synchronized value to sample first DRDY and all data lines.
(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] mclk_m=0, dclk_m=0, drdy_m=0;
(*MARK_DEBUG=DEBUG*) reg [ADC_CHIP_COUNT-1:0] mclk = 0, drdy = 0, dclk = 0;

always @(posedge acqClk) begin
    mclk_m <= adcMCLK_a;
    mclk   <= mclk_m;
    dclk_m <= adcDCLK_a;
    dclk   <= dclk_m;
    drdy_m <= adcDRDY_a;
    drdy   <= drdy_m;
end

// Waveform recorder
localparam [2:0] ST_IDLE          = 2'd0,
                 ST_FILL          = 2'd1,
                 ST_AWAIT_TRIGGER = 2'd2,
                 ST_POST_TRIGGER  = 2'd3;
(*MARK_DEBUG=DEBUG*) reg [1:0] acqState = ST_IDLE;
reg acqAcquisitionActive = 0;
reg [ADDRESS_WIDTH-1:0] acqWriteAddress = 0;

localparam PRE_TRIGGER_LOAD = (SAMPLE_COUNT - POST_TRIGGER_COUNT) - 2;
localparam PRE_TRIGGER_COUNTER_WIDTH = $clog2(PRE_TRIGGER_LOAD+1) + 1;
(*MARK_DEBUG=DEBUG*)
reg [PRE_TRIGGER_COUNTER_WIDTH-1:0] preTriggerCounter = PRE_TRIGGER_LOAD;
wire preTriggerDone = preTriggerCounter[PRE_TRIGGER_COUNTER_WIDTH-1];

localparam POST_TRIGGER_LOAD = (POST_TRIGGER_COUNT - TRIGGER_THRESHOLD) - 2;
localparam POST_TRIGGER_COUNTER_WIDTH = $clog2(POST_TRIGGER_LOAD+1) + 1;
(*MARK_DEBUG=DEBUG*)
reg [POST_TRIGGER_COUNTER_WIDTH-1:0] postTriggerCounter = POST_TRIGGER_LOAD;
wire postTriggerDone = postTriggerCounter[POST_TRIGGER_COUNTER_WIDTH-1];

localparam MISALIGN_COUNT_LOAD = TRIGGER_THRESHOLD - 2;
localparam MISALIGN_COUNTER_WIDTH = $clog2(MISALIGN_COUNT_LOAD+1) + 1;
(*MARK_DEBUG=DEBUG*)
reg [MISALIGN_COUNTER_WIDTH-1:0] misalignCount = MISALIGN_COUNT_LOAD;
wire misalignCountDone = misalignCount[MISALIGN_COUNTER_WIDTH-1];

localparam STRETCH_COUNTER_WIDTH = 8;
(*MARK_DEBUG=DEBUG*) reg [STRETCH_COUNTER_WIDTH-1:0] stretchCounter = 0;
assign acqMisalignedMarker = stretchCounter[STRETCH_COUNTER_WIDTH-1];

reg [1:0] dclkShiftCount = 0;
assign acqDCLKshifted = dclkShiftCount[1];

(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] acqArmToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg acqArmToggle = 0, acqArmToggle_d = 0;

always @(posedge acqClk) begin
    acqArmToggle_m <= sysArmToggle;
    acqArmToggle   <= acqArmToggle_m;
    acqArmToggle_d <= acqArmToggle;
    if (acqAcquisitionActive) begin
        dpram[acqWriteAddress] <= {mclk, dclk, drdy};
        acqWriteAddress <= acqWriteAddress + 1;
    end

    if ((dclk == {ADC_CHIP_COUNT{1'b0}})
     || (dclk == {ADC_CHIP_COUNT{1'b1}})) begin
        dclkShiftCount <= 0;
    end
    else if (!acqDCLKshifted) begin
        dclkShiftCount <= dclkShiftCount + 1;
    end

    if ((drdy == {ADC_CHIP_COUNT{1'b0}})
     || (drdy == {ADC_CHIP_COUNT{1'b1}})) begin
        misalignCount <= MISALIGN_COUNT_LOAD;
        if (acqMisalignedMarker) begin
            stretchCounter <= stretchCounter - 1;
        end
    end
    else begin
        misalignCount <= misalignCount - 1;
        if (misalignCountDone) begin
            stretchCounter <= ~0;
        end
        else if (acqMisalignedMarker) begin
            stretchCounter <= stretchCounter - 1;
        end
    end

    case (acqState)
    ST_IDLE: begin
        preTriggerCounter <= PRE_TRIGGER_LOAD;
        postTriggerCounter <= POST_TRIGGER_LOAD;
        misalignCount <= MISALIGN_COUNT_LOAD;
        if (acqArmToggle != acqArmToggle_d) begin
            acqAcquisitionActive <= 1;
            acqState <= ST_FILL;
        end
    end
    ST_FILL: begin
        preTriggerCounter <= preTriggerCounter - 1;
        if (preTriggerDone) begin
            acqState <= ST_AWAIT_TRIGGER;
        end
    end
    ST_AWAIT_TRIGGER: begin
        if (acqMisalignedMarker || (acqArmToggle != acqArmToggle_d)) begin
            acqState <= ST_POST_TRIGGER;
        end
    end
    ST_POST_TRIGGER: begin
        postTriggerCounter <= postTriggerCounter - 1;
        if (postTriggerDone) begin
            acqAcquisitionActive <= 0;
            acqState <= ST_IDLE;
        end
    end
    default: ;
    endcase
end

// Some values in acquisition clock domain, but races unimportant
assign sysStatus = { acqAcquisitionActive,
                     {32-1-ADDRESS_WIDTH-DATA_WIDTH{1'b0}},
                     acqWriteAddress,
                     sysReadQ };

endmodule
`default_nettype wire
