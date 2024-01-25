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
 * SPI link to MAX4896 relay drivers.
 */
`default_nettype none
module coilDriverSPI #(
    parameter CLK_RATE = 100000000
    ) (
    input  wire        clk,
    input  wire [31:0] GPIO_OUT,
    input  wire        clrStrobe,
    input  wire        setStrobeAndStart,
    output wire [31:0] status,
    output reg         SPI_CLK = 0,
    output reg         SPI_CS_n = 1,
    input  wire        SPI_DOUT,
    output wire        SPI_DIN,
    output reg         COIL_CONTROL_RESET_n = 0,
    input  wire        COIL_CONTROL_FLAGS_n);

localparam SPI_RATE  = 5000000;
localparam SPI_WIDTH = 64;

localparam TICK_COUNTER_RELOAD = ((CLK_RATE+(SPI_RATE*2)-1) / (SPI_RATE*2)) - 2;
localparam TICK_COUNTER_WIDTH = $clog2(TICK_COUNTER_RELOAD+1) + 1;
reg [TICK_COUNTER_WIDTH-1:0] tickCounter;
wire tick = tickCounter[TICK_COUNTER_WIDTH-1];

localparam BIT_COUNTER_LOAD = SPI_WIDTH - 1;
localparam BIT_COUNTER_WIDTH = $clog2(BIT_COUNTER_LOAD+1) + 1;
reg [BIT_COUNTER_WIDTH-1:0] bitCounter;
wire bitCounterDone = bitCounter[BIT_COUNTER_WIDTH-1];

reg [SPI_WIDTH-1:0] shiftReg;
assign SPI_DIN = shiftReg[SPI_WIDTH-1];

assign status = {30'b0, !COIL_CONTROL_FLAGS_n, !SPI_CS_n};

always @(posedge clk) begin
    if (SPI_CS_n) begin
        tickCounter <= TICK_COUNTER_RELOAD;
        bitCounter <= BIT_COUNTER_LOAD;
        if (clrStrobe) begin
            COIL_CONTROL_RESET_n <= 1;
            shiftReg[0]  <= GPIO_OUT[4];   // Reset 5 -- Final bit shfted out
            shiftReg[2]  <= GPIO_OUT[0];   // Reset 1
            shiftReg[4]  <= GPIO_OUT[5];   // Reset 6
            shiftReg[6]  <= GPIO_OUT[1];   // Reset 2
            shiftReg[8]  <= GPIO_OUT[6];   // Reset 7
            shiftReg[10] <= GPIO_OUT[2];   // Reset 3
            shiftReg[12] <= GPIO_OUT[7];   // Reset 8
            shiftReg[14] <= GPIO_OUT[3];   // Reset 4
            shiftReg[16] <= GPIO_OUT[12];  // Reset 13
            shiftReg[18] <= GPIO_OUT[8];   // Reset 9
            shiftReg[20] <= GPIO_OUT[13];  // Reset 14
            shiftReg[22] <= GPIO_OUT[9];   // Reset 10
            shiftReg[24] <= GPIO_OUT[14];  // Reset 15
            shiftReg[26] <= GPIO_OUT[10];  // Reset 11
            shiftReg[28] <= GPIO_OUT[15];  // Reset 16
            shiftReg[30] <= GPIO_OUT[11];  // Reset 12
            shiftReg[32] <= GPIO_OUT[20];  // Reset 21
            shiftReg[34] <= GPIO_OUT[16];  // Reset 17
            shiftReg[36] <= GPIO_OUT[21];  // Reset 22
            shiftReg[38] <= GPIO_OUT[17];  // Reset 18
            shiftReg[40] <= GPIO_OUT[22];  // Reset 23
            shiftReg[42] <= GPIO_OUT[18];  // Reset 19
            shiftReg[44] <= GPIO_OUT[23];  // Reset 24
            shiftReg[46] <= GPIO_OUT[19];  // Reset 20
            shiftReg[48] <= GPIO_OUT[28];  // Reset 29
            shiftReg[50] <= GPIO_OUT[24];  // Reset 25
            shiftReg[52] <= GPIO_OUT[29];  // Reset 30
            shiftReg[54] <= GPIO_OUT[25];  // Reset 26
            shiftReg[56] <= GPIO_OUT[30];  // Reset 31
            shiftReg[58] <= GPIO_OUT[26];  // Reset 27
            shiftReg[60] <= GPIO_OUT[31];  // Reset 32
            shiftReg[62] <= GPIO_OUT[27];  // Reset 28
        end
        if (setStrobeAndStart) begin
            shiftReg[1]  <= GPIO_OUT[4];   // Set 5
            shiftReg[3]  <= GPIO_OUT[0];   // Set 1
            shiftReg[5]  <= GPIO_OUT[5];   // Set 6
            shiftReg[7]  <= GPIO_OUT[1];   // Set 2
            shiftReg[9]  <= GPIO_OUT[6];   // Set 7
            shiftReg[11] <= GPIO_OUT[2];   // Set 3
            shiftReg[13] <= GPIO_OUT[7];   // Set 8
            shiftReg[15] <= GPIO_OUT[3];   // Set 4
            shiftReg[17] <= GPIO_OUT[12];  // Set 13
            shiftReg[19] <= GPIO_OUT[8];   // Set 9
            shiftReg[21] <= GPIO_OUT[13];  // Set 14
            shiftReg[23] <= GPIO_OUT[9];   // Set 10
            shiftReg[25] <= GPIO_OUT[14];  // Set 15
            shiftReg[27] <= GPIO_OUT[10];  // Set 11
            shiftReg[29] <= GPIO_OUT[15];  // Set 16
            shiftReg[31] <= GPIO_OUT[11];  // Set 12
            shiftReg[33] <= GPIO_OUT[20];  // Set 21
            shiftReg[35] <= GPIO_OUT[16];  // Set 17
            shiftReg[37] <= GPIO_OUT[21];  // Set 22
            shiftReg[39] <= GPIO_OUT[17];  // Set 18
            shiftReg[41] <= GPIO_OUT[22];  // Set 23
            shiftReg[43] <= GPIO_OUT[18];  // Set 19
            shiftReg[45] <= GPIO_OUT[23];  // Set 24
            shiftReg[47] <= GPIO_OUT[19];  // Set 20
            shiftReg[49] <= GPIO_OUT[28];  // Set 29
            shiftReg[51] <= GPIO_OUT[24];  // Set 25
            shiftReg[53] <= GPIO_OUT[29];  // Set 30
            shiftReg[55] <= GPIO_OUT[25];  // Set 26
            shiftReg[57] <= GPIO_OUT[30];  // Set 31
            shiftReg[59] <= GPIO_OUT[26];  // Set 27
            shiftReg[61] <= GPIO_OUT[31];  // Set 32
            shiftReg[63] <= GPIO_OUT[27];  // Set 28 -- First bit shifted out
            SPI_CS_n <= 0;
        end
    end
    else begin
        if (tick) begin
            tickCounter <= TICK_COUNTER_RELOAD;
            if (SPI_CLK) begin
                SPI_CLK <= 0;
                shiftReg <= {shiftReg[SPI_WIDTH-2:0], SPI_DIN};
            end
            else begin
                bitCounter <= bitCounter - 1;
                if (bitCounterDone) begin
                    SPI_CS_n <= 1;
                end
                else begin
                    SPI_CLK <= 1;
                end
            end
        end
        else begin
            tickCounter <= tickCounter - 1;
        end
    end
end
endmodule
`default_nettype wire
