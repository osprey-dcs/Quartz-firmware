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
    parameter MCLK_MAX_RATE  = 32000000,
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
    output reg         sysDisableFMCoutputs = 1,

    input  wire        clk32,

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
localparam DCLK_MAX_RATE = MCLK_MAX_RATE / DCLK_DIV;

///////////////////////////////////////////////////////////////////////////////
// System clock (sysClk) domain
///////////////////////////////////////////////////////////////////////////////

reg sysStartAlignmentToggle = 0;
reg doneAlignmentToggle = 0; /* acqClk domain, but needed here */
(*ASYNC_REG="true"*) reg sysDoneAlignmentToggle_m = 0;
reg sysDoneAlignmentToggle = 0;

reg sysResetADC = 1;
reg sysUseFakeAD7768 = 0;
assign adcRESETn = !sysResetADC;

wire [1:0] sysOpcode = sysGPIO_OUT[31:30];
localparam CSR_W_OP_CHIP_PINS     = 2'h1,
           CSR_W_OP_SPI_TRANSFER  = 2'h2,
           CSR_W_OP_AD7768_SELECT = 2'h3;

always @(posedge sysClk) begin
    sysDoneAlignmentToggle_m <= doneAlignmentToggle;
    sysDoneAlignmentToggle   <= sysDoneAlignmentToggle_m;
    if (sysCsrStrobe) begin
        case (sysOpcode)
        CSR_W_OP_CHIP_PINS: begin
            if (sysGPIO_OUT[1]) begin
                sysResetADC <= sysGPIO_OUT[0];
            end
            if (sysGPIO_OUT[3]) begin
                sysUseFakeAD7768 <= sysGPIO_OUT[2];
            end
            if (sysGPIO_OUT[7]) begin
                sysDisableFMCoutputs <= 0;
            end
            if (sysGPIO_OUT[8]) begin
                /*
                 * A request can remain pending for up to a second
                 * so just toggling sysStartAlignmentToggle here
                 * might result in a second request cancelling
                 * an earlier one
                 */
                sysStartAlignmentToggle <= !sysDoneAlignmentToggle;
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
// ADC MCLK domain
///////////////////////////////////////////////////////////////////////////////
// Fake hardware
wire                  [ADC_CHIP_COUNT-1:0] fakeDCLK;
wire                  [ADC_CHIP_COUNT-1:0] fakeDRDY;
wire [(ADC_CHIP_COUNT * ADC_PER_CHIP)-1:0] fakeDOUT;
fakeQuartzAD7768 #(
    .ADC_CHIP_COUNT(ADC_CHIP_COUNT),
    .ADC_PER_CHIP(ADC_PER_CHIP),
    .ADC_WIDTH(ADC_WIDTH))
  fakeQuartzAD7768 (
    .MCLK(clk32),
    .adcDCLK(fakeDCLK),
    .adcDRDY(fakeDRDY),
    .adcDOUT(fakeDOUT));
(*MARK_DEBUG=DEBUG_ACQ*) wire                  [ADC_CHIP_COUNT-1:0] muxDCLK_a;
(*MARK_DEBUG=DEBUG_ACQ*) wire                  [ADC_CHIP_COUNT-1:0] muxDRDY_a;
(*MARK_DEBUG=DEBUG_ACQ*) wire [(ADC_CHIP_COUNT * ADC_PER_CHIP)-1:0] muxDOUT_a;

assign muxDCLK_a = sysUseFakeAD7768 ? fakeDCLK : adcDCLK_a;
assign muxDRDY_a = sysUseFakeAD7768 ? fakeDRDY : adcDRDY_a;
assign muxDOUT_a = sysUseFakeAD7768 ? fakeDOUT : adcDOUT_a;

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock (acqClk) domain
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Get asynchronous DCLK and DRDY into acquisition clock domain.
// Use delayed synchronized value to sample first DRDY and all data lines.
(*ASYNC_REG="true"*) reg [ADC_CHIP_COUNT-1:0] dclk_m = 0, drdy_m = 0;
(*MARK_DEBUG=DEBUG_DRDY*) reg [ADC_CHIP_COUNT-1:0] dclk = 0, dclk_d = 0;
(*MARK_DEBUG=DEBUG_DRDY*) reg [ADC_CHIP_COUNT-1:0] drdy = 0;
(*ASYNC_REG="true"*) reg [(ADC_CHIP_COUNT * ADC_PER_CHIP)-1:0] dout_m = 0;
reg [(ADC_CHIP_COUNT * ADC_PER_CHIP)-1:0] dout = 0;

always @(posedge acqClk) begin
    dclk_m <= muxDCLK_a;
    dclk   <= dclk_m;
    dclk_d <= dclk;
    drdy_m <= muxDRDY_a;
    drdy   <= drdy_m;
    dout_m <= muxDOUT_a;
    dout   <= dout_m;
end
wire [ADC_CHIP_COUNT-1:0] dclkFalling = ~dclk & dclk_d;

