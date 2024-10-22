/*
 * MIT License
 *
 * Copyright (c) 2022 Osprey DCS
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
 * AXI4-Lite connection to simple bit-bash SPI.
 */

`default_nettype none

module marbleBootflash #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter C_S_AXI_ADDR_WIDTH = 2,
    parameter DEBUG              = "false",
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_DATA_WIDTH = 32
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    (*MARK_DEBUG=DEBUG*) output reg  SCK = 0,
    (*MARK_DEBUG=DEBUG*) output reg  CSB = 1,
    (*MARK_DEBUG=DEBUG*) output reg  SO = 0,
    (*MARK_DEBUG=DEBUG*) input  wire SI,
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
    (*MARK_DEBUG=DEBUG*) input  wire     s_axi_wvalid,
    output reg                           s_axi_wready = 0,
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
 * Read side
 */
always @(posedge s_axi_aclk)
begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1;
        s_axi_rvalid <= 0;
    end
    else if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid <= 1;
        s_axi_arready <= 0;
    end
    else if (s_axi_rready) begin
        s_axi_rvalid <= 0;
        s_axi_arready <= 1;
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

reg csb = 1, sck = 0, si = 0;
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        SCK <= 1;
        CSB <= 1;
        SO  <= 0;
    end
    else if (s_axi_wready) begin
        SCK <= s_axi_wdata[0];
        CSB <= s_axi_wdata[1];
        SO  <= s_axi_wdata[2];
    end
end
assign s_axi_rdata = { 28'd0, SI, SO, CSB, SCK };

endmodule

`default_nettype wire
