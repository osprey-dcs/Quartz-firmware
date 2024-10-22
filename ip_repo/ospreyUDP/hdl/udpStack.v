/* ===== ../../EthernetInCore/verilog-ethernet/rtl/iddr.v ===== */
/*

Copyright (c) 2016-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Generic IDDR module
 */
module iddr #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire             clk,

    input  wire [WIDTH-1:0] d,

    output wire [WIDTH-1:0] q1,
    output wire [WIDTH-1:0] q2
);

/*

Provides a consistent input DDR flip flop across multiple FPGA families
              _____       _____       _____       _____       ____
    clk  ____/     \_____/     \_____/     \_____/     \_____/
         _ _____ _____ _____ _____ _____ _____ _____ _____ _____ _
    d    _X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7__X_D8__X_
         _______ ___________ ___________ ___________ ___________ _
    q1   _______X___________X____D0_____X____D2_____X____D4_____X_
         _______ ___________ ___________ ___________ ___________ _
    q2   _______X___________X____D1_____X____D3_____X____D5_____X_

*/

genvar n;

generate

if (TARGET == "XILINX") begin
    for (n = 0; n < WIDTH; n = n + 1) begin : iddr
        if (IODDR_STYLE == "IODDR") begin
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .SRTYPE("ASYNC")
            )
            iddr_inst (
                .Q1(q1[n]),
                .Q2(q2[n]),
                .C(clk),
                .CE(1'b1),
                .D(d[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end else if (IODDR_STYLE == "IODDR2") begin
            wire q1_int;
            reg q1_delay;

            IDDR2 #(
                .DDR_ALIGNMENT("C0")
            )
            iddr_inst (
                .Q0(q1_int),
                .Q1(q2[n]),
                .C0(clk),
                .C1(~clk),
                .CE(1'b1),
                .D(d[n]),
                .R(1'b0),
                .S(1'b0)
            );

            always @(posedge clk) begin
                q1_delay <= q1_int;
            end

            assign q1[n] = q1_delay;
        end
    end
end else if (TARGET == "ALTERA") begin
    wire [WIDTH-1:0] q1_int;
    reg [WIDTH-1:0] q1_delay;

    altddio_in #(
        .WIDTH(WIDTH),
        .POWER_UP_HIGH("OFF")
    )
    altddio_in_inst (
        .aset(1'b0),
        .datain(d),
        .inclocken(1'b1),
        .inclock(clk),
        .aclr(1'b0),
        .dataout_h(q1_int),
        .dataout_l(q2)
    );

    always @(posedge clk) begin
        q1_delay <= q1_int;
    end

    assign q1 = q1_delay;
end else begin
    reg [WIDTH-1:0] d_reg_1 = {WIDTH{1'b0}};
    reg [WIDTH-1:0] d_reg_2 = {WIDTH{1'b0}};

    reg [WIDTH-1:0] q_reg_1 = {WIDTH{1'b0}};
    reg [WIDTH-1:0] q_reg_2 = {WIDTH{1'b0}};

    always @(posedge clk) begin
        d_reg_1 <= d;
    end

    always @(negedge clk) begin
        d_reg_2 <= d;
    end

    always @(posedge clk) begin
        q_reg_1 <= d_reg_1;
        q_reg_2 <= d_reg_2;
    end

    assign q1 = q_reg_1;
    assign q2 = q_reg_2;
end

endgenerate

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/oddr.v ===== */
/*

Copyright (c) 2016-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Generic ODDR module
 */
module oddr #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire             clk,

    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,

    output wire [WIDTH-1:0] q
);

/*

Provides a consistent output DDR flip flop across multiple FPGA families
              _____       _____       _____       _____
    clk  ____/     \_____/     \_____/     \_____/     \_____
         _ ___________ ___________ ___________ ___________ __
    d1   _X____D0_____X____D2_____X____D4_____X____D6_____X__
         _ ___________ ___________ ___________ ___________ __
    d2   _X____D1_____X____D3_____X____D5_____X____D7_____X__
         _____ _____ _____ _____ _____ _____ _____ _____ ____
    d    _____X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7_

*/

genvar n;

generate

if (TARGET == "XILINX") begin
    for (n = 0; n < WIDTH; n = n + 1) begin : oddr
        if (IODDR_STYLE == "IODDR") begin
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .SRTYPE("ASYNC")
            )
            oddr_inst (
                .Q(q[n]),
                .C(clk),
                .CE(1'b1),
                .D1(d1[n]),
                .D2(d2[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end else if (IODDR_STYLE == "IODDR2") begin
            ODDR2 #(
                .DDR_ALIGNMENT("C0"),
                .SRTYPE("ASYNC")
            )
            oddr_inst (
                .Q(q[n]),
                .C0(clk),
                .C1(~clk),
                .CE(1'b1),
                .D0(d1[n]),
                .D1(d2[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    end
end else if (TARGET == "ALTERA") begin
    altddio_out #(
        .WIDTH(WIDTH),
        .POWER_UP_HIGH("OFF"),
        .OE_REG("UNUSED")
    )
    altddio_out_inst (
        .aset(1'b0),
        .datain_h(d1),
        .datain_l(d2),
        .outclocken(1'b1),
        .outclock(clk),
        .aclr(1'b0),
        .dataout(q)
    );
end else begin
    reg [WIDTH-1:0] d_reg_1 = {WIDTH{1'b0}};
    reg [WIDTH-1:0] d_reg_2 = {WIDTH{1'b0}};

    reg [WIDTH-1:0] q_reg = {WIDTH{1'b0}};

    always @(posedge clk) begin
        d_reg_1 <= d1;
        d_reg_2 <= d2;
    end

    always @(posedge clk) begin
        q_reg <= d1;
    end

    always @(negedge clk) begin
        q_reg <= d_reg_2;
    end

    assign q = q_reg;
end

endgenerate

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/ssio_ddr_in.v ===== */
/*

Copyright (c) 2016-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Generic source synchronous DDR input
 */
module ssio_ddr_in #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFG",
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire             input_clk,

    input  wire [WIDTH-1:0] input_d,

    output wire             output_clk,

    output wire [WIDTH-1:0] output_q1,
    output wire [WIDTH-1:0] output_q2
);

wire clk_int;
wire clk_io;

generate

if (TARGET == "XILINX") begin

    // use Xilinx clocking primitives

    if (CLOCK_INPUT_STYLE == "BUFG") begin

        // buffer RX clock
        BUFG
        clk_bufg (
            .I(input_clk),
            .O(clk_int)
        );

        // pass through RX clock to logic and input buffers
        assign clk_io = clk_int;
        assign output_clk = clk_int;

    end else if (CLOCK_INPUT_STYLE == "BUFR") begin

        assign clk_int = input_clk;

        // pass through RX clock to input buffers
        BUFIO
        clk_bufio (
            .I(clk_int),
            .O(clk_io)
        );

        // pass through RX clock to logic
        BUFR #(
            .BUFR_DIVIDE("BYPASS")
        )
        clk_bufr (
            .I(clk_int),
            .O(output_clk),
            .CE(1'b1),
            .CLR(1'b0)
        );
        
    end else if (CLOCK_INPUT_STYLE == "BUFIO") begin

        assign clk_int = input_clk;

        // pass through RX clock to input buffers
        BUFIO
        clk_bufio (
            .I(clk_int),
            .O(clk_io)
        );

        // pass through RX clock to MAC
        BUFG
        clk_bufg (
            .I(clk_int),
            .O(output_clk)
        );

    end

end else begin

    // pass through RX clock to input buffers
    assign clk_io = input_clk;

    // pass through RX clock to logic
    assign clk_int = input_clk;
    assign output_clk = clk_int;

end

endgenerate

iddr #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(WIDTH)
)
data_iddr_inst (
    .clk(clk_io),
    .d(input_d),
    .q1(output_q1),
    .q2(output_q2)
);

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/rgmii_phy_if.v ===== */
/*

Copyright (c) 2015-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * RGMII PHY interface
 */
module rgmii_phy_if #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFG",
    // Use 90 degree clock for RGMII transmit ("TRUE", "FALSE")
    parameter USE_CLK90 = "TRUE"
)
(
    input  wire        clk,
    input  wire        clk90,
    input  wire        rst,

    /*
     * GMII interface to MAC
     */
    output wire        mac_gmii_rx_clk,
    output wire        mac_gmii_rx_rst,
    output wire [7:0]  mac_gmii_rxd,
    output wire        mac_gmii_rx_dv,
    output wire        mac_gmii_rx_er,
    output wire        mac_gmii_tx_clk,
    output wire        mac_gmii_tx_rst,
    output wire        mac_gmii_tx_clk_en,
    input  wire [7:0]  mac_gmii_txd,
    input  wire        mac_gmii_tx_en,
    input  wire        mac_gmii_tx_er,

    /*
     * RGMII interface to PHY
     */
    input  wire        phy_rgmii_rx_clk,
    input  wire [3:0]  phy_rgmii_rxd,
    input  wire        phy_rgmii_rx_ctl,
    output wire        phy_rgmii_tx_clk,
    output wire [3:0]  phy_rgmii_txd,
    output wire        phy_rgmii_tx_ctl,

    /*
     * Control
     */
    input  wire [1:0]  speed
);

// receive

wire rgmii_rx_ctl_1;
wire rgmii_rx_ctl_2;

ssio_ddr_in #
(
    .TARGET(TARGET),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(5)
)
rx_ssio_ddr_inst (
    .input_clk(phy_rgmii_rx_clk),
    .input_d({phy_rgmii_rxd, phy_rgmii_rx_ctl}),
    .output_clk(mac_gmii_rx_clk),
    .output_q1({mac_gmii_rxd[3:0], rgmii_rx_ctl_1}),
    .output_q2({mac_gmii_rxd[7:4], rgmii_rx_ctl_2})
);

assign mac_gmii_rx_dv = rgmii_rx_ctl_1;
assign mac_gmii_rx_er = rgmii_rx_ctl_1 ^ rgmii_rx_ctl_2;

// transmit

reg rgmii_tx_clk_1 = 1'b1;
reg rgmii_tx_clk_2 = 1'b0;
reg rgmii_tx_clk_en = 1'b1;

reg [5:0] count_reg = 6'd0, count_next;

always @(posedge clk) begin
    rgmii_tx_clk_1 <= rgmii_tx_clk_2;

    if (speed == 2'b00) begin
        // 10M
        count_reg <= count_reg + 1;
        rgmii_tx_clk_en <= 1'b0;
        if (count_reg == 24) begin
            rgmii_tx_clk_1 <= 1'b1;
            rgmii_tx_clk_2 <= 1'b1;
        end else if (count_reg >= 49) begin
            rgmii_tx_clk_2 <= 1'b0;
            rgmii_tx_clk_en <= 1'b1;
            count_reg <= 0;
        end
    end else if (speed == 2'b01) begin
        // 100M
        count_reg <= count_reg + 1;
        rgmii_tx_clk_en <= 1'b0;
        if (count_reg == 2) begin
            rgmii_tx_clk_1 <= 1'b1;
            rgmii_tx_clk_2 <= 1'b1;
        end else if (count_reg >= 4) begin
            rgmii_tx_clk_2 <= 1'b0;
            rgmii_tx_clk_en <= 1'b1;
            count_reg <= 0;
        end
    end else begin
        // 1000M
        rgmii_tx_clk_1 <= 1'b1;
        rgmii_tx_clk_2 <= 1'b0;
        rgmii_tx_clk_en <= 1'b1;
    end

    if (rst) begin
        rgmii_tx_clk_1 <= 1'b1;
        rgmii_tx_clk_2 <= 1'b0;
        rgmii_tx_clk_en <= 1'b1;
        count_reg <= 0;
    end
end

reg [3:0] rgmii_txd_1 = 0;
reg [3:0] rgmii_txd_2 = 0;
reg rgmii_tx_ctl_1 = 1'b0;
reg rgmii_tx_ctl_2 = 1'b0;

reg gmii_clk_en = 1'b1;

always @* begin
    if (speed == 2'b00) begin
        // 10M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[3:0];
        if (rgmii_tx_clk_1) begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en ^ mac_gmii_tx_er;
            rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        end else begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en;
            rgmii_tx_ctl_2 = mac_gmii_tx_en;
        end
        gmii_clk_en = rgmii_tx_clk_en;
    end else if (speed == 2'b01) begin
        // 100M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[3:0];
        if (rgmii_tx_clk_1) begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en ^ mac_gmii_tx_er;
            rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        end else begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en;
            rgmii_tx_ctl_2 = mac_gmii_tx_en;
        end
        gmii_clk_en = rgmii_tx_clk_en;
    end else begin
        // 1000M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[7:4];
        rgmii_tx_ctl_1 = mac_gmii_tx_en;
        rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        gmii_clk_en = 1;
    end
end

wire phy_rgmii_tx_clk_new;
wire [3:0] phy_rgmii_txd_new;
wire phy_rgmii_tx_ctl_new;

oddr #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(1)
)
clk_oddr_inst (
    .clk(USE_CLK90 == "TRUE" ? clk90 : clk),
    .d1(rgmii_tx_clk_1),
    .d2(rgmii_tx_clk_2),
    .q(phy_rgmii_tx_clk)
);

oddr #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .WIDTH(5)
)
data_oddr_inst (
    .clk(clk),
    .d1({rgmii_txd_1, rgmii_tx_ctl_1}),
    .d2({rgmii_txd_2, rgmii_tx_ctl_2}),
    .q({phy_rgmii_txd, phy_rgmii_tx_ctl})
);

assign mac_gmii_tx_clk = clk;

assign mac_gmii_tx_clk_en = gmii_clk_en;

// reset sync
reg [3:0] tx_rst_reg = 4'hf;
assign mac_gmii_tx_rst = tx_rst_reg[0];

always @(posedge mac_gmii_tx_clk or posedge rst) begin
    if (rst) begin
        tx_rst_reg <= 4'hf;
    end else begin
        tx_rst_reg <= {1'b0, tx_rst_reg[3:1]};
    end
end

reg [3:0] rx_rst_reg = 4'hf;
assign mac_gmii_rx_rst = rx_rst_reg[0];

always @(posedge mac_gmii_rx_clk or posedge rst) begin
    if (rst) begin
        rx_rst_reg <= 4'hf;
    end else begin
        rx_rst_reg <= {1'b0, rx_rst_reg[3:1]};
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/eth_mac_1g_rgmii_fifo.v ===== */
/*

Copyright (c) 2015-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 1G Ethernet MAC with RGMII interface and TX and RX FIFOs
 */
module eth_mac_1g_rgmii_fifo #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFG",
    // Use 90 degree clock for RGMII transmit ("TRUE", "FALSE")
    parameter USE_CLK90 = "TRUE",
    parameter AXIS_DATA_WIDTH = 8,
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8),
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter TX_FIFO_DEPTH = 4096,
    parameter TX_FIFO_RAM_PIPELINE = 1,
    parameter TX_FRAME_FIFO = 1,
    parameter TX_DROP_OVERSIZE_FRAME = TX_FRAME_FIFO,
    parameter TX_DROP_BAD_FRAME = TX_DROP_OVERSIZE_FRAME,
    parameter TX_DROP_WHEN_FULL = 0,
    parameter RX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_RAM_PIPELINE = 1,
    parameter RX_FRAME_FIFO = 1,
    parameter RX_DROP_OVERSIZE_FRAME = RX_FRAME_FIFO,
    parameter RX_DROP_BAD_FRAME = RX_DROP_OVERSIZE_FRAME,
    parameter RX_DROP_WHEN_FULL = RX_DROP_OVERSIZE_FRAME
)
(
    input  wire                       gtx_clk,
    input  wire                       gtx_clk90,
    input  wire                       gtx_rst,
    input  wire                       logic_clk,
    input  wire                       logic_rst,

    /*
     * AXI input
     */
    input  wire [AXIS_DATA_WIDTH-1:0] tx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0] tx_axis_tkeep,
    input  wire                       tx_axis_tvalid,
    output wire                       tx_axis_tready,
    input  wire                       tx_axis_tlast,
    input  wire                       tx_axis_tuser,

    /*
     * AXI output
     */
    output wire [AXIS_DATA_WIDTH-1:0] rx_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0] rx_axis_tkeep,
    output wire                       rx_axis_tvalid,
    input  wire                       rx_axis_tready,
    output wire                       rx_axis_tlast,
    output wire                       rx_axis_tuser,

    /*
     * RGMII interface
     */
    input  wire                       rgmii_rx_clk,
    input  wire [3:0]                 rgmii_rxd,
    input  wire                       rgmii_rx_ctl,
    output wire                       rgmii_tx_clk,
    output wire [3:0]                 rgmii_txd,
    output wire                       rgmii_tx_ctl,

    /*
     * Status
     */
    output wire                       tx_error_underflow,
    output wire                       tx_fifo_overflow,
    output wire                       tx_fifo_bad_frame,
    output wire                       tx_fifo_good_frame,
    output wire                       rx_error_bad_frame,
    output wire                       rx_error_bad_fcs,
    output wire                       rx_fifo_overflow,
    output wire                       rx_fifo_bad_frame,
    output wire                       rx_fifo_good_frame,
    output wire [1:0]                 speed,

    /*
     * Configuration
     */
    input  wire [7:0]                 cfg_ifg,
    input  wire                       cfg_tx_enable,
    input  wire                       cfg_rx_enable
);

wire tx_clk;
wire rx_clk;
wire tx_rst;
wire rx_rst;

wire [7:0]  tx_fifo_axis_tdata;
wire        tx_fifo_axis_tvalid;
wire        tx_fifo_axis_tready;
wire        tx_fifo_axis_tlast;
wire        tx_fifo_axis_tuser;

wire [7:0]  rx_fifo_axis_tdata;
wire        rx_fifo_axis_tvalid;
wire        rx_fifo_axis_tlast;
wire        rx_fifo_axis_tuser;

// synchronize MAC status signals into logic clock domain
wire tx_error_underflow_int;

reg [0:0] tx_sync_reg_1 = 1'b0;
reg [0:0] tx_sync_reg_2 = 1'b0;
reg [0:0] tx_sync_reg_3 = 1'b0;
reg [0:0] tx_sync_reg_4 = 1'b0;

assign tx_error_underflow = tx_sync_reg_3[0] ^ tx_sync_reg_4[0];

always @(posedge tx_clk or posedge tx_rst) begin
    if (tx_rst) begin
        tx_sync_reg_1 <= 1'b0;
    end else begin
        tx_sync_reg_1 <= tx_sync_reg_1 ^ {tx_error_underflow_int};
    end
end

always @(posedge logic_clk or posedge logic_rst) begin
    if (logic_rst) begin
        tx_sync_reg_2 <= 1'b0;
        tx_sync_reg_3 <= 1'b0;
        tx_sync_reg_4 <= 1'b0;
    end else begin
        tx_sync_reg_2 <= tx_sync_reg_1;
        tx_sync_reg_3 <= tx_sync_reg_2;
        tx_sync_reg_4 <= tx_sync_reg_3;
    end
end

wire rx_error_bad_frame_int;
wire rx_error_bad_fcs_int;

reg [1:0] rx_sync_reg_1 = 2'd0;
reg [1:0] rx_sync_reg_2 = 2'd0;
reg [1:0] rx_sync_reg_3 = 2'd0;
reg [1:0] rx_sync_reg_4 = 2'd0;

assign rx_error_bad_frame = rx_sync_reg_3[0] ^ rx_sync_reg_4[0];
assign rx_error_bad_fcs = rx_sync_reg_3[1] ^ rx_sync_reg_4[1];

always @(posedge rx_clk or posedge rx_rst) begin
    if (rx_rst) begin
        rx_sync_reg_1 <= 2'd0;
    end else begin
        rx_sync_reg_1 <= rx_sync_reg_1 ^ {rx_error_bad_fcs_int, rx_error_bad_frame_int};
    end
end

always @(posedge logic_clk or posedge logic_rst) begin
    if (logic_rst) begin
        rx_sync_reg_2 <= 2'd0;
        rx_sync_reg_3 <= 2'd0;
        rx_sync_reg_4 <= 2'd0;
    end else begin
        rx_sync_reg_2 <= rx_sync_reg_1;
        rx_sync_reg_3 <= rx_sync_reg_2;
        rx_sync_reg_4 <= rx_sync_reg_3;
    end
end

wire [1:0] speed_int;

reg [1:0] speed_sync_reg_1 = 2'b10;
reg [1:0] speed_sync_reg_2 = 2'b10;

assign speed = speed_sync_reg_2;

always @(posedge logic_clk) begin
    speed_sync_reg_1 <= speed_int;
    speed_sync_reg_2 <= speed_sync_reg_1;
end

eth_mac_1g_rgmii #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .USE_CLK90(USE_CLK90),
    .ENABLE_PADDING(ENABLE_PADDING),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH)
)
eth_mac_1g_rgmii_inst (
    .gtx_clk(gtx_clk),
    .gtx_clk90(gtx_clk90),
    .gtx_rst(gtx_rst),
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .tx_axis_tdata(tx_fifo_axis_tdata),
    .tx_axis_tvalid(tx_fifo_axis_tvalid),
    .tx_axis_tready(tx_fifo_axis_tready),
    .tx_axis_tlast(tx_fifo_axis_tlast),
    .tx_axis_tuser(tx_fifo_axis_tuser),
    .rx_axis_tdata(rx_fifo_axis_tdata),
    .rx_axis_tvalid(rx_fifo_axis_tvalid),
    .rx_axis_tlast(rx_fifo_axis_tlast),
    .rx_axis_tuser(rx_fifo_axis_tuser),
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    .tx_error_underflow(tx_error_underflow_int),
    .rx_error_bad_frame(rx_error_bad_frame_int),
    .rx_error_bad_fcs(rx_error_bad_fcs_int),
    .speed(speed_int),
    .cfg_ifg(cfg_ifg),
    .cfg_tx_enable(cfg_tx_enable),
    .cfg_rx_enable(cfg_rx_enable)
);

axis_async_fifo_adapter #(
    .DEPTH(TX_FIFO_DEPTH),
    .S_DATA_WIDTH(AXIS_DATA_WIDTH),
    .S_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .S_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .M_DATA_WIDTH(8),
    .M_KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .RAM_PIPELINE(TX_FIFO_RAM_PIPELINE),
    .FRAME_FIFO(TX_FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_OVERSIZE_FRAME(TX_DROP_OVERSIZE_FRAME),
    .DROP_BAD_FRAME(TX_DROP_BAD_FRAME),
    .DROP_WHEN_FULL(TX_DROP_WHEN_FULL)
)
tx_fifo (
    // AXI input
    .s_clk(logic_clk),
    .s_rst(logic_rst),
    .s_axis_tdata(tx_axis_tdata),
    .s_axis_tkeep(tx_axis_tkeep),
    .s_axis_tvalid(tx_axis_tvalid),
    .s_axis_tready(tx_axis_tready),
    .s_axis_tlast(tx_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(tx_axis_tuser),
    // AXI output
    .m_clk(tx_clk),
    .m_rst(tx_rst),
    .m_axis_tdata(tx_fifo_axis_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_fifo_axis_tvalid),
    .m_axis_tready(tx_fifo_axis_tready),
    .m_axis_tlast(tx_fifo_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_fifo_axis_tuser),
    // Status
    .s_status_overflow(tx_fifo_overflow),
    .s_status_bad_frame(tx_fifo_bad_frame),
    .s_status_good_frame(tx_fifo_good_frame),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

axis_async_fifo_adapter #(
    .DEPTH(RX_FIFO_DEPTH),
    .S_DATA_WIDTH(8),
    .S_KEEP_ENABLE(0),
    .M_DATA_WIDTH(AXIS_DATA_WIDTH),
    .M_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .M_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .RAM_PIPELINE(RX_FIFO_RAM_PIPELINE),
    .FRAME_FIFO(RX_FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_OVERSIZE_FRAME(RX_DROP_OVERSIZE_FRAME),
    .DROP_BAD_FRAME(RX_DROP_BAD_FRAME),
    .DROP_WHEN_FULL(RX_DROP_WHEN_FULL)
)
rx_fifo (
    // AXI input
    .s_clk(rx_clk),
    .s_rst(rx_rst),
    .s_axis_tdata(rx_fifo_axis_tdata),
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_fifo_axis_tvalid),
    .s_axis_tready(),
    .s_axis_tlast(rx_fifo_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_fifo_axis_tuser),
    // AXI output
    .m_clk(logic_clk),
    .m_rst(logic_rst),
    .m_axis_tdata(rx_axis_tdata),
    .m_axis_tkeep(rx_axis_tkeep),
    .m_axis_tvalid(rx_axis_tvalid),
    .m_axis_tready(rx_axis_tready),
    .m_axis_tlast(rx_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(rx_axis_tuser),
    // Status
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(rx_fifo_overflow),
    .m_status_bad_frame(rx_fifo_bad_frame),
    .m_status_good_frame(rx_fifo_good_frame)
);

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/eth_mac_1g_rgmii.v ===== */
/*

Copyright (c) 2015-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 1G Ethernet MAC with RGMII interface
 */
module eth_mac_1g_rgmii #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFG",
    // Use 90 degree clock for RGMII transmit ("TRUE", "FALSE")
    parameter USE_CLK90 = "TRUE",
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64
)
(
    input  wire        gtx_clk,
    input  wire        gtx_clk90,
    input  wire        gtx_rst,
    output wire        rx_clk,
    output wire        rx_rst,
    output wire        tx_clk,
    output wire        tx_rst,

    /*
     * AXI input
     */
    input  wire [7:0]  tx_axis_tdata,
    input  wire        tx_axis_tvalid,
    output wire        tx_axis_tready,
    input  wire        tx_axis_tlast,
    input  wire        tx_axis_tuser,

    /*
     * AXI output
     */
    output wire [7:0]  rx_axis_tdata,
    output wire        rx_axis_tvalid,
    output wire        rx_axis_tlast,
    output wire        rx_axis_tuser,

    /*
     * RGMII interface
     */
    input  wire        rgmii_rx_clk,
    input  wire [3:0]  rgmii_rxd,
    input  wire        rgmii_rx_ctl,
    output wire        rgmii_tx_clk,
    output wire [3:0]  rgmii_txd,
    output wire        rgmii_tx_ctl,

    /*
     * Status
     */
    output wire        tx_error_underflow,
    output wire        rx_error_bad_frame,
    output wire        rx_error_bad_fcs,
    output wire [1:0]  speed,

    /*
     * Configuration
     */
    input  wire [7:0]  cfg_ifg,
    input  wire        cfg_tx_enable,
    input  wire        cfg_rx_enable
);

wire [7:0]  mac_gmii_rxd;
wire        mac_gmii_rx_dv;
wire        mac_gmii_rx_er;
wire        mac_gmii_tx_clk_en;
wire [7:0]  mac_gmii_txd;
wire        mac_gmii_tx_en;
wire        mac_gmii_tx_er;

reg [1:0] speed_reg = 2'b10;
reg mii_select_reg = 1'b0;

(* srl_style = "register" *)
reg [1:0] tx_mii_select_sync = 2'd0;

always @(posedge tx_clk) begin
    tx_mii_select_sync <= {tx_mii_select_sync[0], mii_select_reg};
end

(* srl_style = "register" *)
reg [1:0] rx_mii_select_sync = 2'd0;

always @(posedge rx_clk) begin
    rx_mii_select_sync <= {rx_mii_select_sync[0], mii_select_reg};
end

// PHY speed detection
reg [2:0] rx_prescale = 3'd0;

always @(posedge rx_clk) begin
    rx_prescale <= rx_prescale + 3'd1;
end

(* srl_style = "register" *)
reg [2:0] rx_prescale_sync = 3'd0;

always @(posedge gtx_clk) begin
    rx_prescale_sync <= {rx_prescale_sync[1:0], rx_prescale[2]};
end

reg [6:0] rx_speed_count_1 = 0;
reg [1:0] rx_speed_count_2 = 0;

always @(posedge gtx_clk) begin
    if (gtx_rst) begin
        rx_speed_count_1 <= 0;
        rx_speed_count_2 <= 0;
        speed_reg <= 2'b10;
        mii_select_reg <= 1'b0;
    end else begin
        rx_speed_count_1 <= rx_speed_count_1 + 1;
        
        if (rx_prescale_sync[1] ^ rx_prescale_sync[2]) begin
            rx_speed_count_2 <= rx_speed_count_2 + 1;
        end

        if (&rx_speed_count_1) begin
            // reference count overflow - 10M
            rx_speed_count_1 <= 0;
            rx_speed_count_2 <= 0;
            speed_reg <= 2'b00;
            mii_select_reg <= 1'b1;
        end

        if (&rx_speed_count_2) begin
            // prescaled count overflow - 100M or 1000M
            rx_speed_count_1 <= 0;
            rx_speed_count_2 <= 0;
            if (rx_speed_count_1[6:5]) begin
                // large reference count - 100M
                speed_reg <= 2'b01;
                mii_select_reg <= 1'b1;
            end else begin
                // small reference count - 1000M
                speed_reg <= 2'b10;
                mii_select_reg <= 1'b0;
            end
        end
    end
end

assign speed = speed_reg;

rgmii_phy_if #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .USE_CLK90(USE_CLK90)
)
rgmii_phy_if_inst (
    .clk(gtx_clk),
    .clk90(gtx_clk90),
    .rst(gtx_rst),

    .mac_gmii_rx_clk(rx_clk),
    .mac_gmii_rx_rst(rx_rst),
    .mac_gmii_rxd(mac_gmii_rxd),
    .mac_gmii_rx_dv(mac_gmii_rx_dv),
    .mac_gmii_rx_er(mac_gmii_rx_er),
    .mac_gmii_tx_clk(tx_clk),
    .mac_gmii_tx_rst(tx_rst),
    .mac_gmii_tx_clk_en(mac_gmii_tx_clk_en),
    .mac_gmii_txd(mac_gmii_txd),
    .mac_gmii_tx_en(mac_gmii_tx_en),
    .mac_gmii_tx_er(mac_gmii_tx_er),

    .phy_rgmii_rx_clk(rgmii_rx_clk),
    .phy_rgmii_rxd(rgmii_rxd),
    .phy_rgmii_rx_ctl(rgmii_rx_ctl),
    .phy_rgmii_tx_clk(rgmii_tx_clk),
    .phy_rgmii_txd(rgmii_txd),
    .phy_rgmii_tx_ctl(rgmii_tx_ctl),

    .speed(speed)
);

eth_mac_1g #(
    .ENABLE_PADDING(ENABLE_PADDING),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH)
)
eth_mac_1g_inst (
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .tx_axis_tdata(tx_axis_tdata),
    .tx_axis_tvalid(tx_axis_tvalid),
    .tx_axis_tready(tx_axis_tready),
    .tx_axis_tlast(tx_axis_tlast),
    .tx_axis_tuser(tx_axis_tuser),
    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),
    .gmii_rxd(mac_gmii_rxd),
    .gmii_rx_dv(mac_gmii_rx_dv),
    .gmii_rx_er(mac_gmii_rx_er),
    .gmii_txd(mac_gmii_txd),
    .gmii_tx_en(mac_gmii_tx_en),
    .gmii_tx_er(mac_gmii_tx_er),
    .rx_clk_enable(1'b1),
    .tx_clk_enable(mac_gmii_tx_clk_en),
    .rx_mii_select(rx_mii_select_sync[1]),
    .tx_mii_select(tx_mii_select_sync[1]),
    .tx_error_underflow(tx_error_underflow),
    .rx_error_bad_frame(rx_error_bad_frame),
    .rx_error_bad_fcs(rx_error_bad_fcs),
    .cfg_ifg(cfg_ifg),
    .cfg_tx_enable(cfg_tx_enable),
    .cfg_rx_enable(cfg_rx_enable)
);

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/eth_mac_1g.v ===== */
/*

Copyright (c) 2015-2023 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 1G Ethernet MAC
 */
module eth_mac_1g #
(
    parameter DATA_WIDTH = 8,
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter PTP_TS_ENABLE = 0,
    parameter PTP_TS_FMT_TOD = 1,
    parameter PTP_TS_WIDTH = PTP_TS_FMT_TOD ? 96 : 64,
    parameter TX_PTP_TS_CTRL_IN_TUSER = 0,
    parameter TX_PTP_TAG_ENABLE = PTP_TS_ENABLE,
    parameter TX_PTP_TAG_WIDTH = 16,
    parameter TX_USER_WIDTH = (PTP_TS_ENABLE ? (TX_PTP_TAG_ENABLE ? TX_PTP_TAG_WIDTH : 0) + (TX_PTP_TS_CTRL_IN_TUSER ? 1 : 0) : 0) + 1,
    parameter RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter PFC_ENABLE = 0,
    parameter PAUSE_ENABLE = PFC_ENABLE
)
(
    input  wire                         rx_clk,
    input  wire                         rx_rst,
    input  wire                         tx_clk,
    input  wire                         tx_rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]        tx_axis_tdata,
    input  wire                         tx_axis_tvalid,
    output wire                         tx_axis_tready,
    input  wire                         tx_axis_tlast,
    input  wire [TX_USER_WIDTH-1:0]     tx_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]        rx_axis_tdata,
    output wire                         rx_axis_tvalid,
    output wire                         rx_axis_tlast,
    output wire [RX_USER_WIDTH-1:0]     rx_axis_tuser,

    /*
     * GMII interface
     */
    input  wire [DATA_WIDTH-1:0]        gmii_rxd,
    input  wire                         gmii_rx_dv,
    input  wire                         gmii_rx_er,
    output wire [DATA_WIDTH-1:0]        gmii_txd,
    output wire                         gmii_tx_en,
    output wire                         gmii_tx_er,

    /*
     * PTP
     */
    input  wire [PTP_TS_WIDTH-1:0]      tx_ptp_ts,
    input  wire [PTP_TS_WIDTH-1:0]      rx_ptp_ts,
    output wire [PTP_TS_WIDTH-1:0]      tx_axis_ptp_ts,
    output wire [TX_PTP_TAG_WIDTH-1:0]  tx_axis_ptp_ts_tag,
    output wire                         tx_axis_ptp_ts_valid,

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    input  wire                         tx_lfc_req,
    input  wire                         tx_lfc_resend,
    input  wire                         rx_lfc_en,
    output wire                         rx_lfc_req,
    input  wire                         rx_lfc_ack,

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    input  wire [7:0]                   tx_pfc_req,
    input  wire                         tx_pfc_resend,
    input  wire [7:0]                   rx_pfc_en,
    output wire [7:0]                   rx_pfc_req,
    input  wire [7:0]                   rx_pfc_ack,

    /*
     * Pause interface
     */
    input  wire                         tx_lfc_pause_en,
    input  wire                         tx_pause_req,
    output wire                         tx_pause_ack,

    /*
     * Control
     */
    input  wire                         rx_clk_enable,
    input  wire                         tx_clk_enable,
    input  wire                         rx_mii_select,
    input  wire                         tx_mii_select,

    /*
     * Status
     */
    output wire                         tx_start_packet,
    output wire                         tx_error_underflow,
    output wire                         rx_start_packet,
    output wire                         rx_error_bad_frame,
    output wire                         rx_error_bad_fcs,
    output wire                         stat_tx_mcf,
    output wire                         stat_rx_mcf,
    output wire                         stat_tx_lfc_pkt,
    output wire                         stat_tx_lfc_xon,
    output wire                         stat_tx_lfc_xoff,
    output wire                         stat_tx_lfc_paused,
    output wire                         stat_tx_pfc_pkt,
    output wire [7:0]                   stat_tx_pfc_xon,
    output wire [7:0]                   stat_tx_pfc_xoff,
    output wire [7:0]                   stat_tx_pfc_paused,
    output wire                         stat_rx_lfc_pkt,
    output wire                         stat_rx_lfc_xon,
    output wire                         stat_rx_lfc_xoff,
    output wire                         stat_rx_lfc_paused,
    output wire                         stat_rx_pfc_pkt,
    output wire [7:0]                   stat_rx_pfc_xon,
    output wire [7:0]                   stat_rx_pfc_xoff,
    output wire [7:0]                   stat_rx_pfc_paused,

    /*
     * Configuration
     */
    input  wire [7:0]                   cfg_ifg,
    input  wire                         cfg_tx_enable,
    input  wire                         cfg_rx_enable,
    input  wire [47:0]                  cfg_mcf_rx_eth_dst_mcast,
    input  wire                         cfg_mcf_rx_check_eth_dst_mcast,
    input  wire [47:0]                  cfg_mcf_rx_eth_dst_ucast,
    input  wire                         cfg_mcf_rx_check_eth_dst_ucast,
    input  wire [47:0]                  cfg_mcf_rx_eth_src,
    input  wire                         cfg_mcf_rx_check_eth_src,
    input  wire [15:0]                  cfg_mcf_rx_eth_type,
    input  wire [15:0]                  cfg_mcf_rx_opcode_lfc,
    input  wire                         cfg_mcf_rx_check_opcode_lfc,
    input  wire [15:0]                  cfg_mcf_rx_opcode_pfc,
    input  wire                         cfg_mcf_rx_check_opcode_pfc,
    input  wire                         cfg_mcf_rx_forward,
    input  wire                         cfg_mcf_rx_enable,
    input  wire [47:0]                  cfg_tx_lfc_eth_dst,
    input  wire [47:0]                  cfg_tx_lfc_eth_src,
    input  wire [15:0]                  cfg_tx_lfc_eth_type,
    input  wire [15:0]                  cfg_tx_lfc_opcode,
    input  wire                         cfg_tx_lfc_en,
    input  wire [15:0]                  cfg_tx_lfc_quanta,
    input  wire [15:0]                  cfg_tx_lfc_refresh,
    input  wire [47:0]                  cfg_tx_pfc_eth_dst,
    input  wire [47:0]                  cfg_tx_pfc_eth_src,
    input  wire [15:0]                  cfg_tx_pfc_eth_type,
    input  wire [15:0]                  cfg_tx_pfc_opcode,
    input  wire                         cfg_tx_pfc_en,
    input  wire [8*16-1:0]              cfg_tx_pfc_quanta,
    input  wire [8*16-1:0]              cfg_tx_pfc_refresh,
    input  wire [15:0]                  cfg_rx_lfc_opcode,
    input  wire                         cfg_rx_lfc_en,
    input  wire [15:0]                  cfg_rx_pfc_opcode,
    input  wire                         cfg_rx_pfc_en
);

parameter MAC_CTRL_ENABLE = PAUSE_ENABLE || PFC_ENABLE;
parameter TX_USER_WIDTH_INT = MAC_CTRL_ENABLE ? (PTP_TS_ENABLE ? (TX_PTP_TAG_ENABLE ? TX_PTP_TAG_WIDTH : 0) + 1 : 0) + 1 : TX_USER_WIDTH;

wire [DATA_WIDTH-1:0]         tx_axis_tdata_int;
wire                          tx_axis_tvalid_int;
wire                          tx_axis_tready_int;
wire                          tx_axis_tlast_int;
wire [TX_USER_WIDTH_INT-1:0]  tx_axis_tuser_int;

wire [DATA_WIDTH-1:0]     rx_axis_tdata_int;
wire                      rx_axis_tvalid_int;
wire                      rx_axis_tlast_int;
wire [RX_USER_WIDTH-1:0]  rx_axis_tuser_int;

axis_gmii_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .USER_WIDTH(RX_USER_WIDTH)
)
axis_gmii_rx_inst (
    .clk(rx_clk),
    .rst(rx_rst),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .m_axis_tdata(rx_axis_tdata_int),
    .m_axis_tvalid(rx_axis_tvalid_int),
    .m_axis_tlast(rx_axis_tlast_int),
    .m_axis_tuser(rx_axis_tuser_int),
    .ptp_ts(rx_ptp_ts),
    .clk_enable(rx_clk_enable),
    .mii_select(rx_mii_select),
    .cfg_rx_enable(cfg_rx_enable),
    .start_packet(rx_start_packet),
    .error_bad_frame(rx_error_bad_frame),
    .error_bad_fcs(rx_error_bad_fcs)
);

axis_gmii_tx #(
    .DATA_WIDTH(DATA_WIDTH),
    .ENABLE_PADDING(ENABLE_PADDING),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
    .PTP_TS_ENABLE(PTP_TS_ENABLE),
    .PTP_TS_WIDTH(PTP_TS_WIDTH),
    .PTP_TS_CTRL_IN_TUSER(MAC_CTRL_ENABLE ? PTP_TS_ENABLE : TX_PTP_TS_CTRL_IN_TUSER),
    .PTP_TAG_ENABLE(TX_PTP_TAG_ENABLE),
    .PTP_TAG_WIDTH(TX_PTP_TAG_WIDTH),
    .USER_WIDTH(TX_USER_WIDTH_INT)
)
axis_gmii_tx_inst (
    .clk(tx_clk),
    .rst(tx_rst),
    .s_axis_tdata(tx_axis_tdata_int),
    .s_axis_tvalid(tx_axis_tvalid_int),
    .s_axis_tready(tx_axis_tready_int),
    .s_axis_tlast(tx_axis_tlast_int),
    .s_axis_tuser(tx_axis_tuser_int),
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .ptp_ts(tx_ptp_ts),
    .m_axis_ptp_ts(tx_axis_ptp_ts),
    .m_axis_ptp_ts_tag(tx_axis_ptp_ts_tag),
    .m_axis_ptp_ts_valid(tx_axis_ptp_ts_valid),
    .clk_enable(tx_clk_enable),
    .mii_select(tx_mii_select),
    .cfg_ifg(cfg_ifg),
    .cfg_tx_enable(cfg_tx_enable),
    .start_packet(tx_start_packet),
    .error_underflow(tx_error_underflow)
);

generate

if (MAC_CTRL_ENABLE) begin : mac_ctrl

    localparam MCF_PARAMS_SIZE = PFC_ENABLE ? 18 : 2;

    wire                          tx_mcf_valid;
    wire                          tx_mcf_ready;
    wire [47:0]                   tx_mcf_eth_dst;
    wire [47:0]                   tx_mcf_eth_src;
    wire [15:0]                   tx_mcf_eth_type;
    wire [15:0]                   tx_mcf_opcode;
    wire [MCF_PARAMS_SIZE*8-1:0]  tx_mcf_params;

    wire                          rx_mcf_valid;
    wire [47:0]                   rx_mcf_eth_dst;
    wire [47:0]                   rx_mcf_eth_src;
    wire [15:0]                   rx_mcf_eth_type;
    wire [15:0]                   rx_mcf_opcode;
    wire [MCF_PARAMS_SIZE*8-1:0]  rx_mcf_params;

    // terminate LFC pause requests from RX internally on TX side
    wire                          tx_pause_req_int;
    wire                          rx_lfc_ack_int;

    reg tx_lfc_req_sync_reg_1 = 1'b0;
    reg tx_lfc_req_sync_reg_2 = 1'b0;
    reg tx_lfc_req_sync_reg_3 = 1'b0;

    always @(posedge rx_clk or posedge rx_rst) begin
        if (rx_rst) begin
            tx_lfc_req_sync_reg_1 <= 1'b0;
        end else begin
            tx_lfc_req_sync_reg_1 <= rx_lfc_req;
        end
    end

    always @(posedge tx_clk or posedge tx_rst) begin
        if (tx_rst) begin
            tx_lfc_req_sync_reg_2 <= 1'b0;
            tx_lfc_req_sync_reg_3 <= 1'b0;
        end else begin
            tx_lfc_req_sync_reg_2 <= tx_lfc_req_sync_reg_1;
            tx_lfc_req_sync_reg_3 <= tx_lfc_req_sync_reg_2;
        end
    end

    reg rx_lfc_ack_sync_reg_1 = 1'b0;
    reg rx_lfc_ack_sync_reg_2 = 1'b0;
    reg rx_lfc_ack_sync_reg_3 = 1'b0;

    always @(posedge tx_clk or posedge tx_rst) begin
        if (tx_rst) begin
            rx_lfc_ack_sync_reg_1 <= 1'b0;
        end else begin
            rx_lfc_ack_sync_reg_1 <= tx_lfc_pause_en ? tx_pause_ack : 0;
        end
    end

    always @(posedge rx_clk or posedge rx_rst) begin
        if (rx_rst) begin
            rx_lfc_ack_sync_reg_2 <= 1'b0;
            rx_lfc_ack_sync_reg_3 <= 1'b0;
        end else begin
            rx_lfc_ack_sync_reg_2 <= rx_lfc_ack_sync_reg_1;
            rx_lfc_ack_sync_reg_3 <= rx_lfc_ack_sync_reg_2;
        end
    end

    assign tx_pause_req_int = tx_pause_req || (tx_lfc_pause_en ? tx_lfc_req_sync_reg_3 : 0);

    assign rx_lfc_ack_int = rx_lfc_ack || rx_lfc_ack_sync_reg_3;

    // handle PTP TS enable bit in tuser
    wire [TX_USER_WIDTH_INT-1:0] tx_axis_tuser_in;

    if (PTP_TS_ENABLE && !TX_PTP_TS_CTRL_IN_TUSER) begin
        assign tx_axis_tuser_in = {tx_axis_tuser[TX_USER_WIDTH-1:1], 1'b1, tx_axis_tuser[0]};
    end else begin
        assign tx_axis_tuser_in = tx_axis_tuser;
    end

    mac_ctrl_tx #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(TX_USER_WIDTH_INT),
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
    )
    mac_ctrl_tx_inst (
        .clk(tx_clk),
        .rst(tx_rst),

        /*
         * AXI stream input
         */
        .s_axis_tdata(tx_axis_tdata),
        .s_axis_tkeep(1'b1),
        .s_axis_tvalid(tx_axis_tvalid),
        .s_axis_tready(tx_axis_tready),
        .s_axis_tlast(tx_axis_tlast),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(tx_axis_tuser_in),

        /*
         * AXI stream output
         */
        .m_axis_tdata(tx_axis_tdata_int),
        .m_axis_tkeep(),
        .m_axis_tvalid(tx_axis_tvalid_int),
        .m_axis_tready(tx_axis_tready_int),
        .m_axis_tlast(tx_axis_tlast_int),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(tx_axis_tuser_int),

        /*
         * MAC control frame interface
         */
        .mcf_valid(tx_mcf_valid),
        .mcf_ready(tx_mcf_ready),
        .mcf_eth_dst(tx_mcf_eth_dst),
        .mcf_eth_src(tx_mcf_eth_src),
        .mcf_eth_type(tx_mcf_eth_type),
        .mcf_opcode(tx_mcf_opcode),
        .mcf_params(tx_mcf_params),
        .mcf_id(0),
        .mcf_dest(0),
        .mcf_user(0),

        /*
         * Pause interface
         */
        .tx_pause_req(tx_pause_req_int),
        .tx_pause_ack(tx_pause_ack),

        /*
         * Status
         */
        .stat_tx_mcf(stat_tx_mcf)
    );

    mac_ctrl_rx #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_ENABLE(0),
        .ID_ENABLE(0),
        .DEST_ENABLE(0),
        .USER_ENABLE(1),
        .USER_WIDTH(RX_USER_WIDTH),
        .USE_READY(0),
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
    )
    mac_ctrl_rx_inst (
        .clk(rx_clk),
        .rst(rx_rst),

        /*
         * AXI stream input
         */
        .s_axis_tdata(rx_axis_tdata_int),
        .s_axis_tkeep(1'b1),
        .s_axis_tvalid(rx_axis_tvalid_int),
        .s_axis_tready(),
        .s_axis_tlast(rx_axis_tlast_int),
        .s_axis_tid(0),
        .s_axis_tdest(0),
        .s_axis_tuser(rx_axis_tuser_int),

        /*
         * AXI stream output
         */
        .m_axis_tdata(rx_axis_tdata),
        .m_axis_tkeep(),
        .m_axis_tvalid(rx_axis_tvalid),
        .m_axis_tready(1'b1),
        .m_axis_tlast(rx_axis_tlast),
        .m_axis_tid(),
        .m_axis_tdest(),
        .m_axis_tuser(rx_axis_tuser),

        /*
         * MAC control frame interface
         */
        .mcf_valid(rx_mcf_valid),
        .mcf_eth_dst(rx_mcf_eth_dst),
        .mcf_eth_src(rx_mcf_eth_src),
        .mcf_eth_type(rx_mcf_eth_type),
        .mcf_opcode(rx_mcf_opcode),
        .mcf_params(rx_mcf_params),
        .mcf_id(),
        .mcf_dest(),
        .mcf_user(),

        /*
         * Configuration
         */
        .cfg_mcf_rx_eth_dst_mcast(cfg_mcf_rx_eth_dst_mcast),
        .cfg_mcf_rx_check_eth_dst_mcast(cfg_mcf_rx_check_eth_dst_mcast),
        .cfg_mcf_rx_eth_dst_ucast(cfg_mcf_rx_eth_dst_ucast),
        .cfg_mcf_rx_check_eth_dst_ucast(cfg_mcf_rx_check_eth_dst_ucast),
        .cfg_mcf_rx_eth_src(cfg_mcf_rx_eth_src),
        .cfg_mcf_rx_check_eth_src(cfg_mcf_rx_check_eth_src),
        .cfg_mcf_rx_eth_type(cfg_mcf_rx_eth_type),
        .cfg_mcf_rx_opcode_lfc(cfg_mcf_rx_opcode_lfc),
        .cfg_mcf_rx_check_opcode_lfc(cfg_mcf_rx_check_opcode_lfc),
        .cfg_mcf_rx_opcode_pfc(cfg_mcf_rx_opcode_pfc),
        .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc),
        .cfg_mcf_rx_forward(cfg_mcf_rx_forward),
        .cfg_mcf_rx_enable(cfg_mcf_rx_enable),

        /*
         * Status
         */
        .stat_rx_mcf(stat_rx_mcf)
    );

    mac_pause_ctrl_tx #(
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE),
        .PFC_ENABLE(PFC_ENABLE)
    )
    mac_pause_ctrl_tx_inst (
        .clk(tx_clk),
        .rst(tx_rst),

        /*
         * MAC control frame interface
         */
        .mcf_valid(tx_mcf_valid),
        .mcf_ready(tx_mcf_ready),
        .mcf_eth_dst(tx_mcf_eth_dst),
        .mcf_eth_src(tx_mcf_eth_src),
        .mcf_eth_type(tx_mcf_eth_type),
        .mcf_opcode(tx_mcf_opcode),
        .mcf_params(tx_mcf_params),

        /*
         * Pause (IEEE 802.3 annex 31B)
         */
        .tx_lfc_req(tx_lfc_req),
        .tx_lfc_resend(tx_lfc_resend),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
         */
        .tx_pfc_req(tx_pfc_req),
        .tx_pfc_resend(tx_pfc_resend),

        /*
         * Configuration
         */
        .cfg_tx_lfc_eth_dst(cfg_tx_lfc_eth_dst),
        .cfg_tx_lfc_eth_src(cfg_tx_lfc_eth_src),
        .cfg_tx_lfc_eth_type(cfg_tx_lfc_eth_type),
        .cfg_tx_lfc_opcode(cfg_tx_lfc_opcode),
        .cfg_tx_lfc_en(cfg_tx_lfc_en),
        .cfg_tx_lfc_quanta(cfg_tx_lfc_quanta),
        .cfg_tx_lfc_refresh(cfg_tx_lfc_refresh),
        .cfg_tx_pfc_eth_dst(cfg_tx_pfc_eth_dst),
        .cfg_tx_pfc_eth_src(cfg_tx_pfc_eth_src),
        .cfg_tx_pfc_eth_type(cfg_tx_pfc_eth_type),
        .cfg_tx_pfc_opcode(cfg_tx_pfc_opcode),
        .cfg_tx_pfc_en(cfg_tx_pfc_en),
        .cfg_tx_pfc_quanta(cfg_tx_pfc_quanta),
        .cfg_tx_pfc_refresh(cfg_tx_pfc_refresh),
        .cfg_quanta_step(tx_mii_select ? (4*256)/512 : (8*256)/512),
        .cfg_quanta_clk_en(tx_clk_enable),

        /*
         * Status
         */
        .stat_tx_lfc_pkt(stat_tx_lfc_pkt),
        .stat_tx_lfc_xon(stat_tx_lfc_xon),
        .stat_tx_lfc_xoff(stat_tx_lfc_xoff),
        .stat_tx_lfc_paused(stat_tx_lfc_paused),
        .stat_tx_pfc_pkt(stat_tx_pfc_pkt),
        .stat_tx_pfc_xon(stat_tx_pfc_xon),
        .stat_tx_pfc_xoff(stat_tx_pfc_xoff),
        .stat_tx_pfc_paused(stat_tx_pfc_paused)
    );

    mac_pause_ctrl_rx #(
        .MCF_PARAMS_SIZE(18),
        .PFC_ENABLE(PFC_ENABLE)
    )
    mac_pause_ctrl_rx_inst (
        .clk(rx_clk),
        .rst(rx_rst),

        /*
         * MAC control frame interface
         */
        .mcf_valid(rx_mcf_valid),
        .mcf_eth_dst(rx_mcf_eth_dst),
        .mcf_eth_src(rx_mcf_eth_src),
        .mcf_eth_type(rx_mcf_eth_type),
        .mcf_opcode(rx_mcf_opcode),
        .mcf_params(rx_mcf_params),

        /*
         * Pause (IEEE 802.3 annex 31B)
         */
        .rx_lfc_en(rx_lfc_en),
        .rx_lfc_req(rx_lfc_req),
        .rx_lfc_ack(rx_lfc_ack_int),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
         */
        .rx_pfc_en(rx_pfc_en),
        .rx_pfc_req(rx_pfc_req),
        .rx_pfc_ack(rx_pfc_ack),

        /*
         * Configuration
         */
        .cfg_rx_lfc_opcode(cfg_rx_lfc_opcode),
        .cfg_rx_lfc_en(cfg_rx_lfc_en),
        .cfg_rx_pfc_opcode(cfg_rx_pfc_opcode),
        .cfg_rx_pfc_en(cfg_rx_pfc_en),
        .cfg_quanta_step(rx_mii_select ? (4*256)/512 : (8*256)/512),
        .cfg_quanta_clk_en(rx_clk_enable),

        /*
         * Status
         */
        .stat_rx_lfc_pkt(stat_rx_lfc_pkt),
        .stat_rx_lfc_xon(stat_rx_lfc_xon),
        .stat_rx_lfc_xoff(stat_rx_lfc_xoff),
        .stat_rx_lfc_paused(stat_rx_lfc_paused),
        .stat_rx_pfc_pkt(stat_rx_pfc_pkt),
        .stat_rx_pfc_xon(stat_rx_pfc_xon),
        .stat_rx_pfc_xoff(stat_rx_pfc_xoff),
        .stat_rx_pfc_paused(stat_rx_pfc_paused)
    );

end else begin

    assign tx_axis_tdata_int = tx_axis_tdata;
    assign tx_axis_tvalid_int = tx_axis_tvalid;
    assign tx_axis_tready = tx_axis_tready_int;
    assign tx_axis_tlast_int = tx_axis_tlast;
    assign tx_axis_tuser_int = tx_axis_tuser;

    assign rx_axis_tdata = rx_axis_tdata_int;
    assign rx_axis_tvalid = rx_axis_tvalid_int;
    assign rx_axis_tlast = rx_axis_tlast_int;
    assign rx_axis_tuser = rx_axis_tuser_int;

    assign rx_lfc_req = 0;
    assign rx_pfc_req = 0;
    assign tx_pause_ack = 0;

    assign stat_tx_mcf = 0;
    assign stat_rx_mcf = 0;
    assign stat_tx_lfc_pkt = 0;
    assign stat_tx_lfc_xon = 0;
    assign stat_tx_lfc_xoff = 0;
    assign stat_tx_lfc_paused = 0;
    assign stat_tx_pfc_pkt = 0;
    assign stat_tx_pfc_xon = 0;
    assign stat_tx_pfc_xoff = 0;
    assign stat_tx_pfc_paused = 0;
    assign stat_rx_lfc_pkt = 0;
    assign stat_rx_lfc_xon = 0;
    assign stat_rx_lfc_xoff = 0;
    assign stat_rx_lfc_paused = 0;
    assign stat_rx_pfc_pkt = 0;
    assign stat_rx_pfc_xon = 0;
    assign stat_rx_pfc_xoff = 0;
    assign stat_rx_pfc_paused = 0;

end

endgenerate

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/axis_gmii_rx.v ===== */
/*

Copyright (c) 2015-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream GMII frame receiver (GMII in, AXI out)
 */
module axis_gmii_rx #
(
    parameter DATA_WIDTH = 8,
    parameter PTP_TS_ENABLE = 0,
    parameter PTP_TS_WIDTH = 96,
    parameter USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * GMII input
     */
    input  wire [DATA_WIDTH-1:0]    gmii_rxd,
    input  wire                     gmii_rx_dv,
    input  wire                     gmii_rx_er,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    output wire                     m_axis_tlast,
    output wire [USER_WIDTH-1:0]    m_axis_tuser,

    /*
     * PTP
     */
    input  wire [PTP_TS_WIDTH-1:0]  ptp_ts,

    /*
     * Control
     */
    input  wire                     clk_enable,
    input  wire                     mii_select,

    /*
     * Configuration
     */
    input  wire                     cfg_rx_enable,

    /*
     * Status
     */
    output wire                     start_packet,
    output wire                     error_bad_frame,
    output wire                     error_bad_fcs
);

// bus width assertions
initial begin
    if (DATA_WIDTH != 8) begin
        $error("Error: Interface width must be 8");
        $finish;
    end
end

localparam [7:0]
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5;

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_PAYLOAD = 3'd1,
    STATE_WAIT_LAST = 3'd2;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg reset_crc;
reg update_crc;

reg mii_odd = 1'b0;
reg in_frame = 1'b0;

reg [DATA_WIDTH-1:0] gmii_rxd_d0 = {DATA_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] gmii_rxd_d1 = {DATA_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] gmii_rxd_d2 = {DATA_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] gmii_rxd_d3 = {DATA_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] gmii_rxd_d4 = {DATA_WIDTH{1'b0}};

reg gmii_rx_dv_d0 = 1'b0;
reg gmii_rx_dv_d1 = 1'b0;
reg gmii_rx_dv_d2 = 1'b0;
reg gmii_rx_dv_d3 = 1'b0;
reg gmii_rx_dv_d4 = 1'b0;

reg gmii_rx_er_d0 = 1'b0;
reg gmii_rx_er_d1 = 1'b0;
reg gmii_rx_er_d2 = 1'b0;
reg gmii_rx_er_d3 = 1'b0;
reg gmii_rx_er_d4 = 1'b0;

reg [DATA_WIDTH-1:0] m_axis_tdata_reg = {DATA_WIDTH{1'b0}}, m_axis_tdata_next;
reg m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg m_axis_tlast_reg = 1'b0, m_axis_tlast_next;
reg m_axis_tuser_reg = 1'b0, m_axis_tuser_next;

reg start_packet_int_reg = 1'b0;
reg start_packet_reg = 1'b0;
reg error_bad_frame_reg = 1'b0, error_bad_frame_next;
reg error_bad_fcs_reg = 1'b0, error_bad_fcs_next;

reg [PTP_TS_WIDTH-1:0] ptp_ts_reg = 0;

reg [31:0] crc_state = 32'hFFFFFFFF;
wire [31:0] crc_next;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tuser = PTP_TS_ENABLE ? {ptp_ts_reg, m_axis_tuser_reg} : m_axis_tuser_reg;

assign start_packet = start_packet_reg;
assign error_bad_frame = error_bad_frame_reg;
assign error_bad_fcs = error_bad_fcs_reg;

lfsr #(
    .LFSR_WIDTH(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_CONFIG("GALOIS"),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_WIDTH(8),
    .STYLE("AUTO")
)
eth_crc_8 (
    .data_in(gmii_rxd_d4),
    .state_in(crc_state),
    .data_out(),
    .state_out(crc_next)
);

always @* begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    m_axis_tdata_next = {DATA_WIDTH{1'b0}};
    m_axis_tvalid_next = 1'b0;
    m_axis_tlast_next = 1'b0;
    m_axis_tuser_next = 1'b0;

    error_bad_frame_next = 1'b0;
    error_bad_fcs_next = 1'b0;

    if (!clk_enable) begin
        // clock disabled - hold state
        state_next = state_reg;
    end else if (mii_select && !mii_odd) begin
        // MII even cycle - hold state
        state_next = state_reg;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;

                if (gmii_rx_dv_d4 && !gmii_rx_er_d4 && gmii_rxd_d4 == ETH_SFD && cfg_rx_enable) begin
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_PAYLOAD: begin
                // read payload
                update_crc = 1'b1;

                m_axis_tdata_next = gmii_rxd_d4;
                m_axis_tvalid_next = 1'b1;

                if (gmii_rx_dv_d4 && gmii_rx_er_d4) begin
                    // error
                    m_axis_tlast_next = 1'b1;
                    m_axis_tuser_next = 1'b1;
                    error_bad_frame_next = 1'b1;
                    state_next = STATE_WAIT_LAST;
                end else if (!gmii_rx_dv) begin
                    // end of packet
                    m_axis_tlast_next = 1'b1;
                    if (gmii_rx_er_d0 || gmii_rx_er_d1 || gmii_rx_er_d2 || gmii_rx_er_d3) begin
                        // error received in FCS bytes
                        m_axis_tuser_next = 1'b1;
                        error_bad_frame_next = 1'b1;
                    end else if ({gmii_rxd_d0, gmii_rxd_d1, gmii_rxd_d2, gmii_rxd_d3} == ~crc_next) begin
                        // FCS good
                        m_axis_tuser_next = 1'b0;
                    end else begin
                        // FCS bad
                        m_axis_tuser_next = 1'b1;
                        error_bad_frame_next = 1'b1;
                        error_bad_fcs_next = 1'b1;
                    end
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_WAIT_LAST: begin
                // wait for end of packet

                if (~gmii_rx_dv) begin
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    m_axis_tdata_reg <= m_axis_tdata_next;
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tlast_reg <= m_axis_tlast_next;
    m_axis_tuser_reg <= m_axis_tuser_next;

    start_packet_int_reg <= 1'b0;
    start_packet_reg <= 1'b0;

    if (start_packet_int_reg) begin
        ptp_ts_reg <= ptp_ts;
        start_packet_reg <= 1'b1;
    end

    if (clk_enable) begin
        if (mii_select) begin
            mii_odd <= !mii_odd;

            if (in_frame) begin
                in_frame <= gmii_rx_dv;
            end else if (gmii_rx_dv && {gmii_rxd[3:0], gmii_rxd_d0[7:4]} == ETH_SFD) begin
                in_frame <= 1'b1;
                start_packet_int_reg <= 1'b1;
                mii_odd <= 1'b1;
            end

            gmii_rxd_d0 <= {gmii_rxd[3:0], gmii_rxd_d0[7:4]};

            if (mii_odd) begin
                gmii_rxd_d1 <= gmii_rxd_d0;
                gmii_rxd_d2 <= gmii_rxd_d1;
                gmii_rxd_d3 <= gmii_rxd_d2;
                gmii_rxd_d4 <= gmii_rxd_d3;

                gmii_rx_dv_d0 <= gmii_rx_dv & gmii_rx_dv_d0;
                gmii_rx_dv_d1 <= gmii_rx_dv_d0 & gmii_rx_dv;
                gmii_rx_dv_d2 <= gmii_rx_dv_d1 & gmii_rx_dv;
                gmii_rx_dv_d3 <= gmii_rx_dv_d2 & gmii_rx_dv;
                gmii_rx_dv_d4 <= gmii_rx_dv_d3 & gmii_rx_dv;

                gmii_rx_er_d0 <= gmii_rx_er | gmii_rx_er_d0;
                gmii_rx_er_d1 <= gmii_rx_er_d0;
                gmii_rx_er_d2 <= gmii_rx_er_d1;
                gmii_rx_er_d3 <= gmii_rx_er_d2;
                gmii_rx_er_d4 <= gmii_rx_er_d3;
            end else begin
                gmii_rx_dv_d0 <= gmii_rx_dv;
                gmii_rx_er_d0 <= gmii_rx_er;
            end
        end else begin
            if (in_frame) begin
                in_frame <= gmii_rx_dv;
            end else if (gmii_rx_dv && gmii_rxd == ETH_SFD) begin
                in_frame <= 1'b1;
                start_packet_int_reg <= 1'b1;
            end

            gmii_rxd_d0 <= gmii_rxd;
            gmii_rxd_d1 <= gmii_rxd_d0;
            gmii_rxd_d2 <= gmii_rxd_d1;
            gmii_rxd_d3 <= gmii_rxd_d2;
            gmii_rxd_d4 <= gmii_rxd_d3;

            gmii_rx_dv_d0 <= gmii_rx_dv;
            gmii_rx_dv_d1 <= gmii_rx_dv_d0 & gmii_rx_dv;
            gmii_rx_dv_d2 <= gmii_rx_dv_d1 & gmii_rx_dv;
            gmii_rx_dv_d3 <= gmii_rx_dv_d2 & gmii_rx_dv;
            gmii_rx_dv_d4 <= gmii_rx_dv_d3 & gmii_rx_dv;

            gmii_rx_er_d0 <= gmii_rx_er;
            gmii_rx_er_d1 <= gmii_rx_er_d0;
            gmii_rx_er_d2 <= gmii_rx_er_d1;
            gmii_rx_er_d3 <= gmii_rx_er_d2;
            gmii_rx_er_d4 <= gmii_rx_er_d3;
        end
    end

    if (reset_crc) begin
        crc_state <= 32'hFFFFFFFF;
    end else if (update_crc) begin
        crc_state <= crc_next;
    end

    error_bad_frame_reg <= error_bad_frame_next;
    error_bad_fcs_reg <= error_bad_fcs_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        m_axis_tvalid_reg <= 1'b0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= 1'b0;
        error_bad_frame_reg <= 1'b0;
        error_bad_fcs_reg <= 1'b0;

        in_frame <= 1'b0;
        mii_odd <= 1'b0;

        gmii_rx_dv_d0 <= 1'b0;
        gmii_rx_dv_d1 <= 1'b0;
        gmii_rx_dv_d2 <= 1'b0;
        gmii_rx_dv_d3 <= 1'b0;
        gmii_rx_dv_d4 <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/axis_gmii_tx.v ===== */
/*

Copyright (c) 2015-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream GMII frame transmitter (AXI in, GMII out)
 */
module axis_gmii_tx #
(
    parameter DATA_WIDTH = 8,
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter PTP_TS_ENABLE = 0,
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_TS_CTRL_IN_TUSER = 0,
    parameter PTP_TAG_ENABLE = PTP_TS_ENABLE,
    parameter PTP_TAG_WIDTH = 16,
    parameter USER_WIDTH = (PTP_TS_ENABLE ? (PTP_TAG_ENABLE ? PTP_TAG_WIDTH : 0) + (PTP_TS_CTRL_IN_TUSER ? 1 : 0) : 0) + 1
)
(
    input  wire                      clk,
    input  wire                      rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]     s_axis_tdata,
    input  wire                      s_axis_tvalid,
    output wire                      s_axis_tready,
    input  wire                      s_axis_tlast,
    input  wire [USER_WIDTH-1:0]     s_axis_tuser,

    /*
     * GMII output
     */
    output wire [DATA_WIDTH-1:0]     gmii_txd,
    output wire                      gmii_tx_en,
    output wire                      gmii_tx_er,

    /*
     * PTP
     */
    input  wire [PTP_TS_WIDTH-1:0]   ptp_ts,
    output wire [PTP_TS_WIDTH-1:0]   m_axis_ptp_ts,
    output wire [PTP_TAG_WIDTH-1:0]  m_axis_ptp_ts_tag,
    output wire                      m_axis_ptp_ts_valid,

    /*
     * Control
     */
    input  wire                      clk_enable,
    input  wire                      mii_select,

    /*
     * Configuration
     */
    input  wire [7:0]                cfg_ifg,
    input  wire                      cfg_tx_enable,

    /*
     * Status
     */
    output wire                      start_packet,
    output wire                      error_underflow
);

parameter MIN_LEN_WIDTH = $clog2(MIN_FRAME_LENGTH-4-1+1);

// bus width assertions
initial begin
    if (DATA_WIDTH != 8) begin
        $error("Error: Interface width must be 8");
        $finish;
    end
end

localparam [7:0]
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5;

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_PREAMBLE = 3'd1,
    STATE_PAYLOAD = 3'd2,
    STATE_LAST = 3'd3,
    STATE_PAD = 3'd4,
    STATE_FCS = 3'd5,
    STATE_IFG = 3'd6;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg reset_crc;
reg update_crc;

reg [7:0] s_tdata_reg = 8'd0, s_tdata_next;

reg mii_odd_reg = 1'b0, mii_odd_next;
reg [3:0] mii_msn_reg = 4'b0, mii_msn_next;

reg frame_reg = 1'b0, frame_next;
reg frame_error_reg = 1'b0, frame_error_next;
reg [7:0] frame_ptr_reg = 0, frame_ptr_next;
reg [MIN_LEN_WIDTH-1:0] frame_min_count_reg = 0, frame_min_count_next;

reg [7:0] gmii_txd_reg = 8'd0, gmii_txd_next;
reg gmii_tx_en_reg = 1'b0, gmii_tx_en_next;
reg gmii_tx_er_reg = 1'b0, gmii_tx_er_next;

reg s_axis_tready_reg = 1'b0, s_axis_tready_next;

reg [PTP_TS_WIDTH-1:0] m_axis_ptp_ts_reg = 0, m_axis_ptp_ts_next;
reg [PTP_TAG_WIDTH-1:0] m_axis_ptp_ts_tag_reg = 0, m_axis_ptp_ts_tag_next;
reg m_axis_ptp_ts_valid_reg = 1'b0, m_axis_ptp_ts_valid_next;

reg start_packet_int_reg = 1'b0, start_packet_int_next;
reg start_packet_reg = 1'b0, start_packet_next;
reg error_underflow_reg = 1'b0, error_underflow_next;

reg [31:0] crc_state = 32'hFFFFFFFF;
wire [31:0] crc_next;

assign s_axis_tready = s_axis_tready_reg;

assign gmii_txd = gmii_txd_reg;
assign gmii_tx_en = gmii_tx_en_reg;
assign gmii_tx_er = gmii_tx_er_reg;

assign m_axis_ptp_ts = PTP_TS_ENABLE ? m_axis_ptp_ts_reg : 0;
assign m_axis_ptp_ts_tag = PTP_TAG_ENABLE ? m_axis_ptp_ts_tag_reg : 0;
assign m_axis_ptp_ts_valid = PTP_TS_ENABLE || PTP_TAG_ENABLE ? m_axis_ptp_ts_valid_reg : 1'b0;

assign start_packet = start_packet_reg;
assign error_underflow = error_underflow_reg;

lfsr #(
    .LFSR_WIDTH(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_CONFIG("GALOIS"),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_WIDTH(8),
    .STYLE("AUTO")
)
eth_crc_8 (
    .data_in(s_tdata_reg),
    .state_in(crc_state),
    .data_out(),
    .state_out(crc_next)
);

always @* begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    mii_odd_next = mii_odd_reg;
    mii_msn_next = mii_msn_reg;

    frame_next = frame_reg;
    frame_error_next = frame_error_reg;
    frame_ptr_next = frame_ptr_reg;
    frame_min_count_next = frame_min_count_reg;

    s_axis_tready_next = 1'b0;

    s_tdata_next = s_tdata_reg;

    m_axis_ptp_ts_next = m_axis_ptp_ts_reg;
    m_axis_ptp_ts_tag_next = m_axis_ptp_ts_tag_reg;
    m_axis_ptp_ts_valid_next = 1'b0;

    if (start_packet_reg && PTP_TS_ENABLE) begin
        m_axis_ptp_ts_next = ptp_ts;
        if (PTP_TS_CTRL_IN_TUSER) begin
            m_axis_ptp_ts_tag_next = s_axis_tuser >> 2;
            m_axis_ptp_ts_valid_next = s_axis_tuser[1];
        end else begin
            m_axis_ptp_ts_tag_next = s_axis_tuser >> 1;
            m_axis_ptp_ts_valid_next = 1'b1;
        end
    end

    gmii_txd_next = {DATA_WIDTH{1'b0}};
    gmii_tx_en_next = 1'b0;
    gmii_tx_er_next = 1'b0;

    start_packet_int_next = start_packet_int_reg;
    start_packet_next = 1'b0;
    error_underflow_next = 1'b0;

    if (s_axis_tvalid && s_axis_tready) begin
        frame_next = !s_axis_tlast;
    end

    if (!clk_enable) begin
        // clock disabled - hold state and outputs
        gmii_txd_next = gmii_txd_reg;
        gmii_tx_en_next = gmii_tx_en_reg;
        gmii_tx_er_next = gmii_tx_er_reg;
        state_next = state_reg;
    end else if (mii_select && mii_odd_reg) begin
        // MII odd cycle - hold state, output MSN
        mii_odd_next = 1'b0;
        gmii_txd_next = {4'd0, mii_msn_reg};
        gmii_tx_en_next = gmii_tx_en_reg;
        gmii_tx_er_next = gmii_tx_er_reg;
        state_next = state_reg;
        if (start_packet_int_reg) begin
            start_packet_int_next = 1'b0;
            start_packet_next = 1'b1;
        end
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;

                mii_odd_next = 1'b0;
                frame_ptr_next = 1;

                frame_error_next = 1'b0;
                frame_min_count_next = MIN_FRAME_LENGTH-4-1;

                if (s_axis_tvalid && cfg_tx_enable) begin
                    mii_odd_next = 1'b1;
                    gmii_txd_next = ETH_PRE;
                    gmii_tx_en_next = 1'b1;
                    state_next = STATE_PREAMBLE;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // send preamble
                reset_crc = 1'b1;

                mii_odd_next = 1'b1;
                frame_ptr_next = frame_ptr_reg + 1;

                gmii_txd_next = ETH_PRE;
                gmii_tx_en_next = 1'b1;

                if (frame_ptr_reg == 6) begin
                    s_axis_tready_next = 1'b1;
                    s_tdata_next = s_axis_tdata;
                    state_next = STATE_PREAMBLE;
                end else if (frame_ptr_reg == 7) begin
                    // end of preamble; start payload
                    frame_ptr_next = 0;
                    if (s_axis_tready_reg) begin
                        s_axis_tready_next = 1'b1;
                        s_tdata_next = s_axis_tdata;
                    end
                    gmii_txd_next = ETH_SFD;
                    if (mii_select) begin
                        start_packet_int_next = 1'b1;
                    end else begin
                        start_packet_next = 1'b1;
                    end
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_PREAMBLE;
                end
            end
            STATE_PAYLOAD: begin
                // send payload

                update_crc = 1'b1;
                s_axis_tready_next = 1'b1;

                mii_odd_next = 1'b1;

                if (frame_min_count_reg) begin
                    frame_min_count_next = frame_min_count_reg - 1;
                end

                gmii_txd_next = s_tdata_reg;
                gmii_tx_en_next = 1'b1;

                s_tdata_next = s_axis_tdata;

                if (!s_axis_tvalid || s_axis_tlast) begin
                    s_axis_tready_next = frame_next; // drop frame
                    frame_error_next = !s_axis_tvalid || s_axis_tuser[0];
                    error_underflow_next = !s_axis_tvalid;

                    state_next = STATE_LAST;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_LAST: begin
                // last payload word

                update_crc = 1'b1;
                s_axis_tready_next = 1'b0;

                mii_odd_next = 1'b1;

                gmii_txd_next = s_tdata_reg;
                gmii_tx_en_next = 1'b1;

                if (ENABLE_PADDING && frame_min_count_reg) begin
                    frame_min_count_next = frame_min_count_reg - 1;
                    s_tdata_next = 8'd0;
                    state_next = STATE_PAD;
                end else begin
                    frame_ptr_next = 0;
                    state_next = STATE_FCS;
                end
            end
            STATE_PAD: begin
                // send padding
                s_axis_tready_next = frame_next; // drop frame

                update_crc = 1'b1;
                mii_odd_next = 1'b1;

                gmii_txd_next = 8'd0;
                gmii_tx_en_next = 1'b1;

                s_tdata_next = 8'd0;

                if (frame_min_count_reg) begin
                    frame_min_count_next = frame_min_count_reg - 1;
                    state_next = STATE_PAD;
                end else begin
                    frame_ptr_next = 0;
                    state_next = STATE_FCS;
                end
            end
            STATE_FCS: begin
                // send FCS
                s_axis_tready_next = frame_next; // drop frame

                mii_odd_next = 1'b1;
                frame_ptr_next = frame_ptr_reg + 1;

                case (frame_ptr_reg)
                    2'd0: gmii_txd_next = ~crc_state[7:0];
                    2'd1: gmii_txd_next = ~crc_state[15:8];
                    2'd2: gmii_txd_next = ~crc_state[23:16];
                    2'd3: gmii_txd_next = ~crc_state[31:24];
                endcase
                gmii_tx_en_next = 1'b1;
                gmii_tx_er_next = frame_error_reg;

                if (frame_ptr_reg < 3) begin
                    state_next = STATE_FCS;
                end else begin
                    frame_ptr_next = 0;
                    state_next = STATE_IFG;
                end
            end
            STATE_IFG: begin
                // send IFG
                s_axis_tready_next = frame_next; // drop frame

                mii_odd_next = 1'b1;
                frame_ptr_next = frame_ptr_reg + 1;

                if (frame_ptr_reg < cfg_ifg-1 || frame_reg) begin
                    state_next = STATE_IFG;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
        endcase

        if (mii_select) begin
            mii_msn_next = gmii_txd_next[7:4];
            gmii_txd_next[7:4] = 4'd0;
        end
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    frame_reg <= frame_next;
    frame_error_reg <= frame_error_next;
    frame_ptr_reg <= frame_ptr_next;
    frame_min_count_reg <= frame_min_count_next;

    m_axis_ptp_ts_reg <= m_axis_ptp_ts_next;
    m_axis_ptp_ts_tag_reg <= m_axis_ptp_ts_tag_next;
    m_axis_ptp_ts_valid_reg <= m_axis_ptp_ts_valid_next;

    mii_odd_reg <= mii_odd_next;
    mii_msn_reg <= mii_msn_next;

    s_tdata_reg <= s_tdata_next;

    s_axis_tready_reg <= s_axis_tready_next;

    gmii_txd_reg <= gmii_txd_next;
    gmii_tx_en_reg <= gmii_tx_en_next;
    gmii_tx_er_reg <= gmii_tx_er_next;

    if (reset_crc) begin
        crc_state <= 32'hFFFFFFFF;
    end else if (update_crc) begin
        crc_state <= crc_next;
    end

    start_packet_int_reg <= start_packet_int_next;
    start_packet_reg <= start_packet_next;
    error_underflow_reg <= error_underflow_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        frame_reg <= 1'b0;

        s_axis_tready_reg <= 1'b0;

        m_axis_ptp_ts_valid_reg <= 1'b0;

        gmii_tx_en_reg <= 1'b0;
        gmii_tx_er_reg <= 1'b0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= 1'b0;
        error_underflow_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/lfsr.v ===== */
/*

Copyright (c) 2016-2023 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Parametrizable combinatorial parallel LFSR/CRC
 */
module lfsr #
(
    // width of LFSR
    parameter LFSR_WIDTH = 31,
    // LFSR polynomial
    parameter LFSR_POLY = 31'h10000001,
    // LFSR configuration: "GALOIS", "FIBONACCI"
    parameter LFSR_CONFIG = "FIBONACCI",
    // LFSR feed forward enable
    parameter LFSR_FEED_FORWARD = 0,
    // bit-reverse input and output
    parameter REVERSE = 0,
    // width of data input
    parameter DATA_WIDTH = 8,
    // implementation style: "AUTO", "LOOP", "REDUCTION"
    parameter STYLE = "AUTO"
)
(
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire [LFSR_WIDTH-1:0] state_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire [LFSR_WIDTH-1:0] state_out
);

/*

Fully parametrizable combinatorial parallel LFSR/CRC module.  Implements an unrolled LFSR
next state computation, shifting DATA_WIDTH bits per pass through the module.  Input data
is XORed with LFSR feedback path, tie data_in to zero if this is not required.

Works in two parts: statically computes a set of bit masks, then uses these bit masks to
select bits for XORing to compute the next state.  

Ports:

data_in

Data bits to be shifted through the LFSR (DATA_WIDTH bits)

state_in

LFSR/CRC current state input (LFSR_WIDTH bits)

data_out

Data bits shifted out of LFSR (DATA_WIDTH bits)

state_out

LFSR/CRC next state output (LFSR_WIDTH bits)

Parameters:

LFSR_WIDTH

Specify width of LFSR/CRC register

LFSR_POLY

Specify the LFSR/CRC polynomial in hex format.  For example, the polynomial

x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1

would be represented as

32'h04c11db7

Note that the largest term (x^32) is suppressed.  This term is generated automatically based
on LFSR_WIDTH.

LFSR_CONFIG

Specify the LFSR configuration, either Fibonacci or Galois.  Fibonacci is generally used
for linear-feedback shift registers (LFSR) for pseudorandom binary sequence (PRBS) generators,
scramblers, and descrambers, while Galois is generally used for cyclic redundancy check
generators and checkers.

Fibonacci style (example for 64b66b scrambler, 0x8000000001)

   DIN (LSB first)
    |
    V
   (+)<---------------------------(+)<-----------------------------.
    |                              ^                               |
    |  .----.  .----.       .----. |  .----.       .----.  .----.  |
    +->|  0 |->|  1 |->...->| 38 |-+->| 39 |->...->| 56 |->| 57 |--'
    |  '----'  '----'       '----'    '----'       '----'  '----'
    V
   DOUT

Galois style (example for CRC16, 0x8005)

    ,-------------------+-------------------------+----------(+)<-- DIN (MSB first)
    |                   |                         |           ^
    |  .----.  .----.   V   .----.       .----.   V   .----.  |
    `->|  0 |->|  1 |->(+)->|  2 |->...->| 14 |->(+)->| 15 |--+---> DOUT
       '----'  '----'       '----'       '----'       '----'

LFSR_FEED_FORWARD

Generate feed forward instead of feed back LFSR.  Enable this for PRBS checking and self-
synchronous descrambling.

Fibonacci feed-forward style (example for 64b66b descrambler, 0x8000000001)

   DIN (LSB first)
    |
    |  .----.  .----.       .----.    .----.       .----.  .----.
    +->|  0 |->|  1 |->...->| 38 |-+->| 39 |->...->| 56 |->| 57 |--.
    |  '----'  '----'       '----' |  '----'       '----'  '----'  |
    |                              V                               |
   (+)<---------------------------(+)------------------------------'
    |
    V
   DOUT

Galois feed-forward style

    ,-------------------+-------------------------+------------+--- DIN (MSB first)
    |                   |                         |            |
    |  .----.  .----.   V   .----.       .----.   V   .----.   V
    `->|  0 |->|  1 |->(+)->|  2 |->...->| 14 |->(+)->| 15 |->(+)-> DOUT
       '----'  '----'       '----'       '----'       '----'

REVERSE

Bit-reverse LFSR input and output.  Shifts MSB first by default, set REVERSE for LSB first.

DATA_WIDTH

Specify width of input and output data bus.  The module will perform one shift per input
data bit, so if the input data bus is not required tie data_in to zero and set DATA_WIDTH
to the required number of shifts per clock cycle.  

STYLE

Specify implementation style.  Can be "AUTO", "LOOP", or "REDUCTION".  When "AUTO"
is selected, implemenation will be "LOOP" or "REDUCTION" based on synthesis translate
directives.  "REDUCTION" and "LOOP" are functionally identical, however they simulate
and synthesize differently.  "REDUCTION" is implemented with a loop over a Verilog
reduction operator.  "LOOP" is implemented as a doubly-nested loop with no reduction
operator.  "REDUCTION" is very fast for simulation in iverilog and synthesizes well in
Quartus but synthesizes poorly in ISE, likely due to large inferred XOR gates causing
problems with the optimizer.  "LOOP" synthesizes will in both ISE and Quartus.  "AUTO"
will default to "REDUCTION" when simulating and "LOOP" for synthesizers that obey
synthesis translate directives.

Settings for common LFSR/CRC implementations:

Name        Configuration           Length  Polynomial      Initial value   Notes
CRC16-IBM   Galois, bit-reverse     16      16'h8005        16'hffff
CRC16-CCITT Galois                  16      16'h1021        16'h1d0f
CRC32       Galois, bit-reverse     32      32'h04c11db7    32'hffffffff    Ethernet FCS; invert final output
CRC32C      Galois, bit-reverse     32      32'h1edc6f41    32'hffffffff    iSCSI, Intel CRC32 instruction; invert final output
PRBS6       Fibonacci               6       6'h21           any
PRBS7       Fibonacci               7       7'h41           any
PRBS9       Fibonacci               9       9'h021          any             ITU V.52
PRBS10      Fibonacci               10      10'h081         any             ITU
PRBS11      Fibonacci               11      11'h201         any             ITU O.152
PRBS15      Fibonacci, inverted     15      15'h4001        any             ITU O.152
PRBS17      Fibonacci               17      17'h04001       any
PRBS20      Fibonacci               20      20'h00009       any             ITU V.57
PRBS23      Fibonacci, inverted     23      23'h040001      any             ITU O.151
PRBS29      Fibonacci, inverted     29      29'h08000001    any
PRBS31      Fibonacci, inverted     31      31'h10000001    any
64b66b      Fibonacci, bit-reverse  58      58'h8000000001  any             10G Ethernet
128b130b    Galois, bit-reverse     23      23'h210125      any             PCIe gen 3

*/

function [LFSR_WIDTH+DATA_WIDTH-1:0] lfsr_mask(input [31:0] index);
    reg [LFSR_WIDTH-1:0] lfsr_mask_state[LFSR_WIDTH-1:0];
    reg [DATA_WIDTH-1:0] lfsr_mask_data[LFSR_WIDTH-1:0];
    reg [LFSR_WIDTH-1:0] output_mask_state[DATA_WIDTH-1:0];
    reg [DATA_WIDTH-1:0] output_mask_data[DATA_WIDTH-1:0];

    reg [LFSR_WIDTH-1:0] state_val;
    reg [DATA_WIDTH-1:0] data_val;

    reg [DATA_WIDTH-1:0] data_mask;

    integer i, j;

    begin
        // init bit masks
        for (i = 0; i < LFSR_WIDTH; i = i + 1) begin
            lfsr_mask_state[i] = 0;
            lfsr_mask_state[i][i] = 1'b1;
            lfsr_mask_data[i] = 0;
        end
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            output_mask_state[i] = 0;
            if (i < LFSR_WIDTH) begin
                output_mask_state[i][i] = 1'b1;
            end
            output_mask_data[i] = 0;
        end

        // simulate shift register
        if (LFSR_CONFIG == "FIBONACCI") begin
            // Fibonacci configuration
            for (data_mask = {1'b1, {DATA_WIDTH-1{1'b0}}}; data_mask != 0; data_mask = data_mask >> 1) begin
                // determine shift in value
                // current value in last FF, XOR with input data bit (MSB first)
                state_val = lfsr_mask_state[LFSR_WIDTH-1];
                data_val = lfsr_mask_data[LFSR_WIDTH-1];
                data_val = data_val ^ data_mask;

                // add XOR inputs from correct indicies
                for (j = 1; j < LFSR_WIDTH; j = j + 1) begin
                    if ((LFSR_POLY >> j) & 1) begin
                        state_val = lfsr_mask_state[j-1] ^ state_val;
                        data_val = lfsr_mask_data[j-1] ^ data_val;
                    end
                end

                // shift
                for (j = LFSR_WIDTH-1; j > 0; j = j - 1) begin
                    lfsr_mask_state[j] = lfsr_mask_state[j-1];
                    lfsr_mask_data[j] = lfsr_mask_data[j-1];
                end
                for (j = DATA_WIDTH-1; j > 0; j = j - 1) begin
                    output_mask_state[j] = output_mask_state[j-1];
                    output_mask_data[j] = output_mask_data[j-1];
                end
                output_mask_state[0] = state_val;
                output_mask_data[0] = data_val;
                if (LFSR_FEED_FORWARD) begin
                    // only shift in new input data
                    state_val = {LFSR_WIDTH{1'b0}};
                    data_val = data_mask;
                end
                lfsr_mask_state[0] = state_val;
                lfsr_mask_data[0] = data_val;
            end
        end else if (LFSR_CONFIG == "GALOIS") begin
            // Galois configuration
            for (data_mask = {1'b1, {DATA_WIDTH-1{1'b0}}}; data_mask != 0; data_mask = data_mask >> 1) begin
                // determine shift in value
                // current value in last FF, XOR with input data bit (MSB first)
                state_val = lfsr_mask_state[LFSR_WIDTH-1];
                data_val = lfsr_mask_data[LFSR_WIDTH-1];
                data_val = data_val ^ data_mask;

                // shift
                for (j = LFSR_WIDTH-1; j > 0; j = j - 1) begin
                    lfsr_mask_state[j] = lfsr_mask_state[j-1];
                    lfsr_mask_data[j] = lfsr_mask_data[j-1];
                end
                for (j = DATA_WIDTH-1; j > 0; j = j - 1) begin
                    output_mask_state[j] = output_mask_state[j-1];
                    output_mask_data[j] = output_mask_data[j-1];
                end
                output_mask_state[0] = state_val;
                output_mask_data[0] = data_val;
                if (LFSR_FEED_FORWARD) begin
                    // only shift in new input data
                    state_val = {LFSR_WIDTH{1'b0}};
                    data_val = data_mask;
                end
                lfsr_mask_state[0] = state_val;
                lfsr_mask_data[0] = data_val;

                // add XOR inputs at correct indicies
                for (j = 1; j < LFSR_WIDTH; j = j + 1) begin
                    if ((LFSR_POLY >> j) & 1) begin
                        lfsr_mask_state[j] = lfsr_mask_state[j] ^ state_val;
                        lfsr_mask_data[j] = lfsr_mask_data[j] ^ data_val;
                    end
                end
            end
        end else begin
            $error("Error: unknown configuration setting!");
            $finish;
        end

        // reverse bits if selected
        if (REVERSE) begin
            if (index < LFSR_WIDTH) begin
                state_val = 0;
                for (i = 0; i < LFSR_WIDTH; i = i + 1) begin
                    state_val[i] = lfsr_mask_state[LFSR_WIDTH-index-1][LFSR_WIDTH-i-1];
                end

                data_val = 0;
                for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                    data_val[i] = lfsr_mask_data[LFSR_WIDTH-index-1][DATA_WIDTH-i-1];
                end
            end else begin
                state_val = 0;
                for (i = 0; i < LFSR_WIDTH; i = i + 1) begin
                    state_val[i] = output_mask_state[DATA_WIDTH-(index-LFSR_WIDTH)-1][LFSR_WIDTH-i-1];
                end

                data_val = 0;
                for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                    data_val[i] = output_mask_data[DATA_WIDTH-(index-LFSR_WIDTH)-1][DATA_WIDTH-i-1];
                end
            end
        end else begin
            if (index < LFSR_WIDTH) begin
                state_val = lfsr_mask_state[index];
                data_val = lfsr_mask_data[index];
            end else begin
                state_val = output_mask_state[index-LFSR_WIDTH];
                data_val = output_mask_data[index-LFSR_WIDTH];
            end
        end
        lfsr_mask = {data_val, state_val};
    end
endfunction

// synthesis translate_off
`define SIMULATION
// synthesis translate_on

`ifdef SIMULATION
// "AUTO" style is "REDUCTION" for faster simulation
parameter STYLE_INT = (STYLE == "AUTO") ? "REDUCTION" : STYLE;
`else
// "AUTO" style is "LOOP" for better synthesis result
parameter STYLE_INT = (STYLE == "AUTO") ? "LOOP" : STYLE;
`endif

genvar n;

generate

if (STYLE_INT == "REDUCTION") begin

    // use Verilog reduction operator
    // fast in iverilog
    // significantly larger than generated code with ISE (inferred wide XORs may be tripping up optimizer)
    // slightly smaller than generated code with Quartus
    // --> better for simulation

    for (n = 0; n < LFSR_WIDTH; n = n + 1) begin : lfsr_state
        wire [LFSR_WIDTH+DATA_WIDTH-1:0] mask = lfsr_mask(n);
        assign state_out[n] = ^({data_in, state_in} & mask);
    end
    for (n = 0; n < DATA_WIDTH; n = n + 1) begin : lfsr_data
        wire [LFSR_WIDTH+DATA_WIDTH-1:0] mask = lfsr_mask(n+LFSR_WIDTH);
        assign data_out[n] = ^({data_in, state_in} & mask);
    end

end else if (STYLE_INT == "LOOP") begin

    // use nested loops
    // very slow in iverilog
    // slightly smaller than generated code with ISE
    // same size as generated code with Quartus
    // --> better for synthesis

    for (n = 0; n < LFSR_WIDTH; n = n + 1) begin : lfsr_state
        wire [LFSR_WIDTH+DATA_WIDTH-1:0] mask = lfsr_mask(n);

        reg state_reg;

        assign state_out[n] = state_reg;

        integer i;

        always @* begin
            state_reg = 1'b0;
            for (i = 0; i < LFSR_WIDTH; i = i + 1) begin
                if (mask[i]) begin
                    state_reg = state_reg ^ state_in[i];
                end
            end
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                if (mask[i+LFSR_WIDTH]) begin
                    state_reg = state_reg ^ data_in[i];
                end
            end
        end
    end
    for (n = 0; n < DATA_WIDTH; n = n + 1) begin : lfsr_data
        wire [LFSR_WIDTH+DATA_WIDTH-1:0] mask = lfsr_mask(n+LFSR_WIDTH);

        reg data_reg;

        assign data_out[n] = data_reg;

        integer i;

        always @* begin
            data_reg = 1'b0;
            for (i = 0; i < LFSR_WIDTH; i = i + 1) begin
                if (mask[i]) begin
                    data_reg = data_reg ^ state_in[i];
                end
            end
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                if (mask[i+LFSR_WIDTH]) begin
                    data_reg = data_reg ^ data_in[i];
                end
            end
        end
    end

end else begin

    initial begin
        $error("Error: unknown style setting!");
        $finish;
    end

end

endgenerate

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/eth_axis_rx.v ===== */
/*

Copyright (c) 2014-2020 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream ethernet frame receiver (AXI in, Ethernet frame out)
 */
module eth_axis_rx #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                  clk,
    input  wire                  rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0] s_axis_tkeep,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,
    input  wire                  s_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire                  m_eth_hdr_valid,
    input  wire                  m_eth_hdr_ready,
    output wire [47:0]           m_eth_dest_mac,
    output wire [47:0]           m_eth_src_mac,
    output wire [15:0]           m_eth_type,
    output wire [DATA_WIDTH-1:0] m_eth_payload_axis_tdata,
    output wire [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep,
    output wire                  m_eth_payload_axis_tvalid,
    input  wire                  m_eth_payload_axis_tready,
    output wire                  m_eth_payload_axis_tlast,
    output wire                  m_eth_payload_axis_tuser,

    /*
     * Status signals
     */
    output wire                  busy,
    output wire                  error_header_early_termination
);

parameter BYTE_LANES = KEEP_ENABLE ? KEEP_WIDTH : 1;

parameter HDR_SIZE = 14;

parameter CYCLE_COUNT = (HDR_SIZE+BYTE_LANES-1)/BYTE_LANES;

parameter PTR_WIDTH = $clog2(CYCLE_COUNT);

parameter OFFSET = HDR_SIZE % BYTE_LANES;

// bus width assertions
initial begin
    if (BYTE_LANES * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

/*

Ethernet frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype                   2 octets

This module receives an Ethernet frame on an AXI stream interface, decodes
and strips the headers, then produces the header fields in parallel along
with the payload in a separate AXI stream.

*/

reg read_eth_header_reg = 1'b1, read_eth_header_next;
reg read_eth_payload_reg = 1'b0, read_eth_payload_next;
reg [PTR_WIDTH-1:0] ptr_reg = 0, ptr_next;

reg flush_save;
reg transfer_in_save;

reg s_axis_tready_reg = 1'b0, s_axis_tready_next;

reg m_eth_hdr_valid_reg = 1'b0, m_eth_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0, m_eth_dest_mac_next;
reg [47:0] m_eth_src_mac_reg = 48'd0, m_eth_src_mac_next;
reg [15:0] m_eth_type_reg = 16'd0, m_eth_type_next;

reg busy_reg = 1'b0;
reg error_header_early_termination_reg = 1'b0, error_header_early_termination_next;

reg [DATA_WIDTH-1:0] save_axis_tdata_reg = 64'd0;
reg [KEEP_WIDTH-1:0] save_axis_tkeep_reg = 8'd0;
reg save_axis_tlast_reg = 1'b0;
reg save_axis_tuser_reg = 1'b0;

reg [DATA_WIDTH-1:0] shift_axis_tdata;
reg [KEEP_WIDTH-1:0] shift_axis_tkeep;
reg shift_axis_tvalid;
reg shift_axis_tlast;
reg shift_axis_tuser;
reg shift_axis_input_tready;
reg shift_axis_extra_cycle_reg = 1'b0;

// internal datapath
reg [DATA_WIDTH-1:0] m_eth_payload_axis_tdata_int;
reg [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep_int;
reg                  m_eth_payload_axis_tvalid_int;
reg                  m_eth_payload_axis_tready_int_reg = 1'b0;
reg                  m_eth_payload_axis_tlast_int;
reg                  m_eth_payload_axis_tuser_int;
wire                 m_eth_payload_axis_tready_int_early;

assign s_axis_tready = s_axis_tready_reg;

assign m_eth_hdr_valid = m_eth_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;

assign busy = busy_reg;
assign error_header_early_termination = error_header_early_termination_reg;

always @* begin
    if (OFFSET == 0) begin
        // passthrough if no overlap
        shift_axis_tdata = s_axis_tdata;
        shift_axis_tkeep = s_axis_tkeep;
        shift_axis_tvalid = s_axis_tvalid;
        shift_axis_tlast = s_axis_tlast;
        shift_axis_tuser = s_axis_tuser;
        shift_axis_input_tready = 1'b1;
    end else if (shift_axis_extra_cycle_reg) begin
        shift_axis_tdata = {s_axis_tdata, save_axis_tdata_reg} >> (OFFSET*8);
        shift_axis_tkeep = {{KEEP_WIDTH{1'b0}}, save_axis_tkeep_reg} >> OFFSET;
        shift_axis_tvalid = 1'b1;
        shift_axis_tlast = save_axis_tlast_reg;
        shift_axis_tuser = save_axis_tuser_reg;
        shift_axis_input_tready = flush_save;
    end else begin
        shift_axis_tdata = {s_axis_tdata, save_axis_tdata_reg} >> (OFFSET*8);
        shift_axis_tkeep = {s_axis_tkeep, save_axis_tkeep_reg} >> OFFSET;
        shift_axis_tvalid = s_axis_tvalid;
        shift_axis_tlast = (s_axis_tlast && ((s_axis_tkeep & ({KEEP_WIDTH{1'b1}} << OFFSET)) == 0));
        shift_axis_tuser = (s_axis_tuser && ((s_axis_tkeep & ({KEEP_WIDTH{1'b1}} << OFFSET)) == 0));
        shift_axis_input_tready = !(s_axis_tlast && s_axis_tready && s_axis_tvalid);
    end
end

always @* begin
    read_eth_header_next = read_eth_header_reg;
    read_eth_payload_next = read_eth_payload_reg;
    ptr_next = ptr_reg;

    s_axis_tready_next = m_eth_payload_axis_tready_int_early && shift_axis_input_tready && (!m_eth_hdr_valid || m_eth_hdr_ready);

    flush_save = 1'b0;
    transfer_in_save = 1'b0;

    m_eth_hdr_valid_next = m_eth_hdr_valid_reg && !m_eth_hdr_ready;

    m_eth_dest_mac_next = m_eth_dest_mac_reg;
    m_eth_src_mac_next = m_eth_src_mac_reg;
    m_eth_type_next = m_eth_type_reg;

    error_header_early_termination_next = 1'b0;

    m_eth_payload_axis_tdata_int = shift_axis_tdata;
    m_eth_payload_axis_tkeep_int = shift_axis_tkeep;
    m_eth_payload_axis_tvalid_int = 1'b0;
    m_eth_payload_axis_tlast_int = shift_axis_tlast;
    m_eth_payload_axis_tuser_int = shift_axis_tuser;

    if ((s_axis_tready && s_axis_tvalid) || (m_eth_payload_axis_tready_int_reg && shift_axis_extra_cycle_reg)) begin
        transfer_in_save = 1'b1;

        if (read_eth_header_reg) begin
            // word transfer in - store it
            ptr_next = ptr_reg + 1;

            `define _HEADER_FIELD_(offset, field) \
                if (ptr_reg == offset/BYTE_LANES && (!KEEP_ENABLE || s_axis_tkeep[offset%BYTE_LANES])) begin \
                    field = s_axis_tdata[(offset%BYTE_LANES)*8 +: 8]; \
                end

            `_HEADER_FIELD_(0,  m_eth_dest_mac_next[5*8 +: 8])
            `_HEADER_FIELD_(1,  m_eth_dest_mac_next[4*8 +: 8])
            `_HEADER_FIELD_(2,  m_eth_dest_mac_next[3*8 +: 8])
            `_HEADER_FIELD_(3,  m_eth_dest_mac_next[2*8 +: 8])
            `_HEADER_FIELD_(4,  m_eth_dest_mac_next[1*8 +: 8])
            `_HEADER_FIELD_(5,  m_eth_dest_mac_next[0*8 +: 8])
            `_HEADER_FIELD_(6,  m_eth_src_mac_next[5*8 +: 8])
            `_HEADER_FIELD_(7,  m_eth_src_mac_next[4*8 +: 8])
            `_HEADER_FIELD_(8,  m_eth_src_mac_next[3*8 +: 8])
            `_HEADER_FIELD_(9,  m_eth_src_mac_next[2*8 +: 8])
            `_HEADER_FIELD_(10, m_eth_src_mac_next[1*8 +: 8])
            `_HEADER_FIELD_(11, m_eth_src_mac_next[0*8 +: 8])
            `_HEADER_FIELD_(12, m_eth_type_next[1*8 +: 8])
            `_HEADER_FIELD_(13, m_eth_type_next[0*8 +: 8])

            if (ptr_reg == 13/BYTE_LANES && (!KEEP_ENABLE || s_axis_tkeep[13%BYTE_LANES])) begin
                if (!shift_axis_tlast) begin
                    m_eth_hdr_valid_next = 1'b1;
                    read_eth_header_next = 1'b0;
                    read_eth_payload_next = 1'b1;
                end
            end

            `undef _HEADER_FIELD_
        end

        if (read_eth_payload_reg) begin
            // transfer payload
            m_eth_payload_axis_tdata_int = shift_axis_tdata;
            m_eth_payload_axis_tkeep_int = shift_axis_tkeep;
            m_eth_payload_axis_tvalid_int = 1'b1;
            m_eth_payload_axis_tlast_int = shift_axis_tlast;
            m_eth_payload_axis_tuser_int = shift_axis_tuser;
        end

        if (shift_axis_tlast) begin
            if (read_eth_header_next) begin
                // don't have the whole header
                error_header_early_termination_next = 1'b1;
            end

            flush_save = 1'b1;
            ptr_next = 1'b0;
            read_eth_header_next = 1'b1;
            read_eth_payload_next = 1'b0;
        end
    end
end

always @(posedge clk) begin
    read_eth_header_reg <= read_eth_header_next;
    read_eth_payload_reg <= read_eth_payload_next;
    ptr_reg <= ptr_next;

    s_axis_tready_reg <= s_axis_tready_next;

    m_eth_hdr_valid_reg <= m_eth_hdr_valid_next;
    m_eth_dest_mac_reg <= m_eth_dest_mac_next;
    m_eth_src_mac_reg <= m_eth_src_mac_next;
    m_eth_type_reg <= m_eth_type_next;

    error_header_early_termination_reg <= error_header_early_termination_next;

    busy_reg <= (read_eth_payload_next || ptr_next != 0);

    if (transfer_in_save) begin
        save_axis_tdata_reg <= s_axis_tdata;
        save_axis_tkeep_reg <= s_axis_tkeep;
        save_axis_tuser_reg <= s_axis_tuser;
    end

    if (flush_save) begin
        save_axis_tlast_reg <= 1'b0;
        shift_axis_extra_cycle_reg <= 1'b0;
    end else if (transfer_in_save) begin
        save_axis_tlast_reg <= s_axis_tlast;
        shift_axis_extra_cycle_reg <= OFFSET ? s_axis_tlast && ((s_axis_tkeep & ({KEEP_WIDTH{1'b1}} << OFFSET)) != 0) : 1'b0;
    end

    if (rst) begin
        read_eth_header_reg <= 1'b1;
        read_eth_payload_reg <= 1'b0;
        ptr_reg <= 0;
        s_axis_tready_reg <= 1'b0;
        m_eth_hdr_valid_reg <= 1'b0;
        save_axis_tlast_reg <= 1'b0;
        shift_axis_extra_cycle_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_header_early_termination_reg <= 1'b0;
    end
end

// output datapath logic
reg [DATA_WIDTH-1:0] m_eth_payload_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg                  m_eth_payload_axis_tvalid_reg = 1'b0, m_eth_payload_axis_tvalid_next;
reg                  m_eth_payload_axis_tlast_reg = 1'b0;
reg                  m_eth_payload_axis_tuser_reg = 1'b0;

reg [DATA_WIDTH-1:0] temp_m_eth_payload_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] temp_m_eth_payload_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg                  temp_m_eth_payload_axis_tvalid_reg = 1'b0, temp_m_eth_payload_axis_tvalid_next;
reg                  temp_m_eth_payload_axis_tlast_reg = 1'b0;
reg                  temp_m_eth_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_eth_payload_int_to_output;
reg store_eth_payload_int_to_temp;
reg store_eth_payload_axis_temp_to_output;

assign m_eth_payload_axis_tdata = m_eth_payload_axis_tdata_reg;
assign m_eth_payload_axis_tkeep = KEEP_ENABLE ? m_eth_payload_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
assign m_eth_payload_axis_tvalid = m_eth_payload_axis_tvalid_reg;
assign m_eth_payload_axis_tlast = m_eth_payload_axis_tlast_reg;
assign m_eth_payload_axis_tuser = m_eth_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_eth_payload_axis_tready_int_early = m_eth_payload_axis_tready || (!temp_m_eth_payload_axis_tvalid_reg && !m_eth_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_reg;
    temp_m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;

    store_eth_payload_int_to_output = 1'b0;
    store_eth_payload_int_to_temp = 1'b0;
    store_eth_payload_axis_temp_to_output = 1'b0;
    
    if (m_eth_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_eth_payload_axis_tready || !m_eth_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_eth_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_eth_payload_int_to_temp = 1'b1;
        end
    end else if (m_eth_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;
        temp_m_eth_payload_axis_tvalid_next = 1'b0;
        store_eth_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_eth_payload_axis_tvalid_reg <= m_eth_payload_axis_tvalid_next;
    m_eth_payload_axis_tready_int_reg <= m_eth_payload_axis_tready_int_early;
    temp_m_eth_payload_axis_tvalid_reg <= temp_m_eth_payload_axis_tvalid_next;

    // datapath
    if (store_eth_payload_int_to_output) begin
        m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        m_eth_payload_axis_tkeep_reg <= m_eth_payload_axis_tkeep_int;
        m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end else if (store_eth_payload_axis_temp_to_output) begin
        m_eth_payload_axis_tdata_reg <= temp_m_eth_payload_axis_tdata_reg;
        m_eth_payload_axis_tkeep_reg <= temp_m_eth_payload_axis_tkeep_reg;
        m_eth_payload_axis_tlast_reg <= temp_m_eth_payload_axis_tlast_reg;
        m_eth_payload_axis_tuser_reg <= temp_m_eth_payload_axis_tuser_reg;
    end

    if (store_eth_payload_int_to_temp) begin
        temp_m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        temp_m_eth_payload_axis_tkeep_reg <= m_eth_payload_axis_tkeep_int;
        temp_m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        temp_m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end

    if (rst) begin
        m_eth_payload_axis_tvalid_reg <= 1'b0;
        m_eth_payload_axis_tready_int_reg <= 1'b0;
        temp_m_eth_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/eth_axis_tx.v ===== */
/*

Copyright (c) 2014-2020 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream ethernet frame transmitter (Ethernet frame in, AXI out)
 */
module eth_axis_tx #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                  clk,
    input  wire                  rst,

    /*
     * Ethernet frame input
     */
    input  wire                  s_eth_hdr_valid,
    output wire                  s_eth_hdr_ready,
    input  wire [47:0]           s_eth_dest_mac,
    input  wire [47:0]           s_eth_src_mac,
    input  wire [15:0]           s_eth_type,
    input  wire [DATA_WIDTH-1:0] s_eth_payload_axis_tdata,
    input  wire [KEEP_WIDTH-1:0] s_eth_payload_axis_tkeep,
    input  wire                  s_eth_payload_axis_tvalid,
    output wire                  s_eth_payload_axis_tready,
    input  wire                  s_eth_payload_axis_tlast,
    input  wire                  s_eth_payload_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire [KEEP_WIDTH-1:0] m_axis_tkeep,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,
    output wire                  m_axis_tuser,

    /*
     * Status signals
     */
    output wire                  busy
);

parameter BYTE_LANES = KEEP_ENABLE ? KEEP_WIDTH : 1;

parameter HDR_SIZE = 14;

parameter CYCLE_COUNT = (HDR_SIZE+BYTE_LANES-1)/BYTE_LANES;

parameter PTR_WIDTH = $clog2(CYCLE_COUNT);

parameter OFFSET = HDR_SIZE % BYTE_LANES;

// bus width assertions
initial begin
    if (BYTE_LANES * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

/*

Ethernet frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype                   2 octets

This module receives an Ethernet frame with header fields in parallel along
with the payload in an AXI stream, combines the header with the payload, and
transmits the complete Ethernet frame on the output AXI stream interface.

*/

// datapath control signals
reg store_eth_hdr;

reg send_eth_header_reg = 1'b0, send_eth_header_next;
reg send_eth_payload_reg = 1'b0, send_eth_payload_next;
reg [PTR_WIDTH-1:0] ptr_reg = 0, ptr_next;

reg flush_save;
reg transfer_in_save;

reg [47:0] eth_dest_mac_reg = 48'd0;
reg [47:0] eth_src_mac_reg = 48'd0;
reg [15:0] eth_type_reg = 16'd0;

reg s_eth_hdr_ready_reg = 1'b0, s_eth_hdr_ready_next;
reg s_eth_payload_axis_tready_reg = 1'b0, s_eth_payload_axis_tready_next;

reg busy_reg = 1'b0;

reg [DATA_WIDTH-1:0] save_eth_payload_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] save_eth_payload_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg save_eth_payload_axis_tlast_reg = 1'b0;
reg save_eth_payload_axis_tuser_reg = 1'b0;

reg [DATA_WIDTH-1:0] shift_eth_payload_axis_tdata;
reg [KEEP_WIDTH-1:0] shift_eth_payload_axis_tkeep;
reg shift_eth_payload_axis_tvalid;
reg shift_eth_payload_axis_tlast;
reg shift_eth_payload_axis_tuser;
reg shift_eth_payload_axis_input_tready;
reg shift_eth_payload_axis_extra_cycle_reg = 1'b0;

// internal datapath
reg [DATA_WIDTH-1:0] m_axis_tdata_int;
reg [KEEP_WIDTH-1:0] m_axis_tkeep_int;
reg                  m_axis_tvalid_int;
reg                  m_axis_tready_int_reg = 1'b0;
reg                  m_axis_tlast_int;
reg                  m_axis_tuser_int;
wire                 m_axis_tready_int_early;

assign s_eth_hdr_ready = s_eth_hdr_ready_reg;
assign s_eth_payload_axis_tready = s_eth_payload_axis_tready_reg;

assign busy = busy_reg;

always @* begin
    if (OFFSET == 0) begin
        // passthrough if no overlap
        shift_eth_payload_axis_tdata = s_eth_payload_axis_tdata;
        shift_eth_payload_axis_tkeep = s_eth_payload_axis_tkeep;
        shift_eth_payload_axis_tvalid = s_eth_payload_axis_tvalid;
        shift_eth_payload_axis_tlast = s_eth_payload_axis_tlast;
        shift_eth_payload_axis_tuser = s_eth_payload_axis_tuser;
        shift_eth_payload_axis_input_tready = 1'b1;
    end else if (shift_eth_payload_axis_extra_cycle_reg) begin
        shift_eth_payload_axis_tdata = {s_eth_payload_axis_tdata, save_eth_payload_axis_tdata_reg} >> ((KEEP_WIDTH-OFFSET)*8);
        shift_eth_payload_axis_tkeep = {{KEEP_WIDTH{1'b0}}, save_eth_payload_axis_tkeep_reg} >> (KEEP_WIDTH-OFFSET);
        shift_eth_payload_axis_tvalid = 1'b1;
        shift_eth_payload_axis_tlast = save_eth_payload_axis_tlast_reg;
        shift_eth_payload_axis_tuser = save_eth_payload_axis_tuser_reg;
        shift_eth_payload_axis_input_tready = flush_save;
    end else begin
        shift_eth_payload_axis_tdata = {s_eth_payload_axis_tdata, save_eth_payload_axis_tdata_reg} >> ((KEEP_WIDTH-OFFSET)*8);
        shift_eth_payload_axis_tkeep = {s_eth_payload_axis_tkeep, save_eth_payload_axis_tkeep_reg} >> (KEEP_WIDTH-OFFSET);
        shift_eth_payload_axis_tvalid = s_eth_payload_axis_tvalid;
        shift_eth_payload_axis_tlast = (s_eth_payload_axis_tlast && ((s_eth_payload_axis_tkeep & ({KEEP_WIDTH{1'b1}} << (KEEP_WIDTH-OFFSET))) == 0));
        shift_eth_payload_axis_tuser = (s_eth_payload_axis_tuser && ((s_eth_payload_axis_tkeep & ({KEEP_WIDTH{1'b1}} << (KEEP_WIDTH-OFFSET))) == 0));
        shift_eth_payload_axis_input_tready = !(s_eth_payload_axis_tlast && s_eth_payload_axis_tready && s_eth_payload_axis_tvalid);
    end
end

always @* begin
    send_eth_header_next = send_eth_header_reg;
    send_eth_payload_next = send_eth_payload_reg;
    ptr_next = ptr_reg;

    s_eth_hdr_ready_next = 1'b0;
    s_eth_payload_axis_tready_next = 1'b0;

    store_eth_hdr = 1'b0;

    flush_save = 1'b0;
    transfer_in_save = 1'b0;

    m_axis_tdata_int = {DATA_WIDTH{1'b0}};
    m_axis_tkeep_int = {KEEP_WIDTH{1'b0}};
    m_axis_tvalid_int = 1'b0;
    m_axis_tlast_int = 1'b0;
    m_axis_tuser_int = 1'b0;

    if (s_eth_hdr_ready && s_eth_hdr_valid) begin
        store_eth_hdr = 1'b1;
        ptr_next = 0;
        send_eth_header_next = 1'b1;
        send_eth_payload_next = (OFFSET != 0) && (CYCLE_COUNT == 1);
        s_eth_payload_axis_tready_next = send_eth_payload_next && m_axis_tready_int_early;
    end

    if (send_eth_payload_reg) begin
        s_eth_payload_axis_tready_next = m_axis_tready_int_early && shift_eth_payload_axis_input_tready;

        m_axis_tdata_int = shift_eth_payload_axis_tdata;
        m_axis_tkeep_int = shift_eth_payload_axis_tkeep;
        m_axis_tlast_int = shift_eth_payload_axis_tlast;
        m_axis_tuser_int = shift_eth_payload_axis_tuser;

        if ((s_eth_payload_axis_tready && s_eth_payload_axis_tvalid) || (m_axis_tready_int_reg && shift_eth_payload_axis_extra_cycle_reg)) begin
            transfer_in_save = 1'b1;

            m_axis_tvalid_int = 1'b1;

            if (shift_eth_payload_axis_tlast) begin
                flush_save = 1'b1;
                s_eth_payload_axis_tready_next = 1'b0;
                ptr_next = 0;
                send_eth_payload_next = 1'b0;
            end
        end
    end

    if (m_axis_tready_int_reg && (!OFFSET || !send_eth_payload_reg || m_axis_tvalid_int)) begin
        if (send_eth_header_reg) begin
            ptr_next = ptr_reg + 1;

            if ((OFFSET != 0) && (CYCLE_COUNT == 1 || ptr_next == CYCLE_COUNT-1) && !send_eth_payload_reg) begin
                send_eth_payload_next = 1'b1;
                s_eth_payload_axis_tready_next = m_axis_tready_int_early && shift_eth_payload_axis_input_tready;
            end

            m_axis_tvalid_int = 1'b1;

            `define _HEADER_FIELD_(offset, field) \
                if (ptr_reg == offset/BYTE_LANES) begin \
                    m_axis_tdata_int[(offset%BYTE_LANES)*8 +: 8] = field; \
                    m_axis_tkeep_int[offset%BYTE_LANES] = 1'b1; \
                end

            `_HEADER_FIELD_(0,  eth_dest_mac_reg[5*8 +: 8])
            `_HEADER_FIELD_(1,  eth_dest_mac_reg[4*8 +: 8])
            `_HEADER_FIELD_(2,  eth_dest_mac_reg[3*8 +: 8])
            `_HEADER_FIELD_(3,  eth_dest_mac_reg[2*8 +: 8])
            `_HEADER_FIELD_(4,  eth_dest_mac_reg[1*8 +: 8])
            `_HEADER_FIELD_(5,  eth_dest_mac_reg[0*8 +: 8])
            `_HEADER_FIELD_(6,  eth_src_mac_reg[5*8 +: 8])
            `_HEADER_FIELD_(7,  eth_src_mac_reg[4*8 +: 8])
            `_HEADER_FIELD_(8,  eth_src_mac_reg[3*8 +: 8])
            `_HEADER_FIELD_(9,  eth_src_mac_reg[2*8 +: 8])
            `_HEADER_FIELD_(10, eth_src_mac_reg[1*8 +: 8])
            `_HEADER_FIELD_(11, eth_src_mac_reg[0*8 +: 8])
            `_HEADER_FIELD_(12, eth_type_reg[1*8 +: 8])
            `_HEADER_FIELD_(13, eth_type_reg[0*8 +: 8])

            if (ptr_reg == 13/BYTE_LANES) begin
                if (!send_eth_payload_reg) begin
                    s_eth_payload_axis_tready_next = m_axis_tready_int_early;
                    send_eth_payload_next = 1'b1;
                end
                send_eth_header_next = 1'b0;
            end

            `undef _HEADER_FIELD_
        end
    end

    s_eth_hdr_ready_next = !(send_eth_header_next || send_eth_payload_next);
end

always @(posedge clk) begin
    send_eth_header_reg <= send_eth_header_next;
    send_eth_payload_reg <= send_eth_payload_next;
    ptr_reg <= ptr_next;

    s_eth_hdr_ready_reg <= s_eth_hdr_ready_next;
    s_eth_payload_axis_tready_reg <= s_eth_payload_axis_tready_next;

    busy_reg <= send_eth_header_next || send_eth_payload_next;

    if (store_eth_hdr) begin
        eth_dest_mac_reg <= s_eth_dest_mac;
        eth_src_mac_reg <= s_eth_src_mac;
        eth_type_reg <= s_eth_type;
    end

    if (transfer_in_save) begin
        save_eth_payload_axis_tdata_reg <= s_eth_payload_axis_tdata;
        save_eth_payload_axis_tkeep_reg <= s_eth_payload_axis_tkeep;
        save_eth_payload_axis_tuser_reg <= s_eth_payload_axis_tuser;
    end

    if (flush_save) begin
        save_eth_payload_axis_tlast_reg <= 1'b0;
        shift_eth_payload_axis_extra_cycle_reg <= 1'b0;
    end else if (transfer_in_save) begin
        save_eth_payload_axis_tlast_reg <= s_eth_payload_axis_tlast;
        shift_eth_payload_axis_extra_cycle_reg <= OFFSET ? s_eth_payload_axis_tlast && ((s_eth_payload_axis_tkeep & ({KEEP_WIDTH{1'b1}} << (KEEP_WIDTH-OFFSET))) != 0) : 1'b0;
    end

    if (rst) begin
        send_eth_header_reg <= 1'b0;
        send_eth_payload_reg <= 1'b0;
        ptr_reg <= 0;
        s_eth_hdr_ready_reg <= 1'b0;
        s_eth_payload_axis_tready_reg <= 1'b0;
        busy_reg <= 1'b0;
    end
end

// output datapath logic
reg [DATA_WIDTH-1:0] m_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] m_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg                  m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg                  m_axis_tlast_reg = 1'b0;
reg                  m_axis_tuser_reg = 1'b0;

reg [DATA_WIDTH-1:0] temp_m_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] temp_m_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg                  temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
reg                  temp_m_axis_tlast_reg = 1'b0;
reg                  temp_m_axis_tuser_reg = 1'b0;

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_axis_temp_to_output;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tkeep = KEEP_ENABLE ? m_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;
assign m_axis_tuser = m_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_axis_tready_int_early = m_axis_tready || (!temp_m_axis_tvalid_reg && !m_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_axis_tvalid_next = m_axis_tvalid_reg;
    temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;
    
    if (m_axis_tready_int_reg) begin
        // input is ready
        if (m_axis_tready || !m_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_tvalid_next = m_axis_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_tvalid_next = m_axis_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_axis_tready) begin
        // input is not ready, but output is ready
        m_axis_tvalid_next = temp_m_axis_tvalid_reg;
        temp_m_axis_tvalid_next = 1'b0;
        store_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tready_int_reg <= m_axis_tready_int_early;
    temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_tdata_reg <= m_axis_tdata_int;
        m_axis_tkeep_reg <= m_axis_tkeep_int;
        m_axis_tlast_reg <= m_axis_tlast_int;
        m_axis_tuser_reg <= m_axis_tuser_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_tdata_reg <= temp_m_axis_tdata_reg;
        m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
        m_axis_tlast_reg <= temp_m_axis_tlast_reg;
        m_axis_tuser_reg <= temp_m_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_tdata_reg <= m_axis_tdata_int;
        temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
        temp_m_axis_tlast_reg <= m_axis_tlast_int;
        temp_m_axis_tuser_reg <= m_axis_tuser_int;
    end

    if (rst) begin
        m_axis_tvalid_reg <= 1'b0;
        m_axis_tready_int_reg <= 1'b0;
        temp_m_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/udp_complete.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IPv4 and ARP block with UDP support, ethernet frame interface
 */
module udp_complete #(
    parameter ARP_CACHE_ADDR_WIDTH = 9,
    parameter ARP_REQUEST_RETRY_COUNT = 4,
    parameter ARP_REQUEST_RETRY_INTERVAL = 125000000*2,
    parameter ARP_REQUEST_TIMEOUT = 125000000*30,
    parameter UDP_CHECKSUM_GEN_ENABLE = 1,
    parameter UDP_CHECKSUM_PAYLOAD_FIFO_DEPTH = 2048,
    parameter UDP_CHECKSUM_HEADER_FIFO_DEPTH = 8
)
(
    input  wire        clk,
    input  wire        rst,
    
    /*
     * Ethernet frame input
     */
    input  wire        s_eth_hdr_valid,
    output wire        s_eth_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [7:0]  s_eth_payload_axis_tdata,
    input  wire        s_eth_payload_axis_tvalid,
    output wire        s_eth_payload_axis_tready,
    input  wire        s_eth_payload_axis_tlast,
    input  wire        s_eth_payload_axis_tuser,
    
    /*
     * Ethernet frame output
     */
    output wire        m_eth_hdr_valid,
    input  wire        m_eth_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [7:0]  m_eth_payload_axis_tdata,
    output wire        m_eth_payload_axis_tvalid,
    input  wire        m_eth_payload_axis_tready,
    output wire        m_eth_payload_axis_tlast,
    output wire        m_eth_payload_axis_tuser,
    
    /*
     * IP input
     */
    input  wire        s_ip_hdr_valid,
    output wire        s_ip_hdr_ready,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [7:0]  s_ip_payload_axis_tdata,
    input  wire        s_ip_payload_axis_tvalid,
    output wire        s_ip_payload_axis_tready,
    input  wire        s_ip_payload_axis_tlast,
    input  wire        s_ip_payload_axis_tuser,
    
    /*
     * IP output
     */
    output wire        m_ip_hdr_valid,
    input  wire        m_ip_hdr_ready,
    output wire [47:0] m_ip_eth_dest_mac,
    output wire [47:0] m_ip_eth_src_mac,
    output wire [15:0] m_ip_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [7:0]  m_ip_payload_axis_tdata,
    output wire        m_ip_payload_axis_tvalid,
    input  wire        m_ip_payload_axis_tready,
    output wire        m_ip_payload_axis_tlast,
    output wire        m_ip_payload_axis_tuser,
    
    /*
     * UDP input
     */
    input  wire        s_udp_hdr_valid,
    output wire        s_udp_hdr_ready,
    input  wire [5:0]  s_udp_ip_dscp,
    input  wire [1:0]  s_udp_ip_ecn,
    input  wire [7:0]  s_udp_ip_ttl,
    input  wire [31:0] s_udp_ip_source_ip,
    input  wire [31:0] s_udp_ip_dest_ip,
    input  wire [15:0] s_udp_source_port,
    input  wire [15:0] s_udp_dest_port,
    input  wire [15:0] s_udp_length,
    input  wire [15:0] s_udp_checksum,
    input  wire [7:0]  s_udp_payload_axis_tdata,
    input  wire        s_udp_payload_axis_tvalid,
    output wire        s_udp_payload_axis_tready,
    input  wire        s_udp_payload_axis_tlast,
    input  wire        s_udp_payload_axis_tuser,
    
    /*
     * UDP output
     */
    output wire        m_udp_hdr_valid,
    input  wire        m_udp_hdr_ready,
    output wire [47:0] m_udp_eth_dest_mac,
    output wire [47:0] m_udp_eth_src_mac,
    output wire [15:0] m_udp_eth_type,
    output wire [3:0]  m_udp_ip_version,
    output wire [3:0]  m_udp_ip_ihl,
    output wire [5:0]  m_udp_ip_dscp,
    output wire [1:0]  m_udp_ip_ecn,
    output wire [15:0] m_udp_ip_length,
    output wire [15:0] m_udp_ip_identification,
    output wire [2:0]  m_udp_ip_flags,
    output wire [12:0] m_udp_ip_fragment_offset,
    output wire [7:0]  m_udp_ip_ttl,
    output wire [7:0]  m_udp_ip_protocol,
    output wire [15:0] m_udp_ip_header_checksum,
    output wire [31:0] m_udp_ip_source_ip,
    output wire [31:0] m_udp_ip_dest_ip,
    output wire [15:0] m_udp_source_port,
    output wire [15:0] m_udp_dest_port,
    output wire [15:0] m_udp_length,
    output wire [15:0] m_udp_checksum,
    output wire [7:0]  m_udp_payload_axis_tdata,
    output wire        m_udp_payload_axis_tvalid,
    input  wire        m_udp_payload_axis_tready,
    output wire        m_udp_payload_axis_tlast,
    output wire        m_udp_payload_axis_tuser,

    /*
     * Status
     */
    output wire        ip_rx_busy,
    output wire        ip_tx_busy,
    output wire        udp_rx_busy,
    output wire        udp_tx_busy,
    output wire        ip_rx_error_header_early_termination,
    output wire        ip_rx_error_payload_early_termination,
    output wire        ip_rx_error_invalid_header,
    output wire        ip_rx_error_invalid_checksum,
    output wire        ip_tx_error_payload_early_termination,
    output wire        ip_tx_error_arp_failed,
    output wire        udp_rx_error_header_early_termination,
    output wire        udp_rx_error_payload_early_termination,
    output wire        udp_tx_error_payload_early_termination,

    /*
     * Configuration
     */
    input  wire [47:0] local_mac,
    input  wire [31:0] local_ip,
    input  wire [31:0] gateway_ip,
    input  wire [31:0] subnet_mask,
    input  wire        clear_arp_cache
);

wire ip_rx_ip_hdr_valid;
wire ip_rx_ip_hdr_ready;
wire [47:0] ip_rx_ip_eth_dest_mac;
wire [47:0] ip_rx_ip_eth_src_mac;
wire [15:0] ip_rx_ip_eth_type;
wire [3:0] ip_rx_ip_version;
wire [3:0] ip_rx_ip_ihl;
wire [5:0] ip_rx_ip_dscp;
wire [1:0] ip_rx_ip_ecn;
wire [15:0] ip_rx_ip_length;
wire [15:0] ip_rx_ip_identification;
wire [2:0] ip_rx_ip_flags;
wire [12:0] ip_rx_ip_fragment_offset;
wire [7:0] ip_rx_ip_ttl;
wire [7:0] ip_rx_ip_protocol;
wire [15:0] ip_rx_ip_header_checksum;
wire [31:0] ip_rx_ip_source_ip;
wire [31:0] ip_rx_ip_dest_ip;
wire [7:0] ip_rx_ip_payload_axis_tdata;
wire ip_rx_ip_payload_axis_tvalid;
wire ip_rx_ip_payload_axis_tlast;
wire ip_rx_ip_payload_axis_tuser;
wire ip_rx_ip_payload_axis_tready;

wire ip_tx_ip_hdr_valid;
wire ip_tx_ip_hdr_ready;
wire [5:0] ip_tx_ip_dscp;
wire [1:0] ip_tx_ip_ecn;
wire [15:0] ip_tx_ip_length;
wire [7:0] ip_tx_ip_ttl;
wire [7:0] ip_tx_ip_protocol;
wire [31:0] ip_tx_ip_source_ip;
wire [31:0] ip_tx_ip_dest_ip;
wire [7:0] ip_tx_ip_payload_axis_tdata;
wire ip_tx_ip_payload_axis_tvalid;
wire ip_tx_ip_payload_axis_tlast;
wire ip_tx_ip_payload_axis_tuser;
wire ip_tx_ip_payload_axis_tready;

wire udp_rx_ip_hdr_valid;
wire udp_rx_ip_hdr_ready;
wire [47:0] udp_rx_ip_eth_dest_mac;
wire [47:0] udp_rx_ip_eth_src_mac;
wire [15:0] udp_rx_ip_eth_type;
wire [3:0] udp_rx_ip_version;
wire [3:0] udp_rx_ip_ihl;
wire [5:0] udp_rx_ip_dscp;
wire [1:0] udp_rx_ip_ecn;
wire [15:0] udp_rx_ip_length;
wire [15:0] udp_rx_ip_identification;
wire [2:0] udp_rx_ip_flags;
wire [12:0] udp_rx_ip_fragment_offset;
wire [7:0] udp_rx_ip_ttl;
wire [7:0] udp_rx_ip_protocol;
wire [15:0] udp_rx_ip_header_checksum;
wire [31:0] udp_rx_ip_source_ip;
wire [31:0] udp_rx_ip_dest_ip;
wire [7:0] udp_rx_ip_payload_axis_tdata;
wire udp_rx_ip_payload_axis_tvalid;
wire udp_rx_ip_payload_axis_tlast;
wire udp_rx_ip_payload_axis_tuser;
wire udp_rx_ip_payload_axis_tready;

wire udp_tx_ip_hdr_valid;
wire udp_tx_ip_hdr_ready;
wire [5:0] udp_tx_ip_dscp;
wire [1:0] udp_tx_ip_ecn;
wire [15:0] udp_tx_ip_length;
wire [7:0] udp_tx_ip_ttl;
wire [7:0] udp_tx_ip_protocol;
wire [31:0] udp_tx_ip_source_ip;
wire [31:0] udp_tx_ip_dest_ip;
wire [7:0] udp_tx_ip_payload_axis_tdata;
wire udp_tx_ip_payload_axis_tvalid;
wire udp_tx_ip_payload_axis_tlast;
wire udp_tx_ip_payload_axis_tuser;
wire udp_tx_ip_payload_axis_tready;

/*
 * Input classifier (ip_protocol)
 */
wire s_select_udp = (ip_rx_ip_protocol == 8'h11);
wire s_select_ip = !s_select_udp;

reg s_select_udp_reg = 1'b0;
reg s_select_ip_reg = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        s_select_udp_reg <= 1'b0;
        s_select_ip_reg <= 1'b0;
    end else begin
        if (ip_rx_ip_payload_axis_tvalid) begin
            if ((!s_select_udp_reg && !s_select_ip_reg) ||
                (ip_rx_ip_payload_axis_tvalid && ip_rx_ip_payload_axis_tready && ip_rx_ip_payload_axis_tlast)) begin
                s_select_udp_reg <= s_select_udp;
                s_select_ip_reg <= s_select_ip;
            end
        end else begin
            s_select_udp_reg <= 1'b0;
            s_select_ip_reg <= 1'b0;
        end
    end
end

// IP frame to UDP module
assign udp_rx_ip_hdr_valid = s_select_udp && ip_rx_ip_hdr_valid;
assign udp_rx_ip_eth_dest_mac = ip_rx_ip_eth_dest_mac;
assign udp_rx_ip_eth_src_mac = ip_rx_ip_eth_src_mac;
assign udp_rx_ip_eth_type = ip_rx_ip_eth_type;
assign udp_rx_ip_version = ip_rx_ip_version;
assign udp_rx_ip_ihl = ip_rx_ip_ihl;
assign udp_rx_ip_dscp = ip_rx_ip_dscp;
assign udp_rx_ip_ecn = ip_rx_ip_ecn;
assign udp_rx_ip_length = ip_rx_ip_length;
assign udp_rx_ip_identification = ip_rx_ip_identification;
assign udp_rx_ip_flags = ip_rx_ip_flags;
assign udp_rx_ip_fragment_offset = ip_rx_ip_fragment_offset;
assign udp_rx_ip_ttl = ip_rx_ip_ttl;
assign udp_rx_ip_protocol = 8'h11;
assign udp_rx_ip_header_checksum = ip_rx_ip_header_checksum;
assign udp_rx_ip_source_ip = ip_rx_ip_source_ip;
assign udp_rx_ip_dest_ip = ip_rx_ip_dest_ip;
assign udp_rx_ip_payload_axis_tdata = ip_rx_ip_payload_axis_tdata;
assign udp_rx_ip_payload_axis_tvalid = s_select_udp_reg && ip_rx_ip_payload_axis_tvalid;
assign udp_rx_ip_payload_axis_tlast = ip_rx_ip_payload_axis_tlast;
assign udp_rx_ip_payload_axis_tuser = ip_rx_ip_payload_axis_tuser;

// External IP frame output
assign m_ip_hdr_valid = s_select_ip && ip_rx_ip_hdr_valid;
assign m_ip_eth_dest_mac = ip_rx_ip_eth_dest_mac;
assign m_ip_eth_src_mac = ip_rx_ip_eth_src_mac;
assign m_ip_eth_type = ip_rx_ip_eth_type;
assign m_ip_version = ip_rx_ip_version;
assign m_ip_ihl = ip_rx_ip_ihl;
assign m_ip_dscp = ip_rx_ip_dscp;
assign m_ip_ecn = ip_rx_ip_ecn;
assign m_ip_length = ip_rx_ip_length;
assign m_ip_identification = ip_rx_ip_identification;
assign m_ip_flags = ip_rx_ip_flags;
assign m_ip_fragment_offset = ip_rx_ip_fragment_offset;
assign m_ip_ttl = ip_rx_ip_ttl;
assign m_ip_protocol = ip_rx_ip_protocol;
assign m_ip_header_checksum = ip_rx_ip_header_checksum;
assign m_ip_source_ip = ip_rx_ip_source_ip;
assign m_ip_dest_ip = ip_rx_ip_dest_ip;
assign m_ip_payload_axis_tdata = ip_rx_ip_payload_axis_tdata;
assign m_ip_payload_axis_tvalid = s_select_ip_reg && ip_rx_ip_payload_axis_tvalid;
assign m_ip_payload_axis_tlast = ip_rx_ip_payload_axis_tlast;
assign m_ip_payload_axis_tuser = ip_rx_ip_payload_axis_tuser;

assign ip_rx_ip_hdr_ready = (s_select_udp && udp_rx_ip_hdr_ready) ||
                            (s_select_ip && m_ip_hdr_ready);

assign ip_rx_ip_payload_axis_tready = (s_select_udp_reg && udp_rx_ip_payload_axis_tready) ||
                                      (s_select_ip_reg && m_ip_payload_axis_tready);

/*
 * Output arbiter
 */
ip_arb_mux #(
    .S_COUNT(2),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1)
)
ip_arb_mux_inst (
    .clk(clk),
    .rst(rst),
    // IP frame inputs
    .s_ip_hdr_valid({s_ip_hdr_valid, udp_tx_ip_hdr_valid}),
    .s_ip_hdr_ready({s_ip_hdr_ready, udp_tx_ip_hdr_ready}),
    .s_eth_dest_mac(0),
    .s_eth_src_mac(0),
    .s_eth_type(0),
    .s_ip_version(0),
    .s_ip_ihl(0),
    .s_ip_dscp({s_ip_dscp, udp_tx_ip_dscp}),
    .s_ip_ecn({s_ip_ecn, udp_tx_ip_ecn}),
    .s_ip_length({s_ip_length, udp_tx_ip_length}),
    .s_ip_identification(0),
    .s_ip_flags(0),
    .s_ip_fragment_offset(0),
    .s_ip_ttl({s_ip_ttl, udp_tx_ip_ttl}),
    .s_ip_protocol({s_ip_protocol, udp_tx_ip_protocol}),
    .s_ip_header_checksum(0),
    .s_ip_source_ip({s_ip_source_ip, udp_tx_ip_source_ip}),
    .s_ip_dest_ip({s_ip_dest_ip, udp_tx_ip_dest_ip}),
    .s_ip_payload_axis_tdata({s_ip_payload_axis_tdata, udp_tx_ip_payload_axis_tdata}),
    .s_ip_payload_axis_tkeep(0),
    .s_ip_payload_axis_tvalid({s_ip_payload_axis_tvalid, udp_tx_ip_payload_axis_tvalid}),
    .s_ip_payload_axis_tready({s_ip_payload_axis_tready, udp_tx_ip_payload_axis_tready}),
    .s_ip_payload_axis_tlast({s_ip_payload_axis_tlast, udp_tx_ip_payload_axis_tlast}),
    .s_ip_payload_axis_tid(0),
    .s_ip_payload_axis_tdest(0),
    .s_ip_payload_axis_tuser({s_ip_payload_axis_tuser, udp_tx_ip_payload_axis_tuser}),
    // IP frame output
    .m_ip_hdr_valid(ip_tx_ip_hdr_valid),
    .m_ip_hdr_ready(ip_tx_ip_hdr_ready),
    .m_eth_dest_mac(),
    .m_eth_src_mac(),
    .m_eth_type(),
    .m_ip_version(),
    .m_ip_ihl(),
    .m_ip_dscp(ip_tx_ip_dscp),
    .m_ip_ecn(ip_tx_ip_ecn),
    .m_ip_length(ip_tx_ip_length),
    .m_ip_identification(),
    .m_ip_flags(),
    .m_ip_fragment_offset(),
    .m_ip_ttl(ip_tx_ip_ttl),
    .m_ip_protocol(ip_tx_ip_protocol),
    .m_ip_header_checksum(),
    .m_ip_source_ip(ip_tx_ip_source_ip),
    .m_ip_dest_ip(ip_tx_ip_dest_ip),
    .m_ip_payload_axis_tdata(ip_tx_ip_payload_axis_tdata),
    .m_ip_payload_axis_tkeep(),
    .m_ip_payload_axis_tvalid(ip_tx_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(ip_tx_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(ip_tx_ip_payload_axis_tlast),
    .m_ip_payload_axis_tid(),
    .m_ip_payload_axis_tdest(),
    .m_ip_payload_axis_tuser(ip_tx_ip_payload_axis_tuser)
);

/*
 * IP stack
 */
ip_complete #(
    .ARP_CACHE_ADDR_WIDTH(ARP_CACHE_ADDR_WIDTH),
    .ARP_REQUEST_RETRY_COUNT(ARP_REQUEST_RETRY_COUNT),
    .ARP_REQUEST_RETRY_INTERVAL(ARP_REQUEST_RETRY_INTERVAL),
    .ARP_REQUEST_TIMEOUT(ARP_REQUEST_TIMEOUT)
)
ip_complete_inst (
    .clk(clk),
    .rst(rst),
    // Ethernet frame input
    .s_eth_hdr_valid(s_eth_hdr_valid),
    .s_eth_hdr_ready(s_eth_hdr_ready),
    .s_eth_dest_mac(s_eth_dest_mac),
    .s_eth_src_mac(s_eth_src_mac),
    .s_eth_type(s_eth_type),
    .s_eth_payload_axis_tdata(s_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(s_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(s_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(s_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(s_eth_payload_axis_tuser),
    // Ethernet frame output
    .m_eth_hdr_valid(m_eth_hdr_valid),
    .m_eth_hdr_ready(m_eth_hdr_ready),
    .m_eth_dest_mac(m_eth_dest_mac),
    .m_eth_src_mac(m_eth_src_mac),
    .m_eth_type(m_eth_type),
    .m_eth_payload_axis_tdata(m_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(m_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(m_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(m_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(m_eth_payload_axis_tuser),
    // IP frame input
    .s_ip_hdr_valid(ip_tx_ip_hdr_valid),
    .s_ip_hdr_ready(ip_tx_ip_hdr_ready),
    .s_ip_dscp(ip_tx_ip_dscp),
    .s_ip_ecn(ip_tx_ip_ecn),
    .s_ip_length(ip_tx_ip_length),
    .s_ip_ttl(ip_tx_ip_ttl),
    .s_ip_protocol(ip_tx_ip_protocol),
    .s_ip_source_ip(ip_tx_ip_source_ip),
    .s_ip_dest_ip(ip_tx_ip_dest_ip),
    .s_ip_payload_axis_tdata(ip_tx_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(ip_tx_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(ip_tx_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(ip_tx_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(ip_tx_ip_payload_axis_tuser),
    // IP frame output
    .m_ip_hdr_valid(ip_rx_ip_hdr_valid),
    .m_ip_hdr_ready(ip_rx_ip_hdr_ready),
    .m_ip_eth_dest_mac(ip_rx_ip_eth_dest_mac),
    .m_ip_eth_src_mac(ip_rx_ip_eth_src_mac),
    .m_ip_eth_type(ip_rx_ip_eth_type),
    .m_ip_version(ip_rx_ip_version),
    .m_ip_ihl(ip_rx_ip_ihl),
    .m_ip_dscp(ip_rx_ip_dscp),
    .m_ip_ecn(ip_rx_ip_ecn),
    .m_ip_length(ip_rx_ip_length),
    .m_ip_identification(ip_rx_ip_identification),
    .m_ip_flags(ip_rx_ip_flags),
    .m_ip_fragment_offset(ip_rx_ip_fragment_offset),
    .m_ip_ttl(ip_rx_ip_ttl),
    .m_ip_protocol(ip_rx_ip_protocol),
    .m_ip_header_checksum(ip_rx_ip_header_checksum),
    .m_ip_source_ip(ip_rx_ip_source_ip),
    .m_ip_dest_ip(ip_rx_ip_dest_ip),
    .m_ip_payload_axis_tdata(ip_rx_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(ip_rx_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(ip_rx_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(ip_rx_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(ip_rx_ip_payload_axis_tuser),
    // Status
    .rx_busy(ip_rx_busy),
    .tx_busy(ip_tx_busy),
    .rx_error_header_early_termination(ip_rx_error_header_early_termination),
    .rx_error_payload_early_termination(ip_rx_error_payload_early_termination),
    .rx_error_invalid_header(ip_rx_error_invalid_header),
    .rx_error_invalid_checksum(ip_rx_error_invalid_checksum),
    .tx_error_payload_early_termination(ip_tx_error_payload_early_termination),
    .tx_error_arp_failed(ip_tx_error_arp_failed),
    // Configuration
    .local_mac(local_mac),
    .local_ip(local_ip),
    .gateway_ip(gateway_ip),
    .subnet_mask(subnet_mask),
    .clear_arp_cache(clear_arp_cache)
);

/*
 * UDP interface
 */
udp #(
    .CHECKSUM_GEN_ENABLE(UDP_CHECKSUM_GEN_ENABLE),
    .CHECKSUM_PAYLOAD_FIFO_DEPTH(UDP_CHECKSUM_PAYLOAD_FIFO_DEPTH),
    .CHECKSUM_HEADER_FIFO_DEPTH(UDP_CHECKSUM_HEADER_FIFO_DEPTH)
)
udp_inst (
    .clk(clk),
    .rst(rst),
    // IP frame input
    .s_ip_hdr_valid(udp_rx_ip_hdr_valid),
    .s_ip_hdr_ready(udp_rx_ip_hdr_ready),
    .s_ip_eth_dest_mac(udp_rx_ip_eth_dest_mac),
    .s_ip_eth_src_mac(udp_rx_ip_eth_src_mac),
    .s_ip_eth_type(udp_rx_ip_eth_type),
    .s_ip_version(udp_rx_ip_version),
    .s_ip_ihl(udp_rx_ip_ihl),
    .s_ip_dscp(udp_rx_ip_dscp),
    .s_ip_ecn(udp_rx_ip_ecn),
    .s_ip_length(udp_rx_ip_length),
    .s_ip_identification(udp_rx_ip_identification),
    .s_ip_flags(udp_rx_ip_flags),
    .s_ip_fragment_offset(udp_rx_ip_fragment_offset),
    .s_ip_ttl(udp_rx_ip_ttl),
    .s_ip_protocol(udp_rx_ip_protocol),
    .s_ip_header_checksum(udp_rx_ip_header_checksum),
    .s_ip_source_ip(udp_rx_ip_source_ip),
    .s_ip_dest_ip(udp_rx_ip_dest_ip),
    .s_ip_payload_axis_tdata(udp_rx_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(udp_rx_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(udp_rx_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(udp_rx_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(udp_rx_ip_payload_axis_tuser),
    // IP frame output
    .m_ip_hdr_valid(udp_tx_ip_hdr_valid),
    .m_ip_hdr_ready(udp_tx_ip_hdr_ready),
    .m_ip_eth_dest_mac(),
    .m_ip_eth_src_mac(),
    .m_ip_eth_type(),
    .m_ip_version(),
    .m_ip_ihl(),
    .m_ip_dscp(udp_tx_ip_dscp),
    .m_ip_ecn(udp_tx_ip_ecn),
    .m_ip_length(udp_tx_ip_length),
    .m_ip_identification(),
    .m_ip_flags(),
    .m_ip_fragment_offset(),
    .m_ip_ttl(udp_tx_ip_ttl),
    .m_ip_protocol(udp_tx_ip_protocol),
    .m_ip_header_checksum(),
    .m_ip_source_ip(udp_tx_ip_source_ip),
    .m_ip_dest_ip(udp_tx_ip_dest_ip),
    .m_ip_payload_axis_tdata(udp_tx_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(udp_tx_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(udp_tx_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(udp_tx_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(udp_tx_ip_payload_axis_tuser),
    // UDP frame input
    .s_udp_hdr_valid(s_udp_hdr_valid),
    .s_udp_hdr_ready(s_udp_hdr_ready),
    .s_udp_eth_dest_mac(48'd0),
    .s_udp_eth_src_mac(48'd0),
    .s_udp_eth_type(16'd0),
    .s_udp_ip_version(4'd0),
    .s_udp_ip_ihl(4'd0),
    .s_udp_ip_dscp(s_udp_ip_dscp),
    .s_udp_ip_ecn(s_udp_ip_ecn),
    .s_udp_ip_identification(16'd0),
    .s_udp_ip_flags(3'd0),
    .s_udp_ip_fragment_offset(13'd0),
    .s_udp_ip_ttl(s_udp_ip_ttl),
    .s_udp_ip_header_checksum(16'd0),
    .s_udp_ip_source_ip(s_udp_ip_source_ip),
    .s_udp_ip_dest_ip(s_udp_ip_dest_ip),
    .s_udp_source_port(s_udp_source_port),
    .s_udp_dest_port(s_udp_dest_port),
    .s_udp_length(s_udp_length),
    .s_udp_checksum(s_udp_checksum),
    .s_udp_payload_axis_tdata(s_udp_payload_axis_tdata),
    .s_udp_payload_axis_tvalid(s_udp_payload_axis_tvalid),
    .s_udp_payload_axis_tready(s_udp_payload_axis_tready),
    .s_udp_payload_axis_tlast(s_udp_payload_axis_tlast),
    .s_udp_payload_axis_tuser(s_udp_payload_axis_tuser),
    // UDP frame output
    .m_udp_hdr_valid(m_udp_hdr_valid),
    .m_udp_hdr_ready(m_udp_hdr_ready),
    .m_udp_eth_dest_mac(m_udp_eth_dest_mac),
    .m_udp_eth_src_mac(m_udp_eth_src_mac),
    .m_udp_eth_type(m_udp_eth_type),
    .m_udp_ip_version(m_udp_ip_version),
    .m_udp_ip_ihl(m_udp_ip_ihl),
    .m_udp_ip_dscp(m_udp_ip_dscp),
    .m_udp_ip_ecn(m_udp_ip_ecn),
    .m_udp_ip_length(m_udp_ip_length),
    .m_udp_ip_identification(m_udp_ip_identification),
    .m_udp_ip_flags(m_udp_ip_flags),
    .m_udp_ip_fragment_offset(m_udp_ip_fragment_offset),
    .m_udp_ip_ttl(m_udp_ip_ttl),
    .m_udp_ip_protocol(m_udp_ip_protocol),
    .m_udp_ip_header_checksum(m_udp_ip_header_checksum),
    .m_udp_ip_source_ip(m_udp_ip_source_ip),
    .m_udp_ip_dest_ip(m_udp_ip_dest_ip),
    .m_udp_source_port(m_udp_source_port),
    .m_udp_dest_port(m_udp_dest_port),
    .m_udp_length(m_udp_length),
    .m_udp_checksum(m_udp_checksum),
    .m_udp_payload_axis_tdata(m_udp_payload_axis_tdata),
    .m_udp_payload_axis_tvalid(m_udp_payload_axis_tvalid),
    .m_udp_payload_axis_tready(m_udp_payload_axis_tready),
    .m_udp_payload_axis_tlast(m_udp_payload_axis_tlast),
    .m_udp_payload_axis_tuser(m_udp_payload_axis_tuser),
    // Status
    .rx_busy(udp_rx_busy),
    .tx_busy(udp_tx_busy),
    .rx_error_header_early_termination(udp_rx_error_header_early_termination),
    .rx_error_payload_early_termination(udp_rx_error_payload_early_termination),
    .tx_error_payload_early_termination(udp_tx_error_payload_early_termination)
);

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/udp_checksum_gen.v ===== */
/*

Copyright (c) 2016-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * UDP checksum calculation module
 */
module udp_checksum_gen #
(
    parameter PAYLOAD_FIFO_DEPTH = 2048,
    parameter HEADER_FIFO_DEPTH = 8
)
(
    input  wire        clk,
    input  wire        rst,
    
    /*
     * UDP frame input
     */
    input  wire        s_udp_hdr_valid,
    output wire        s_udp_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [3:0]  s_ip_version,
    input  wire [3:0]  s_ip_ihl,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_identification,
    input  wire [2:0]  s_ip_flags,
    input  wire [12:0] s_ip_fragment_offset,
    input  wire [7:0]  s_ip_ttl,
    input  wire [15:0] s_ip_header_checksum,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [15:0] s_udp_source_port,
    input  wire [15:0] s_udp_dest_port,
    input  wire [7:0]  s_udp_payload_axis_tdata,
    input  wire        s_udp_payload_axis_tvalid,
    output wire        s_udp_payload_axis_tready,
    input  wire        s_udp_payload_axis_tlast,
    input  wire        s_udp_payload_axis_tuser,
    
    /*
     * UDP frame output
     */
    output wire        m_udp_hdr_valid,
    input  wire        m_udp_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [15:0] m_udp_source_port,
    output wire [15:0] m_udp_dest_port,
    output wire [15:0] m_udp_length,
    output wire [15:0] m_udp_checksum,
    output wire [7:0]  m_udp_payload_axis_tdata,
    output wire        m_udp_payload_axis_tvalid,
    input  wire        m_udp_payload_axis_tready,
    output wire        m_udp_payload_axis_tlast,
    output wire        m_udp_payload_axis_tuser,
    
    /*
     * Status signals
     */
    output wire        busy
);

/*

UDP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets

 source port                 2 octets
 desination port             2 octets
 length                      2 octets
 checksum                    2 octets

 payload                     length octets

This module receives a UDP frame with header fields in parallel and payload on
an AXI stream interface, calculates the length and checksum, then produces the
header fields in parallel along with the UDP payload in a separate AXI stream.

*/

parameter HEADER_FIFO_ADDR_WIDTH = $clog2(HEADER_FIFO_DEPTH);

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_SUM_HEADER_1 = 3'd1,
    STATE_SUM_HEADER_2 = 3'd2,
    STATE_SUM_HEADER_3 = 3'd3,
    STATE_SUM_PAYLOAD = 3'd4,
    STATE_FINISH_SUM = 3'd5;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_udp_hdr;
reg shift_payload_in;
reg [31:0] checksum_part;

reg [15:0] frame_ptr_reg = 16'd0, frame_ptr_next;

reg [31:0] checksum_reg = 32'd0, checksum_next;

reg [47:0] eth_dest_mac_reg = 48'd0;
reg [47:0] eth_src_mac_reg = 48'd0;
reg [15:0] eth_type_reg = 16'd0;
reg [3:0]  ip_version_reg = 4'd0;
reg [3:0]  ip_ihl_reg = 4'd0;
reg [5:0]  ip_dscp_reg = 6'd0;
reg [1:0]  ip_ecn_reg = 2'd0;
reg [15:0] ip_identification_reg = 16'd0;
reg [2:0]  ip_flags_reg = 3'd0;
reg [12:0] ip_fragment_offset_reg = 13'd0;
reg [7:0]  ip_ttl_reg = 8'd0;
reg [15:0] ip_header_checksum_reg = 16'd0;
reg [31:0] ip_source_ip_reg = 32'd0;
reg [31:0] ip_dest_ip_reg = 32'd0;
reg [15:0] udp_source_port_reg = 16'd0;
reg [15:0] udp_dest_port_reg = 16'd0;

reg hdr_valid_reg = 0, hdr_valid_next;

reg s_udp_hdr_ready_reg = 1'b0, s_udp_hdr_ready_next;
reg s_udp_payload_axis_tready_reg = 1'b0, s_udp_payload_axis_tready_next;

reg busy_reg = 1'b0;

/*
 * UDP Payload FIFO
 */
wire [7:0] s_udp_payload_fifo_tdata;
wire s_udp_payload_fifo_tvalid;
wire s_udp_payload_fifo_tready;
wire s_udp_payload_fifo_tlast;
wire s_udp_payload_fifo_tuser;

wire [7:0] m_udp_payload_fifo_tdata;
wire m_udp_payload_fifo_tvalid;
wire m_udp_payload_fifo_tready;
wire m_udp_payload_fifo_tlast;
wire m_udp_payload_fifo_tuser;

axis_fifo #(
    .DEPTH(PAYLOAD_FIFO_DEPTH),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .FRAME_FIFO(0)
)
payload_fifo (
    .clk(clk),
    .rst(rst),
    // AXI input
    .s_axis_tdata(s_udp_payload_fifo_tdata),
    .s_axis_tkeep(0),
    .s_axis_tvalid(s_udp_payload_fifo_tvalid),
    .s_axis_tready(s_udp_payload_fifo_tready),
    .s_axis_tlast(s_udp_payload_fifo_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(s_udp_payload_fifo_tuser),
    // AXI output
    .m_axis_tdata(m_udp_payload_fifo_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(m_udp_payload_fifo_tvalid),
    .m_axis_tready(m_udp_payload_fifo_tready),
    .m_axis_tlast(m_udp_payload_fifo_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(m_udp_payload_fifo_tuser),
    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);

assign s_udp_payload_fifo_tdata = s_udp_payload_axis_tdata;
assign s_udp_payload_fifo_tvalid = s_udp_payload_axis_tvalid && shift_payload_in;
assign s_udp_payload_axis_tready = s_udp_payload_fifo_tready && shift_payload_in;
assign s_udp_payload_fifo_tlast = s_udp_payload_axis_tlast;
assign s_udp_payload_fifo_tuser = s_udp_payload_axis_tuser;

assign m_udp_payload_axis_tdata = m_udp_payload_fifo_tdata;
assign m_udp_payload_axis_tvalid = m_udp_payload_fifo_tvalid;
assign m_udp_payload_fifo_tready = m_udp_payload_axis_tready;
assign m_udp_payload_axis_tlast = m_udp_payload_fifo_tlast;
assign m_udp_payload_axis_tuser = m_udp_payload_fifo_tuser;

/*
 * UDP Header FIFO
 */
reg [HEADER_FIFO_ADDR_WIDTH:0] header_fifo_wr_ptr_reg = {HEADER_FIFO_ADDR_WIDTH+1{1'b0}}, header_fifo_wr_ptr_next;
reg [HEADER_FIFO_ADDR_WIDTH:0] header_fifo_rd_ptr_reg = {HEADER_FIFO_ADDR_WIDTH+1{1'b0}}, header_fifo_rd_ptr_next;

reg [47:0] eth_dest_mac_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [47:0] eth_src_mac_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] eth_type_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [3:0] ip_version_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [3:0] ip_ihl_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [5:0] ip_dscp_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [1:0] ip_ecn_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] ip_identification_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [2:0] ip_flags_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [12:0] ip_fragment_offset_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [7:0] ip_ttl_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] ip_header_checksum_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [31:0] ip_source_ip_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [31:0] ip_dest_ip_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] udp_source_port_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] udp_dest_port_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] udp_length_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];
reg [15:0] udp_checksum_mem[(2**HEADER_FIFO_ADDR_WIDTH)-1:0];

reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;
reg [3:0]  m_ip_version_reg = 4'd0;
reg [3:0]  m_ip_ihl_reg = 4'd0;
reg [5:0]  m_ip_dscp_reg = 6'd0;
reg [1:0]  m_ip_ecn_reg = 2'd0;
reg [15:0] m_ip_identification_reg = 16'd0;
reg [2:0]  m_ip_flags_reg = 3'd0;
reg [12:0] m_ip_fragment_offset_reg = 13'd0;
reg [7:0]  m_ip_ttl_reg = 8'd0;
reg [15:0] m_ip_header_checksum_reg = 16'd0;
reg [31:0] m_ip_source_ip_reg = 32'd0;
reg [31:0] m_ip_dest_ip_reg = 32'd0;
reg [15:0] m_udp_source_port_reg = 16'd0;
reg [15:0] m_udp_dest_port_reg = 16'd0;
reg [15:0] m_udp_length_reg = 16'd0;
reg [15:0] m_udp_checksum_reg = 16'd0;

reg m_udp_hdr_valid_reg = 1'b0, m_udp_hdr_valid_next;

// full when first MSB different but rest same
wire header_fifo_full = ((header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH] != header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH]) &&
                         (header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0] == header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]));
// empty when pointers match exactly
wire header_fifo_empty = header_fifo_wr_ptr_reg == header_fifo_rd_ptr_reg;

// control signals
reg header_fifo_write;
reg header_fifo_read;

wire header_fifo_ready = !header_fifo_full;

assign m_udp_hdr_valid = m_udp_hdr_valid_reg;

assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_ip_version = m_ip_version_reg;
assign m_ip_ihl = m_ip_ihl_reg;
assign m_ip_dscp = m_ip_dscp_reg;
assign m_ip_ecn = m_ip_ecn_reg;
assign m_ip_length = m_udp_length_reg + 16'd20;
assign m_ip_identification = m_ip_identification_reg;
assign m_ip_flags = m_ip_flags_reg;
assign m_ip_fragment_offset = m_ip_fragment_offset_reg;
assign m_ip_ttl = m_ip_ttl_reg;
assign m_ip_protocol = 8'h11;
assign m_ip_header_checksum = m_ip_header_checksum_reg;
assign m_ip_source_ip = m_ip_source_ip_reg;
assign m_ip_dest_ip = m_ip_dest_ip_reg;
assign m_udp_source_port = m_udp_source_port_reg;
assign m_udp_dest_port = m_udp_dest_port_reg;
assign m_udp_length = m_udp_length_reg;
assign m_udp_checksum = m_udp_checksum_reg;

// Write logic
always @* begin
    header_fifo_write = 1'b0;

    header_fifo_wr_ptr_next = header_fifo_wr_ptr_reg;

    if (hdr_valid_reg) begin
        // input data valid
        if (~header_fifo_full) begin
            // not full, perform write
            header_fifo_write = 1'b1;
            header_fifo_wr_ptr_next = header_fifo_wr_ptr_reg + 1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        header_fifo_wr_ptr_reg <= {HEADER_FIFO_ADDR_WIDTH+1{1'b0}};
    end else begin
        header_fifo_wr_ptr_reg <= header_fifo_wr_ptr_next;
    end

    if (header_fifo_write) begin
        eth_dest_mac_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= eth_dest_mac_reg;
        eth_src_mac_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= eth_src_mac_reg;
        eth_type_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= eth_type_reg;
        ip_version_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_version_reg;
        ip_ihl_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_ihl_reg;
        ip_dscp_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_dscp_reg;
        ip_ecn_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_ecn_reg;
        ip_identification_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_identification_reg;
        ip_flags_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_flags_reg;
        ip_fragment_offset_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_fragment_offset_reg;
        ip_ttl_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_ttl_reg;
        ip_header_checksum_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_header_checksum_reg;
        ip_source_ip_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_source_ip_reg;
        ip_dest_ip_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= ip_dest_ip_reg;
        udp_source_port_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= udp_source_port_reg;
        udp_dest_port_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= udp_dest_port_reg;
        udp_length_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= frame_ptr_reg;
        udp_checksum_mem[header_fifo_wr_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]] <= checksum_reg[15:0];
    end
end

// Read logic
always @* begin
    header_fifo_read = 1'b0;

    header_fifo_rd_ptr_next = header_fifo_rd_ptr_reg;

    m_udp_hdr_valid_next = m_udp_hdr_valid_reg;

    if (m_udp_hdr_ready || !m_udp_hdr_valid) begin
        // output data not valid OR currently being transferred
        if (!header_fifo_empty) begin
            // not empty, perform read
            header_fifo_read = 1'b1;
            m_udp_hdr_valid_next = 1'b1;
            header_fifo_rd_ptr_next = header_fifo_rd_ptr_reg + 1;
        end else begin
            // empty, invalidate
            m_udp_hdr_valid_next = 1'b0;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        header_fifo_rd_ptr_reg <= {HEADER_FIFO_ADDR_WIDTH+1{1'b0}};
        m_udp_hdr_valid_reg <= 1'b0;
    end else begin
        header_fifo_rd_ptr_reg <= header_fifo_rd_ptr_next;
        m_udp_hdr_valid_reg <= m_udp_hdr_valid_next;
    end

    if (header_fifo_read) begin
        m_eth_dest_mac_reg <= eth_dest_mac_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_eth_src_mac_reg <= eth_src_mac_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_eth_type_reg <= eth_type_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_version_reg <= ip_version_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_ihl_reg <= ip_ihl_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_dscp_reg <= ip_dscp_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_ecn_reg <= ip_ecn_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_identification_reg <= ip_identification_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_flags_reg <= ip_flags_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_fragment_offset_reg <= ip_fragment_offset_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_ttl_reg <= ip_ttl_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_header_checksum_reg <= ip_header_checksum_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_source_ip_reg <= ip_source_ip_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_ip_dest_ip_reg <= ip_dest_ip_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_udp_source_port_reg <= udp_source_port_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_udp_dest_port_reg <= udp_dest_port_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_udp_length_reg <= udp_length_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
        m_udp_checksum_reg <= udp_checksum_mem[header_fifo_rd_ptr_reg[HEADER_FIFO_ADDR_WIDTH-1:0]];
    end
end

assign s_udp_hdr_ready = s_udp_hdr_ready_reg;

assign busy = busy_reg;

always @* begin
    state_next = STATE_IDLE;

    s_udp_hdr_ready_next = 1'b0;
    s_udp_payload_axis_tready_next = 1'b0;

    store_udp_hdr = 1'b0;
    shift_payload_in = 1'b0;

    frame_ptr_next = frame_ptr_reg;
    checksum_next = checksum_reg;

    hdr_valid_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state
            s_udp_hdr_ready_next = header_fifo_ready;

            if (s_udp_hdr_ready && s_udp_hdr_valid) begin
                store_udp_hdr = 1'b1;
                frame_ptr_next = 0;
                // 16'h0011 = zero padded type field
                // 16'h0010 = header length times two
                checksum_next = 16'h0011 + 16'h0010;
                s_udp_hdr_ready_next = 1'b0;
                state_next = STATE_SUM_HEADER_1;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_SUM_HEADER_1: begin
            // sum pseudo header and header
            checksum_next = checksum_reg + ip_source_ip_reg[31:16] + ip_source_ip_reg[15:0];
            state_next = STATE_SUM_HEADER_2;
        end
        STATE_SUM_HEADER_2: begin
            // sum pseudo header and header
            checksum_next = checksum_reg + ip_dest_ip_reg[31:16] + ip_dest_ip_reg[15:0];
            state_next = STATE_SUM_HEADER_3;
        end
        STATE_SUM_HEADER_3: begin
            // sum pseudo header and header
            checksum_next = checksum_reg + udp_source_port_reg + udp_dest_port_reg;
            frame_ptr_next = 8;
            state_next = STATE_SUM_PAYLOAD;
        end
        STATE_SUM_PAYLOAD: begin
            // sum payload
            shift_payload_in = 1'b1;

            if (s_udp_payload_axis_tready && s_udp_payload_axis_tvalid) begin
                // checksum computation for payload - alternately store and accumulate
                // add 2 for length calculation (two length fields in pseudo header)
                if (frame_ptr_reg[0]) begin
                    checksum_next = checksum_reg + {8'h00, s_udp_payload_axis_tdata} + 2;
                end else begin
                    checksum_next = checksum_reg + {s_udp_payload_axis_tdata, 8'h00} + 2;
                end

                frame_ptr_next = frame_ptr_reg + 1;

                if (s_udp_payload_axis_tlast) begin
                    state_next = STATE_FINISH_SUM;
                end else begin
                    state_next = STATE_SUM_PAYLOAD;
                end
            end else begin
                state_next = STATE_SUM_PAYLOAD;
            end
        end
        STATE_FINISH_SUM: begin
            // add MSW (twice!) for proper ones complement sum
            checksum_part = checksum_reg[15:0] + checksum_reg[31:16];
            checksum_next = ~(checksum_part[15:0] + checksum_part[16]);
            hdr_valid_next = 1;
            state_next = STATE_IDLE;
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_udp_hdr_ready_reg <= 1'b0;
        s_udp_payload_axis_tready_reg <= 1'b0;
        hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        s_udp_hdr_ready_reg <= s_udp_hdr_ready_next;
        s_udp_payload_axis_tready_reg <= s_udp_payload_axis_tready_next;

        hdr_valid_reg <= hdr_valid_next;

        busy_reg <= state_next != STATE_IDLE;
    end

    frame_ptr_reg <= frame_ptr_next;
    checksum_reg <= checksum_next;

    // datapath
    if (store_udp_hdr) begin
        eth_dest_mac_reg <= s_eth_dest_mac;
        eth_src_mac_reg <= s_eth_src_mac;
        eth_type_reg <= s_eth_type;
        ip_version_reg <= s_ip_version;
        ip_ihl_reg <= s_ip_ihl;
        ip_dscp_reg <= s_ip_dscp;
        ip_ecn_reg <= s_ip_ecn;
        ip_identification_reg <= s_ip_identification;
        ip_flags_reg <= s_ip_flags;
        ip_fragment_offset_reg <= s_ip_fragment_offset;
        ip_ttl_reg <= s_ip_ttl;
        ip_header_checksum_reg <= s_ip_header_checksum;
        ip_source_ip_reg <= s_ip_source_ip;
        ip_dest_ip_reg <= s_ip_dest_ip;
        udp_source_port_reg <= s_udp_source_port;
        udp_dest_port_reg <= s_udp_dest_port;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/udp.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * UDP block, IP interface
 */
module udp #
(
    parameter CHECKSUM_GEN_ENABLE = 1,
    parameter CHECKSUM_PAYLOAD_FIFO_DEPTH = 2048,
    parameter CHECKSUM_HEADER_FIFO_DEPTH = 8
)
(
    input  wire        clk,
    input  wire        rst,
    
    /*
     * IP frame input
     */
    input  wire        s_ip_hdr_valid,
    output wire        s_ip_hdr_ready,
    input  wire [47:0] s_ip_eth_dest_mac,
    input  wire [47:0] s_ip_eth_src_mac,
    input  wire [15:0] s_ip_eth_type,
    input  wire [3:0]  s_ip_version,
    input  wire [3:0]  s_ip_ihl,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [15:0] s_ip_identification,
    input  wire [2:0]  s_ip_flags,
    input  wire [12:0] s_ip_fragment_offset,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [15:0] s_ip_header_checksum,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [7:0]  s_ip_payload_axis_tdata,
    input  wire        s_ip_payload_axis_tvalid,
    output wire        s_ip_payload_axis_tready,
    input  wire        s_ip_payload_axis_tlast,
    input  wire        s_ip_payload_axis_tuser,
    
    /*
     * IP frame output
     */
    output wire        m_ip_hdr_valid,
    input  wire        m_ip_hdr_ready,
    output wire [47:0] m_ip_eth_dest_mac,
    output wire [47:0] m_ip_eth_src_mac,
    output wire [15:0] m_ip_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [7:0]  m_ip_payload_axis_tdata,
    output wire        m_ip_payload_axis_tvalid,
    input  wire        m_ip_payload_axis_tready,
    output wire        m_ip_payload_axis_tlast,
    output wire        m_ip_payload_axis_tuser,
    
    /*
     * UDP frame input
     */
    input  wire        s_udp_hdr_valid,
    output wire        s_udp_hdr_ready,
    input  wire [47:0] s_udp_eth_dest_mac,
    input  wire [47:0] s_udp_eth_src_mac,
    input  wire [15:0] s_udp_eth_type,
    input  wire [3:0]  s_udp_ip_version,
    input  wire [3:0]  s_udp_ip_ihl,
    input  wire [5:0]  s_udp_ip_dscp,
    input  wire [1:0]  s_udp_ip_ecn,
    input  wire [15:0] s_udp_ip_identification,
    input  wire [2:0]  s_udp_ip_flags,
    input  wire [12:0] s_udp_ip_fragment_offset,
    input  wire [7:0]  s_udp_ip_ttl,
    input  wire [15:0] s_udp_ip_header_checksum,
    input  wire [31:0] s_udp_ip_source_ip,
    input  wire [31:0] s_udp_ip_dest_ip,
    input  wire [15:0] s_udp_source_port,
    input  wire [15:0] s_udp_dest_port,
    input  wire [15:0] s_udp_length,
    input  wire [15:0] s_udp_checksum,
    input  wire [7:0]  s_udp_payload_axis_tdata,
    input  wire        s_udp_payload_axis_tvalid,
    output wire        s_udp_payload_axis_tready,
    input  wire        s_udp_payload_axis_tlast,
    input  wire        s_udp_payload_axis_tuser,
    
    /*
     * UDP frame output
     */
    output wire        m_udp_hdr_valid,
    input  wire        m_udp_hdr_ready,
    output wire [47:0] m_udp_eth_dest_mac,
    output wire [47:0] m_udp_eth_src_mac,
    output wire [15:0] m_udp_eth_type,
    output wire [3:0]  m_udp_ip_version,
    output wire [3:0]  m_udp_ip_ihl,
    output wire [5:0]  m_udp_ip_dscp,
    output wire [1:0]  m_udp_ip_ecn,
    output wire [15:0] m_udp_ip_length,
    output wire [15:0] m_udp_ip_identification,
    output wire [2:0]  m_udp_ip_flags,
    output wire [12:0] m_udp_ip_fragment_offset,
    output wire [7:0]  m_udp_ip_ttl,
    output wire [7:0]  m_udp_ip_protocol,
    output wire [15:0] m_udp_ip_header_checksum,
    output wire [31:0] m_udp_ip_source_ip,
    output wire [31:0] m_udp_ip_dest_ip,
    output wire [15:0] m_udp_source_port,
    output wire [15:0] m_udp_dest_port,
    output wire [15:0] m_udp_length,
    output wire [15:0] m_udp_checksum,
    output wire [7:0]  m_udp_payload_axis_tdata,
    output wire        m_udp_payload_axis_tvalid,
    input  wire        m_udp_payload_axis_tready,
    output wire        m_udp_payload_axis_tlast,
    output wire        m_udp_payload_axis_tuser,
    
    /*
     * Status signals
     */
    output wire        rx_busy,
    output wire        tx_busy,
    output wire        rx_error_header_early_termination,
    output wire        rx_error_payload_early_termination,
    output wire        tx_error_payload_early_termination
);

wire        tx_udp_hdr_valid;
wire        tx_udp_hdr_ready;
wire [47:0] tx_udp_eth_dest_mac;
wire [47:0] tx_udp_eth_src_mac;
wire [15:0] tx_udp_eth_type;
wire [3:0]  tx_udp_ip_version;
wire [3:0]  tx_udp_ip_ihl;
wire [5:0]  tx_udp_ip_dscp;
wire [1:0]  tx_udp_ip_ecn;
wire [15:0] tx_udp_ip_identification;
wire [2:0]  tx_udp_ip_flags;
wire [12:0] tx_udp_ip_fragment_offset;
wire [7:0]  tx_udp_ip_ttl;
wire [15:0] tx_udp_ip_header_checksum;
wire [31:0] tx_udp_ip_source_ip;
wire [31:0] tx_udp_ip_dest_ip;
wire [15:0] tx_udp_source_port;
wire [15:0] tx_udp_dest_port;
wire [15:0] tx_udp_length;
wire [15:0] tx_udp_checksum;
wire [7:0]  tx_udp_payload_axis_tdata;
wire        tx_udp_payload_axis_tvalid;
wire        tx_udp_payload_axis_tready;
wire        tx_udp_payload_axis_tlast;
wire        tx_udp_payload_axis_tuser;

udp_ip_rx
udp_ip_rx_inst (
    .clk(clk),
    .rst(rst),
    // IP frame input
    .s_ip_hdr_valid(s_ip_hdr_valid),
    .s_ip_hdr_ready(s_ip_hdr_ready),
    .s_eth_dest_mac(s_ip_eth_dest_mac),
    .s_eth_src_mac(s_ip_eth_src_mac),
    .s_eth_type(s_ip_eth_type),
    .s_ip_version(s_ip_version),
    .s_ip_ihl(s_ip_ihl),
    .s_ip_dscp(s_ip_dscp),
    .s_ip_ecn(s_ip_ecn),
    .s_ip_length(s_ip_length),
    .s_ip_identification(s_ip_identification),
    .s_ip_flags(s_ip_flags),
    .s_ip_fragment_offset(s_ip_fragment_offset),
    .s_ip_ttl(s_ip_ttl),
    .s_ip_protocol(s_ip_protocol),
    .s_ip_header_checksum(s_ip_header_checksum),
    .s_ip_source_ip(s_ip_source_ip),
    .s_ip_dest_ip(s_ip_dest_ip),
    .s_ip_payload_axis_tdata(s_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(s_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(s_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(s_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(s_ip_payload_axis_tuser),
    // UDP frame output
    .m_udp_hdr_valid(m_udp_hdr_valid),
    .m_udp_hdr_ready(m_udp_hdr_ready),
    .m_eth_dest_mac(m_udp_eth_dest_mac),
    .m_eth_src_mac(m_udp_eth_src_mac),
    .m_eth_type(m_udp_eth_type),
    .m_ip_version(m_udp_ip_version),
    .m_ip_ihl(m_udp_ip_ihl),
    .m_ip_dscp(m_udp_ip_dscp),
    .m_ip_ecn(m_udp_ip_ecn),
    .m_ip_length(m_udp_ip_length),
    .m_ip_identification(m_udp_ip_identification),
    .m_ip_flags(m_udp_ip_flags),
    .m_ip_fragment_offset(m_udp_ip_fragment_offset),
    .m_ip_ttl(m_udp_ip_ttl),
    .m_ip_protocol(m_udp_ip_protocol),
    .m_ip_header_checksum(m_udp_ip_header_checksum),
    .m_ip_source_ip(m_udp_ip_source_ip),
    .m_ip_dest_ip(m_udp_ip_dest_ip),
    .m_udp_source_port(m_udp_source_port),
    .m_udp_dest_port(m_udp_dest_port),
    .m_udp_length(m_udp_length),
    .m_udp_checksum(m_udp_checksum),
    .m_udp_payload_axis_tdata(m_udp_payload_axis_tdata),
    .m_udp_payload_axis_tvalid(m_udp_payload_axis_tvalid),
    .m_udp_payload_axis_tready(m_udp_payload_axis_tready),
    .m_udp_payload_axis_tlast(m_udp_payload_axis_tlast),
    .m_udp_payload_axis_tuser(m_udp_payload_axis_tuser),
    // Status signals
    .busy(rx_busy),
    .error_header_early_termination(rx_error_header_early_termination),
    .error_payload_early_termination(rx_error_payload_early_termination)
);

generate

if (CHECKSUM_GEN_ENABLE) begin

    udp_checksum_gen #(
        .PAYLOAD_FIFO_DEPTH(CHECKSUM_PAYLOAD_FIFO_DEPTH),
        .HEADER_FIFO_DEPTH(CHECKSUM_HEADER_FIFO_DEPTH)
    )
    udp_checksum_gen_inst (
        .clk(clk),
        .rst(rst),
        // UDP frame input
        .s_udp_hdr_valid(s_udp_hdr_valid),
        .s_udp_hdr_ready(s_udp_hdr_ready),
        .s_eth_dest_mac(s_udp_eth_dest_mac),
        .s_eth_src_mac(s_udp_eth_src_mac),
        .s_eth_type(s_udp_eth_type),
        .s_ip_version(s_udp_ip_version),
        .s_ip_ihl(s_udp_ip_ihl),
        .s_ip_dscp(s_udp_ip_dscp),
        .s_ip_ecn(s_udp_ip_ecn),
        .s_ip_identification(s_udp_ip_identification),
        .s_ip_flags(s_udp_ip_flags),
        .s_ip_fragment_offset(s_udp_ip_fragment_offset),
        .s_ip_ttl(s_udp_ip_ttl),
        .s_ip_header_checksum(s_udp_ip_header_checksum),
        .s_ip_source_ip(s_udp_ip_source_ip),
        .s_ip_dest_ip(s_udp_ip_dest_ip),
        .s_udp_source_port(s_udp_source_port),
        .s_udp_dest_port(s_udp_dest_port),
        .s_udp_payload_axis_tdata(s_udp_payload_axis_tdata),
        .s_udp_payload_axis_tvalid(s_udp_payload_axis_tvalid),
        .s_udp_payload_axis_tready(s_udp_payload_axis_tready),
        .s_udp_payload_axis_tlast(s_udp_payload_axis_tlast),
        .s_udp_payload_axis_tuser(s_udp_payload_axis_tuser),
        // UDP frame output
        .m_udp_hdr_valid(tx_udp_hdr_valid),
        .m_udp_hdr_ready(tx_udp_hdr_ready),
        .m_eth_dest_mac(tx_udp_eth_dest_mac),
        .m_eth_src_mac(tx_udp_eth_src_mac),
        .m_eth_type(tx_udp_eth_type),
        .m_ip_version(tx_udp_ip_version),
        .m_ip_ihl(tx_udp_ip_ihl),
        .m_ip_dscp(tx_udp_ip_dscp),
        .m_ip_ecn(tx_udp_ip_ecn),
        .m_ip_length(),
        .m_ip_identification(tx_udp_ip_identification),
        .m_ip_flags(tx_udp_ip_flags),
        .m_ip_fragment_offset(tx_udp_ip_fragment_offset),
        .m_ip_ttl(tx_udp_ip_ttl),
        .m_ip_protocol(),
        .m_ip_header_checksum(tx_udp_ip_header_checksum),
        .m_ip_source_ip(tx_udp_ip_source_ip),
        .m_ip_dest_ip(tx_udp_ip_dest_ip),
        .m_udp_source_port(tx_udp_source_port),
        .m_udp_dest_port(tx_udp_dest_port),
        .m_udp_length(tx_udp_length),
        .m_udp_checksum(tx_udp_checksum),
        .m_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
        .m_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
        .m_udp_payload_axis_tready(tx_udp_payload_axis_tready),
        .m_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
        .m_udp_payload_axis_tuser(tx_udp_payload_axis_tuser),
        // Status signals
        .busy()
    );

end else begin

    assign tx_udp_hdr_valid = s_udp_hdr_valid;
    assign s_udp_hdr_ready = tx_udp_hdr_ready;
    assign tx_udp_eth_dest_mac = s_udp_eth_dest_mac;
    assign tx_udp_eth_src_mac = s_udp_eth_src_mac;
    assign tx_udp_eth_type = s_udp_eth_type;
    assign tx_udp_ip_version = s_udp_ip_version;
    assign tx_udp_ip_ihl = s_udp_ip_ihl;
    assign tx_udp_ip_dscp = s_udp_ip_dscp;
    assign tx_udp_ip_ecn = s_udp_ip_ecn;
    assign tx_udp_ip_identification = s_udp_ip_identification;
    assign tx_udp_ip_flags = s_udp_ip_flags;
    assign tx_udp_ip_fragment_offset = s_udp_ip_fragment_offset;
    assign tx_udp_ip_ttl = s_udp_ip_ttl;
    assign tx_udp_ip_header_checksum = s_udp_ip_header_checksum;
    assign tx_udp_ip_source_ip = s_udp_ip_source_ip;
    assign tx_udp_ip_dest_ip = s_udp_ip_dest_ip;
    assign tx_udp_source_port = s_udp_source_port;
    assign tx_udp_dest_port = s_udp_dest_port;
    assign tx_udp_length = s_udp_length;
    assign tx_udp_checksum = s_udp_checksum;
    assign tx_udp_payload_axis_tdata = s_udp_payload_axis_tdata;
    assign tx_udp_payload_axis_tvalid = s_udp_payload_axis_tvalid;
    assign s_udp_payload_axis_tready = tx_udp_payload_axis_tready;
    assign tx_udp_payload_axis_tlast = s_udp_payload_axis_tlast;
    assign tx_udp_payload_axis_tuser = s_udp_payload_axis_tuser;

end

endgenerate

udp_ip_tx
udp_ip_tx_inst (
    .clk(clk),
    .rst(rst),
    // UDP frame input
    .s_udp_hdr_valid(tx_udp_hdr_valid),
    .s_udp_hdr_ready(tx_udp_hdr_ready),
    .s_eth_dest_mac(tx_udp_eth_dest_mac),
    .s_eth_src_mac(tx_udp_eth_src_mac),
    .s_eth_type(tx_udp_eth_type),
    .s_ip_version(tx_udp_ip_version),
    .s_ip_ihl(tx_udp_ip_ihl),
    .s_ip_dscp(tx_udp_ip_dscp),
    .s_ip_ecn(tx_udp_ip_ecn),
    .s_ip_identification(tx_udp_ip_identification),
    .s_ip_flags(tx_udp_ip_flags),
    .s_ip_fragment_offset(tx_udp_ip_fragment_offset),
    .s_ip_ttl(tx_udp_ip_ttl),
    .s_ip_protocol(8'h11),
    .s_ip_header_checksum(tx_udp_ip_header_checksum),
    .s_ip_source_ip(tx_udp_ip_source_ip),
    .s_ip_dest_ip(tx_udp_ip_dest_ip),
    .s_udp_source_port(tx_udp_source_port),
    .s_udp_dest_port(tx_udp_dest_port),
    .s_udp_length(tx_udp_length),
    .s_udp_checksum(tx_udp_checksum),
    .s_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
    .s_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
    .s_udp_payload_axis_tready(tx_udp_payload_axis_tready),
    .s_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
    .s_udp_payload_axis_tuser(tx_udp_payload_axis_tuser),
    // IP frame output
    .m_ip_hdr_valid(m_ip_hdr_valid),
    .m_ip_hdr_ready(m_ip_hdr_ready),
    .m_eth_dest_mac(m_ip_eth_dest_mac),
    .m_eth_src_mac(m_ip_eth_src_mac),
    .m_eth_type(m_ip_eth_type),
    .m_ip_version(m_ip_version),
    .m_ip_ihl(m_ip_ihl),
    .m_ip_dscp(m_ip_dscp),
    .m_ip_ecn(m_ip_ecn),
    .m_ip_length(m_ip_length),
    .m_ip_identification(m_ip_identification),
    .m_ip_flags(m_ip_flags),
    .m_ip_fragment_offset(m_ip_fragment_offset),
    .m_ip_ttl(m_ip_ttl),
    .m_ip_protocol(m_ip_protocol),
    .m_ip_header_checksum(m_ip_header_checksum),
    .m_ip_source_ip(m_ip_source_ip),
    .m_ip_dest_ip(m_ip_dest_ip),
    .m_ip_payload_axis_tdata(m_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(m_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(m_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(m_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(m_ip_payload_axis_tuser),
    // Status signals
    .busy(tx_busy),
    .error_payload_early_termination(tx_error_payload_early_termination)
);

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/udp_ip_rx.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * UDP ethernet frame receiver (IP frame in, UDP frame out)
 */
module udp_ip_rx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * IP frame input
     */
    input  wire        s_ip_hdr_valid,
    output wire        s_ip_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [3:0]  s_ip_version,
    input  wire [3:0]  s_ip_ihl,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [15:0] s_ip_identification,
    input  wire [2:0]  s_ip_flags,
    input  wire [12:0] s_ip_fragment_offset,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [15:0] s_ip_header_checksum,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [7:0]  s_ip_payload_axis_tdata,
    input  wire        s_ip_payload_axis_tvalid,
    output wire        s_ip_payload_axis_tready,
    input  wire        s_ip_payload_axis_tlast,
    input  wire        s_ip_payload_axis_tuser,

    /*
     * UDP frame output
     */
    output wire        m_udp_hdr_valid,
    input  wire        m_udp_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [15:0] m_udp_source_port,
    output wire [15:0] m_udp_dest_port,
    output wire [15:0] m_udp_length,
    output wire [15:0] m_udp_checksum,
    output wire [7:0]  m_udp_payload_axis_tdata,
    output wire        m_udp_payload_axis_tvalid,
    input  wire        m_udp_payload_axis_tready,
    output wire        m_udp_payload_axis_tlast,
    output wire        m_udp_payload_axis_tuser,

    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_header_early_termination,
    output wire        error_payload_early_termination
);

/*

UDP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets

 source port                 2 octets
 desination port             2 octets
 length                      2 octets
 checksum                    2 octets

 payload                     length octets

This module receives an IP frame with header fields in parallel and payload on
an AXI stream interface, decodes and strips the UDP header fields, then
produces the header fields in parallel along with the UDP payload in a
separate AXI stream.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_READ_HEADER = 3'd1,
    STATE_READ_PAYLOAD = 3'd2,
    STATE_READ_PAYLOAD_LAST = 3'd3,
    STATE_WAIT_LAST = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_ip_hdr;
reg store_udp_source_port_0;
reg store_udp_source_port_1;
reg store_udp_dest_port_0;
reg store_udp_dest_port_1;
reg store_udp_length_0;
reg store_udp_length_1;
reg store_udp_checksum_0;
reg store_udp_checksum_1;
reg store_last_word;

reg [2:0] hdr_ptr_reg = 3'd0, hdr_ptr_next;
reg [15:0] word_count_reg = 16'd0, word_count_next;

reg [7:0] last_word_data_reg = 8'd0;

reg m_udp_hdr_valid_reg = 1'b0, m_udp_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;
reg [3:0] m_ip_version_reg = 4'd0;
reg [3:0] m_ip_ihl_reg = 4'd0;
reg [5:0] m_ip_dscp_reg = 6'd0;
reg [1:0] m_ip_ecn_reg = 2'd0;
reg [15:0] m_ip_length_reg = 16'd0;
reg [15:0] m_ip_identification_reg = 16'd0;
reg [2:0] m_ip_flags_reg = 3'd0;
reg [12:0] m_ip_fragment_offset_reg = 13'd0;
reg [7:0] m_ip_ttl_reg = 8'd0;
reg [7:0] m_ip_protocol_reg = 8'd0;
reg [15:0] m_ip_header_checksum_reg = 16'd0;
reg [31:0] m_ip_source_ip_reg = 32'd0;
reg [31:0] m_ip_dest_ip_reg = 32'd0;
reg [15:0] m_udp_source_port_reg = 16'd0;
reg [15:0] m_udp_dest_port_reg = 16'd0;
reg [15:0] m_udp_length_reg = 16'd0;
reg [15:0] m_udp_checksum_reg = 16'd0;

reg s_ip_hdr_ready_reg = 1'b0, s_ip_hdr_ready_next;
reg s_ip_payload_axis_tready_reg = 1'b0, s_ip_payload_axis_tready_next;

reg busy_reg = 1'b0;
reg error_header_early_termination_reg = 1'b0, error_header_early_termination_next;
reg error_payload_early_termination_reg = 1'b0, error_payload_early_termination_next;

// internal datapath
reg [7:0] m_udp_payload_axis_tdata_int;
reg       m_udp_payload_axis_tvalid_int;
reg       m_udp_payload_axis_tready_int_reg = 1'b0;
reg       m_udp_payload_axis_tlast_int;
reg       m_udp_payload_axis_tuser_int;
wire      m_udp_payload_axis_tready_int_early;

assign s_ip_hdr_ready = s_ip_hdr_ready_reg;
assign s_ip_payload_axis_tready = s_ip_payload_axis_tready_reg;

assign m_udp_hdr_valid = m_udp_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_ip_version = m_ip_version_reg;
assign m_ip_ihl = m_ip_ihl_reg;
assign m_ip_dscp = m_ip_dscp_reg;
assign m_ip_ecn = m_ip_ecn_reg;
assign m_ip_length = m_ip_length_reg;
assign m_ip_identification = m_ip_identification_reg;
assign m_ip_flags = m_ip_flags_reg;
assign m_ip_fragment_offset = m_ip_fragment_offset_reg;
assign m_ip_ttl = m_ip_ttl_reg;
assign m_ip_protocol = m_ip_protocol_reg;
assign m_ip_header_checksum = m_ip_header_checksum_reg;
assign m_ip_source_ip = m_ip_source_ip_reg;
assign m_ip_dest_ip = m_ip_dest_ip_reg;
assign m_udp_source_port = m_udp_source_port_reg;
assign m_udp_dest_port = m_udp_dest_port_reg;
assign m_udp_length = m_udp_length_reg;
assign m_udp_checksum = m_udp_checksum_reg;

assign busy = busy_reg;
assign error_header_early_termination = error_header_early_termination_reg;
assign error_payload_early_termination = error_payload_early_termination_reg;

always @* begin
    state_next = STATE_IDLE;

    s_ip_hdr_ready_next = 1'b0;
    s_ip_payload_axis_tready_next = 1'b0;

    store_ip_hdr = 1'b0;
    store_udp_source_port_0 = 1'b0;
    store_udp_source_port_1 = 1'b0;
    store_udp_dest_port_0 = 1'b0;
    store_udp_dest_port_1 = 1'b0;
    store_udp_length_0 = 1'b0;
    store_udp_length_1 = 1'b0;
    store_udp_checksum_0 = 1'b0;
    store_udp_checksum_1 = 1'b0;

    store_last_word = 1'b0;

    hdr_ptr_next = hdr_ptr_reg;
    word_count_next = word_count_reg;

    m_udp_hdr_valid_next = m_udp_hdr_valid_reg && !m_udp_hdr_ready;

    error_header_early_termination_next = 1'b0;
    error_payload_early_termination_next = 1'b0;

    m_udp_payload_axis_tdata_int = 8'd0;
    m_udp_payload_axis_tvalid_int = 1'b0;
    m_udp_payload_axis_tlast_int = 1'b0;
    m_udp_payload_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for header
            hdr_ptr_next = 3'd0;
            s_ip_hdr_ready_next = !m_udp_hdr_valid_next;

            if (s_ip_hdr_ready && s_ip_hdr_valid) begin
                s_ip_hdr_ready_next = 1'b0;
                s_ip_payload_axis_tready_next = 1'b1;
                store_ip_hdr = 1'b1;
                state_next = STATE_READ_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ_HEADER: begin
            // read header state
            s_ip_payload_axis_tready_next = 1'b1;
            word_count_next = m_udp_length_reg - 16'd8;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                // word transfer in - store it
                hdr_ptr_next = hdr_ptr_reg + 3'd1;
                state_next = STATE_READ_HEADER;

                case (hdr_ptr_reg)
                    3'h0: store_udp_source_port_1 = 1'b1;
                    3'h1: store_udp_source_port_0 = 1'b1;
                    3'h2: store_udp_dest_port_1 = 1'b1;
                    3'h3: store_udp_dest_port_0 = 1'b1;
                    3'h4: store_udp_length_1 = 1'b1;
                    3'h5: store_udp_length_0 = 1'b1;
                    3'h6: store_udp_checksum_1 = 1'b1;
                    3'h7: begin
                        store_udp_checksum_0 = 1'b1;
                        m_udp_hdr_valid_next = 1'b1;
                        s_ip_payload_axis_tready_next = m_udp_payload_axis_tready_int_early;
                        state_next = STATE_READ_PAYLOAD;
                    end
                endcase

                if (s_ip_payload_axis_tlast) begin
                    error_header_early_termination_next = 1'b1;
                    m_udp_hdr_valid_next = 1'b0;
                    s_ip_hdr_ready_next = !m_udp_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end

            end else begin
                state_next = STATE_READ_HEADER;
            end
        end
        STATE_READ_PAYLOAD: begin
            // read payload
            s_ip_payload_axis_tready_next = m_udp_payload_axis_tready_int_early;

            m_udp_payload_axis_tdata_int = s_ip_payload_axis_tdata;
            m_udp_payload_axis_tlast_int = s_ip_payload_axis_tlast;
            m_udp_payload_axis_tuser_int = s_ip_payload_axis_tuser;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                // word transfer through
                word_count_next = word_count_reg - 16'd1;
                m_udp_payload_axis_tvalid_int = 1'b1;
                if (s_ip_payload_axis_tlast) begin
                    if (word_count_reg != 16'd1) begin
                        // end of frame, but length does not match
                        m_udp_payload_axis_tuser_int = 1'b1;
                        error_payload_early_termination_next = 1'b1;
                    end
                    s_ip_hdr_ready_next = !m_udp_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    if (word_count_reg == 16'd1) begin
                        store_last_word = 1'b1;
                        m_udp_payload_axis_tvalid_int = 1'b0;
                        state_next = STATE_READ_PAYLOAD_LAST;
                    end else begin
                        state_next = STATE_READ_PAYLOAD;
                    end
                end
            end else begin
                state_next = STATE_READ_PAYLOAD;
            end
        end
        STATE_READ_PAYLOAD_LAST: begin
            // read and discard until end of frame
            s_ip_payload_axis_tready_next = m_udp_payload_axis_tready_int_early;

            m_udp_payload_axis_tdata_int = last_word_data_reg;
            m_udp_payload_axis_tlast_int = s_ip_payload_axis_tlast;
            m_udp_payload_axis_tuser_int = s_ip_payload_axis_tuser;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                if (s_ip_payload_axis_tlast) begin
                    s_ip_hdr_ready_next = !m_udp_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    m_udp_payload_axis_tvalid_int = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_READ_PAYLOAD_LAST;
                end
            end else begin
                state_next = STATE_READ_PAYLOAD_LAST;
            end
        end
        STATE_WAIT_LAST: begin
            // wait for end of frame; read and discard
            s_ip_payload_axis_tready_next = 1'b1;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                if (s_ip_payload_axis_tlast) begin
                    s_ip_hdr_ready_next = !m_udp_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end else begin
                state_next = STATE_WAIT_LAST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_ip_hdr_ready_reg <= 1'b0;
        s_ip_payload_axis_tready_reg <= 1'b0;
        m_udp_hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_header_early_termination_reg <= 1'b0;
        error_payload_early_termination_reg <= 1'b0;
    end else begin
        state_reg <= state_next;


        s_ip_hdr_ready_reg <= s_ip_hdr_ready_next;
        s_ip_payload_axis_tready_reg <= s_ip_payload_axis_tready_next;

        m_udp_hdr_valid_reg <= m_udp_hdr_valid_next;

        error_header_early_termination_reg <= error_header_early_termination_next;
        error_payload_early_termination_reg <= error_payload_early_termination_next;

        busy_reg <= state_next != STATE_IDLE;
    end

    hdr_ptr_reg <= hdr_ptr_next;
    word_count_reg <= word_count_next;

    // datapath
    if (store_ip_hdr) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
        m_ip_version_reg <= s_ip_version;
        m_ip_ihl_reg <= s_ip_ihl;
        m_ip_dscp_reg <= s_ip_dscp;
        m_ip_ecn_reg <= s_ip_ecn;
        m_ip_length_reg <= s_ip_length;
        m_ip_identification_reg <= s_ip_identification;
        m_ip_flags_reg <= s_ip_flags;
        m_ip_fragment_offset_reg <= s_ip_fragment_offset;
        m_ip_ttl_reg <= s_ip_ttl;
        m_ip_protocol_reg <= s_ip_protocol;
        m_ip_header_checksum_reg <= s_ip_header_checksum;
        m_ip_source_ip_reg <= s_ip_source_ip;
        m_ip_dest_ip_reg <= s_ip_dest_ip;
    end

    if (store_last_word) begin
        last_word_data_reg <= m_udp_payload_axis_tdata_int;
    end

    if (store_udp_source_port_0) m_udp_source_port_reg[ 7: 0] <= s_ip_payload_axis_tdata;
    if (store_udp_source_port_1) m_udp_source_port_reg[15: 8] <= s_ip_payload_axis_tdata;
    if (store_udp_dest_port_0) m_udp_dest_port_reg[ 7: 0] <= s_ip_payload_axis_tdata;
    if (store_udp_dest_port_1) m_udp_dest_port_reg[15: 8] <= s_ip_payload_axis_tdata;
    if (store_udp_length_0) m_udp_length_reg[ 7: 0] <= s_ip_payload_axis_tdata;
    if (store_udp_length_1) m_udp_length_reg[15: 8] <= s_ip_payload_axis_tdata;
    if (store_udp_checksum_0) m_udp_checksum_reg[ 7: 0] <= s_ip_payload_axis_tdata;
    if (store_udp_checksum_1) m_udp_checksum_reg[15: 8] <= s_ip_payload_axis_tdata;
end

// output datapath logic
reg [7:0] m_udp_payload_axis_tdata_reg = 8'd0;
reg       m_udp_payload_axis_tvalid_reg = 1'b0, m_udp_payload_axis_tvalid_next;
reg       m_udp_payload_axis_tlast_reg = 1'b0;
reg       m_udp_payload_axis_tuser_reg = 1'b0;

reg [7:0] temp_m_udp_payload_axis_tdata_reg = 8'd0;
reg       temp_m_udp_payload_axis_tvalid_reg = 1'b0, temp_m_udp_payload_axis_tvalid_next;
reg       temp_m_udp_payload_axis_tlast_reg = 1'b0;
reg       temp_m_udp_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_udp_payload_int_to_output;
reg store_udp_payload_int_to_temp;
reg store_udp_payload_axis_temp_to_output;

assign m_udp_payload_axis_tdata = m_udp_payload_axis_tdata_reg;
assign m_udp_payload_axis_tvalid = m_udp_payload_axis_tvalid_reg;
assign m_udp_payload_axis_tlast = m_udp_payload_axis_tlast_reg;
assign m_udp_payload_axis_tuser = m_udp_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_udp_payload_axis_tready_int_early = m_udp_payload_axis_tready || (!temp_m_udp_payload_axis_tvalid_reg && !m_udp_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_udp_payload_axis_tvalid_next = m_udp_payload_axis_tvalid_reg;
    temp_m_udp_payload_axis_tvalid_next = temp_m_udp_payload_axis_tvalid_reg;

    store_udp_payload_int_to_output = 1'b0;
    store_udp_payload_int_to_temp = 1'b0;
    store_udp_payload_axis_temp_to_output = 1'b0;
    
    if (m_udp_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_udp_payload_axis_tready || !m_udp_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_udp_payload_axis_tvalid_next = m_udp_payload_axis_tvalid_int;
            store_udp_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_udp_payload_axis_tvalid_next = m_udp_payload_axis_tvalid_int;
            store_udp_payload_int_to_temp = 1'b1;
        end
    end else if (m_udp_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_udp_payload_axis_tvalid_next = temp_m_udp_payload_axis_tvalid_reg;
        temp_m_udp_payload_axis_tvalid_next = 1'b0;
        store_udp_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_udp_payload_axis_tvalid_reg <= m_udp_payload_axis_tvalid_next;
    m_udp_payload_axis_tready_int_reg <= m_udp_payload_axis_tready_int_early;
    temp_m_udp_payload_axis_tvalid_reg <= temp_m_udp_payload_axis_tvalid_next;

    // datapath
    if (store_udp_payload_int_to_output) begin
        m_udp_payload_axis_tdata_reg <= m_udp_payload_axis_tdata_int;
        m_udp_payload_axis_tlast_reg <= m_udp_payload_axis_tlast_int;
        m_udp_payload_axis_tuser_reg <= m_udp_payload_axis_tuser_int;
    end else if (store_udp_payload_axis_temp_to_output) begin
        m_udp_payload_axis_tdata_reg <= temp_m_udp_payload_axis_tdata_reg;
        m_udp_payload_axis_tlast_reg <= temp_m_udp_payload_axis_tlast_reg;
        m_udp_payload_axis_tuser_reg <= temp_m_udp_payload_axis_tuser_reg;
    end

    if (store_udp_payload_int_to_temp) begin
        temp_m_udp_payload_axis_tdata_reg <= m_udp_payload_axis_tdata_int;
        temp_m_udp_payload_axis_tlast_reg <= m_udp_payload_axis_tlast_int;
        temp_m_udp_payload_axis_tuser_reg <= m_udp_payload_axis_tuser_int;
    end

    if (rst) begin
        m_udp_payload_axis_tvalid_reg <= 1'b0;
        m_udp_payload_axis_tready_int_reg <= 1'b0;
        temp_m_udp_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/udp_ip_tx.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * UDP ethernet frame transmitter (UDP frame in, IP frame out)
 */
module udp_ip_tx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * UDP frame input
     */
    input  wire        s_udp_hdr_valid,
    output wire        s_udp_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [3:0]  s_ip_version,
    input  wire [3:0]  s_ip_ihl,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_identification,
    input  wire [2:0]  s_ip_flags,
    input  wire [12:0] s_ip_fragment_offset,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [15:0] s_ip_header_checksum,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [15:0] s_udp_source_port,
    input  wire [15:0] s_udp_dest_port,
    input  wire [15:0] s_udp_length,
    input  wire [15:0] s_udp_checksum,
    input  wire [7:0]  s_udp_payload_axis_tdata,
    input  wire        s_udp_payload_axis_tvalid,
    output wire        s_udp_payload_axis_tready,
    input  wire        s_udp_payload_axis_tlast,
    input  wire        s_udp_payload_axis_tuser,

    /*
     * IP frame output
     */
    output wire        m_ip_hdr_valid,
    input  wire        m_ip_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [7:0]  m_ip_payload_axis_tdata,
    output wire        m_ip_payload_axis_tvalid,
    input  wire        m_ip_payload_axis_tready,
    output wire        m_ip_payload_axis_tlast,
    output wire        m_ip_payload_axis_tuser,

    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_payload_early_termination
);

/*

UDP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets

 source port                 2 octets
 desination port             2 octets
 length                      2 octets
 checksum                    2 octets

 payload                     length octets

This module receives a UDP frame with header fields in parallel along with the
payload in an AXI stream, combines the header with the payload, passes through
the IP headers, and transmits the complete IP payload on an AXI interface.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_WRITE_HEADER = 3'd1,
    STATE_WRITE_PAYLOAD = 3'd2,
    STATE_WRITE_PAYLOAD_LAST = 3'd3,
    STATE_WAIT_LAST = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_udp_hdr;
reg store_last_word;

reg [2:0] hdr_ptr_reg = 3'd0, hdr_ptr_next;
reg [15:0] word_count_reg = 16'd0, word_count_next;

reg [7:0] last_word_data_reg = 8'd0;

reg [15:0] udp_source_port_reg = 16'd0;
reg [15:0] udp_dest_port_reg = 16'd0;
reg [15:0] udp_length_reg = 16'd0;
reg [15:0] udp_checksum_reg = 16'd0;

reg s_udp_hdr_ready_reg = 1'b0, s_udp_hdr_ready_next;
reg s_udp_payload_axis_tready_reg = 1'b0, s_udp_payload_axis_tready_next;

reg m_ip_hdr_valid_reg = 1'b0, m_ip_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;
reg [3:0] m_ip_version_reg = 4'd0;
reg [3:0] m_ip_ihl_reg = 4'd0;
reg [5:0] m_ip_dscp_reg = 6'd0;
reg [1:0] m_ip_ecn_reg = 2'd0;
reg [15:0] m_ip_length_reg = 16'd0;
reg [15:0] m_ip_identification_reg = 16'd0;
reg [2:0] m_ip_flags_reg = 3'd0;
reg [12:0] m_ip_fragment_offset_reg = 13'd0;
reg [7:0] m_ip_ttl_reg = 8'd0;
reg [7:0] m_ip_protocol_reg = 8'd0;
reg [15:0] m_ip_header_checksum_reg = 16'd0;
reg [31:0] m_ip_source_ip_reg = 32'd0;
reg [31:0] m_ip_dest_ip_reg = 32'd0;

reg busy_reg = 1'b0;
reg error_payload_early_termination_reg = 1'b0, error_payload_early_termination_next;

// internal datapath
reg [7:0] m_ip_payload_axis_tdata_int;
reg       m_ip_payload_axis_tvalid_int;
reg       m_ip_payload_axis_tready_int_reg = 1'b0;
reg       m_ip_payload_axis_tlast_int;
reg       m_ip_payload_axis_tuser_int;
wire      m_ip_payload_axis_tready_int_early;

assign s_udp_hdr_ready = s_udp_hdr_ready_reg;
assign s_udp_payload_axis_tready = s_udp_payload_axis_tready_reg;

assign m_ip_hdr_valid = m_ip_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_ip_version = m_ip_version_reg;
assign m_ip_ihl = m_ip_ihl_reg;
assign m_ip_dscp = m_ip_dscp_reg;
assign m_ip_ecn = m_ip_ecn_reg;
assign m_ip_length = m_ip_length_reg;
assign m_ip_identification = m_ip_identification_reg;
assign m_ip_flags = m_ip_flags_reg;
assign m_ip_fragment_offset = m_ip_fragment_offset_reg;
assign m_ip_ttl = m_ip_ttl_reg;
assign m_ip_protocol = m_ip_protocol_reg;
assign m_ip_header_checksum = m_ip_header_checksum_reg;
assign m_ip_source_ip = m_ip_source_ip_reg;
assign m_ip_dest_ip = m_ip_dest_ip_reg;

assign busy = busy_reg;
assign error_payload_early_termination = error_payload_early_termination_reg;

always @* begin
    state_next = STATE_IDLE;

    s_udp_hdr_ready_next = 1'b0;
    s_udp_payload_axis_tready_next = 1'b0;

    store_udp_hdr = 1'b0;

    store_last_word = 1'b0;

    hdr_ptr_next = hdr_ptr_reg;
    word_count_next = word_count_reg;

    m_ip_hdr_valid_next = m_ip_hdr_valid_reg && !m_ip_hdr_ready;

    error_payload_early_termination_next = 1'b0;

    m_ip_payload_axis_tdata_int = 8'd0;
    m_ip_payload_axis_tvalid_int = 1'b0;
    m_ip_payload_axis_tlast_int = 1'b0;
    m_ip_payload_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for data
            hdr_ptr_next = 3'd0;
            s_udp_hdr_ready_next = !m_ip_hdr_valid_next;

            if (s_udp_hdr_ready && s_udp_hdr_valid) begin
                store_udp_hdr = 1'b1;
                s_udp_hdr_ready_next = 1'b0;
                m_ip_hdr_valid_next = 1'b1;
                if (m_ip_payload_axis_tready_int_reg) begin
                    m_ip_payload_axis_tvalid_int = 1'b1;
                    m_ip_payload_axis_tdata_int = s_udp_source_port[15: 8];
                    hdr_ptr_next = 3'd1;
                end
                state_next = STATE_WRITE_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_WRITE_HEADER: begin
            // write header state
            word_count_next = udp_length_reg - 16'd8;

            if (m_ip_payload_axis_tready_int_reg) begin
                // word transfer out
                hdr_ptr_next = hdr_ptr_reg + 3'd1;
                m_ip_payload_axis_tvalid_int = 1'b1;
                state_next = STATE_WRITE_HEADER;
                case (hdr_ptr_reg)
                    3'h0: m_ip_payload_axis_tdata_int = udp_source_port_reg[15: 8];
                    3'h1: m_ip_payload_axis_tdata_int = udp_source_port_reg[ 7: 0];
                    3'h2: m_ip_payload_axis_tdata_int = udp_dest_port_reg[15: 8];
                    3'h3: m_ip_payload_axis_tdata_int = udp_dest_port_reg[ 7: 0];
                    3'h4: m_ip_payload_axis_tdata_int = udp_length_reg[15: 8];
                    3'h5: m_ip_payload_axis_tdata_int = udp_length_reg[ 7: 0];
                    3'h6: m_ip_payload_axis_tdata_int = udp_checksum_reg[15: 8];
                    3'h7: begin
                        m_ip_payload_axis_tdata_int = udp_checksum_reg[ 7: 0];
                        s_udp_payload_axis_tready_next = m_ip_payload_axis_tready_int_early;
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                endcase
            end else begin
                state_next = STATE_WRITE_HEADER;
            end
        end
        STATE_WRITE_PAYLOAD: begin
            // write payload
            s_udp_payload_axis_tready_next = m_ip_payload_axis_tready_int_early;

            m_ip_payload_axis_tdata_int = s_udp_payload_axis_tdata;
            m_ip_payload_axis_tlast_int = s_udp_payload_axis_tlast;
            m_ip_payload_axis_tuser_int = s_udp_payload_axis_tuser;

            if (s_udp_payload_axis_tready && s_udp_payload_axis_tvalid) begin
                // word transfer through
                word_count_next = word_count_reg - 16'd1;
                m_ip_payload_axis_tvalid_int = 1'b1;
                if (s_udp_payload_axis_tlast) begin
                    if (word_count_reg != 16'd1) begin
                        // end of frame, but length does not match
                        m_ip_payload_axis_tuser_int = 1'b1;
                        error_payload_early_termination_next = 1'b1;
                    end
                    s_udp_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_udp_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    if (word_count_reg == 16'd1) begin
                        store_last_word = 1'b1;
                        m_ip_payload_axis_tvalid_int = 1'b0;
                        state_next = STATE_WRITE_PAYLOAD_LAST;
                    end else begin
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD;
            end
        end
        STATE_WRITE_PAYLOAD_LAST: begin
            // read and discard until end of frame
            s_udp_payload_axis_tready_next = m_ip_payload_axis_tready_int_early;

            m_ip_payload_axis_tdata_int = last_word_data_reg;
            m_ip_payload_axis_tlast_int = s_udp_payload_axis_tlast;
            m_ip_payload_axis_tuser_int = s_udp_payload_axis_tuser;

            if (s_udp_payload_axis_tready && s_udp_payload_axis_tvalid) begin
                if (s_udp_payload_axis_tlast) begin
                    s_udp_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_udp_payload_axis_tready_next = 1'b0;
                    m_ip_payload_axis_tvalid_int = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WRITE_PAYLOAD_LAST;
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD_LAST;
            end
        end
        STATE_WAIT_LAST: begin
            // wait for end of frame; read and discard
            s_udp_payload_axis_tready_next = 1'b1;

            if (s_udp_payload_axis_tvalid) begin
                if (s_udp_payload_axis_tlast) begin
                    s_udp_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_udp_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end else begin
                state_next = STATE_WAIT_LAST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_udp_hdr_ready_reg <= 1'b0;
        s_udp_payload_axis_tready_reg <= 1'b0;
        m_ip_hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_payload_early_termination_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        s_udp_hdr_ready_reg <= s_udp_hdr_ready_next;
        s_udp_payload_axis_tready_reg <= s_udp_payload_axis_tready_next;

        m_ip_hdr_valid_reg <= m_ip_hdr_valid_next;

        busy_reg <= state_next != STATE_IDLE;

        error_payload_early_termination_reg <= error_payload_early_termination_next;
    end

    hdr_ptr_reg <= hdr_ptr_next;
    word_count_reg <= word_count_next;

    // datapath
    if (store_udp_hdr) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
        m_ip_version_reg <= s_ip_version;
        m_ip_ihl_reg <= s_ip_ihl;
        m_ip_dscp_reg <= s_ip_dscp;
        m_ip_ecn_reg <= s_ip_ecn;
        m_ip_length_reg <= s_udp_length + 20;
        m_ip_identification_reg <= s_ip_identification;
        m_ip_flags_reg <= s_ip_flags;
        m_ip_fragment_offset_reg <= s_ip_fragment_offset;
        m_ip_ttl_reg <= s_ip_ttl;
        m_ip_protocol_reg <= s_ip_protocol;
        m_ip_header_checksum_reg <= s_ip_header_checksum;
        m_ip_source_ip_reg <= s_ip_source_ip;
        m_ip_dest_ip_reg <= s_ip_dest_ip;
        udp_source_port_reg <= s_udp_source_port;
        udp_dest_port_reg <= s_udp_dest_port;
        udp_length_reg <= s_udp_length;
        udp_checksum_reg <= s_udp_checksum;
    end

    if (store_last_word) begin
        last_word_data_reg <= m_ip_payload_axis_tdata_int;
    end
end

// output datapath logic
reg [7:0] m_ip_payload_axis_tdata_reg = 8'd0;
reg       m_ip_payload_axis_tvalid_reg = 1'b0, m_ip_payload_axis_tvalid_next;
reg       m_ip_payload_axis_tlast_reg = 1'b0;
reg       m_ip_payload_axis_tuser_reg = 1'b0;

reg [7:0] temp_m_ip_payload_axis_tdata_reg = 8'd0;
reg       temp_m_ip_payload_axis_tvalid_reg = 1'b0, temp_m_ip_payload_axis_tvalid_next;
reg       temp_m_ip_payload_axis_tlast_reg = 1'b0;
reg       temp_m_ip_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_ip_payload_int_to_output;
reg store_ip_payload_int_to_temp;
reg store_ip_payload_axis_temp_to_output;

assign m_ip_payload_axis_tdata = m_ip_payload_axis_tdata_reg;
assign m_ip_payload_axis_tvalid = m_ip_payload_axis_tvalid_reg;
assign m_ip_payload_axis_tlast = m_ip_payload_axis_tlast_reg;
assign m_ip_payload_axis_tuser = m_ip_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_ip_payload_axis_tready_int_early = m_ip_payload_axis_tready || (!temp_m_ip_payload_axis_tvalid_reg && !m_ip_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_reg;
    temp_m_ip_payload_axis_tvalid_next = temp_m_ip_payload_axis_tvalid_reg;

    store_ip_payload_int_to_output = 1'b0;
    store_ip_payload_int_to_temp = 1'b0;
    store_ip_payload_axis_temp_to_output = 1'b0;
    
    if (m_ip_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_ip_payload_axis_tready || !m_ip_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_int;
            store_ip_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_int;
            store_ip_payload_int_to_temp = 1'b1;
        end
    end else if (m_ip_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_ip_payload_axis_tvalid_next = temp_m_ip_payload_axis_tvalid_reg;
        temp_m_ip_payload_axis_tvalid_next = 1'b0;
        store_ip_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_ip_payload_axis_tvalid_reg <= m_ip_payload_axis_tvalid_next;
    m_ip_payload_axis_tready_int_reg <= m_ip_payload_axis_tready_int_early;
    temp_m_ip_payload_axis_tvalid_reg <= temp_m_ip_payload_axis_tvalid_next;

    // datapath
    if (store_ip_payload_int_to_output) begin
        m_ip_payload_axis_tdata_reg <= m_ip_payload_axis_tdata_int;
        m_ip_payload_axis_tlast_reg <= m_ip_payload_axis_tlast_int;
        m_ip_payload_axis_tuser_reg <= m_ip_payload_axis_tuser_int;
    end else if (store_ip_payload_axis_temp_to_output) begin
        m_ip_payload_axis_tdata_reg <= temp_m_ip_payload_axis_tdata_reg;
        m_ip_payload_axis_tlast_reg <= temp_m_ip_payload_axis_tlast_reg;
        m_ip_payload_axis_tuser_reg <= temp_m_ip_payload_axis_tuser_reg;
    end

    if (store_ip_payload_int_to_temp) begin
        temp_m_ip_payload_axis_tdata_reg <= m_ip_payload_axis_tdata_int;
        temp_m_ip_payload_axis_tlast_reg <= m_ip_payload_axis_tlast_int;
        temp_m_ip_payload_axis_tuser_reg <= m_ip_payload_axis_tuser_int;
    end

    if (rst) begin
        m_ip_payload_axis_tvalid_reg <= 1'b0;
        m_ip_payload_axis_tready_int_reg <= 1'b0;
        temp_m_ip_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/ip_complete.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IPv4 and ARP block, ethernet frame interface
 */
module ip_complete #(
    parameter ARP_CACHE_ADDR_WIDTH = 9,
    parameter ARP_REQUEST_RETRY_COUNT = 4,
    parameter ARP_REQUEST_RETRY_INTERVAL = 125000000*2,
    parameter ARP_REQUEST_TIMEOUT = 125000000*30
)
(
    input  wire        clk,
    input  wire        rst,

    /*
     * Ethernet frame input
     */
    input  wire        s_eth_hdr_valid,
    output wire        s_eth_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [7:0]  s_eth_payload_axis_tdata,
    input  wire        s_eth_payload_axis_tvalid,
    output wire        s_eth_payload_axis_tready,
    input  wire        s_eth_payload_axis_tlast,
    input  wire        s_eth_payload_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire        m_eth_hdr_valid,
    input  wire        m_eth_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [7:0]  m_eth_payload_axis_tdata,
    output wire        m_eth_payload_axis_tvalid,
    input  wire        m_eth_payload_axis_tready,
    output wire        m_eth_payload_axis_tlast,
    output wire        m_eth_payload_axis_tuser,

    /*
     * IP input
     */
    input  wire        s_ip_hdr_valid,
    output wire        s_ip_hdr_ready,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [7:0]  s_ip_payload_axis_tdata,
    input  wire        s_ip_payload_axis_tvalid,
    output wire        s_ip_payload_axis_tready,
    input  wire        s_ip_payload_axis_tlast,
    input  wire        s_ip_payload_axis_tuser,

    /*
     * IP output
     */
    output wire        m_ip_hdr_valid,
    input  wire        m_ip_hdr_ready,
    output wire [47:0] m_ip_eth_dest_mac,
    output wire [47:0] m_ip_eth_src_mac,
    output wire [15:0] m_ip_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [7:0]  m_ip_payload_axis_tdata,
    output wire        m_ip_payload_axis_tvalid,
    input  wire        m_ip_payload_axis_tready,
    output wire        m_ip_payload_axis_tlast,
    output wire        m_ip_payload_axis_tuser,

    /*
     * Status
     */
    output wire rx_busy,
    output wire tx_busy,
    output wire rx_error_header_early_termination,
    output wire rx_error_payload_early_termination,
    output wire rx_error_invalid_header,
    output wire rx_error_invalid_checksum,
    output wire tx_error_payload_early_termination,
    output wire tx_error_arp_failed,

    /*
     * Configuration
     */
    input  wire [47:0] local_mac,
    input  wire [31:0] local_ip,
    input  wire [31:0] gateway_ip,
    input  wire [31:0] subnet_mask,
    input  wire        clear_arp_cache
);

/*

This module integrates the IP and ARP modules for a complete IP stack

*/

wire arp_request_valid;
wire arp_request_ready;
wire [31:0] arp_request_ip;
wire arp_response_valid;
wire arp_response_ready;
wire arp_response_error;
wire [47:0] arp_response_mac;

wire ip_rx_eth_hdr_valid;
wire ip_rx_eth_hdr_ready;
wire [47:0] ip_rx_eth_dest_mac;
wire [47:0] ip_rx_eth_src_mac;
wire [15:0] ip_rx_eth_type;
wire [7:0] ip_rx_eth_payload_axis_tdata;
wire ip_rx_eth_payload_axis_tvalid;
wire ip_rx_eth_payload_axis_tready;
wire ip_rx_eth_payload_axis_tlast;
wire ip_rx_eth_payload_axis_tuser;

wire ip_tx_eth_hdr_valid;
wire ip_tx_eth_hdr_ready;
wire [47:0] ip_tx_eth_dest_mac;
wire [47:0] ip_tx_eth_src_mac;
wire [15:0] ip_tx_eth_type;
wire [7:0] ip_tx_eth_payload_axis_tdata;
wire ip_tx_eth_payload_axis_tvalid;
wire ip_tx_eth_payload_axis_tready;
wire ip_tx_eth_payload_axis_tlast;
wire ip_tx_eth_payload_axis_tuser;

wire arp_rx_eth_hdr_valid;
wire arp_rx_eth_hdr_ready;
wire [47:0] arp_rx_eth_dest_mac;
wire [47:0] arp_rx_eth_src_mac;
wire [15:0] arp_rx_eth_type;
wire [7:0] arp_rx_eth_payload_axis_tdata;
wire arp_rx_eth_payload_axis_tvalid;
wire arp_rx_eth_payload_axis_tready;
wire arp_rx_eth_payload_axis_tlast;
wire arp_rx_eth_payload_axis_tuser;

wire arp_tx_eth_hdr_valid;
wire arp_tx_eth_hdr_ready;
wire [47:0] arp_tx_eth_dest_mac;
wire [47:0] arp_tx_eth_src_mac;
wire [15:0] arp_tx_eth_type;
wire [7:0] arp_tx_eth_payload_axis_tdata;
wire arp_tx_eth_payload_axis_tvalid;
wire arp_tx_eth_payload_axis_tready;
wire arp_tx_eth_payload_axis_tlast;
wire arp_tx_eth_payload_axis_tuser;

/*
 * Input classifier (eth_type)
 */
wire s_select_ip = (s_eth_type == 16'h0800);
wire s_select_arp = (s_eth_type == 16'h0806);
wire s_select_none = !(s_select_ip || s_select_arp);

reg s_select_ip_reg = 1'b0;
reg s_select_arp_reg = 1'b0;
reg s_select_none_reg = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        s_select_ip_reg <= 1'b0;
        s_select_arp_reg <= 1'b0;
        s_select_none_reg <= 1'b0;
    end else begin
        if (s_eth_payload_axis_tvalid) begin
            if ((!s_select_ip_reg && !s_select_arp_reg && !s_select_none_reg) ||
                (s_eth_payload_axis_tvalid && s_eth_payload_axis_tready && s_eth_payload_axis_tlast)) begin
                s_select_ip_reg <= s_select_ip;
                s_select_arp_reg <= s_select_arp;
                s_select_none_reg <= s_select_none;
            end
        end else begin
            s_select_ip_reg <= 1'b0;
            s_select_arp_reg <= 1'b0;
            s_select_none_reg <= 1'b0;
        end
    end
end

assign ip_rx_eth_hdr_valid = s_select_ip && s_eth_hdr_valid;
assign ip_rx_eth_dest_mac = s_eth_dest_mac;
assign ip_rx_eth_src_mac = s_eth_src_mac;
assign ip_rx_eth_type = 16'h0800;
assign ip_rx_eth_payload_axis_tdata = s_eth_payload_axis_tdata;
assign ip_rx_eth_payload_axis_tvalid = s_select_ip_reg && s_eth_payload_axis_tvalid;
assign ip_rx_eth_payload_axis_tlast = s_eth_payload_axis_tlast;
assign ip_rx_eth_payload_axis_tuser = s_eth_payload_axis_tuser;

assign arp_rx_eth_hdr_valid = s_select_arp && s_eth_hdr_valid;
assign arp_rx_eth_dest_mac = s_eth_dest_mac;
assign arp_rx_eth_src_mac = s_eth_src_mac;
assign arp_rx_eth_type = 16'h0806;
assign arp_rx_eth_payload_axis_tdata = s_eth_payload_axis_tdata;
assign arp_rx_eth_payload_axis_tvalid = s_select_arp_reg && s_eth_payload_axis_tvalid;
assign arp_rx_eth_payload_axis_tlast = s_eth_payload_axis_tlast;
assign arp_rx_eth_payload_axis_tuser = s_eth_payload_axis_tuser;

assign s_eth_hdr_ready = (s_select_ip && ip_rx_eth_hdr_ready) ||
                         (s_select_arp && arp_rx_eth_hdr_ready) ||
                         (s_select_none);

assign s_eth_payload_axis_tready = (s_select_ip_reg && ip_rx_eth_payload_axis_tready) ||
                                   (s_select_arp_reg && arp_rx_eth_payload_axis_tready) ||
                                   s_select_none_reg;

/*
 * Output arbiter
 */
eth_arb_mux #(
    .S_COUNT(2),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1)
)
eth_arb_mux_inst (
    .clk(clk),
    .rst(rst),
    // Ethernet frame inputs
    .s_eth_hdr_valid({ip_tx_eth_hdr_valid, arp_tx_eth_hdr_valid}),
    .s_eth_hdr_ready({ip_tx_eth_hdr_ready, arp_tx_eth_hdr_ready}),
    .s_eth_dest_mac({ip_tx_eth_dest_mac, arp_tx_eth_dest_mac}),
    .s_eth_src_mac({ip_tx_eth_src_mac, arp_tx_eth_src_mac}),
    .s_eth_type({ip_tx_eth_type, arp_tx_eth_type}),
    .s_eth_payload_axis_tdata({ip_tx_eth_payload_axis_tdata, arp_tx_eth_payload_axis_tdata}),
    .s_eth_payload_axis_tkeep(0),
    .s_eth_payload_axis_tvalid({ip_tx_eth_payload_axis_tvalid, arp_tx_eth_payload_axis_tvalid}),
    .s_eth_payload_axis_tready({ip_tx_eth_payload_axis_tready, arp_tx_eth_payload_axis_tready}),
    .s_eth_payload_axis_tlast({ip_tx_eth_payload_axis_tlast, arp_tx_eth_payload_axis_tlast}),
    .s_eth_payload_axis_tid(0),
    .s_eth_payload_axis_tdest(0),
    .s_eth_payload_axis_tuser({ip_tx_eth_payload_axis_tuser, arp_tx_eth_payload_axis_tuser}),
    // Ethernet frame output
    .m_eth_hdr_valid(m_eth_hdr_valid),
    .m_eth_hdr_ready(m_eth_hdr_ready),
    .m_eth_dest_mac(m_eth_dest_mac),
    .m_eth_src_mac(m_eth_src_mac),
    .m_eth_type(m_eth_type),
    .m_eth_payload_axis_tdata(m_eth_payload_axis_tdata),
    .m_eth_payload_axis_tkeep(),
    .m_eth_payload_axis_tvalid(m_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(m_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(m_eth_payload_axis_tlast),
    .m_eth_payload_axis_tid(),
    .m_eth_payload_axis_tdest(),
    .m_eth_payload_axis_tuser(m_eth_payload_axis_tuser)
);

/*
 * IP module
 */
ip
ip_inst (
    .clk(clk),
    .rst(rst),
    // Ethernet frame input
    .s_eth_hdr_valid(ip_rx_eth_hdr_valid),
    .s_eth_hdr_ready(ip_rx_eth_hdr_ready),
    .s_eth_dest_mac(ip_rx_eth_dest_mac),
    .s_eth_src_mac(ip_rx_eth_src_mac),
    .s_eth_type(ip_rx_eth_type),
    .s_eth_payload_axis_tdata(ip_rx_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(ip_rx_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(ip_rx_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(ip_rx_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(ip_rx_eth_payload_axis_tuser),
    // Ethernet frame output
    .m_eth_hdr_valid(ip_tx_eth_hdr_valid),
    .m_eth_hdr_ready(ip_tx_eth_hdr_ready),
    .m_eth_dest_mac(ip_tx_eth_dest_mac),
    .m_eth_src_mac(ip_tx_eth_src_mac),
    .m_eth_type(ip_tx_eth_type),
    .m_eth_payload_axis_tdata(ip_tx_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(ip_tx_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(ip_tx_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(ip_tx_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(ip_tx_eth_payload_axis_tuser),
    // IP frame output
    .m_ip_hdr_valid(m_ip_hdr_valid),
    .m_ip_hdr_ready(m_ip_hdr_ready),
    .m_ip_eth_dest_mac(m_ip_eth_dest_mac),
    .m_ip_eth_src_mac(m_ip_eth_src_mac),
    .m_ip_eth_type(m_ip_eth_type),
    .m_ip_version(m_ip_version),
    .m_ip_ihl(m_ip_ihl),
    .m_ip_dscp(m_ip_dscp),
    .m_ip_ecn(m_ip_ecn),
    .m_ip_length(m_ip_length),
    .m_ip_identification(m_ip_identification),
    .m_ip_flags(m_ip_flags),
    .m_ip_fragment_offset(m_ip_fragment_offset),
    .m_ip_ttl(m_ip_ttl),
    .m_ip_protocol(m_ip_protocol),
    .m_ip_header_checksum(m_ip_header_checksum),
    .m_ip_source_ip(m_ip_source_ip),
    .m_ip_dest_ip(m_ip_dest_ip),
    .m_ip_payload_axis_tdata(m_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(m_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(m_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(m_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(m_ip_payload_axis_tuser),
    // IP frame input
    .s_ip_hdr_valid(s_ip_hdr_valid),
    .s_ip_hdr_ready(s_ip_hdr_ready),
    .s_ip_dscp(s_ip_dscp),
    .s_ip_ecn(s_ip_ecn),
    .s_ip_length(s_ip_length),
    .s_ip_ttl(s_ip_ttl),
    .s_ip_protocol(s_ip_protocol),
    .s_ip_source_ip(s_ip_source_ip),
    .s_ip_dest_ip(s_ip_dest_ip),
    .s_ip_payload_axis_tdata(s_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(s_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(s_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(s_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(s_ip_payload_axis_tuser),
    // ARP requests
    .arp_request_valid(arp_request_valid),
    .arp_request_ready(arp_request_ready),
    .arp_request_ip(arp_request_ip),
    .arp_response_valid(arp_response_valid),
    .arp_response_ready(arp_response_ready),
    .arp_response_error(arp_response_error),
    .arp_response_mac(arp_response_mac),
    // Status
    .rx_busy(rx_busy),
    .tx_busy(tx_busy),
    .rx_error_header_early_termination(rx_error_header_early_termination),
    .rx_error_payload_early_termination(rx_error_payload_early_termination),
    .rx_error_invalid_header(rx_error_invalid_header),
    .rx_error_invalid_checksum(rx_error_invalid_checksum),
    .tx_error_payload_early_termination(tx_error_payload_early_termination),
    .tx_error_arp_failed(tx_error_arp_failed),
    // Configuration
    .local_mac(local_mac),
    .local_ip(local_ip)
);

/*
 * ARP module
 */
arp #(
    .CACHE_ADDR_WIDTH(ARP_CACHE_ADDR_WIDTH),
    .REQUEST_RETRY_COUNT(ARP_REQUEST_RETRY_COUNT),
    .REQUEST_RETRY_INTERVAL(ARP_REQUEST_RETRY_INTERVAL),
    .REQUEST_TIMEOUT(ARP_REQUEST_TIMEOUT)
)
arp_inst (
    .clk(clk),
    .rst(rst),
    // Ethernet frame input
    .s_eth_hdr_valid(arp_rx_eth_hdr_valid),
    .s_eth_hdr_ready(arp_rx_eth_hdr_ready),
    .s_eth_dest_mac(arp_rx_eth_dest_mac),
    .s_eth_src_mac(arp_rx_eth_src_mac),
    .s_eth_type(arp_rx_eth_type),
    .s_eth_payload_axis_tdata(arp_rx_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(arp_rx_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(arp_rx_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(arp_rx_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(arp_rx_eth_payload_axis_tuser),
    // Ethernet frame output
    .m_eth_hdr_valid(arp_tx_eth_hdr_valid),
    .m_eth_hdr_ready(arp_tx_eth_hdr_ready),
    .m_eth_dest_mac(arp_tx_eth_dest_mac),
    .m_eth_src_mac(arp_tx_eth_src_mac),
    .m_eth_type(arp_tx_eth_type),
    .m_eth_payload_axis_tdata(arp_tx_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(arp_tx_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(arp_tx_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(arp_tx_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(arp_tx_eth_payload_axis_tuser),
    // ARP requests
    .arp_request_valid(arp_request_valid),
    .arp_request_ready(arp_request_ready),
    .arp_request_ip(arp_request_ip),
    .arp_response_valid(arp_response_valid),
    .arp_response_ready(arp_response_ready),
    .arp_response_error(arp_response_error),
    .arp_response_mac(arp_response_mac),
    // Configuration
    .local_mac(local_mac),
    .local_ip(local_ip),
    .gateway_ip(gateway_ip),
    .subnet_mask(subnet_mask),
    .clear_cache(clear_arp_cache)
);

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/ip.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IPv4 block, ethernet frame interface
 */
module ip
(
    input  wire        clk,
    input  wire        rst,

    /*
     * Ethernet frame input
     */
    input  wire        s_eth_hdr_valid,
    output wire        s_eth_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [7:0]  s_eth_payload_axis_tdata,
    input  wire        s_eth_payload_axis_tvalid,
    output wire        s_eth_payload_axis_tready,
    input  wire        s_eth_payload_axis_tlast,
    input  wire        s_eth_payload_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire        m_eth_hdr_valid,
    input  wire        m_eth_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [7:0]  m_eth_payload_axis_tdata,
    output wire        m_eth_payload_axis_tvalid,
    input  wire        m_eth_payload_axis_tready,
    output wire        m_eth_payload_axis_tlast,
    output wire        m_eth_payload_axis_tuser,

    /*
     * ARP requests
     */
    output wire        arp_request_valid,
    input  wire        arp_request_ready,
    output wire [31:0] arp_request_ip,
    input  wire        arp_response_valid,
    output wire        arp_response_ready,
    input  wire        arp_response_error,
    input  wire [47:0] arp_response_mac,

    /*
     * IP input
     */
    input  wire        s_ip_hdr_valid,
    output wire        s_ip_hdr_ready,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [7:0]  s_ip_payload_axis_tdata,
    input  wire        s_ip_payload_axis_tvalid,
    output wire        s_ip_payload_axis_tready,
    input  wire        s_ip_payload_axis_tlast,
    input  wire        s_ip_payload_axis_tuser,

    /*
     * IP output
     */
    output wire        m_ip_hdr_valid,
    input  wire        m_ip_hdr_ready,
    output wire [47:0] m_ip_eth_dest_mac,
    output wire [47:0] m_ip_eth_src_mac,
    output wire [15:0] m_ip_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [7:0]  m_ip_payload_axis_tdata,
    output wire        m_ip_payload_axis_tvalid,
    input  wire        m_ip_payload_axis_tready,
    output wire        m_ip_payload_axis_tlast,
    output wire        m_ip_payload_axis_tuser,

    /*
     * Status
     */
    output wire rx_busy,
    output wire tx_busy,
    output wire rx_error_header_early_termination,
    output wire rx_error_payload_early_termination,
    output wire rx_error_invalid_header,
    output wire rx_error_invalid_checksum,
    output wire tx_error_payload_early_termination,
    output wire tx_error_arp_failed,

    /*
     * Configuration
     */
    input  wire [47:0] local_mac,
    input  wire [31:0] local_ip
);

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_ARP_QUERY = 2'd1,
    STATE_WAIT_PACKET = 2'd2;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg outgoing_ip_hdr_valid_reg = 1'b0, outgoing_ip_hdr_valid_next;
wire outgoing_ip_hdr_ready;
reg [47:0] outgoing_eth_dest_mac_reg = 48'h000000000000, outgoing_eth_dest_mac_next;
wire outgoing_ip_payload_axis_tready;

/*
 * IP frame processing
 */
ip_eth_rx
ip_eth_rx_inst (
    .clk(clk),
    .rst(rst),
    // Ethernet frame input
    .s_eth_hdr_valid(s_eth_hdr_valid),
    .s_eth_hdr_ready(s_eth_hdr_ready),
    .s_eth_dest_mac(s_eth_dest_mac),
    .s_eth_src_mac(s_eth_src_mac),
    .s_eth_type(s_eth_type),
    .s_eth_payload_axis_tdata(s_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(s_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(s_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(s_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(s_eth_payload_axis_tuser),
    // IP frame output
    .m_ip_hdr_valid(m_ip_hdr_valid),
    .m_ip_hdr_ready(m_ip_hdr_ready),
    .m_eth_dest_mac(m_ip_eth_dest_mac),
    .m_eth_src_mac(m_ip_eth_src_mac),
    .m_eth_type(m_ip_eth_type),
    .m_ip_version(m_ip_version),
    .m_ip_ihl(m_ip_ihl),
    .m_ip_dscp(m_ip_dscp),
    .m_ip_ecn(m_ip_ecn),
    .m_ip_length(m_ip_length),
    .m_ip_identification(m_ip_identification),
    .m_ip_flags(m_ip_flags),
    .m_ip_fragment_offset(m_ip_fragment_offset),
    .m_ip_ttl(m_ip_ttl),
    .m_ip_protocol(m_ip_protocol),
    .m_ip_header_checksum(m_ip_header_checksum),
    .m_ip_source_ip(m_ip_source_ip),
    .m_ip_dest_ip(m_ip_dest_ip),
    .m_ip_payload_axis_tdata(m_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(m_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(m_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(m_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(m_ip_payload_axis_tuser),
    // Status signals
    .busy(rx_busy),
    .error_header_early_termination(rx_error_header_early_termination),
    .error_payload_early_termination(rx_error_payload_early_termination),
    .error_invalid_header(rx_error_invalid_header),
    .error_invalid_checksum(rx_error_invalid_checksum)
);

ip_eth_tx
ip_eth_tx_inst (
    .clk(clk),
    .rst(rst),
    // IP frame input
    .s_ip_hdr_valid(outgoing_ip_hdr_valid_reg),
    .s_ip_hdr_ready(outgoing_ip_hdr_ready),
    .s_eth_dest_mac(outgoing_eth_dest_mac_reg),
    .s_eth_src_mac(local_mac),
    .s_eth_type(16'h0800),
    .s_ip_dscp(s_ip_dscp),
    .s_ip_ecn(s_ip_ecn),
    .s_ip_length(s_ip_length),
    .s_ip_identification(16'd0),
    .s_ip_flags(3'b010),
    .s_ip_fragment_offset(13'd0),
    .s_ip_ttl(s_ip_ttl),
    .s_ip_protocol(s_ip_protocol),
    .s_ip_source_ip(s_ip_source_ip),
    .s_ip_dest_ip(s_ip_dest_ip),
    .s_ip_payload_axis_tdata(s_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(s_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(outgoing_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(s_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(s_ip_payload_axis_tuser),
    // Ethernet frame output
    .m_eth_hdr_valid(m_eth_hdr_valid),
    .m_eth_hdr_ready(m_eth_hdr_ready),
    .m_eth_dest_mac(m_eth_dest_mac),
    .m_eth_src_mac(m_eth_src_mac),
    .m_eth_type(m_eth_type),
    .m_eth_payload_axis_tdata(m_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(m_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(m_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(m_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(m_eth_payload_axis_tuser),
    // Status signals
    .busy(tx_busy),
    .error_payload_early_termination(tx_error_payload_early_termination)
);

reg s_ip_hdr_ready_reg = 1'b0, s_ip_hdr_ready_next;

reg arp_request_valid_reg = 1'b0, arp_request_valid_next;

reg arp_response_ready_reg = 1'b0, arp_response_ready_next;

reg drop_packet_reg = 1'b0, drop_packet_next;

assign s_ip_hdr_ready = s_ip_hdr_ready_reg;
assign s_ip_payload_axis_tready = outgoing_ip_payload_axis_tready || drop_packet_reg;

assign arp_request_valid = arp_request_valid_reg;
assign arp_request_ip = s_ip_dest_ip;
assign arp_response_ready = arp_response_ready_reg;

assign tx_error_arp_failed = arp_response_error;

always @* begin
    state_next = STATE_IDLE;

    arp_request_valid_next = arp_request_valid_reg && !arp_request_ready;
    arp_response_ready_next = 1'b0;
    drop_packet_next = 1'b0;

    s_ip_hdr_ready_next = 1'b0;

    outgoing_ip_hdr_valid_next = outgoing_ip_hdr_valid_reg && !outgoing_ip_hdr_ready;
    outgoing_eth_dest_mac_next = outgoing_eth_dest_mac_reg;

    case (state_reg)
        STATE_IDLE: begin
            // wait for outgoing packet
            if (s_ip_hdr_valid) begin
                // initiate ARP request
                arp_request_valid_next = 1'b1;
                arp_response_ready_next = 1'b1;
                state_next = STATE_ARP_QUERY;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_ARP_QUERY: begin
            arp_response_ready_next = 1'b1;

            if (arp_response_valid) begin
                // wait for ARP reponse
                if (arp_response_error) begin
                    // did not get MAC address; drop packet
                    s_ip_hdr_ready_next = 1'b1;
                    drop_packet_next = 1'b1;
                    state_next = STATE_WAIT_PACKET;
                end else begin
                    // got MAC address; send packet
                    s_ip_hdr_ready_next = 1'b1;
                    outgoing_ip_hdr_valid_next = 1'b1;
                    outgoing_eth_dest_mac_next = arp_response_mac;
                    state_next = STATE_WAIT_PACKET;
                end
            end else begin
                state_next = STATE_ARP_QUERY;
            end
        end
        STATE_WAIT_PACKET: begin
            drop_packet_next = drop_packet_reg;

            // wait for packet transfer to complete
            if (s_ip_payload_axis_tlast && s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_WAIT_PACKET;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        arp_request_valid_reg <= 1'b0;
        arp_response_ready_reg <= 1'b0;
        drop_packet_reg <= 1'b0;
        s_ip_hdr_ready_reg <= 1'b0;
        outgoing_ip_hdr_valid_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        arp_request_valid_reg <= arp_request_valid_next;
        arp_response_ready_reg <= arp_response_ready_next;
        drop_packet_reg <= drop_packet_next;

        s_ip_hdr_ready_reg <= s_ip_hdr_ready_next;

        outgoing_ip_hdr_valid_reg <= outgoing_ip_hdr_valid_next;
    end

    outgoing_eth_dest_mac_reg <= outgoing_eth_dest_mac_next;
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/ip_eth_rx.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IP ethernet frame receiver (Ethernet frame in, IP frame out)
 */
module ip_eth_rx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * Ethernet frame input
     */
    input  wire        s_eth_hdr_valid,
    output wire        s_eth_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [7:0]  s_eth_payload_axis_tdata,
    input  wire        s_eth_payload_axis_tvalid,
    output wire        s_eth_payload_axis_tready,
    input  wire        s_eth_payload_axis_tlast,
    input  wire        s_eth_payload_axis_tuser,

    /*
     * IP frame output
     */
    output wire        m_ip_hdr_valid,
    input  wire        m_ip_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [7:0]  m_ip_payload_axis_tdata,
    output wire        m_ip_payload_axis_tvalid,
    input  wire        m_ip_payload_axis_tready,
    output wire        m_ip_payload_axis_tlast,
    output wire        m_ip_payload_axis_tuser,

    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_header_early_termination,
    output wire        error_payload_early_termination,
    output wire        error_invalid_header,
    output wire        error_invalid_checksum
);

/*

IP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets
 payload                     length octets

This module receives an Ethernet frame with header fields in parallel and
payload on an AXI stream interface, decodes and strips the IP header fields,
then produces the header fields in parallel along with the IP payload in a
separate AXI stream.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_READ_HEADER = 3'd1,
    STATE_READ_PAYLOAD = 3'd2,
    STATE_READ_PAYLOAD_LAST = 3'd3,
    STATE_WAIT_LAST = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_eth_hdr;
reg store_ip_version_ihl;
reg store_ip_dscp_ecn;
reg store_ip_length_0;
reg store_ip_length_1;
reg store_ip_identification_0;
reg store_ip_identification_1;
reg store_ip_flags_fragment_offset_0;
reg store_ip_flags_fragment_offset_1;
reg store_ip_ttl;
reg store_ip_protocol;
reg store_ip_header_checksum_0;
reg store_ip_header_checksum_1;
reg store_ip_source_ip_0;
reg store_ip_source_ip_1;
reg store_ip_source_ip_2;
reg store_ip_source_ip_3;
reg store_ip_dest_ip_0;
reg store_ip_dest_ip_1;
reg store_ip_dest_ip_2;
reg store_ip_dest_ip_3;
reg store_last_word;

reg [5:0] hdr_ptr_reg = 6'd0, hdr_ptr_next;
reg [15:0] word_count_reg = 16'd0, word_count_next;

reg [15:0] hdr_sum_reg = 16'd0, hdr_sum_next;

reg [7:0] last_word_data_reg = 8'd0;

reg s_eth_hdr_ready_reg = 1'b0, s_eth_hdr_ready_next;
reg s_eth_payload_axis_tready_reg = 1'b0, s_eth_payload_axis_tready_next;

reg m_ip_hdr_valid_reg = 1'b0, m_ip_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;
reg [3:0] m_ip_version_reg = 4'd0;
reg [3:0] m_ip_ihl_reg = 4'd0;
reg [5:0] m_ip_dscp_reg = 6'd0;
reg [1:0] m_ip_ecn_reg = 2'd0;
reg [15:0] m_ip_length_reg = 16'd0;
reg [15:0] m_ip_identification_reg = 16'd0;
reg [2:0] m_ip_flags_reg = 3'd0;
reg [12:0] m_ip_fragment_offset_reg = 13'd0;
reg [7:0] m_ip_ttl_reg = 8'd0;
reg [7:0] m_ip_protocol_reg = 8'd0;
reg [15:0] m_ip_header_checksum_reg = 16'd0;
reg [31:0] m_ip_source_ip_reg = 32'd0;
reg [31:0] m_ip_dest_ip_reg = 32'd0;

reg busy_reg = 1'b0;
reg error_header_early_termination_reg = 1'b0, error_header_early_termination_next;
reg error_payload_early_termination_reg = 1'b0, error_payload_early_termination_next;
reg error_invalid_header_reg = 1'b0, error_invalid_header_next;
reg error_invalid_checksum_reg = 1'b0, error_invalid_checksum_next;

// internal datapath
reg [7:0] m_ip_payload_axis_tdata_int;
reg       m_ip_payload_axis_tvalid_int;
reg       m_ip_payload_axis_tready_int_reg = 1'b0;
reg       m_ip_payload_axis_tlast_int;
reg       m_ip_payload_axis_tuser_int;
wire      m_ip_payload_axis_tready_int_early;

assign s_eth_hdr_ready = s_eth_hdr_ready_reg;
assign s_eth_payload_axis_tready = s_eth_payload_axis_tready_reg;

assign m_ip_hdr_valid = m_ip_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_ip_version = m_ip_version_reg;
assign m_ip_ihl = m_ip_ihl_reg;
assign m_ip_dscp = m_ip_dscp_reg;
assign m_ip_ecn = m_ip_ecn_reg;
assign m_ip_length = m_ip_length_reg;
assign m_ip_identification = m_ip_identification_reg;
assign m_ip_flags = m_ip_flags_reg;
assign m_ip_fragment_offset = m_ip_fragment_offset_reg;
assign m_ip_ttl = m_ip_ttl_reg;
assign m_ip_protocol = m_ip_protocol_reg;
assign m_ip_header_checksum = m_ip_header_checksum_reg;
assign m_ip_source_ip = m_ip_source_ip_reg;
assign m_ip_dest_ip = m_ip_dest_ip_reg;

assign busy = busy_reg;
assign error_header_early_termination = error_header_early_termination_reg;
assign error_payload_early_termination = error_payload_early_termination_reg;
assign error_invalid_header = error_invalid_header_reg;
assign error_invalid_checksum = error_invalid_checksum_reg;

function [15:0] add1c16b;
    input [15:0] a, b;
    reg [16:0] t;
    begin
        t = a+b;
        add1c16b = t[15:0] + t[16];
    end
endfunction

always @* begin
    state_next = STATE_IDLE;

    s_eth_hdr_ready_next = 1'b0;
    s_eth_payload_axis_tready_next = 1'b0;

    store_eth_hdr = 1'b0;
    store_ip_version_ihl = 1'b0;
    store_ip_dscp_ecn = 1'b0;
    store_ip_length_0 = 1'b0;
    store_ip_length_1 = 1'b0;
    store_ip_identification_0 = 1'b0;
    store_ip_identification_1 = 1'b0;
    store_ip_flags_fragment_offset_0 = 1'b0;
    store_ip_flags_fragment_offset_1 = 1'b0;
    store_ip_ttl = 1'b0;
    store_ip_protocol = 1'b0;
    store_ip_header_checksum_0 = 1'b0;
    store_ip_header_checksum_1 = 1'b0;
    store_ip_source_ip_0 = 1'b0;
    store_ip_source_ip_1 = 1'b0;
    store_ip_source_ip_2 = 1'b0;
    store_ip_source_ip_3 = 1'b0;
    store_ip_dest_ip_0 = 1'b0;
    store_ip_dest_ip_1 = 1'b0;
    store_ip_dest_ip_2 = 1'b0;
    store_ip_dest_ip_3 = 1'b0;

    store_last_word = 1'b0;

    hdr_ptr_next = hdr_ptr_reg;
    word_count_next = word_count_reg;

    hdr_sum_next = hdr_sum_reg;

    m_ip_hdr_valid_next = m_ip_hdr_valid_reg && !m_ip_hdr_ready;

    error_header_early_termination_next = 1'b0;
    error_payload_early_termination_next = 1'b0;
    error_invalid_header_next = 1'b0;
    error_invalid_checksum_next = 1'b0;

    m_ip_payload_axis_tdata_int = 8'd0;
    m_ip_payload_axis_tvalid_int = 1'b0;
    m_ip_payload_axis_tlast_int = 1'b0;
    m_ip_payload_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for header
            hdr_ptr_next = 16'd0;
            hdr_sum_next = 16'd0;
            s_eth_hdr_ready_next = !m_ip_hdr_valid_next;

            if (s_eth_hdr_ready && s_eth_hdr_valid) begin
                s_eth_hdr_ready_next = 1'b0;
                s_eth_payload_axis_tready_next = 1'b1;
                store_eth_hdr = 1'b1;
                state_next = STATE_READ_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ_HEADER: begin
            // read header
            s_eth_payload_axis_tready_next = 1'b1;
            word_count_next = m_ip_length_reg - 5*4;

            if (s_eth_payload_axis_tready && s_eth_payload_axis_tvalid) begin
                // word transfer in - store it
                hdr_ptr_next = hdr_ptr_reg + 6'd1;
                state_next = STATE_READ_HEADER;

                if (hdr_ptr_reg[0]) begin
                    hdr_sum_next = add1c16b(hdr_sum_reg, {8'd0, s_eth_payload_axis_tdata});
                end else begin
                    hdr_sum_next = add1c16b(hdr_sum_reg, {s_eth_payload_axis_tdata, 8'd0});
                end

                case (hdr_ptr_reg)
                    6'h00: store_ip_version_ihl = 1'b1;
                    6'h01: store_ip_dscp_ecn = 1'b1;
                    6'h02: store_ip_length_1 = 1'b1;
                    6'h03: store_ip_length_0 = 1'b1;
                    6'h04: store_ip_identification_1 = 1'b1;
                    6'h05: store_ip_identification_0 = 1'b1;
                    6'h06: store_ip_flags_fragment_offset_1 = 1'b1;
                    6'h07: store_ip_flags_fragment_offset_0 = 1'b1;
                    6'h08: store_ip_ttl = 1'b1;
                    6'h09: store_ip_protocol = 1'b1;
                    6'h0A: store_ip_header_checksum_1 = 1'b1;
                    6'h0B: store_ip_header_checksum_0 = 1'b1;
                    6'h0C: store_ip_source_ip_3 = 1'b1;
                    6'h0D: store_ip_source_ip_2 = 1'b1;
                    6'h0E: store_ip_source_ip_1 = 1'b1;
                    6'h0F: store_ip_source_ip_0 = 1'b1;
                    6'h10: store_ip_dest_ip_3 = 1'b1;
                    6'h11: store_ip_dest_ip_2 = 1'b1;
                    6'h12: store_ip_dest_ip_1 = 1'b1;
                    6'h13: begin
                        store_ip_dest_ip_0 = 1'b1;
                        if (m_ip_version_reg != 4'd4 || m_ip_ihl_reg != 4'd5) begin
                            error_invalid_header_next = 1'b1;
                            state_next = STATE_WAIT_LAST;
                        end else if (hdr_sum_next != 16'hffff) begin
                            error_invalid_checksum_next = 1'b1;
                            state_next = STATE_WAIT_LAST;
                        end else begin
                            m_ip_hdr_valid_next = 1'b1;
                            s_eth_payload_axis_tready_next = m_ip_payload_axis_tready_int_early;
                            state_next = STATE_READ_PAYLOAD;
                        end
                    end
                endcase

                if (s_eth_payload_axis_tlast) begin
                    error_header_early_termination_next = 1'b1;
                    m_ip_hdr_valid_next = 1'b0;
                    s_eth_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_eth_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end

            end else begin
                state_next = STATE_READ_HEADER;
            end
        end
        STATE_READ_PAYLOAD: begin
            // read payload
            s_eth_payload_axis_tready_next = m_ip_payload_axis_tready_int_early;

            m_ip_payload_axis_tdata_int = s_eth_payload_axis_tdata;
            m_ip_payload_axis_tlast_int = s_eth_payload_axis_tlast;
            m_ip_payload_axis_tuser_int = s_eth_payload_axis_tuser;

            if (s_eth_payload_axis_tready && s_eth_payload_axis_tvalid) begin
                // word transfer through
                word_count_next = word_count_reg - 16'd1;
                m_ip_payload_axis_tvalid_int = 1'b1;
                if (s_eth_payload_axis_tlast) begin
                    if (word_count_reg > 16'd1) begin
                        // end of frame, but length does not match
                        m_ip_payload_axis_tuser_int = 1'b1;
                        error_payload_early_termination_next = 1'b1;
                    end
                    s_eth_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_eth_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    if (word_count_reg == 16'd1) begin
                        store_last_word = 1'b1;
                        m_ip_payload_axis_tvalid_int = 1'b0;
                        state_next = STATE_READ_PAYLOAD_LAST;
                    end else begin
                        state_next = STATE_READ_PAYLOAD;
                    end
                end
            end else begin
                state_next = STATE_READ_PAYLOAD;
            end
        end
        STATE_READ_PAYLOAD_LAST: begin
            // read and discard until end of frame
            s_eth_payload_axis_tready_next = m_ip_payload_axis_tready_int_early;

            m_ip_payload_axis_tdata_int = last_word_data_reg;
            m_ip_payload_axis_tlast_int = s_eth_payload_axis_tlast;
            m_ip_payload_axis_tuser_int = s_eth_payload_axis_tuser;

            if (s_eth_payload_axis_tready && s_eth_payload_axis_tvalid) begin
                if (s_eth_payload_axis_tlast) begin
                    s_eth_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_eth_payload_axis_tready_next = 1'b0;
                    m_ip_payload_axis_tvalid_int = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_READ_PAYLOAD_LAST;
                end
            end else begin
                state_next = STATE_READ_PAYLOAD_LAST;
            end
        end
        STATE_WAIT_LAST: begin
            // read and discard until end of frame
            s_eth_payload_axis_tready_next = 1'b1;

            if (s_eth_payload_axis_tready && s_eth_payload_axis_tvalid) begin
                if (s_eth_payload_axis_tlast) begin
                    s_eth_hdr_ready_next = !m_ip_hdr_valid_next;
                    s_eth_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end else begin
                state_next = STATE_WAIT_LAST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_eth_hdr_ready_reg <= 1'b0;
        s_eth_payload_axis_tready_reg <= 1'b0;
        m_ip_hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_header_early_termination_reg <= 1'b0;
        error_payload_early_termination_reg <= 1'b0;
        error_invalid_header_reg <= 1'b0;
        error_invalid_checksum_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        s_eth_hdr_ready_reg <= s_eth_hdr_ready_next;
        s_eth_payload_axis_tready_reg <= s_eth_payload_axis_tready_next;

        m_ip_hdr_valid_reg <= m_ip_hdr_valid_next;

        error_header_early_termination_reg <= error_header_early_termination_next;
        error_payload_early_termination_reg <= error_payload_early_termination_next;
        error_invalid_header_reg <= error_invalid_header_next;
        error_invalid_checksum_reg <= error_invalid_checksum_next;

        busy_reg <= state_next != STATE_IDLE;
    end

    hdr_ptr_reg <= hdr_ptr_next;
    word_count_reg <= word_count_next;

    hdr_sum_reg <= hdr_sum_next;

    // datapath
    if (store_eth_hdr) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
    end

    if (store_last_word) begin
        last_word_data_reg <= m_ip_payload_axis_tdata_int;
    end

    if (store_ip_version_ihl) {m_ip_version_reg, m_ip_ihl_reg} <= s_eth_payload_axis_tdata;
    if (store_ip_dscp_ecn) {m_ip_dscp_reg, m_ip_ecn_reg} <= s_eth_payload_axis_tdata;
    if (store_ip_length_0) m_ip_length_reg[ 7: 0] <= s_eth_payload_axis_tdata;
    if (store_ip_length_1) m_ip_length_reg[15: 8] <= s_eth_payload_axis_tdata;
    if (store_ip_identification_0) m_ip_identification_reg[ 7: 0] <= s_eth_payload_axis_tdata;
    if (store_ip_identification_1) m_ip_identification_reg[15: 8] <= s_eth_payload_axis_tdata;
    if (store_ip_flags_fragment_offset_0) m_ip_fragment_offset_reg[ 7:0] <= s_eth_payload_axis_tdata;
    if (store_ip_flags_fragment_offset_1) {m_ip_flags_reg, m_ip_fragment_offset_reg[12:8]} <= s_eth_payload_axis_tdata;
    if (store_ip_ttl) m_ip_ttl_reg <= s_eth_payload_axis_tdata;
    if (store_ip_protocol) m_ip_protocol_reg <= s_eth_payload_axis_tdata;
    if (store_ip_header_checksum_0) m_ip_header_checksum_reg[ 7: 0] <= s_eth_payload_axis_tdata;
    if (store_ip_header_checksum_1) m_ip_header_checksum_reg[15: 8] <= s_eth_payload_axis_tdata;
    if (store_ip_source_ip_0) m_ip_source_ip_reg[ 7: 0] <= s_eth_payload_axis_tdata;
    if (store_ip_source_ip_1) m_ip_source_ip_reg[15: 8] <= s_eth_payload_axis_tdata;
    if (store_ip_source_ip_2) m_ip_source_ip_reg[23:16] <= s_eth_payload_axis_tdata;
    if (store_ip_source_ip_3) m_ip_source_ip_reg[31:24] <= s_eth_payload_axis_tdata;
    if (store_ip_dest_ip_0) m_ip_dest_ip_reg[ 7: 0] <= s_eth_payload_axis_tdata;
    if (store_ip_dest_ip_1) m_ip_dest_ip_reg[15: 8] <= s_eth_payload_axis_tdata;
    if (store_ip_dest_ip_2) m_ip_dest_ip_reg[23:16] <= s_eth_payload_axis_tdata;
    if (store_ip_dest_ip_3) m_ip_dest_ip_reg[31:24] <= s_eth_payload_axis_tdata;
end

// output datapath logic
reg [7:0] m_ip_payload_axis_tdata_reg = 8'd0;
reg       m_ip_payload_axis_tvalid_reg = 1'b0, m_ip_payload_axis_tvalid_next;
reg       m_ip_payload_axis_tlast_reg = 1'b0;
reg       m_ip_payload_axis_tuser_reg = 1'b0;

reg [7:0] temp_m_ip_payload_axis_tdata_reg = 8'd0;
reg       temp_m_ip_payload_axis_tvalid_reg = 1'b0, temp_m_ip_payload_axis_tvalid_next;
reg       temp_m_ip_payload_axis_tlast_reg = 1'b0;
reg       temp_m_ip_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_ip_payload_int_to_output;
reg store_ip_payload_int_to_temp;
reg store_ip_payload_axis_temp_to_output;

assign m_ip_payload_axis_tdata = m_ip_payload_axis_tdata_reg;
assign m_ip_payload_axis_tvalid = m_ip_payload_axis_tvalid_reg;
assign m_ip_payload_axis_tlast = m_ip_payload_axis_tlast_reg;
assign m_ip_payload_axis_tuser = m_ip_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_ip_payload_axis_tready_int_early = m_ip_payload_axis_tready || (!temp_m_ip_payload_axis_tvalid_reg && !m_ip_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_reg;
    temp_m_ip_payload_axis_tvalid_next = temp_m_ip_payload_axis_tvalid_reg;

    store_ip_payload_int_to_output = 1'b0;
    store_ip_payload_int_to_temp = 1'b0;
    store_ip_payload_axis_temp_to_output = 1'b0;
    
    if (m_ip_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_ip_payload_axis_tready || !m_ip_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_int;
            store_ip_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_int;
            store_ip_payload_int_to_temp = 1'b1;
        end
    end else if (m_ip_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_ip_payload_axis_tvalid_next = temp_m_ip_payload_axis_tvalid_reg;
        temp_m_ip_payload_axis_tvalid_next = 1'b0;
        store_ip_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_ip_payload_axis_tvalid_reg <= m_ip_payload_axis_tvalid_next;
    m_ip_payload_axis_tready_int_reg <= m_ip_payload_axis_tready_int_early;
    temp_m_ip_payload_axis_tvalid_reg <= temp_m_ip_payload_axis_tvalid_next;

    // datapath
    if (store_ip_payload_int_to_output) begin
        m_ip_payload_axis_tdata_reg <= m_ip_payload_axis_tdata_int;
        m_ip_payload_axis_tlast_reg <= m_ip_payload_axis_tlast_int;
        m_ip_payload_axis_tuser_reg <= m_ip_payload_axis_tuser_int;
    end else if (store_ip_payload_axis_temp_to_output) begin
        m_ip_payload_axis_tdata_reg <= temp_m_ip_payload_axis_tdata_reg;
        m_ip_payload_axis_tlast_reg <= temp_m_ip_payload_axis_tlast_reg;
        m_ip_payload_axis_tuser_reg <= temp_m_ip_payload_axis_tuser_reg;
    end

    if (store_ip_payload_int_to_temp) begin
        temp_m_ip_payload_axis_tdata_reg <= m_ip_payload_axis_tdata_int;
        temp_m_ip_payload_axis_tlast_reg <= m_ip_payload_axis_tlast_int;
        temp_m_ip_payload_axis_tuser_reg <= m_ip_payload_axis_tuser_int;
    end

    if (rst) begin
        m_ip_payload_axis_tvalid_reg <= 1'b0;
        m_ip_payload_axis_tready_int_reg <= 1'b0;
        temp_m_ip_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/ip_eth_tx.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IP ethernet frame transmitter (IP frame in, Ethernet frame out)
 */
module ip_eth_tx
(
    input  wire        clk,
    input  wire        rst,

    /*
     * IP frame input
     */
    input  wire        s_ip_hdr_valid,
    output wire        s_ip_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [15:0] s_ip_identification,
    input  wire [2:0]  s_ip_flags,
    input  wire [12:0] s_ip_fragment_offset,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [7:0]  s_ip_payload_axis_tdata,
    input  wire        s_ip_payload_axis_tvalid,
    output wire        s_ip_payload_axis_tready,
    input  wire        s_ip_payload_axis_tlast,
    input  wire        s_ip_payload_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire        m_eth_hdr_valid,
    input  wire        m_eth_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [7:0]  m_eth_payload_axis_tdata,
    output wire        m_eth_payload_axis_tvalid,
    input  wire        m_eth_payload_axis_tready,
    output wire        m_eth_payload_axis_tlast,
    output wire        m_eth_payload_axis_tuser,

    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_payload_early_termination
);

/*

IP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets
 payload                     length octets

This module receives an IP frame with header fields in parallel along with the
payload in an AXI stream, combines the header with the payload, passes through
the Ethernet headers, and transmits the complete Ethernet payload on an AXI
interface.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_WRITE_HEADER = 3'd1,
    STATE_WRITE_PAYLOAD = 3'd2,
    STATE_WRITE_PAYLOAD_LAST = 3'd3,
    STATE_WAIT_LAST = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_ip_hdr;
reg store_last_word;

reg [5:0] hdr_ptr_reg = 6'd0, hdr_ptr_next;
reg [15:0] word_count_reg = 16'd0, word_count_next;

reg [15:0] hdr_sum_reg = 16'd0, hdr_sum_next;

reg [7:0] last_word_data_reg = 8'd0;

reg [5:0] ip_dscp_reg = 6'd0;
reg [1:0] ip_ecn_reg = 2'd0;
reg [15:0] ip_length_reg = 16'd0;
reg [15:0] ip_identification_reg = 16'd0;
reg [2:0] ip_flags_reg = 3'd0;
reg [12:0] ip_fragment_offset_reg = 13'd0;
reg [7:0] ip_ttl_reg = 8'd0;
reg [7:0] ip_protocol_reg = 8'd0;
reg [31:0] ip_source_ip_reg = 32'd0;
reg [31:0] ip_dest_ip_reg = 32'd0;

reg s_ip_hdr_ready_reg = 1'b0, s_ip_hdr_ready_next;
reg s_ip_payload_axis_tready_reg = 1'b0, s_ip_payload_axis_tready_next;

reg m_eth_hdr_valid_reg = 1'b0, m_eth_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;

reg busy_reg = 1'b0;
reg error_payload_early_termination_reg = 1'b0, error_payload_early_termination_next;

// internal datapath
reg [7:0] m_eth_payload_axis_tdata_int;
reg       m_eth_payload_axis_tvalid_int;
reg       m_eth_payload_axis_tready_int_reg = 1'b0;
reg       m_eth_payload_axis_tlast_int;
reg       m_eth_payload_axis_tuser_int;
wire      m_eth_payload_axis_tready_int_early;

assign s_ip_hdr_ready = s_ip_hdr_ready_reg;
assign s_ip_payload_axis_tready = s_ip_payload_axis_tready_reg;

assign m_eth_hdr_valid = m_eth_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;

assign busy = busy_reg;
assign error_payload_early_termination = error_payload_early_termination_reg;

function [15:0] add1c16b;
    input [15:0] a, b;
    reg [16:0] t;
    begin
        t = a+b;
        add1c16b = t[15:0] + t[16];
    end
endfunction

always @* begin
    state_next = STATE_IDLE;

    s_ip_hdr_ready_next = 1'b0;
    s_ip_payload_axis_tready_next = 1'b0;

    store_ip_hdr = 1'b0;

    store_last_word = 1'b0;

    hdr_ptr_next = hdr_ptr_reg;
    word_count_next = word_count_reg;

    hdr_sum_next = hdr_sum_reg;

    m_eth_hdr_valid_next = m_eth_hdr_valid_reg && !m_eth_hdr_ready;

    error_payload_early_termination_next = 1'b0;

    m_eth_payload_axis_tdata_int = 8'd0;
    m_eth_payload_axis_tvalid_int = 1'b0;
    m_eth_payload_axis_tlast_int = 1'b0;
    m_eth_payload_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for data
            hdr_ptr_next = 6'd0;
            s_ip_hdr_ready_next = !m_eth_hdr_valid_next;

            if (s_ip_hdr_ready && s_ip_hdr_valid) begin
                store_ip_hdr = 1'b1;
                s_ip_hdr_ready_next = 1'b0;
                m_eth_hdr_valid_next = 1'b1;
                if (m_eth_payload_axis_tready_int_reg) begin
                    m_eth_payload_axis_tvalid_int = 1'b1;
                    m_eth_payload_axis_tdata_int = {4'd4, 4'd5}; // ip_version, ip_ihl
                    hdr_ptr_next = 6'd1;
                end
                state_next = STATE_WRITE_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_WRITE_HEADER: begin
            // write header
            word_count_next = ip_length_reg - 5*4;

            if (m_eth_payload_axis_tready_int_reg) begin
                hdr_ptr_next = hdr_ptr_reg + 6'd1;
                m_eth_payload_axis_tvalid_int = 1;
                state_next = STATE_WRITE_HEADER;
                case (hdr_ptr_reg)
                    6'h00: begin
                        m_eth_payload_axis_tdata_int = {4'd4, 4'd5}; // ip_version, ip_ihl
                    end
                    6'h01: begin
                        m_eth_payload_axis_tdata_int = {ip_dscp_reg, ip_ecn_reg};
                        hdr_sum_next = {4'd4, 4'd5, ip_dscp_reg, ip_ecn_reg};
                    end
                    6'h02: begin
                        m_eth_payload_axis_tdata_int = ip_length_reg[15: 8];
                        hdr_sum_next = add1c16b(hdr_sum_reg, ip_length_reg);
                    end
                    6'h03: begin
                        m_eth_payload_axis_tdata_int = ip_length_reg[ 7: 0];
                        hdr_sum_next = add1c16b(hdr_sum_reg, ip_identification_reg);
                    end
                    6'h04: begin
                        m_eth_payload_axis_tdata_int = ip_identification_reg[15: 8];
                        hdr_sum_next = add1c16b(hdr_sum_reg, {ip_flags_reg, ip_fragment_offset_reg});
                    end
                    6'h05: begin
                        m_eth_payload_axis_tdata_int = ip_identification_reg[ 7: 0];
                        hdr_sum_next = add1c16b(hdr_sum_reg, {ip_ttl_reg, ip_protocol_reg});
                    end
                    6'h06: begin
                        m_eth_payload_axis_tdata_int = {ip_flags_reg, ip_fragment_offset_reg[12:8]};
                        hdr_sum_next = add1c16b(hdr_sum_reg, ip_source_ip_reg[31:16]);
                    end
                    6'h07: begin
                        m_eth_payload_axis_tdata_int = ip_fragment_offset_reg[ 7: 0];
                        hdr_sum_next = add1c16b(hdr_sum_reg, ip_source_ip_reg[15:0]);
                    end
                    6'h08: begin
                        m_eth_payload_axis_tdata_int = ip_ttl_reg;
                        hdr_sum_next = add1c16b(hdr_sum_reg, ip_dest_ip_reg[31:16]);
                    end
                    6'h09: begin
                        m_eth_payload_axis_tdata_int = ip_protocol_reg;
                        hdr_sum_next = add1c16b(hdr_sum_reg, ip_dest_ip_reg[15:0]);
                    end
                    6'h0A: m_eth_payload_axis_tdata_int = ~hdr_sum_reg[15: 8];
                    6'h0B: m_eth_payload_axis_tdata_int = ~hdr_sum_reg[ 7: 0];
                    6'h0C: m_eth_payload_axis_tdata_int = ip_source_ip_reg[31:24];
                    6'h0D: m_eth_payload_axis_tdata_int = ip_source_ip_reg[23:16];
                    6'h0E: m_eth_payload_axis_tdata_int = ip_source_ip_reg[15: 8];
                    6'h0F: m_eth_payload_axis_tdata_int = ip_source_ip_reg[ 7: 0];
                    6'h10: m_eth_payload_axis_tdata_int = ip_dest_ip_reg[31:24];
                    6'h11: m_eth_payload_axis_tdata_int = ip_dest_ip_reg[23:16];
                    6'h12: m_eth_payload_axis_tdata_int = ip_dest_ip_reg[15: 8];
                    6'h13: begin
                        m_eth_payload_axis_tdata_int = ip_dest_ip_reg[ 7: 0];
                        s_ip_payload_axis_tready_next = m_eth_payload_axis_tready_int_early;
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                endcase
            end else begin
                state_next = STATE_WRITE_HEADER;
            end
        end
        STATE_WRITE_PAYLOAD: begin
            // write payload
            s_ip_payload_axis_tready_next = m_eth_payload_axis_tready_int_early;

            m_eth_payload_axis_tdata_int = s_ip_payload_axis_tdata;
            m_eth_payload_axis_tlast_int = s_ip_payload_axis_tlast;
            m_eth_payload_axis_tuser_int = s_ip_payload_axis_tuser;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                // word transfer through
                word_count_next = word_count_reg - 6'd1;
                m_eth_payload_axis_tvalid_int = 1'b1;
                if (s_ip_payload_axis_tlast) begin
                    if (word_count_reg != 16'd1) begin
                        // end of frame, but length does not match
                        m_eth_payload_axis_tuser_int = 1'b1;
                        error_payload_early_termination_next = 1'b1;
                    end
                    s_ip_hdr_ready_next = !m_eth_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    if (word_count_reg == 16'd1) begin
                        store_last_word = 1'b1;
                        m_eth_payload_axis_tvalid_int = 1'b0;
                        state_next = STATE_WRITE_PAYLOAD_LAST;
                    end else begin
                        state_next = STATE_WRITE_PAYLOAD;
                    end
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD;
            end
        end
        STATE_WRITE_PAYLOAD_LAST: begin
            // read and discard until end of frame
            s_ip_payload_axis_tready_next = m_eth_payload_axis_tready_int_early;

            m_eth_payload_axis_tdata_int = last_word_data_reg;
            m_eth_payload_axis_tlast_int = s_ip_payload_axis_tlast;
            m_eth_payload_axis_tuser_int = s_ip_payload_axis_tuser;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                if (s_ip_payload_axis_tlast) begin
                    s_ip_hdr_ready_next = !m_eth_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    m_eth_payload_axis_tvalid_int = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WRITE_PAYLOAD_LAST;
                end
            end else begin
                state_next = STATE_WRITE_PAYLOAD_LAST;
            end
        end
        STATE_WAIT_LAST: begin
            // read and discard until end of frame
            s_ip_payload_axis_tready_next = 1'b1;

            if (s_ip_payload_axis_tready && s_ip_payload_axis_tvalid) begin
                if (s_ip_payload_axis_tlast) begin
                    s_ip_hdr_ready_next = !m_eth_hdr_valid_next;
                    s_ip_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end else begin
                state_next = STATE_WAIT_LAST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_ip_hdr_ready_reg <= 1'b0;
        s_ip_payload_axis_tready_reg <= 1'b0;
        m_eth_hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_payload_early_termination_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        s_ip_hdr_ready_reg <= s_ip_hdr_ready_next;
        s_ip_payload_axis_tready_reg <= s_ip_payload_axis_tready_next;

        m_eth_hdr_valid_reg <= m_eth_hdr_valid_next;

        busy_reg <= state_next != STATE_IDLE;

        error_payload_early_termination_reg <= error_payload_early_termination_next;
    end

    hdr_ptr_reg <= hdr_ptr_next;
    word_count_reg <= word_count_next;

    hdr_sum_reg <= hdr_sum_next;

    // datapath
    if (store_ip_hdr) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
        ip_dscp_reg <= s_ip_dscp;
        ip_ecn_reg <= s_ip_ecn;
        ip_length_reg <= s_ip_length;
        ip_identification_reg <= s_ip_identification;
        ip_flags_reg <= s_ip_flags;
        ip_fragment_offset_reg <= s_ip_fragment_offset;
        ip_ttl_reg <= s_ip_ttl;
        ip_protocol_reg <= s_ip_protocol;
        ip_source_ip_reg <= s_ip_source_ip;
        ip_dest_ip_reg <= s_ip_dest_ip;
    end

    if (store_last_word) begin
        last_word_data_reg <= m_eth_payload_axis_tdata_int;
    end
end

// output datapath logic
reg [7:0] m_eth_payload_axis_tdata_reg = 8'd0;
reg       m_eth_payload_axis_tvalid_reg = 1'b0, m_eth_payload_axis_tvalid_next;
reg       m_eth_payload_axis_tlast_reg = 1'b0;
reg       m_eth_payload_axis_tuser_reg = 1'b0;

reg [7:0] temp_m_eth_payload_axis_tdata_reg = 8'd0;
reg       temp_m_eth_payload_axis_tvalid_reg = 1'b0, temp_m_eth_payload_axis_tvalid_next;
reg       temp_m_eth_payload_axis_tlast_reg = 1'b0;
reg       temp_m_eth_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_eth_payload_int_to_output;
reg store_eth_payload_int_to_temp;
reg store_eth_payload_axis_temp_to_output;

assign m_eth_payload_axis_tdata = m_eth_payload_axis_tdata_reg;
assign m_eth_payload_axis_tvalid = m_eth_payload_axis_tvalid_reg;
assign m_eth_payload_axis_tlast = m_eth_payload_axis_tlast_reg;
assign m_eth_payload_axis_tuser = m_eth_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_eth_payload_axis_tready_int_early = m_eth_payload_axis_tready || (!temp_m_eth_payload_axis_tvalid_reg && !m_eth_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_reg;
    temp_m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;

    store_eth_payload_int_to_output = 1'b0;
    store_eth_payload_int_to_temp = 1'b0;
    store_eth_payload_axis_temp_to_output = 1'b0;
    
    if (m_eth_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_eth_payload_axis_tready || !m_eth_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_eth_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_eth_payload_int_to_temp = 1'b1;
        end
    end else if (m_eth_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;
        temp_m_eth_payload_axis_tvalid_next = 1'b0;
        store_eth_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_eth_payload_axis_tvalid_reg <= m_eth_payload_axis_tvalid_next;
    m_eth_payload_axis_tready_int_reg <= m_eth_payload_axis_tready_int_early;
    temp_m_eth_payload_axis_tvalid_reg <= temp_m_eth_payload_axis_tvalid_next;

    // datapath
    if (store_eth_payload_int_to_output) begin
        m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end else if (store_eth_payload_axis_temp_to_output) begin
        m_eth_payload_axis_tdata_reg <= temp_m_eth_payload_axis_tdata_reg;
        m_eth_payload_axis_tlast_reg <= temp_m_eth_payload_axis_tlast_reg;
        m_eth_payload_axis_tuser_reg <= temp_m_eth_payload_axis_tuser_reg;
    end

    if (store_eth_payload_int_to_temp) begin
        temp_m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        temp_m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        temp_m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end

    if (rst) begin
        m_eth_payload_axis_tvalid_reg <= 1'b0;
        m_eth_payload_axis_tready_int_reg <= 1'b0;
        temp_m_eth_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/ip_arb_mux.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * IP arbitrated multiplexer
 */
module ip_arb_mux #
(
    parameter S_COUNT = 4,
    parameter DATA_WIDTH = 8,
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter USER_ENABLE = 1,
    parameter USER_WIDTH = 1,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * IP frame inputs
     */
    input  wire [S_COUNT-1:0]            s_ip_hdr_valid,
    output wire [S_COUNT-1:0]            s_ip_hdr_ready,
    input  wire [S_COUNT*48-1:0]         s_eth_dest_mac,
    input  wire [S_COUNT*48-1:0]         s_eth_src_mac,
    input  wire [S_COUNT*16-1:0]         s_eth_type,
    input  wire [S_COUNT*4-1:0]          s_ip_version,
    input  wire [S_COUNT*4-1:0]          s_ip_ihl,
    input  wire [S_COUNT*6-1:0]          s_ip_dscp,
    input  wire [S_COUNT*2-1:0]          s_ip_ecn,
    input  wire [S_COUNT*16-1:0]         s_ip_length,
    input  wire [S_COUNT*16-1:0]         s_ip_identification,
    input  wire [S_COUNT*3-1:0]          s_ip_flags,
    input  wire [S_COUNT*13-1:0]         s_ip_fragment_offset,
    input  wire [S_COUNT*8-1:0]          s_ip_ttl,
    input  wire [S_COUNT*8-1:0]          s_ip_protocol,
    input  wire [S_COUNT*16-1:0]         s_ip_header_checksum,
    input  wire [S_COUNT*32-1:0]         s_ip_source_ip,
    input  wire [S_COUNT*32-1:0]         s_ip_dest_ip,
    input  wire [S_COUNT*DATA_WIDTH-1:0] s_ip_payload_axis_tdata,
    input  wire [S_COUNT*KEEP_WIDTH-1:0] s_ip_payload_axis_tkeep,
    input  wire [S_COUNT-1:0]            s_ip_payload_axis_tvalid,
    output wire [S_COUNT-1:0]            s_ip_payload_axis_tready,
    input  wire [S_COUNT-1:0]            s_ip_payload_axis_tlast,
    input  wire [S_COUNT*ID_WIDTH-1:0]   s_ip_payload_axis_tid,
    input  wire [S_COUNT*DEST_WIDTH-1:0] s_ip_payload_axis_tdest,
    input  wire [S_COUNT*USER_WIDTH-1:0] s_ip_payload_axis_tuser,

    /*
     * IP frame output
     */
    output wire                          m_ip_hdr_valid,
    input  wire                          m_ip_hdr_ready,
    output wire [47:0]                   m_eth_dest_mac,
    output wire [47:0]                   m_eth_src_mac,
    output wire [15:0]                   m_eth_type,
    output wire [3:0]                    m_ip_version,
    output wire [3:0]                    m_ip_ihl,
    output wire [5:0]                    m_ip_dscp,
    output wire [1:0]                    m_ip_ecn,
    output wire [15:0]                   m_ip_length,
    output wire [15:0]                   m_ip_identification,
    output wire [2:0]                    m_ip_flags,
    output wire [12:0]                   m_ip_fragment_offset,
    output wire [7:0]                    m_ip_ttl,
    output wire [7:0]                    m_ip_protocol,
    output wire [15:0]                   m_ip_header_checksum,
    output wire [31:0]                   m_ip_source_ip,
    output wire [31:0]                   m_ip_dest_ip,
    output wire [DATA_WIDTH-1:0]         m_ip_payload_axis_tdata,
    output wire [KEEP_WIDTH-1:0]         m_ip_payload_axis_tkeep,
    output wire                          m_ip_payload_axis_tvalid,
    input  wire                          m_ip_payload_axis_tready,
    output wire                          m_ip_payload_axis_tlast,
    output wire [ID_WIDTH-1:0]           m_ip_payload_axis_tid,
    output wire [DEST_WIDTH-1:0]         m_ip_payload_axis_tdest,
    output wire [USER_WIDTH-1:0]         m_ip_payload_axis_tuser
);

parameter CL_S_COUNT = $clog2(S_COUNT);

reg frame_reg = 1'b0, frame_next;

reg [S_COUNT-1:0] s_ip_hdr_ready_reg = {S_COUNT{1'b0}}, s_ip_hdr_ready_next;

reg m_ip_hdr_valid_reg = 1'b0, m_ip_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0, m_eth_dest_mac_next;
reg [47:0] m_eth_src_mac_reg = 48'd0, m_eth_src_mac_next;
reg [15:0] m_eth_type_reg = 16'd0, m_eth_type_next;
reg [3:0]  m_ip_version_reg = 4'd0, m_ip_version_next;
reg [3:0]  m_ip_ihl_reg = 4'd0, m_ip_ihl_next;
reg [5:0]  m_ip_dscp_reg = 6'd0, m_ip_dscp_next;
reg [1:0]  m_ip_ecn_reg = 2'd0, m_ip_ecn_next;
reg [15:0] m_ip_length_reg = 16'd0, m_ip_length_next;
reg [15:0] m_ip_identification_reg = 16'd0, m_ip_identification_next;
reg [2:0]  m_ip_flags_reg = 3'd0, m_ip_flags_next;
reg [12:0] m_ip_fragment_offset_reg = 13'd0, m_ip_fragment_offset_next;
reg [7:0]  m_ip_ttl_reg = 8'd0, m_ip_ttl_next;
reg [7:0]  m_ip_protocol_reg = 8'd0, m_ip_protocol_next;
reg [15:0] m_ip_header_checksum_reg = 16'd0, m_ip_header_checksum_next;
reg [31:0] m_ip_source_ip_reg = 32'd0, m_ip_source_ip_next;
reg [31:0] m_ip_dest_ip_reg = 32'd0, m_ip_dest_ip_next;

wire [S_COUNT-1:0] request;
wire [S_COUNT-1:0] acknowledge;
wire [S_COUNT-1:0] grant;
wire grant_valid;
wire [CL_S_COUNT-1:0] grant_encoded;

// internal datapath
reg  [DATA_WIDTH-1:0] m_ip_payload_axis_tdata_int;
reg  [KEEP_WIDTH-1:0] m_ip_payload_axis_tkeep_int;
reg                   m_ip_payload_axis_tvalid_int;
reg                   m_ip_payload_axis_tready_int_reg = 1'b0;
reg                   m_ip_payload_axis_tlast_int;
reg  [ID_WIDTH-1:0]   m_ip_payload_axis_tid_int;
reg  [DEST_WIDTH-1:0] m_ip_payload_axis_tdest_int;
reg  [USER_WIDTH-1:0] m_ip_payload_axis_tuser_int;
wire                  m_ip_payload_axis_tready_int_early;

assign s_ip_hdr_ready = s_ip_hdr_ready_reg;

assign s_ip_payload_axis_tready = (m_ip_payload_axis_tready_int_reg && grant_valid) << grant_encoded;

assign m_ip_hdr_valid = m_ip_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_ip_version = m_ip_version_reg;
assign m_ip_ihl = m_ip_ihl_reg;
assign m_ip_dscp = m_ip_dscp_reg;
assign m_ip_ecn = m_ip_ecn_reg;
assign m_ip_length = m_ip_length_reg;
assign m_ip_identification = m_ip_identification_reg;
assign m_ip_flags = m_ip_flags_reg;
assign m_ip_fragment_offset = m_ip_fragment_offset_reg;
assign m_ip_ttl = m_ip_ttl_reg;
assign m_ip_protocol = m_ip_protocol_reg;
assign m_ip_header_checksum = m_ip_header_checksum_reg;
assign m_ip_source_ip = m_ip_source_ip_reg;
assign m_ip_dest_ip = m_ip_dest_ip_reg;

// mux for incoming packet
wire [DATA_WIDTH-1:0] current_s_tdata  = s_ip_payload_axis_tdata[grant_encoded*DATA_WIDTH +: DATA_WIDTH];
wire [KEEP_WIDTH-1:0] current_s_tkeep  = s_ip_payload_axis_tkeep[grant_encoded*KEEP_WIDTH +: KEEP_WIDTH];
wire                  current_s_tvalid = s_ip_payload_axis_tvalid[grant_encoded];
wire                  current_s_tready = s_ip_payload_axis_tready[grant_encoded];
wire                  current_s_tlast  = s_ip_payload_axis_tlast[grant_encoded];
wire [ID_WIDTH-1:0]   current_s_tid    = s_ip_payload_axis_tid[grant_encoded*ID_WIDTH +: ID_WIDTH];
wire [DEST_WIDTH-1:0] current_s_tdest  = s_ip_payload_axis_tdest[grant_encoded*DEST_WIDTH +: DEST_WIDTH];
wire [USER_WIDTH-1:0] current_s_tuser  = s_ip_payload_axis_tuser[grant_encoded*USER_WIDTH +: USER_WIDTH];

// arbiter instance
arbiter #(
    .PORTS(S_COUNT),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
arb_inst (
    .clk(clk),
    .rst(rst),
    .request(request),
    .acknowledge(acknowledge),
    .grant(grant),
    .grant_valid(grant_valid),
    .grant_encoded(grant_encoded)
);

assign request = s_ip_hdr_valid & ~grant;
assign acknowledge = grant & s_ip_payload_axis_tvalid & s_ip_payload_axis_tready & s_ip_payload_axis_tlast;

always @* begin
    frame_next = frame_reg;

    s_ip_hdr_ready_next = {S_COUNT{1'b0}};

    m_ip_hdr_valid_next = m_ip_hdr_valid_reg && !m_ip_hdr_ready;
    m_eth_dest_mac_next = m_eth_dest_mac_reg;
    m_eth_src_mac_next = m_eth_src_mac_reg;
    m_eth_type_next = m_eth_type_reg;
    m_ip_version_next = m_ip_version_reg;
    m_ip_ihl_next = m_ip_ihl_reg;
    m_ip_dscp_next = m_ip_dscp_reg;
    m_ip_ecn_next = m_ip_ecn_reg;
    m_ip_length_next = m_ip_length_reg;
    m_ip_identification_next = m_ip_identification_reg;
    m_ip_flags_next = m_ip_flags_reg;
    m_ip_fragment_offset_next = m_ip_fragment_offset_reg;
    m_ip_ttl_next = m_ip_ttl_reg;
    m_ip_protocol_next = m_ip_protocol_reg;
    m_ip_header_checksum_next = m_ip_header_checksum_reg;
    m_ip_source_ip_next = m_ip_source_ip_reg;
    m_ip_dest_ip_next = m_ip_dest_ip_reg;

    if (s_ip_payload_axis_tvalid[grant_encoded] && s_ip_payload_axis_tready[grant_encoded]) begin
        // end of frame detection
        if (s_ip_payload_axis_tlast[grant_encoded]) begin
            frame_next = 1'b0;
        end
    end

    if (!frame_reg && grant_valid && (m_ip_hdr_ready || !m_ip_hdr_valid)) begin
        // start of frame
        frame_next = 1'b1;

        s_ip_hdr_ready_next = grant;

        m_ip_hdr_valid_next = 1'b1;
        m_eth_dest_mac_next = s_eth_dest_mac[grant_encoded*48 +: 48];
        m_eth_src_mac_next = s_eth_src_mac[grant_encoded*48 +: 48];
        m_eth_type_next = s_eth_type[grant_encoded*16 +: 16];
        m_ip_version_next = s_ip_version[grant_encoded*4 +: 4];
        m_ip_ihl_next = s_ip_ihl[grant_encoded*4 +: 4];
        m_ip_dscp_next = s_ip_dscp[grant_encoded*6 +: 6];
        m_ip_ecn_next = s_ip_ecn[grant_encoded*2 +: 2];
        m_ip_length_next = s_ip_length[grant_encoded*16 +: 16];
        m_ip_identification_next = s_ip_identification[grant_encoded*16 +: 16];
        m_ip_flags_next = s_ip_flags[grant_encoded*3 +: 3];
        m_ip_fragment_offset_next = s_ip_fragment_offset[grant_encoded*13 +: 13];
        m_ip_ttl_next = s_ip_ttl[grant_encoded*8 +: 8];
        m_ip_protocol_next = s_ip_protocol[grant_encoded*8 +: 8];
        m_ip_header_checksum_next = s_ip_header_checksum[grant_encoded*16 +: 16];
        m_ip_source_ip_next = s_ip_source_ip[grant_encoded*32 +: 32];
        m_ip_dest_ip_next = s_ip_dest_ip[grant_encoded*32 +: 32];
    end

    // pass through selected packet data
    m_ip_payload_axis_tdata_int  = current_s_tdata;
    m_ip_payload_axis_tkeep_int  = current_s_tkeep;
    m_ip_payload_axis_tvalid_int = current_s_tvalid && m_ip_payload_axis_tready_int_reg && grant_valid;
    m_ip_payload_axis_tlast_int  = current_s_tlast;
    m_ip_payload_axis_tid_int    = current_s_tid;
    m_ip_payload_axis_tdest_int  = current_s_tdest;
    m_ip_payload_axis_tuser_int  = current_s_tuser;
end

always @(posedge clk) begin
    frame_reg <= frame_next;

    s_ip_hdr_ready_reg <= s_ip_hdr_ready_next;

    m_ip_hdr_valid_reg <= m_ip_hdr_valid_next;
    m_eth_dest_mac_reg <= m_eth_dest_mac_next;
    m_eth_src_mac_reg <= m_eth_src_mac_next;
    m_eth_type_reg <= m_eth_type_next;
    m_ip_version_reg <= m_ip_version_next;
    m_ip_ihl_reg <= m_ip_ihl_next;
    m_ip_dscp_reg <= m_ip_dscp_next;
    m_ip_ecn_reg <= m_ip_ecn_next;
    m_ip_length_reg <= m_ip_length_next;
    m_ip_identification_reg <= m_ip_identification_next;
    m_ip_flags_reg <= m_ip_flags_next;
    m_ip_fragment_offset_reg <= m_ip_fragment_offset_next;
    m_ip_ttl_reg <= m_ip_ttl_next;
    m_ip_protocol_reg <= m_ip_protocol_next;
    m_ip_header_checksum_reg <= m_ip_header_checksum_next;
    m_ip_source_ip_reg <= m_ip_source_ip_next;
    m_ip_dest_ip_reg <= m_ip_dest_ip_next;

    if (rst) begin
        frame_reg <= 1'b0;
        s_ip_hdr_ready_reg <= {S_COUNT{1'b0}};
        m_ip_hdr_valid_reg <= 1'b0;
    end
end

// output datapath logic
reg [DATA_WIDTH-1:0] m_ip_payload_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] m_ip_payload_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
reg                  m_ip_payload_axis_tvalid_reg = 1'b0, m_ip_payload_axis_tvalid_next;
reg                  m_ip_payload_axis_tlast_reg  = 1'b0;
reg [ID_WIDTH-1:0]   m_ip_payload_axis_tid_reg    = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0] m_ip_payload_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0] m_ip_payload_axis_tuser_reg  = {USER_WIDTH{1'b0}};

reg [DATA_WIDTH-1:0] temp_m_ip_payload_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] temp_m_ip_payload_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
reg                  temp_m_ip_payload_axis_tvalid_reg = 1'b0, temp_m_ip_payload_axis_tvalid_next;
reg                  temp_m_ip_payload_axis_tlast_reg  = 1'b0;
reg [ID_WIDTH-1:0]   temp_m_ip_payload_axis_tid_reg    = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0] temp_m_ip_payload_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0] temp_m_ip_payload_axis_tuser_reg  = {USER_WIDTH{1'b0}};

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_ip_payload_axis_temp_to_output;

assign m_ip_payload_axis_tdata  = m_ip_payload_axis_tdata_reg;
assign m_ip_payload_axis_tkeep  = KEEP_ENABLE ? m_ip_payload_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
assign m_ip_payload_axis_tvalid = m_ip_payload_axis_tvalid_reg;
assign m_ip_payload_axis_tlast  = m_ip_payload_axis_tlast_reg;
assign m_ip_payload_axis_tid    = ID_ENABLE   ? m_ip_payload_axis_tid_reg   : {ID_WIDTH{1'b0}};
assign m_ip_payload_axis_tdest  = DEST_ENABLE ? m_ip_payload_axis_tdest_reg : {DEST_WIDTH{1'b0}};
assign m_ip_payload_axis_tuser  = USER_ENABLE ? m_ip_payload_axis_tuser_reg : {USER_WIDTH{1'b0}};

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_ip_payload_axis_tready_int_early = m_ip_payload_axis_tready || (!temp_m_ip_payload_axis_tvalid_reg && !m_ip_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_reg;
    temp_m_ip_payload_axis_tvalid_next = temp_m_ip_payload_axis_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_ip_payload_axis_temp_to_output = 1'b0;

    if (m_ip_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_ip_payload_axis_tready || !m_ip_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_ip_payload_axis_tvalid_next = m_ip_payload_axis_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_ip_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_ip_payload_axis_tvalid_next = temp_m_ip_payload_axis_tvalid_reg;
        temp_m_ip_payload_axis_tvalid_next = 1'b0;
        store_ip_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_ip_payload_axis_tvalid_reg <= m_ip_payload_axis_tvalid_next;
    m_ip_payload_axis_tready_int_reg <= m_ip_payload_axis_tready_int_early;
    temp_m_ip_payload_axis_tvalid_reg <= temp_m_ip_payload_axis_tvalid_next;

    // datapath
    if (store_axis_int_to_output) begin
        m_ip_payload_axis_tdata_reg <= m_ip_payload_axis_tdata_int;
        m_ip_payload_axis_tkeep_reg <= m_ip_payload_axis_tkeep_int;
        m_ip_payload_axis_tlast_reg <= m_ip_payload_axis_tlast_int;
        m_ip_payload_axis_tid_reg   <= m_ip_payload_axis_tid_int;
        m_ip_payload_axis_tdest_reg <= m_ip_payload_axis_tdest_int;
        m_ip_payload_axis_tuser_reg <= m_ip_payload_axis_tuser_int;
    end else if (store_ip_payload_axis_temp_to_output) begin
        m_ip_payload_axis_tdata_reg <= temp_m_ip_payload_axis_tdata_reg;
        m_ip_payload_axis_tkeep_reg <= temp_m_ip_payload_axis_tkeep_reg;
        m_ip_payload_axis_tlast_reg <= temp_m_ip_payload_axis_tlast_reg;
        m_ip_payload_axis_tid_reg   <= temp_m_ip_payload_axis_tid_reg;
        m_ip_payload_axis_tdest_reg <= temp_m_ip_payload_axis_tdest_reg;
        m_ip_payload_axis_tuser_reg <= temp_m_ip_payload_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_ip_payload_axis_tdata_reg <= m_ip_payload_axis_tdata_int;
        temp_m_ip_payload_axis_tkeep_reg <= m_ip_payload_axis_tkeep_int;
        temp_m_ip_payload_axis_tlast_reg <= m_ip_payload_axis_tlast_int;
        temp_m_ip_payload_axis_tid_reg   <= m_ip_payload_axis_tid_int;
        temp_m_ip_payload_axis_tdest_reg <= m_ip_payload_axis_tdest_int;
        temp_m_ip_payload_axis_tuser_reg <= m_ip_payload_axis_tuser_int;
    end

    if (rst) begin
        m_ip_payload_axis_tvalid_reg <= 1'b0;
        m_ip_payload_axis_tready_int_reg <= 1'b0;
        temp_m_ip_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/arp.v ===== */
/*

Copyright (c) 2014-2020 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * ARP block for IPv4, ethernet frame interface
 */
module arp #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    // Log2 of ARP cache size
    parameter CACHE_ADDR_WIDTH = 9,
    // ARP request retry count
    parameter REQUEST_RETRY_COUNT = 4,
    // ARP request retry interval (in cycles)
    parameter REQUEST_RETRY_INTERVAL = 125000000*2,
    // ARP request timeout (in cycles)
    parameter REQUEST_TIMEOUT = 125000000*30
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * Ethernet frame input
     */
    input  wire                   s_eth_hdr_valid,
    output wire                   s_eth_hdr_ready,
    input  wire [47:0]            s_eth_dest_mac,
    input  wire [47:0]            s_eth_src_mac,
    input  wire [15:0]            s_eth_type,
    input  wire [DATA_WIDTH-1:0]  s_eth_payload_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_eth_payload_axis_tkeep,
    input  wire                   s_eth_payload_axis_tvalid,
    output wire                   s_eth_payload_axis_tready,
    input  wire                   s_eth_payload_axis_tlast,
    input  wire                   s_eth_payload_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire                   m_eth_hdr_valid,
    input  wire                   m_eth_hdr_ready,
    output wire [47:0]            m_eth_dest_mac,
    output wire [47:0]            m_eth_src_mac,
    output wire [15:0]            m_eth_type,
    output wire [DATA_WIDTH-1:0]  m_eth_payload_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_eth_payload_axis_tkeep,
    output wire                   m_eth_payload_axis_tvalid,
    input  wire                   m_eth_payload_axis_tready,
    output wire                   m_eth_payload_axis_tlast,
    output wire                   m_eth_payload_axis_tuser,

    /*
     * ARP requests
     */
    input  wire                   arp_request_valid,
    output wire                   arp_request_ready,
    input  wire [31:0]            arp_request_ip,
    output wire                   arp_response_valid,
    input  wire                   arp_response_ready,
    output wire                   arp_response_error,
    output wire [47:0]            arp_response_mac,

    /*
     * Configuration
     */
    input  wire [47:0]            local_mac,
    input  wire [31:0]            local_ip,
    input  wire [31:0]            gateway_ip,
    input  wire [31:0]            subnet_mask,
    input  wire                   clear_cache
);

localparam [15:0]
    ARP_OPER_ARP_REQUEST = 16'h0001,
    ARP_OPER_ARP_REPLY = 16'h0002,
    ARP_OPER_INARP_REQUEST = 16'h0008,
    ARP_OPER_INARP_REPLY = 16'h0009;

wire incoming_frame_valid;
reg incoming_frame_ready;
wire [47:0] incoming_eth_dest_mac;
wire [47:0] incoming_eth_src_mac;
wire [15:0] incoming_eth_type;
wire [15:0] incoming_arp_htype;
wire [15:0] incoming_arp_ptype;
wire [7:0]  incoming_arp_hlen;
wire [7:0]  incoming_arp_plen;
wire [15:0] incoming_arp_oper;
wire [47:0] incoming_arp_sha;
wire [31:0] incoming_arp_spa;
wire [47:0] incoming_arp_tha;
wire [31:0] incoming_arp_tpa;

/*
 * ARP frame processing
 */
arp_eth_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(KEEP_ENABLE),
    .KEEP_WIDTH(KEEP_WIDTH)
)
arp_eth_rx_inst (
    .clk(clk),
    .rst(rst),
    // Ethernet frame input
    .s_eth_hdr_valid(s_eth_hdr_valid),
    .s_eth_hdr_ready(s_eth_hdr_ready),
    .s_eth_dest_mac(s_eth_dest_mac),
    .s_eth_src_mac(s_eth_src_mac),
    .s_eth_type(s_eth_type),
    .s_eth_payload_axis_tdata(s_eth_payload_axis_tdata),
    .s_eth_payload_axis_tkeep(s_eth_payload_axis_tkeep),
    .s_eth_payload_axis_tvalid(s_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(s_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(s_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(s_eth_payload_axis_tuser),
    // ARP frame output
    .m_frame_valid(incoming_frame_valid),
    .m_frame_ready(incoming_frame_ready),
    .m_eth_dest_mac(incoming_eth_dest_mac),
    .m_eth_src_mac(incoming_eth_src_mac),
    .m_eth_type(incoming_eth_type),
    .m_arp_htype(incoming_arp_htype),
    .m_arp_ptype(incoming_arp_ptype),
    .m_arp_hlen(incoming_arp_hlen),
    .m_arp_plen(incoming_arp_plen),
    .m_arp_oper(incoming_arp_oper),
    .m_arp_sha(incoming_arp_sha),
    .m_arp_spa(incoming_arp_spa),
    .m_arp_tha(incoming_arp_tha),
    .m_arp_tpa(incoming_arp_tpa),
    // Status signals
    .busy(),
    .error_header_early_termination(),
    .error_invalid_header()
);

reg outgoing_frame_valid_reg = 1'b0, outgoing_frame_valid_next;
wire outgoing_frame_ready;
reg [47:0] outgoing_eth_dest_mac_reg = 48'd0, outgoing_eth_dest_mac_next;
reg [15:0] outgoing_arp_oper_reg = 16'd0, outgoing_arp_oper_next;
reg [47:0] outgoing_arp_tha_reg = 48'd0, outgoing_arp_tha_next;
reg [31:0] outgoing_arp_tpa_reg = 32'd0, outgoing_arp_tpa_next;

arp_eth_tx #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(KEEP_ENABLE),
    .KEEP_WIDTH(KEEP_WIDTH)
)
arp_eth_tx_inst (
    .clk(clk),
    .rst(rst),
    // ARP frame input
    .s_frame_valid(outgoing_frame_valid_reg),
    .s_frame_ready(outgoing_frame_ready),
    .s_eth_dest_mac(outgoing_eth_dest_mac_reg),
    .s_eth_src_mac(local_mac),
    .s_eth_type(16'h0806),
    .s_arp_htype(16'h0001),
    .s_arp_ptype(16'h0800),
    .s_arp_oper(outgoing_arp_oper_reg),
    .s_arp_sha(local_mac),
    .s_arp_spa(local_ip),
    .s_arp_tha(outgoing_arp_tha_reg),
    .s_arp_tpa(outgoing_arp_tpa_reg),
    // Ethernet frame output
    .m_eth_hdr_valid(m_eth_hdr_valid),
    .m_eth_hdr_ready(m_eth_hdr_ready),
    .m_eth_dest_mac(m_eth_dest_mac),
    .m_eth_src_mac(m_eth_src_mac),
    .m_eth_type(m_eth_type),
    .m_eth_payload_axis_tdata(m_eth_payload_axis_tdata),
    .m_eth_payload_axis_tkeep(m_eth_payload_axis_tkeep),
    .m_eth_payload_axis_tvalid(m_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(m_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(m_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(m_eth_payload_axis_tuser),
    // Status signals
    .busy()
);

reg cache_query_request_valid_reg = 1'b0, cache_query_request_valid_next;
reg [31:0] cache_query_request_ip_reg = 32'd0, cache_query_request_ip_next;
wire cache_query_response_valid;
wire cache_query_response_error;
wire [47:0] cache_query_response_mac;

reg cache_write_request_valid_reg = 1'b0, cache_write_request_valid_next;
reg [31:0] cache_write_request_ip_reg = 32'd0, cache_write_request_ip_next;
reg [47:0] cache_write_request_mac_reg = 48'd0, cache_write_request_mac_next;

/*
 * ARP cache
 */
arp_cache #(
    .CACHE_ADDR_WIDTH(CACHE_ADDR_WIDTH)
)
arp_cache_inst (
    .clk(clk),
    .rst(rst),
    // Query cache
    .query_request_valid(cache_query_request_valid_reg),
    .query_request_ready(),
    .query_request_ip(cache_query_request_ip_reg),
    .query_response_valid(cache_query_response_valid),
    .query_response_ready(1'b1),
    .query_response_error(cache_query_response_error),
    .query_response_mac(cache_query_response_mac),
    // Write cache
    .write_request_valid(cache_write_request_valid_reg),
    .write_request_ready(),
    .write_request_ip(cache_write_request_ip_reg),
    .write_request_mac(cache_write_request_mac_reg),
    // Configuration
    .clear_cache(clear_cache)
);

reg arp_request_operation_reg = 1'b0, arp_request_operation_next;

reg arp_request_ready_reg = 1'b0, arp_request_ready_next;
reg [31:0] arp_request_ip_reg = 32'd0, arp_request_ip_next;

reg arp_response_valid_reg = 1'b0, arp_response_valid_next;
reg arp_response_error_reg = 1'b0, arp_response_error_next;
reg [47:0] arp_response_mac_reg = 48'd0, arp_response_mac_next;

reg [5:0] arp_request_retry_cnt_reg = 6'd0, arp_request_retry_cnt_next;
reg [35:0] arp_request_timer_reg = 36'd0, arp_request_timer_next;

assign arp_request_ready = arp_request_ready_reg;

assign arp_response_valid = arp_response_valid_reg;
assign arp_response_error = arp_response_error_reg;
assign arp_response_mac = arp_response_mac_reg;

always @* begin
    incoming_frame_ready = 1'b0;

    outgoing_frame_valid_next = outgoing_frame_valid_reg && !outgoing_frame_ready;
    outgoing_eth_dest_mac_next = outgoing_eth_dest_mac_reg;
    outgoing_arp_oper_next = outgoing_arp_oper_reg;
    outgoing_arp_tha_next = outgoing_arp_tha_reg;
    outgoing_arp_tpa_next = outgoing_arp_tpa_reg;

    cache_query_request_valid_next = 1'b0;
    cache_query_request_ip_next = cache_query_request_ip_reg;

    cache_write_request_valid_next = 1'b0;
    cache_write_request_mac_next = cache_write_request_mac_reg;
    cache_write_request_ip_next = cache_write_request_ip_reg;

    arp_request_ready_next = 1'b0;
    arp_request_ip_next = arp_request_ip_reg;
    arp_request_operation_next = arp_request_operation_reg;
    arp_request_retry_cnt_next = arp_request_retry_cnt_reg;
    arp_request_timer_next = arp_request_timer_reg;
    arp_response_valid_next = arp_response_valid_reg && !arp_response_ready;
    arp_response_error_next = 1'b0;
    arp_response_mac_next = 48'd0;

    // manage incoming frames
    incoming_frame_ready = outgoing_frame_ready;
    if (incoming_frame_valid && incoming_frame_ready) begin
        if (incoming_eth_type == 16'h0806 && incoming_arp_htype == 16'h0001 && incoming_arp_ptype == 16'h0800) begin
            // store sender addresses in cache
            cache_write_request_valid_next = 1'b1;
            cache_write_request_ip_next = incoming_arp_spa;
            cache_write_request_mac_next = incoming_arp_sha;
            if (incoming_arp_oper == ARP_OPER_ARP_REQUEST) begin
                // ARP request
                if (incoming_arp_tpa == local_ip) begin
                    // send reply frame to valid incoming request
                    outgoing_frame_valid_next = 1'b1;
                    outgoing_eth_dest_mac_next = incoming_eth_src_mac;
                    outgoing_arp_oper_next = ARP_OPER_ARP_REPLY;
                    outgoing_arp_tha_next = incoming_arp_sha;
                    outgoing_arp_tpa_next = incoming_arp_spa;
                end
            end else if (incoming_arp_oper == ARP_OPER_INARP_REQUEST) begin
                // INARP request
                if (incoming_arp_tha == local_mac) begin
                    // send reply frame to valid incoming request
                    outgoing_frame_valid_next = 1'b1;
                    outgoing_eth_dest_mac_next = incoming_eth_src_mac;
                    outgoing_arp_oper_next = ARP_OPER_INARP_REPLY;
                    outgoing_arp_tha_next = incoming_arp_sha;
                    outgoing_arp_tpa_next = incoming_arp_spa;
                end 
            end
        end
    end

    // manage ARP lookup requests
    if (arp_request_operation_reg) begin
        arp_request_ready_next = 1'b0;
        cache_query_request_valid_next = 1'b1;
        arp_request_timer_next = arp_request_timer_reg - 1;
        // if we got a response, it will go in the cache, so when the query succeds, we're done
        if (cache_query_response_valid && !cache_query_response_error) begin
            arp_request_operation_next = 1'b0;
            cache_query_request_valid_next = 1'b0;
            arp_response_valid_next = 1'b1;
            arp_response_error_next = 1'b0;
            arp_response_mac_next = cache_query_response_mac;
        end
        // timer timeout
        if (arp_request_timer_reg == 0) begin
            if (arp_request_retry_cnt_reg > 0) begin
                // have more retries
                // send ARP request frame
                outgoing_frame_valid_next = 1'b1;
                outgoing_eth_dest_mac_next = 48'hffffffffffff;
                outgoing_arp_oper_next = ARP_OPER_ARP_REQUEST;
                outgoing_arp_tha_next = 48'h000000000000;
                outgoing_arp_tpa_next = arp_request_ip_reg;
                arp_request_retry_cnt_next = arp_request_retry_cnt_reg - 1;
                if (arp_request_retry_cnt_reg > 1) begin
                    arp_request_timer_next = REQUEST_RETRY_INTERVAL;
                end else begin
                    arp_request_timer_next = REQUEST_TIMEOUT;
                end
            end else begin
                // out of retries
                arp_request_operation_next = 1'b0;
                arp_response_valid_next = 1'b1;
                arp_response_error_next = 1'b1;
                cache_query_request_valid_next = 1'b0;
            end
        end
    end else begin
        arp_request_ready_next = !arp_response_valid_next;
        if (cache_query_request_valid_reg) begin
            cache_query_request_valid_next = 1'b1;
            if (cache_query_response_valid) begin
                if (cache_query_response_error) begin
                    arp_request_operation_next = 1'b1;
                    // send ARP request frame
                    outgoing_frame_valid_next = 1'b1;
                    outgoing_eth_dest_mac_next = 48'hffffffffffff;
                    outgoing_arp_oper_next = ARP_OPER_ARP_REQUEST;
                    outgoing_arp_tha_next = 48'h000000000000;
                    outgoing_arp_tpa_next = arp_request_ip_reg;
                    arp_request_retry_cnt_next = REQUEST_RETRY_COUNT-1;
                    arp_request_timer_next = REQUEST_RETRY_INTERVAL;
                end else begin
                    cache_query_request_valid_next = 1'b0;
                    arp_response_valid_next = 1'b1;
                    arp_response_error_next = 1'b0;
                    arp_response_mac_next = cache_query_response_mac;
                end
            end
        end else if (arp_request_valid && arp_request_ready) begin
            if (arp_request_ip == 32'hffffffff) begin
                // broadcast address; use broadcast MAC address
                arp_response_valid_next = 1'b1;
                arp_response_error_next = 1'b0;
                arp_response_mac_next = 48'hffffffffffff;
            end else if (((arp_request_ip ^ gateway_ip) & subnet_mask) == 0) begin
                // within subnet
                // (no bits differ between request IP and gateway IP where subnet mask is set)
                if (~(arp_request_ip | subnet_mask) == 0) begin
                    // broadcast address; use broadcast MAC address
                    // (all bits in request IP set where subnet mask is clear)
                    arp_response_valid_next = 1'b1;
                    arp_response_error_next = 1'b0;
                    arp_response_mac_next = 48'hffffffffffff;
                end else begin
                    // unicast address; look up IP directly
                    cache_query_request_valid_next = 1'b1;
                    cache_query_request_ip_next = arp_request_ip;
                    arp_request_ip_next = arp_request_ip;
                end
            end else begin
                // outside of subnet, so look up gateway address
                cache_query_request_valid_next = 1'b1;
                cache_query_request_ip_next = gateway_ip;
                arp_request_ip_next = gateway_ip;
            end
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        outgoing_frame_valid_reg <= 1'b0;
        cache_query_request_valid_reg <= 1'b0;
        cache_write_request_valid_reg <= 1'b0;
        arp_request_ready_reg <= 1'b0;
        arp_request_operation_reg <= 1'b0;
        arp_request_retry_cnt_reg <= 6'd0;
        arp_request_timer_reg <= 36'd0;
        arp_response_valid_reg <= 1'b0;
    end else begin
        outgoing_frame_valid_reg <= outgoing_frame_valid_next;
        cache_query_request_valid_reg <= cache_query_request_valid_next;
        cache_write_request_valid_reg <= cache_write_request_valid_next;
        arp_request_ready_reg <= arp_request_ready_next;
        arp_request_operation_reg <= arp_request_operation_next;
        arp_request_retry_cnt_reg <= arp_request_retry_cnt_next;
        arp_request_timer_reg <= arp_request_timer_next;
        arp_response_valid_reg <= arp_response_valid_next;
    end

    cache_query_request_ip_reg <= cache_query_request_ip_next;
    outgoing_eth_dest_mac_reg <= outgoing_eth_dest_mac_next;
    outgoing_arp_oper_reg <= outgoing_arp_oper_next;
    outgoing_arp_tha_reg <= outgoing_arp_tha_next;
    outgoing_arp_tpa_reg <= outgoing_arp_tpa_next;
    cache_write_request_mac_reg <= cache_write_request_mac_next;
    cache_write_request_ip_reg <= cache_write_request_ip_next;
    arp_request_ip_reg <= arp_request_ip_next;
    arp_response_error_reg <= arp_response_error_next;
    arp_response_mac_reg <= arp_response_mac_next;
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/arp_cache.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * ARP cache
 */
module arp_cache #(
    parameter CACHE_ADDR_WIDTH = 9
)
(
    input  wire        clk,
    input  wire        rst,

    /*
     * Cache query
     */
    input  wire        query_request_valid,
    output wire        query_request_ready,
    input  wire [31:0] query_request_ip,

    output wire        query_response_valid,
    input  wire        query_response_ready,
    output wire        query_response_error,
    output wire [47:0] query_response_mac,

    /*
     * Cache write
     */
    input  wire        write_request_valid,
    output wire        write_request_ready,
    input  wire [31:0] write_request_ip,
    input  wire [47:0] write_request_mac,

    /*
     * Configuration
     */
    input  wire        clear_cache
);

reg mem_write = 0;
reg store_query = 0;
reg store_write = 0;

reg query_ip_valid_reg = 0, query_ip_valid_next;
reg [31:0] query_ip_reg = 0;
reg write_ip_valid_reg = 0, write_ip_valid_next;
reg [31:0] write_ip_reg = 0;
reg [47:0] write_mac_reg = 0;
reg clear_cache_reg = 0, clear_cache_next;

reg [CACHE_ADDR_WIDTH-1:0] wr_ptr_reg = {CACHE_ADDR_WIDTH{1'b0}}, wr_ptr_next;
reg [CACHE_ADDR_WIDTH-1:0] rd_ptr_reg = {CACHE_ADDR_WIDTH{1'b0}}, rd_ptr_next;

reg valid_mem[(2**CACHE_ADDR_WIDTH)-1:0];
reg [31:0] ip_addr_mem[(2**CACHE_ADDR_WIDTH)-1:0];
reg [47:0] mac_addr_mem[(2**CACHE_ADDR_WIDTH)-1:0];

reg query_request_ready_reg = 0, query_request_ready_next;

reg query_response_valid_reg = 0, query_response_valid_next;
reg query_response_error_reg = 0, query_response_error_next;
reg [47:0] query_response_mac_reg = 0;

reg write_request_ready_reg = 0, write_request_ready_next;

wire [31:0] query_request_hash;
wire [31:0] write_request_hash;

assign query_request_ready = query_request_ready_reg;

assign query_response_valid = query_response_valid_reg;
assign query_response_error = query_response_error_reg;
assign query_response_mac = query_response_mac_reg;

assign write_request_ready = write_request_ready_reg;

lfsr #(
    .LFSR_WIDTH(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_CONFIG("GALOIS"),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_WIDTH(32),
    .STYLE("AUTO")
)
rd_hash (
    .data_in(query_request_ip),
    .state_in(32'hffffffff),
    .data_out(),
    .state_out(query_request_hash)
);

lfsr #(
    .LFSR_WIDTH(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_CONFIG("GALOIS"),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_WIDTH(32),
    .STYLE("AUTO")
)
wr_hash (
    .data_in(write_request_ip),
    .state_in(32'hffffffff),
    .data_out(),
    .state_out(write_request_hash)
);

integer i;

initial begin
    for (i = 0; i < 2**CACHE_ADDR_WIDTH; i = i + 1) begin
        valid_mem[i] = 1'b0;
        ip_addr_mem[i] = 32'd0;
        mac_addr_mem[i] = 48'd0;
    end
end

always @* begin
    mem_write = 1'b0;
    store_query = 1'b0;
    store_write = 1'b0;

    wr_ptr_next = wr_ptr_reg;
    rd_ptr_next = rd_ptr_reg;

    clear_cache_next = clear_cache_reg | clear_cache;

    query_ip_valid_next = query_ip_valid_reg;

    query_request_ready_next = (~query_ip_valid_reg || ~query_request_valid || query_response_ready) && !clear_cache_next;

    query_response_valid_next = query_response_valid_reg & ~query_response_ready;
    query_response_error_next = query_response_error_reg;

    if (query_ip_valid_reg && (~query_request_valid || query_response_ready)) begin
        query_response_valid_next = 1;
        query_ip_valid_next = 0;
        if (valid_mem[rd_ptr_reg] && ip_addr_mem[rd_ptr_reg] == query_ip_reg) begin
            query_response_error_next = 0;
        end else begin
            query_response_error_next = 1;
        end
    end

    if (query_request_valid && query_request_ready && (~query_ip_valid_reg || ~query_request_valid || query_response_ready)) begin
        store_query = 1;
        query_ip_valid_next = 1;
        rd_ptr_next = query_request_hash[CACHE_ADDR_WIDTH-1:0];
    end

    write_ip_valid_next = write_ip_valid_reg;

    write_request_ready_next = !clear_cache_next;

    if (write_ip_valid_reg) begin
        write_ip_valid_next = 0;
        mem_write = 1;
    end

    if (write_request_valid && write_request_ready) begin
        store_write = 1;
        write_ip_valid_next = 1;
        wr_ptr_next = write_request_hash[CACHE_ADDR_WIDTH-1:0];
    end

    if (clear_cache) begin
        clear_cache_next = 1'b1;
        wr_ptr_next = 0;
    end else if (clear_cache_reg) begin
        wr_ptr_next = wr_ptr_reg + 1;
        clear_cache_next = wr_ptr_next != 0;
        mem_write = 1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        query_ip_valid_reg <= 1'b0;
        query_request_ready_reg <= 1'b0;
        query_response_valid_reg <= 1'b0;
        write_ip_valid_reg <= 1'b0;
        write_request_ready_reg <= 1'b0;
        clear_cache_reg <= 1'b1;
        wr_ptr_reg <= 0;
    end else begin
        query_ip_valid_reg <= query_ip_valid_next;
        query_request_ready_reg <= query_request_ready_next;
        query_response_valid_reg <= query_response_valid_next;
        write_ip_valid_reg <= write_ip_valid_next;
        write_request_ready_reg <= write_request_ready_next;
        clear_cache_reg <= clear_cache_next;
        wr_ptr_reg <= wr_ptr_next;
    end

    query_response_error_reg <= query_response_error_next;

    if (store_query) begin
        query_ip_reg <= query_request_ip;
    end

    if (store_write) begin
        write_ip_reg <= write_request_ip;
        write_mac_reg <= write_request_mac;
    end

    rd_ptr_reg <= rd_ptr_next;

    query_response_mac_reg <= mac_addr_mem[rd_ptr_reg];

    if (mem_write) begin
        valid_mem[wr_ptr_reg] <= !clear_cache_reg;
        ip_addr_mem[wr_ptr_reg] <= write_ip_reg;
        mac_addr_mem[wr_ptr_reg] <= write_mac_reg;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/arp_eth_rx.v ===== */
/*

Copyright (c) 2014-2020 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * ARP ethernet frame receiver (Ethernet frame in, ARP frame out)
 */
module arp_eth_rx #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * Ethernet frame input
     */
    input  wire                   s_eth_hdr_valid,
    output wire                   s_eth_hdr_ready,
    input  wire [47:0]            s_eth_dest_mac,
    input  wire [47:0]            s_eth_src_mac,
    input  wire [15:0]            s_eth_type,
    input  wire [DATA_WIDTH-1:0]  s_eth_payload_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_eth_payload_axis_tkeep,
    input  wire                   s_eth_payload_axis_tvalid,
    output wire                   s_eth_payload_axis_tready,
    input  wire                   s_eth_payload_axis_tlast,
    input  wire                   s_eth_payload_axis_tuser,

    /*
     * ARP frame output
     */
    output wire                   m_frame_valid,
    input  wire                   m_frame_ready,
    output wire [47:0]            m_eth_dest_mac,
    output wire [47:0]            m_eth_src_mac,
    output wire [15:0]            m_eth_type,
    output wire [15:0]            m_arp_htype,
    output wire [15:0]            m_arp_ptype,
    output wire [7:0]             m_arp_hlen,
    output wire [7:0]             m_arp_plen,
    output wire [15:0]            m_arp_oper,
    output wire [47:0]            m_arp_sha,
    output wire [31:0]            m_arp_spa,
    output wire [47:0]            m_arp_tha,
    output wire [31:0]            m_arp_tpa,

    /*
     * Status signals
     */
    output wire                   busy,
    output wire                   error_header_early_termination,
    output wire                   error_invalid_header
);

parameter BYTE_LANES = KEEP_ENABLE ? KEEP_WIDTH : 1;

parameter HDR_SIZE = 28;

parameter CYCLE_COUNT = (HDR_SIZE+BYTE_LANES-1)/BYTE_LANES;

parameter PTR_WIDTH = $clog2(CYCLE_COUNT);

parameter OFFSET = HDR_SIZE % BYTE_LANES;

// bus width assertions
initial begin
    if (BYTE_LANES * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

/*

ARP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0806)          2 octets
 HTYPE (1)                   2 octets
 PTYPE (0x0800)              2 octets
 HLEN (6)                    1 octets
 PLEN (4)                    1 octets
 OPER                        2 octets
 SHA Sender MAC              6 octets
 SPA Sender IP               4 octets
 THA Target MAC              6 octets
 TPA Target IP               4 octets

This module receives an Ethernet frame with header fields in parallel and
payload on an AXI stream interface, decodes the ARP packet fields, and
produces the frame fields in parallel.  

*/

// datapath control signals
reg store_eth_hdr;

reg read_eth_header_reg = 1'b1, read_eth_header_next;
reg read_arp_header_reg = 1'b0, read_arp_header_next;
reg [PTR_WIDTH-1:0] ptr_reg = 0, ptr_next;

reg s_eth_hdr_ready_reg = 1'b0, s_eth_hdr_ready_next;
reg s_eth_payload_axis_tready_reg = 1'b0, s_eth_payload_axis_tready_next;

reg m_frame_valid_reg = 1'b0, m_frame_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;
reg [15:0] m_arp_htype_reg = 16'd0, m_arp_htype_next;
reg [15:0] m_arp_ptype_reg = 16'd0, m_arp_ptype_next;
reg [7:0]  m_arp_hlen_reg = 8'd0, m_arp_hlen_next;
reg [7:0]  m_arp_plen_reg = 8'd0, m_arp_plen_next;
reg [15:0] m_arp_oper_reg = 16'd0, m_arp_oper_next;
reg [47:0] m_arp_sha_reg = 48'd0, m_arp_sha_next;
reg [31:0] m_arp_spa_reg = 32'd0, m_arp_spa_next;
reg [47:0] m_arp_tha_reg = 48'd0, m_arp_tha_next;
reg [31:0] m_arp_tpa_reg = 32'd0, m_arp_tpa_next;

reg busy_reg = 1'b0;
reg error_header_early_termination_reg = 1'b0, error_header_early_termination_next;
reg error_invalid_header_reg = 1'b0, error_invalid_header_next;

assign s_eth_hdr_ready = s_eth_hdr_ready_reg;
assign s_eth_payload_axis_tready = s_eth_payload_axis_tready_reg;

assign m_frame_valid = m_frame_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_arp_htype = m_arp_htype_reg;
assign m_arp_ptype = m_arp_ptype_reg;
assign m_arp_hlen = m_arp_hlen_reg;
assign m_arp_plen = m_arp_plen_reg;
assign m_arp_oper = m_arp_oper_reg;
assign m_arp_sha = m_arp_sha_reg;
assign m_arp_spa = m_arp_spa_reg;
assign m_arp_tha = m_arp_tha_reg;
assign m_arp_tpa = m_arp_tpa_reg;

assign busy = busy_reg;
assign error_header_early_termination = error_header_early_termination_reg;
assign error_invalid_header = error_invalid_header_reg;

always @* begin
    read_eth_header_next = read_eth_header_reg;
    read_arp_header_next = read_arp_header_reg;
    ptr_next = ptr_reg;

    s_eth_hdr_ready_next = 1'b0;
    s_eth_payload_axis_tready_next = 1'b0;

    store_eth_hdr = 1'b0;

    m_frame_valid_next = m_frame_valid_reg && !m_frame_ready;

    m_arp_htype_next = m_arp_htype_reg;
    m_arp_ptype_next = m_arp_ptype_reg;
    m_arp_hlen_next = m_arp_hlen_reg;
    m_arp_plen_next = m_arp_plen_reg;
    m_arp_oper_next = m_arp_oper_reg;
    m_arp_sha_next = m_arp_sha_reg;
    m_arp_spa_next = m_arp_spa_reg;
    m_arp_tha_next = m_arp_tha_reg;
    m_arp_tpa_next = m_arp_tpa_reg;

    error_header_early_termination_next = 1'b0;
    error_invalid_header_next = 1'b0;

    if (s_eth_hdr_ready && s_eth_hdr_valid) begin
        if (read_eth_header_reg) begin
            store_eth_hdr = 1'b1;
            ptr_next = 0;
            read_eth_header_next = 1'b0;
            read_arp_header_next = 1'b1;
        end
    end

    if (s_eth_payload_axis_tready && s_eth_payload_axis_tvalid) begin
        if (read_arp_header_reg) begin
            // word transfer in - store it
            ptr_next = ptr_reg + 1;

            `define _HEADER_FIELD_(offset, field) \
                if (ptr_reg == offset/BYTE_LANES && (!KEEP_ENABLE || s_eth_payload_axis_tkeep[offset%BYTE_LANES])) begin \
                    field = s_eth_payload_axis_tdata[(offset%BYTE_LANES)*8 +: 8]; \
                end

            `_HEADER_FIELD_(0,  m_arp_htype_next[1*8 +: 8])
            `_HEADER_FIELD_(1,  m_arp_htype_next[0*8 +: 8])
            `_HEADER_FIELD_(2,  m_arp_ptype_next[1*8 +: 8])
            `_HEADER_FIELD_(3,  m_arp_ptype_next[0*8 +: 8])
            `_HEADER_FIELD_(4,  m_arp_hlen_next[0*8 +: 8])
            `_HEADER_FIELD_(5,  m_arp_plen_next[0*8 +: 8])
            `_HEADER_FIELD_(6,  m_arp_oper_next[1*8 +: 8])
            `_HEADER_FIELD_(7,  m_arp_oper_next[0*8 +: 8])
            `_HEADER_FIELD_(8,  m_arp_sha_next[5*8 +: 8])
            `_HEADER_FIELD_(9,  m_arp_sha_next[4*8 +: 8])
            `_HEADER_FIELD_(10, m_arp_sha_next[3*8 +: 8])
            `_HEADER_FIELD_(11, m_arp_sha_next[2*8 +: 8])
            `_HEADER_FIELD_(12, m_arp_sha_next[1*8 +: 8])
            `_HEADER_FIELD_(13, m_arp_sha_next[0*8 +: 8])
            `_HEADER_FIELD_(14, m_arp_spa_next[3*8 +: 8])
            `_HEADER_FIELD_(15, m_arp_spa_next[2*8 +: 8])
            `_HEADER_FIELD_(16, m_arp_spa_next[1*8 +: 8])
            `_HEADER_FIELD_(17, m_arp_spa_next[0*8 +: 8])
            `_HEADER_FIELD_(18, m_arp_tha_next[5*8 +: 8])
            `_HEADER_FIELD_(19, m_arp_tha_next[4*8 +: 8])
            `_HEADER_FIELD_(20, m_arp_tha_next[3*8 +: 8])
            `_HEADER_FIELD_(21, m_arp_tha_next[2*8 +: 8])
            `_HEADER_FIELD_(22, m_arp_tha_next[1*8 +: 8])
            `_HEADER_FIELD_(23, m_arp_tha_next[0*8 +: 8])
            `_HEADER_FIELD_(24, m_arp_tpa_next[3*8 +: 8])
            `_HEADER_FIELD_(25, m_arp_tpa_next[2*8 +: 8])
            `_HEADER_FIELD_(26, m_arp_tpa_next[1*8 +: 8])
            `_HEADER_FIELD_(27, m_arp_tpa_next[0*8 +: 8])

            if (ptr_reg == 27/BYTE_LANES && (!KEEP_ENABLE || s_eth_payload_axis_tkeep[27%BYTE_LANES])) begin
                read_arp_header_next = 1'b0;
            end

            `undef _HEADER_FIELD_
        end

        if (s_eth_payload_axis_tlast) begin
            if (read_arp_header_next) begin
                // don't have the whole header
                error_header_early_termination_next = 1'b1;
            end else if (m_arp_hlen_next != 4'd6 || m_arp_plen_next != 4'd4) begin
                // lengths not valid
                error_invalid_header_next = 1'b1;
            end else begin
                // otherwise, transfer tuser
                m_frame_valid_next = !s_eth_payload_axis_tuser;
            end

            ptr_next = 1'b0;
            read_eth_header_next = 1'b1;
            read_arp_header_next = 1'b0;
        end
    end

    if (read_eth_header_next) begin
        s_eth_hdr_ready_next = !m_frame_valid_next;
    end else begin
        s_eth_payload_axis_tready_next = 1'b1;
    end
end

always @(posedge clk) begin
    read_eth_header_reg <= read_eth_header_next;
    read_arp_header_reg <= read_arp_header_next;
    ptr_reg <= ptr_next;

    s_eth_hdr_ready_reg <= s_eth_hdr_ready_next;
    s_eth_payload_axis_tready_reg <= s_eth_payload_axis_tready_next;

    m_frame_valid_reg <= m_frame_valid_next;

    m_arp_htype_reg <= m_arp_htype_next;
    m_arp_ptype_reg <= m_arp_ptype_next;
    m_arp_hlen_reg <= m_arp_hlen_next;
    m_arp_plen_reg <= m_arp_plen_next;
    m_arp_oper_reg <= m_arp_oper_next;
    m_arp_sha_reg <= m_arp_sha_next;
    m_arp_spa_reg <= m_arp_spa_next;
    m_arp_tha_reg <= m_arp_tha_next;
    m_arp_tpa_reg <= m_arp_tpa_next;

    error_header_early_termination_reg <= error_header_early_termination_next;
    error_invalid_header_reg <= error_invalid_header_next;

    busy_reg <= read_arp_header_next;

    // datapath
    if (store_eth_hdr) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
    end

    if (rst) begin
        read_eth_header_reg <= 1'b1;
        read_arp_header_reg <= 1'b0;
        ptr_reg <= 0;
        s_eth_payload_axis_tready_reg <= 1'b0;
        m_frame_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_header_early_termination_reg <= 1'b0;
        error_invalid_header_reg <= 1'b0;
    end 
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/arp_eth_tx.v ===== */
/*

Copyright (c) 2014-2020 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * ARP ethernet frame transmitter (ARP frame in, Ethernet frame out)
 */
module arp_eth_tx #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * ARP frame input
     */
    input  wire                   s_frame_valid,
    output wire                   s_frame_ready,
    input  wire [47:0]            s_eth_dest_mac,
    input  wire [47:0]            s_eth_src_mac,
    input  wire [15:0]            s_eth_type,
    input  wire [15:0]            s_arp_htype,
    input  wire [15:0]            s_arp_ptype,
    input  wire [15:0]            s_arp_oper,
    input  wire [47:0]            s_arp_sha,
    input  wire [31:0]            s_arp_spa,
    input  wire [47:0]            s_arp_tha,
    input  wire [31:0]            s_arp_tpa,

    /*
     * Ethernet frame output
     */
    output wire                   m_eth_hdr_valid,
    input  wire                   m_eth_hdr_ready,
    output wire [47:0]            m_eth_dest_mac,
    output wire [47:0]            m_eth_src_mac,
    output wire [15:0]            m_eth_type,
    output wire [DATA_WIDTH-1:0]  m_eth_payload_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_eth_payload_axis_tkeep,
    output wire                   m_eth_payload_axis_tvalid,
    input  wire                   m_eth_payload_axis_tready,
    output wire                   m_eth_payload_axis_tlast,
    output wire                   m_eth_payload_axis_tuser,

    /*
     * Status signals
     */
    output wire                   busy
);

parameter BYTE_LANES = KEEP_ENABLE ? KEEP_WIDTH : 1;

parameter HDR_SIZE = 28;

parameter CYCLE_COUNT = (HDR_SIZE+BYTE_LANES-1)/BYTE_LANES;

parameter PTR_WIDTH = $clog2(CYCLE_COUNT);

parameter OFFSET = HDR_SIZE % BYTE_LANES;

// bus width assertions
initial begin
    if (BYTE_LANES * 8 != DATA_WIDTH) begin
        $error("Error: AXI stream interface requires byte (8-bit) granularity (instance %m)");
        $finish;
    end
end

/*

ARP Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0806)          2 octets
 HTYPE (1)                   2 octets
 PTYPE (0x0800)              2 octets
 HLEN (6)                    1 octets
 PLEN (4)                    1 octets
 OPER                        2 octets
 SHA Sender MAC              6 octets
 SPA Sender IP               4 octets
 THA Target MAC              6 octets
 TPA Target IP               4 octets

This module receives an ARP frame with header fields in parallel  and
transmits the complete Ethernet payload on an AXI interface.

*/

// datapath control signals
reg store_frame;

reg send_arp_header_reg = 1'b0, send_arp_header_next;
reg [PTR_WIDTH-1:0] ptr_reg = 0, ptr_next;

reg [15:0] arp_htype_reg = 16'd0;
reg [15:0] arp_ptype_reg = 16'd0;
reg [15:0] arp_oper_reg = 16'd0;
reg [47:0] arp_sha_reg = 48'd0;
reg [31:0] arp_spa_reg = 32'd0;
reg [47:0] arp_tha_reg = 48'd0;
reg [31:0] arp_tpa_reg = 32'd0;

reg s_frame_ready_reg = 1'b0, s_frame_ready_next;

reg m_eth_hdr_valid_reg = 1'b0, m_eth_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;

reg busy_reg = 1'b0;

// internal datapath
reg [DATA_WIDTH-1:0] m_eth_payload_axis_tdata_int;
reg [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep_int;
reg                  m_eth_payload_axis_tvalid_int;
reg                  m_eth_payload_axis_tready_int_reg = 1'b0;
reg                  m_eth_payload_axis_tlast_int;
reg                  m_eth_payload_axis_tuser_int;
wire                 m_eth_payload_axis_tready_int_early;

assign s_frame_ready = s_frame_ready_reg;

assign m_eth_hdr_valid = m_eth_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;

assign busy = busy_reg;

always @* begin
    send_arp_header_next = send_arp_header_reg;
    ptr_next = ptr_reg;

    s_frame_ready_next = 1'b0;

    store_frame = 1'b0;

    m_eth_hdr_valid_next = m_eth_hdr_valid_reg && !m_eth_hdr_ready;

    m_eth_payload_axis_tdata_int = {DATA_WIDTH{1'b0}};
    m_eth_payload_axis_tkeep_int = {KEEP_WIDTH{1'b0}};
    m_eth_payload_axis_tvalid_int = 1'b0;
    m_eth_payload_axis_tlast_int = 1'b0;
    m_eth_payload_axis_tuser_int = 1'b0;

    if (s_frame_ready && s_frame_valid) begin
        store_frame = 1'b1;
        m_eth_hdr_valid_next = 1'b1;
        ptr_next = 0;
        send_arp_header_next = 1'b1;
    end

    if (m_eth_payload_axis_tready_int_reg) begin
        if (send_arp_header_reg) begin
            ptr_next = ptr_reg + 1;

            m_eth_payload_axis_tdata_int = {DATA_WIDTH{1'b0}};
            m_eth_payload_axis_tkeep_int = {KEEP_WIDTH{1'b0}};
            m_eth_payload_axis_tvalid_int = 1'b1;
            m_eth_payload_axis_tlast_int = 1'b0;
            m_eth_payload_axis_tuser_int = 1'b0;

            `define _HEADER_FIELD_(offset, field) \
                if (ptr_reg == offset/BYTE_LANES) begin \
                    m_eth_payload_axis_tdata_int[(offset%BYTE_LANES)*8 +: 8] = field; \
                    m_eth_payload_axis_tkeep_int[offset%BYTE_LANES] = 1'b1; \
                end

            `_HEADER_FIELD_(0,  arp_htype_reg[1*8 +: 8])
            `_HEADER_FIELD_(1,  arp_htype_reg[0*8 +: 8])
            `_HEADER_FIELD_(2,  arp_ptype_reg[1*8 +: 8])
            `_HEADER_FIELD_(3,  arp_ptype_reg[0*8 +: 8])
            `_HEADER_FIELD_(4,  8'd6)
            `_HEADER_FIELD_(5,  8'd4)
            `_HEADER_FIELD_(6,  arp_oper_reg[1*8 +: 8])
            `_HEADER_FIELD_(7,  arp_oper_reg[0*8 +: 8])
            `_HEADER_FIELD_(8,  arp_sha_reg[5*8 +: 8])
            `_HEADER_FIELD_(9,  arp_sha_reg[4*8 +: 8])
            `_HEADER_FIELD_(10, arp_sha_reg[3*8 +: 8])
            `_HEADER_FIELD_(11, arp_sha_reg[2*8 +: 8])
            `_HEADER_FIELD_(12, arp_sha_reg[1*8 +: 8])
            `_HEADER_FIELD_(13, arp_sha_reg[0*8 +: 8])
            `_HEADER_FIELD_(14, arp_spa_reg[3*8 +: 8])
            `_HEADER_FIELD_(15, arp_spa_reg[2*8 +: 8])
            `_HEADER_FIELD_(16, arp_spa_reg[1*8 +: 8])
            `_HEADER_FIELD_(17, arp_spa_reg[0*8 +: 8])
            `_HEADER_FIELD_(18, arp_tha_reg[5*8 +: 8])
            `_HEADER_FIELD_(19, arp_tha_reg[4*8 +: 8])
            `_HEADER_FIELD_(20, arp_tha_reg[3*8 +: 8])
            `_HEADER_FIELD_(21, arp_tha_reg[2*8 +: 8])
            `_HEADER_FIELD_(22, arp_tha_reg[1*8 +: 8])
            `_HEADER_FIELD_(23, arp_tha_reg[0*8 +: 8])
            `_HEADER_FIELD_(24, arp_tpa_reg[3*8 +: 8])
            `_HEADER_FIELD_(25, arp_tpa_reg[2*8 +: 8])
            `_HEADER_FIELD_(26, arp_tpa_reg[1*8 +: 8])
            `_HEADER_FIELD_(27, arp_tpa_reg[0*8 +: 8])

            if (ptr_reg == 27/BYTE_LANES) begin
                m_eth_payload_axis_tlast_int = 1'b1;
                send_arp_header_next = 1'b0;
            end

            `undef _HEADER_FIELD_
        end
    end

    s_frame_ready_next = !m_eth_hdr_valid_next && !send_arp_header_next;
end

always @(posedge clk) begin
    send_arp_header_reg <= send_arp_header_next;
    ptr_reg <= ptr_next;

    s_frame_ready_reg <= s_frame_ready_next;

    m_eth_hdr_valid_reg <= m_eth_hdr_valid_next;

    busy_reg <= send_arp_header_next;

    if (store_frame) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
        arp_htype_reg <= s_arp_htype;
        arp_ptype_reg <= s_arp_ptype;
        arp_oper_reg <= s_arp_oper;
        arp_sha_reg <= s_arp_sha;
        arp_spa_reg <= s_arp_spa;
        arp_tha_reg <= s_arp_tha;
        arp_tpa_reg <= s_arp_tpa;
    end

    if (rst) begin
        send_arp_header_reg <= 1'b0;
        ptr_reg <= 0;
        s_frame_ready_reg <= 1'b0;
        m_eth_hdr_valid_reg <= 1'b0;
        busy_reg <= 1'b0;
    end
end

// output datapath logic
reg [DATA_WIDTH-1:0] m_eth_payload_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg                  m_eth_payload_axis_tvalid_reg = 1'b0, m_eth_payload_axis_tvalid_next;
reg                  m_eth_payload_axis_tlast_reg = 1'b0;
reg                  m_eth_payload_axis_tuser_reg = 1'b0;

reg [DATA_WIDTH-1:0] temp_m_eth_payload_axis_tdata_reg = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] temp_m_eth_payload_axis_tkeep_reg = {KEEP_WIDTH{1'b0}};
reg                  temp_m_eth_payload_axis_tvalid_reg = 1'b0, temp_m_eth_payload_axis_tvalid_next;
reg                  temp_m_eth_payload_axis_tlast_reg = 1'b0;
reg                  temp_m_eth_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_eth_payload_int_to_output;
reg store_eth_payload_int_to_temp;
reg store_eth_payload_axis_temp_to_output;

assign m_eth_payload_axis_tdata = m_eth_payload_axis_tdata_reg;
assign m_eth_payload_axis_tkeep = KEEP_ENABLE ? m_eth_payload_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
assign m_eth_payload_axis_tvalid = m_eth_payload_axis_tvalid_reg;
assign m_eth_payload_axis_tlast = m_eth_payload_axis_tlast_reg;
assign m_eth_payload_axis_tuser = m_eth_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_eth_payload_axis_tready_int_early = m_eth_payload_axis_tready || (!temp_m_eth_payload_axis_tvalid_reg && !m_eth_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_reg;
    temp_m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;

    store_eth_payload_int_to_output = 1'b0;
    store_eth_payload_int_to_temp = 1'b0;
    store_eth_payload_axis_temp_to_output = 1'b0;

    if (m_eth_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_eth_payload_axis_tready || !m_eth_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_eth_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_eth_payload_int_to_temp = 1'b1;
        end
    end else if (m_eth_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;
        temp_m_eth_payload_axis_tvalid_next = 1'b0;
        store_eth_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_eth_payload_axis_tvalid_reg <= m_eth_payload_axis_tvalid_next;
    m_eth_payload_axis_tready_int_reg <= m_eth_payload_axis_tready_int_early;
    temp_m_eth_payload_axis_tvalid_reg <= temp_m_eth_payload_axis_tvalid_next;

    // datapath
    if (store_eth_payload_int_to_output) begin
        m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        m_eth_payload_axis_tkeep_reg <= m_eth_payload_axis_tkeep_int;
        m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end else if (store_eth_payload_axis_temp_to_output) begin
        m_eth_payload_axis_tdata_reg <= temp_m_eth_payload_axis_tdata_reg;
        m_eth_payload_axis_tkeep_reg <= temp_m_eth_payload_axis_tkeep_reg;
        m_eth_payload_axis_tlast_reg <= temp_m_eth_payload_axis_tlast_reg;
        m_eth_payload_axis_tuser_reg <= temp_m_eth_payload_axis_tuser_reg;
    end

    if (store_eth_payload_int_to_temp) begin
        temp_m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        temp_m_eth_payload_axis_tkeep_reg <= m_eth_payload_axis_tkeep_int;
        temp_m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        temp_m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end

    if (rst) begin
        m_eth_payload_axis_tvalid_reg <= 1'b0;
        m_eth_payload_axis_tready_int_reg <= 1'b0;
        temp_m_eth_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/rtl/eth_arb_mux.v ===== */
/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Ethernet arbitrated multiplexer
 */
module eth_arb_mux #
(
    parameter S_COUNT = 4,
    parameter DATA_WIDTH = 8,
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter USER_ENABLE = 1,
    parameter USER_WIDTH = 1,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 1
)
(
    input  wire                          clk,
    input  wire                          rst,

    /*
     * Ethernet frame inputs
     */
    input  wire [S_COUNT-1:0]            s_eth_hdr_valid,
    output wire [S_COUNT-1:0]            s_eth_hdr_ready,
    input  wire [S_COUNT*48-1:0]         s_eth_dest_mac,
    input  wire [S_COUNT*48-1:0]         s_eth_src_mac,
    input  wire [S_COUNT*16-1:0]         s_eth_type,
    input  wire [S_COUNT*DATA_WIDTH-1:0] s_eth_payload_axis_tdata,
    input  wire [S_COUNT*KEEP_WIDTH-1:0] s_eth_payload_axis_tkeep,
    input  wire [S_COUNT-1:0]            s_eth_payload_axis_tvalid,
    output wire [S_COUNT-1:0]            s_eth_payload_axis_tready,
    input  wire [S_COUNT-1:0]            s_eth_payload_axis_tlast,
    input  wire [S_COUNT*ID_WIDTH-1:0]   s_eth_payload_axis_tid,
    input  wire [S_COUNT*DEST_WIDTH-1:0] s_eth_payload_axis_tdest,
    input  wire [S_COUNT*USER_WIDTH-1:0] s_eth_payload_axis_tuser,

    /*
     * Ethernet frame output
     */
    output wire                          m_eth_hdr_valid,
    input  wire                          m_eth_hdr_ready,
    output wire [47:0]                   m_eth_dest_mac,
    output wire [47:0]                   m_eth_src_mac,
    output wire [15:0]                   m_eth_type,
    output wire [DATA_WIDTH-1:0]         m_eth_payload_axis_tdata,
    output wire [KEEP_WIDTH-1:0]         m_eth_payload_axis_tkeep,
    output wire                          m_eth_payload_axis_tvalid,
    input  wire                          m_eth_payload_axis_tready,
    output wire                          m_eth_payload_axis_tlast,
    output wire [ID_WIDTH-1:0]           m_eth_payload_axis_tid,
    output wire [DEST_WIDTH-1:0]         m_eth_payload_axis_tdest,
    output wire [USER_WIDTH-1:0]         m_eth_payload_axis_tuser
);

parameter CL_S_COUNT = $clog2(S_COUNT);

reg frame_reg = 1'b0, frame_next;

reg [S_COUNT-1:0] s_eth_hdr_ready_reg = {S_COUNT{1'b0}}, s_eth_hdr_ready_next;

reg m_eth_hdr_valid_reg = 1'b0, m_eth_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0, m_eth_dest_mac_next;
reg [47:0] m_eth_src_mac_reg = 48'd0, m_eth_src_mac_next;
reg [15:0] m_eth_type_reg = 16'd0, m_eth_type_next;

wire [S_COUNT-1:0] request;
wire [S_COUNT-1:0] acknowledge;
wire [S_COUNT-1:0] grant;
wire grant_valid;
wire [CL_S_COUNT-1:0] grant_encoded;

// internal datapath
reg  [DATA_WIDTH-1:0] m_eth_payload_axis_tdata_int;
reg  [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep_int;
reg                   m_eth_payload_axis_tvalid_int;
reg                   m_eth_payload_axis_tready_int_reg = 1'b0;
reg                   m_eth_payload_axis_tlast_int;
reg  [ID_WIDTH-1:0]   m_eth_payload_axis_tid_int;
reg  [DEST_WIDTH-1:0] m_eth_payload_axis_tdest_int;
reg  [USER_WIDTH-1:0] m_eth_payload_axis_tuser_int;
wire                  m_eth_payload_axis_tready_int_early;

assign s_eth_hdr_ready = s_eth_hdr_ready_reg;

assign s_eth_payload_axis_tready = (m_eth_payload_axis_tready_int_reg && grant_valid) << grant_encoded;

assign m_eth_hdr_valid = m_eth_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;

// mux for incoming packet
wire [DATA_WIDTH-1:0] current_s_tdata  = s_eth_payload_axis_tdata[grant_encoded*DATA_WIDTH +: DATA_WIDTH];
wire [KEEP_WIDTH-1:0] current_s_tkeep  = s_eth_payload_axis_tkeep[grant_encoded*KEEP_WIDTH +: KEEP_WIDTH];
wire                  current_s_tvalid = s_eth_payload_axis_tvalid[grant_encoded];
wire                  current_s_tready = s_eth_payload_axis_tready[grant_encoded];
wire                  current_s_tlast  = s_eth_payload_axis_tlast[grant_encoded];
wire [ID_WIDTH-1:0]   current_s_tid    = s_eth_payload_axis_tid[grant_encoded*ID_WIDTH +: ID_WIDTH];
wire [DEST_WIDTH-1:0] current_s_tdest  = s_eth_payload_axis_tdest[grant_encoded*DEST_WIDTH +: DEST_WIDTH];
wire [USER_WIDTH-1:0] current_s_tuser  = s_eth_payload_axis_tuser[grant_encoded*USER_WIDTH +: USER_WIDTH];

// arbiter instance
arbiter #(
    .PORTS(S_COUNT),
    .ARB_TYPE_ROUND_ROBIN(ARB_TYPE_ROUND_ROBIN),
    .ARB_BLOCK(1),
    .ARB_BLOCK_ACK(1),
    .ARB_LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
arb_inst (
    .clk(clk),
    .rst(rst),
    .request(request),
    .acknowledge(acknowledge),
    .grant(grant),
    .grant_valid(grant_valid),
    .grant_encoded(grant_encoded)
);

assign request = s_eth_hdr_valid & ~grant;
assign acknowledge = grant & s_eth_payload_axis_tvalid & s_eth_payload_axis_tready & s_eth_payload_axis_tlast;

always @* begin
    frame_next = frame_reg;

    s_eth_hdr_ready_next = {S_COUNT{1'b0}};

    m_eth_hdr_valid_next = m_eth_hdr_valid_reg && !m_eth_hdr_ready;
    m_eth_dest_mac_next = m_eth_dest_mac_reg;
    m_eth_src_mac_next = m_eth_src_mac_reg;
    m_eth_type_next = m_eth_type_reg;

    if (s_eth_payload_axis_tvalid[grant_encoded] && s_eth_payload_axis_tready[grant_encoded]) begin
        // end of frame detection
        if (s_eth_payload_axis_tlast[grant_encoded]) begin
            frame_next = 1'b0;
        end
    end

    if (!frame_reg && grant_valid && (m_eth_hdr_ready || !m_eth_hdr_valid)) begin
        // start of frame
        frame_next = 1'b1;

        s_eth_hdr_ready_next = grant;

        m_eth_hdr_valid_next = 1'b1;
        m_eth_dest_mac_next = s_eth_dest_mac[grant_encoded*48 +: 48];
        m_eth_src_mac_next = s_eth_src_mac[grant_encoded*48 +: 48];
        m_eth_type_next = s_eth_type[grant_encoded*16 +: 16];
    end

    // pass through selected packet data
    m_eth_payload_axis_tdata_int  = current_s_tdata;
    m_eth_payload_axis_tkeep_int  = current_s_tkeep;
    m_eth_payload_axis_tvalid_int = current_s_tvalid && m_eth_payload_axis_tready_int_reg && grant_valid;
    m_eth_payload_axis_tlast_int  = current_s_tlast;
    m_eth_payload_axis_tid_int    = current_s_tid;
    m_eth_payload_axis_tdest_int  = current_s_tdest;
    m_eth_payload_axis_tuser_int  = current_s_tuser;
end

always @(posedge clk) begin
    frame_reg <= frame_next;

    s_eth_hdr_ready_reg <= s_eth_hdr_ready_next;

    m_eth_hdr_valid_reg <= m_eth_hdr_valid_next;
    m_eth_dest_mac_reg <= m_eth_dest_mac_next;
    m_eth_src_mac_reg <= m_eth_src_mac_next;
    m_eth_type_reg <= m_eth_type_next;

    if (rst) begin
        frame_reg <= 1'b0;
        s_eth_hdr_ready_reg <= {S_COUNT{1'b0}};
        m_eth_hdr_valid_reg <= 1'b0;
    end
end

// output datapath logic
reg [DATA_WIDTH-1:0] m_eth_payload_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] m_eth_payload_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
reg                  m_eth_payload_axis_tvalid_reg = 1'b0, m_eth_payload_axis_tvalid_next;
reg                  m_eth_payload_axis_tlast_reg  = 1'b0;
reg [ID_WIDTH-1:0]   m_eth_payload_axis_tid_reg    = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0] m_eth_payload_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0] m_eth_payload_axis_tuser_reg  = {USER_WIDTH{1'b0}};

reg [DATA_WIDTH-1:0] temp_m_eth_payload_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
reg [KEEP_WIDTH-1:0] temp_m_eth_payload_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
reg                  temp_m_eth_payload_axis_tvalid_reg = 1'b0, temp_m_eth_payload_axis_tvalid_next;
reg                  temp_m_eth_payload_axis_tlast_reg  = 1'b0;
reg [ID_WIDTH-1:0]   temp_m_eth_payload_axis_tid_reg    = {ID_WIDTH{1'b0}};
reg [DEST_WIDTH-1:0] temp_m_eth_payload_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
reg [USER_WIDTH-1:0] temp_m_eth_payload_axis_tuser_reg  = {USER_WIDTH{1'b0}};

// datapath control
reg store_axis_int_to_output;
reg store_axis_int_to_temp;
reg store_eth_payload_axis_temp_to_output;

assign m_eth_payload_axis_tdata  = m_eth_payload_axis_tdata_reg;
assign m_eth_payload_axis_tkeep  = KEEP_ENABLE ? m_eth_payload_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
assign m_eth_payload_axis_tvalid = m_eth_payload_axis_tvalid_reg;
assign m_eth_payload_axis_tlast  = m_eth_payload_axis_tlast_reg;
assign m_eth_payload_axis_tid    = ID_ENABLE   ? m_eth_payload_axis_tid_reg   : {ID_WIDTH{1'b0}};
assign m_eth_payload_axis_tdest  = DEST_ENABLE ? m_eth_payload_axis_tdest_reg : {DEST_WIDTH{1'b0}};
assign m_eth_payload_axis_tuser  = USER_ENABLE ? m_eth_payload_axis_tuser_reg : {USER_WIDTH{1'b0}};

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_eth_payload_axis_tready_int_early = m_eth_payload_axis_tready || (!temp_m_eth_payload_axis_tvalid_reg && !m_eth_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_reg;
    temp_m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_eth_payload_axis_temp_to_output = 1'b0;

    if (m_eth_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_eth_payload_axis_tready || !m_eth_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_eth_payload_axis_tvalid_next = m_eth_payload_axis_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if (m_eth_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_eth_payload_axis_tvalid_next = temp_m_eth_payload_axis_tvalid_reg;
        temp_m_eth_payload_axis_tvalid_next = 1'b0;
        store_eth_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_eth_payload_axis_tvalid_reg <= m_eth_payload_axis_tvalid_next;
    m_eth_payload_axis_tready_int_reg <= m_eth_payload_axis_tready_int_early;
    temp_m_eth_payload_axis_tvalid_reg <= temp_m_eth_payload_axis_tvalid_next;

    // datapath
    if (store_axis_int_to_output) begin
        m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        m_eth_payload_axis_tkeep_reg <= m_eth_payload_axis_tkeep_int;
        m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        m_eth_payload_axis_tid_reg   <= m_eth_payload_axis_tid_int;
        m_eth_payload_axis_tdest_reg <= m_eth_payload_axis_tdest_int;
        m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end else if (store_eth_payload_axis_temp_to_output) begin
        m_eth_payload_axis_tdata_reg <= temp_m_eth_payload_axis_tdata_reg;
        m_eth_payload_axis_tkeep_reg <= temp_m_eth_payload_axis_tkeep_reg;
        m_eth_payload_axis_tlast_reg <= temp_m_eth_payload_axis_tlast_reg;
        m_eth_payload_axis_tid_reg   <= temp_m_eth_payload_axis_tid_reg;
        m_eth_payload_axis_tdest_reg <= temp_m_eth_payload_axis_tdest_reg;
        m_eth_payload_axis_tuser_reg <= temp_m_eth_payload_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_eth_payload_axis_tdata_reg <= m_eth_payload_axis_tdata_int;
        temp_m_eth_payload_axis_tkeep_reg <= m_eth_payload_axis_tkeep_int;
        temp_m_eth_payload_axis_tlast_reg <= m_eth_payload_axis_tlast_int;
        temp_m_eth_payload_axis_tid_reg   <= m_eth_payload_axis_tid_int;
        temp_m_eth_payload_axis_tdest_reg <= m_eth_payload_axis_tdest_int;
        temp_m_eth_payload_axis_tuser_reg <= m_eth_payload_axis_tuser_int;
    end

    if (rst) begin
        m_eth_payload_axis_tvalid_reg <= 1'b0;
        m_eth_payload_axis_tready_int_reg <= 1'b0;
        temp_m_eth_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/lib/axis/rtl/arbiter.v ===== */
/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Arbiter module
 */
module arbiter #
(
    parameter PORTS = 4,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // blocking arbiter enable
    parameter ARB_BLOCK = 0,
    // block on acknowledge assert when nonzero, request deassert when 0
    parameter ARB_BLOCK_ACK = 1,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 0
)
(
    input  wire                     clk,
    input  wire                     rst,

    input  wire [PORTS-1:0]         request,
    input  wire [PORTS-1:0]         acknowledge,

    output wire [PORTS-1:0]         grant,
    output wire                     grant_valid,
    output wire [$clog2(PORTS)-1:0] grant_encoded
);

reg [PORTS-1:0] grant_reg = 0, grant_next;
reg grant_valid_reg = 0, grant_valid_next;
reg [$clog2(PORTS)-1:0] grant_encoded_reg = 0, grant_encoded_next;

assign grant_valid = grant_valid_reg;
assign grant = grant_reg;
assign grant_encoded = grant_encoded_reg;

wire request_valid;
wire [$clog2(PORTS)-1:0] request_index;
wire [PORTS-1:0] request_mask;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
priority_encoder_inst (
    .input_unencoded(request),
    .output_valid(request_valid),
    .output_encoded(request_index),
    .output_unencoded(request_mask)
);

reg [PORTS-1:0] mask_reg = 0, mask_next;

wire masked_request_valid;
wire [$clog2(PORTS)-1:0] masked_request_index;
wire [PORTS-1:0] masked_request_mask;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
priority_encoder_masked (
    .input_unencoded(request & mask_reg),
    .output_valid(masked_request_valid),
    .output_encoded(masked_request_index),
    .output_unencoded(masked_request_mask)
);

always @* begin
    grant_next = 0;
    grant_valid_next = 0;
    grant_encoded_next = 0;
    mask_next = mask_reg;

    if (ARB_BLOCK && !ARB_BLOCK_ACK && grant_reg & request) begin
        // granted request still asserted; hold it
        grant_valid_next = grant_valid_reg;
        grant_next = grant_reg;
        grant_encoded_next = grant_encoded_reg;
    end else if (ARB_BLOCK && ARB_BLOCK_ACK && grant_valid && !(grant_reg & acknowledge)) begin
        // granted request not yet acknowledged; hold it
        grant_valid_next = grant_valid_reg;
        grant_next = grant_reg;
        grant_encoded_next = grant_encoded_reg;
    end else if (request_valid) begin
        if (ARB_TYPE_ROUND_ROBIN) begin
            if (masked_request_valid) begin
                grant_valid_next = 1;
                grant_next = masked_request_mask;
                grant_encoded_next = masked_request_index;
                if (ARB_LSB_HIGH_PRIORITY) begin
                    mask_next = {PORTS{1'b1}} << (masked_request_index + 1);
                end else begin
                    mask_next = {PORTS{1'b1}} >> (PORTS - masked_request_index);
                end
            end else begin
                grant_valid_next = 1;
                grant_next = request_mask;
                grant_encoded_next = request_index;
                if (ARB_LSB_HIGH_PRIORITY) begin
                    mask_next = {PORTS{1'b1}} << (request_index + 1);
                end else begin
                    mask_next = {PORTS{1'b1}} >> (PORTS - request_index);
                end
            end
        end else begin
            grant_valid_next = 1;
            grant_next = request_mask;
            grant_encoded_next = request_index;
        end
    end
end

always @(posedge clk) begin
    grant_reg <= grant_next;
    grant_valid_reg <= grant_valid_next;
    grant_encoded_reg <= grant_encoded_next;
    mask_reg <= mask_next;

    if (rst) begin
        grant_reg <= 0;
        grant_valid_reg <= 0;
        grant_encoded_reg <= 0;
        mask_reg <= 0;
    end
end

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/lib/axis/rtl/priority_encoder.v ===== */
/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Priority encoder module
 */
module priority_encoder #
(
    parameter WIDTH = 4,
    // LSB priority selection
    parameter LSB_HIGH_PRIORITY = 0
)
(
    input  wire [WIDTH-1:0]         input_unencoded,
    output wire                     output_valid,
    output wire [$clog2(WIDTH)-1:0] output_encoded,
    output wire [WIDTH-1:0]         output_unencoded
);

parameter LEVELS = WIDTH > 2 ? $clog2(WIDTH) : 1;
parameter W = 2**LEVELS;

// pad input to even power of two
wire [W-1:0] input_padded = {{W-WIDTH{1'b0}}, input_unencoded};

wire [W/2-1:0] stage_valid[LEVELS-1:0];
wire [W/2-1:0] stage_enc[LEVELS-1:0];

generate
    genvar l, n;

    // process input bits; generate valid bit and encoded bit for each pair
    for (n = 0; n < W/2; n = n + 1) begin : loop_in
        assign stage_valid[0][n] = |input_padded[n*2+1:n*2];
        if (LSB_HIGH_PRIORITY) begin
            // bit 0 is highest priority
            assign stage_enc[0][n] = !input_padded[n*2+0];
        end else begin
            // bit 0 is lowest priority
            assign stage_enc[0][n] = input_padded[n*2+1];
        end
    end

    // compress down to single valid bit and encoded bus
    for (l = 1; l < LEVELS; l = l + 1) begin : loop_levels
        for (n = 0; n < W/(2*2**l); n = n + 1) begin : loop_compress
            assign stage_valid[l][n] = |stage_valid[l-1][n*2+1:n*2];
            if (LSB_HIGH_PRIORITY) begin
                // bit 0 is highest priority
                assign stage_enc[l][(n+1)*(l+1)-1:n*(l+1)] = stage_valid[l-1][n*2+0] ? {1'b0, stage_enc[l-1][(n*2+1)*l-1:(n*2+0)*l]} : {1'b1, stage_enc[l-1][(n*2+2)*l-1:(n*2+1)*l]};
            end else begin
                // bit 0 is lowest priority
                assign stage_enc[l][(n+1)*(l+1)-1:n*(l+1)] = stage_valid[l-1][n*2+1] ? {1'b1, stage_enc[l-1][(n*2+2)*l-1:(n*2+1)*l]} : {1'b0, stage_enc[l-1][(n*2+1)*l-1:(n*2+0)*l]};
            end
        end
    end
endgenerate

assign output_valid = stage_valid[LEVELS-1];
assign output_encoded = stage_enc[LEVELS-1];
assign output_unencoded = 1 << output_encoded;

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/lib/axis/rtl/axis_fifo.v ===== */
/*

Copyright (c) 2013-2023 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream FIFO
 */
module axis_fifo #
(
    // FIFO depth in words
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter DEPTH = 4096,
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    // Propagate tlast signal
    parameter LAST_ENABLE = 1,
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // number of RAM pipeline registers
    parameter RAM_PIPELINE = 1,
    // use output FIFO
    // When set, the RAM read enable and pipeline clock enables are removed
    parameter OUTPUT_FIFO_ENABLE = 0,
    // Frame FIFO mode - operate on frames instead of cycles
    // When set, m_axis_tvalid will not be deasserted within a frame
    // Requires LAST_ENABLE set
    parameter FRAME_FIFO = 0,
    // tuser value for bad frame marker
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    // tuser mask for bad frame marker
    parameter USER_BAD_FRAME_MASK = 1'b1,
    // Drop frames larger than FIFO
    // Requires FRAME_FIFO set
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    // Drop frames marked bad
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_BAD_FRAME = 0,
    // Drop incoming frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_WHEN_FULL = 0,
    // Mark incoming frames as bad frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO to be clear
    parameter MARK_WHEN_FULL = 0,
    // Enable pause request input
    parameter PAUSE_ENABLE = 0,
    // Pause between frames
    parameter FRAME_PAUSE = FRAME_FIFO
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [ID_WIDTH-1:0]    s_axis_tid,
    input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [ID_WIDTH-1:0]    m_axis_tid,
    output wire [DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Pause
     */
    input  wire                   pause_req,
    output wire                   pause_ack,

    /*
     * Status
     */
    output wire [$clog2(DEPTH):0] status_depth,
    output wire [$clog2(DEPTH):0] status_depth_commit,
    output wire                   status_overflow,
    output wire                   status_bad_frame,
    output wire                   status_good_frame
);

parameter ADDR_WIDTH = (KEEP_ENABLE && KEEP_WIDTH > 1) ? $clog2(DEPTH/KEEP_WIDTH) : $clog2(DEPTH);

parameter OUTPUT_FIFO_ADDR_WIDTH = RAM_PIPELINE < 2 ? 3 : $clog2(RAM_PIPELINE*2+7);

// check configuration
initial begin
    if (FRAME_FIFO && !LAST_ENABLE) begin
        $error("Error: FRAME_FIFO set requires LAST_ENABLE set (instance %m)");
        $finish;
    end

    if (DROP_OVERSIZE_FRAME && !FRAME_FIFO) begin
        $error("Error: DROP_OVERSIZE_FRAME set requires FRAME_FIFO set (instance %m)");
        $finish;
    end

    if (DROP_BAD_FRAME && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_BAD_FRAME set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if (DROP_WHEN_FULL && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_WHEN_FULL set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if ((DROP_BAD_FRAME || MARK_WHEN_FULL) && (USER_BAD_FRAME_MASK & {USER_WIDTH{1'b1}}) == 0) begin
        $error("Error: Invalid USER_BAD_FRAME_MASK value (instance %m)");
        $finish;
    end

    if (MARK_WHEN_FULL && FRAME_FIFO) begin
        $error("Error: MARK_WHEN_FULL is not compatible with FRAME_FIFO (instance %m)");
        $finish;
    end

    if (MARK_WHEN_FULL && !LAST_ENABLE) begin
        $error("Error: MARK_WHEN_FULL set requires LAST_ENABLE set (instance %m)");
        $finish;
    end
end

localparam KEEP_OFFSET = DATA_WIDTH;
localparam LAST_OFFSET = KEEP_OFFSET + (KEEP_ENABLE ? KEEP_WIDTH : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_ENABLE ? 1          : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_ENABLE   ? ID_WIDTH   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_ENABLE ? DEST_WIDTH : 0);
localparam WIDTH       = USER_OFFSET + (USER_ENABLE ? USER_WIDTH : 0);

reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_commit_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}};

(* ramstyle = "no_rw_check" *)
reg [WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];
reg mem_read_data_valid_reg = 1'b0;

(* shreg_extract = "no" *)
reg [WIDTH-1:0] m_axis_pipe_reg[RAM_PIPELINE+1-1:0];
reg [RAM_PIPELINE+1-1:0] m_axis_tvalid_pipe_reg = 0;

// full when first MSB different but rest same
wire full = wr_ptr_reg == (rd_ptr_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}});
// empty when pointers match exactly
wire empty = wr_ptr_commit_reg == rd_ptr_reg;
// overflow within packet
wire full_wr = wr_ptr_reg == (wr_ptr_commit_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}});

reg s_frame_reg = 1'b0;

reg drop_frame_reg = 1'b0;
reg mark_frame_reg = 1'b0;
reg send_frame_reg = 1'b0;
reg [ADDR_WIDTH:0] depth_reg = 0;
reg [ADDR_WIDTH:0] depth_commit_reg = 0;
reg overflow_reg = 1'b0;
reg bad_frame_reg = 1'b0;
reg good_frame_reg = 1'b0;

assign s_axis_tready = FRAME_FIFO ? (!full || (full_wr && DROP_OVERSIZE_FRAME) || DROP_WHEN_FULL) : (!full || MARK_WHEN_FULL);

wire [WIDTH-1:0] s_axis;

generate
    assign s_axis[DATA_WIDTH-1:0] = s_axis_tdata;
    if (KEEP_ENABLE) assign s_axis[KEEP_OFFSET +: KEEP_WIDTH] = s_axis_tkeep;
    if (LAST_ENABLE) assign s_axis[LAST_OFFSET]               = s_axis_tlast | mark_frame_reg;
    if (ID_ENABLE)   assign s_axis[ID_OFFSET   +: ID_WIDTH]   = s_axis_tid;
    if (DEST_ENABLE) assign s_axis[DEST_OFFSET +: DEST_WIDTH] = s_axis_tdest;
    if (USER_ENABLE) assign s_axis[USER_OFFSET +: USER_WIDTH] = mark_frame_reg ? USER_BAD_FRAME_VALUE : s_axis_tuser;
endgenerate

wire [WIDTH-1:0] m_axis = m_axis_pipe_reg[RAM_PIPELINE+1-1];

wire                   m_axis_tready_pipe;
wire                   m_axis_tvalid_pipe = m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1];

wire [DATA_WIDTH-1:0]  m_axis_tdata_pipe  = m_axis[DATA_WIDTH-1:0];
wire [KEEP_WIDTH-1:0]  m_axis_tkeep_pipe  = KEEP_ENABLE ? m_axis[KEEP_OFFSET +: KEEP_WIDTH] : {KEEP_WIDTH{1'b1}};
wire                   m_axis_tlast_pipe  = LAST_ENABLE ? m_axis[LAST_OFFSET] : 1'b1;
wire [ID_WIDTH-1:0]    m_axis_tid_pipe    = ID_ENABLE   ? m_axis[ID_OFFSET +: ID_WIDTH] : {ID_WIDTH{1'b0}};
wire [DEST_WIDTH-1:0]  m_axis_tdest_pipe  = DEST_ENABLE ? m_axis[DEST_OFFSET +: DEST_WIDTH] : {DEST_WIDTH{1'b0}};
wire [USER_WIDTH-1:0]  m_axis_tuser_pipe  = USER_ENABLE ? m_axis[USER_OFFSET +: USER_WIDTH] : {USER_WIDTH{1'b0}};

wire                   m_axis_tready_out;
wire                   m_axis_tvalid_out;

wire [DATA_WIDTH-1:0]  m_axis_tdata_out;
wire [KEEP_WIDTH-1:0]  m_axis_tkeep_out;
wire                   m_axis_tlast_out;
wire [ID_WIDTH-1:0]    m_axis_tid_out;
wire [DEST_WIDTH-1:0]  m_axis_tdest_out;
wire [USER_WIDTH-1:0]  m_axis_tuser_out;

wire pipe_ready;

assign status_depth = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {depth_reg, {$clog2(KEEP_WIDTH){1'b0}}} : depth_reg;
assign status_depth_commit = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {depth_commit_reg, {$clog2(KEEP_WIDTH){1'b0}}} : depth_commit_reg;
assign status_overflow = overflow_reg;
assign status_bad_frame = bad_frame_reg;
assign status_good_frame = good_frame_reg;

// Write logic
always @(posedge clk) begin
    overflow_reg <= 1'b0;
    bad_frame_reg <= 1'b0;
    good_frame_reg <= 1'b0;

    if (s_axis_tready && s_axis_tvalid && LAST_ENABLE) begin
        // track input frame status
        s_frame_reg <= !s_axis_tlast;
    end

    if (FRAME_FIFO) begin
        // frame FIFO mode
        if (s_axis_tready && s_axis_tvalid) begin
            // transfer in
            if ((full && DROP_WHEN_FULL) || (full_wr && DROP_OVERSIZE_FRAME) || drop_frame_reg) begin
                // full, packet overflow, or currently dropping frame
                // drop frame
                drop_frame_reg <= 1'b1;
                if (s_axis_tlast) begin
                    // end of frame, reset write pointer
                    wr_ptr_reg <= wr_ptr_commit_reg;
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else begin
                // store it
                mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                wr_ptr_reg <= wr_ptr_reg + 1;
                if (s_axis_tlast || (!DROP_OVERSIZE_FRAME && (full_wr || send_frame_reg))) begin
                    // end of frame or send frame
                    send_frame_reg <= !s_axis_tlast;
                    if (s_axis_tlast && DROP_BAD_FRAME && USER_BAD_FRAME_MASK & ~(s_axis_tuser ^ USER_BAD_FRAME_VALUE)) begin
                        // bad packet, reset write pointer
                        wr_ptr_reg <= wr_ptr_commit_reg;
                        bad_frame_reg <= 1'b1;
                    end else begin
                        // good packet or packet overflow, update write pointer
                        wr_ptr_commit_reg <= wr_ptr_reg + 1;
                        good_frame_reg <= s_axis_tlast;
                    end
                end
            end
        end else if (s_axis_tvalid && full_wr && !DROP_OVERSIZE_FRAME) begin
            // data valid with packet overflow
            // update write pointer
            send_frame_reg <= 1'b1;
            wr_ptr_commit_reg <= wr_ptr_reg;
        end
    end else begin
        // normal FIFO mode
        if (s_axis_tready && s_axis_tvalid) begin
            if (drop_frame_reg && MARK_WHEN_FULL) begin
                // currently dropping frame
                if (s_axis_tlast) begin
                    // end of frame
                    if (!full && mark_frame_reg) begin
                        // terminate marked frame
                        mark_frame_reg <= 1'b0;
                        mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                        wr_ptr_reg <= wr_ptr_reg + 1;
                        wr_ptr_commit_reg <= wr_ptr_reg + 1;
                    end
                    // end of frame, clear drop flag
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else if ((full || mark_frame_reg) && MARK_WHEN_FULL) begin
                // full or marking frame
                // drop frame; mark if this isn't the first cycle
                drop_frame_reg <= 1'b1;
                mark_frame_reg <= mark_frame_reg || s_frame_reg;
                if (s_axis_tlast) begin
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else begin
                // transfer in
                mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                wr_ptr_reg <= wr_ptr_reg + 1;
                wr_ptr_commit_reg <= wr_ptr_reg + 1;
            end
        end else if ((!full && !drop_frame_reg && mark_frame_reg) && MARK_WHEN_FULL) begin
            // terminate marked frame
            mark_frame_reg <= 1'b0;
            mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
            wr_ptr_reg <= wr_ptr_reg + 1;
            wr_ptr_commit_reg <= wr_ptr_reg + 1;
        end
    end

    if (rst) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_commit_reg <= {ADDR_WIDTH+1{1'b0}};

        s_frame_reg <= 1'b0;

        drop_frame_reg <= 1'b0;
        mark_frame_reg <= 1'b0;
        send_frame_reg <= 1'b0;
        overflow_reg <= 1'b0;
        bad_frame_reg <= 1'b0;
        good_frame_reg <= 1'b0;
    end
end

// Status
always @(posedge clk) begin
    depth_reg <= wr_ptr_reg - rd_ptr_reg;
    depth_commit_reg <= wr_ptr_commit_reg - rd_ptr_reg;
end

// Read logic
integer j;

always @(posedge clk) begin
    if (m_axis_tready_pipe) begin
        // output ready; invalidate stage
        m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1] <= 1'b0;
    end

    for (j = RAM_PIPELINE+1-1; j > 0; j = j - 1) begin
        if (m_axis_tready_pipe || ((~m_axis_tvalid_pipe_reg) >> j)) begin
            // output ready or bubble in pipeline; transfer down pipeline
            m_axis_tvalid_pipe_reg[j] <= m_axis_tvalid_pipe_reg[j-1];
            m_axis_pipe_reg[j] <= m_axis_pipe_reg[j-1];
            m_axis_tvalid_pipe_reg[j-1] <= 1'b0;
        end
    end

    if (m_axis_tready_pipe || ~m_axis_tvalid_pipe_reg) begin
        // output ready or bubble in pipeline; read new data from FIFO
        m_axis_tvalid_pipe_reg[0] <= 1'b0;
        m_axis_pipe_reg[0] <= mem[rd_ptr_reg[ADDR_WIDTH-1:0]];
        if (!empty && pipe_ready) begin
            // not empty, increment pointer
            m_axis_tvalid_pipe_reg[0] <= 1'b1;
            rd_ptr_reg <= rd_ptr_reg + 1;
        end
    end

    if (rst) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        m_axis_tvalid_pipe_reg <= 0;
    end
end

generate

if (!OUTPUT_FIFO_ENABLE) begin

    assign pipe_ready = 1'b1;

    assign m_axis_tready_pipe = m_axis_tready_out;
    assign m_axis_tvalid_out = m_axis_tvalid_pipe;

    assign m_axis_tdata_out = m_axis_tdata_pipe;
    assign m_axis_tkeep_out = m_axis_tkeep_pipe;
    assign m_axis_tlast_out = m_axis_tlast_pipe;
    assign m_axis_tid_out   = m_axis_tid_pipe;
    assign m_axis_tdest_out = m_axis_tdest_pipe;
    assign m_axis_tuser_out = m_axis_tuser_pipe;

end else begin : output_fifo

    // output datapath logic
    reg [DATA_WIDTH-1:0] m_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
    reg [KEEP_WIDTH-1:0] m_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
    reg                  m_axis_tvalid_reg = 1'b0;
    reg                  m_axis_tlast_reg  = 1'b0;
    reg [ID_WIDTH-1:0]   m_axis_tid_reg    = {ID_WIDTH{1'b0}};
    reg [DEST_WIDTH-1:0] m_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
    reg [USER_WIDTH-1:0] m_axis_tuser_reg  = {USER_WIDTH{1'b0}};

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [KEEP_WIDTH-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg                  out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [ID_WIDTH-1:0]   out_fifo_tid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [DEST_WIDTH-1:0] out_fifo_tdest[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    assign pipe_ready = !out_fifo_half_full_reg;

    assign m_axis_tready_pipe = 1'b1;

    assign m_axis_tdata_out  = m_axis_tdata_reg;
    assign m_axis_tkeep_out  = KEEP_ENABLE ? m_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
    assign m_axis_tvalid_out = m_axis_tvalid_reg;
    assign m_axis_tlast_out  = LAST_ENABLE ? m_axis_tlast_reg : 1'b1;
    assign m_axis_tid_out    = ID_ENABLE   ? m_axis_tid_reg   : {ID_WIDTH{1'b0}};
    assign m_axis_tdest_out  = DEST_ENABLE ? m_axis_tdest_reg : {DEST_WIDTH{1'b0}};
    assign m_axis_tuser_out  = USER_ENABLE ? m_axis_tuser_reg : {USER_WIDTH{1'b0}};

    always @(posedge clk) begin
        m_axis_tvalid_reg <= m_axis_tvalid_reg && !m_axis_tready_out;

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && m_axis_tvalid_pipe) begin
            out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdata_pipe;
            out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tkeep_pipe;
            out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tlast_pipe;
            out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tid_pipe;
            out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdest_pipe;
            out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tuser_pipe;
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!m_axis_tvalid_reg || m_axis_tready_out)) begin
            m_axis_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tvalid_reg <= 1'b1;
            m_axis_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            m_axis_tvalid_reg <= 1'b0;
        end
    end

end

if (PAUSE_ENABLE) begin : pause

    // Pause logic
    reg pause_reg = 1'b0;
    reg pause_frame_reg = 1'b0;

    assign m_axis_tready_out = m_axis_tready && !pause_reg;
    assign m_axis_tvalid = m_axis_tvalid_out && !pause_reg;

    assign m_axis_tdata = m_axis_tdata_out;
    assign m_axis_tkeep = m_axis_tkeep_out;
    assign m_axis_tlast = m_axis_tlast_out;
    assign m_axis_tid   = m_axis_tid_out;
    assign m_axis_tdest = m_axis_tdest_out;
    assign m_axis_tuser = m_axis_tuser_out;

    assign pause_ack = pause_reg;

    always @(posedge clk) begin
        if (FRAME_PAUSE) begin
            if (pause_reg) begin
                // paused; update pause status
                pause_reg <= pause_req;
            end else if (m_axis_tvalid_out) begin
                // frame transfer; set frame bit
                pause_frame_reg <= 1'b1;
                if (m_axis_tready && m_axis_tlast) begin
                    // end of frame; clear frame bit and update pause status
                    pause_frame_reg <= 1'b0;
                    pause_reg <= pause_req;
                end
            end else if (!pause_frame_reg) begin
                // idle; update pause status
                pause_reg <= pause_req;
            end
        end else begin
            pause_reg <= pause_req;
        end

        if (rst) begin
            pause_frame_reg <= 1'b0;
            pause_reg <= 1'b0;
        end
    end

end else begin

    assign m_axis_tready_out = m_axis_tready;
    assign m_axis_tvalid = m_axis_tvalid_out;

    assign m_axis_tdata = m_axis_tdata_out;
    assign m_axis_tkeep = m_axis_tkeep_out;
    assign m_axis_tlast = m_axis_tlast_out;
    assign m_axis_tid   = m_axis_tid_out;
    assign m_axis_tdest = m_axis_tdest_out;
    assign m_axis_tuser = m_axis_tuser_out;

    assign pause_ack = 1'b0;

end

endgenerate

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/lib/axis/rtl/axis_async_fifo.v ===== */
/*

Copyright (c) 2014-2023 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream asynchronous FIFO
 */
module axis_async_fifo #
(
    // FIFO depth in words
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter DEPTH = 4096,
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    // Propagate tlast signal
    parameter LAST_ENABLE = 1,
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // number of RAM pipeline registers
    parameter RAM_PIPELINE = 1,
    // use output FIFO
    // When set, the RAM read enable and pipeline clock enables are removed
    parameter OUTPUT_FIFO_ENABLE = 0,
    // Frame FIFO mode - operate on frames instead of cycles
    // When set, m_axis_tvalid will not be deasserted within a frame
    // Requires LAST_ENABLE set
    parameter FRAME_FIFO = 0,
    // tuser value for bad frame marker
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    // tuser mask for bad frame marker
    parameter USER_BAD_FRAME_MASK = 1'b1,
    // Drop frames larger than FIFO
    // Requires FRAME_FIFO set
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    // Drop frames marked bad
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_BAD_FRAME = 0,
    // Drop incoming frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_WHEN_FULL = 0,
    // Mark incoming frames as bad frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO to be clear
    parameter MARK_WHEN_FULL = 0,
    // Enable pause request input
    parameter PAUSE_ENABLE = 0,
    // Pause between frames
    parameter FRAME_PAUSE = FRAME_FIFO
)
(
    /*
     * AXI input
     */
    input  wire                   s_clk,
    input  wire                   s_rst,
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [ID_WIDTH-1:0]    s_axis_tid,
    input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    input  wire                   m_clk,
    input  wire                   m_rst,
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [ID_WIDTH-1:0]    m_axis_tid,
    output wire [DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Pause
     */
    input  wire                   s_pause_req,
    output wire                   s_pause_ack,
    input  wire                   m_pause_req,
    output wire                   m_pause_ack,

    /*
     * Status
     */
    output wire [$clog2(DEPTH):0] s_status_depth,
    output wire [$clog2(DEPTH):0] s_status_depth_commit,
    output wire                   s_status_overflow,
    output wire                   s_status_bad_frame,
    output wire                   s_status_good_frame,
    output wire [$clog2(DEPTH):0] m_status_depth,
    output wire [$clog2(DEPTH):0] m_status_depth_commit,
    output wire                   m_status_overflow,
    output wire                   m_status_bad_frame,
    output wire                   m_status_good_frame
);

parameter ADDR_WIDTH = (KEEP_ENABLE && KEEP_WIDTH > 1) ? $clog2(DEPTH/KEEP_WIDTH) : $clog2(DEPTH);

parameter OUTPUT_FIFO_ADDR_WIDTH = RAM_PIPELINE < 2 ? 3 : $clog2(RAM_PIPELINE*2+7);

// check configuration
initial begin
    if (FRAME_FIFO && !LAST_ENABLE) begin
        $error("Error: FRAME_FIFO set requires LAST_ENABLE set (instance %m)");
        $finish;
    end

    if (DROP_OVERSIZE_FRAME && !FRAME_FIFO) begin
        $error("Error: DROP_OVERSIZE_FRAME set requires FRAME_FIFO set (instance %m)");
        $finish;
    end

    if (DROP_BAD_FRAME && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_BAD_FRAME set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if (DROP_WHEN_FULL && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_WHEN_FULL set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if ((DROP_BAD_FRAME || MARK_WHEN_FULL) && (USER_BAD_FRAME_MASK & {USER_WIDTH{1'b1}}) == 0) begin
        $error("Error: Invalid USER_BAD_FRAME_MASK value (instance %m)");
        $finish;
    end

    if (MARK_WHEN_FULL && FRAME_FIFO) begin
        $error("Error: MARK_WHEN_FULL is not compatible with FRAME_FIFO (instance %m)");
        $finish;
    end

    if (MARK_WHEN_FULL && !LAST_ENABLE) begin
        $error("Error: MARK_WHEN_FULL set requires LAST_ENABLE set (instance %m)");
        $finish;
    end
end

localparam KEEP_OFFSET = DATA_WIDTH;
localparam LAST_OFFSET = KEEP_OFFSET + (KEEP_ENABLE ? KEEP_WIDTH : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_ENABLE ? 1          : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_ENABLE   ? ID_WIDTH   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_ENABLE ? DEST_WIDTH : 0);
localparam WIDTH       = USER_OFFSET + (USER_ENABLE ? USER_WIDTH : 0);

function [ADDR_WIDTH:0] bin2gray(input [ADDR_WIDTH:0] b);
    bin2gray = b ^ (b >> 1);
endfunction

function [ADDR_WIDTH:0] gray2bin(input [ADDR_WIDTH:0] g);
    integer i;
    for (i = 0; i <= ADDR_WIDTH; i = i + 1) begin
        gray2bin[i] = ^(g >> i);
    end
endfunction

reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_commit_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_sync_commit_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_conv_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_conv_reg = {ADDR_WIDTH+1{1'b0}};

reg [ADDR_WIDTH:0] wr_ptr_temp;
reg [ADDR_WIDTH:0] rd_ptr_temp;

(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] wr_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] wr_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] wr_ptr_commit_sync_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] rd_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
(* SHREG_EXTRACT = "NO" *)
reg [ADDR_WIDTH:0] rd_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};

reg wr_ptr_update_valid_reg = 1'b0;
reg wr_ptr_update_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_sync1_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_sync2_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_sync3_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_ack_sync1_reg = 1'b0;
(* SHREG_EXTRACT = "NO" *)
reg wr_ptr_update_ack_sync2_reg = 1'b0;

(* SHREG_EXTRACT = "NO" *)
reg s_rst_sync1_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg s_rst_sync2_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg s_rst_sync3_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg m_rst_sync1_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg m_rst_sync2_reg = 1'b1;
(* SHREG_EXTRACT = "NO" *)
reg m_rst_sync3_reg = 1'b1;

(* ramstyle = "no_rw_check" *)
reg [WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];
reg mem_read_data_valid_reg = 1'b0;

(* shreg_extract = "no" *)
reg [WIDTH-1:0] m_axis_pipe_reg[RAM_PIPELINE+1-1:0];
reg [RAM_PIPELINE+1-1:0] m_axis_tvalid_pipe_reg = 0;

// full when first TWO MSBs do NOT match, but rest matches
// (gray code equivalent of first MSB different but rest same)
wire full = wr_ptr_gray_reg == (rd_ptr_gray_sync2_reg ^ {2'b11, {ADDR_WIDTH-1{1'b0}}});
// empty when pointers match exactly
wire empty = FRAME_FIFO ? (rd_ptr_reg == wr_ptr_commit_sync_reg) : (rd_ptr_gray_reg == wr_ptr_gray_sync2_reg);
// overflow within packet
wire full_wr = wr_ptr_reg == (wr_ptr_commit_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}});

// control signals
reg write;
reg read;
reg store_output;

reg s_frame_reg = 1'b0;
reg m_frame_reg = 1'b0;

reg drop_frame_reg = 1'b0;
reg mark_frame_reg = 1'b0;
reg send_frame_reg = 1'b0;
reg overflow_reg = 1'b0;
reg bad_frame_reg = 1'b0;
reg good_frame_reg = 1'b0;

reg m_drop_frame_reg = 1'b0;
reg m_terminate_frame_reg = 1'b0;

reg [ADDR_WIDTH:0] s_depth_reg = 0;
reg [ADDR_WIDTH:0] s_depth_commit_reg = 0;
reg [ADDR_WIDTH:0] m_depth_reg = 0;
reg [ADDR_WIDTH:0] m_depth_commit_reg = 0;

reg overflow_sync1_reg = 1'b0;
reg overflow_sync2_reg = 1'b0;
reg overflow_sync3_reg = 1'b0;
reg overflow_sync4_reg = 1'b0;
reg bad_frame_sync1_reg = 1'b0;
reg bad_frame_sync2_reg = 1'b0;
reg bad_frame_sync3_reg = 1'b0;
reg bad_frame_sync4_reg = 1'b0;
reg good_frame_sync1_reg = 1'b0;
reg good_frame_sync2_reg = 1'b0;
reg good_frame_sync3_reg = 1'b0;
reg good_frame_sync4_reg = 1'b0;

assign s_axis_tready = (FRAME_FIFO ? (!full || (full_wr && DROP_OVERSIZE_FRAME) || DROP_WHEN_FULL) : (!full || MARK_WHEN_FULL)) && !s_rst_sync3_reg;

wire [WIDTH-1:0] s_axis;

generate
    assign s_axis[DATA_WIDTH-1:0] = s_axis_tdata;
    if (KEEP_ENABLE) assign s_axis[KEEP_OFFSET +: KEEP_WIDTH] = s_axis_tkeep;
    if (LAST_ENABLE) assign s_axis[LAST_OFFSET]               = s_axis_tlast | mark_frame_reg;
    if (ID_ENABLE)   assign s_axis[ID_OFFSET   +: ID_WIDTH]   = s_axis_tid;
    if (DEST_ENABLE) assign s_axis[DEST_OFFSET +: DEST_WIDTH] = s_axis_tdest;
    if (USER_ENABLE) assign s_axis[USER_OFFSET +: USER_WIDTH] = mark_frame_reg ? USER_BAD_FRAME_VALUE : s_axis_tuser;
endgenerate

wire [WIDTH-1:0] m_axis = m_axis_pipe_reg[RAM_PIPELINE+1-1];

wire                   m_axis_tready_pipe;
wire                   m_axis_tvalid_pipe = m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1];

wire [DATA_WIDTH-1:0]  m_axis_tdata_pipe  = m_axis[DATA_WIDTH-1:0];
wire [KEEP_WIDTH-1:0]  m_axis_tkeep_pipe  = KEEP_ENABLE ? m_axis[KEEP_OFFSET +: KEEP_WIDTH] : {KEEP_WIDTH{1'b1}};
wire                   m_axis_tlast_pipe  = LAST_ENABLE ? m_axis[LAST_OFFSET] | m_terminate_frame_reg : 1'b1;
wire [ID_WIDTH-1:0]    m_axis_tid_pipe    = ID_ENABLE   ? m_axis[ID_OFFSET +: ID_WIDTH] : {ID_WIDTH{1'b0}};
wire [DEST_WIDTH-1:0]  m_axis_tdest_pipe  = DEST_ENABLE ? m_axis[DEST_OFFSET +: DEST_WIDTH] : {DEST_WIDTH{1'b0}};
wire [USER_WIDTH-1:0]  m_axis_tuser_pipe  = USER_ENABLE ? (m_terminate_frame_reg ? USER_BAD_FRAME_VALUE : m_axis[USER_OFFSET +: USER_WIDTH]) : {USER_WIDTH{1'b0}};

wire                   m_axis_tready_out;
wire                   m_axis_tvalid_out;

wire [DATA_WIDTH-1:0]  m_axis_tdata_out;
wire [KEEP_WIDTH-1:0]  m_axis_tkeep_out;
wire                   m_axis_tlast_out;
wire [ID_WIDTH-1:0]    m_axis_tid_out;
wire [DEST_WIDTH-1:0]  m_axis_tdest_out;
wire [USER_WIDTH-1:0]  m_axis_tuser_out;

wire pipe_ready;

assign s_status_depth = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {s_depth_reg, {$clog2(KEEP_WIDTH){1'b0}}} : s_depth_reg;
assign s_status_depth_commit = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {s_depth_commit_reg, {$clog2(KEEP_WIDTH){1'b0}}} : s_depth_commit_reg;
assign s_status_overflow = overflow_reg;
assign s_status_bad_frame = bad_frame_reg;
assign s_status_good_frame = good_frame_reg;

assign m_status_depth = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {m_depth_reg, {$clog2(KEEP_WIDTH){1'b0}}} : m_depth_reg;
assign m_status_depth_commit = (KEEP_ENABLE && KEEP_WIDTH > 1) ? {m_depth_commit_reg, {$clog2(KEEP_WIDTH){1'b0}}} : m_depth_commit_reg;
assign m_status_overflow = overflow_sync3_reg ^ overflow_sync4_reg;
assign m_status_bad_frame = bad_frame_sync3_reg ^ bad_frame_sync4_reg;
assign m_status_good_frame = good_frame_sync3_reg ^ good_frame_sync4_reg;

// reset synchronization
always @(posedge m_clk or posedge m_rst) begin
    if (m_rst) begin
        s_rst_sync1_reg <= 1'b1;
    end else begin
        s_rst_sync1_reg <= 1'b0;
    end
end

always @(posedge s_clk) begin
    s_rst_sync2_reg <= s_rst_sync1_reg;
    s_rst_sync3_reg <= s_rst_sync2_reg;
end

always @(posedge s_clk or posedge s_rst) begin
    if (s_rst) begin
        m_rst_sync1_reg <= 1'b1;
    end else begin
        m_rst_sync1_reg <= 1'b0;
    end
end

always @(posedge m_clk) begin
    m_rst_sync2_reg <= m_rst_sync1_reg;
    m_rst_sync3_reg <= m_rst_sync2_reg;
end

// Write logic
always @(posedge s_clk) begin
    overflow_reg <= 1'b0;
    bad_frame_reg <= 1'b0;
    good_frame_reg <= 1'b0;

    if (FRAME_FIFO && wr_ptr_update_valid_reg) begin
        // have updated pointer to sync
        if (wr_ptr_update_reg == wr_ptr_update_ack_sync2_reg) begin
            // no sync in progress; sync update
            wr_ptr_update_valid_reg <= 1'b0;
            wr_ptr_sync_commit_reg <= wr_ptr_commit_reg;
            wr_ptr_update_reg <= !wr_ptr_update_ack_sync2_reg;
        end
    end

    if (s_axis_tready && s_axis_tvalid && LAST_ENABLE) begin
        // track input frame status
        s_frame_reg <= !s_axis_tlast;
    end

    if (s_rst_sync3_reg && LAST_ENABLE) begin
        // if sink side is reset during transfer, drop partial frame
        if (s_frame_reg && !(s_axis_tready && s_axis_tvalid && s_axis_tlast)) begin
            drop_frame_reg <= 1'b1;
        end
        if (s_axis_tready && s_axis_tvalid && !s_axis_tlast) begin
            drop_frame_reg <= 1'b1;
        end
    end

    if (FRAME_FIFO) begin
        // frame FIFO mode
        if (s_axis_tready && s_axis_tvalid) begin
            // transfer in
            if ((full && DROP_WHEN_FULL) || (full_wr && DROP_OVERSIZE_FRAME) || drop_frame_reg) begin
                // full, packet overflow, or currently dropping frame
                // drop frame
                drop_frame_reg <= 1'b1;
                if (s_axis_tlast) begin
                    // end of frame, reset write pointer
                    wr_ptr_temp = wr_ptr_commit_reg;
                    wr_ptr_reg <= wr_ptr_temp;
                    wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else begin
                mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                wr_ptr_temp = wr_ptr_reg + 1;
                wr_ptr_reg <= wr_ptr_temp;
                wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                if (s_axis_tlast || (!DROP_OVERSIZE_FRAME && (full_wr || send_frame_reg))) begin
                    // end of frame or send frame
                    send_frame_reg <= !s_axis_tlast;
                    if (s_axis_tlast && DROP_BAD_FRAME && USER_BAD_FRAME_MASK & ~(s_axis_tuser ^ USER_BAD_FRAME_VALUE)) begin
                        // bad packet, reset write pointer
                        wr_ptr_temp = wr_ptr_commit_reg;
                        wr_ptr_reg <= wr_ptr_temp;
                        wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                        bad_frame_reg <= 1'b1;
                    end else begin
                        // good packet or packet overflow, update write pointer
                        wr_ptr_temp = wr_ptr_reg + 1;
                        wr_ptr_reg <= wr_ptr_temp;
                        wr_ptr_commit_reg <= wr_ptr_temp;
                        wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);

                        if (wr_ptr_update_reg == wr_ptr_update_ack_sync2_reg) begin
                            // no sync in progress; sync update
                            wr_ptr_update_valid_reg <= 1'b0;
                            wr_ptr_sync_commit_reg <= wr_ptr_temp;
                            wr_ptr_update_reg <= !wr_ptr_update_ack_sync2_reg;
                        end else begin
                            // sync in progress; flag it for later
                            wr_ptr_update_valid_reg <= 1'b1;
                        end

                        good_frame_reg <= s_axis_tlast;
                    end
                end
            end
        end else if (s_axis_tvalid && full_wr && FRAME_FIFO && !DROP_OVERSIZE_FRAME) begin
            // data valid with packet overflow
            // update write pointer
            send_frame_reg <= 1'b1;
            wr_ptr_temp = wr_ptr_reg;
            wr_ptr_reg <= wr_ptr_temp;
            wr_ptr_commit_reg <= wr_ptr_temp;
            wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);

            if (wr_ptr_update_reg == wr_ptr_update_ack_sync2_reg) begin
                // no sync in progress; sync update
                wr_ptr_update_valid_reg <= 1'b0;
                wr_ptr_sync_commit_reg <= wr_ptr_temp;
                wr_ptr_update_reg <= !wr_ptr_update_ack_sync2_reg;
            end else begin
                // sync in progress; flag it for later
                wr_ptr_update_valid_reg <= 1'b1;
            end
        end
    end else begin
        // normal FIFO mode
        if (s_axis_tready && s_axis_tvalid) begin
            if (drop_frame_reg && LAST_ENABLE) begin
                // currently dropping frame
                if (s_axis_tlast) begin
                    // end of frame
                    if (!full && mark_frame_reg && MARK_WHEN_FULL) begin
                        // terminate marked frame
                        mark_frame_reg <= 1'b0;
                        mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                        wr_ptr_temp = wr_ptr_reg + 1;
                        wr_ptr_reg <= wr_ptr_temp;
                        wr_ptr_commit_reg <= wr_ptr_temp;
                        wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
                    end
                    // end of frame, clear drop flag
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else if ((full || mark_frame_reg) && MARK_WHEN_FULL) begin
                // full or marking frame
                // drop frame; mark if this isn't the first cycle
                drop_frame_reg <= 1'b1;
                mark_frame_reg <= mark_frame_reg || s_frame_reg;
                if (s_axis_tlast) begin
                    drop_frame_reg <= 1'b0;
                    overflow_reg <= 1'b1;
                end
            end else begin
                // transfer in
                mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
                wr_ptr_temp = wr_ptr_reg + 1;
                wr_ptr_reg <= wr_ptr_temp;
                wr_ptr_commit_reg <= wr_ptr_temp;
                wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
            end
        end else if ((!full && !drop_frame_reg && mark_frame_reg) && MARK_WHEN_FULL) begin
            // terminate marked frame
            mark_frame_reg <= 1'b0;
            mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
            wr_ptr_temp = wr_ptr_reg + 1;
            wr_ptr_reg <= wr_ptr_temp;
            wr_ptr_commit_reg <= wr_ptr_temp;
            wr_ptr_gray_reg <= bin2gray(wr_ptr_temp);
        end
    end

    if (s_rst_sync3_reg) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_commit_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_sync_commit_reg <= {ADDR_WIDTH+1{1'b0}};

        wr_ptr_update_valid_reg <= 1'b0;
        wr_ptr_update_reg <= 1'b0;
    end

    if (s_rst) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_commit_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_sync_commit_reg <= {ADDR_WIDTH+1{1'b0}};

        wr_ptr_update_valid_reg <= 1'b0;
        wr_ptr_update_reg <= 1'b0;

        s_frame_reg <= 1'b0;

        drop_frame_reg <= 1'b0;
        mark_frame_reg <= 1'b0;
        send_frame_reg <= 1'b0;
        overflow_reg <= 1'b0;
        bad_frame_reg <= 1'b0;
        good_frame_reg <= 1'b0;
    end
end

// Write-side status
always @(posedge s_clk) begin
    rd_ptr_conv_reg <= gray2bin(rd_ptr_gray_sync2_reg);
    s_depth_reg <= wr_ptr_reg - rd_ptr_conv_reg;
    s_depth_commit_reg <= wr_ptr_commit_reg - rd_ptr_conv_reg;
end

// pointer synchronization
always @(posedge s_clk) begin
    rd_ptr_gray_sync1_reg <= rd_ptr_gray_reg;
    rd_ptr_gray_sync2_reg <= rd_ptr_gray_sync1_reg;
    wr_ptr_update_ack_sync1_reg <= wr_ptr_update_sync3_reg;
    wr_ptr_update_ack_sync2_reg <= wr_ptr_update_ack_sync1_reg;

    if (s_rst) begin
        rd_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_update_ack_sync1_reg <= 1'b0;
        wr_ptr_update_ack_sync2_reg <= 1'b0;
    end
end

always @(posedge m_clk) begin
    wr_ptr_gray_sync1_reg <= wr_ptr_gray_reg;
    wr_ptr_gray_sync2_reg <= wr_ptr_gray_sync1_reg;
    if (FRAME_FIFO && wr_ptr_update_sync2_reg ^ wr_ptr_update_sync3_reg) begin
        wr_ptr_commit_sync_reg <= wr_ptr_sync_commit_reg;
    end
    wr_ptr_update_sync1_reg <= wr_ptr_update_reg;
    wr_ptr_update_sync2_reg <= wr_ptr_update_sync1_reg;
    wr_ptr_update_sync3_reg <= wr_ptr_update_sync2_reg;

    if (FRAME_FIFO && m_rst_sync3_reg) begin
        wr_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
    end

    if (m_rst) begin
        wr_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_commit_sync_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_update_sync1_reg <= 1'b0;
        wr_ptr_update_sync2_reg <= 1'b0;
        wr_ptr_update_sync3_reg <= 1'b0;
    end
end

// status synchronization
always @(posedge s_clk) begin
    overflow_sync1_reg <= overflow_sync1_reg ^ overflow_reg;
    bad_frame_sync1_reg <= bad_frame_sync1_reg ^ bad_frame_reg;
    good_frame_sync1_reg <= good_frame_sync1_reg ^ good_frame_reg;

    if (s_rst) begin
        overflow_sync1_reg <= 1'b0;
        bad_frame_sync1_reg <= 1'b0;
        good_frame_sync1_reg <= 1'b0;
    end
end

always @(posedge m_clk) begin
    overflow_sync2_reg <= overflow_sync1_reg;
    overflow_sync3_reg <= overflow_sync2_reg;
    overflow_sync4_reg <= overflow_sync3_reg;
    bad_frame_sync2_reg <= bad_frame_sync1_reg;
    bad_frame_sync3_reg <= bad_frame_sync2_reg;
    bad_frame_sync4_reg <= bad_frame_sync3_reg;
    good_frame_sync2_reg <= good_frame_sync1_reg;
    good_frame_sync3_reg <= good_frame_sync2_reg;
    good_frame_sync4_reg <= good_frame_sync3_reg;

    if (m_rst) begin
        overflow_sync2_reg <= 1'b0;
        overflow_sync3_reg <= 1'b0;
        overflow_sync4_reg <= 1'b0;
        bad_frame_sync2_reg <= 1'b0;
        bad_frame_sync3_reg <= 1'b0;
        bad_frame_sync4_reg <= 1'b0;
        good_frame_sync2_reg <= 1'b0;
        good_frame_sync3_reg <= 1'b0;
        good_frame_sync4_reg <= 1'b0;
    end
end

// Read logic
integer j;

always @(posedge m_clk) begin
    if (m_axis_tready_pipe) begin
        // output ready; invalidate stage
        m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1] <= 1'b0;
        m_terminate_frame_reg <= 1'b0;
    end

    for (j = RAM_PIPELINE+1-1; j > 0; j = j - 1) begin
        if (m_axis_tready_pipe || ((~m_axis_tvalid_pipe_reg) >> j)) begin
            // output ready or bubble in pipeline; transfer down pipeline
            m_axis_tvalid_pipe_reg[j] <= m_axis_tvalid_pipe_reg[j-1];
            m_axis_pipe_reg[j] <= m_axis_pipe_reg[j-1];
            m_axis_tvalid_pipe_reg[j-1] <= 1'b0;
        end
    end

    if (m_axis_tready_pipe || ~m_axis_tvalid_pipe_reg) begin
        // output ready or bubble in pipeline; read new data from FIFO
        m_axis_tvalid_pipe_reg[0] <= 1'b0;
        m_axis_pipe_reg[0] <= mem[rd_ptr_reg[ADDR_WIDTH-1:0]];
        if (!empty && !m_rst_sync3_reg && !m_drop_frame_reg && pipe_ready) begin
            // not empty, increment pointer
            m_axis_tvalid_pipe_reg[0] <= 1'b1;
            rd_ptr_temp = rd_ptr_reg + 1;
            rd_ptr_reg <= rd_ptr_temp;
            rd_ptr_gray_reg <= rd_ptr_temp ^ (rd_ptr_temp >> 1);
        end
    end

    if (m_axis_tvalid_pipe && LAST_ENABLE) begin
        // track output frame status
        if (m_axis_tlast_pipe && m_axis_tready_pipe) begin
            m_frame_reg <= 1'b0;
        end else begin
            m_frame_reg <= 1'b1;
        end
    end

    if (m_drop_frame_reg && (OUTPUT_FIFO_ENABLE ? pipe_ready : m_axis_tready_pipe || !m_axis_tvalid_pipe) && LAST_ENABLE) begin
        // terminate frame
        // (only for frame transfers interrupted by source reset)
        m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-1] <= 1'b1;
        m_terminate_frame_reg <= 1'b1;
        m_drop_frame_reg <= 1'b0;
    end

    if (m_rst_sync3_reg && LAST_ENABLE) begin
        // if source side is reset during transfer, drop partial frame

        // empty output pipeline, except for last stage
        if (RAM_PIPELINE > 0) begin
            m_axis_tvalid_pipe_reg[RAM_PIPELINE+1-2:0] <= 0;
        end

        if (m_frame_reg && (!m_axis_tvalid_pipe || (m_axis_tvalid_pipe && !m_axis_tlast_pipe)) &&
                !(m_drop_frame_reg || m_terminate_frame_reg)) begin
            // terminate frame
            m_drop_frame_reg <= 1'b1;
        end
    end

    if (m_rst_sync3_reg) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
    end

    if (m_rst) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        m_axis_tvalid_pipe_reg <= 0;
        m_frame_reg <= 1'b0;
        m_drop_frame_reg <= 1'b0;
        m_terminate_frame_reg <= 1'b0;
    end
end

// Read-side status
always @(posedge m_clk) begin
    wr_ptr_conv_reg <= gray2bin(wr_ptr_gray_sync2_reg);
    m_depth_reg <= wr_ptr_conv_reg - rd_ptr_reg;
    m_depth_commit_reg <= FRAME_FIFO ? wr_ptr_commit_sync_reg - rd_ptr_reg : wr_ptr_conv_reg - rd_ptr_reg;
end

generate

if (!OUTPUT_FIFO_ENABLE) begin

    assign pipe_ready = 1'b1;

    assign m_axis_tready_pipe = m_axis_tready_out;
    assign m_axis_tvalid_out = m_axis_tvalid_pipe;

    assign m_axis_tdata_out = m_axis_tdata_pipe;
    assign m_axis_tkeep_out = m_axis_tkeep_pipe;
    assign m_axis_tlast_out = m_axis_tlast_pipe;
    assign m_axis_tid_out   = m_axis_tid_pipe;
    assign m_axis_tdest_out = m_axis_tdest_pipe;
    assign m_axis_tuser_out = m_axis_tuser_pipe;

end else begin : output_fifo

    // output datapath logic
    reg [DATA_WIDTH-1:0] m_axis_tdata_reg  = {DATA_WIDTH{1'b0}};
    reg [KEEP_WIDTH-1:0] m_axis_tkeep_reg  = {KEEP_WIDTH{1'b0}};
    reg                  m_axis_tvalid_reg = 1'b0;
    reg                  m_axis_tlast_reg  = 1'b0;
    reg [ID_WIDTH-1:0]   m_axis_tid_reg    = {ID_WIDTH{1'b0}};
    reg [DEST_WIDTH-1:0] m_axis_tdest_reg  = {DEST_WIDTH{1'b0}};
    reg [USER_WIDTH-1:0] m_axis_tuser_reg  = {USER_WIDTH{1'b0}};

    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
    reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
    reg out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [KEEP_WIDTH-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg                  out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [ID_WIDTH-1:0]   out_fifo_tid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [DEST_WIDTH-1:0] out_fifo_tdest[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    reg [USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

    assign pipe_ready = !out_fifo_half_full_reg;

    assign m_axis_tready_pipe = 1'b1;

    assign m_axis_tdata_out  = m_axis_tdata_reg;
    assign m_axis_tkeep_out  = KEEP_ENABLE ? m_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
    assign m_axis_tvalid_out = m_axis_tvalid_reg;
    assign m_axis_tlast_out  = LAST_ENABLE ? m_axis_tlast_reg : 1'b1;
    assign m_axis_tid_out    = ID_ENABLE   ? m_axis_tid_reg   : {ID_WIDTH{1'b0}};
    assign m_axis_tdest_out  = DEST_ENABLE ? m_axis_tdest_reg : {DEST_WIDTH{1'b0}};
    assign m_axis_tuser_out  = USER_ENABLE ? m_axis_tuser_reg : {USER_WIDTH{1'b0}};

    always @(posedge m_clk) begin
        m_axis_tvalid_reg <= m_axis_tvalid_reg && !m_axis_tready_out;

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_ADDR_WIDTH-1);

        if (!out_fifo_full && m_axis_tvalid_pipe) begin
            out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdata_pipe;
            out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tkeep_pipe;
            out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tlast_pipe;
            out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tid_pipe;
            out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tdest_pipe;
            out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_tuser_pipe;
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!m_axis_tvalid_reg || m_axis_tready_out)) begin
            m_axis_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tvalid_reg <= 1'b1;
            m_axis_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            m_axis_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (m_rst) begin
            out_fifo_wr_ptr_reg <= 0;
            out_fifo_rd_ptr_reg <= 0;
            m_axis_tvalid_reg <= 1'b0;
        end
    end

end

if (PAUSE_ENABLE) begin : pause

    // Pause logic
    reg pause_reg = 1'b0;
    reg pause_frame_reg = 1'b0;

    reg s_pause_req_sync1_reg;
    reg s_pause_req_sync2_reg;
    reg s_pause_req_sync3_reg;
    reg s_pause_ack_sync1_reg;
    reg s_pause_ack_sync2_reg;
    reg s_pause_ack_sync3_reg;

    always @(posedge s_clk) begin
        s_pause_req_sync1_reg <= s_pause_req;
        s_pause_ack_sync2_reg <= s_pause_ack_sync1_reg;
        s_pause_ack_sync3_reg <= s_pause_ack_sync2_reg;
    end

    always @(posedge m_clk) begin
        s_pause_req_sync2_reg <= s_pause_req_sync1_reg;
        s_pause_req_sync3_reg <= s_pause_req_sync2_reg;
        s_pause_ack_sync1_reg <= pause_reg;
    end

    assign m_axis_tready_out = m_axis_tready && !pause_reg;
    assign m_axis_tvalid = m_axis_tvalid_out && !pause_reg;

    assign m_axis_tdata = m_axis_tdata_out;
    assign m_axis_tkeep = m_axis_tkeep_out;
    assign m_axis_tlast = m_axis_tlast_out;
    assign m_axis_tid   = m_axis_tid_out;
    assign m_axis_tdest = m_axis_tdest_out;
    assign m_axis_tuser = m_axis_tuser_out;

    assign s_pause_ack = s_pause_ack_sync3_reg;
    assign m_pause_ack = pause_reg;

    always @(posedge m_clk) begin
        if (FRAME_PAUSE) begin
            if (pause_reg) begin
                // paused; update pause status
                pause_reg <= m_pause_req || s_pause_req_sync3_reg;
            end else if (m_axis_tvalid_out) begin
                // frame transfer; set frame bit
                pause_frame_reg <= 1'b1;
                if (m_axis_tready && m_axis_tlast) begin
                    // end of frame; clear frame bit and update pause status
                    pause_frame_reg <= 1'b0;
                    pause_reg <= m_pause_req || s_pause_req_sync3_reg;
                end
            end else if (!pause_frame_reg) begin
                // idle; update pause status
                pause_reg <= m_pause_req || s_pause_req_sync3_reg;
            end
        end else begin
            pause_reg <= m_pause_req || s_pause_req_sync3_reg;
        end

        if (m_rst) begin
            pause_frame_reg <= 1'b0;
            pause_reg <= 1'b0;
        end
    end

end else begin

    assign m_axis_tready_out = m_axis_tready;
    assign m_axis_tvalid = m_axis_tvalid_out;

    assign m_axis_tdata = m_axis_tdata_out;
    assign m_axis_tkeep = m_axis_tkeep_out;
    assign m_axis_tlast = m_axis_tlast_out;
    assign m_axis_tid   = m_axis_tid_out;
    assign m_axis_tdest = m_axis_tdest_out;
    assign m_axis_tuser = m_axis_tuser_out;

    assign s_pause_ack = 1'b0;
    assign m_pause_ack = 1'b0;

end

endgenerate

endmodule

`resetall
/* ===== ../../EthernetInCore/verilog-ethernet/lib/axis/rtl/axis_async_fifo_adapter.v ===== */
/*

Copyright (c) 2019 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream asynchronous FIFO with width converter
 */
module axis_async_fifo_adapter #
(
    // FIFO depth in words
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter DEPTH = 4096,
    // Width of input AXI stream interface in bits
    parameter S_DATA_WIDTH = 8,
    // Propagate tkeep signal on input interface
    // If disabled, tkeep assumed to be 1'b1
    parameter S_KEEP_ENABLE = (S_DATA_WIDTH>8),
    // tkeep signal width (words per cycle) on input interface
    parameter S_KEEP_WIDTH = ((S_DATA_WIDTH+7)/8),
    // Width of output AXI stream interface in bits
    parameter M_DATA_WIDTH = 8,
    // Propagate tkeep signal on output interface
    // If disabled, tkeep assumed to be 1'b1
    parameter M_KEEP_ENABLE = (M_DATA_WIDTH>8),
    // tkeep signal width (words per cycle) on output interface
    parameter M_KEEP_WIDTH = ((M_DATA_WIDTH+7)/8),
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // number of RAM pipeline registers in FIFO
    parameter RAM_PIPELINE = 1,
    // use output FIFO
    // When set, the RAM read enable and pipeline clock enables are removed
    parameter OUTPUT_FIFO_ENABLE = 0,
    // Frame FIFO mode - operate on frames instead of cycles
    // When set, m_axis_tvalid will not be deasserted within a frame
    // Requires LAST_ENABLE set
    parameter FRAME_FIFO = 0,
    // tuser value for bad frame marker
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    // tuser mask for bad frame marker
    parameter USER_BAD_FRAME_MASK = 1'b1,
    // Drop frames larger than FIFO
    // Requires FRAME_FIFO set
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    // Drop frames marked bad
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_BAD_FRAME = 0,
    // Drop incoming frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_WHEN_FULL = 0,
    // Mark incoming frames as bad frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO to be clear
    parameter MARK_WHEN_FULL = 0,
    // Enable pause request input
    parameter PAUSE_ENABLE = 0,
    // Pause between frames
    parameter FRAME_PAUSE = FRAME_FIFO
)
(
    /*
     * AXI input
     */
    input  wire                     s_clk,
    input  wire                     s_rst,
    input  wire [S_DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [S_KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,
    input  wire [ID_WIDTH-1:0]      s_axis_tid,
    input  wire [DEST_WIDTH-1:0]    s_axis_tdest,
    input  wire [USER_WIDTH-1:0]    s_axis_tuser,

    /*
     * AXI output
     */
    input  wire                     m_clk,
    input  wire                     m_rst,
    output wire [M_DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [M_KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,
    output wire [ID_WIDTH-1:0]      m_axis_tid,
    output wire [DEST_WIDTH-1:0]    m_axis_tdest,
    output wire [USER_WIDTH-1:0]    m_axis_tuser,

    /*
     * Pause
     */
    input  wire                     s_pause_req,
    output wire                     s_pause_ack,
    input  wire                     m_pause_req,
    output wire                     m_pause_ack,

    /*
     * Status
     */
    output wire [$clog2(DEPTH):0]   s_status_depth,
    output wire [$clog2(DEPTH):0]   s_status_depth_commit,
    output wire                     s_status_overflow,
    output wire                     s_status_bad_frame,
    output wire                     s_status_good_frame,
    output wire [$clog2(DEPTH):0]   m_status_depth,
    output wire [$clog2(DEPTH):0]   m_status_depth_commit,
    output wire                     m_status_overflow,
    output wire                     m_status_bad_frame,
    output wire                     m_status_good_frame
);

// force keep width to 1 when disabled
localparam S_BYTE_LANES = S_KEEP_ENABLE ? S_KEEP_WIDTH : 1;
localparam M_BYTE_LANES = M_KEEP_ENABLE ? M_KEEP_WIDTH : 1;

// bus byte sizes (must be identical)
localparam S_BYTE_SIZE = S_DATA_WIDTH / S_BYTE_LANES;
localparam M_BYTE_SIZE = M_DATA_WIDTH / M_BYTE_LANES;
// output bus is wider
localparam EXPAND_BUS = M_BYTE_LANES > S_BYTE_LANES;
// total data and keep widths
localparam DATA_WIDTH = EXPAND_BUS ? M_DATA_WIDTH : S_DATA_WIDTH;
localparam KEEP_WIDTH = EXPAND_BUS ? M_BYTE_LANES : S_BYTE_LANES;

// bus width assertions
initial begin
    if (S_BYTE_SIZE * S_BYTE_LANES != S_DATA_WIDTH) begin
        $error("Error: input data width not evenly divisible (instance %m)");
        $finish;
    end

    if (M_BYTE_SIZE * M_BYTE_LANES != M_DATA_WIDTH) begin
        $error("Error: output data width not evenly divisible (instance %m)");
        $finish;
    end

    if (S_BYTE_SIZE != M_BYTE_SIZE) begin
        $error("Error: byte size mismatch (instance %m)");
        $finish;
    end
end

wire [DATA_WIDTH-1:0]  pre_fifo_axis_tdata;
wire [KEEP_WIDTH-1:0]  pre_fifo_axis_tkeep;
wire                   pre_fifo_axis_tvalid;
wire                   pre_fifo_axis_tready;
wire                   pre_fifo_axis_tlast;
wire [ID_WIDTH-1:0]    pre_fifo_axis_tid;
wire [DEST_WIDTH-1:0]  pre_fifo_axis_tdest;
wire [USER_WIDTH-1:0]  pre_fifo_axis_tuser;

wire [DATA_WIDTH-1:0]  post_fifo_axis_tdata;
wire [KEEP_WIDTH-1:0]  post_fifo_axis_tkeep;
wire                   post_fifo_axis_tvalid;
wire                   post_fifo_axis_tready;
wire                   post_fifo_axis_tlast;
wire [ID_WIDTH-1:0]    post_fifo_axis_tid;
wire [DEST_WIDTH-1:0]  post_fifo_axis_tdest;
wire [USER_WIDTH-1:0]  post_fifo_axis_tuser;

generate

if (M_BYTE_LANES > S_BYTE_LANES) begin : upsize_pre

    // output wider, adapt width before FIFO

    axis_adapter #(
        .S_DATA_WIDTH(S_DATA_WIDTH),
        .S_KEEP_ENABLE(S_KEEP_ENABLE),
        .S_KEEP_WIDTH(S_KEEP_WIDTH),
        .M_DATA_WIDTH(M_DATA_WIDTH),
        .M_KEEP_ENABLE(M_KEEP_ENABLE),
        .M_KEEP_WIDTH(M_KEEP_WIDTH),
        .ID_ENABLE(ID_ENABLE),
        .ID_WIDTH(ID_WIDTH),
        .DEST_ENABLE(DEST_ENABLE),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_ENABLE(USER_ENABLE),
        .USER_WIDTH(USER_WIDTH)
    )
    adapter_inst (
        .clk(s_clk),
        .rst(s_rst),
        // AXI input
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tid(s_axis_tid),
        .s_axis_tdest(s_axis_tdest),
        .s_axis_tuser(s_axis_tuser),
        // AXI output
        .m_axis_tdata(pre_fifo_axis_tdata),
        .m_axis_tkeep(pre_fifo_axis_tkeep),
        .m_axis_tvalid(pre_fifo_axis_tvalid),
        .m_axis_tready(pre_fifo_axis_tready),
        .m_axis_tlast(pre_fifo_axis_tlast),
        .m_axis_tid(pre_fifo_axis_tid),
        .m_axis_tdest(pre_fifo_axis_tdest),
        .m_axis_tuser(pre_fifo_axis_tuser)
    );

end else begin : bypass_pre

    assign pre_fifo_axis_tdata = s_axis_tdata;
    assign pre_fifo_axis_tkeep = s_axis_tkeep;
    assign pre_fifo_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = pre_fifo_axis_tready;
    assign pre_fifo_axis_tlast = s_axis_tlast;
    assign pre_fifo_axis_tid = s_axis_tid;
    assign pre_fifo_axis_tdest = s_axis_tdest;
    assign pre_fifo_axis_tuser = s_axis_tuser;

end

axis_async_fifo #(
    .DEPTH(DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(EXPAND_BUS ? M_KEEP_ENABLE : S_KEEP_ENABLE),
    .KEEP_WIDTH(KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(ID_ENABLE),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(DEST_ENABLE),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(USER_WIDTH),
    .RAM_PIPELINE(RAM_PIPELINE),
    .OUTPUT_FIFO_ENABLE(OUTPUT_FIFO_ENABLE),
    .FRAME_FIFO(FRAME_FIFO),
    .USER_BAD_FRAME_VALUE(USER_BAD_FRAME_VALUE),
    .USER_BAD_FRAME_MASK(USER_BAD_FRAME_MASK),
    .DROP_OVERSIZE_FRAME(DROP_OVERSIZE_FRAME),
    .DROP_BAD_FRAME(DROP_BAD_FRAME),
    .DROP_WHEN_FULL(DROP_WHEN_FULL),
    .MARK_WHEN_FULL(MARK_WHEN_FULL),
    .PAUSE_ENABLE(PAUSE_ENABLE),
    .FRAME_PAUSE(FRAME_PAUSE)
)
fifo_inst (
    // AXI input
    .s_clk(s_clk),
    .s_rst(s_rst),
    .s_axis_tdata(pre_fifo_axis_tdata),
    .s_axis_tkeep(pre_fifo_axis_tkeep),
    .s_axis_tvalid(pre_fifo_axis_tvalid),
    .s_axis_tready(pre_fifo_axis_tready),
    .s_axis_tlast(pre_fifo_axis_tlast),
    .s_axis_tid(pre_fifo_axis_tid),
    .s_axis_tdest(pre_fifo_axis_tdest),
    .s_axis_tuser(pre_fifo_axis_tuser),
    // AXI output
    .m_clk(m_clk),
    .m_rst(m_rst),
    .m_axis_tdata(post_fifo_axis_tdata),
    .m_axis_tkeep(post_fifo_axis_tkeep),
    .m_axis_tvalid(post_fifo_axis_tvalid),
    .m_axis_tready(post_fifo_axis_tready),
    .m_axis_tlast(post_fifo_axis_tlast),
    .m_axis_tid(post_fifo_axis_tid),
    .m_axis_tdest(post_fifo_axis_tdest),
    .m_axis_tuser(post_fifo_axis_tuser),
    // Pause
    .s_pause_req(s_pause_req),
    .s_pause_ack(s_pause_ack),
    .m_pause_req(m_pause_req),
    .m_pause_ack(m_pause_ack),
    // Status
    .s_status_depth(s_status_depth),
    .s_status_depth_commit(s_status_depth_commit),
    .s_status_overflow(s_status_overflow),
    .s_status_bad_frame(s_status_bad_frame),
    .s_status_good_frame(s_status_good_frame),
    .m_status_depth(m_status_depth),
    .m_status_depth_commit(m_status_depth_commit),
    .m_status_overflow(m_status_overflow),
    .m_status_bad_frame(m_status_bad_frame),
    .m_status_good_frame(m_status_good_frame)
);

if (M_BYTE_LANES < S_BYTE_LANES) begin : downsize_post

    // input wider, adapt width after FIFO

    axis_adapter #(
        .S_DATA_WIDTH(S_DATA_WIDTH),
        .S_KEEP_ENABLE(S_KEEP_ENABLE),
        .S_KEEP_WIDTH(S_KEEP_WIDTH),
        .M_DATA_WIDTH(M_DATA_WIDTH),
        .M_KEEP_ENABLE(M_KEEP_ENABLE),
        .M_KEEP_WIDTH(M_KEEP_WIDTH),
        .ID_ENABLE(ID_ENABLE),
        .ID_WIDTH(ID_WIDTH),
        .DEST_ENABLE(DEST_ENABLE),
        .DEST_WIDTH(DEST_WIDTH),
        .USER_ENABLE(USER_ENABLE),
        .USER_WIDTH(USER_WIDTH)
    )
    adapter_inst (
        .clk(m_clk),
        .rst(m_rst),
        // AXI input
        .s_axis_tdata(post_fifo_axis_tdata),
        .s_axis_tkeep(post_fifo_axis_tkeep),
        .s_axis_tvalid(post_fifo_axis_tvalid),
        .s_axis_tready(post_fifo_axis_tready),
        .s_axis_tlast(post_fifo_axis_tlast),
        .s_axis_tid(post_fifo_axis_tid),
        .s_axis_tdest(post_fifo_axis_tdest),
        .s_axis_tuser(post_fifo_axis_tuser),
        // AXI output
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tid(m_axis_tid),
        .m_axis_tdest(m_axis_tdest),
        .m_axis_tuser(m_axis_tuser)
    );

end else begin : bypass_post

    assign m_axis_tdata = post_fifo_axis_tdata;
    assign m_axis_tkeep = post_fifo_axis_tkeep;
    assign m_axis_tvalid = post_fifo_axis_tvalid;
    assign post_fifo_axis_tready = m_axis_tready;
    assign m_axis_tlast = post_fifo_axis_tlast;
    assign m_axis_tid = post_fifo_axis_tid;
    assign m_axis_tdest = post_fifo_axis_tdest;
    assign m_axis_tuser = post_fifo_axis_tuser;

end

endgenerate

endmodule

`resetall
