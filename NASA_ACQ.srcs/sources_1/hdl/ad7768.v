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
    parameter DEBUG_DRDY     = "false",
    parameter DEBUG_ALIGN    = "false",
    parameter DEBUG_ACQ      = "false",
    parameter DEBUG_PINS     = "false",
    parameter DEBUG_SPI      = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysDRDYstatus,
    output wire [31:0] sysDRDYhistory,
    output wire [31:0] sysAlignCount,

    input  wire                                                acqClk,
    (*MARK_DEBUG=DEBUG_ALIGN*) input  wire                     acqPPSstrobe,
    (*MARK_DEBUG=DEBUG_ACQ*)   output reg                      acqStrobe=0,
    (*MARK_DEBUG=DEBUG_ACQ*)   output wire
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

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain
///////////////////////////////////////////////////////////////////////////////

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


///////////////////////////////////////////////////////////////////////////////
// ADC MCLK (clk32) domain
///////////////////////////////////////////////////////////////////////////////
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
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Get asynchronous DCLK and DRDY from into acquisition clock domain.
// Use delayed synchronized value to sample first DRDY and all data lines.
(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] dclk_m = 0, drdy_m = 0;
reg [ADC_CHIP_COUNT-1:0] dclk = 0, dclk_d = 0, dclkRising = 0;
(*MARK_DEBUG=DEBUG_DRDY*) reg [ADC_CHIP_COUNT-1:0] drdy = 0;
reg [ADC_CHIP_COUNT-1:0] drdy_d = 0, drdyRising = 0;

always @(posedge acqClk) begin
    dclk_m <= muxDCLK_a;
    dclk   <= dclk_m;
    dclk_d <= dclk;
    dclkRising <= dclk & ~dclk_d;
    drdy_m <= muxDRDY_a;
    drdy   <= drdy_m;
    drdy_d <= drdy;
    drdyRising <= drdy & ~drdy_d;
end

///////////////////////////////////////////////////////////////////////////////
// Check DRDY alignment
(*MARK_DEBUG=DEBUG_DRDY*) reg drdyAligned = 0;
localparam [1:0] DRDY_STATE_AWAIT_RISING = 2'd0,
                 DRDY_STATE_SKEW_1       = 2'd1,
                 DRDY_STATE_SKEW_2       = 2'd1,
                 DRDY_STATE_AWAIT_LOW    = 2'd3;
(*MARK_DEBUG=DEBUG_DRDY*) reg [1:0] drdyState = DRDY_STATE_AWAIT_RISING;
(*MARK_DEBUG=DEBUG_DRDY*) reg [(3*ADC_CHIP_COUNT)-1:0] drdySkewPattern = 0;

