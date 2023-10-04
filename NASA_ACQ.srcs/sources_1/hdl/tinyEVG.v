// MIT License
//
// Copyright (c) 2106 Osprey DCS
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Core of MRF-compativble event generator
// Provides heartbeats, time stamps, arbitrary events and,
// optionally, distributed buffer.
// Nets with names beginning with 'sys' are in the system clock (sysClk) domain.

module tinyEVG #(
    parameter SECONDS_WIDTH                    = 32,
    parameter DISTRIBUTED_BUFFER_ADDRESS_WIDTH = 11,
    parameter DEBUG                            = "false"
    ) (
    // Connection to transmitter
    input  wire                     evgTxClk,
    output reg               [15:0] evgTxWord,
    output reg                [1:0] evgTxIsK,

    // Arbitrary event request
    input  wire               [7:0] eventCode,
    input  wire                     eventStrobe,

    // Heartbeat event request
    input  wire                     heartbeatRequest,

    // Time of day
    input  wire                     ppsStrobe,
    input  wire                     secondsStrobe,
    input  wire [SECONDS_WIDTH-1:0] seconds,

    // Distributed bus
    input  wire               [7:0] distributedBus,

    // Distributed buffer
    input  wire                                        sysClk,
    input  wire                                        sysSendStrobe,
    input  wire                                        sysWriteStrobe,
    input  wire [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] sysWriteAddress,
    input  wire                                  [7:0] sysWriteData,
    output reg                                         sysBufferBusy = 0);

localparam EVCODE_SHIFT_ZERO     = 8'h70;
localparam EVCODE_SHIFT_ONE      = 8'h71;
localparam EVCODE_HEARTBEAT      = 8'h7A;
localparam EVCODE_SECONDS_MARKER = 8'h7D;
localparam EVCODE_K28_0          = 8'h1C;
localparam EVCODE_K28_1          = 8'h3C;
localparam EVCODE_K28_5          = 8'hBC;

// Dual-port RAM
reg [7:0] dpram[0:(1 << DISTRIBUTED_BUFFER_ADDRESS_WIDTH) - 1], dpramQ;
reg sendMatch = 0;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg sysSendToggle = 0;
(* ASYNC_REG = "true" *) reg sysSendMatch_m = 0;
reg sysSendMatch = 0;
reg [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] sysLastAddress;
always @(posedge sysClk) begin
    if (sysWriteStrobe) begin
        dpram[sysWriteAddress] <= sysWriteData;
        sysLastAddress <= sysWriteAddress;
    end
    sysSendMatch_m <= sendMatch;
    sysSendMatch   <= sysSendMatch_m;
    if (sysBufferBusy) begin
        if (sysSendMatch == sysSendToggle) begin
            sysBufferBusy <= 0;
        end
    end
    else if (sysSendStrobe) begin
        sysSendToggle <= !sysSendToggle;
        sysBufferBusy <= 1;
    end
end

///////////////////////////////////////////////////////////////////////////////
// Event generator clock domain
(*MARK_DEBUG=DEBUG*) reg ppsPending = 0, haveSeconds = 0, sentSeconds = 0;
(*MARK_DEBUG=DEBUG*) reg [SECONDS_WIDTH-1:0] secondsReg;
reg [SECONDS_WIDTH-1:0] secondsShiftReg;
reg [$clog2(SECONDS_WIDTH):0] secondsBitCount = ~0;
wire secondsBitCountDone = secondsBitCount[$clog2(SECONDS_WIDTH)];
reg secondsBitCountDone_d = 1;
reg [2:0] secondsGap = 0;
reg [2:0] commaGap = 0;
(* ASYNC_REG = "true" *) reg sendToggle_m;
reg sendToggle = 0;
reg bufferBusy;

// Buffer transmission state machine
localparam S_START  = 3'd0,
           S_DATA   = 3'd1,
           S_STOP   = 3'd2,
           S_CHK_HI = 3'd3,
           S_CHK_LO = 3'd4;
reg [2:0] bufferState = S_START;
reg [DISTRIBUTED_BUFFER_ADDRESS_WIDTH-1:0] bufferAddress;
reg [DISTRIBUTED_BUFFER_ADDRESS_WIDTH:0] bufferCounter = 0;
wire bufferCounterDone = bufferCounter[DISTRIBUTED_BUFFER_ADDRESS_WIDTH];
reg [15:0] bufferChecksum;

