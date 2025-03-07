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
 * Basic test bench for AD7768 octal ADC data transfer
 */
`timescale 1ns/100ps
`default_nettype none

module ad7768_tb;

parameter ADC_CHIP_COUNT = 4;
parameter ADC_PER_CHIP   = 8;
parameter ADC_WIDTH      = 24;
parameter SYSCLK_RATE    = 100000000;
parameter ACQ_CLK_RATE   = 125000000;
parameter MCLK_RATE      = 32000000;

reg         sysClk = 0;
reg         sysCsrStrobe = 0;
reg  [31:0] sysGPIO_OUT = {32{1'bx}};
wire [31:0] sysStatus;
wire [31:0] sysAuxStatus;

reg                                                acqClk = 0;
reg                                                acqPPSstrobe = 0;
wire                                               acqStrobe;
wire [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData;
wire         [(ADC_CHIP_COUNT*ADC_PER_CHIP*8)-1:0] acqHeaders;

wire                      adcSCLK;
wire [ADC_CHIP_COUNT-1:0] adcCSn;
wire                      adcSDI;
reg  [ADC_CHIP_COUNT-1:0] adcSDO = {ADC_CHIP_COUNT{1'bx}};

reg                [ADC_CHIP_COUNT-1:0] adcDCLK = 0;
reg                [ADC_CHIP_COUNT-1:0] adcDRDY = 0;
reg [(ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0] adcDOUT = 0;
wire                                    adcSTARTn;
wire                                    adcRESETn;

// Instantiate device under test
ad7768 #(
    .ADC_CHIP_COUNT(ADC_CHIP_COUNT),
    .ADC_PER_CHIP(ADC_PER_CHIP),
    .ADC_WIDTH(ADC_WIDTH),
    .SYSCLK_RATE(SYSCLK_RATE),
    .ACQ_CLK_RATE(ACQ_CLK_RATE),
    .MCLK_RATE(MCLK_RATE))
  ad7768_i (
    .sysClk(sysClk),
    .sysCsrStrobe(sysCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysStatus),
    .sysAuxStatus(sysAuxStatus),
    .acqClk(acqClk),
    .acqPPSstrobe(acqPPSstrobe),
    .acqStrobe(acqStrobe),
    .acqData(acqData),
    .acqHeaders(acqHeaders),
    .adcSCLK(adcSCLK),
    .adcCSn(adcCSn),
    .adcSDI(adcSDI),
    .adcSDO(adcSDO),
    .adcDCLK_a(adcDCLK),
    .adcDRDY_a(adcDRDY),
    .adcDOUT_a(adcDOUT),
    .adcSTARTn(adcSTARTn),
    .adcRESETn(adcRESETn));

localparam HDR_WIDTH = 8;
localparam MCLK_DIV  = 4;

// Generate clocks
localparam MCLK_DELAY = (1000000000/(MCLK_RATE/MCLK_DIV))/2;
always begin #5 sysClk = !sysClk; end
always begin #4 acqClk = !acqClk; end
always begin #MCLK_DELAY adcDCLK[0] = !adcDCLK[0]; end
integer d;
always @(adcDCLK[0]) begin
    for (d = 1 ; d < ADC_CHIP_COUNT ; d = d + 1) begin
        adcDCLK[d] = adcDCLK[0];
        #7;
    end
end
integer r;
always @(adcDRDY[0]) begin
    for (r = 1 ; r < ADC_CHIP_COUNT ; r = r + 1) begin
        #7 adcDRDY[r] = adcDRDY[0];
    end
end

// Generate a fake PPS marker for DRDY[0] to time against
integer ppsDelay = 2;
always @(posedge adcDRDY[0]) begin
    if (ppsDelay != 0) begin
        ppsDelay = ppsDelay - 1;
        if (ppsDelay == 0) begin
            #3000;
            @(posedge acqClk) acqPPSstrobe <= 1;
            @(posedge acqClk) acqPPSstrobe <= 0;
        end
    end
end

// Generate data and DRDY
localparam SHIFTREG_WIDTH = HDR_WIDTH + ADC_WIDTH;
localparam CHANNEL_COUNT = ADC_CHIP_COUNT * ADC_PER_CHIP;
reg [SHIFTREG_WIDTH-1:0] shifters [0:CHANNEL_COUNT-1];
integer i;
integer adcVal = 0;
integer shiftCount = SHIFTREG_WIDTH - 1;
always @(posedge adcDCLK) begin
    #2 begin
        adcDRDY[0] = shiftCount == 0 ? 1'b1 : 1'b0;
        for (i = 0 ; i < CHANNEL_COUNT ; i = i + 1) begin
            adcDOUT[i] = shifters[i][SHIFTREG_WIDTH-1];
            shifters[i] = shifters[i] << 1;
            #1;
        end
    end
    if (shiftCount == 0) begin
        shiftCount = SHIFTREG_WIDTH - 1;
        for (i = 0 ; i < CHANNEL_COUNT ; i = i + 1) begin
            shifters[i] = (i << ADC_WIDTH) | adcVal;
            adcVal = adcVal + 1;
        end
    end
    else begin
        shiftCount = shiftCount - 1;
    end
end
initial begin
    for (i = 0 ; i < CHANNEL_COUNT ; i = i + 1) begin
        shifters[i] = 0;
    end
end

// Handle SPI
integer spiBitCount = -1;
reg [15:0] spiReg = {16{1'bx}};
reg spiBit;
wire [ADC_CHIP_COUNT-1:0] expectCSn = ~2;
always @(adcCSn) begin
    if ((spiBitCount != -1) || (adcSCLK != 0)) begin
        $display("ADC CSn %X, bit count %d, SPI CLOCK %d at %d -- FAIL",
                                           adcCSn, spiBitCount, adcSCLK, $time);
        good = 0;
    end
    else if (adcCSn != {ADC_CHIP_COUNT{1'b1}}) begin
        spiBitCount = 15;
        spiReg = 16'h0012;
    end
    else if (adcCSn == {ADC_CHIP_COUNT{1'b1}}) begin
        spiBitCount = -1;
        spiReg = {16{1'bx}};
    end
end
always @(posedge adcSCLK) begin
    if (adcCSn != {ADC_CHIP_COUNT{1'b1}}) begin
        spiBit = adcSDI;
    end
end
always @(negedge adcSCLK) begin
    if (adcCSn != {ADC_CHIP_COUNT{1'b1}}) begin
        spiReg = {spiReg[14:0], spiBit};
        if (spiBitCount == 0) begin
            $write("SPI %X to %X -- ", spiReg, ~adcCSn);
            if ((spiReg == 16'h6543) && (adcCSn == expectCSn)) begin
                $display("PASS");
            end
            else begin
                $display("FAIL");
                good = 0;
            end
        end
        spiBitCount = spiBitCount - 1;
    end
end
integer sp;
always @(spiReg or adcCSn) begin
    for (sp = 0 ; sp < ADC_CHIP_COUNT ; sp = sp + 1) begin
        adcSDO[sp] = adcCSn[sp] ? 1'bx : spiReg[15];
    end
end

reg good = 1;
initial
begin
    $dumpfile("ad7768_tb.fst");
    $dumpvars(0, ad7768_tb);

    // Check ADC Reset
    #100 ;
    writeCsr((1 << 30) | 3);
    #100 ;
    if (adcRESETn != 0) begin
        $display("Applied reset, but adcRESETn not low -- FAIL");
        good = 0;
    end
    #100 ;
    writeCsr((1 << 30) | 2);
    #100 ;
    if (adcRESETn != 1) begin
        $display("Removed reset, but adcRESETn not high -- FAIL");
        good = 0;
    end

    // Check ADC SPI
    writeCsr((2 << 30) | (2 << 16) | 16'h6543);
    if (!sysStatus[31]) begin
        $display("SPI didn't start -- FAIL");
        good = 0;
    end
    while (sysStatus[31]) begin
        #10;
    end
    if (sysStatus[0+:16] != 16'h0012) begin
        $display("SPI READBACK:%X -- FAIL", sysStatus[0+:16]);
        good = 0;
    end

    #30000 ;
    if (!sysStatus[29]) begin
        $display("Chips not aligned.");
        good = 0;
    end
    $display("PPS to DRDY:%d  DRDY Skew:%d", sysAuxStatus[16+:16],
                                             sysAuxStatus[0+:16]);
    $display("%s", good ? "PASS" : "FAIL");
    $finish;
end

integer c;
integer expect = 0;
always @(posedge acqClk) begin
    if (acqStrobe) begin
        $display("SAMPLE");
        for (c = 0 ; c < CHANNEL_COUNT ; c = c + 1) begin
            $write("%d %X -- ", acqHeaders[c*HDR_WIDTH+:HDR_WIDTH],
                                acqData[c*ADC_WIDTH+:ADC_WIDTH]);
            if ((acqHeaders[c*HDR_WIDTH+:HDR_WIDTH] == c)
             && (acqData[c*ADC_WIDTH+:ADC_WIDTH] == expect)) begin
                $display("PASS");
            end
            else begin
                $display("FAIL");
                good = 0;
            end
            expect = expect + 1;
        end
    end
end

task writeCsr;
    input [31:0] w;
    begin
    @(posedge sysClk) begin
        sysGPIO_OUT <= w;
        sysCsrStrobe <= 1;
    end
    @(posedge sysClk) begin
        sysGPIO_OUT <= {32{1'bx}};
        sysCsrStrobe <= 0;
    end
    @(posedge sysClk) ;
    end
endtask

endmodule
