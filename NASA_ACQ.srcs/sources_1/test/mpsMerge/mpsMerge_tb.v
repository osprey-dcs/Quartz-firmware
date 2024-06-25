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
module mpsMerge_tb;

parameter MGT_COUNT        = 8;
parameter MGT_DATA_WIDTH   = 16;
parameter MPS_OUTPUT_COUNT = 8;

reg          sysClk = 0;
reg          sysCsrStrobe = 0;
reg  [31:0] sysGPIO_OUT = {32{1'bx}};
wire [31:0] sysStatus;

reg  [(MGT_COUNT*MGT_DATA_WIDTH)-1:0] mgtRxChars = 0;
reg                   [MGT_COUNT-1:0] mgtRxLinkUp = 0;

reg                       mgtTxClk = 0;
wire [MGT_DATA_WIDTH-1:0] mpfTxChars;
wire                      mpfTxCharIsK;

// Instantiate device under test
mpsMerge #(
    .MGT_COUNT(MGT_COUNT),
    .MGT_DATA_WIDTH(MGT_DATA_WIDTH),
    .MPS_OUTPUT_COUNT(MPS_OUTPUT_COUNT))
  mpsMerge_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .mgtRxChars(mgtRxChars),
    .mgtRxLinkUp(mgtRxLinkUp),
    .mgtTxClk(mgtTxClk),
    .mpfTxChars(mpfTxChars),
    .mpfTxCharIsK(mpfTxCharIsK));

// Generate clocks
always begin #5 sysClk = !sysClk; end
always begin #4 mgtTxClk = !mgtTxClk; end

integer i;
integer good = 1;
initial
begin
    $dumpfile("mpsMerge_tb.fst");
    $dumpvars(0, mpsMerge_tb);

    // All uplinks important, all uplinks active, no faults
    mgtRxLinkUp = {MGT_COUNT{1'b1}};
    writeCSR(8'hFE);
    check(8'h00);

    // Confirm that any 'important', 'bad' links trip all outputs
    // and that an 'unimportant', 'bad' link does not trip any outputs
    for (i = 1 ; i < MGT_COUNT ; i = i + 1) begin
        writeCSR(8'hFE);
        mgtRxLinkUp = {MGT_COUNT{1'b1}} & ~(1 << i);;
        check(8'hFF);
        writeCSR({MGT_COUNT{1'b1}} & ~(1 << i));
        check(8'h00);
    end

    // Single fault
    mgtRxLinkUp = {MGT_COUNT{1'b1}};
    writeCSR(8'hFE);
    setRx(0, 8'hA5);
    setRx(1, 8'h02);
    check(8'h02);

    // Add another fault
    setRx(2, 8'h20);
    check(8'h22);

    // Add another fault
    setRx(MGT_COUNT-1, 8'h80);
    check(8'hA2);

    // Confirm that faults from 'unimportant' links are ignored
    writeCSR(8'h7E);
    check(8'h22);

    #10 ;
    $display("%s", good ? "PASS" : "FAIL");
    $finish;
end

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

// Set receiver distributed bus value
task setRx;
    input integer i;
    input [7:0] c;
    begin
    mgtRxChars[((i*MGT_DATA_WIDTH)+8)+:8] = c;
    end
endtask

// Check for desired result
task check;
    input [MPS_OUTPUT_COUNT-1:0] expect;
    reg [MPS_OUTPUT_COUNT-1:0] important;
    begin
    #40;
    important = sysStatus;
    $write("Use:%x Links:%x Rx:%x got:%x want:%x -- ",
                                       important, mgtRxLinkUp, mgtRxChars,
                                       mpfTxChars[8+:MPS_OUTPUT_COUNT], expect);
    if (mpfTxChars[8+:MPS_OUTPUT_COUNT] == expect) begin
        $display("PASS");
    end
    else begin
        $display("FAIL");
        good = 0;
    end
    end
endtask

endmodule
`default_nettype wire
