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
 * Event generator sequencer
 */

`default_nettype none

module ospreyEVGsequencer #(
    parameter SEQRAM_ADDR_WIDTH = 12,
    parameter DEBUG             = "false"
    ) (
    input  wire        sysClk,
    input  wire [31:0] sysWriteData,
    input  wire        sysWriteStrobe,
    output wire [31:0] sysStatus,

                         input  wire        evgClk,
                         input  wire        trigger,
    (*MARK_DEBUG=DEBUG*) output reg   [7:0] eventCode = 0,
    (*MARK_DEBUG=DEBUG*) output reg         eventCodeTVALID = 0);

localparam SEQRAM_WIDTH = 36;
localparam EVENT_CODE_WIDTH = 8;
localparam COARSE_DELAY_SHIFT = 6;
localparam EVENT_CODE_END_OF_SEQUENCE = {EVENT_CODE_WIDTH{1'b1}};
localparam SEQDELAY_WIDTH = SEQRAM_WIDTH - EVENT_CODE_WIDTH;

// Dual-port sequence RAM
reg [SEQRAM_WIDTH-1:0] seqram [0:(1<<SEQRAM_ADDR_WIDTH)-1];
(*MARK_DEBUG=DEBUG*) reg [SEQRAM_WIDTH-1:0] seqramQ;

///////////////////////////////////////////////////////////////////////////////
// System clock domain

localparam OP_CONTROL      = 2'd0,
           OP_LATCH_DELAY  = 2'd1,
           OP_WRITE_RAM    = 2'd2;

// Control actions
reg sysArmToggle = 0, sysCancelToggle = 0, sysTriggerToggle = 0;

// Extract values from write data
wire                   [1:0] sysOpcode = sysWriteData[31:30];
wire  [EVENT_CODE_WIDTH-1:0] sysWriteEvent = sysWriteData[0+:EVENT_CODE_WIDTH];
wire [SEQRAM_ADDR_WIDTH-1:0] sysWriteAddress =
                              sysWriteData[EVENT_CODE_WIDTH+:SEQRAM_ADDR_WIDTH];
reg     [SEQDELAY_WIDTH-1:0] sysDelayLatch;

always @(posedge sysClk) begin
    if (sysWriteStrobe) begin
        case (sysOpcode)
        OP_CONTROL: begin
            if (sysWriteData[0]) begin
                sysArmToggle <= !sysArmToggle;
            end
            if (sysWriteData[1]) begin
                sysCancelToggle <= !sysCancelToggle;
            end
            if (sysWriteData[2]) begin
                sysTriggerToggle <= !sysTriggerToggle;
            end
        end
        OP_LATCH_DELAY: begin
            sysDelayLatch <= sysWriteData[SEQDELAY_WIDTH-1:0];
        end
        OP_WRITE_RAM: begin
            seqram[sysWriteAddress] <= {sysWriteEvent, sysDelayLatch};
        end
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
// Event generator clock domain

// Extract values from dual-port RAM read register
localparam SEQCOUNT_WIDTH = SEQDELAY_WIDTH - 1;
wire [SEQDELAY_WIDTH-2:0] seqCount = seqramQ[SEQDELAY_WIDTH-2:0];
wire seqCountIsCoarse = seqramQ[SEQDELAY_WIDTH-1];
wire [EVENT_CODE_WIDTH-1:0] seqCode = seqramQ[SEQDELAY_WIDTH+:EVENT_CODE_WIDTH];
reg  [EVENT_CODE_WIDTH-1:0] eventCodePending = 0;

localparam DELAY_COUNTER_WIDTH = 1 + SEQCOUNT_WIDTH + COARSE_DELAY_SHIFT;
(*MARK_DEBUG=DEBUG*) reg [DELAY_COUNTER_WIDTH-1:0] delayCounter;
(*MARK_DEBUG=DEBUG*)wire delayCounterDone = delayCounter[DELAY_COUNTER_WIDTH-1];

(*ASYNC_REG="true"*) reg armToggle_m = 0;
reg armToggle = 0, armToggle_d = 0;

(*ASYNC_REG="true"*) reg cancelToggle_m = 0;
reg cancelToggle = 0, cancelToggle_d = 0;

(*ASYNC_REG="true"*) reg swTriggerToggle_m = 0;
reg swTriggerToggle = 0, swTriggerToggle_d = 0;

(*MARK_DEBUG=DEBUG*) reg [SEQRAM_ADDR_WIDTH-1:0] rAddr;

(*MARK_DEBUG=DEBUG*) reg armed = 0;
(*MARK_DEBUG=DEBUG*) reg active = 0;

always @(posedge evgClk) begin
    /*
     * Housekeeping
     */
    armToggle_m <= sysArmToggle;
    armToggle   <= armToggle_m;
    armToggle_d <= armToggle;
    cancelToggle_m <= sysCancelToggle;
    cancelToggle   <= cancelToggle_m;
    cancelToggle_d <= cancelToggle;
    swTriggerToggle_m <= sysTriggerToggle;
    swTriggerToggle   <= swTriggerToggle_m;
    swTriggerToggle_d <= swTriggerToggle;

    /*
     * Sequencer
     */
    if (delayCounterDone) begin
        seqramQ <= seqram[rAddr];
    end
    if (cancelToggle != cancelToggle_d) begin
        eventCodeTVALID <= 0;
        armed <= 0;
        active <= 0;
    end
    else if (!active) begin
        eventCodeTVALID <= 0;
        eventCodePending <= 0;
        delayCounter <= {DELAY_COUNTER_WIDTH{1'b1}};
        if (armed && (trigger || (swTriggerToggle != swTriggerToggle_d))) begin
            rAddr <= 1;
            active <= 1;
        end
        else begin
            rAddr <= 0;
            if (armToggle != armToggle_d) begin
                armed <= 1;
            end
        end
    end
    else if (delayCounterDone) begin
        armed <= 0;
        eventCode <= eventCodePending;
        if (eventCodePending == EVENT_CODE_END_OF_SEQUENCE) begin
            eventCodeTVALID <= 0;
            active <= 0;
        end
        else begin
            if (eventCodePending == 0) begin
                eventCodeTVALID <= 0;
            end
            else begin
                eventCodeTVALID <= 1;
            end
            eventCodePending <= seqCode;
            delayCounter <= (seqCountIsCoarse ?
                              {1'b0, seqCount, {COARSE_DELAY_SHIFT{1'b0}}} :
                              {1'b0, {COARSE_DELAY_SHIFT{1'b0}}, seqCount}) - 1;
            rAddr <= rAddr + 1;
        end
    end
    else begin
        eventCodeTVALID <= 0;
        delayCounter <= delayCounter - 1;
    end
end

// Simple status bits need no fancy clock-crossing logic
assign sysStatus = { {30{1'b0}}, active, armed };

endmodule
`default_nettype wire