always @(posedge evgTxClk) begin
    // Timer housekeeping
    if (!secondsGap[2]) secondsGap <= secondsGap - 1;
    commaGap <= commaGap[2] ? 2 : commaGap - 1;

    // Update the time of day
    if (secondsStrobe) begin
        secondsReg <= seconds;
        haveSeconds <= 1;
    end
    else if (ppsStrobe) begin
        secondsReg <= secondsReg + 1;
    end

    // Make note of a PPS request
    if (ppsStrobe) begin
        if (!ppsPending) begin
            ppsPending <= 1;
        end
    end
    secondsBitCountDone_d <= secondsBitCountDone;
    if (secondsBitCountDone && !secondsBitCountDone_d) begin
        sentSeconds <= 1;
    end

    // Send events in priority order
    // Arbitrary event request
    if (eventStrobe) begin
        evgTxWord[7:0] <= eventCode;
        evgTxIsK[0] <= 0;
    end
    // Then heartbeats -- may be inhibited by FIFO event, but never delayed.
    else if (heartbeatRequest) begin
        evgTxWord[7:0] <= EVCODE_HEARTBEAT;
        evgTxIsK[0] <= 0;
    end
    // Then PPS markers (which could be delayed by an arbitrary amount).
    // Best practice is to ensure gap between arbitrary event requests
    else if (ppsPending) begin
        ppsPending <= 0;
        secondsGap <= 3;
        if (sentSeconds) begin
            evgTxWord[7:0] <= EVCODE_SECONDS_MARKER;
            evgTxIsK[0] <= 0;
        end
        else begin
            evgTxWord[7:0] <= 0;
            evgTxIsK[0] <= 0;
        end
        if (haveSeconds) begin
            secondsBitCount <= SECONDS_WIDTH - 1;
            secondsShiftReg <= secondsReg;
        end
    end
    // Lowest priorty -- POSIX seconds shift register
    else if (!secondsBitCountDone && secondsGap[2]) begin
        secondsBitCount <= secondsBitCount - 1;
        secondsGap <= 3;
        secondsShiftReg <= { secondsShiftReg[0+:SECONDS_WIDTH-1], 1'b0 };
        evgTxWord[7:0] <= secondsShiftReg[SECONDS_WIDTH-1] ? EVCODE_SHIFT_ONE :
                                                             EVCODE_SHIFT_ZERO;
        evgTxIsK[0] <= 0;
    end
    else if (commaGap[2]) begin
        evgTxWord[7:0] <= EVCODE_K28_5;
        evgTxIsK[0] <= 1;
    end
    else begin
        evgTxWord[7:0] <= 0;
        evgTxIsK[0] <= 0;
    end

    // Distributed data buffer
    sendToggle_m <= sysSendToggle;
    sendToggle   <= sendToggle_m;
    dpramQ <= dpram[bufferAddress];
    if (bufferBusy) begin
        if (!commaGap[0]) begin
            case (bufferState)
            S_START: begin
                evgTxWord[15:8] <= EVCODE_K28_0;
                evgTxIsK[1] <= 1;
                bufferChecksum <= 0;
                bufferAddress <= 0;
                bufferState <= S_DATA;
            end
            S_DATA: begin
                evgTxWord[15:8] <= dpramQ;
                evgTxIsK[1] <= 0;
                bufferChecksum <= bufferChecksum + dpramQ;
                bufferAddress <= bufferAddress + 1;
                bufferCounter <= bufferCounter - 1;
                if (bufferCounterDone) begin
                    bufferState <= S_STOP;
                end
            end
            S_STOP: begin
                bufferChecksum <= ~bufferChecksum;
                evgTxWord[15:8] <= EVCODE_K28_1;
                evgTxIsK[1] <= 1;
                bufferState <= S_CHK_HI;
            end
            S_CHK_HI: begin
                evgTxWord[15:8] <= bufferChecksum[15:8];
                evgTxIsK[1] <= 0;
                bufferState <= S_CHK_LO;
            end
            S_CHK_LO: begin
                evgTxWord[15:8] <= bufferChecksum[7:0];
                evgTxIsK[1] <= 0;
                bufferBusy <= 0;
                sendMatch <= !sendMatch;
            end
            default: ;
            endcase
        end
        else begin
            evgTxWord[15:8] <= distributedBus;
            evgTxIsK[1] <= 0;
        end
    end
    else begin
        evgTxWord[15:8] <= distributedBus;
        evgTxIsK[1] <= 0;
        bufferState <= S_START;
        if (sendToggle != sendMatch) begin
            bufferCounter <= {1'b0, sysLastAddress} - 1;
            bufferBusy <= 1;
        end
    end
end

endmodule
