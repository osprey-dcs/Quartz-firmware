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
 * AD7768 8 channel, 24 bit Delta/Sigma ADC
 */
`default_nettype none
module ad7768 #(
    parameter ADC_CHIP_COUNT = 1,
    parameter ADC_PER_CHIP   = 8,
    parameter ADC_WIDTH      = 24,
    parameter SYSCLK_RATE    = 100000000,
    parameter ACQ_CLK_RATE   = 125000000,
    parameter MCLK_RATE      = 32000000,
    parameter DEBUG_ACQ      = "false",
    parameter DEBUG_ALIGN    = "false",
    parameter DEBUG_PINS     = "false",
    parameter DEBUG_PPS      = "false",
    parameter DEBUG_SKEW     = "false",
    parameter DEBUG_SPI      = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysAuxStatus,
    output reg  [31:0] sysDRDYhistory,

    input  wire                                              acqClk,
    (*MARK_DEBUG=DEBUG_PPS*) input  wire                     acqPPSstrobe,
    (*MARK_DEBUG=DEBUG_ACQ*) output reg                      acqStrobe=0,
    (*MARK_DEBUG=DEBUG_ACQ*) output wire
                [(ADC_CHIP_COUNT*ADC_PER_CHIP*ADC_WIDTH)-1:0] acqData,
    (*MARK_DEBUG=DEBUG_ACQ*) output wire
                        [(ADC_CHIP_COUNT*ADC_PER_CHIP*8)-1:0] acqHeaders,

    (*MARK_DEBUG=DEBUG_SPI*) output wire                      adcSCLK,
    (*MARK_DEBUG=DEBUG_SPI*) output wire [ADC_CHIP_COUNT-1:0] adcCSn,
    (*MARK_DEBUG=DEBUG_SPI*) output wire                      adcSDI,
    (*MARK_DEBUG=DEBUG_SPI*) input  wire [ADC_CHIP_COUNT-1:0] adcSDO,

                              input  wire                          adcMCLK,
    (*MARK_DEBUG=DEBUG_PINS*) input  wire     [ADC_CHIP_COUNT-1:0] adcDCLK_a,
    (*MARK_DEBUG=DEBUG_PINS*) input  wire     [ADC_CHIP_COUNT-1:0] adcDRDY_a,
    (*MARK_DEBUG=DEBUG_PINS*) input  wire
                               [(ADC_CHIP_COUNT*ADC_PER_CHIP)-1:0] adcDOUT_a,
    (*MARK_DEBUG=DEBUG_PINS*) output wire                          adcSTARTn,
    (*MARK_DEBUG=DEBUG_PINS*) output wire                          adcRESETn);

localparam SKEW_LIMIT_NS = 30;
localparam SKEW_LIMIT_ACQ_TICKS =  (((ACQ_CLK_RATE / 1000) * SKEW_LIMIT_NS) +
                                                              999999) / 1000000;
localparam HEADER_WIDTH = 8;
localparam DCLK_DIV = 4;
localparam DCLK_RATE = MCLK_RATE / DCLK_DIV;
localparam DRDY_RATE = DCLK_RATE / 32;
localparam CEIL_CLOCKS_PER_DRDY = (ACQ_CLK_RATE + DRDY_RATE - 1) / DRDY_RATE;

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain

reg sysStartAlignmentToggle = 0;
reg sysResetADC = 0;
reg sysUseFakeAD7768 = 0;
assign adcRESETn = !sysResetADC;

wire [1:0] sysOpcode = sysGPIO_OUT[31:30];
localparam CSR_W_OP_CHIP_PINS    = 2'h1,
           CSR_W_OP_SPI_TRANSFER = 2'h2;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        case (sysOpcode)
        CSR_W_OP_CHIP_PINS: begin
            if (sysGPIO_OUT[1]) begin
                sysResetADC <= sysGPIO_OUT[0];
            end
            if (sysGPIO_OUT[3]) begin
                sysUseFakeAD7768 <= sysGPIO_OUT[2];
            end
            if (sysGPIO_OUT[8]) begin
                sysStartAlignmentToggle <= !sysStartAlignmentToggle;
            end
        end
        default: ;
        endcase
    end
end

// SPI
localparam SPI_SHIFTREG_WIDTH = 16;
localparam SPI_RATE = 10000000;
localparam SPI_DELAY_DIVISOR = ((SYSCLK_RATE / 2) + SPI_RATE - 1) / SPI_RATE;
localparam SPI_DELAY_LOAD = SPI_DELAY_DIVISOR - 2;
localparam SPI_DELAY_WIDTH = $clog2(SPI_DELAY_LOAD+1)+1;
reg [SPI_DELAY_WIDTH-1:0] spiDelay = SPI_DELAY_LOAD;
wire spiDelayDone = spiDelay[SPI_DELAY_WIDTH-1];
localparam SPI_BITCOUNT_LOAD = SPI_SHIFTREG_WIDTH - 1;
localparam SPI_BITCOUNT_WIDTH = $clog2(SPI_BITCOUNT_LOAD+1)+1;
reg [SPI_BITCOUNT_WIDTH-1:0] spiBitcount = SPI_BITCOUNT_LOAD;
wire spiBitcountDone = spiBitcount[SPI_BITCOUNT_WIDTH-1];
reg spiActive = 0;
(*MARK_DEBUG=DEBUG_SPI*) reg [SPI_SHIFTREG_WIDTH-1:0] spiShiftReg;
reg spiClk = 0;
reg [ADC_CHIP_COUNT-1:0] spiCSn = ~0;
(*MARK_DEBUG=DEBUG_SPI*) reg spiSDO;
always @(posedge sysClk) begin
    if (spiActive) begin
        if (spiDelayDone) begin
            spiDelay <= SPI_DELAY_LOAD;
            if (spiClk) begin
                spiClk <= 0;
                spiShiftReg <= { spiShiftReg[0+:SPI_SHIFTREG_WIDTH-1], spiSDO };
                spiBitcount <= spiBitcount - 1;
            end
            else begin
                if (spiBitcountDone) begin
                    spiActive <= 0;
                end
                else begin
                    spiSDO <= |(adcSDO & ~spiCSn);
                    spiClk <= 1;
                end
            end
        end
        else begin
            spiDelay <= spiDelay - 1;
        end
    end
    else begin
        spiDelay <= SPI_DELAY_LOAD;
        spiBitcount <= SPI_BITCOUNT_LOAD;
        spiClk <= 0;
        if (sysCsrStrobe && (sysOpcode == CSR_W_OP_SPI_TRANSFER)) begin
            spiShiftReg <= sysGPIO_OUT[0+:SPI_SHIFTREG_WIDTH];
            spiCSn <= ~sysGPIO_OUT[SPI_SHIFTREG_WIDTH+:ADC_CHIP_COUNT];
            spiActive <= 1;
        end
        else begin
            spiCSn <= ~0;
        end
    end
end
assign adcSCLK = spiClk;
assign adcCSn  = spiCSn;
assign adcSDI = spiShiftReg[SPI_SHIFTREG_WIDTH-1];

/*
 * Some of these signals are in clock domain other than the system clock
 * domain where they are read by the microBlaze, but race conditions are
 * unimportant so there's no need for fancy domain-crossing logic
 */
(*MARK_DEBUG=DEBUG_ALIGN*) reg doneAlignmentToggle = 0;
(*MARK_DEBUG=DEBUG_SKEW*)  reg chipsAreAligned = 0;
assign sysStatus = { spiActive,
                     doneAlignmentToggle ^ sysStartAlignmentToggle,
                     chipsAreAligned,
                     {32 - 3 - SPI_SHIFTREG_WIDTH{1'b0}},
                     spiShiftReg };

///////////////////////////////////////////////////////////////////////////////
// ADC MCLK (clk32) domain
// Fake hardware
wire                  [ADC_CHIP_COUNT-1:0] fake_DCLK;
wire                  [ADC_CHIP_COUNT-1:0] fake_DRDY;
wire [(ADC_CHIP_COUNT * ADC_PER_CHIP)-1:0] fake_DOUT;
fakeQuartzAD7768 #(
    .ADC_CHIP_COUNT(ADC_CHIP_COUNT),
    .ADC_PER_CHIP(ADC_PER_CHIP),
    .ADC_WIDTH(ADC_WIDTH))
  fakeQuartzAD7768 (
    .MCLK(adcMCLK),
    .adcDCLK(fake_DCLK),
    .adcDRDY(fake_DRDY),
    .adcDOUT(fake_DOUT));
wire                  [ADC_CHIP_COUNT-1:0] muxDCLK_a;
wire                  [ADC_CHIP_COUNT-1:0] muxDRDY_a;
wire [(ADC_CHIP_COUNT * ADC_PER_CHIP)-1:0] muxDOUT_a;

assign muxDCLK_a = sysUseFakeAD7768 ? fake_DCLK : adcDCLK_a;
assign muxDRDY_a = sysUseFakeAD7768 ? fake_DRDY : adcDRDY_a;
assign muxDOUT_a = sysUseFakeAD7768 ? fake_DOUT : adcDOUT_a;

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock (acqClk) domain
localparam ADC_BITCOUNT_LOAD = HEADER_WIDTH + ADC_WIDTH - 2;
localparam ADC_BITCOUNT_WIDTH = $clog2(ADC_BITCOUNT_LOAD+1)+1;
reg [ADC_BITCOUNT_WIDTH-1:0] adcBitCount = ADC_BITCOUNT_LOAD;
(*MARK_DEBUG=DEBUG_ACQ*) wire adcBitCountDone=adcBitCount[ADC_BITCOUNT_WIDTH-1];
reg acqActive = 0;

// Get asynchronous DCLK from from ADC chip into acquisition clock domain.
// Use delayed synchronized value to sample first DRDY and all data lines.
localparam SAMPLE_DELAY_TICKS = (ACQ_CLK_RATE + DCLK_RATE) / (2 * DCLK_RATE);
// Account for DCLK debouncing and the fact that the counter goes to minus one.
localparam SAMPLE_DELAY_LOAD = SAMPLE_DELAY_TICKS - 3;
localparam SAMPLE_DELAY_WIDTH = $clog2(SAMPLE_DELAY_LOAD+1) + 1;
reg [SAMPLE_DELAY_WIDTH-1:0] sampleDelay = SAMPLE_DELAY_LOAD;
(*MARK_DEBUG=DEBUG_ACQ*) wire sampleFlag = sampleDelay[SAMPLE_DELAY_WIDTH-1];
reg delaying = 0;
/*
 * Need to at least latch all DCLK lines to be able to
 * refer to them in a ChipScope instance.
 */
(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] adcDCLK_m = 0;

/*
 * Only need the first since all should be aligned.
 */
(*MARK_DEBUG=DEBUG_ACQ*) reg adcDCLK = 0, adcDRDY = 0;
                     reg adcDCLK_d = 0;
always @(posedge acqClk) begin
    adcDCLK_m <= muxDCLK_a;
    adcDCLK   <= adcDCLK_m[0];
    adcDCLK_d <= adcDCLK;
    if (delaying) begin
        if (sampleFlag) begin
            sampleDelay <= SAMPLE_DELAY_LOAD;
            delaying <= 0;
        end
        else begin
            sampleDelay <= sampleDelay - 1;
        end
    end
    else if (adcDCLK && !adcDCLK_d) begin
        delaying <= 1;
    end
    /*
     * No need to stabilize muxDRDY_a since they are
     * sampled here only when they should be stable.
     */
    if (acqActive) begin
        if (sampleFlag) begin
            if (adcBitCountDone) begin
                acqStrobe <= 1;
            end
            if (muxDRDY_a) begin
                adcBitCount <= ADC_BITCOUNT_LOAD;
            end
            else if (!adcBitCountDone) begin
                adcBitCount <= adcBitCount - 1;
            end
            else begin
                acqActive <= 0;
            end
            adcDRDY <= muxDRDY_a[0];
        end
        else begin
            acqStrobe <= 0;
        end
    end
    else begin
        acqStrobe <= 0;
        if (sampleFlag) begin
            if (muxDRDY_a) begin
                adcBitCount <= ADC_BITCOUNT_LOAD;
                acqActive <= 1;
            end
        end
    end
end

genvar i;
generate
for (i = 0 ; i < ADC_CHIP_COUNT * ADC_PER_CHIP ; i = i + 1) begin : adcDOUT
  reg  [HEADER_WIDTH+ADC_WIDTH-1:0] shiftReg;
  (*MARK_DEBUG=DEBUG_ACQ*)wire [HEADER_WIDTH+ADC_WIDTH-1:0] shiftNext = {
                            shiftReg[HEADER_WIDTH+ADC_WIDTH-2:0], muxDOUT_a[i]};
  assign acqData[i*ADC_WIDTH+:ADC_WIDTH] = shiftReg[0+:ADC_WIDTH];
  assign acqHeaders[i*HEADER_WIDTH+:HEADER_WIDTH] =
                                           shiftReg[ADC_WIDTH+:HEADER_WIDTH];
  always @(posedge acqClk) begin
    if (sampleFlag && acqActive) begin
        shiftReg <= shiftNext;
    end
  end
end
endgenerate

// Measure skew beween ADC DRDY signals.
localparam SKEW_COUNT_WIDTH = $clog2(CEIL_CLOCKS_PER_DRDY) + 1;
(*ASYNC_REG="true"*)      reg [ADC_CHIP_COUNT-1:0] skewDRDY_m = 0;
(*MARK_DEBUG=DEBUG_SKEW*) reg [ADC_CHIP_COUNT-1:0] skewDRDY = 0;
                          reg [ADC_CHIP_COUNT-1:0] skewDRDY_d = 0;
localparam S_SKEW_AWAIT_LOW        = 2'd0,
           S_SKEW_AWAIT_FIRST_HIGH = 2'd1,
           S_SKEW_AWAIT_ALL_HIGH   = 2'd2;
(*MARK_DEBUG=DEBUG_SKEW*) reg [1:0] skewState = S_SKEW_AWAIT_LOW;
reg                           [SKEW_COUNT_WIDTH-1:0] skewCount = ~0;
(*MARK_DEBUG=DEBUG_SKEW*) reg [SKEW_COUNT_WIDTH-1:0] skew = ~0;
wire skewCountDone = skewCount[SKEW_COUNT_WIDTH-1];

/*
 * Tiny logic analyzer
 * sysDRDYhistory is not really in system clock domain,
 * but C code knows that its value may be metastable.
 */
localparam DRDY_HISTORY_CAPACITY = 32 / ADC_CHIP_COUNT;
localparam DRDY_HISTORY_COUNTER_WIDTH = $clog2(DRDY_HISTORY_CAPACITY) + 1;
reg [31:0] drdyHistory;
reg [DRDY_HISTORY_COUNTER_WIDTH-1:0] drdyHistoryCounter;
wire [DRDY_HISTORY_COUNTER_WIDTH-2:0] drdyHistoryIndex =
                            drdyHistoryCounter[0+:DRDY_HISTORY_COUNTER_WIDTH-1];
wire drdyHistoryCounterDone = drdyHistoryCounter[DRDY_HISTORY_COUNTER_WIDTH-1];

always @(posedge acqClk) begin
    skewDRDY_m <= muxDRDY_a;
    skewDRDY   <= skewDRDY_m;
    skewDRDY_d <= skewDRDY;
    case (skewState)
    S_SKEW_AWAIT_LOW: begin
        skewCount <= 0;
        sysDRDYhistory <= drdyHistory;
        drdyHistoryCounter <= 1;
        if (skewDRDY == 0) begin
            drdyHistory <= ~0;
            skewState <= S_SKEW_AWAIT_FIRST_HIGH;
        end
    end
    S_SKEW_AWAIT_FIRST_HIGH: begin
        drdyHistory[0+:ADC_CHIP_COUNT] <= skewDRDY;
        if (skewDRDY == {ADC_CHIP_COUNT{1'b1}}) begin
            skew <= 0;
            skewCount <= 0;
            skewState <= S_SKEW_AWAIT_LOW;
        end
        else if (skewDRDY != 0) begin
            skewCount <= 1;
            skewState <= S_SKEW_AWAIT_ALL_HIGH;
        end
        else if (skewCountDone) begin
            skewState <= S_SKEW_AWAIT_LOW;
        end
        else begin
            skewCount <= skewCount + 1;
        end
    end
    S_SKEW_AWAIT_ALL_HIGH: begin
        if (!drdyHistoryCounterDone) begin
            drdyHistory[(drdyHistoryIndex*ADC_CHIP_COUNT)+:ADC_CHIP_COUNT] <=
                                                                       skewDRDY;
            drdyHistoryCounter <= drdyHistoryCounter + 1;
        end
        if (skewDRDY == {ADC_CHIP_COUNT{1'b1}}) begin
            skew <= skewCount;
            skewCount <= 0;
            skewState <= S_SKEW_AWAIT_LOW;
        end
        else if (skewCountDone) begin
            skew <= ~0;
            skewState <= S_SKEW_AWAIT_LOW;
        end
        else begin
            skewCount <= skewCount + 1;
        end
    end
    endcase
    chipsAreAligned <= (skew <= SKEW_LIMIT_ACQ_TICKS);
end

// Measure time beween PPS strobe and rising edge of first DRDY
localparam PPS_DRDY_COUNT_MAX = (ACQ_CLK_RATE/1000) + (ACQ_CLK_RATE/100000);
localparam PPS_DRDY_COUNT_WIDTH = $clog2(PPS_DRDY_COUNT_MAX+1) + 1;
reg                           [PPS_DRDY_COUNT_WIDTH-1:0] ppsDrdyCount = ~0;
(*MARK_DEBUG=DEBUG_SKEW*) reg [PPS_DRDY_COUNT_WIDTH-1:0] ppsDrdyTicks = ~0;
wire ppsDrdyOverflow = ppsDrdyCount[PPS_DRDY_COUNT_WIDTH-1];
reg ppsDrdyActive = 0;
always @(posedge acqClk) begin
    if (ppsDrdyActive) begin
        if (skewDRDY[0] && !skewDRDY_d[0]) begin
            ppsDrdyTicks <= ppsDrdyCount;
            ppsDrdyActive <= 0;
        end
        else if (ppsDrdyOverflow) begin
            ppsDrdyTicks <= ~0;
            ppsDrdyActive <= 0;
        end
        else begin
            ppsDrdyCount <= ppsDrdyCount + 1;
        end
    end
    else begin
        ppsDrdyCount <= 0;
        if (acqPPSstrobe) begin
            ppsDrdyActive <= 1;
        end
    end
end

/*
 * Don't worry about clock-crossing.
 * C code knows that values may be metastable.
 */
assign sysAuxStatus = { {20-PPS_DRDY_COUNT_WIDTH{1'b0}}, ppsDrdyTicks,
                        {12-SKEW_COUNT_WIDTH{1'b0}}, skew };

// See where ADC DRDY arrives relative to PPS strobe.
localparam PPS_CHECK_TICKS = (ACQ_CLK_RATE + DCLK_RATE) /  DCLK_RATE;
localparam PPS_CHECK_WIDTH = $clog2(PPS_CHECK_TICKS+1) + 1;
reg [PPS_CHECK_WIDTH-1:0] ppsCheck = ~0;
(*MARK_DEBUG=DEBUG_PPS*) wire ppsCheckOverflow = ppsCheck[PPS_CHECK_WIDTH-1];
(*MARK_DEBUG=DEBUG_PPS*) reg [PPS_CHECK_WIDTH-1:0] ppsAlignment = ~0;
reg ppsCheckInProgress = 0;
always @(posedge acqClk) begin
    if (acqPPSstrobe) begin
        ppsCheck <= 0;
        ppsCheckInProgress <= 1;
    end
    else if (ppsCheckInProgress) begin
        if (adcDRDY || ppsCheckOverflow) begin
            ppsCheckInProgress <= 0;
            ppsAlignment <= ppsCheck;
        end
        else begin
            ppsCheck <= ppsCheck + 1;
        end
    end
end

// Emit ADC alignment START synchronized to PPS
localparam PPS_ALIGN_STRETCH_TICKS = ACQ_CLK_RATE / (MCLK_RATE / 4);
localparam PPS_ALIGN_STRETCH_COUNT_WIDTH = $clog2(PPS_ALIGN_STRETCH_TICKS+1)+1;
reg [PPS_ALIGN_STRETCH_COUNT_WIDTH-1:0] ppsAlignCount=PPS_ALIGN_STRETCH_TICKS;
wire ppsAlignDone = ppsAlignCount[PPS_ALIGN_STRETCH_COUNT_WIDTH-1];
(*ASYNC_REG="true"*) reg startAlignmentToggle_m = 0;
(*MARK_DEBUG=DEBUG_ALIGN*) reg startAlignmentToggle = 0;
(*MARK_DEBUG=DEBUG_ALIGN*) reg alignmentActive = 0;

always @(posedge acqClk) begin
    startAlignmentToggle_m <= sysStartAlignmentToggle;
    startAlignmentToggle   <= startAlignmentToggle_m;
    if (alignmentActive) begin
        if (ppsAlignDone) begin
            alignmentActive <= 0;
            doneAlignmentToggle <= !doneAlignmentToggle;
        end
        else begin
            ppsAlignCount <= ppsAlignCount - 1;
        end
    end
    else begin
        ppsAlignCount <= PPS_ALIGN_STRETCH_TICKS;
        if ((startAlignmentToggle != doneAlignmentToggle) && acqPPSstrobe) begin
            alignmentActive <=1;
        end
    end
end
assign adcSTARTn = ~alignmentActive;

endmodule
`default_nettype wire
