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
 * Event fanout
 * Very limited capability.
 * Good only for forwarding time to downstream acquisition nodes.
 */
`default_nettype none
module evf #(
    parameter CFG_EVG_CLK_RATE = 125000000,
    parameter DEBUG            = "false"
    ) (
                         input  wire        rxClk,
                         input  wire        rxLinkUp,
    (*MARK_DEBUG=DEBUG*) input  wire [15:0] rxChars,
    (*MARK_DEBUG=DEBUG*) input  wire  [1:0] rxCharIsK,
                         input  wire        txClk,
    (*MARK_DEBUG=DEBUG*) output wire [15:0] txChars,
    (*MARK_DEBUG=DEBUG*) output wire  [1:0] txCharIsK);

localparam EVCODE_NOP = 8'h00;
localparam K28_5 = 8'hBC;

/*
 * Send alignment comma on four cycle boundaries
 */
reg [2:0] commaCounter = 0;
wire commaCounterDone = commaCounter[2];

/*
 * FIFO write side
 */
reg [7:0] fifoIN;
reg       fifoWREN;

/*
 * FIFO read side
 */
wire [7:0] fifoOUT;
wire       fifoEMPTY;
reg  [7:0] txCode;
reg        txCodeIsK;

(*ASYNC_REG="TRUE"*) reg rxReady_m = 0;
reg rxReady = 0;
reg fifoRST = 1;
always @(posedge rxClk) begin
    /*
     * FIFO write side
     */
    fifoIN <= rxChars[7:0];
    if (!rxLinkUp
     && (rxCharIsK == 2'b00)
     && (rxChars[7:0] != EVCODE_NOP)) begin
        fifoWREN <= 1;
    end
    else begin
        fifoWREN <= 0;
    end
end

always @(posedge txClk) begin
    /*
     * FIFO read side
     */
    if (commaCounterDone) begin
        commaCounter <= 0;
    end
    else begin
        commaCounter <= commaCounter + 1;
    end
    if (!fifoEMPTY) begin
        txCode <= fifoOUT;
        txCodeIsK <= 0;
    end
    else if (commaCounterDone) begin
        txCode <= K28_5;
        txCodeIsK <= 1;
    end
    else begin
        txCode <= EVCODE_NOP;
        txCodeIsK <= 0;
    end
end
assign txChars = { 8'h00, txCode };
assign txCharIsK = { 1'b0, txCodeIsK };

/*
 * Instantiate the event code clock-crossing FIFO
 * Instantiation from Vivado language template.
 */
FIFO_DUALCLOCK_MACRO  #(
      .ALMOST_EMPTY_OFFSET(9'h080), // Sets the almost empty threshold
      .ALMOST_FULL_OFFSET(9'h080),  // Sets almost full threshold
      .DATA_WIDTH(8),   // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      .DEVICE("7SERIES"),  // Target device: "7SERIES"
      .FIFO_SIZE ("18Kb"), // Target BRAM: "18Kb" or "36Kb"
      .FIRST_WORD_FALL_THROUGH ("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
 ) evcodeFIFO (
      .ALMOSTEMPTY(),    // 1-bit output almost empty
      .ALMOSTFULL(),     // 1-bit output almost full
      .DO(fifoOUT),      // Output data, width defined by DATA_WIDTH parameter
      .EMPTY(fifoEMPTY), // 1-bit output empty
      .FULL(),           // 1-bit output full
      .RDCOUNT(),        // Output read count, width determined by FIFO depth
      .RDERR(),          // 1-bit output read error
      .WRCOUNT(),        // Output write count, width determined by FIFO depth
      .WRERR(),          // 1-bit output write error
      .DI(fifoIN),       // Input data, width defined by DATA_WIDTH parameter
      .RDCLK(txClk),     // 1-bit input read clock
      .RDEN(1'b1),       // 1-bit input read enable
      .RST(!rxLinkUp),   // 1-bit input reset
      .WRCLK(rxClk),     // 1-bit input write clock
      .WREN(fifoWREN)    // 1-bit input write enable
   );
endmodule
`default_nettype wire
