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
 * Package and send ADC readings
 */
`default_nettype none
module buildPacket #(
    parameter ADC_CHIP_COUNT      = 4,
    parameter ADC_PER_CHIP        = 8,
    parameter ADC_WIDTH           = 24,
    parameter UDP_PACKET_CAPACITY = 1472,
    parameter ACQ_CLK_RATE        = 125000000,
    parameter DEBUG               = "false",
    parameter DEBUG_MERGE_LIMITS  = "false",
    parameter DEBUG_REPORT_LIMITS = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysActiveBitmapStrobe,
    input  wire        sysByteCountStrobe,
    input  wire        sysThresholdStrobe,
    input  wire        sysLimitExcursionStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysActiveRbk,
    output wire [31:0] sysByteCountRbk,
    output wire [31:0] sysThresholdRbk,
    output wire [31:0] sysLimitExcursions,
    output wire [31:0] sysSequenceNumber,
    input  wire        sysTimeValid,

    input  wire                                               acqClk,
    input  wire                                               acqStrobe,
    input  wire [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData,
    output wire         [(4*ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0]acqLimitExcursions,

    input  wire [31:0] acqSeconds,
    input  wire [31:0] acqTicks,
    input  wire        acqClkLocked,
    input  wire        acqEnableAcquisition,

    output wire       M_TVALID,
    output wire       M_TLAST,
    output wire [7:0] M_TDATA,
    input  wire       M_TREADY);

localparam LIMIT_EXCURSION_WIDTH = 4 * ADC_CHIP_COUNT * ADC_PER_CHIP;
wire [LIMIT_EXCURSION_WIDTH-1:0] packetLimitExcursions;
wire       rawPacketTVALID, rawPacketTLAST, rawPacketTREADY;
wire [7:0] rawPacketTDATA;

//
// Instantiate the core packet builder
//
buildPacketCore #(
    .ADC_CHIP_COUNT(ADC_CHIP_COUNT),
    .ADC_PER_CHIP(ADC_PER_CHIP),
    .ADC_WIDTH(ADC_WIDTH),
    .UDP_PACKET_CAPACITY(UDP_PACKET_CAPACITY),
    .DEBUG(DEBUG))
  buildPacketCore (
    .sysClk(sysClk),
    .sysActiveBitmapStrobe(sysActiveBitmapStrobe),
    .sysByteCountStrobe(sysByteCountStrobe),
    .sysThresholdStrobe(sysThresholdStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .sysActiveRbk(sysActiveRbk),
    .sysByteCountRbk(sysByteCountRbk),
    .sysThresholdRbk(sysThresholdRbk),
    .sysSequenceNumber(sysSequenceNumber),
    .sysTimeValid(sysTimeValid),
    .acqClk(acqClk),
    .acqStrobe(acqStrobe),
    .acqData(acqData),
    .acqLimitExcursions(acqLimitExcursions),
    .acqSeconds(acqSeconds),
    .acqTicks(acqTicks),
    .acqClkLocked(acqClkLocked),
    .acqEnableAcquisition(acqEnableAcquisition),
    .M_TVALID(rawPacketTVALID),
    .M_TLAST(rawPacketTLAST),
    .M_TDATA(rawPacketTDATA),
    .packetLimitExcursions(packetLimitExcursions),
    .M_TREADY(rawPacketTREADY));

//
// Merge ADC limit excursions into packet data stream
//
mergeLimitExcursions #(
    .BITMAPS_WIDTH(LIMIT_EXCURSION_WIDTH),
    .DEBUG(DEBUG_MERGE_LIMITS))
  mergeLimitExcursions (
    .clk(acqClk),
    .S_TVALID(rawPacketTVALID),
    .S_TLAST(rawPacketTLAST),
    .S_TDATA(rawPacketTDATA),
    .S_TREADY(rawPacketTREADY),
    .packetLimitExcursions(packetLimitExcursions),
    .M_TVALID(M_TVALID),
    .M_TLAST(M_TLAST),
    .M_TDATA(M_TDATA),
    .M_TREADY(M_TREADY));

//
// Latch ADC excursions until read
//
reportLimitExcursions #(
    .INPUT_COUNT(LIMIT_EXCURSION_WIDTH),
    .DEBUG(DEBUG_REPORT_LIMITS))
  reportLimitExcursions_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysLimitExcursionStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysLimitExcursions),
    .acqClk(acqClk),
    .acqLimitExcursions(acqLimitExcursions),
    .acqLimitExcursionsTVALID(acqStrobe));
endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//
// Emit stream containing packet minus the excursion limits.
// Emit packet excursion limits with last byte of packet.
//
module buildPacketCore #(
    parameter ADC_CHIP_COUNT      = 4,
    parameter ADC_PER_CHIP        = 8,
    parameter ADC_WIDTH           = 24,
    parameter UDP_PACKET_CAPACITY = 1472,
    parameter DEBUG               = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysActiveBitmapStrobe,
    input  wire        sysByteCountStrobe,
    input  wire        sysThresholdStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysActiveRbk,
    output wire [31:0] sysByteCountRbk,
    output reg  [31:0] sysThresholdRbk,
    output wire [31:0] sysSequenceNumber,
    input  wire        sysTimeValid,

                         input  wire                          acqClk,
    (*MARK_DEBUG=DEBUG*) input  wire                          acqStrobe,
    input  wire [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData,
    (*MARK_DEBUG=DEBUG*) output wire [(4*ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0]
                                                             acqLimitExcursions,

    (*MARK_DEBUG=DEBUG*) input  wire [31:0] acqSeconds,
    (*MARK_DEBUG=DEBUG*) input  wire [31:0] acqTicks,
    (*MARK_DEBUG=DEBUG*) input  wire        acqClkLocked,
    (*MARK_DEBUG=DEBUG*) input  wire        acqEnableAcquisition,

    (*MARK_DEBUG=DEBUG*) output reg        M_TVALID = 0,
    (*MARK_DEBUG=DEBUG*) output reg        M_TLAST = 0,
    (*MARK_DEBUG=DEBUG*) output reg  [7:0] M_TDATA,
    (*MARK_DEBUG=DEBUG*) output reg [(4*ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0]
                                           packetLimitExcursions = 0,
    (*MARK_DEBUG=DEBUG*) input  wire       M_TREADY);

localparam BYTES_PER_ADC = (ADC_WIDTH + 7) / 8;

localparam ADC_COUNT = ADC_CHIP_COUNT * ADC_PER_CHIP;
localparam ADC_SHIFT_COUNT = ADC_COUNT * BYTES_PER_ADC;
localparam ADC_SHIFT_COUNTER_LOAD = ADC_SHIFT_COUNT - 1;
localparam ADC_SHIFT_COUNTER_WIDTH = $clog2(ADC_SHIFT_COUNTER_LOAD+1) + 1;
localparam ADC_SEL_WIDTH = $clog2(ADC_COUNT);

localparam HEADER_BYTE_COUNT = 8 * 4;
localparam HEADER_SHIFT_COUNTER_LOAD = HEADER_BYTE_COUNT - 1;
localparam HEADER_SHIFT_COUNTER_WIDTH = $clog2(HEADER_SHIFT_COUNTER_LOAD+1) + 1;

localparam BYTECOUNT_WIDTH = $clog2(UDP_PACKET_CAPACITY-HEADER_BYTE_COUNT+1);
localparam BYTECOUNTER_WIDTH = BYTECOUNT_WIDTH + 1;

// Support for forwarding values from one clock domain to another
localparam FORWARD_DATA_WIDTH = 1 + BYTECOUNT_WIDTH + ADC_COUNT;
reg sysForwardToggle = 0, acqForwardToggle = 0;
(*ASYNC_REG="true"*) reg sysAcqForwardToggle_m = 0, acqSysForwardToggle_m = 0;
reg sysAcqForwardToggle = 0, acqSysForwardToggle = 0;
reg [FORWARD_DATA_WIDTH-1:0] sysForwardData, acqForwardData;

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain

reg [ADC_COUNT-1:0] sysActiveChannels = ~0;
reg [BYTECOUNT_WIDTH-1:0] sysByteCount = 1400;
reg sysSubscriberPresent = 0;
reg sysIsCalibrated = 0;

wire [ADC_SEL_WIDTH-1:0] sysADCsel = sysGPIO_OUT[ADC_WIDTH+:ADC_SEL_WIDTH];
reg signed [ADC_WIDTH-1:0] sysThresholdLOLO [0:ADC_COUNT-1];
reg signed [ADC_WIDTH-1:0] sysThresholdLO   [0:ADC_COUNT-1];
reg signed [ADC_WIDTH-1:0] sysThresholdHI   [0:ADC_COUNT-1];
reg signed [ADC_WIDTH-1:0] sysThresholdHIHI [0:ADC_COUNT-1];
// Two-level multiplexer to make it easier to meet timing
reg [(4*ADC_WIDTH)-1:0] sysThresholdRbkMux0;
reg [ADC_SEL_WIDTH-1:0] sysThresholdRbkADCsel;
reg               [1:0] sysThresholdRbkSel;

always @(posedge sysClk) begin
    if (sysActiveBitmapStrobe) begin
        sysActiveChannels <= sysGPIO_OUT[0+:ADC_COUNT];
    end
    if (sysByteCountStrobe) begin
        if (sysGPIO_OUT[16]) sysByteCount <= sysGPIO_OUT[0+:BYTECOUNT_WIDTH];
        if (sysGPIO_OUT[24]) begin
            sysIsCalibrated <= 0;
        end
        else if (sysGPIO_OUT[25]) begin
            sysIsCalibrated <= 1;
        end
        if (sysGPIO_OUT[30]) begin
            sysSubscriberPresent <= 0;
        end
        else if (sysGPIO_OUT[31]) begin
            sysSubscriberPresent <= 1;
        end
    end
    if (sysThresholdStrobe) begin
        sysThresholdRbkADCsel <= sysADCsel;
        sysThresholdRbkSel <= sysGPIO_OUT[31:30];
        if (sysGPIO_OUT[29]) begin
            case (sysGPIO_OUT[31:30])
            2'b00:  sysThresholdLOLO[sysADCsel] <= sysGPIO_OUT[ADC_WIDTH-1:0];
            2'b01:  sysThresholdLO  [sysADCsel] <= sysGPIO_OUT[ADC_WIDTH-1:0];
            2'b10:  sysThresholdHI  [sysADCsel] <= sysGPIO_OUT[ADC_WIDTH-1:0];
            2'b11:  sysThresholdHIHI[sysADCsel] <= sysGPIO_OUT[ADC_WIDTH-1:0];
            endcase
        end
    end

    // Forward values to ACQ clock domain
    sysAcqForwardToggle_m <= acqForwardToggle;
    sysAcqForwardToggle   <= sysAcqForwardToggle_m;
    if (sysForwardToggle == sysAcqForwardToggle) begin
        sysForwardData <= {sysSubscriberPresent,sysByteCount,sysActiveChannels};
        sysForwardToggle <= !sysForwardToggle;
    end

    // Threshold readback
    sysThresholdRbkMux0 <= { sysThresholdHIHI[sysThresholdRbkADCsel],
                             sysThresholdHI  [sysThresholdRbkADCsel],
                             sysThresholdLO  [sysThresholdRbkADCsel],
                             sysThresholdLOLO[sysThresholdRbkADCsel] };
    sysThresholdRbk <= {
               sysThresholdRbkSel,
               {32-2-ADC_SEL_WIDTH-ADC_WIDTH{1'b0}},
               sysThresholdRbkADCsel,
               sysThresholdRbkMux0[(sysThresholdRbkSel*ADC_WIDTH)+:ADC_WIDTH] };
end

// Some in acqClk domain, but race condition to system clock domain unimportant.
(*MARK_DEBUG=DEBUG*) reg acquisitionActive = 0;
(*MARK_DEBUG=DEBUG*) reg adcOverrun = 0;
(*MARK_DEBUG=DEBUG*) reg sendOverrun = 0;
assign sysStatus = { acqEnableAcquisition,
                     acquisitionActive,
                     sysSubscriberPresent,
                     sysIsCalibrated,
                     24'b0,
                     sendOverrun, adcOverrun, !sysTimeValid, !acqClkLocked };
assign sysActiveRbk = sysActiveChannels;
assign sysByteCountRbk = { {32-BYTECOUNT_WIDTH{1'b0}}, sysByteCount};

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock (acqClk) domain

// Clock crossing
(*ASYNC_REG="true"*) reg acqTimeValid_m = 0;
reg acqTimeValid = 0;
always @(posedge acqClk) begin
    acqTimeValid_m <= sysTimeValid;
    acqTimeValid   <= acqTimeValid_m;
    acqSysForwardToggle_m <= sysForwardToggle;
    acqSysForwardToggle   <= acqSysForwardToggle_m;
    if ((acqForwardToggle != acqSysForwardToggle) && !acquisitionActive) begin
        acqForwardData <= sysForwardData;
        acqForwardToggle <= !acqForwardToggle;
    end
end
wire       [ADC_COUNT-1:0] acqActiveChannels = acqForwardData[0+:ADC_COUNT];
wire [BYTECOUNT_WIDTH-1:0] acqByteCount =
                                     acqForwardData[ADC_COUNT+:BYTECOUNT_WIDTH];
wire acqSubscriberPresent = acqForwardData[ADC_COUNT+BYTECOUNT_WIDTH];

// State machine counters

// Header shift register count
(*MARK_DEBUG=DEBUG*) reg [HEADER_SHIFT_COUNTER_WIDTH-1:0] headerShiftCounter;
wire headerShiftCounterDone = headerShiftCounter[HEADER_SHIFT_COUNTER_WIDTH-1];

// ADC shift register count
(*MARK_DEBUG=DEBUG*) reg [ADC_SHIFT_COUNTER_WIDTH-1:0] adcShiftCounter;
wire adcShiftCounterDone = adcShiftCounter[ADC_SHIFT_COUNTER_WIDTH-1];

// Packet byte count
(*MARK_DEBUG=DEBUG*) reg [BYTECOUNTER_WIDTH-1:0] byteCounter;
wire byteCounterDone = byteCounter[BYTECOUNTER_WIDTH-1];

// Count bytes in a single ADC reading
localparam ADC_BYTE_COUNTER_LOAD = BYTES_PER_ADC - 2;
localparam ADC_BYTE_COUNTER_WIDTH = $clog2(ADC_BYTE_COUNTER_LOAD+1) + 1;
reg [ADC_BYTE_COUNTER_WIDTH-1:0] adcByteCounter;
wire adcByteCounterDone = adcByteCounter[ADC_BYTE_COUNTER_WIDTH-1];

// State machine controls
reg inPacket = 0;
reg awaitAcqStrobe = 0;
reg sendChecksumLo = 0;

// Packet header
localparam HEADER_SHIFT_REG_WIDTH = HEADER_BYTE_COUNT * 8;
reg [HEADER_SHIFT_REG_WIDTH-1:0] headerShiftReg;
reg [63:0] sequenceNumber = 1;
// C code knows that there are clock-domain race conditions:
assign sysSequenceNumber = sequenceNumber[31:0];

// Threshold detection
(*MARK_DEBUG=DEBUG*)wire [ADC_COUNT-1:0] belowLOLO, belowLO, aboveHI, aboveHIHI;
assign acqLimitExcursions = { belowLOLO, belowLO, aboveHI, aboveHIHI };

// ADC readings -- switch to big-endian
localparam ADC_SHIFT_REG_WIDTH = ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH;
wire [ADC_SHIFT_REG_WIDTH-1:0] adcDataShiftLoad;
reg  [ADC_SHIFT_REG_WIDTH-1:0] adcDataShiftReg;

genvar i;
generate
for (i = 0 ; i < ADC_COUNT ; i = i + 1) begin : perADC
    (*MARK_DEBUG=DEBUG*) wire signed [ADC_WIDTH-1:0] v =
                                              acqData[(i*ADC_WIDTH)+:ADC_WIDTH];
    (*MARK_DEBUG=DEBUG*) wire signed [ADC_WIDTH-1:0] LOLO = sysThresholdLOLO[i];
    (*MARK_DEBUG=DEBUG*) wire signed [ADC_WIDTH-1:0] LO   = sysThresholdLO  [i];
    (*MARK_DEBUG=DEBUG*) wire signed [ADC_WIDTH-1:0] HI   = sysThresholdHI  [i];
    (*MARK_DEBUG=DEBUG*) wire signed [ADC_WIDTH-1:0] HIHI = sysThresholdHIHI[i];

    assign adcDataShiftLoad[(i*ADC_WIDTH)+ 0+:8] = acqData[(i*ADC_WIDTH)+16+:8];
    assign adcDataShiftLoad[(i*ADC_WIDTH)+ 8+:8] = acqData[(i*ADC_WIDTH)+ 8+:8];
    assign adcDataShiftLoad[(i*ADC_WIDTH)+16+:8] = acqData[(i*ADC_WIDTH)+ 0+:8];

    assign belowLOLO[i] = (v <= LOLO);
    assign belowLO  [i] = (v <= LO);
    assign aboveHI  [i] = (v >= HI);
    assign aboveHIHI[i] = (v >= HIHI);
end
endgenerate

/*
 * The '- 8' arises from the fact that the pscdrvByteCount does not include
 * the first 8 bytes of the header (4-byte magic word and 4-byte size).
 * The '+ 16' arises from the fact that the HEADER_BYTE_COUNT does not
 * take into account the 4 4-byte limit excursion bitmaps.
 */
wire [31:0] pscdrvByteCount = {1'b0, acqByteCount} + HEADER_BYTE_COUNT - 8 + 16;

// Active channels
reg [ADC_COUNT-1:0] activeChannelShiftReg;

always @(posedge acqClk) begin
    if (acquisitionActive) begin
        if (M_TVALID && !M_TREADY) begin
            sendOverrun <= 1;
        end
        if (awaitAcqStrobe) begin
            if (acqStrobe) begin
                adcDataShiftReg <= adcDataShiftLoad;
                adcShiftCounter <= ADC_SHIFT_COUNTER_LOAD;
                activeChannelShiftReg <= acqActiveChannels;
                adcByteCounter <= ADC_BYTE_COUNTER_LOAD;
                packetLimitExcursions <= packetLimitExcursions |
                                                             acqLimitExcursions;
                awaitAcqStrobe <= 0;
                inPacket <= 1;
                if (!inPacket) begin
                    sendChecksumLo <= 1;
                    headerShiftCounter <= HEADER_SHIFT_COUNTER_LOAD;
                    byteCounter <= acqByteCount - 2;
                    sequenceNumber <= sequenceNumber + 1;
                    /* PSCDRV packet header with additional fields */
                    headerShiftReg <= {
                          "P", "S", "N", "B",
                          pscdrvByteCount,
                          { {27{1'b0}},
                            !sysIsCalibrated,
                            sendOverrun, adcOverrun,
                            !acqTimeValid, !acqClkLocked },
                          acqActiveChannels,
                          sequenceNumber[63:32],
                          sequenceNumber[31:0],
                          acqSeconds,
                          {acqTicks[0+:29], 3'b000} }; /* nanoseconds */
                end
            end
        end
        else begin
            if (acqStrobe) begin
                adcOverrun <= 1;
            end
            if (!headerShiftCounterDone) begin
                headerShiftCounter <= headerShiftCounter - 1;
                M_TDATA <= headerShiftReg[HEADER_SHIFT_REG_WIDTH-1-:8];
                M_TVALID <= 1;
                headerShiftReg <= {headerShiftReg[0+:HEADER_SHIFT_REG_WIDTH-8],
                                                                         8'bx };
            end
            else if (!adcShiftCounterDone) begin
                adcShiftCounter <= adcShiftCounter - 1;
                M_TDATA <= adcDataShiftReg[7:0];
                M_TVALID <= activeChannelShiftReg[0];
                adcDataShiftReg <= { 8'bx,
                                    adcDataShiftReg[8+:ADC_SHIFT_REG_WIDTH-8] };
                if (adcByteCounterDone) begin
                    adcByteCounter <= ADC_BYTE_COUNTER_LOAD;
                        // Shift in 1's from the top to ensure that the
                        // byteCounter is updated in case of a mismatch
                        // between the bit map and the byte count.
                        // We don't want to risk getting stuck here
                        // because some client failed to abide by
                        // proper operating procedure.
                        activeChannelShiftReg <= { 1'b1,
                                         activeChannelShiftReg[ADC_COUNT-1:1] };
                end
                else begin
                    adcByteCounter <= adcByteCounter - 1;
                end
                if (activeChannelShiftReg[0]) begin
                    byteCounter <= byteCounter - 1;
                end
                if (byteCounterDone) begin
                    M_TLAST <= 1;
                end
            end
            else begin
                M_TVALID <= 0;
                M_TLAST <= 0;
                if (M_TLAST) begin
                    inPacket <= 0;
                    packetLimitExcursions <= 0;
                    acquisitionActive <= (acqEnableAcquisition &&
                                          acqSubscriberPresent);
                end
                awaitAcqStrobe <= 1;
            end
        end
    end
    else begin
        sequenceNumber <= {acqSeconds, 32'b0};
        awaitAcqStrobe <= 1;
        packetLimitExcursions <= 0;
        if (acqEnableAcquisition && acqSubscriberPresent) begin
            adcOverrun <= 0;
            sendOverrun <= 0;
            acquisitionActive <= 1;
        end
    end
end

endmodule
`default_nettype wire
