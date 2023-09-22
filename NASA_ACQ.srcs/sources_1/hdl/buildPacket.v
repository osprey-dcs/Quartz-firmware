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
    input  wire        sysCsrStrobe,
    input  wire        sysActiveBitmapStrobe,
    input  wire        sysByteCountStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysActiveBitmap,
    output wire [31:0] sysByteCount,

    input  wire                                                       acqClk,
    (*MARK_DEBUG=DEBUG*) input  wire                                  acqStrobe,
    (*MARK_DEBUG=DEBUG*) input  wire
                        [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData,

    input  wire [31:0] acqSeconds,
    input  wire [31:0] acqTicks,

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

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain

// Used in acqClk domain, but changed only when acquisition is idle
reg [ADC_COUNT-1:0] activeChannels = {ADC_COUNT{1'b1}};
reg [BYTECOUNT_WIDTH-1:0] byteCount = 0;

// Used in acqClk domain, but race conditions unimportant
(*ASYNC_REG="true"*) reg acqTimeInvalid = 0;

// Used in acqClk domain with proper clock-domain-crossing logic
reg sysAcquisitionEnable = 0;

always @(posedge sysClk) begin
    // Bit-bang SPI
    if (sysCsrStrobe) begin
        if      (sysGPIO_OUT[30]) sysAcquisitionEnable <= 0;
        else if (sysGPIO_OUT[31]) sysAcquisitionEnable <= 1;
        if      (sysGPIO_OUT[0]) acqTimeInvalid <= 1;
        else if (sysGPIO_OUT[1]) acqTimeInvalid <= 0;
    end
    if (sysActiveBitmapStrobe) begin
        activeChannels <= sysGPIO_OUT[0+:ADC_COUNT];
    end
    if (sysByteCountStrobe) begin
        byteCount <= sysGPIO_OUT[0+:BYTECOUNT_WIDTH];
    end
end

// Used in acqClk domain, but race condition to system clock domain unimportant.
(*MARK_DEBUG=DEBUG*) reg acquisitionEnabled = 0;
reg adcOverrun = 0;
reg sendOverrun = 0;
assign sysStatus = { sysAcquisitionEnable,
                     acquisitionEnabled,
                     14'b0,
                     sendOverrun,
                     adcOverrun,
                     13'b0, acqTimeInvalid };
assign sysActiveBitmap = activeChannels;
assign sysByteCount = { {32-BYTECOUNT_WIDTH{1'b0}}, byteCount};

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock (acqClk) domain

// Clock crossing
(*ASYN_REG="true"*) reg acquisitionEnable_m;
(*MARK_DEBUG=DEBUG*) reg acquisitionEnable = 0;

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
 * The '- 6' arises frm the fact that the byteCount value is 2 less than
 * the number of ADC bytes and that the pscdrvByteCount does not include
 * the 8 byte PSCDRV header.
 */
wire [31:0] pscdrvByteCount = {1'b0, byteCount} + HEADER_BYTE_COUNT - 6;

// Active channels
reg [ADC_COUNT-1:0] activeChannelShiftReg;

always @(posedge acqClk) begin
    acquisitionEnable_m <= sysAcquisitionEnable;
    acquisitionEnable   <= acquisitionEnable_m;
    if (acquisitionEnabled) begin
        if (M_TVALID && !M_TREADY) begin
            sendOverrun <= 1;
        end
        if (awaitAcqStrobe) begin
            if (acqStrobe) begin
                adcDataShiftReg <= adcDataShiftLoad;
                adcShiftCounter <= ADC_SHIFT_COUNTER_LOAD;
                activeChannelShiftReg <= activeChannels;
                adcByteCounter <= ADC_BYTE_COUNTER_LOAD;
                awaitAcqStrobe <= 0;
                inPacket <= 1;
                if (!inPacket) begin
                    sendChecksumLo <= 1;
                    headerShiftCounter <= HEADER_SHIFT_COUNTER_LOAD;
                    byteCounter <= {1'b0, byteCount};
                    sequenceNumber <= sequenceNumber + 1;
                    /* PSCDRV packet header with additional fields */
                    headerShiftReg <= {
                          "P", "S", "N", "A",
                          pscdrvByteCount,
                          { {16{1'b0}}, sendOverrun, adcOverrun,
                            {13{1'b0}}, acqTimeInvalid },
                          activeChannels,
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
                        activeChannelShiftReg <= { 1'bx,
                                        activeChannelShiftReg[1+:ADC_COUNT-1] };
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
                    acquisitionEnabled <= acquisitionEnable;
                end
                awaitAcqStrobe <= 1;
            end
        end
    end
    else begin
        sequenceNumber <= {acqSeconds, 32'b0};
        awaitAcqStrobe <= 1;
        if (acquisitionEnable) begin
            adcOverrun <= 0;
            sendOverrun <= 0;
            acquisitionEnabled <= 1;
        end
    end
end

endmodule
`default_nettype wire
