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
 * Test MPS merge operation
 */
`timescale 1ns/1ns

`default_nettype none
module mpsLocal_tb;

parameter MPS_OUTPUT_COUNT = 8;
parameter MPS_INPUT_COUNT  = 8;
parameter ADC_COUNT        = 32;
parameter TIMESTAMP_WIDTH  = 64;

reg          sysClk = 0;
reg          sysCsrStrobe = 0;
reg          sysDataStrobe = 0;
reg  [31:0] sysGPIO_OUT = {32{1'bx}};
wire [31:0] sysStatus;
wire [31:0] sysData;

reg  evrClk = 0;
reg  evrClearMPSstrobe = 0;

reg                        acqClk = 0;
reg                        acqLimitExcursionsTVALID = 0;
reg  [TIMESTAMP_WIDTH-1:0] acqTimestamp = 64'h300000000;
reg  [MPS_INPUT_COUNT-1:0] mpsInputs = 0;
reg  [(4*ADC_COUNT)-1:0] acqLimitExcursions = {4*ADC_COUNT{1'bx}};

reg         mgtTxClk = 0;
wire [15:0] mpsTxChars;
wire        mpsTxCharIsK;
wire [MPS_OUTPUT_COUNT-1:0] mpsTripped = mpsTxChars[8+:MPS_OUTPUT_COUNT];

// Instantiate device under test
mpsLocal #(
    .MPS_OUTPUT_COUNT(MPS_OUTPUT_COUNT),
    .MPS_INPUT_COUNT(MPS_INPUT_COUNT),
    .ADC_COUNT(ADC_COUNT),
    .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH))
  mpsLocal_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysDataStrobe(sysDataStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .sysData(sysData),
    .evrClk(evrClk),
    .evrClearMPSstrobe(evrClearMPSstrobe),
    .acqClk(acqClk),
    .acqLimitExcursions(acqLimitExcursions),
    .acqLimitExcursionsTVALID(acqLimitExcursionsTVALID),
    .acqTimestamp(acqTimestamp),
    .mpsInputStates_a(mpsInputs),
    .mgtTxClk(mgtTxClk),
    .mpsTxChars(mpsTxChars),
    .mpsTxCharIsK(mpsTxCharIsK));

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #1 while(1) begin #4 evrClk = !evrClk; end end
always begin #2 while(1) begin #4 acqClk = !acqClk; end end
always begin #3 while(1) begin #4 mgtTxClk = !mgtTxClk; end end

// Useful constants
localparam R_HIHI_BITMAP          = 8'h00;
localparam R_HI_BITMAP            = 8'h01;
localparam R_LO_BITMAP            = 8'h02;
localparam R_LOLO_BITMAP          = 8'h03;
localparam R_DISCRETE_BITMAP      = 8'h04;
localparam R_DISCRETE_GOOD_STATE  = 8'h05;
localparam R_FIRST_FAULT_HIHI     = 8'h06;
localparam R_FIRST_FAULT_HI       = 8'h07;
localparam R_FIRST_FAULT_LO       = 8'h08;
localparam R_FIRST_FAULT_LOLO     = 8'h09;
localparam R_FIRST_FAULT_DISCRETE = 8'h0A;
localparam R_FIRST_FAULT_SECONDS  = 8'h0B;
localparam R_FIRST_FAULT_TICKS    = 8'h0C;
localparam R_STATUS               = 8'h0D;

// Keep track of 'time of day'
always @(posedge acqClk) begin
    if (acqTimestamp[0+:32] == 999) begin
        acqTimestamp[0+:32] <= 0;
        acqTimestamp[32+:32] <= acqTimestamp[32+:32] + 1;
    end
    else begin
        acqTimestamp[0+:32] <= acqTimestamp[0+:32] + 1;
    end
end



integer channel;
integer good = 1;
initial
begin
    $dumpfile("mpsLocal_tb.fst");
    $dumpvars(0, mpsLocal_tb);

    for (channel = 0 ; channel < MPS_OUTPUT_COUNT ; channel = channel + 1) begin
        writeReg(channel, R_DISCRETE_GOOD_STATE, 8'hFF);
        mpsInputs = 8'hFF;

        // Check that enabling some conditions leaves things untripped
        writeReg(channel,     R_LOLO_BITMAP, 32'h80000000);
        writeReg(channel,       R_LO_BITMAP, 32'hFFFFFFFF);
        writeReg(channel,       R_HI_BITMAP, 32'h00001000);
        writeReg(channel,     R_HIHI_BITMAP, 32'h00000400);
        writeReg(channel, R_DISCRETE_BITMAP, 32'h00000010);
        checkTrip(0);

        // Check that a bunch of unimportant conditions leaves things untripped
        adc(~32'h80000000, ~32'hFFFFFFFF, ~32'h00001000, ~32'h00000400);
        mpsInputs = 8'h10;
        checkTrip(0);

        // Check that one important condition trips
        adc(32'h80000000, ~32'hFFFFFFFF, ~32'h00001000, ~32'h00000400);
        checkTrip(1 << channel);

        // Check that attempting to clear trip fails and sets new 'first fault'
        adc(32'h80000000, 32'hFFFFFFFF, ~32'h00001000, ~32'h00000400);
        clearTrip();
        checkTrip(1 << channel);

        // Check that trip can be cleared when all important inputs are good
        adc(~32'h80000000, ~32'hFFFFFFFF, ~32'h00001000, ~32'h00000400);
        clearTrip();
        checkTrip(0);

        // Check that hardware input can cause trip
        adc(~32'h80000000, ~32'hFFFFFFFF, ~32'h00001000, ~32'h00000400);
        mpsInputs = 0;
        checkTrip(1 << channel);

        // Mark all inputs 'uninteresting'
        writeReg(channel,     R_LOLO_BITMAP, 32'h0);
        writeReg(channel,       R_LO_BITMAP, 32'h0);
        writeReg(channel,       R_HI_BITMAP, 32'h0);
        writeReg(channel,     R_HIHI_BITMAP, 32'h0);
        writeReg(channel, R_DISCRETE_BITMAP, 32'h0);
        #100;
        clearTrip();
        checkTrip(0);

        // Restore things
        adc(0, 0, 0, 0);
        mpsInputs = 0;
    end
    $display("%s", good ? "PASS" : "FAIL");
    $finish;
end

// Write to register
task writeReg;
    input [31:0] m;
    input [31:0] r;
    input [31:0] w;
    begin
    selectReg(m, r);
    #40;
    @(posedge sysClk) begin
        sysGPIO_OUT <= w;
        sysDataStrobe <= 1;
    end
    @(posedge sysClk) begin
        sysGPIO_OUT <= {32{1'bx}};
        sysDataStrobe <= 0;
    end
    @(posedge sysClk) ;
    end
endtask

// Read from register
task readReg;
    input  [31:0] m;
    input  [31:0] r;
    output [31:0] v;
    begin
    selectReg(m, r);
    #40;
    v = sysData;
    @(posedge sysClk) ;
    end
endtask

// Select a particular register
task selectReg;
    input [31:0] m;
    input [31:0] r;
    begin
    writeCSR((r << 8) | m);
    #40;
    end
endtask

// Write value to CSR
task writeCSR;
    input [31:0] w;
    begin
    @(posedge sysClk) begin
        sysGPIO_OUT <= w;
        sysCsrStrobe <= 1;
    end
    @(posedge sysClk) begin
        sysGPIO_OUT <= {32{1'bx}};
        sysCsrStrobe <= 0;
    end
    @(posedge sysClk) ;
    end
endtask

// Clear trip
task clearTrip;
    begin
    @(posedge evrClk) begin
        evrClearMPSstrobe <= 1;
    end
    @(posedge evrClk) begin
        evrClearMPSstrobe <= 0;
    end
    end
endtask

// Set ADC limit excursions
task adc;
    input [ADC_COUNT-1:0] belowLOLO;
    input [ADC_COUNT-1:0] belowLO;
    input [ADC_COUNT-1:0] aboveHI;
    input [ADC_COUNT-1:0] aboveHIHI;
    begin
    @(posedge acqClk) begin
        acqLimitExcursions <= { belowLOLO, belowLO, aboveHI, aboveHIHI };
        acqLimitExcursionsTVALID <= 1;
    end
    @(posedge acqClk) begin
        acqLimitExcursions <= {4*ADC_COUNT{1'bx}};
        acqLimitExcursionsTVALID <= 0;
    end
    end
endtask

// Check trip status
task checkTrip;
    input [MPS_OUTPUT_COUNT-1:0] expect;
    reg [31:0] seconds, ticks, v;
    reg t, e;
    integer i, r;
    begin
    #100;
    for (i = 0 ; i < MPS_OUTPUT_COUNT ; i = i + 1) begin
        t = mpsTripped[i];
        e = expect[i];
        if (t || (t != e)) begin
            $write("%1d: T:%d", i + 1, t);
            readReg(i, R_FIRST_FAULT_SECONDS, seconds);
            readReg(i, R_FIRST_FAULT_TICKS, ticks);
            $write(" %08X:%08X", seconds, ticks);
            for (r = R_FIRST_FAULT_LOLO ; r >= R_FIRST_FAULT_HIHI ; r = r - 1) begin
                readReg(i, r, v);
                $write(" %08X", v);
            end
            readReg(i, R_FIRST_FAULT_DISCRETE, v);
            $write(" %02X", v);
            $write(" -- ");
            if (t == e) begin
                $display("PASS");
            end
            else begin
                $display("FAIL %d", $time);
                good = 0;
            end
        end
    end
    end
endtask
endmodule
`default_nettype wire
