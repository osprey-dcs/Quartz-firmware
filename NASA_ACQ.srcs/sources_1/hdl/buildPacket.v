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
    parameter DEBUG               = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysActiveBitmapStrobe,
    input  wire        sysByteCountStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysActiveRbk,
    output wire [31:0] sysByteCountRbk,
    input  wire        sysTimeValid,

    input  wire                                       acqClk,
    (*MARK_DEBUG=DEBUG*) input  wire                  acqStrobe,
    (*MARK_DEBUG=DEBUG*) input  wire
        [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData,

    (*MARK_DEBUG=DEBUG*) input  wire [31:0] acqSeconds,
    (*MARK_DEBUG=DEBUG*) input  wire [31:0] acqTicks,
    (*MARK_DEBUG=DEBUG*) input  wire        acqClkLocked,
    (*MARK_DEBUG=DEBUG*) input  wire        acqEnableAcquisition,

    (*MARK_DEBUG=DEBUG*) output reg        M_TVALID = 0,
    (*MARK_DEBUG=DEBUG*) output reg        M_TLAST = 0,
    (*MARK_DEBUG=DEBUG*) output reg  [7:0] M_TDATA,
    (*MARK_DEBUG=DEBUG*) input  wire       M_TREADY);

localparam BYTES_PER_ADC = (ADC_WIDTH + 7) / 8;

localparam ADC_COUNT = ADC_CHIP_COUNT * ADC_PER_CHIP;
localparam ADCS_PER_SAMPLE_WIDTH = $clog2(ADC_COUNT+1);
localparam ADC_SHIFT_COUNT = ADC_COUNT * BYTES_PER_ADC;
localparam ADC_SHIFT_COUNTER_LOAD = ADC_SHIFT_COUNT - 1;
localparam ADC_SHIFT_COUNTER_WIDTH = $clog2(ADC_SHIFT_COUNTER_LOAD+1) + 1;

localparam HEADER_BYTE_COUNT = 8 * 4;
localparam HEADER_SHIFT_COUNTER_LOAD = HEADER_BYTE_COUNT - 1;
localparam HEADER_SHIFT_COUNTER_WIDTH = $clog2(HEADER_SHIFT_COUNTER_LOAD+1) + 1;

localparam BYTECOUNT_WIDTH = $clog2(UDP_PACKET_CAPACITY-HEADER_BYTE_COUNT+1);
localparam BYTECOUNTER_WIDTH = BYTECOUNT_WIDTH + 1;

// Support for forwarding values from one clock domain to another
localparam FORWARD_DATA_WIDTH = BYTECOUNT_WIDTH + ADC_COUNT;
reg sysForwardToggle = 0, acqForwardToggle = 0;
(*ASYNC_REG="true"*) reg sysAcqForwardToggle_m = 0, acqSysForwardToggle_m = 0;
reg sysAcqForwardToggle = 0, acqSysForwardToggle = 0;
reg [FORWARD_DATA_WIDTH-1:0] sysForwardData, acqForwardData;

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain

reg [ADC_COUNT-1:0] sysActiveChannels = ~0;
reg [BYTECOUNT_WIDTH-1:0] sysByteCount = 1400;

always @(posedge sysClk) begin
    if (sysActiveBitmapStrobe) begin
        sysActiveChannels <= sysGPIO_OUT[0+:ADC_COUNT];
    end
    if (sysByteCountStrobe) begin
        sysByteCount <= sysGPIO_OUT[0+:BYTECOUNT_WIDTH];
    end

    // Forward values to ACQ clock domain
    sysAcqForwardToggle_m <= acqForwardToggle;
    sysAcqForwardToggle   <= sysAcqForwardToggle_m;
    if (sysForwardToggle == sysAcqForwardToggle) begin
        sysForwardData <= {sysByteCount, sysActiveChannels};
        sysForwardToggle <= !sysForwardToggle;
    end
end

// Some in acqClk domain, but race condition to system clock domain unimportant.
(*MARK_DEBUG=DEBUG*) reg acquisitionActive = 0;
(*MARK_DEBUG=DEBUG*) reg adcOverrun = 0;
(*MARK_DEBUG=DEBUG*) reg sendOverrun = 0;
assign sysStatus = { acqEnableAcquisition, acquisitionActive, 26'b0,
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

// ADC readings -- switch to big-endian
localparam ADC_SHIFT_REG_WIDTH = ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH;
wire [ADC_SHIFT_REG_WIDTH-1:0] adcDataShiftLoad;
reg  [ADC_SHIFT_REG_WIDTH-1:0] adcDataShiftReg;
genvar i;
generate
for (i = 0 ; i < ADC_COUNT ; i = i + 1) begin : adcByteSwap
    assign adcDataShiftLoad[(i*ADC_WIDTH)+ 0+:8] = acqData[(i*ADC_WIDTH)+16+:8];
    assign adcDataShiftLoad[(i*ADC_WIDTH)+ 8+:8] = acqData[(i*ADC_WIDTH)+ 8+:8];
    assign adcDataShiftLoad[(i*ADC_WIDTH)+16+:8] = acqData[(i*ADC_WIDTH)+ 0+:8];
end
endgenerate

/*
 * The '- 8' arises frm the fact that the pscdrvByteCount does not include
 * the first 8 bytes of the header (4-byte magic word and 4-byte size).
 */
wire [31:0] pscdrvByteCount = {1'b0, acqByteCount} + HEADER_BYTE_COUNT - 8;

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
                awaitAcqStrobe <= 0;
                inPacket <= 1;
                if (!inPacket) begin
                    sendChecksumLo <= 1;
                    headerShiftCounter <= HEADER_SHIFT_COUNTER_LOAD;
                    byteCounter <= acqByteCount - 2;
                    sequenceNumber <= sequenceNumber + 1;
                    /* PSCDRV packet header with additional fields */
                    headerShiftReg <= {
                          "P", "S", "N", "A",
                          pscdrvByteCount,
                          { {28{1'b0}},
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
                    acquisitionActive <= acqEnableAcquisition;
                end
                awaitAcqStrobe <= 1;
            end
        end
    end
    else begin
        sequenceNumber <= {acqSeconds, 32'b0};
        awaitAcqStrobe <= 1;
        if (acqEnableAcquisition) begin
            adcOverrun <= 0;
            sendOverrun <= 0;
            acquisitionActive <= 1;
        end
    end
end

endmodule
`default_nettype wire
