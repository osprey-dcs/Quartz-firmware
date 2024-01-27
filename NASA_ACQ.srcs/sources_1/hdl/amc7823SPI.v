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
 * SPI link to AMC7823 analog monitoring and control circuit
 * Shift on rising SCLK edge, sample on falling edge.
 */
`default_nettype none
module amc7823SPI #(
    parameter CLK_RATE = 100000000
    ) (
    input  wire        clk,
    input  wire [31:0] GPIO_OUT,
    input  wire        csrStrobe,
    output wire [31:0] status,
    output reg         SPI_CLK = 0,
    output reg         SPI_CS_n = 1,
    input  wire        SPI_DOUT,
    output reg         SPI_DIN = 0);

localparam SPI_RATE  = 10000000;
localparam SPI_WIDTH = 32;

localparam TICK_COUNTER_RELOAD = ((CLK_RATE+(SPI_RATE*2)-1) / (SPI_RATE*2)) - 2;
localparam TICK_COUNTER_WIDTH = $clog2(TICK_COUNTER_RELOAD+1) + 1;
reg [TICK_COUNTER_WIDTH-1:0] tickCounter;
wire tick = tickCounter[TICK_COUNTER_WIDTH-1];

localparam BIT_COUNTER_LOAD = SPI_WIDTH - 2;
localparam BIT_COUNTER_WIDTH = $clog2(BIT_COUNTER_LOAD+1) + 1;
reg [BIT_COUNTER_WIDTH-1:0] bitCounter;
wire bitCounterDone = bitCounter[BIT_COUNTER_WIDTH-1];
reg busy = 0;

reg [SPI_WIDTH-1:0] shiftReg;

assign status = {busy, shiftReg[30:0]};

always @(posedge clk) begin
    if (busy) begin
        if (tick) begin
            tickCounter <= TICK_COUNTER_RELOAD;
            if (SPI_CLK) begin
                SPI_CLK <= 0;
                shiftReg[0] <= SPI_DOUT;
                bitCounter <= bitCounter - 1;
                if (bitCounterDone) begin
                    busy <= 0;
                end
            end
            else begin
                SPI_DIN <= shiftReg[SPI_WIDTH-1];
                shiftReg <= {shiftReg[SPI_WIDTH-2:0], 1'bx};
                SPI_CLK <= 1;
            end
        end
        else begin
            tickCounter <= tickCounter - 1;
        end
    end
    else begin
        tickCounter <= TICK_COUNTER_RELOAD;
        bitCounter <= BIT_COUNTER_LOAD;
        if (csrStrobe) begin
            if (GPIO_OUT[30]) begin
                SPI_CS_n <= GPIO_OUT[29];
            end
            else begin
                shiftReg <= GPIO_OUT;
                busy <= 1;
            end
        end
    end
end
endmodule
`default_nettype wire
