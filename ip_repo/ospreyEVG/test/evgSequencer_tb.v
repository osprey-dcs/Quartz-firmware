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
 * Event generator sequencer test bench
 */

`timescale 1ns/100ps
`default_nettype none

module evgSequencer_tb;

localparam SEQRAM_ADDR_WIDTH = 12;
localparam DELAY_WIDTH       = 28;
localparam EVENT_CODE_WIDTH  = 8;
localparam EVENT_CODE_END_OF_SEQUENCE = {EVENT_CODE_WIDTH{1'b1}};

localparam OP_CONTROL      = 2'd0,
           OP_LATCH_DELAY  = 2'd1,
           OP_WRITE_RAM    = 2'd2;

localparam COARSE_DELAY = (1 << 27);

reg         sysClk = 0;
reg  [31:0] sysWriteData = {32{1'bx}};;
reg         sysWriteStrobe = 0;
wire [31:0] sysStatus;
wire isArmed  = sysStatus[0];
wire isActive = sysStatus[1];

reg                         evgClk = 0;
reg                         trigger = 0;
wire [EVENT_CODE_WIDTH-1:0] eventCode;
wire                        eventCodeTVALID;

// Instantiate device under test
ospreyEVGsequencer #(.SEQRAM_ADDR_WIDTH(SEQRAM_ADDR_WIDTH))
  ospreyEVGsequencer (
    .sysClk(sysClk),
    .sysWriteData(sysWriteData),
    .sysWriteStrobe(sysWriteStrobe),
    .sysStatus(sysStatus),
    .evgClk(evgClk),
    .trigger(trigger),
    .eventCode(eventCode),
    .eventCodeTVALID(eventCodeTVALID));

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 evgClk = !evgClk; end

// Watch for events
integer gapCount, wasActive = 0;
always @(negedge evgClk) begin
    if (!isActive) gapCount = 0;
end
always @(posedge evgClk) begin
    if (isActive) begin
        if (!wasActive) begin
            $display("===============");
            wasActive <= 1;
        end
        if (eventCodeTVALID) begin
            $display("%5d %3d", gapCount, eventCode);
            gapCount <= 0;
        end
        else begin
            gapCount <= gapCount + 1;
        end
    end
    else begin
        wasActive <= 0;
    end
end

initial
begin
    $dumpfile("evgSequencer_tb.fst");
    $dumpvars(0, evgSequencer_tb);

    // Zero delay sequence
    writeRAM(0, 0, 1);
    writeRAM(1, 0, 2);
    writeRAM(2, 0, 3);
    writeRAM(3, 0, EVENT_CODE_END_OF_SEQUENCE);
    arm();
    swTrigger();
    while ((sysStatus & 3) != 0) #10;

    // Unit delay sequence
    writeRAM(0, 1, 1);
    writeRAM(1, 1, 2);
    writeRAM(2, 1, 3);
    writeRAM(3, 1, EVENT_CODE_END_OF_SEQUENCE);
    arm();
    swTrigger();
    while ((sysStatus & 3) != 0) #10;

    // Longer delay sequence
    writeRAM(0, 3, 3);
    writeRAM(1, 4, 4);
    writeRAM(2, 5, 5);
    writeRAM(3, 6, EVENT_CODE_END_OF_SEQUENCE);
    arm();
    swTrigger();
    while ((sysStatus & 3) != 0) #10;

    // Coarse delay sequence
    writeRAM(0, 3, 1);
    writeRAM(1, COARSE_DELAY+2, 2);
    writeRAM(2, 0, 3);
    writeRAM(3, 0, 4);
    writeRAM(4, 1, EVENT_CODE_END_OF_SEQUENCE);
    arm();
    swTrigger();
    while ((sysStatus & 3) != 0) #10;

    $finish;
end

task writeRAM;
    input [SEQRAM_ADDR_WIDTH-1:0] address;
    input [DELAY_WIDTH-1:0] delay;
    input [EVENT_CODE_WIDTH-1:0] evcode;
    begin
    writeReg({OP_LATCH_DELAY, {32-2-DELAY_WIDTH{1'bx}}, delay});
    writeReg({OP_WRITE_RAM, {32-2-SEQRAM_ADDR_WIDTH-EVENT_CODE_WIDTH{1'bx}},
                                                              address, evcode});
    end
endtask

task arm;
    begin
    writeReg({OP_CONTROL, 30'h0001});
    end
endtask

task cancel;
    begin
    writeReg({OP_CONTROL, 30'h0002});
    end
endtask

task swTrigger;
    begin
    writeReg({OP_CONTROL, 30'h0004});
    end
endtask

task writeReg;
    input [31:0] writeValue;
    begin
    @(posedge sysClk) begin
        sysWriteData <= writeValue;
        sysWriteStrobe <= 1;
    end
    @(posedge sysClk) begin
        sysWriteData <= {32{1'bx}};
        sysWriteStrobe <= 0;
    end
    @(posedge sysClk) ;
    @(posedge sysClk) ;
    @(posedge sysClk) ;
    end
endtask
endmodule
`default_nettype wire
