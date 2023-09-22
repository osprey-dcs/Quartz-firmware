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
 * Test bench for NASA acquisition packet builder
 */
`timescale 1ns/1ns
`default_nettype none

module buildPacket_tb #(
`include "../../hdl/gpio.v"
    parameter endParms=0) ();

parameter ADC_CHIP_COUNT      = CFG_AD7768_CHIP_COUNT;
parameter ADC_PER_CHIP        = CFG_AD7768_ADC_PER_CHIP;
parameter ADC_WIDTH           = CFG_AD7768_WIDTH;
parameter UDP_PACKET_CAPACITY = CFG_UDP_PACKET_CAPACITY;

reg         sysClk = 0;
reg         sysCsrStrobe = 0;
reg         sysActiveBitmapStrobe = 0;
reg         sysByteCountStrobe = 0;
reg  [31:0] sysGPIO_OUT = {32{1'bx}};
wire [31:0] sysStatus;
wire [31:0] sysActiveBitmap;
wire [31:0] sysByteCount;

reg                                               acqClk = 0;
reg                                               acqStrobe = 0;
reg [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData;

reg [31:0] acqSeconds = 100000;
reg [31:0] acqTicks = 0;

wire       M_TVALID;
wire       M_TLAST;
wire [7:0] M_TDATA;
reg        M_TREADY = 1'b1;

buildPacket #(
    .ADC_CHIP_COUNT(ADC_CHIP_COUNT),
    .ADC_PER_CHIP(ADC_PER_CHIP),
    .ADC_WIDTH(ADC_WIDTH),
    .UDP_PACKET_CAPACITY(UDP_PACKET_CAPACITY),
    .DEBUG("false"))
  buildPacket (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysActiveBitmapStrobe(sysActiveBitmapStrobe),
    .sysByteCountStrobe(sysByteCountStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .sysActiveBitmap(sysActiveBitmap),
    .sysByteCount(sysByteCount),
    .acqClk(acqClk),
    .acqStrobe(acqStrobe),
    .acqData(acqData),
    .acqSeconds(acqSeconds),
    .acqTicks(acqTicks),
    .M_TVALID(M_TVALID),
    .M_TLAST(M_TLAST),
    .M_TDATA(M_TDATA),
    .M_TREADY(M_TREADY));

localparam BYTES_PER_ADC = (ADC_WIDTH+7)/8;
localparam ADC_COUNT = ADC_CHIP_COUNT * ADC_PER_CHIP;
localparam HEADER_BYTE_COUNT = 8 * 4;

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 acqClk = !acqClk; end

// Fake time-of-day
always @(posedge acqClk) begin
    if (acqTicks == (12500-1)) begin
        acqSeconds <= acqSeconds + 1;
        acqTicks <= 0;
    end
    else begin
        acqTicks <= acqTicks + 1;
    end
end

integer pkIndex = 0;
integer pkCount = 0;
always @(posedge acqClk) begin
    if (M_TVALID) begin
        $display("%4d %02x", pkIndex, M_TDATA);
        if (M_TLAST) begin
            pkIndex = 0;
            pkCount = pkCount + 1;
            $display("================");
        end
        else begin
            pkIndex = pkIndex + 1;
        end
    end
end

// Fake ADC readings (250 kHz)
reg [ADC_WIDTH-1:0]  adcValue = 0;
integer acqTickCounter = 0;
integer sampleNumber = 0;
integer i;
always @(posedge acqClk) begin 
    if ($time > 10000000) begin
        $display("=== TIMEOUT! ===");
        $finish;
    end
    if (acqTickCounter == 499) begin
        sampleNumber = sampleNumber + 1;
        for (i = 0 ; i < (ADC_CHIP_COUNT * ADC_PER_CHIP) ; i = i + 1) begin
            adcValue[ADC_WIDTH-1:8] = sampleNumber;
            adcValue[7:0] = i;
            acqData[i*ADC_WIDTH+:ADC_WIDTH] <= adcValue;
        end
        acqStrobe <= 1;
        acqTickCounter <= 0;
    end
    else begin
        acqStrobe <= 0;
        acqTickCounter <= acqTickCounter + 1;
    end
end

reg [15:0] adcsPerSample, samplesPerPacket;
initial
begin
    $dumpfile("buildPacket_tb.lxt");
    $dumpvars(0, buildPacket_tb);

    #200 ;
    // All channels
    runTest({ADC_COUNT{1'b1}});

    // First channel only
    runTest({{ADC_COUNT-1{1'b0}}, 1'b1});

    // Last channel only
    runTest({1'b1, {ADC_COUNT-1{1'b0}}});

    // All but first channel
    runTest({{ADC_COUNT-1{1'b1}}, 1'b0});

    // All but last channel
    runTest({1'b0, {ADC_COUNT-1{1'b1}}});

    // Odd channels
    runTest({ADC_COUNT/2{2'b01}});

    // Even channels
    runTest({ADC_COUNT/2{2'b10}});

    $display("=== DONE ===");
    #2000 ;
    $finish;
end

task runTest;
    input [ADC_COUNT-1:0] activeChannels;
    reg [15:0] adcsPerSample;
    reg [15:0] samplesPerPacket;
    integer i;
    integer pkLimit;
    begin
    pkLimit = pkCount + 2;
    adcsPerSample = 0;
    for (i = 0 ; i < ADC_COUNT ; i = i + 1) begin
        if (activeChannels[i]) adcsPerSample = adcsPerSample + 1;
    end
    samplesPerPacket = (UDP_PACKET_CAPACITY - HEADER_BYTE_COUNT) /
                                                (adcsPerSample * BYTES_PER_ADC);
    writeReg(0, {32{1'b0}});
    writeReg(2, (samplesPerPacket*adcsPerSample*BYTES_PER_ADC)-2);
    writeReg(1, activeChannels);
    writeReg(0, {1'b1, {31{1'b0}}});
    while (pkCount < pkLimit) #10;
    writeReg(0, {32{1'b0}});
    while (sysStatus[31]) #10;
    end
endtask

task writeReg;
    input [31:0] regIndex;
    input [31:0] value;
    begin
    @(posedge sysClk) begin
        case (regIndex)
        0: sysCsrStrobe <= 1;
        1: sysActiveBitmapStrobe <= 1;
        2: sysByteCountStrobe <= 1;
        endcase
        sysGPIO_OUT <= value;
    end
    @(posedge sysClk) begin
        sysCsrStrobe <= 0;
        sysActiveBitmapStrobe <= 0;
        sysByteCountStrobe <= 0;
        sysGPIO_OUT <= {31{1'bx}};
    end
    end
endtask
endmodule
