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
 * Communicate with on-board microcontroller
 */
module mmcIO #(
    parameter DEBUG = "false"
    ) (
    input         clk,
    input         csrStrobe,
    input  [31:0] GPIO_OUT,
    output [31:0] status,

    input  MMC_CSB,
    input  MMC_SCLK,
    input  MMC_MOSI,
    output MMC_MISO);

localparam OPCODE_WIDTH  = 4;
localparam ADDR_LO_WIDTH = 4;
localparam ADDR_HI_WIDTH = 7;
localparam ADDR_WIDTH = ADDR_HI_WIDTH + ADDR_LO_WIDTH;
localparam DATA_WIDTH    = 8;

localparam OPCODE_NETWORK_CONFIG = 1,
           OPCODE_CONTROL        = 2,
           OPCODE_UDP_CONFIG     = 3,
           OPCODE_MAILBOX_READ   = 4,
           OPCODE_MAILBOX_WRITE  = 5;
(*mark_debug=DEBUG*) reg  [OPCODE_WIDTH-1:0] opcode;

localparam CONTROL_ADDRLO_ENABLE_ETHERNET = 0,
           CONTROL_ADDRLO_SET_ADDRHI      = 2;

localparam S_FETCH_OPCODE =  0,
           S_FETCH_ADDRESS = 1,
           S_TRANSFER_DATA = 2,
           S_DONE          = 3;
(*mark_debug=DEBUG*) reg [1:0] state;

(*mark_debug=DEBUG*) reg [3:0] bitCounter;
wire bitCounterDone = bitCounter[3];
(*mark_debug=DEBUG*) reg [ADDR_LO_WIDTH-1:0] addrLo;
(*mark_debug=DEBUG*) reg [ADDR_HI_WIDTH-1:0] addrHi;

// Stabilize incoming lines
(*ASYNC_REG="true"*) reg MMC_CSB_m;
(*mark_debug=DEBUG*) reg MMC_CSB_s;
(*ASYNC_REG="true"*) reg MMC_SCLK_m;
(*mark_debug=DEBUG*) reg MMC_SCLK_s;
                     reg MMC_SCLK_d;

// I/O shift registers
(*mark_debug=DEBUG*) reg [DATA_WIDTH-1:0] rxShift, txShift;
wire [DATA_WIDTH-1:0] nextRxShift = {rxShift[0+:DATA_WIDTH-1], MMC_MOSI};
assign MMC_MISO = txShift[DATA_WIDTH-1];
reg setTx_d0 = 0, setTx_d1 = 0, setTx_d2 = 0;

/*
 * Mailbox full dual-port RAM (single clock)
 * Take care when making changes since it is easy
 * to break the inferrence of block RAM.
 */
reg  [ADDR_WIDTH-1:0] sysReadAddress;
wire [ADDR_WIDTH-1:0] sysWriteAddress = GPIO_OUT[2*DATA_WIDTH+:ADDR_WIDTH];
wire [ADDR_WIDTH-1:0] sysMailboxAddress = csrStrobe ? sysWriteAddress
                                                    : sysReadAddress;
wire [ADDR_WIDTH-1:0] mmcWriteAddress = {addrHi, addrLo};
reg mmcMailboxWriteEnable = 0;
reg [DATA_WIDTH-1:0] mailboxDPRAM[0:(1 << ADDR_WIDTH) - 1];
reg [DATA_WIDTH-1:0] sysMailboxQ, mmcMailboxQ;
always @(posedge clk) begin
    sysMailboxQ <= mailboxDPRAM[sysMailboxAddress];
    if (csrStrobe && GPIO_OUT[31]) begin
        mailboxDPRAM[sysMailboxAddress] <= GPIO_OUT[0+:DATA_WIDTH];
    end
end
always @(posedge clk) begin
    mmcMailboxQ <= mailboxDPRAM[{addrHi, addrLo}];
    if (mmcMailboxWriteEnable) begin
        mailboxDPRAM[mmcWriteAddress] <= rxShift;
    end