///////////////////////////////////////////////////////////////////////////////
// Check DRDY alignment
(*MARK_DEBUG=DEBUG_DRDY*) reg drdyAligned = 0;
localparam [2:0] DRDY_STATE_AWAIT_LOW    = 3'd0,
                 DRDY_STATE_AWAIT_RISING = 3'd1,
                 DRDY_STATE_SKEW_1       = 3'd2,
                 DRDY_STATE_SKEW_2       = 3'd3,
                 DRDY_STATE_SKEW_3       = 3'd4;
(*MARK_DEBUG=DEBUG_DRDY*) reg [2:0] drdyState = DRDY_STATE_AWAIT_LOW;
(*MARK_DEBUG=DEBUG_DRDY*) reg [(4*ADC_CHIP_COUNT)-1:0] drdySkewPattern = 0;
reg anyDRDYrising = 0;

always @(posedge acqClk) begin
    case (drdyState)
    DRDY_STATE_AWAIT_LOW: begin
        anyDRDYrising <= 0;
        if (drdy == 0) begin
            drdyState <= DRDY_STATE_AWAIT_RISING;
        end
    end
    DRDY_STATE_AWAIT_RISING: begin
        if (drdy != 0) begin
            anyDRDYrising <= 1;
            drdySkewPattern[0*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
            if (drdy == {ADC_CHIP_COUNT{1'b1}}) begin
                // Aligned within about 8 ns
                drdyAligned <= 1;
                drdyState <= DRDY_STATE_AWAIT_LOW;
            end
            else begin
                drdyState <= DRDY_STATE_SKEW_1;
            end
        end
    end
    DRDY_STATE_SKEW_1: begin
        anyDRDYrising <= 0;
        drdySkewPattern[1*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
        if (drdy == {ADC_CHIP_COUNT{1'b1}}) begin
            // Aligned within about 16 ns
            drdyAligned <= 1;
            drdyState <= DRDY_STATE_AWAIT_LOW;
        end
        else begin
            drdyState <= DRDY_STATE_SKEW_2;
        end
    end
    DRDY_STATE_SKEW_2: begin
        drdySkewPattern[2*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
        if (drdy == {ADC_CHIP_COUNT{1'b1}}) begin
            // Aligned within between about 8 and about 24 ns
            drdyAligned <= 1;
            drdyState <= DRDY_STATE_AWAIT_LOW;
        end
        else begin
            drdyAligned <= 0;
            drdyState <= DRDY_STATE_SKEW_3;
        end
    end
    DRDY_STATE_SKEW_3: begin
        drdySkewPattern[3*ADC_CHIP_COUNT+:ADC_CHIP_COUNT] <= drdy;
        drdyState <= DRDY_STATE_AWAIT_LOW;
    end
    default: drdyState <= DRDY_STATE_AWAIT_LOW;
    endcase
end

///////////////////////////////////////////////////////////////////////////////
// Sample DRDY and DOUT
// This block samples all lines using the DCLK from the first AD7768.

localparam ADC_BITCOUNT_LOAD = HEADER_WIDTH + ADC_WIDTH - 2;
localparam ADC_BITCOUNT_WIDTH = $clog2(ADC_BITCOUNT_LOAD+1)+1;
reg [ADC_BITCOUNT_WIDTH-1:0] adcBitCount = ADC_BITCOUNT_LOAD;
(*MARK_DEBUG=DEBUG_ACQ*) wire adcBitCountDone=adcBitCount[ADC_BITCOUNT_WIDTH-1];
(*MARK_DEBUG=DEBUG_ACQ*) reg acqActive = 0;

always @(posedge acqClk) begin
    // Enable shift register when framed by DRDY
    if (acqActive) begin
        if (dclkFalling[0]) begin
            if (adcBitCountDone) begin
                acqStrobe <= 1;
            end
            if (drdy[0]) begin
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
        if (dclkFalling[0] && drdy[0]) begin
            // FIXME: Should acqActive be set only if DRDY are aligned?
            acqActive <= 1;
        end
    end
end
genvar i;
generate
for (i = 0 ; i < ADC_CHIP_COUNT * ADC_PER_CHIP ; i = i + 1) begin : adcDOUT
  (*MARK_DEBUG=DEBUG_ACQ*) reg [HEADER_WIDTH+ADC_WIDTH-1:0] shiftReg;
  wire [HEADER_WIDTH+ADC_WIDTH-1:0] shiftNext = {
                                shiftReg[0+:HEADER_WIDTH+ADC_WIDTH-1], dout[i]};
  assign acqData[i*ADC_WIDTH+:ADC_WIDTH] = shiftReg[0+:ADC_WIDTH];
  assign acqHeaders[i*HEADER_WIDTH+:HEADER_WIDTH] =
                                              shiftReg[ADC_WIDTH+:HEADER_WIDTH];
  always @(posedge acqClk) begin
    if (dclkFalling[0] && acqActive) begin
        shiftReg <= shiftNext;
    end
  end
end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// Fetch header using each AD7768's DCLK
// This is done to try to gain insight as to what is happening when
// the DRDY lines of one or more AD7768 chips decide to shift.

reg [(ADC_CHIP_COUNT*ADC_PER_CHIP*HEADER_WIDTH)-1:0] perChipHeaders;
// Multiplex headers back to processor.
// Don't worry about clock crossing, the processor knows to check for races.
localparam HEADER_MUX_SEL_WIDTH = $clog2(ADC_CHIP_COUNT * ADC_PER_CHIP);
reg [HEADER_MUX_SEL_WIDTH-1:0] headerMuxSel = 0;
reg [HEADER_WIDTH-1:0] headerMux = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        case (sysOpcode)
        CSR_W_OP_AD7768_SELECT: begin
            headerMuxSel <= sysGPIO_OUT[HEADER_MUX_SEL_WIDTH-1:0];
        end
        default: ;
        endcase
    end
end
always @(posedge acqClk) begin
    headerMux <= perChipHeaders[headerMuxSel*HEADER_WIDTH+:HEADER_WIDTH];
end

genvar ad7768, c;
generate
for (ad7768 = 0 ; ad7768 < ADC_CHIP_COUNT ; ad7768 = ad7768 + 1) begin : perChip
    localparam BITCOUNT_LOAD = HEADER_WIDTH - 2;
    localparam BITCOUNT_WIDTH = $clog2(BITCOUNT_LOAD+1)+1;
    reg [BITCOUNT_WIDTH-1:0] bitCount = BITCOUNT_LOAD;
    (*MARK_DEBUG=DEBUG_ACQ*) wire bitCountDone = bitCount[BITCOUNT_WIDTH-1];
    (*MARK_DEBUG=DEBUG_ACQ*) reg active = 0;
    always @(posedge acqClk) begin
        // Enable shift register when framed by DRDY
        if (active) begin
            if (dclkFalling[ad7768]) begin
                if (!bitCountDone) begin
                    bitCount <= bitCount - 1;
                end
                else begin
                    active <= 0;
                end
            end
        end
        else begin
            bitCount <= BITCOUNT_LOAD;
            if (dclkFalling[ad7768] && drdy[ad7768]) begin
                active <= 1;
            end
        end
    end
    for (c = 0 ; c < ADC_PER_CHIP ; c = c + 1) begin : perChan
        integer idx = (ad7768 * ADC_PER_CHIP) + c;
        (*MARK_DEBUG=DEBUG_ACQ*) reg [HEADER_WIDTH-1:0] shiftReg;
        wire [HEADER_WIDTH-1:0] shiftNext = {
                                         shiftReg[HEADER_WIDTH-2:0], dout[idx]};
        always @(posedge acqClk) begin
            if (dclkFalling[ad7768] && active) begin
                shiftReg <= shiftNext;
                if (bitCountDone) begin
                    perChipHeaders[idx*HEADER_WIDTH+:HEADER_WIDTH] <= shiftNext;
                end
            end
        end
    end
end
endgenerate

assign sysStatus = { spiActive,
                     sysDoneAlignmentToggle ^ sysStartAlignmentToggle,
                     sysUseFakeAD7768,
                     sysResetADC,
                     {32 - 4 - HEADER_WIDTH - SPI_SHIFTREG_WIDTH{1'b0}},
                     headerMux,
                     spiShiftReg };

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
        if (anyDRDYrising) begin
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
(*MARK_DEBUG=DEBUG_ALIGN*) reg alignmentActive = 0;

localparam ADC_ALIGN_COUNT_WIDTH = 20;
reg [ADC_ALIGN_COUNT_WIDTH-1:0] adcAlignCount = 0;

always @(posedge acqClk) begin
    startAlignmentToggle_m <= sysStartAlignmentToggle;
    startAlignmentToggle   <= startAlignmentToggle_m;
    if (alignmentActive) begin
        if (adcAlignDone) begin
            alignmentActive <= 0;
            doneAlignmentToggle <= startAlignmentToggle;
        end
        else begin
            adcAlignStretch <= adcAlignStretch - 1;
        end
    end
    else begin
        adcAlignStretch <= ADC_ALIGN_STRETCH_TICKS;
        if ((startAlignmentToggle != doneAlignmentToggle) && acqPPSstrobe) begin
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

assign sysDRDYstatus = { !drdyAligned,
                         {32-1-PPS_DRDY_COUNT_WIDTH{1'b0}},
                         ppsDrdyTicks };

assign sysDRDYhistory = { drdyState,
                          {32-3-(4*ADC_CHIP_COUNT){1'b0}},
                          drdySkewPattern };

assign sysAlignCount = { {32-ADC_ALIGN_COUNT_WIDTH{1'b0}}, adcAlignCount };

endmodule
`default_nettype wire
