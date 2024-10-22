/*
 * MIT License
 *
 * Copyright (c) 2021 Osprey DCS
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
 * AXI-Lite wrapper with one additional cycle of read latency
 * Based on the excellent tutorials by Dan Gisselquist.
 *                              https://zipcpu.com/blog/2020/03/08/easyaxil.html
 */

`default_nettype none

module axi_lite_generic_reg_v3_0 #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter C_S_AXI_ADDR_WIDTH = 7,
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_DATA_WIDTH = 32
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    input wire [(1<<(C_S_AXI_ADDR_WIDTH+3-$clog2(C_S_AXI_DATA_WIDTH)))*
                                                C_S_AXI_DATA_WIDTH-1:0] GPIO_IN,
    output reg [(1<<(C_S_AXI_ADDR_WIDTH+3-$clog2(C_S_AXI_DATA_WIDTH)))-1:0]
                                                                   GPIO_STROBES,
    output reg                                [C_S_AXI_DATA_WIDTH-1:0] GPIO_OUT,
    ////////////////////// AXI-Lite Boilerplate Ports ///////////////////
    input  wire                          s_axi_aclk,
    input  wire                          s_axi_aresetn,

    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready = 1,
    input  wire                    [2:0] s_axi_arprot,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg                           s_axi_rvalid = 0,
    input  wire                          s_axi_rready,
    output wire                    [1:0] s_axi_rresp,

    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
    input  wire                    [2:0] s_axi_awprot,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready = 1,
    input  wire                    [3:0] s_axi_wstrb,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    output reg                           s_axi_bvalid = 0,
    input  wire                          s_axi_bready,
    output wire                    [1:0] s_axi_bresp);

/*
 * Static outputs -- success always
 */
assign s_axi_rresp = 2'b00;
assign s_axi_bresp = 2'b00;

/*
 * Read side -- Ensure address remains stable during cycle
 */
reg  [C_S_AXI_ADDR_WIDTH-1:0] raddrLatch;
wire [C_S_AXI_ADDR_WIDTH-1:0] raddr = s_axi_arready ? s_axi_araddr : raddrLatch;
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1;
        s_axi_rvalid <= 0;
    end
    else if (s_axi_arready) begin
        raddrLatch <= s_axi_araddr;
        if (s_axi_arvalid) begin
            s_axi_arready <= 0;
        end
    end
    else begin
        if (s_axi_rvalid) begin
            if (s_axi_rready) begin
                s_axi_rvalid <= 0;
                s_axi_arready <= 1;
            end
        end
        else begin
            s_axi_rvalid <= 1;
        end
    end
end

/*
 * Write side
 */
assign s_axi_awready = s_axi_wready;
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_wready <= 0;
    end
    else begin
        s_axi_wready <= !s_axi_wready && s_axi_awvalid && s_axi_wvalid &&
                                                (!s_axi_bvalid || s_axi_bready);
    end
    if (!s_axi_aresetn) begin
        s_axi_bvalid <= 0;
    end
    else if (s_axi_wready) begin
        s_axi_bvalid <= 1;
    end
    else if (s_axi_bready) begin
        s_axi_bvalid <= 0;
    end

end
//////////////////////// End of AXI-Lite Boilerplate ////////////////////////

/*
 * Generic register block
 */
localparam AXI_ADDR_LSB = $clog2(C_S_AXI_DATA_WIDTH) - 3;
localparam REG_INDEX_WIDTH = C_S_AXI_ADDR_WIDTH - AXI_ADDR_LSB;

wire [REG_INDEX_WIDTH-1:0] readRegIndex = raddr[AXI_ADDR_LSB+:REG_INDEX_WIDTH];
wire [REG_INDEX_WIDTH-1:0] writeRegIndex = s_axi_awaddr[AXI_ADDR_LSB+:
                                                               REG_INDEX_WIDTH];
// GPIO READ
// Help the router meet timing by providing two levels of multiplexer registers.
// Thus the need for the 'read with latency' version of AXI-Lite boilerplate.
// Hold output stable during read cycle.
localparam CHANNEL_COUNT = 1 << REG_INDEX_WIDTH;
localparam L2MUX_INPUT_COUNT = (CHANNEL_COUNT + 15) / 16;
localparam L1MUX_WIDTH = L2MUX_INPUT_COUNT * C_S_AXI_DATA_WIDTH;

reg        [L1MUX_WIDTH-1:0] l1mux;
reg [C_S_AXI_DATA_WIDTH-1:0] l2mux;
wire                   [3:0] l1MuxSel = readRegIndex[REG_INDEX_WIDTH-1-:4];
wire [REG_INDEX_WIDTH-4-1:0] l2MuxSel = readRegIndex[0+:REG_INDEX_WIDTH-4];
assign s_axi_rdata = l2mux;

always @(posedge s_axi_aclk) begin
    l1mux <= GPIO_IN[l1MuxSel*L1MUX_WIDTH+:L1MUX_WIDTH];
    l2mux <= l1mux[l2MuxSel*C_S_AXI_DATA_WIDTH+:C_S_AXI_DATA_WIDTH];
end

// GPIO WRITE
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        GPIO_STROBES <= 0;
    end
    else begin
        if (s_axi_wready && (s_axi_wstrb == 4'hF)) begin
            GPIO_STROBES[writeRegIndex] <= 1'b1;
            GPIO_OUT <= s_axi_wdata;
        end
        else begin
            GPIO_STROBES <= {CHANNEL_COUNT{1'b0}};
        end
    end
end
endmodule
`default_nettype wire
