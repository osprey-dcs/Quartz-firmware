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
 * Test bench for ADC limit excursion merging
 */
`timescale 1ns/1ns
`default_nettype none

module mergeLimitExcursions_tb;

localparam ADC_CHIP_COUNT = 4;
localparam ADC_PER_CHIP   = 8;
localparam BITMAPS_WIDTH   = 128;

reg        clk = 0;
reg        M_TVALID = 0;
reg        M_TLAST = 0;
reg  [7:0] M_TDATA = {8{1'bx}};
wire       M_TREADY;
reg [BITMAPS_WIDTH-1:0] packetLimitExcursions = {BITMAPS_WIDTH{1'bx}};
wire       S_TVALID;
wire       S_TLAST;
wire [7:0] S_TDATA;

// Instantiate device under test
mergeLimitExcursions #(
    .BITMAPS_WIDTH(BITMAPS_WIDTH),
    .DEBUG("false"))
  mergeLimitExcursions (
    .clk(clk),
    .S_TVALID(M_TVALID),
    .S_TLAST(M_TLAST),
    .S_TDATA(M_TDATA),
    .S_TREADY(M_TREADY),
    .packetLimitExcursions(packetLimitExcursions),
    .M_TVALID(S_TVALID),
    .M_TLAST(S_TLAST),
    .M_TDATA(S_TDATA),
    .M_TREADY(1'b1));

// Generate clock
always begin #4 clk = !clk; end

initial
begin
    $dumpfile("mergeLimitExcursions_tb.fst");
    $dumpvars(0, mergeLimitExcursions_tb);

    #100;
    sendPacket();
    #30000;
    sendPacket();
    #30000;
    $finish;
end

task sendPacket;
    integer i;
    begin
    for (i = 0 ; i < 100 ; i = i + 1) begin
        @(posedge clk) begin
            M_TVALID <= 1;
            M_TDATA <= i;
            if (i == 99) begin
                M_TLAST <= 1;
                packetLimitExcursions <= 128'hA0_A1_A2_A3_A4_A5_A6_A7_A8_A9_AA_AB_AC_AD_AE_AF;
            end
        end
    end
    @(posedge clk) begin
        M_TVALID <= 0;
        M_TLAST <= 0;
        packetLimitExcursions <= {BITMAPS_WIDTH{1'bx}};
    end
    end
endtask
endmodule

module buildPacketMergeBitmapsFIFO (
    output wire       wr_rst_busy,
    output wire       rd_rst_busy,
    input  wire       s_aclk,
    input  wire       s_aresetn,
    input  wire       s_axis_tvalid,
    output wire       s_axis_tready,
    input  wire [7:0] s_axis_tdata,
    input  wire       s_axis_tlast,
    output wire       m_axis_tvalid,
    input  wire       m_axis_tready,
    output wire [7:0] m_axis_tdata,
    output wire       m_axis_tlast,
    output wire       axis_overflow);

reg [10:0] head = 0, tail = 0;
reg  [8:0] dpram [0:2047];

assign axis_overflow = ((head + 1) == tail);
assign s_axis_tready = !axis_overflow;

assign m_axis_tvalid = (head != tail);
assign m_axis_tdata = dpram[tail][7:0];
assign m_axis_tlast = dpram[tail][8];

assign wr_rst_busy = 1'b0;
assign rd_rst_busy = 1'b0;

always @(posedge s_aclk) begin
    if (s_aresetn == 0) begin
        head <= 0;
        tail <= 0;
    end
    else begin
        if (s_axis_tvalid) begin
            dpram[head] <= {s_axis_tlast, s_axis_tdata};
            head <= head + 1;
        end
        if (m_axis_tvalid && m_axis_tready) begin
            tail <= tail + 1;
        end
    end
end
endmodule
