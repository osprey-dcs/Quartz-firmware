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
 * Merge ADC limit excursion bitmaps into outgoing packet stream
 */
`default_nettype none
module mergeLimitExcursions #(
    parameter BITMAPS_WIDTH = 4 * 32,
    parameter DEBUG       = "false"
    ) (
    input  wire                     clk,

    (*MARK_DEBUG=DEBUG*) input  wire                     S_TVALID,
    (*MARK_DEBUG=DEBUG*) input  wire                     S_TLAST,
    (*MARK_DEBUG=DEBUG*) input  wire               [7:0] S_TDATA,
    (*MARK_DEBUG=DEBUG*) output wire                     S_TREADY,
    (*MARK_DEBUG=DEBUG*) input  wire [BITMAPS_WIDTH-1:0] packetLimitExcursions,

    (*MARK_DEBUG=DEBUG*) output reg        M_TVALID = 0,
    (*MARK_DEBUG=DEBUG*) output reg        M_TLAST = 0,
    (*MARK_DEBUG=DEBUG*) output reg  [7:0] M_TDATA = 0,
    (*MARK_DEBUG=DEBUG*) input  wire       M_TREADY);

assign S_TREADY = 1'b1;

localparam HEADER_BYTE_COUNT = 32;
localparam BITMAP_BYTE_COUNT = (BITMAPS_WIDTH + 7) / 8;

localparam HEADER_COUNTER_LOAD = HEADER_BYTE_COUNT - 2;
localparam HEADER_COUNTER_WIDTH = $clog2(HEADER_COUNTER_LOAD+1) + 1;
reg [HEADER_COUNTER_WIDTH-1:0] headerCount = HEADER_COUNTER_LOAD;
(*MARK_DEBUG=DEBUG*) wire headerCountDone = headerCount[HEADER_COUNTER_WIDTH-1];

localparam BITMAP_COUNTER_LOAD = BITMAP_BYTE_COUNT - 2;
localparam BITMAP_COUNTER_WIDTH = $clog2(BITMAP_COUNTER_LOAD+1) + 1;
reg [BITMAP_COUNTER_WIDTH-1:0] bitmapCount = BITMAP_COUNTER_LOAD;
(*MARK_DEBUG=DEBUG*) wire bitmapCountDone = bitmapCount[BITMAP_COUNTER_WIDTH-1];
reg [BITMAPS_WIDTH-1:0] bitmaps;

localparam [2:0] ST_AWAIT_DATA   = 3'd0,
                 ST_SEND_HEADER  = 3'd1,
                 ST_SEND_BITMAPS = 3'd2,
                 ST_SEND_ADCS    = 3'd3,
                 ST_FLUSH        = 3'd4;
(*MARK_DEBUG=DEBUG*) reg [2:0] state = ST_AWAIT_DATA;
(*MARK_DEBUG=DEBUG*) reg fifoRESETn = 1;

// Buffer the packet
// Need space for just a single packet.
(*MARK_DEBUG=DEBUG*) wire       fifoInTREADY;
(*MARK_DEBUG=DEBUG*) wire       fifoOutTVALID;
(*MARK_DEBUG=DEBUG*) wire       fifoOutTLAST;
(*MARK_DEBUG=DEBUG*) wire [7:0] fifoOutTDATA;
(*MARK_DEBUG=DEBUG*) reg        fifoOutTREADY = 0;
(*MARK_DEBUG=DEBUG*) wire       fifoOverflow;

buildPacketMergeBitmapsFIFO buildPacketMergeBitmapsFIFO (
  .wr_rst_busy(),                            // output wire wr_rst_busy
  .rd_rst_busy(),                            // output wire rd_rst_busy
  .s_aclk(clk),                              // input wire s_aclk
  .s_aresetn(fifoRESETn),                    // input wire s_aresetn
  .s_axis_tvalid(S_TVALID),                  // input wire s_axis_tvalid
  .s_axis_tready(fifoInTREADY),              // output wire s_axis_tready
  .s_axis_tdata(S_TDATA),                    // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast(S_TLAST),                    // input wire s_axis_tlast
  .m_axis_tvalid(fifoOutTVALID),             // output wire m_axis_tvalid
  .m_axis_tready(fifoOutTREADY && M_TREADY), // input wire m_axis_tready
  .m_axis_tdata(fifoOutTDATA),               // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast(fifoOutTLAST),               // output wire m_axis_tlast
  .axis_overflow(fifoOverflow));             // output wire axis_overflow


always @(posedge clk) begin
    if (fifoOverflow) begin
        fifoRESETn <= 0;
        state <= ST_FLUSH;
    end
    else begin
        case (state)
        ST_AWAIT_DATA: begin
            M_TLAST <= 0;
            M_TVALID <= 0;
            bitmaps <= packetLimitExcursions;
            headerCount <= HEADER_COUNTER_LOAD;
            bitmapCount <= BITMAP_COUNTER_LOAD;
            if (S_TREADY && S_TLAST) begin
                fifoOutTREADY <= 1;
                state <= ST_SEND_HEADER;
            end
        end
        ST_SEND_HEADER: begin
            M_TVALID <= 1;
            M_TDATA <= fifoOutTDATA;
            if (M_TREADY) begin
                headerCount <= headerCount - 1;
                if (headerCountDone) begin
                    fifoOutTREADY <= 0;
                    state <= ST_SEND_BITMAPS;
                end
            end
        end
        ST_SEND_BITMAPS: begin
            M_TDATA <= bitmaps[BITMAPS_WIDTH-1-:8];
            bitmaps <= (bitmaps << 8);
            if (M_TREADY) begin
                bitmapCount <= bitmapCount - 1;
                if (bitmapCountDone) begin
                    fifoOutTREADY <= 1;
                    state <= ST_SEND_ADCS;
                end
            end
        end
        ST_SEND_ADCS: begin
            M_TDATA <= fifoOutTDATA;
            M_TLAST <= fifoOutTLAST;
            if (fifoOutTLAST) begin
                fifoOutTREADY <= 0;
            end
            if (M_TREADY) begin
                if (M_TLAST) begin
                    M_TVALID <= 0;
                    state <= ST_AWAIT_DATA;
                end
            end
        end
        ST_FLUSH: begin
            fifoRESETn <= 0;
            M_TLAST <= 0;
            M_TVALID <= 0;
            if (S_TVALID && S_TLAST) begin
                state <= ST_AWAIT_DATA;
            end
        end
        endcase
    end
end
endmodule
`default_nettype wire
