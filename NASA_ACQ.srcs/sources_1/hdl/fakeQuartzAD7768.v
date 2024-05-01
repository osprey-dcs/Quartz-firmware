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
 * Provide fake AD7768 data.
 * Useful for testing other firmware before Quartz boards arrive.
 */
`default_nettype none
module fakeQuartzAD7768 #(
    parameter ADC_CHIP_COUNT = 1,
    parameter ADC_PER_CHIP   = 8,
    parameter ADC_WIDTH      = 24
    ) (
    input  wire                                     MCLK,
    output wire                [ADC_CHIP_COUNT-1:0] adcDCLK,
    output wire                [ADC_CHIP_COUNT-1:0] adcDRDY,
    output wire [(ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0] adcDOUT);

localparam MCLK_DIV = 4;
localparam MCLK_DIV_LOAD = (MCLK_DIV / 2) - 2;
localparam MCLK_DIV_WIDTH = $clog2(MCLK_DIV_LOAD+1) + 1;
reg [MCLK_DIV_WIDTH-1:0] mclkDiv = MCLK_DIV_LOAD;
wire mclkDivDone = mclkDiv[MCLK_DIV_WIDTH-1];
reg dclk = 0;

localparam HEADER_WIDTH = 8;
localparam SHIFTREG_WIDTH = HEADER_WIDTH + ADC_WIDTH;
reg [SHIFTREG_WIDTH-1:0] shiftReg0 = 0;
wire dout = shiftReg0[SHIFTREG_WIDTH-1];
reg shiftReg1Neg = 0;
reg [SHIFTREG_WIDTH-1:0] shiftReg1 = 4096;
wire dout1 = shiftReg1[SHIFTREG_WIDTH-1];

localparam BITCOUNTER_LOAD = HEADER_WIDTH + ADC_WIDTH - 2; 
localparam BITCOUNTER_WIDTH = $clog2(BITCOUNTER_LOAD+1) + 1;
reg [BITCOUNTER_WIDTH-1:0] bitCounter = BITCOUNTER_LOAD;
wire bitCounterDone = bitCounter[BITCOUNTER_WIDTH-1];

reg [ADC_WIDTH-1:0] adcVal = 0;

always @(posedge MCLK) begin
    if (mclkDivDone) begin
        mclkDiv <= MCLK_DIV_LOAD;
        dclk <= !dclk;
        if (dclk == 0) begin
            if (bitCounterDone) begin
                bitCounter <= BITCOUNTER_LOAD;
                shiftReg0 <= { {HEADER_WIDTH{1'b0}}, adcVal };
                shiftReg1 <= shiftReg1Neg ? -4096 : 4096;
                adcVal <= adcVal + 1;
            end
            else begin
                bitCounter <= bitCounter - 1;
                shiftReg0 <= {shiftReg0[0+:SHIFTREG_WIDTH-1], 1'b0};
                shiftReg1 <= {shiftReg1[0+:SHIFTREG_WIDTH-1], 1'b0};
                shiftReg1Neg <= !shiftReg1Neg;
            end
        end
    end
    else begin
        mclkDiv <= mclkDiv - 1;
    end
end


assign adcDCLK = {ADC_CHIP_COUNT{dclk}};
assign adcDRDY = {ADC_CHIP_COUNT{bitCounterDone}};
genvar i;
generate
  for (i = 0 ; i < (ADC_CHIP_COUNT*ADC_PER_CHIP) ; i = i + 1) begin
    assign adcDOUT[i] = (i == 1) ? dout1 : dout;
  end
endgenerate

endmodule
`default_nettype wire
