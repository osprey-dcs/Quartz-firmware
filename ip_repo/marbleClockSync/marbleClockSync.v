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
 * Synchronize Marble VCXO clock to PPS marker
 */
`default_nettype none
module marbleClockSync #(
    parameter CLK_RATE                 = 100000000,
    parameter DAC_COUNTS_PER_HZ        = 35,
    parameter DEBUG                    = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysAuxStatus,
    output wire [31:0] sysHwInterval,
    output wire [31:0] sysPPSjitter,
    input  wire        stableClk200,
    input  wire        clk,
    input  wire        ppsPrimary_a,
    input  wire        ppsSecondary_a,
    input  wire        isOffsetBinary,
    (*MARK_DEBUG=DEBUG*) output reg  hwPPSvalid = 0,
    (*MARK_DEBUG=DEBUG*) output reg  ppsStrobe = 0,
    (*MARK_DEBUG=DEBUG*) output wire ppsMarker,
    (*MARK_DEBUG=DEBUG*) output reg  ppsToggle = 0,
    (*MARK_DEBUG=DEBUG*) output reg  SPI_CLK = 1,
    (*MARK_DEBUG=DEBUG*) output reg  SPI_SYNCn = 1,
    (*MARK_DEBUG=DEBUG*) output wire SPI_SDI);

/*
 * Make error limit fairly wide to accomodate devices
 * with different DAC_COUNTS_PER_HZ sensitivity.
 */
localparam DAC_WIDTH = 16;
localparam UNLOCK_COUNT = 20; // Unlocked until good for this many samples
localparam DETECT_RANGE_US = 30; // Detect local PPS within +/- this of hardware
localparam SCALE_SHIFT = 8; // Integer arithmetic scaling
localparam LOW_JITTER_LIMIT_NS = 38;
localparam LOW_JITTER_HYSTERESIS_NS = 10;

//////////////////////////////////////////////////////////////////////////////
// System clock domain

reg sysPLLenable = 0;
reg [DAC_WIDTH-1:0] sysDACvalue;
reg sysDACtoggle = 0;
reg sysEnableJitter = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        if (sysGPIO_OUT[30]) begin
            sysPLLenable <= 0;
        end
        else if (sysGPIO_OUT[31]) begin
            sysPLLenable <= 1;
        end

        if (sysGPIO_OUT[29]) begin
            sysDACtoggle <= !sysDACtoggle;
            sysDACvalue = sysGPIO_OUT[DAC_WIDTH-1:0];
        end

        if (sysGPIO_OUT[27]) begin
            sysEnableJitter <= 0;
        end
        else if (sysGPIO_OUT[28]) begin
            sysEnableJitter <= 1;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// Select hardware PPS reference

wire ppsPrimaryStrobe, ppsPrimaryIsValid;
wire ppsSecondaryStrobe, ppsSecondaryIsValid;

marbleClockSyncIsPPSvalid #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(2000),
    .DEBUG(DEBUG))
  marbleClockSyncIsPPSvalidPrimary (
    .clk(clk),
    .pps_a(ppsPrimary_a),
    .ppsStrobe(ppsPrimaryStrobe),
    .ppsIsValid(ppsPrimaryIsValid));

marbleClockSyncIsPPSvalid #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(2000),
    .DEBUG(DEBUG))
  marbleClockSyncIsPPSvalidSecondary (
    .clk(clk),
    .pps_a(ppsSecondary_a),
    .ppsStrobe(ppsSecondaryStrobe),
    .ppsIsValid(ppsSecondaryIsValid));

// Optional jitter addition
(*ASYN_REG="true"*) reg enableJitter_m = 0;
reg enableJitter = 0;
wire ppsJitteryStrobe;
jitterbug jitter(.clk(clk),
                 .ppsStrobe(ppsSecondaryStrobe),
                 .ppsJitteryStrobe(ppsJitteryStrobe));

always @(posedge clk) begin
    hwPPSvalid <= ppsPrimaryIsValid || ppsSecondaryIsValid;
    enableJitter_m <= sysEnableJitter;
    enableJitter   <= enableJitter_m;
end
(*MARK_DEBUG=DEBUG*) wire hwPPSstrobe = ppsPrimaryIsValid ? ppsPrimaryStrobe
                                                          : (enableJitter ? 
                                                            ppsJitteryStrobe :
                                                            ppsSecondaryStrobe);
reg hwPPStoggle = 0;

//////////////////////////////////////////////////////////////////////////////
// PPS generation
localparam CLK_COUNTER_LOAD = CLK_RATE - 2;
localparam CLK_COUNTER_WIDTH = $clog2(CLK_COUNTER_LOAD+1)+1;
reg [CLK_COUNTER_WIDTH-1:0] clkCounter = CLK_COUNTER_LOAD;
wire clkCounterDone = clkCounter[CLK_COUNTER_WIDTH-1];
reg [CLK_COUNTER_WIDTH-1:0] hwIntervalCounter = 0, hwInterval = 0;

localparam PPS_STRETCH_LOAD = CLK_RATE / 100000;
localparam PPS_STRETCH_WIDTH = $clog2(PPS_STRETCH_LOAD+1)+1;
reg signed [PPS_STRETCH_WIDTH-1:0] ppsStretch = 0;
assign ppsMarker = ppsStretch[PPS_STRETCH_WIDTH-1];

//////////////////////////////////////////////////////////////////////////////
// Phase locked loop

localparam DETECT_RANGE = ((CLK_RATE / 1000) * DETECT_RANGE_US) / 1000;
localparam GATE_COUNTER_WIDTH = $clog2(DETECT_RANGE) + 1;
reg signed [GATE_COUNTER_WIDTH-1:0] earlyCounter = 0, lateCounter = 0;
(*MARK_DEBUG=DEBUG*)wire earlyOverflow = earlyCounter[GATE_COUNTER_WIDTH-1];
(*MARK_DEBUG=DEBUG*)wire lateOverflow = lateCounter[GATE_COUNTER_WIDTH-1];

localparam UNLOCK_COUNTER_RELOAD = UNLOCK_COUNT - 1;
localparam UNLOCK_COUNTER_WIDTH = $clog2(UNLOCK_COUNTER_RELOAD+1)+1;
reg [UNLOCK_COUNTER_WIDTH-1:0] unlockCounter = UNLOCK_COUNTER_RELOAD;
(*MARK_DEBUG=DEBUG*) wire pllLocked = unlockCounter[UNLOCK_COUNTER_WIDTH-1];

(*ASYNC_REG="true"*) reg enable_m = 0;
(*MARK_DEBUG=DEBUG*) reg enable = 0;
(*ASYNC_REG="true"*) reg dacToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg dacToggle = 0, dacToggle_d = 0;

// Control action
localparam CTRL_WIDTH = GATE_COUNTER_WIDTH + SCALE_SHIFT + 2;
(*MARK_DEBUG=DEBUG*) reg signed [CTRL_WIDTH-1:0] phaseError;
(*MARK_DEBUG=DEBUG*) reg signed [CTRL_WIDTH-1:0] phaseErrorOld;
(*MARK_DEBUG=DEBUG*) reg signed [CTRL_WIDTH-1:0] hzDeltaScaled;

// VCXO scaling
localparam PRODUCT_WIDTH = CTRL_WIDTH + $clog2(DAC_COUNTS_PER_HZ) + 1;
localparam DAC_SCALED_WIDTH = DAC_WIDTH + SCALE_SHIFT;
(*MARK_DEBUG=DEBUG*) reg  signed    [PRODUCT_WIDTH-1:0] dacDeltaScaled;
(*MARK_DEBUG=DEBUG*) reg  signed [DAC_SCALED_WIDTH-1:0] dacScaled;
(*MARK_DEBUG=DEBUG*) wire signed        [DAC_WIDTH-1:0] dacValue =
                                              dacScaled[SCALE_SHIFT+:DAC_WIDTH];
wire [DAC_WIDTH-1:0] sendValue = dacValue^{isOffsetBinary,{DAC_WIDTH-1{1'b0}}};
(*MARK_DEBUG=DEBUG*) reg dacStrobe = 0;
(*MARK_DEBUG=DEBUG*) reg dacBusy = 0;

// Scale and accumulate
wire signed [PRODUCT_WIDTH:0] dacDeltaScaledWide = dacDeltaScaled;
wire signed [PRODUCT_WIDTH:0] dacScaledWide = dacScaled;
reg  signed [PRODUCT_WIDTH:0] nextDacScaledWide;

// Clipping
wire signed        [DAC_WIDTH-1:0] dacMax = {1'b0, {DAC_WIDTH-1{1'b1}}};
wire signed        [DAC_WIDTH-1:0] dacMin = {1'b1, {DAC_WIDTH-1{1'b0}}};
wire signed [DAC_SCALED_WIDTH-1:0] scaledMax= {dacMax,{SCALE_SHIFT{1'b0}}};
wire signed [DAC_SCALED_WIDTH-1:0] scaledMin= {dacMin,{SCALE_SHIFT{1'b0}}};
wire signed      [PRODUCT_WIDTH:0] wideMax = scaledMax;
wire signed      [PRODUCT_WIDTH:0] wideMin = scaledMin;

// State machine
localparam [2:0] PLL_ST_INITIALIZE             = 3'd0,
                 PLL_ST_AWAIT_HW_PPS           = 3'd1,
                 PLL_ST_AWAIT_LATE_HW_PPS      = 3'd2,
                 PLL_ST_COMPUTE_CONTROL_ACTION = 3'd3,
                 PLL_ST_AWAIT_SCALING_1        = 3'd4,
                 PLL_ST_AWAIT_SCALING_2        = 3'd5,
                 PLL_ST_APPLY_DAC_DELTA        = 3'd6,
                 PLL_ST_AWAIT_DAC_IDLE         = 3'd7;
(*MARK_DEBUG=DEBUG*) reg [2:0] pllState = PLL_ST_INITIALIZE;
reg measuredJitterIsLow = 0;
(*ASYNC_REG="true"*) reg jitterIsLow_m =0;
reg jitterIsLow =0;

always @(posedge clk) begin
    /*
     * Housekeeping
     */
    enable_m <= sysPLLenable;
    enable   <= enable_m;
    dacToggle_m <= sysDACtoggle;
    dacToggle   <= dacToggle_m;
    dacToggle_d <= dacToggle;
    jitterIsLow_m <= measuredJitterIsLow;
    jitterIsLow   <= jitterIsLow_m;

    /*
     * Scale control action (Hz) to DAC counts.
     */
    dacDeltaScaled <= hzDeltaScaled * DAC_COUNTS_PER_HZ;
    nextDacScaledWide <= dacScaledWide + dacDeltaScaledWide;

    /*
     * Measure interval between HW PPS strobes
     */
    if (hwPPSstrobe) begin
        hwPPStoggle <= !hwPPStoggle;
        hwInterval <= hwIntervalCounter;
        hwIntervalCounter <= 1;
    end
    else begin
        hwIntervalCounter <= hwIntervalCounter + 1;
    end

    /*
     * Generate PPS
     */
    if ((pllState == PLL_ST_INITIALIZE) ? hwPPSstrobe : clkCounterDone) begin
        clkCounter <= CLK_COUNTER_LOAD;
        ppsStrobe <= 1;
        ppsStretch <= -PPS_STRETCH_LOAD;
        ppsToggle <= !ppsToggle;
    end
    else begin
        clkCounter <= clkCounter - 1;
        ppsStrobe <= 0;
        if (ppsMarker) begin
            ppsStretch <= ppsStretch + 1;
        end
    end

    /*
     * State machine
     */
    case (pllState)
    PLL_ST_INITIALIZE: begin
        phaseError <= 1 << GATE_COUNTER_WIDTH;
        phaseErrorOld <= 0;
        earlyCounter <= ~0;
        unlockCounter <= UNLOCK_COUNTER_RELOAD;
        if (enable && hwPPSvalid && hwPPSstrobe) begin
            pllState <= PLL_ST_AWAIT_HW_PPS;
        end
        else if (dacToggle != dacToggle_d) begin
            dacScaled <= {sysDACvalue, {SCALE_SHIFT{1'b0}} };
            dacStrobe <= 1;
        end
        else begin
            dacStrobe <= 0;
        end
    end
    PLL_ST_AWAIT_HW_PPS: begin
        lateCounter <= 1;
        if (!enable || !hwPPSvalid) begin
            pllState <= PLL_ST_INITIALIZE;
        end
        else if (hwPPSstrobe) begin
            if (ppsStrobe) begin
                phaseError <= 0;
                pllState <= PLL_ST_COMPUTE_CONTROL_ACTION;
            end
            else if (!earlyOverflow) begin
                phaseError <= -earlyCounter;
                pllState <= PLL_ST_COMPUTE_CONTROL_ACTION;
            end
            else begin
                pllState <= PLL_ST_AWAIT_LATE_HW_PPS;
            end
        end
        if (ppsStrobe) begin
            earlyCounter <= 1;
        end
        else if (!earlyOverflow) begin
            earlyCounter <= earlyCounter + 1;
        end
    end
    PLL_ST_AWAIT_LATE_HW_PPS: begin
        lateCounter <= lateCounter + 1;
        if (ppsStrobe) begin
            phaseError <= lateCounter;
            pllState <= PLL_ST_COMPUTE_CONTROL_ACTION;
        end
        else if (lateOverflow) begin
            // No local PPS in detect window.
            pllState <= PLL_ST_INITIALIZE;
        end
    end
    PLL_ST_COMPUTE_CONTROL_ACTION: begin
        /*
         * Velocity form of proportional plus integral controller.
         *
         * Slow PLL: Kp = 1/16      Ki = 1/256
         * Fast PLL: Kp = 1/2       Ki = 1/4
         */
        hzDeltaScaled <= pllLocked && !jitterIsLow ?
                          (((phaseError - phaseErrorOld) << (SCALE_SHIFT - 4)) +
                            (phaseError << (SCALE_SHIFT - 8)))
                                                :
                          (((phaseError - phaseErrorOld) << (SCALE_SHIFT - 1)) +
                            (phaseError << (SCALE_SHIFT - 2)));
        phaseErrorOld <= phaseError;
        earlyCounter <= ~0;
        pllState <= PLL_ST_AWAIT_SCALING_1;
    end
    PLL_ST_AWAIT_SCALING_1: begin // Multiply
        pllState <= PLL_ST_AWAIT_SCALING_2;
    end
    PLL_ST_AWAIT_SCALING_2: begin // Accumulate
        pllState <= PLL_ST_APPLY_DAC_DELTA;
    end
    PLL_ST_APPLY_DAC_DELTA: begin // Clip
        /*
         * Saturating math
         * This accumulation and saturationcould be done in the DSP48E that
         * is doing the Hz->DAC scaling, but for now we'll do it by hand.
         */
        if (nextDacScaledWide > wideMax) begin
            dacScaled <= scaledMax;
        end
        else if (nextDacScaledWide < wideMin) begin
            dacScaled <= scaledMin;
        end
        else begin
            dacScaled <= nextDacScaledWide[0+:DAC_SCALED_WIDTH];
        end
        if (!pllLocked) begin
            unlockCounter <= unlockCounter - 1;
        end
        dacStrobe <= 1;
        pllState <= PLL_ST_AWAIT_DAC_IDLE;
    end
    PLL_ST_AWAIT_DAC_IDLE: begin
        dacStrobe <= 0;
        if (!dacStrobe && !dacBusy) begin
            pllState <= PLL_ST_AWAIT_HW_PPS;
        end
    end
    default: pllState <= PLL_ST_INITIALIZE;
    endcase
end

wire signed [23:0] phaseError24 = phaseError;
assign sysStatus = {pllLocked, ppsToggle, enable, enableJitter,
                    jitterIsLow, 3'b0, phaseError24};
assign sysAuxStatus = { {32-3-DAC_WIDTH{1'b0}}, pllState, dacValue };
assign sysHwInterval = { hwPPSvalid, hwPPStoggle,
                         ppsSecondaryIsValid, ppsPrimaryIsValid,
                         {32-4-(CLK_COUNTER_WIDTH-1){1'b0}},
                         hwInterval[0+:CLK_COUNTER_WIDTH-1] };

//////////////////////////////////////////////////////////////////////////////
// Jitter measurement
localparam JITTER_FILTER_LOG2_ALPHA = 5;
localparam JITTER_CLK_RATE = 200000000;
localparam JITTER_COUNTER_MAX = (JITTER_CLK_RATE / 10) * 12;
localparam JITTER_COUNTER_WIDTH = $clog2(JITTER_COUNTER_MAX+1) + 1;

// Ignore differences greater than 50 microseconds
localparam JITTER_MAX_CHANGE = JITTER_CLK_RATE/ 20000;
localparam JITTER_VALUE_WIDTH = $clog2(JITTER_MAX_CHANGE+1) + 1;
localparam JITTER_OUTPUT_WIDEN = 3;
localparam JITTER_OUTPUT_WIDTH = JITTER_VALUE_WIDTH + JITTER_OUTPUT_WIDEN;

(*MARK_DEBUG=DEBUG*) reg [JITTER_COUNTER_WIDTH-1:0] jitterIntervalCounter = 0;
                     reg [JITTER_COUNTER_WIDTH-1:0] jitterInterval = 0;
(*MARK_DEBUG=DEBUG*)reg signed[JITTER_COUNTER_WIDTH:0] jitterIntervalChange = 0;
(*MARK_DEBUG=DEBUG*)reg    [JITTER_COUNTER_WIDTH:0] jitterIntervalChangeAbs = 0;

(*ASYNC_REG="true"*) reg jitterPPSvalid_m = 0;
(*ASYNC_REG="true"*) reg jitterPPStoggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg jitterPPSvalid = 0;
(*MARK_DEBUG=DEBUG*) reg [1:0] jitterPPSvalidCount = 0;
(*MARK_DEBUG=DEBUG*) reg jitterPPStoggle = 0;
                     reg jitterPPStoggle_d = 0;
(*MARK_DEBUG=DEBUG*) reg [2:0] jitterState = 0;

reg [JITTER_VALUE_WIDTH+JITTER_FILTER_LOG2_ALPHA-1:0] jitterFilter;

// Not really in system clock domain, but C code knows value may have races.
assign sysPPSjitter = { {32-JITTER_OUTPUT_WIDTH{1'b0}},
                   jitterFilter[JITTER_VALUE_WIDTH+JITTER_FILTER_LOG2_ALPHA-1 -:
                                                         JITTER_OUTPUT_WIDTH] };

always @(posedge stableClk200) begin
    jitterPPSvalid_m <= hwPPSvalid;
    jitterPPSvalid   <= jitterPPSvalid_m;
    jitterPPStoggle_m <= hwPPStoggle;
    jitterPPStoggle   <= jitterPPStoggle_m;
    jitterPPStoggle_d <= jitterPPStoggle;
    if (jitterPPSvalid) begin
        if (jitterPPStoggle != jitterPPStoggle_d) begin
            jitterIntervalChange <= {1'b0, jitterIntervalCounter} -
                                                         {1'b0, jitterInterval};
            jitterInterval <= jitterIntervalCounter;
            jitterIntervalCounter <= 1;
            if (jitterPPSvalidCount[1]) begin
                jitterState[0] <= 1;
            end
            else begin
                jitterPPSvalidCount <= jitterPPSvalidCount + 1;
            end
        end
        else begin
            jitterState <= jitterState << 1;
            jitterIntervalCounter <= jitterIntervalCounter + 1;
        end
    end
    else begin
        jitterPPSvalidCount <= 0;
        jitterState <= 0;
    end
    if (jitterState[0])  begin
        jitterIntervalChangeAbs <= (jitterIntervalChange < 0) ?
                                                        -jitterIntervalChange :
                                                         jitterIntervalChange;
    end
    if (jitterState[1]) begin
        if (jitterIntervalChangeAbs > JITTER_MAX_CHANGE) begin
            jitterIntervalChangeAbs <= JITTER_MAX_CHANGE;
        end
    end
    if (jitterState[2]) begin
        jitterFilter <= jitterFilter -
               {{JITTER_FILTER_LOG2_ALPHA{1'b0}},
                   jitterFilter[JITTER_FILTER_LOG2_ALPHA+:JITTER_VALUE_WIDTH]} +
               {{JITTER_FILTER_LOG2_ALPHA{1'b0}},
                    jitterIntervalChangeAbs[JITTER_VALUE_WIDTH-1:0]};

    end
    if (measuredJitterIsLow) begin
        if (sysPPSjitter > (((LOW_JITTER_LIMIT_NS + LOW_JITTER_HYSTERESIS_NS) *
                                         (1 << JITTER_OUTPUT_WIDEN)) / 5)) begin
            measuredJitterIsLow <= 0;
        end
    end
    else begin
        if (sysPPSjitter <= ((LOW_JITTER_LIMIT_NS *
                                         (1 << JITTER_OUTPUT_WIDEN)) / 5)) begin
            measuredJitterIsLow <= 1;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// SPI DAC8550
// Was AD5662 but changed 2022-08-23 due to availability.
// Electrically compatible, but the DAC8550 is twos-complement.
function integer ns2ticks;
    input integer ns;
    begin
        ns2ticks = (((ns) * (CLK_RATE/100)) + 9999999) / 10000000;
    end
endfunction
localparam Tdelay = ns2ticks(50/2); // 20 MHz clock
localparam SPI_DELAY_RELOAD = (Tdelay >= 2) ? Tdelay - 2 : 0;
localparam SPI_DELAYCOUNTER_WIDTH = $clog2(SPI_DELAY_RELOAD+1)+1;
reg [SPI_DELAYCOUNTER_WIDTH-1:0] spiDelayCounter = SPI_DELAY_RELOAD;
wire spiDelayCounterDone = spiDelayCounter[SPI_DELAYCOUNTER_WIDTH-1];

localparam SPI_SHIFTREG_WIDTH = 24;
localparam SPI_BITCOUNTER_RELOAD = SPI_SHIFTREG_WIDTH - 1;
localparam SPI_BITCOUNTER_WIDTH = $clog2(SPI_BITCOUNTER_RELOAD+1)+1;
reg [SPI_BITCOUNTER_WIDTH-1:0] spiBitCounter = ~0;
wire spiBitCounterDone = spiBitCounter[SPI_BITCOUNTER_WIDTH-1];

reg [SPI_SHIFTREG_WIDTH-1:0] spiShiftReg = 0;
assign SPI_SDI = spiShiftReg[SPI_SHIFTREG_WIDTH-1];

localparam SPI_ST_IDLE     = 2'd0,
           SPI_ST_TRANSFER = 2'd1,
           SPI_ST_FINISH   = 2'd2;
reg [1:0] spiState = SPI_ST_IDLE;

always @(posedge clk) begin
    if ((spiState == SPI_ST_IDLE) || spiDelayCounterDone) begin
        spiDelayCounter <= SPI_DELAY_RELOAD;
    end
    else begin
        spiDelayCounter <= spiDelayCounter - 1;
    end
    case (spiState)
    SPI_ST_IDLE: begin
        spiBitCounter <= SPI_BITCOUNTER_RELOAD;
        if (dacStrobe) begin
            dacBusy <= 1;
            spiShiftReg <= {{SPI_SHIFTREG_WIDTH-DAC_WIDTH{1'b0}}, sendValue};
            SPI_SYNCn <= 0;
            spiState <= SPI_ST_TRANSFER;
        end
    end
    SPI_ST_TRANSFER: begin
        if (spiDelayCounterDone) begin
            if (SPI_CLK) begin
                spiBitCounter <= spiBitCounter - 1;
                if (spiBitCounterDone) begin
                    SPI_SYNCn <= 1;
                    spiState <= SPI_ST_FINISH;
                end
                else begin
                    SPI_CLK <= 0;
                end
            end
            else begin
                SPI_CLK <= 1;
                spiShiftReg <= {spiShiftReg[SPI_SHIFTREG_WIDTH-2:0], 1'b0};
            end
        end
    end
    SPI_ST_FINISH: begin
        if (spiDelayCounterDone) begin
            dacBusy <= 0;
            spiState <= SPI_ST_IDLE;
        end
    end
    default: spiState <= SPI_ST_IDLE;
    endcase
end
endmodule

/*
 * Debounce and confirm validity of PPS signal.
 * Negative logic on output to ensure the absolute minimum
 * number of LUTs between the input and output signals.
 */
module marbleClockSyncIsPPSvalid #(
    parameter CLK_RATE    = -1,
    parameter DEBOUNCE_NS = -1,
    parameter DEBUG       = "false"
    ) (
                         input  wire clk,
                         input  wire pps_a,
    (*MARK_DEBUG=DEBUG*) output reg  ppsStrobe,
    (*MARK_DEBUG=DEBUG*) output reg  ppsIsValid = 0);

localparam DEBOUNCE_TICKS = (DEBOUNCE_NS * (CLK_RATE/1000) + 999999) / 1000000;
localparam DEBOUNCE_RELOAD = DEBOUNCE_TICKS - 2;
localparam DEBOUNCE_COUNTER_WIDTH = $clog2(DEBOUNCE_RELOAD+1) + 1;
reg [DEBOUNCE_COUNTER_WIDTH-1:0] debounceCounter = DEBOUNCE_RELOAD;
(*MARK_DEBUG=DEBUG*)wire debounceDone=debounceCounter[DEBOUNCE_COUNTER_WIDTH-1];

localparam PPS_TOOSLOW_RELOAD = CLK_RATE + (CLK_RATE / 5000);
localparam PPS_TOOFAST_RELOAD = CLK_RATE - (CLK_RATE / 5000);
localparam PPS_RELOAD         = CLK_RATE - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_TOOSLOW_RELOAD+1) + 1;

reg [PPS_COUNTER_WIDTH-1:0] tooSlowCounter = PPS_TOOSLOW_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooSlow = tooSlowCounter[PPS_COUNTER_WIDTH-1];
reg [PPS_COUNTER_WIDTH-1:0] tooFastCounter = PPS_TOOFAST_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooFast = !tooFastCounter[PPS_COUNTER_WIDTH-1];

(*ASYNC_REG="TRUE"*) reg pps_m = 0;
(*MARK_DEBUG=DEBUG*) reg pps = 0;
reg pps_d = 0;
always @(posedge clk) begin
    pps_m <= pps_a;
    pps   <= pps_m;
    pps_d <= pps;

    if (pps) begin
        debounceCounter <= DEBOUNCE_RELOAD;
    end
    else if (!debounceDone) begin
        debounceCounter <= debounceCounter - 1;
    end

    if (pps && !pps_d && debounceDone) begin
        if (!tooFast && !tooSlow) begin
            ppsStrobe <= 1;
            ppsIsValid <= 1;
        end
        else begin
            ppsIsValid <= 0;
        end
        tooSlowCounter <= PPS_TOOSLOW_RELOAD;
        tooFastCounter <= PPS_TOOFAST_RELOAD;
    end
    else begin
        ppsStrobe <= 0;
        if (tooFast) begin
            tooFastCounter <= tooFastCounter - 1;
        end
        if (tooSlow) begin
            ppsIsValid <= 0;
        end
        else begin
            tooSlowCounter <= tooSlowCounter - 1;
        end
    end
end
endmodule

/*
 * Turn a stable PPS strobe into a jittery PPS strobe
 */
module jitterbug (
    input  wire clk,
    input  wire ppsStrobe,
    output reg  ppsJitteryStrobe = 0);

// Delay generator
localparam DELAY_WIDTH = 11;
localparam DELAY_COUNTER_WIDTH = DELAY_WIDTH + 1;
reg [DELAY_COUNTER_WIDTH-1:0] delayCounter;
wire delayCounterDone = delayCounter[DELAY_COUNTER_WIDTH-1];
reg delayCounterDone_d = 0;

// PRBS15
reg [14:0] prbs = 1;

always @(posedge clk) begin
    prbs <= { prbs[13:0], prbs[14] ^ prbs[13] };
    delayCounterDone_d <= delayCounterDone;
    ppsJitteryStrobe <= delayCounterDone && !delayCounterDone_d;

    if (ppsStrobe) begin
        delayCounter <= {1'b0, prbs[DELAY_COUNTER_WIDTH-2:0]};
    end
    else if (!delayCounterDone) begin
        delayCounter <= delayCounter - 1;
    end
end
endmodule

`default_nettype wire
