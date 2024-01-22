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
            shiftReg[32+:32] <= GPIO_OUT;
        end
        if (setStrobeAndStart) begin
            shiftReg[0+:32] <= GPIO_OUT;
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