end

/*
 * Network configuration simple dual-port RAM (single clock)
 */
(*mark_debug=DEBUG*) reg mmcNetConfigWriteEnable = 0;
reg [DATA_WIDTH-1:0] netConfigDPRAM[0:(1 << ADDR_LO_WIDTH)-1];
reg [DATA_WIDTH-1:0] sysNetConfigQ;
wire [ADDR_LO_WIDTH-1:0]sysNetConfigAddress=sysMailboxAddress[0+:ADDR_LO_WIDTH];
always @(posedge clk) begin
    sysNetConfigQ <= netConfigDPRAM[sysNetConfigAddress];
    if (mmcNetConfigWriteEnable) begin
        netConfigDPRAM[addrLo] <= rxShift;
    end
end

/*
 * Local I/O
 */
reg ethernetEnable = 0;
always @(posedge clk) begin
    if (csrStrobe) begin
        sysReadAddress <= sysWriteAddress;
    end
end
assign status = { ethernetEnable,
                  {32-1-ADDR_WIDTH-DATA_WIDTH-DATA_WIDTH{1'b0}},
                  sysMailboxAddress,
                  sysNetConfigQ,
                  sysMailboxQ };

/*
 * Data transfer state machine
 */
always @(posedge clk) begin
    // Stabilize incoming lines
    MMC_CSB_m  <= MMC_CSB;
    MMC_CSB_s  <= MMC_CSB_m;
    MMC_SCLK_m <= MMC_SCLK;
    MMC_SCLK_s <= MMC_SCLK_m;
    MMC_SCLK_d <= MMC_SCLK_s;
    setTx_d1 <= setTx_d0;
    setTx_d2 <= setTx_d1;

    if (MMC_CSB_s) begin // No transfer in progress
        setTx_d0 <= 0;
        bitCounter <= OPCODE_WIDTH - 2;
        state <= S_FETCH_OPCODE;
        if (state == S_DONE) begin
            case (opcode)
            OPCODE_NETWORK_CONFIG:  mmcNetConfigWriteEnable <= 1;
            OPCODE_CONTROL: begin
                case (addrLo)
                CONTROL_ADDRLO_ENABLE_ETHERNET: ethernetEnable <= rxShift[0];
                CONTROL_ADDRLO_SET_ADDRHI: addrHi <= rxShift[ADDR_HI_WIDTH-1:0];
                default: ;
                endcase
            end
            OPCODE_MAILBOX_WRITE:   mmcMailboxWriteEnable <= 1;
            default: ;
            endcase
        end
        else begin
            mmcMailboxWriteEnable <= 0;
            mmcNetConfigWriteEnable <= 0;
        end
    end
    else if (!MMC_SCLK_s && MMC_SCLK_d) begin  // Falling edge of clock
        rxShift <= nextRxShift;
        if (setTx_d2) begin
            txShift <= {txShift[0+:DATA_WIDTH-1], 1'b0};
        end
        if (!bitCounterDone) begin
            bitCounter <= bitCounter - 1;
        end
        case (state)
        S_FETCH_OPCODE: begin
            if (bitCounterDone) begin
                opcode <= nextRxShift[0+:OPCODE_WIDTH];
                bitCounter <= ADDR_LO_WIDTH - 2;
                state <= S_FETCH_ADDRESS;
            end
        end
        S_FETCH_ADDRESS: begin
            if (bitCounterDone) begin
                addrLo <= nextRxShift[0+:ADDR_LO_WIDTH];
                bitCounter <= DATA_WIDTH - 2;
                setTx_d0 <= 1;
                state <= S_TRANSFER_DATA;
            end
        end
        S_TRANSFER_DATA: begin
            if (bitCounterDone) begin
                state <= S_DONE;
            end
        end
        default: ;
        endcase
    end
    else if (setTx_d1 && !setTx_d2) begin
        // Latch output data into shift register when appropriate
        txShift <= mmcMailboxQ;
    end
end
endmodule