always @(posedge acqClk) begin
    case (drdyState)
    DRDY_STATE_AWAIT_RISING: begin
        if (drdyRising) begin
            drdySkewPattern[0*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
            if (drdy == {ADC_CHIP_COUNT{1'b1}}) begin
                drdyAligned <= 1;
            end
            else begin
                drdyState <= DRDY_STATE_SKEW_1;
            end
        end
    end
    DRDY_STATE_SKEW_1: begin
        drdySkewPattern[1*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
        if (drdy == {ADC_CHIP_COUNT{1'b1}}) begin
            drdyAligned <= 1;
            drdyState <= DRDY_STATE_AWAIT_RISING;
        end
        else begin
            drdyState <= DRDY_STATE_SKEW_2;
        end
    end
    DRDY_STATE_SKEW_2: begin
        drdySkewPattern[2*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
        if (drdy == {ADC_CHIP_COUNT{1'b1}}) begin
            drdyAligned <= 1;
            drdyState <= DRDY_STATE_AWAIT_RISING;
        end
        else begin
            drdyAligned <= 0;
            drdyState <= DRDY_STATE_AWAIT_LOW;
        end
    end
    DRDY_STATE_AWAIT_LOW: begin
        if (drdy == {ADC_CHIP_COUNT{1'b0}}) begin
            drdyState <= DRDY_STATE_AWAIT_RISING;
        end
    end
    default: drdyState <= DRDY_STATE_AWAIT_LOW;
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// Sample DRDY and DOUT
// No need to stabilize them since they are should be stable when sampled.

localparam SAMPLE_DELAY_TICKS = (ACQ_CLK_RATE + DCLK_RATE) / (2 * DCLK_RATE);
localparam SAMPLE_DELAY_LOAD = SAMPLE_DELAY_TICKS - 4;
localparam SAMPLE_DELAY_WIDTH = $clog2(SAMPLE_DELAY_LOAD+1) + 1;
reg [SAMPLE_DELAY_WIDTH-1:0] sampleDelay = SAMPLE_DELAY_LOAD;
(*MARK_DEBUG=DEBUG_ACQ*) wire sampleFlag = sampleDelay[SAMPLE_DELAY_WIDTH-1];
reg delaying = 0;

localparam ADC_BITCOUNT_LOAD = HEADER_WIDTH + ADC_WIDTH - 2;
localparam ADC_BITCOUNT_WIDTH = $clog2(ADC_BITCOUNT_LOAD+1)+1;
reg [ADC_BITCOUNT_WIDTH-1:0] adcBitCount = ADC_BITCOUNT_LOAD;
(*MARK_DEBUG=DEBUG_ACQ*) wire adcBitCountDone=adcBitCount[ADC_BITCOUNT_WIDTH-1];
reg acqActive = 0;

always @(posedge acqClk) begin
    // Assert sampleFlag near center of shortest DCLK cycle
    if (delaying) begin
        if (sampleFlag) begin
            sampleDelay <= SAMPLE_DELAY_LOAD;
            delaying <= 0;
        end
        else begin
            sampleDelay <= sampleDelay - 1;
        end
    end
    else if (dclkRising[0] != 0) begin
        delaying <= 1;
    end

    // Enable shift register when framed by DRDY
    if (acqActive) begin
        if (sampleFlag) begin
            if (adcBitCountDone) begin
                acqStrobe <= 1;
            end
            if (muxDRDY_a[0]) begin
                adcBitCount <= ADC_BITCOUNT_LOAD;
            end
            else if (!adcBitCountDone) begin
                adcBitCount <= adcBitCount - 1;
            end
            else begin
                acqActive <= 0;
            end
        end
        else begin
            acqStrobe <= 0;
        end
    end
    else begin
        acqStrobe <= 0;
        adcBitCount <= ADC_BITCOUNT_LOAD;
        if (sampleFlag) begin
            if (muxDRDY_a[0]) begin
                // FIXME: Should acqActive be set only if DRDY are aligned?
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

//////////////////////////////////////////////////////////////////////////////
// Measure time beween PPS strobe and rising edge of first DRDY
//
localparam PPS_DRDY_COUNT_MAX = (ACQ_CLK_RATE/1000) + (ACQ_CLK_RATE/100000);
localparam PPS_DRDY_COUNT_WIDTH = $clog2(PPS_DRDY_COUNT_MAX+1) + 1;
reg                           [PPS_DRDY_COUNT_WIDTH-1:0] ppsDrdyCount = ~0;
(*MARK_DEBUG=DEBUG_DRDY*) reg [PPS_DRDY_COUNT_WIDTH-1:0] ppsDrdyTicks = ~0;
wire ppsDrdyOverflow = ppsDrdyCount[PPS_DRDY_COUNT_WIDTH-1];
reg ppsDrdyActive = 0;
always @(posedge acqClk) begin
    if (ppsDrdyActive) begin
        if (drdyRising[0]) begin
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

//////////////////////////////////////////////////////////////////////////////
// Emit ADC alignment START synchronized to PPS
// Request an alignment upon request from the system or on DRDY misalignment.
// Stretch START* to about 500 ns.
localparam ADC_ALIGN_STRETCH_TICKS = ACQ_CLK_RATE / 2000000;
localparam ADC_ALIGN_STRETCH_COUNT_WIDTH = $clog2(ADC_ALIGN_STRETCH_TICKS+1)+1;
reg [ADC_ALIGN_STRETCH_COUNT_WIDTH-1:0] adcAlignStretch=ADC_ALIGN_STRETCH_TICKS;
wire adcAlignDone = adcAlignStretch[ADC_ALIGN_STRETCH_COUNT_WIDTH-1];
(*ASYNC_REG="true"*) reg startAlignmentToggle_m = 0;
(*MARK_DEBUG=DEBUG_ALIGN*) reg startAlignmentToggle = 0;
(*MARK_DEBUG=DEBUG_ALIGN*) reg doneAlignmentToggle = 0;
(*MARK_DEBUG=DEBUG_ALIGN*) reg alignmentActive = 0;

localparam ADC_ALIGN_COUNT_WIDTH = 20;
reg [ADC_ALIGN_COUNT_WIDTH-1:0] adcAlignCount = 0;

always @(posedge acqClk) begin
    startAlignmentToggle_m <= sysStartAlignmentToggle;
    startAlignmentToggle   <= startAlignmentToggle_m;
    if (alignmentActive) begin
        if (adcAlignDone) begin
            alignmentActive <= 0;
            doneAlignmentToggle <= !doneAlignmentToggle;
        end
        else begin
            adcAlignStretch <= adcAlignStretch - 1;
        end
    end
    else begin
        adcAlignStretch <= ADC_ALIGN_STRETCH_TICKS;
        if ((!drdyAligned || (startAlignmentToggle != doneAlignmentToggle))
         && acqPPSstrobe) begin
            adcAlignCount <= adcAlignCount + 1;
            alignmentActive <=1;
        end
    end
end
assign adcSTARTn = ~alignmentActive;

//////////////////////////////////////////////////////////////////////////////
// Pass status back to system
// Don't worry about clock-crossing since the C code
// knows the values may be metastable.

assign sysStatus = { spiActive,
                     doneAlignmentToggle ^ sysStartAlignmentToggle,
                     {32 - 2 - SPI_SHIFTREG_WIDTH{1'b0}},
                     spiShiftReg };

assign sysDRDYstatus = { !drdyAligned,
                         {32-1-PPS_DRDY_COUNT_WIDTH{1'b0}},
                         ppsDrdyTicks };

assign sysDRDYhistory = { {32-(3*ADC_CHIP_COUNT){1'b0}}, drdySkewPattern };

assign sysAlignCount = { {32-ADC_ALIGN_COUNT_WIDTH{1'b0}}, adcAlignCount };

endmodule
`default_nettype wire
