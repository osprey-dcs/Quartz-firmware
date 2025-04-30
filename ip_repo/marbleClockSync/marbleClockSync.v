/*
 * MIT License
 *
 * Copyright (c) 2025 Osprey DCS
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
 * The CLK_RATE and DAC_COUNTS_PER_HZ parameters are exposed
 * primarily for changing their values for simulation.
 *
 * The Marble VCXO sensitivity varies between boards.  The value here is
 * somewhere in the middle of the range.  Small errors are unimportant.
 */
`default_nettype none
module marbleClockSync #(
    parameter      CLK_RATE          = 125000000,
    parameter real DAC_COUNTS_PER_HZ = 28.0,
    parameter      DEBUG             = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output wire [31:0] sysAuxStatus,
    output wire [31:0] sysHwInterval,
    input  wire        clk125,
    input  wire        clk500,
    input  wire        ppsPrimary_pin,
    input  wire        ppsSecondary_pin,
    input  wire        ppsFromFabric,
    output wire        hwPPSmarker_a,
    (*MARK_DEBUG=DEBUG*) output reg  hwPPSvalid = 0,
    (*MARK_DEBUG=DEBUG*) output wire ppsMarker,
    (*MARK_DEBUG=DEBUG*) output reg  ppsToggle = 0,
    (*MARK_DEBUG=DEBUG*) output reg  SPI_CLK = 1,
    (*MARK_DEBUG=DEBUG*) output reg  SPI_SYNCn = 1,
    (*MARK_DEBUG=DEBUG*) output wire SPI_SDI);


localparam DAC_WIDTH = 16;
localparam UNLOCK_COUNT = 20; // Unlocked until good for this many samples
localparam SCALE_SHIFT = 9; // Integer arithmetic scaling
localparam FINE_ERROR_WIDTH = 3;
localparam LOW_JITTER_THRESHOLD_NS = 32;
localparam JITTER_HYSTERESIS_NS = 5;

//////////////////////////////////////////////////////////////////////////////
// System clock domain

reg sysPLLenable = 1;
reg [DAC_WIDTH-1:0] sysDACvalue;
reg sysDACtoggle = 0;
reg sysIsOffsetBinary = 0;

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
            sysIsOffsetBinary <= 0;
        end
        else if (sysGPIO_OUT[28]) begin
            sysIsOffsetBinary <= 1;
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// Select PPS reference

wire ppsPrimary_a, ppsSecondary_a, ppsTertiary_a;
wire ppsPrimaryStrobe, ppsPrimaryIsValid;
wire ppsSecondaryStrobe, ppsSecondaryIsValid;
wire ppsTertiaryStrobe, ppsTertiaryIsValid;

assign hwPPSmarker_a = ppsPrimaryIsValid ? ppsPrimary_a :
                      (ppsSecondaryIsValid ? ppsSecondary_a :
                      (ppsTertiaryIsValid ? ppsTertiary_a : 0));

wire signed[FINE_ERROR_WIDTH-1:0] phaseErrorFinePrimary,
                                  phaseErrorFineSecondary,
                                  phaseErrorFineTertiary;
(*MARK_DEBUG=DEBUG*) wire signed [FINE_ERROR_WIDTH-1:0] phaseErrorFine =
                                                        ppsPrimaryIsValid ?
                                                        phaseErrorFinePrimary :
                                                        (ppsSecondaryIsValid ?
                                                        phaseErrorFineSecondary:
                                                        phaseErrorFineTertiary);

//
// An IDELAY is required to drive the ISERDES from fabric.
//
wire ppsFromFabricIDELAY;
IDELAYE2 #(
    .CINVCTRL_SEL("FALSE"),   // Enable dynamic clock inversion (FALSE, TRUE)
    .DELAY_SRC("DATAIN"),     // Delay input (IDATAIN, DATAIN)
    .HIGH_PERFORMANCE_MODE("FALSE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
    .IDELAY_TYPE("FIXED"),    // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
    .IDELAY_VALUE(0),         // Input delay tap setting (0-31)
    .PIPE_SEL("FALSE"),       // Select pipelined mode, FALSE, TRUE
    .REFCLK_FREQUENCY(200.0), // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
    .SIGNAL_PATTERN("DATA")   // DATA, CLOCK input signal
    )
  clockSyncFabricIDELAY (
    .CNTVALUEOUT(),          // 5-bit output: Counter value output
    .DATAOUT(ppsFromFabricIDELAY), // 1-bit output: Delayed data output
    .C(1'b0),                // 1-bit input: Clock input
    .CE(1'b0),               // 1-bit input: Active high enable increment/decrement input
    .CINVCTRL(1'b0),         // 1-bit input: Dynamic clock inversion input
    .CNTVALUEIN(5'd0),       // 5-bit input: Counter value input
    .DATAIN(ppsFromFabric),  // 1-bit input: Internal delay data input
    .IDATAIN(1'b0),          // 1-bit input: Data input from the I/O
    .INC(1'b0),              // 1-bit input: Increment / Decrement tap delay input
    .LD(1'b0),               // 1-bit input: Load IDELAY_VALUE input
    .LDPIPEEN(1'b0),         // 1-bit input: Enable PIPELINE register to load data input
    .REGRST(1'b0)            // 1-bit input: Active-high reset tap-delay input
   );

//
// Instantiate the blocks to sample the incoming PPS markers.
//
marbleClockSyncIsPPSvalid #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(2000),
    .IOBDELAY("NONE"),
    .DEBUG(DEBUG))
  marbleClockSyncIsPPSvalidPrimary (
    .clk125(clk125),
    .clk500(clk500),
    .pps_ibuf(ppsPrimary_pin),
    .pps_idelay(1'b0),
    .pps_a(ppsPrimary_a),
    .ppsStrobe(ppsPrimaryStrobe),
    .ppsIsValid(ppsPrimaryIsValid),
    .phaseErrorFine(phaseErrorFinePrimary));

marbleClockSyncIsPPSvalid #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(2000),
    .IOBDELAY("NONE"),
    .DEBUG(DEBUG))
  marbleClockSyncIsPPSvalidSecondary (
    .clk125(clk125),
    .clk500(clk500),
    .pps_ibuf(ppsSecondary_pin),
    .pps_a(ppsSecondary_a),
    .pps_idelay(1'b0),
    .ppsStrobe(ppsSecondaryStrobe),
    .ppsIsValid(ppsSecondaryIsValid),
    .phaseErrorFine(phaseErrorFineSecondary));

marbleClockSyncIsPPSvalid #(
    .CLK_RATE(CLK_RATE),
    .DEBOUNCE_NS(2000),
    .IOBDELAY("BOTH"),
    .DEBUG(DEBUG))
  marbleClockSyncIsPPSvalidTertiary (
    .clk125(clk125),
    .clk500(clk500),
    .pps_ibuf(1'b0),
    .pps_idelay(ppsFromFabricIDELAY),
    .pps_a(ppsTertiary_a),
    .ppsStrobe(ppsTertiaryStrobe),
    .ppsIsValid(ppsTertiaryIsValid),
    .phaseErrorFine(phaseErrorFineTertiary));

(*MARK_DEBUG=DEBUG*) wire hwPPSstrobe = ppsPrimaryIsValid   ? ppsPrimaryStrobe :
                                        ppsSecondaryIsValid ? ppsSecondaryStrobe
                                                            : ppsTertiaryStrobe;
reg hwPPStoggle = 0;
always @(posedge clk125) begin
    hwPPSvalid <= ppsPrimaryIsValid||ppsSecondaryIsValid||ppsTertiaryIsValid;
    if (hwPPSstrobe) begin
        hwPPStoggle <= !hwPPStoggle;
    end
end

//////////////////////////////////////////////////////////////////////////////
// PPS generation
localparam CLK_COUNTER_LOAD = CLK_RATE - 2;
localparam CLK_COUNTER_WIDTH = $clog2(CLK_COUNTER_LOAD+1)+1;
reg [CLK_COUNTER_WIDTH-1:0] clkCounter = CLK_COUNTER_LOAD;
reg clkCounterEnable = 0;
(*MARK_DEBUG=DEBUG*) wire swPPSstrobe = clkCounter[CLK_COUNTER_WIDTH-1];
reg [CLK_COUNTER_WIDTH-1:0] hwIntervalCounter = 0, hwInterval = 0;

localparam PPS_STRETCH_LOAD = CLK_RATE / 100000;
localparam PPS_STRETCH_WIDTH = $clog2(PPS_STRETCH_LOAD+1)+1;
reg signed [PPS_STRETCH_WIDTH-1:0] ppsStretch = 0;
assign ppsMarker = ppsStretch[PPS_STRETCH_WIDTH-1];

//////////////////////////////////////////////////////////////////////////////
// Phase locked loop

// Allow DAC_COUNTS_PER_HZ to have a fractional component.
localparam DAC_SCALE_SHIFT = 4;
localparam DAC_PER_HZ_SCALED = $rtoi(DAC_COUNTS_PER_HZ * (1<<DAC_SCALE_SHIFT));

// Disallow phase errors greater than the theoretical VCXO range
localparam LOCK_RANGE = $rtoi(((1 << (DAC_WIDTH - 1)) - 1) / DAC_COUNTS_PER_HZ);

// Add one bit to ensure that (phaseError - phaseErrorOld) can't overflow.
localparam COARSE_ERROR_WIDTH = $clog2($rtoi((1<<DAC_WIDTH) /
                                                        DAC_COUNTS_PER_HZ)) + 1;
(*MARK_DEBUG=DEBUG*) reg signed [COARSE_ERROR_WIDTH-1:0] phaseErrorCoarse;

localparam PHASE_ERROR_WIDTH = COARSE_ERROR_WIDTH + FINE_ERROR_WIDTH;
wire signed [PHASE_ERROR_WIDTH-1:0] phaseErrorCoarseScaled =
                                 { phaseErrorCoarse, {FINE_ERROR_WIDTH{1'b0}} };
(*MARK_DEBUG=DEBUG*) reg signed [PHASE_ERROR_WIDTH-1:0]phaseError,phaseErrorOld;
wire signed [PHASE_ERROR_WIDTH-1:0] phaseErrorDiff = phaseError - phaseErrorOld;
reg signed [23:0] phaseError24;
reg [PHASE_ERROR_WIDTH-1:0] jitterAbs;

// Estimate jitter by low-pass filtering absolute value of phase error
localparam JITTER_FILTER_SHIFT = 5;
reg [PHASE_ERROR_WIDTH+JITTER_FILTER_SHIFT-1:0] jitterAccumulator;
(*MARK_DEBUG=DEBUG*) wire [PHASE_ERROR_WIDTH-1:0] jitter =
                      jitterAccumulator[JITTER_FILTER_SHIFT+:PHASE_ERROR_WIDTH];
// Average jitter to 1/4 ns resolution
wire [15:0] jitterMonitor = jitterAccumulator[JITTER_FILTER_SHIFT-2+:16];

localparam UNLOCK_COUNTER_RELOAD = UNLOCK_COUNT - 1;
localparam UNLOCK_COUNTER_WIDTH = $clog2(UNLOCK_COUNTER_RELOAD+1)+1;
reg [UNLOCK_COUNTER_WIDTH-1:0] unlockCounter = UNLOCK_COUNTER_RELOAD;
(*MARK_DEBUG=DEBUG*) wire pllLocked = unlockCounter[UNLOCK_COUNTER_WIDTH-1];

(*ASYNC_REG="true"*) reg enable_m = 0;
(*MARK_DEBUG=DEBUG*) reg enable = 0, enabled = 0;
(*ASYNC_REG="true"*) reg dacManualToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg dacManualToggle = 0, dacManualToggleCheck = 0;

// Control action
// Add one bit to handle the case where the proportional and integral terms
// have different signs, so the sum might not need the extra bit, the
// individual terms might.
localparam CTRL_WIDTH = PHASE_ERROR_WIDTH + SCALE_SHIFT + 1;
(*MARK_DEBUG=DEBUG*) reg signed [CTRL_WIDTH-1:0] ctrlDelta;

// Saturate (avoid integrator windup)
// Limit DAC output to linear part of VCXO range
localparam DAC_LIMIT = (((1 << (DAC_WIDTH - 1)) - 1) * 7) / 8;
localparam CTRL_LIMIT = $rtoi((DAC_LIMIT << (SCALE_SHIFT + FINE_ERROR_WIDTH)) /
                                                             DAC_COUNTS_PER_HZ);
localparam CTRL_LIMIT_WIDTH = $clog2(CTRL_LIMIT+1) + 1;
wire signed [CTRL_WIDTH-1:0] ctrlAccumulateLimit = CTRL_LIMIT;
(*MARK_DEBUG=DEBUG*) reg signed [CTRL_WIDTH-1:0] ctrlAccumulate = 0;
(*MARK_DEBUG=DEBUG*) wire signed [CTRL_WIDTH-1:0] ctrlAccumulateNext =
                                                     ctrlAccumulate + ctrlDelta;

// VCXO scaling
// Extra bit accounts for signed DSP multiplier.
localparam DAC_CALIB_WIDTH = $clog2(DAC_PER_HZ_SCALED+1) + 1;
wire signed [DAC_CALIB_WIDTH-1:0] dacCalibFactor = DAC_PER_HZ_SCALED;
localparam PRODUCT_WIDTH = CTRL_LIMIT_WIDTH + DAC_CALIB_WIDTH;
(*MARK_DEBUG=DEBUG*) reg signed [PRODUCT_WIDTH-1:0] product;
(*MARK_DEBUG=DEBUG*) reg signed [DAC_WIDTH-1:0] dacValue = 0;

// DAC data transfer
// Assume sysIsOffsetBinary changes only when DAC updates are disabled
wire [DAC_WIDTH-1:0] sendValue = dacValue ^
                                        {sysIsOffsetBinary,{DAC_WIDTH-1{1'b0}}};
(*MARK_DEBUG=DEBUG*) reg dacUpdateToggle = 0;
(*MARK_DEBUG=DEBUG*) reg dacBusy = 0;

// State machine
localparam [3:0] PLL_ST_INIT                    = 4'd0,
                 PLL_ST_OPEN_LOOP               = 4'd1,
                 PLL_ST_AWAIT_EITHER_PPS        = 4'd2,
                 PLL_ST_AWAIT_SW_PPS            = 4'd3,
                 PLL_ST_AWAIT_HW_PPS            = 4'd4,
                 PLL_ST_COMPUTE_PHASE_ERROR     = 4'd5,
                 PLL_ST_COMPUTE_CONTROL_DELTA   = 4'd6,
                 PLL_ST_ACCUMULATE_AND_SATURATE = 4'd7,
                 PLL_ST_COMPUTE_DAC_VALUE       = 4'd8,
                 PLL_ST_UPDATE_DAC              = 4'd9;
(*MARK_DEBUG=DEBUG*) reg [3:0] pllState = PLL_ST_INIT;
(*MARK_DEBUG=DEBUG*) reg jitterIsHigh = 0;

// Startup delay -- provide time for PPS checks to get working
localparam START_DELAY_LOAD = (2 * CLK_RATE) + (CLK_RATE / 4);
localparam START_DELAY_WIDTH = $clog2(START_DELAY_LOAD+1) + 1;
reg [START_DELAY_WIDTH-1:0] startDelay = START_DELAY_LOAD;
wire startDelayDone = startDelay[START_DELAY_WIDTH-1];

always @(posedge clk125) begin
    /*
     * Housekeeping
     */
    enable_m <= sysPLLenable;
    enable   <= enable_m;
    dacManualToggle_m <= sysDACtoggle;
    dacManualToggle   <= dacManualToggle_m;
    if (!startDelayDone) begin
        startDelay <= startDelay - 1;
    end

    /*
     * Measure interval between HW PPS strobes
     */
    if (hwPPSstrobe) begin
        hwInterval <= hwIntervalCounter;
        hwIntervalCounter <= 1;
    end
    else begin
        hwIntervalCounter <= hwIntervalCounter + 1;
    end

    /*
     * Generate PPS
     */
    if (!clkCounterEnable || swPPSstrobe) begin
        clkCounter <= CLK_COUNTER_LOAD;
    end
    else begin
        clkCounter <= clkCounter - 1;
    end
    if (pllLocked ? swPPSstrobe : (hwPPSvalid && hwPPSstrobe)) begin
        ppsStretch <= -PPS_STRETCH_LOAD;
        ppsToggle <= !ppsToggle;
    end
    else begin
        if (ppsMarker) begin
            ppsStretch <= ppsStretch + 1;
        end
    end

    /*
     * State machine
     */
    case (pllState)
    PLL_ST_INIT: begin
        if (startDelayDone) begin
            /*
             * If the FPGA is restarting (as opposed to the board powering-up)
             * the DAC will still be set to an old value.
             * Ensure that the DAC is in a known state by writing to it now.
             */
            dacValue <= 0;
            dacUpdateToggle <= !dacUpdateToggle;
            pllState <= PLL_ST_OPEN_LOOP;
        end
    end
    PLL_ST_OPEN_LOOP: begin
        enabled <= 0;
        clkCounterEnable <= 0;
        phaseErrorCoarse <= 0;
        phaseErrorOld <= 0;
        jitterAccumulator <= 0;
        ctrlAccumulate <= 0;
        unlockCounter <= UNLOCK_COUNTER_RELOAD;
        if (enable && hwPPSvalid && hwPPSstrobe) begin
            pllState <= PLL_ST_AWAIT_HW_PPS;
        end
        else if (dacManualToggle != dacManualToggleCheck) begin
            dacManualToggleCheck <= dacManualToggle;
            dacValue <= sysDACvalue;
            dacUpdateToggle <= !dacUpdateToggle;
        end
    end
    PLL_ST_AWAIT_EITHER_PPS: begin
        phaseErrorCoarse <= 0;
        if (!hwPPSvalid) begin
            pllState <= PLL_ST_OPEN_LOOP;
        end
        else begin
            if (hwPPSstrobe && swPPSstrobe) begin
                pllState <= PLL_ST_COMPUTE_PHASE_ERROR;
            end
            else if (swPPSstrobe) begin
                pllState <= PLL_ST_AWAIT_HW_PPS;
            end
            else if (hwPPSstrobe) begin
                pllState <= PLL_ST_AWAIT_SW_PPS;
            end
        end
    end
    PLL_ST_AWAIT_HW_PPS: begin
        // Local clock is too fast, phase error is negative
        phaseErrorCoarse <= phaseErrorCoarse - 1;
        if (!hwPPSvalid || (enabled && (phaseErrorCoarse < -LOCK_RANGE))) begin
            pllState <= PLL_ST_OPEN_LOOP;
        end
        else if (hwPPSstrobe) begin
            if (enabled) begin
                pllState <= PLL_ST_COMPUTE_PHASE_ERROR;
            end
            else begin
                /*
                 * First update after closing loop does a fast VCXO
                 * slew to get frequency close to steady-state value
                 * and phase close to zero on next update.
                 */
                phaseError <= (CLK_RATE - hwIntervalCounter)
                                                        << FINE_ERROR_WIDTH;
                ctrlDelta <= (CLK_RATE - hwIntervalCounter) <<
                                             (SCALE_SHIFT+FINE_ERROR_WIDTH);
                clkCounterEnable <= 1;
                pllState <= PLL_ST_ACCUMULATE_AND_SATURATE;
            end
        end
    end
    PLL_ST_AWAIT_SW_PPS: begin
        // Local clock is too slow, phase error is positive
        phaseErrorCoarse <= phaseErrorCoarse + 1;
        if (!hwPPSvalid || (phaseErrorCoarse > LOCK_RANGE)) begin
            pllState <= PLL_ST_OPEN_LOOP;
        end
        else if (swPPSstrobe) begin
            pllState <= PLL_ST_COMPUTE_PHASE_ERROR;
        end
    end
    PLL_ST_COMPUTE_PHASE_ERROR: begin
        phaseError <= phaseErrorCoarseScaled + phaseErrorFine;
        pllState <= PLL_ST_COMPUTE_CONTROL_DELTA;
    end
    PLL_ST_COMPUTE_CONTROL_DELTA: begin
        /*
         * Update 'locked' state
         */
        if (!pllLocked) begin
            unlockCounter <= unlockCounter - 1;
        end

        /*
         * Velocity form of proportional plus integral controller.
         *
         * Slow PLL: Kp = 1/16      Ki = 1/512
         * Fast PLL: Kp = 1/4       Ki = 1/16
         *
         * Use slow PLL when locked to high-jitter PPS marker.
         */
        ctrlDelta <= pllLocked && jitterIsHigh ?
                      ((phaseErrorDiff << (SCALE_SHIFT - 4)) +
                       (phaseError << (SCALE_SHIFT - 9)))
                                               :
                      ((phaseErrorDiff << (SCALE_SHIFT - 2)) +
                       (phaseError << (SCALE_SHIFT - 4)));
        phaseErrorOld <= phaseError;
        jitterAbs <= (phaseErrorDiff<0) ? -phaseErrorDiff : phaseErrorDiff;
        pllState <= PLL_ST_ACCUMULATE_AND_SATURATE;
    end
    PLL_ST_ACCUMULATE_AND_SATURATE: begin
        /*
         * No worry about overflow in the limit checks
         * since there's extra bit in CTRL_WIDTH.
         */
        if (ctrlAccumulateNext > ctrlAccumulateLimit) begin
            ctrlAccumulate <= ctrlAccumulateLimit;
        end
        else if (ctrlAccumulateNext < -ctrlAccumulateLimit) begin
            ctrlAccumulate <= -ctrlAccumulateLimit;
        end
        else begin
            ctrlAccumulate <= ctrlAccumulateNext;
        end
        if (enabled) begin
            jitterAccumulator <= jitterAccumulator + jitterAbs -
                                 (jitterAccumulator >> JITTER_FILTER_SHIFT);
        end
        pllState <= PLL_ST_COMPUTE_DAC_VALUE;
    end
    PLL_ST_COMPUTE_DAC_VALUE: begin
        /*
         * Forward phase error value to processor
         */
        phaseError24 <= phaseError;

        /*
         * Convert control action (Hz) to DAC counts.
         *   ctrlAccumulate is scaled by (1<<(SCALE_SHIFT+FINE_ERROR_WIDTH)
         *   dacCalibFactor is scaled by (1<<DAC_SCALE_SHIFT)
         * Use only as many bits of ctrlAccumulate as needed to fit the
         * satured limit.  This ensures that we can fit a single DSP48.
         */
        product <= ctrlAccumulate[CTRL_LIMIT_WIDTH-1:0] * dacCalibFactor;

        /*
         * Check jitter
         */
        if (jitter > (LOW_JITTER_THRESHOLD_NS + JITTER_HYSTERESIS_NS)) begin
            jitterIsHigh <= 1;
        end
        else if (jitter < LOW_JITTER_THRESHOLD_NS) begin
            jitterIsHigh <= 0;
        end
        pllState <= PLL_ST_UPDATE_DAC;
    end
    PLL_ST_UPDATE_DAC: begin
        /*
         * Remove scale factors
         */
        dacValue <= product[(SCALE_SHIFT+FINE_ERROR_WIDTH+DAC_SCALE_SHIFT)
                                                               +:DAC_WIDTH];
        /*
         * Check for 'enable' only in this state to prevent extra or
         * missing ppsMarkers when disabling (we have just seen both
         * hardware and software strobes at this point so we know that
         * it's about a second until the next hardware marker).
         */
        if (enable) begin
            dacUpdateToggle <= !dacUpdateToggle;
            enabled <= 1;
            pllState <= PLL_ST_AWAIT_EITHER_PPS;
        end
        else begin
            pllState <= PLL_ST_OPEN_LOOP;
        end
    end
    default: pllState <= PLL_ST_OPEN_LOOP;
    endcase
end

assign sysStatus = {pllLocked, dacUpdateToggle, enable, jitterIsHigh,
                    hwPPSvalid, hwPPStoggle, sysIsOffsetBinary, dacBusy,
                    phaseError24};
assign sysAuxStatus = { jitterMonitor, dacValue };
assign sysHwInterval = { hwPPSvalid,
                         ppsTertiaryIsValid,
                         ppsSecondaryIsValid,
                         ppsPrimaryIsValid,
                         hwPPStoggle,
                         {32-5-(CLK_COUNTER_WIDTH-1){1'b0}},
                         hwInterval[0+:CLK_COUNTER_WIDTH-1] };

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
localparam Tdelay = ns2ticks(50/2); // 20 MHz SPI clock
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
reg dacUpdateToggle_d = 0;

always @(posedge clk125) begin
    if ((spiState == SPI_ST_IDLE) || spiDelayCounterDone) begin
        spiDelayCounter <= SPI_DELAY_RELOAD;
    end
    else begin
        spiDelayCounter <= spiDelayCounter - 1;
    end
    dacUpdateToggle_d <= dacUpdateToggle;
    case (spiState)
    SPI_ST_IDLE: begin
        spiBitCounter <= SPI_BITCOUNTER_RELOAD;
        if (dacUpdateToggle != dacUpdateToggle_d) begin
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
 * Confirm validity of PPS signal and measure arrival point relative to clk125.
 * Desired arrival point of hardware PPS marker rising edge is in the middle
 * of a clk125 cycle (rxVal == 8'b0001111).
 * Values with fewer leading zeros indicate that the hardware PPS marker is
 * arriving early relative to the softare PPS marker -- the VCXO is too slow
 * so the phase error is positive and the VCXO speed will be increased.
 */
module marbleClockSyncIsPPSvalid #(
    parameter CLK_RATE    = -1,
    parameter DEBOUNCE_NS = -1,
    parameter IOBDELAY    = "NONE",
    parameter DEBUG       = "false"
    ) (
                         input  wire clk125,
                         input  wire clk500,
                         input  wire pps_ibuf,
                         input  wire pps_idelay,
                         output wire pps_a,
    (*MARK_DEBUG=DEBUG*) output reg  ppsStrobe = 0,
    (*MARK_DEBUG=DEBUG*) output reg  ppsIsValid = 0,
    (*MARK_DEBUG=DEBUG*) output reg  signed [2:0] phaseErrorFine);

localparam DEBOUNCE_TICKS = (DEBOUNCE_NS * (CLK_RATE/1000) + 999999) / 1000000;
localparam DEBOUNCE_RELOAD = DEBOUNCE_TICKS - 2;
localparam DEBOUNCE_COUNTER_WIDTH = $clog2(DEBOUNCE_RELOAD+1) + 1;
reg [DEBOUNCE_COUNTER_WIDTH-1:0] debounceCounter = DEBOUNCE_RELOAD;
(*MARK_DEBUG=DEBUG*)wire debounceDone=debounceCounter[DEBOUNCE_COUNTER_WIDTH-1];

localparam PPS_TOOSLOW_RELOAD = (CLK_RATE / 100) * 101;
localparam PPS_TOOFAST_RELOAD = (CLK_RATE / 100) * 99;
localparam PPS_RELOAD         = CLK_RATE - 2;
localparam PPS_COUNTER_WIDTH = $clog2(PPS_TOOSLOW_RELOAD+1) + 1;

reg [PPS_COUNTER_WIDTH-1:0] tooSlowCounter = PPS_TOOSLOW_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooSlow = tooSlowCounter[PPS_COUNTER_WIDTH-1];
reg [PPS_COUNTER_WIDTH-1:0] tooFastCounter = PPS_TOOFAST_RELOAD;
(*MARK_DEBUG=DEBUG*) wire tooFast = !tooFastCounter[PPS_COUNTER_WIDTH-1];

(*MARK_DEBUG=DEBUG*) wire [7:0] rxVal;
wire pps = (rxVal != 0);
reg pps_d = 0;

always @(posedge clk125) begin
    pps_d <= pps;
    if (pps) begin
        debounceCounter <= DEBOUNCE_RELOAD;
    end
    else if (!debounceDone) begin
        debounceCounter <= debounceCounter - 1;
    end
    if (pps && !pps_d && debounceDone) begin
        if (!tooFast && !tooSlow) begin
            ppsIsValid <= 1;
            ppsStrobe <= 1;
            casex (rxVal)
            8'b1xxxxxxx: phaseErrorFine <=  3;
            8'b01xxxxxx: phaseErrorFine <=  2;
            8'b001xxxxx: phaseErrorFine <=  1;
            8'b0001xxxx: phaseErrorFine <=  0;
            8'b00001xxx: phaseErrorFine <= -1;
            8'b000001xx: phaseErrorFine <= -2;
            8'b0000001x: phaseErrorFine <= -3;
            8'b00000001: phaseErrorFine <= -4;
            endcase
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

/*
 * Fine measurement of input signal rise time
 *
 * From Xilinx HDL Language Template, version 2023.1
 */
ISERDESE2 #(
    .DATA_RATE("DDR"),           // DDR, SDR
    .DATA_WIDTH(8),              // Parallel data width (2-8,10,14)
    .DYN_CLKDIV_INV_EN("FALSE"), // Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
    .DYN_CLK_INV_EN("FALSE"),    // Enable DYNCLKINVSEL inversion (FALSE, TRUE)
    // INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
    .INTERFACE_TYPE("NETWORKING"),// MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
    .IOBDELAY(IOBDELAY),         // NONE, BOTH, IBUF, IFD
    .NUM_CE(2),                  // Number of clock enables (1,2)
    .OFB_USED("FALSE"),          // Select OFB path (FALSE, TRUE)
    .SERDES_MODE("MASTER"))      // MASTER, SLAVE
  ISERDESE2_inst (
    .O(pps_a),             // 1-bit output: Combinatorial output
    // Q1 - Q8: 1-bit (each) output: Registered data outputs
    .Q1(rxVal[0]),
    .Q2(rxVal[1]),
    .Q3(rxVal[2]),
    .Q4(rxVal[3]),
    .Q5(rxVal[4]),
    .Q6(rxVal[5]),
    .Q7(rxVal[6]),
    .Q8(rxVal[7]),
    // SHIFTOUT1, SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
    .SHIFTOUT1(),
    .SHIFTOUT2(),
    .BITSLIP(1'b0),        // 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
    // CLKDIV when asserted (active High). Subsequently, the data seen on the Q1
    // to Q8 output ports will shift, as in a barrel-shifter operation, one
    // position every time Bitslip is invoked (DDR operation is different from
    // SDR).

    // CE1, CE2: 1-bit (each) input: Data register clock enable inputs
    .CE1(1'b1),
    .CE2(1'b1),
    .CLKDIVP(1'b0),        // 1-bit input: TBD
    // Clocks: 1-bit (each) input: ISERDESE2 clock input ports
    .CLK(clk500),          // 1-bit input: High-speed clock
    .CLKB(!clk500),        // 1-bit input: High-speed secondary clock
    .CLKDIV(clk125),       // 1-bit input: Divided clock
    .OCLK(1'b0),           // 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY"
    // Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
    .DYNCLKDIVSEL(1'b0),   // 1-bit input: Dynamic CLKDIV inversion
    .DYNCLKSEL(1'b0),      // 1-bit input: Dynamic CLK/CLKB inversion
    // Input Data: 1-bit (each) input: ISERDESE2 data input ports
    .D(pps_ibuf),          // 1-bit input: Data input
    .DDLY(pps_idelay),     // 1-bit input: Serial data from IDELAYE2
    .OFB(1'b0),            // 1-bit input: Data feedback from OSERDESE2
    .OCLKB(1'b0),          // 1-bit input: High speed negative edge output clock
    .RST(1'b0),            // 1-bit input: Active high asynchronous reset
    // SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
    .SHIFTIN1(1'b0),
    .SHIFTIN2(1'b0));
endmodule

`default_nettype wire
