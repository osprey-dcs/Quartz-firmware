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
 * AXI4-Lite wrapper around open-source UDP/IPv4/Ethernet stack
 * Assumes RGMII PHY with in-phase 125 MHz clock.
 * Stack doesn't seem to support sending UDP packets with 0-length payload.
 * Based on Axi-Lite example with one additional cycle of read latency.
 * Extra cycle is needed in case of back-to-back read cycles.
 */

`default_nettype none

module ospreyUDP #(
    ////////////////////// Application-specific Parameters ///////////////////
    parameter ENABLE_ICMP_ECHO = "false",
    parameter DEBUG_AXI        = "false",
    parameter DEBUG_RX         = "false",
    parameter DEBUG_RX_UDP     = "false",
    parameter DEBUG_RX_MAC     = "false",
    parameter DEBUG_TX         = "false",
    parameter DEBUG_TX_UDP     = "false",
    parameter DEBUG_TX_MAC     = "false",
    parameter DEBUG_TX_FAST    = "false",
    parameter DEBUG_ICMP       = "false",
    parameter PKBUF_CAPACITY   = 1472,
    parameter RX_FIFO_DEPTH    = 4096,
    ////////////////////// AXI-Lite Boilerplate Parameters ///////////////////
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32
    ) (
    ////////////////////// Application-specific Ports ///////////////////
    // Ethernet PHY reference
    input  wire clk125,
    // Ethernet: 1000BASE-T RGMII
    input  wire       phy_rx_clk,
    input  wire [3:0] phy_rxd,
    input  wire       phy_rx_ctl,
    output wire       phy_tx_clk,
    output wire [3:0] phy_txd,
    output wire       phy_tx_ctl,
    output wire       phy_reset_n,
    // Received packet interrupt request
    output reg        rxIRQ = 0,
    // Fast data stream (all ports are in the network clock (clk125) domain)
(*MARK_DEBUG=DEBUG_TX_FAST*) input  wire  [7:0] fastTx_tdata,
(*MARK_DEBUG=DEBUG_TX_FAST*) input  wire        fastTx_tvalid,
(*MARK_DEBUG=DEBUG_TX_FAST*) input  wire        fastTx_tlast,
(*MARK_DEBUG=DEBUG_TX_FAST*) output reg         fastTx_tready = 0,

    ////////////////////// AXI-Lite Boilerplate Ports ///////////////////
    input  wire                                            s_axi_lite_aclk,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                        s_axi_lite_aresetn,

(*MARK_DEBUG=DEBUG_AXI*)input  wire                        s_axi_lite_arvalid,
(*MARK_DEBUG=DEBUG_AXI*)output reg                         s_axi_lite_arready=1,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                   [2:0]s_axi_lite_arprot,
(*MARK_DEBUG=DEBUG_AXI*)input  wire[C_S_AXI_ADDR_WIDTH-1:0]s_axi_lite_araddr,
(*MARK_DEBUG=DEBUG_AXI*)output wire[C_S_AXI_DATA_WIDTH-1:0]s_axi_lite_rdata,
(*MARK_DEBUG=DEBUG_AXI*)output reg                         s_axi_lite_rvalid=0,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                        s_axi_lite_rready,
(*MARK_DEBUG=DEBUG_AXI*)output wire                   [1:0]s_axi_lite_rresp,

(*MARK_DEBUG=DEBUG_AXI*)input  wire                        s_axi_lite_awvalid,
                        output wire                        s_axi_lite_awready,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                   [2:0]s_axi_lite_awprot,
(*MARK_DEBUG=DEBUG_AXI*)input  wire[C_S_AXI_ADDR_WIDTH-1:0]s_axi_lite_awaddr,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                        s_axi_lite_wvalid,
(*MARK_DEBUG=DEBUG_AXI*)output reg                         s_axi_lite_wready=0,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                   [3:0]s_axi_lite_wstrb,
(*MARK_DEBUG=DEBUG_AXI*)input  wire[C_S_AXI_DATA_WIDTH-1:0]s_axi_lite_wdata,
(*MARK_DEBUG=DEBUG_AXI*)output reg                          s_axi_lite_bvalid=0,
(*MARK_DEBUG=DEBUG_AXI*)input  wire                         s_axi_lite_bready,
(*MARK_DEBUG=DEBUG_AXI*)output wire                    [1:0]s_axi_lite_bresp);

/*
 * Static outputs -- success always
 */
assign s_axi_lite_rresp = 2'b00;
assign s_axi_lite_bresp = 2'b00;

/*
 * Read side -- Ensure address remains stable during cycle
 */
reg  [C_S_AXI_ADDR_WIDTH-1:0] raddrLatch;
wire [C_S_AXI_ADDR_WIDTH-1:0] raddr = s_axi_lite_arready ? s_axi_lite_araddr : raddrLatch;
always @(posedge s_axi_lite_aclk)
begin
    if (!s_axi_lite_aresetn) begin
        s_axi_lite_arready <= 1;
        s_axi_lite_rvalid <= 0;
    end
    else if (s_axi_lite_arready) begin
        raddrLatch <= s_axi_lite_araddr;
        if (s_axi_lite_arvalid) begin
            s_axi_lite_arready <= 0;
        end
    end
    else begin
        if (s_axi_lite_rvalid) begin
            if (s_axi_lite_rready) begin
                s_axi_lite_rvalid <= 0;
                s_axi_lite_arready <= 1;
            end
        end
        else begin
            s_axi_lite_rvalid <= 1;
        end
    end
end

/*
 * Write side
 */
assign s_axi_lite_awready = s_axi_lite_wready;
always @(posedge s_axi_lite_aclk)
begin
    if (!s_axi_lite_aresetn) begin
        s_axi_lite_wready <= 0;
    end
    else begin
        s_axi_lite_wready <= !s_axi_lite_wready &&
                              s_axi_lite_awvalid &&
                              s_axi_lite_wvalid &&
                              (!s_axi_lite_bvalid || s_axi_lite_bready);
    end
    if (!s_axi_lite_aresetn) begin
        s_axi_lite_bvalid <= 0;
    end
    else if (s_axi_lite_wready) begin
        s_axi_lite_bvalid <= 1;
    end
    else if (s_axi_lite_bready) begin
        s_axi_lite_bvalid <= 0;
    end

end
//////////////////////// End of AXI-Lite Boilerplate ////////////////////////

localparam PK_BYTE_COUNT_WIDTH = $clog2(PKBUF_CAPACITY+1);

(*MARK_DEBUG=DEBUG_AXI*) wire sysCsrStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysTxDataStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysTxDestAddrStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysTxPortsStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysTxLengthStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysMACloStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysMAChiStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysLocalAddrStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysGatewayStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysNetmaskStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire sysRxDataStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire fastTxDestAddrStrobe;
(*MARK_DEBUG=DEBUG_AXI*) wire fastTxPortsStrobe;
assign sysCsrStrobe       = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h0);
assign sysTxDataStrobe    = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h1);
assign sysTxDestAddrStrobe= s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h2);
assign sysTxPortsStrobe   = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h3);
assign sysTxLengthStrobe  = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h4);
assign sysMACloStrobe     = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h5);
assign sysMAChiStrobe     = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h6);
assign sysLocalAddrStrobe = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h7);
assign sysGatewayStrobe   = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h8);
assign sysNetmaskStrobe   = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'h9);
assign fastTxDestAddrStrobe=s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'hA);
assign fastTxPortsStrobe  = s_axi_lite_wready&&(s_axi_lite_awaddr[5:2] == 4'hB);
assign sysRxDataStrobe    = s_axi_lite_rvalid && s_axi_lite_rready &&
                                                           (raddr[5:2] == 4'h1);

// Enable/disable network stack
reg sysResetn = 0;

// Dual-port RAM
localparam PKBUF_WORD_ADDR_WIDTH = $clog2((PKBUF_CAPACITY+3)/4);
reg [31:0] rxBuf [0:(1<<PKBUF_WORD_ADDR_WIDTH)-1], rxBufQ;
reg [31:0] txBuf [0:(1<<PKBUF_WORD_ADDR_WIDTH)-1], txBufQ;
reg [31:0] fastTxBuf [0:(1<<PKBUF_WORD_ADDR_WIDTH)-1], fastTxBufQ;

//////////////////////////////////////////////////////////////////////////////
// System clock domain

// Synchronize reset requests
(*ASYNC_REG="true"*) reg peripheralReset_m = 1;
reg peripheralReset = 1;
always @(posedge s_axi_lite_aclk) begin
    peripheralReset_m <= !s_axi_lite_aresetn;
    peripheralReset   <= peripheralReset_m;
    if (peripheralReset) begin
        sysResetn <= 0;
    end
    else if (sysCsrStrobe) begin
        case (s_axi_lite_wdata[31:30])
        2'b01: sysResetn <= 0;
        2'b10: sysResetn <= 1;
        default: ;
        endcase
    end
end

// System side of dual port RAM
reg [PKBUF_WORD_ADDR_WIDTH-1:0] sysPkAddr;
always @(posedge s_axi_lite_aclk) begin
    if (sysTxDataStrobe) begin
        txBuf[sysPkAddr] <= s_axi_lite_wdata;
    end
    rxBufQ <= rxBuf[sysPkAddr];
end
always @(posedge s_axi_lite_aclk) begin
    if (sysCsrStrobe) begin
        sysPkAddr <= s_axi_lite_wdata[0+:PKBUF_WORD_ADDR_WIDTH];
    end
    else if (sysTxDataStrobe || sysRxDataStrobe) begin
        sysPkAddr <= sysPkAddr + 1;
    end
end

// Configuration
reg [47:0] local_mac;
reg [31:0] local_ip;
reg [31:0] gateway_ip;
reg [31:0] subnet_mask;
always @(posedge s_axi_lite_aclk) begin
    if (sysMACloStrobe)      local_mac[0+:32]  <= s_axi_lite_wdata;
    if (sysMAChiStrobe)      local_mac[32+:16] <= s_axi_lite_wdata[0+:16];
    if (sysLocalAddrStrobe)  local_ip          <= s_axi_lite_wdata;
    if (sysGatewayStrobe)    gateway_ip        <= s_axi_lite_wdata;
    if (sysNetmaskStrobe)    subnet_mask       <= s_axi_lite_wdata;
end

// Packet transmission
reg [31:0] sysTxDestinationAddress;
reg [15:0] sysTxSourcePort, sysTxDestinationPort;
reg [PK_BYTE_COUNT_WIDTH-1:0] sysTxLength;
reg [31:0] fastTxDestinationAddress;
reg [15:0] fastTxSourcePort, fastTxDestinationPort;
reg sysTxStartToggle = 0;
(*MARK_DEBUG=DEBUG_TX*) reg txDoneToggle = 0;
(*ASYNC_REG="true"*) reg sysTxDoneToggle_m = 0;
reg sysTxDoneToggle = 0;
wire sysTxBusy = (sysTxStartToggle ^ txDoneToggle);
reg sysTxOverrun = 0;
always @(posedge s_axi_lite_aclk) begin
    if (!sysResetn) begin
        sysTxDoneToggle_m <= 0;
        sysTxDoneToggle   <= 0;
        sysTxStartToggle  <= 0;
    end
    else begin
        if (sysCsrStrobe && s_axi_lite_wdata[29]) begin
            if (sysTxBusy) begin
                sysTxOverrun <= 1;
            end
            else begin
                sysTxOverrun <= 0;
                sysTxStartToggle <= !sysTxStartToggle;
            end
        end
        sysTxDoneToggle_m <= txDoneToggle;
        sysTxDoneToggle   <= sysTxDoneToggle_m;
    end
    if (sysTxDestAddrStrobe) begin
        sysTxDestinationAddress <= s_axi_lite_wdata;
    end
    if (sysTxPortsStrobe) begin
        sysTxDestinationPort <= s_axi_lite_wdata[0+:16];
        sysTxSourcePort <= s_axi_lite_wdata[16+:16];
    end
    if (sysTxLengthStrobe) begin
        sysTxLength <= s_axi_lite_wdata[0+:PK_BYTE_COUNT_WIDTH];
    end
    if (fastTxDestAddrStrobe) begin
        fastTxDestinationAddress <= s_axi_lite_wdata;
    end
    if (fastTxPortsStrobe) begin
        fastTxDestinationPort <= s_axi_lite_wdata[0+:16];
        fastTxSourcePort <= s_axi_lite_wdata[16+:16];
    end
end

// Packet reception
// Receiver control/status
reg sysRxDoneToggle = 0;
(*MARK_DEBUG=DEBUG_RX*) reg rxFullToggle = 0;
(*ASYNC_REG="true"*) reg sysRxFullToggle_m = 0;
reg sysRxFullToggle = 0;
wire rxPacketPresent = (sysRxDoneToggle ^ sysRxFullToggle);
reg  rxInterruptEnable = 0;

always @(posedge s_axi_lite_aclk) begin
    if (!sysResetn) begin
        sysRxFullToggle_m <= 0;
        sysRxFullToggle   <= 0;
        sysRxDoneToggle   <= 0;
        rxInterruptEnable <= 0;
        rxIRQ <= 0;
    end
    else begin
        rxIRQ <= (rxPacketPresent && rxInterruptEnable);
        if (sysCsrStrobe) begin
            if (s_axi_lite_wdata[28] && rxPacketPresent) begin
                sysRxDoneToggle <= !sysRxDoneToggle;
            end
            if (s_axi_lite_wdata[25]) begin
                rxInterruptEnable <= 0;
            end
            else if (s_axi_lite_wdata[24]) begin
                rxInterruptEnable <= 1;
            end
        end
        sysRxFullToggle_m <= rxFullToggle;
        sysRxFullToggle   <= sysRxFullToggle_m;
    end
end

// Status register
wire [1:0] speed;
wire [31:0]  sysStatus = { 1'b0, !sysResetn, sysTxBusy, rxPacketPresent,
                           2'b0, sysTxOverrun, rxInterruptEnable,
                           2'b0, speed,
                           {20-PKBUF_WORD_ADDR_WIDTH{1'b0}}, sysPkAddr };

// Multiplex AXI read data
reg  [31:0] rdMux;
wire [31:0] sysRxSourceAddress;
wire [31:0] sysRxPorts;
wire [31:0] sysRxLength;
always @(posedge s_axi_lite_aclk) begin
    case (raddr[5:2])
    4'h0:   rdMux <= sysStatus;
    4'h1:   rdMux <= rxBufQ;
    4'h2:   rdMux <= sysRxSourceAddress;
    4'h3:   rdMux <= sysRxPorts;
    4'h4:   rdMux <= sysRxLength;
    4'h5:   rdMux <= local_mac[0+:32];
    4'h6:   rdMux <= {16'h0000, local_mac[32+:16]};
    4'h7:   rdMux <= local_ip;
    4'h8:   rdMux <= gateway_ip;
    4'h9:   rdMux <= subnet_mask;
    default: ;
    endcase
end
assign s_axi_lite_rdata = rdMux;

//////////////////////////////////////////////////////////////////////////////
// Network stack clock domain

// Network stack side of dual port RAM
(*MARK_DEBUG=DEBUG_TX*) wire txReadEnable;
(*MARK_DEBUG=DEBUG_TX*) reg [PKBUF_WORD_ADDR_WIDTH-1:0] txRdAddr;
(*MARK_DEBUG=DEBUG_TX*) reg [1:0] txByteSelect;
always @(posedge clk125) begin
    if (txReadEnable) begin
        txBufQ <= txBuf[txRdAddr];
        fastTxBufQ <= fastTxBuf[txRdAddr];
    end
end
(*MARK_DEBUG=DEBUG_TX*) wire [7:0] txBufByte;
(*MARK_DEBUG=DEBUG_RX*) reg [PKBUF_WORD_ADDR_WIDTH-1:0] rxWrAddr;
(*MARK_DEBUG=DEBUG_RX*) wire                      [7:0] rxWrData;
(*MARK_DEBUG=DEBUG_RX*) wire                      [3:0] rxWrEnable;
genvar b;
generate;
for (b = 0 ; b < 4 ; b = b + 1) begin : rxByteWrite
    always @(posedge clk125) begin
        if (rxWrEnable[b]) rxBuf[rxWrAddr][b*8+:8] <= rxWrData;
    end
end
endgenerate

// Synchronize reset requests
(*ASYNC_REG="true"*) reg resetStack_m = 1;
reg resetStack = 1;
always @(posedge clk125) begin
    resetStack_m <= !sysResetn;
    resetStack   <= resetStack_m;
end
assign phy_reset_n = !resetStack;

// UDP frame I/O
(*MARK_DEBUG=DEBUG_RX_UDP*) wire rx_udp_hdr_valid;
(*MARK_DEBUG=DEBUG_RX_UDP*) reg  rx_udp_hdr_ready  = 0;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [47:0] rx_udp_eth_dest_mac;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [47:0] rx_udp_eth_src_mac;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_eth_type;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [3:0] rx_udp_ip_version;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [3:0] rx_udp_ip_ihl;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [5:0] rx_udp_ip_dscp;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [1:0] rx_udp_ip_ecn;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_ip_length;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_ip_identification;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [2:0] rx_udp_ip_flags;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [12:0] rx_udp_ip_fragment_offset;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [7:0] rx_udp_ip_ttl;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [7:0] rx_udp_ip_protocol;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_ip_header_checksum;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [31:0] rx_udp_ip_source_ip;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [31:0] rx_udp_ip_dest_ip;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_source_port;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_dest_port;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_length;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [15:0] rx_udp_checksum;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire [7:0] rx_udp_payload_axis_tdata;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire rx_udp_payload_axis_tvalid;
(*MARK_DEBUG=DEBUG_RX_UDP*) reg  rx_udp_payload_axis_tready = 0;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire rx_udp_payload_axis_tlast;
(*MARK_DEBUG=DEBUG_RX_UDP*) wire rx_udp_payload_axis_tuser;
(*MARK_DEBUG=DEBUG_TX_UDP*) reg         tx_udp_hdr_valid = 0;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire        tx_udp_hdr_ready;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire  [5:0] tx_udp_ip_dscp = 0;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire  [1:0] tx_udp_ip_ecn = 0;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire  [7:0] tx_udp_ip_ttl = 16;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire [31:0] tx_udp_ip_source_ip = local_ip;
(*MARK_DEBUG=DEBUG_TX_UDP*) reg  [31:0] tx_udp_ip_dest_ip;
(*MARK_DEBUG=DEBUG_TX_UDP*) reg  [15:0] tx_udp_source_port;
(*MARK_DEBUG=DEBUG_TX_UDP*) reg  [15:0] tx_udp_dest_port;
(*MARK_DEBUG=DEBUG_TX_UDP*) reg  [15:0] tx_udp_length;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire [15:0] tx_udp_checksum = 0;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire  [7:0] tx_udp_payload_axis_tdata = txBufByte;
(*MARK_DEBUG=DEBUG_TX_UDP*) reg         tx_udp_payload_axis_tvalid = 0;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire        tx_udp_payload_axis_tready;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire        tx_udp_payload_axis_tlast;
(*MARK_DEBUG=DEBUG_TX_UDP*) wire        tx_udp_payload_axis_tuser = 0;

// Packet reception
(*ASYNC_REG="true"*) reg rxDoneToggle_m = 0;
(*MARK_DEBUG=DEBUG_RX*) reg rxDoneToggle = 0;
localparam RX_S_IDLE  = 2'd0,
           RX_S_ACCEPT= 2'd1,
           RX_S_FULL  = 2'd2;
(*MARK_DEBUG=DEBUG_RX*) reg [1:0] rxState = RX_S_IDLE;
(*MARK_DEBUG=DEBUG_RX*) reg rxBadPacket;
(*MARK_DEBUG=DEBUG_RX*) reg                      [31:0] rxSourceAddress;
(*MARK_DEBUG=DEBUG_RX*) reg                      [31:0] rxPorts;
(*MARK_DEBUG=DEBUG_RX*) reg   [PK_BYTE_COUNT_WIDTH-1:0] rxLength;
(*MARK_DEBUG=DEBUG_RX*) reg                       [3:0] rxByteSelect = 0;
assign rxWrEnable = rxByteSelect & {4{rx_udp_payload_axis_tvalid &&
                                      rx_udp_payload_axis_tready}};
assign rxWrData = rx_udp_payload_axis_tdata;
always @(posedge clk125) begin
    if (resetStack) begin
        rxDoneToggle_m             <= 0;
        rxDoneToggle               <= 0;
        rxFullToggle               <= 0;
        rx_udp_hdr_ready           <= 1;
        rx_udp_payload_axis_tready <= 0;
    end
    else begin
        rxDoneToggle_m <= sysRxDoneToggle;
        rxDoneToggle   <= rxDoneToggle_m;
        case (rxState)
        RX_S_IDLE: begin
            rxWrAddr <= 0;
            rxByteSelect = 4'b0001;
            rxBadPacket <= 0;
            if (rx_udp_hdr_valid) begin
                rxSourceAddress <= rx_udp_ip_source_ip;
                rxPorts <= {rx_udp_source_port, rx_udp_dest_port};
                rxLength <= rx_udp_length - 8;
                rx_udp_hdr_ready <= 0;
                rx_udp_payload_axis_tready <= 1;
                rxState <= RX_S_ACCEPT;
            end
        end
        RX_S_ACCEPT: begin
            if (rx_udp_payload_axis_tvalid) begin
                if (rxByteSelect == 4'b1000) begin
                    rxWrAddr <= rxWrAddr + 1;
                end
                rxByteSelect <= { rxByteSelect[2:0], rxByteSelect[3] };
                if (rx_udp_payload_axis_tuser) begin
                    rxBadPacket <= 1;
                end
                if (rx_udp_payload_axis_tlast) begin
                    rx_udp_payload_axis_tready <= 0;
                    if (rxBadPacket || rx_udp_payload_axis_tuser) begin
                        rx_udp_hdr_ready <= 1;
                        rxState <= RX_S_IDLE;
                    end
                    else begin
                        rxFullToggle <= !rxFullToggle;
                        rxState <= RX_S_FULL;
                    end
                end
            end
        end
        RX_S_FULL: begin
            if (rxDoneToggle == rxFullToggle) begin
                rx_udp_hdr_ready <= 1;
                rxState <= RX_S_IDLE;
            end
        end
        default: begin
            rx_udp_hdr_ready <= 1;
            rx_udp_payload_axis_tready <= 0;
            rxState <= RX_S_IDLE;
        end
        endcase
    end
end

/*
 * No need for clock-crossing logic.
 * Values will be used only when stable
 */
assign sysRxSourceAddress = rxSourceAddress;
assign sysRxPorts = rxPorts;
assign sysRxLength = { {32-PK_BYTE_COUNT_WIDTH{1'b0}}, rxLength};

// Fast data stream support
reg fastTxFlushToggle = 0, fastTxFlushDone = 0;
reg fastTxStartToggle = 0, fastTxDoneToggle = 0;
(*MARK_DEBUG=DEBUG_TX_FAST*) reg [PK_BYTE_COUNT_WIDTH-1:0] fastTxCount = 0;
wire [PKBUF_WORD_ADDR_WIDTH-1:0] fastTxWrAddr =
                                           fastTxCount[PK_BYTE_COUNT_WIDTH-1:2];
wire [1:0] fastTxWrByteSel = fastTxCount[1:0];
reg fastTx = 0;

// Single-clock, simple dual port RAM (from Verilog template)
genvar i;
generate
localparam NB_COL    = 4;
localparam COL_WIDTH = 8;
wire [NB_COL-1:0] fastTxBufWriteEnable;
    for (i = 0; i < NB_COL; i = i+1) begin: byte_write
        assign fastTxBufWriteEnable[i] = fastTx_tready && fastTx_tvalid &&
                                                         (fastTxWrByteSel == i);
        always @(posedge clk125) begin
            if (fastTxBufWriteEnable[i]) begin
                fastTxBuf[fastTxWrAddr][(i+1)*COL_WIDTH-1:i*COL_WIDTH] <=
                                                                   fastTx_tdata;
            end
        end
    end
endgenerate
always @(posedge clk125) begin
    if (fastTxFlushToggle != fastTxFlushDone) begin
        fastTxCount <= 0;
        if (fastTx_tvalid) begin
            fastTx_tready <= 1;
        end
        else begin
            fastTx_tready <= 0;
            fastTxFlushDone <= fastTxFlushToggle;
        end
    end
    else begin
        if (fastTxStartToggle == fastTxDoneToggle) begin
            if (fastTx_tready) begin
                if (fastTx_tvalid) begin
                    fastTxCount <= fastTxCount + 1;
                    if (fastTx_tlast) begin
                        fastTxStartToggle <= !fastTxStartToggle;
                        fastTx_tready <= 0;
                    end
                end
            end
            else begin
                fastTxCount <= 0;
                fastTx_tready <= 1;
            end
        end
    end
end

// Packet transmission
(*ASYNC_REG="true"*) reg txStartToggle_m = 0;
(*MARK_DEBUG=DEBUG_TX*) reg txStartToggle = 0;
localparam TX_COUNTER_WIDTH = PK_BYTE_COUNT_WIDTH + 1;
(*MARK_DEBUG=DEBUG_TX*) reg [TX_COUNTER_WIDTH-1:0] txCounter;
assign tx_udp_payload_axis_tlast = txCounter[TX_COUNTER_WIDTH-1];
localparam TX_S_IDLE        = 2'd0,
           TX_S_SEND_HEADER = 2'd1,
           TX_S_SEND_DATA   = 2'd2;
(*MARK_DEBUG=DEBUG_TX*) reg [1:0] txState = TX_S_IDLE;
(*MARK_DEBUG=DEBUG_TX*) reg txBad = 0;
assign txReadEnable = (txState == TX_S_SEND_HEADER)
                   || (tx_udp_payload_axis_tvalid
                    && tx_udp_payload_axis_tready
                    && (txByteSelect == 2'h3));
assign txBufByte = fastTx ? fastTxBufQ[txByteSelect*8+:8] :
                            txBufQ[txByteSelect*8+:8];
always @(posedge clk125) begin
    if (resetStack || txBad) begin
        txState <= TX_S_IDLE;
        txBad <= 0;
        txStartToggle_m <= 0;
        txStartToggle <= 0;
        txDoneToggle <= 0;
        tx_udp_hdr_valid <= 0;
        tx_udp_payload_axis_tvalid <= 0;
        fastTxFlushToggle <= fastTxFlushDone;
    end
    else begin
        txStartToggle_m <= sysTxStartToggle;
        txStartToggle <= txStartToggle_m;
        case (txState)
        TX_S_IDLE: begin
            txByteSelect <= 0;
            txRdAddr <= 0;
            if (fastTxDoneToggle != fastTxStartToggle) begin
                tx_udp_ip_dest_ip <= fastTxDestinationAddress;
                tx_udp_dest_port <= fastTxDestinationPort;
                tx_udp_source_port <= fastTxSourcePort;
                tx_udp_length <= fastTxCount + 8;
                txCounter <= fastTxCount - 2;
                fastTx <= 1;
                txState <= TX_S_SEND_HEADER;
                tx_udp_hdr_valid <= 1;
            end
            else if (txDoneToggle != txStartToggle) begin
                tx_udp_ip_dest_ip <= sysTxDestinationAddress;
                tx_udp_dest_port <= sysTxDestinationPort;
                tx_udp_source_port <= sysTxSourcePort;
                tx_udp_length <= sysTxLength + 8;
                txCounter <= sysTxLength - 2;
                fastTx <= 0;
                txState <= TX_S_SEND_HEADER;
                tx_udp_hdr_valid <= 1;
            end
        end
        TX_S_SEND_HEADER: begin
            if (tx_udp_hdr_ready) begin
                tx_udp_hdr_valid <= 0;
                txState <= TX_S_SEND_DATA;
                tx_udp_payload_axis_tvalid <= 1;
                txRdAddr <= txRdAddr + 1;
            end
        end
        TX_S_SEND_DATA: begin
            if (tx_udp_payload_axis_tready) begin
                txCounter <= txCounter - 1;
                txByteSelect <= txByteSelect + 1;
                if (txByteSelect == 2'h3) begin
                    txRdAddr <= txRdAddr + 1;
                end
                if (tx_udp_payload_axis_tlast) begin
                    tx_udp_payload_axis_tvalid <= 0;
                    if (fastTx) begin
                        fastTxDoneToggle <= !fastTxDoneToggle;
                    end
                    else begin
                        txDoneToggle <= !txDoneToggle;
                    end
                    txState <= TX_S_IDLE;
                end
            end
        end
        default: txBad <= 1;
        endcase
    end
end

// UDP frame I/O
// AXI streams between MAC and Ethernet modules
(*MARK_DEBUG=DEBUG_RX_MAC*) wire [7:0] rx_axis_tdata;
(*MARK_DEBUG=DEBUG_RX_MAC*) wire rx_axis_tvalid;
(*MARK_DEBUG=DEBUG_RX_MAC*) wire rx_axis_tready;
(*MARK_DEBUG=DEBUG_RX_MAC*) wire rx_axis_tlast;
(*MARK_DEBUG=DEBUG_RX_MAC*) wire rx_axis_tuser;
(*MARK_DEBUG=DEBUG_TX_MAC*) wire [7:0] tx_axis_tdata;
(*MARK_DEBUG=DEBUG_TX_MAC*) wire tx_axis_tvalid;
(*MARK_DEBUG=DEBUG_TX_MAC*) wire tx_axis_tready;
(*MARK_DEBUG=DEBUG_TX_MAC*) wire tx_axis_tlast;
(*MARK_DEBUG=DEBUG_TX_MAC*) wire tx_axis_tuser;

// Ethernet frame between Ethernet and UDP stack modules
wire rx_eth_hdr_ready;
wire rx_eth_hdr_valid;
wire [47:0] rx_eth_dest_mac;
wire [47:0] rx_eth_src_mac;
wire [15:0] rx_eth_type;
wire [7:0] rx_eth_payload_axis_tdata;
wire rx_eth_payload_axis_tvalid;
wire rx_eth_payload_axis_tready;
wire rx_eth_payload_axis_tlast;
wire rx_eth_payload_axis_tuser;
wire tx_eth_hdr_ready;
wire tx_eth_hdr_valid;
wire [47:0] tx_eth_dest_mac;
wire [47:0] tx_eth_src_mac;
wire [15:0] tx_eth_type;
wire [7:0] tx_eth_payload_axis_tdata;
wire tx_eth_payload_axis_tvalid;
wire tx_eth_payload_axis_tready;
wire tx_eth_payload_axis_tlast;
wire tx_eth_payload_axis_tuser;

// IPv4 frame between IP and UDP stack modules
(*MARK_DEBUG=DEBUG_ICMP*) wire rx_ip_hdr_valid;
wire rx_ip_hdr_ready;
wire [47:0] rx_ip_eth_dest_mac;
wire [47:0] rx_ip_eth_src_mac;
wire [15:0] rx_ip_eth_type;
wire [3:0] rx_ip_version;
wire [3:0] rx_ip_ihl;
wire [5:0] rx_ip_dscp;
wire [1:0] rx_ip_ecn;
wire [15:0] rx_ip_length;
wire [15:0] rx_ip_identification;
wire [2:0] rx_ip_flags;
wire [12:0] rx_ip_fragment_offset;
wire [7:0] rx_ip_ttl;
wire [7:0] rx_ip_protocol;
wire [15:0] rx_ip_header_checksum;
wire [31:0] rx_ip_source_ip;
wire [31:0] rx_ip_dest_ip;
(*MARK_DEBUG=DEBUG_ICMP*) wire [7:0] rx_ip_payload_axis_tdata;
(*MARK_DEBUG=DEBUG_ICMP*) wire rx_ip_payload_axis_tvalid;
wire rx_ip_payload_axis_tready;
(*MARK_DEBUG=DEBUG_ICMP*) wire rx_ip_payload_axis_tlast;
(*MARK_DEBUG=DEBUG_ICMP*) wire rx_ip_payload_axis_tuser;
wire tx_ip_hdr_valid;
wire tx_ip_hdr_ready;
wire [5:0] tx_ip_dscp;
wire [1:0] tx_ip_ecn;
wire [15:0] tx_ip_length;
wire [7:0] tx_ip_ttl;
wire [7:0] tx_ip_protocol;
wire [31:0] tx_ip_source_ip;
wire [31:0] tx_ip_dest_ip;
(*MARK_DEBUG=DEBUG_ICMP*) wire [7:0] tx_ip_payload_axis_tdata;
(*MARK_DEBUG=DEBUG_ICMP*) wire tx_ip_payload_axis_tvalid;
(*MARK_DEBUG=DEBUG_ICMP*) wire tx_ip_payload_axis_tready;
(*MARK_DEBUG=DEBUG_ICMP*) wire tx_ip_payload_axis_tlast;
wire tx_ip_payload_axis_tuser;
wire [7:0] rx_fifo_udp_payload_axis_tdata;
wire rx_fifo_udp_payload_axis_tvalid;
wire rx_fifo_udp_payload_axis_tready;
wire rx_fifo_udp_payload_axis_tlast;
wire rx_fifo_udp_payload_axis_tuser;
wire [7:0] tx_fifo_udp_payload_axis_tdata;
wire tx_fifo_udp_payload_axis_tvalid;
wire tx_fifo_udp_payload_axis_tready;
wire tx_fifo_udp_payload_axis_tlast;
wire tx_fifo_udp_payload_axis_tuser;

generate
if (ENABLE_ICMP_ECHO=="true") begin
localparam ICMP_ECHO_CAPACITY = 64;
localparam ICMP_ECHO_ADDRESS_WIDTH=$clog2(ICMP_ECHO_CAPACITY);
localparam ICMP_ECHO_DATA_COUNTER_WIDTH = ICMP_ECHO_ADDRESS_WIDTH+1;

(*MARK_DEBUG=DEBUG_ICMP*)
reg [ICMP_ECHO_DATA_COUNTER_WIDTH-1:0] icmp_echo_data_counter;
wire icmp_echo_tlast = icmp_echo_data_counter[ICMP_ECHO_DATA_COUNTER_WIDTH-1];
(*MARK_DEBUG=DEBUG_ICMP*) reg[ICMP_ECHO_ADDRESS_WIDTH-1:0]icmp_echo_ram_address;
reg [7:0] icmp_echo_ram [0:ICMP_ECHO_CAPACITY-1];
(*MARK_DEBUG=DEBUG_ICMP*) reg [7:0] icmp_echo_ram_q;
(*MARK_DEBUG=DEBUG_ICMP*) reg [2:0] icmp_echo_header_counter;
wire icmp_echo_in_header = icmp_echo_header_counter[2];
(*MARK_DEBUG=DEBUG_ICMP*) wire icmp_echo_data_write_enable =
                                     rx_ip_payload_axis_tvalid &&
                                     (icmp_echo_state == ICMP_ECHO_S_RECEIVING);
(*MARK_DEBUG=DEBUG_ICMP*) wire icmp_echo_data_read_enable =
                                    (icmp_echo_state == ICMP_ECHO_S_SEND_HEADER)
                                  || ((icmp_echo_state == ICMP_ECHO_S_SENDING)
                                   && tx_ip_payload_axis_tready);
(*MARK_DEBUG=DEBUG_ICMP*) wire [7:0] icmp_echo_tx_tdata =
                icmp_echo_header_counter == 3'h7 ? 8'h00 :
                icmp_echo_header_counter == 3'h5 ? icmp_echo_tx_checksum[15:8] :
                icmp_echo_header_counter == 3'h4 ? icmp_echo_tx_checksum[7:0] :
                icmp_echo_ram_q;
localparam ICMP_ECHO_S_IDLE        = 2'h0,
           ICMP_ECHO_S_RECEIVING   = 2'h1,
           ICMP_ECHO_S_SEND_HEADER = 2'h2,
           ICMP_ECHO_S_SENDING     = 2'h3;
(*MARK_DEBUG=DEBUG_ICMP*) reg [1:0] icmp_echo_state = ICMP_ECHO_S_IDLE;
(*MARK_DEBUG=DEBUG_ICMP*) reg [15:0] icmp_echo_rx_checksum;
(*MARK_DEBUG=DEBUG_ICMP*) reg        icmp_echo_tx_ip_hdr_valid = 0;
(*MARK_DEBUG=DEBUG_ICMP*) reg        icmp_echo_tx_tvalid = 0;
(*MARK_DEBUG=DEBUG_ICMP*) reg [31:0] icmp_echo_tx_dest_ip;
(*MARK_DEBUG=DEBUG_ICMP*) reg [15:0] icmp_echo_tx_ip_length;
(*MARK_DEBUG=DEBUG_ICMP*) reg [15:0] icmp_echo_tx_checksum;

always @(posedge clk125) begin
    icmp_echo_tx_checksum <= icmp_echo_rx_checksum +
                    ((icmp_echo_rx_checksum >= 16'hf7FF) ? 16'h0801 : 16'h0800);
    if (icmp_echo_data_write_enable) begin
        icmp_echo_ram[icmp_echo_ram_address] <= rx_ip_payload_axis_tdata;
    end
    if (icmp_echo_data_read_enable) begin
        icmp_echo_ram_q <= icmp_echo_ram[icmp_echo_ram_address];
    end
    case (icmp_echo_state)
    ICMP_ECHO_S_IDLE: begin
        icmp_echo_header_counter <= 3'h7;
        icmp_echo_data_counter <= rx_ip_length - 20 - 2;
        icmp_echo_tx_ip_length <= rx_ip_length;
        icmp_echo_ram_address <= 0;
        icmp_echo_tx_dest_ip  <= rx_ip_source_ip;
        if (rx_ip_hdr_valid
         && (rx_ip_protocol == 8'h01)
         && (rx_ip_length <= (20 + ICMP_ECHO_CAPACITY))
         && (rx_ip_dest_ip == local_ip)) begin
            icmp_echo_state <= ICMP_ECHO_S_RECEIVING;
        end
    end
    ICMP_ECHO_S_RECEIVING: begin
        if (rx_ip_payload_axis_tvalid) begin
            icmp_echo_data_counter <= icmp_echo_data_counter - 1;
            if ((rx_ip_payload_axis_tlast != icmp_echo_tlast)
             || (rx_ip_payload_axis_tlast && rx_ip_payload_axis_tuser)) begin
                icmp_echo_state <= ICMP_ECHO_S_IDLE;
            end
            else if (icmp_echo_tlast && rx_ip_payload_axis_tlast) begin
                icmp_echo_tx_ip_hdr_valid <= 1;
                icmp_echo_ram_address <= 0;
                icmp_echo_state <= ICMP_ECHO_S_SEND_HEADER;
            end
            else begin
                icmp_echo_ram_address <= icmp_echo_ram_address + 1;
                if (icmp_echo_in_header) begin
                    icmp_echo_header_counter <= icmp_echo_header_counter - 1;
                    case (icmp_echo_header_counter[1:0])
                    2'h3: if (rx_ip_payload_axis_tdata != 8'h08)
                                            icmp_echo_state <= ICMP_ECHO_S_IDLE;
                    2'h1: icmp_echo_rx_checksum[15:8]<=rx_ip_payload_axis_tdata;
                    2'h0: icmp_echo_rx_checksum[7:0] <=rx_ip_payload_axis_tdata;
                    default: ;
                        endcase
                end
            end
        end
    end
    ICMP_ECHO_S_SEND_HEADER: begin
        icmp_echo_header_counter <= 3'h7;
        icmp_echo_data_counter <= rx_ip_length - 20 - 2;
        if (tx_ip_hdr_ready) begin
            icmp_echo_tx_ip_hdr_valid <= 0;
            icmp_echo_tx_tvalid <= 1;
            icmp_echo_ram_address <= icmp_echo_ram_address + 1;
            icmp_echo_state <= ICMP_ECHO_S_SENDING;
        end
    end
    ICMP_ECHO_S_SENDING: begin
        if (tx_ip_payload_axis_tready) begin
            icmp_echo_data_counter <= icmp_echo_data_counter - 1;
            icmp_echo_ram_address <= icmp_echo_ram_address + 1;
            if (icmp_echo_in_header) begin
                icmp_echo_header_counter <= icmp_echo_header_counter - 1;
            end
            if (icmp_echo_tlast) begin
                icmp_echo_tx_tvalid <= 0;
                icmp_echo_state <= ICMP_ECHO_S_IDLE;
            end
        end
    end
    default: icmp_echo_state <= ICMP_ECHO_S_IDLE;
    endcase
end

assign rx_ip_hdr_ready = 1;
assign rx_ip_payload_axis_tready = 1;
assign tx_ip_hdr_valid = icmp_echo_tx_ip_hdr_valid;
assign tx_ip_dscp = 0;
assign tx_ip_ecn = 0;
assign tx_ip_length = icmp_echo_tx_ip_length;
assign tx_ip_ttl = 16;
assign tx_ip_protocol = 8'h01;
assign tx_ip_source_ip = local_ip;
assign tx_ip_dest_ip = icmp_echo_tx_dest_ip;
assign tx_ip_payload_axis_tdata = icmp_echo_tx_tdata;
assign tx_ip_payload_axis_tvalid = icmp_echo_tx_tvalid;
assign tx_ip_payload_axis_tlast = icmp_echo_tlast;
assign tx_ip_payload_axis_tuser = 0;

end
else begin

// IP ports not used
assign rx_ip_hdr_ready = 1;
assign rx_ip_payload_axis_tready = 1;
assign tx_ip_hdr_valid = 0;
assign tx_ip_dscp = 0;
assign tx_ip_ecn = 0;
assign tx_ip_length = 0;
assign tx_ip_ttl = 0;
assign tx_ip_protocol = 0;
assign tx_ip_source_ip = 0;
assign tx_ip_dest_ip = 0;
assign tx_ip_payload_axis_tdata = 0;
assign tx_ip_payload_axis_tvalid = 0;
assign tx_ip_payload_axis_tlast = 0;
assign tx_ip_payload_axis_tuser = 0;

end
endgenerate

eth_mac_1g_rgmii_fifo #(
    .TARGET("XILINX"),
    .IODDR_STYLE("IODDR"),
    .CLOCK_INPUT_STYLE("BUFR"),
    .USE_CLK90("FALSE"),
    .ENABLE_PADDING(1),
    .MIN_FRAME_LENGTH(64),
    .TX_FIFO_DEPTH(4096),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .RX_FRAME_FIFO(1)
)
eth_mac_inst (
    .gtx_clk(clk125),
    .gtx_clk90(1'b0),
    .gtx_rst(resetStack),
    .logic_clk(clk125),
    .logic_rst(resetStack),

    .tx_axis_tdata(tx_axis_tdata),
    .tx_axis_tkeep(1'b1),
    .tx_axis_tvalid(tx_axis_tvalid),
    .tx_axis_tready(tx_axis_tready),
    .tx_axis_tlast(tx_axis_tlast),
    .tx_axis_tuser(tx_axis_tuser),

    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tkeep(),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tready(rx_axis_tready),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),

    .rgmii_rx_clk(phy_rx_clk),
    .rgmii_rxd(phy_rxd),
    .rgmii_rx_ctl(phy_rx_ctl),
    .rgmii_tx_clk(phy_tx_clk),
    .rgmii_txd(phy_txd),
    .rgmii_tx_ctl(phy_tx_ctl),

    .tx_error_underflow(),
    .tx_fifo_overflow(),
    .tx_fifo_bad_frame(),
    .tx_fifo_good_frame(),
    .rx_error_bad_frame(),
    .rx_error_bad_fcs(),
    .rx_fifo_overflow(),
    .rx_fifo_bad_frame(),
    .rx_fifo_good_frame(),
    .speed(speed),

    .cfg_ifg(8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_enable(1'b1)
);

eth_axis_rx
eth_axis_rx_inst (
    .clk(clk125),
    .rst(resetStack),
    // AXI input
    .s_axis_tdata(rx_axis_tdata),
    .s_axis_tvalid(rx_axis_tvalid),
    .s_axis_tready(rx_axis_tready),
    .s_axis_tlast(rx_axis_tlast),
    .s_axis_tuser(rx_axis_tuser),
    // Ethernet frame output
    .m_eth_hdr_valid(rx_eth_hdr_valid),
    .m_eth_hdr_ready(rx_eth_hdr_ready),
    .m_eth_dest_mac(rx_eth_dest_mac),
    .m_eth_src_mac(rx_eth_src_mac),
    .m_eth_type(rx_eth_type),
    .m_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(rx_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),
    // Status signals
    .busy(),
    .error_header_early_termination()
);

eth_axis_tx
eth_axis_tx_inst (
    .clk(clk125),
    .rst(resetStack),
    // Ethernet frame input
    .s_eth_hdr_valid(tx_eth_hdr_valid),
    .s_eth_hdr_ready(tx_eth_hdr_ready),
    .s_eth_dest_mac(tx_eth_dest_mac),
    .s_eth_src_mac(tx_eth_src_mac),
    .s_eth_type(tx_eth_type),
    .s_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(tx_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),
    // AXI output
    .m_axis_tdata(tx_axis_tdata),
    .m_axis_tvalid(tx_axis_tvalid),
    .m_axis_tready(tx_axis_tready),
    .m_axis_tlast(tx_axis_tlast),
    .m_axis_tuser(tx_axis_tuser),
    // Status signals
    .busy()
);

udp_complete
udp_complete_inst (
    .clk(clk125),
    .rst(resetStack),
    // Ethernet frame input
    .s_eth_hdr_valid(rx_eth_hdr_valid),
    .s_eth_hdr_ready(rx_eth_hdr_ready),
    .s_eth_dest_mac(rx_eth_dest_mac),
    .s_eth_src_mac(rx_eth_src_mac),
    .s_eth_type(rx_eth_type),
    .s_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(rx_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),
    // Ethernet frame output
    .m_eth_hdr_valid(tx_eth_hdr_valid),
    .m_eth_hdr_ready(tx_eth_hdr_ready),
    .m_eth_dest_mac(tx_eth_dest_mac),
    .m_eth_src_mac(tx_eth_src_mac),
    .m_eth_type(tx_eth_type),
    .m_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(tx_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),
    // IP frame input
    .s_ip_hdr_valid(tx_ip_hdr_valid),
    .s_ip_hdr_ready(tx_ip_hdr_ready),
    .s_ip_dscp(tx_ip_dscp),
    .s_ip_ecn(tx_ip_ecn),
    .s_ip_length(tx_ip_length),
    .s_ip_ttl(tx_ip_ttl),
    .s_ip_protocol(tx_ip_protocol),
    .s_ip_source_ip(tx_ip_source_ip),
    .s_ip_dest_ip(tx_ip_dest_ip),
    .s_ip_payload_axis_tdata(tx_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(tx_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(tx_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(tx_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(tx_ip_payload_axis_tuser),
    // IP frame output
    .m_ip_hdr_valid(rx_ip_hdr_valid),
    .m_ip_hdr_ready(rx_ip_hdr_ready),
    .m_ip_eth_dest_mac(rx_ip_eth_dest_mac),
    .m_ip_eth_src_mac(rx_ip_eth_src_mac),
    .m_ip_eth_type(rx_ip_eth_type),
    .m_ip_version(rx_ip_version),
    .m_ip_ihl(rx_ip_ihl),
    .m_ip_dscp(rx_ip_dscp),
    .m_ip_ecn(rx_ip_ecn),
    .m_ip_length(rx_ip_length),
    .m_ip_identification(rx_ip_identification),
    .m_ip_flags(rx_ip_flags),
    .m_ip_fragment_offset(rx_ip_fragment_offset),
    .m_ip_ttl(rx_ip_ttl),
    .m_ip_protocol(rx_ip_protocol),
    .m_ip_header_checksum(rx_ip_header_checksum),
    .m_ip_source_ip(rx_ip_source_ip),
    .m_ip_dest_ip(rx_ip_dest_ip),
    .m_ip_payload_axis_tdata(rx_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(rx_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(rx_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(rx_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(rx_ip_payload_axis_tuser),
    // UDP frame input
    .s_udp_hdr_valid(tx_udp_hdr_valid),
    .s_udp_hdr_ready(tx_udp_hdr_ready),
    .s_udp_ip_dscp(tx_udp_ip_dscp),
    .s_udp_ip_ecn(tx_udp_ip_ecn),
    .s_udp_ip_ttl(tx_udp_ip_ttl),
    .s_udp_ip_source_ip(tx_udp_ip_source_ip),
    .s_udp_ip_dest_ip(tx_udp_ip_dest_ip),
    .s_udp_source_port(tx_udp_source_port),
    .s_udp_dest_port(tx_udp_dest_port),
    .s_udp_length(tx_udp_length),
    .s_udp_checksum(tx_udp_checksum),
    .s_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
    .s_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
    .s_udp_payload_axis_tready(tx_udp_payload_axis_tready),
    .s_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
    .s_udp_payload_axis_tuser(tx_udp_payload_axis_tuser),
    // UDP frame output
    .m_udp_hdr_valid(rx_udp_hdr_valid),
    .m_udp_hdr_ready(rx_udp_hdr_ready),
    .m_udp_eth_dest_mac(rx_udp_eth_dest_mac),
    .m_udp_eth_src_mac(rx_udp_eth_src_mac),
    .m_udp_eth_type(rx_udp_eth_type),
    .m_udp_ip_version(rx_udp_ip_version),
    .m_udp_ip_ihl(rx_udp_ip_ihl),
    .m_udp_ip_dscp(rx_udp_ip_dscp),
    .m_udp_ip_ecn(rx_udp_ip_ecn),
    .m_udp_ip_length(rx_udp_ip_length),
    .m_udp_ip_identification(rx_udp_ip_identification),
    .m_udp_ip_flags(rx_udp_ip_flags),
    .m_udp_ip_fragment_offset(rx_udp_ip_fragment_offset),
    .m_udp_ip_ttl(rx_udp_ip_ttl),
    .m_udp_ip_protocol(rx_udp_ip_protocol),
    .m_udp_ip_header_checksum(rx_udp_ip_header_checksum),
    .m_udp_ip_source_ip(rx_udp_ip_source_ip),
    .m_udp_ip_dest_ip(rx_udp_ip_dest_ip),
    .m_udp_source_port(rx_udp_source_port),
    .m_udp_dest_port(rx_udp_dest_port),
    .m_udp_length(rx_udp_length),
    .m_udp_checksum(rx_udp_checksum),
    .m_udp_payload_axis_tdata(rx_udp_payload_axis_tdata),
    .m_udp_payload_axis_tvalid(rx_udp_payload_axis_tvalid),
    .m_udp_payload_axis_tready(rx_udp_payload_axis_tready),
    .m_udp_payload_axis_tlast(rx_udp_payload_axis_tlast),
    .m_udp_payload_axis_tuser(rx_udp_payload_axis_tuser),
    // Status signals
    .ip_rx_busy(),
    .ip_tx_busy(),
    .udp_rx_busy(),
    .udp_tx_busy(),
    .ip_rx_error_header_early_termination(),
    .ip_rx_error_payload_early_termination(),
    .ip_rx_error_invalid_header(),
    .ip_rx_error_invalid_checksum(),
    .ip_tx_error_payload_early_termination(),
    .ip_tx_error_arp_failed(),
    .udp_rx_error_header_early_termination(),
    .udp_rx_error_payload_early_termination(),
    .udp_tx_error_payload_early_termination(),
    // Configuration
    .local_mac(local_mac),
    .local_ip(local_ip),
    .gateway_ip(gateway_ip),
    .subnet_mask(subnet_mask),
    .clear_arp_cache(0)
);

axis_fifo #(
    .DEPTH(8192),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .FRAME_FIFO(0)
)
udp_payload_fifo (
    .clk(clk125),
    .rst(resetStack),

    // AXI input
    .s_axis_tdata(rx_fifo_udp_payload_axis_tdata),
    .s_axis_tkeep(1'b1),
    .s_axis_tvalid(rx_fifo_udp_payload_axis_tvalid),
    .s_axis_tready(rx_fifo_udp_payload_axis_tready),
    .s_axis_tlast(rx_fifo_udp_payload_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_fifo_udp_payload_axis_tuser),

    // AXI output
    .m_axis_tdata(tx_fifo_udp_payload_axis_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_fifo_udp_payload_axis_tvalid),
    .m_axis_tready(tx_fifo_udp_payload_axis_tready),
    .m_axis_tlast(tx_fifo_udp_payload_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_fifo_udp_payload_axis_tuser),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

endmodule

`default_nettype wire
