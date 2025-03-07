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
 * Local Machine Protection System operations
 */
`default_nettype none
module mpsLocal #(
    parameter MPS_OUTPUT_COUNT = -1,
    parameter MPS_INPUT_COUNT  = -1,
    parameter ADC_COUNT        = -1,
    parameter TIMESTAMP_WIDTH  = -1,
    parameter DEBUG            = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire        sysDataStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,
    output reg  [31:0] sysData,
  
    input  wire evrClk,
    input  wire evrClearMPSstrobe,

    input  wire                       acqClk,
    input  wire   [(4*ADC_COUNT)-1:0] acqLimitExcursions,
    input  wire                       acqLimitExcursionsTVALID,
    input  wire [TIMESTAMP_WIDTH-1:0] acqTimestamp,
    input  wire [MPS_INPUT_COUNT-1:0] mpsInputStates_a,

    input  wire                       mgtTxClk,
    output reg                 [15:0] mpsTxChars = 0,
    output reg                        mpsTxCharIsK = 0);

localparam MPS_SEL_WIDTH = $clog2(MPS_OUTPUT_COUNT);
localparam REG_SEL_WIDTH = 4;

reg [MPS_SEL_WIDTH-1:0] sysMPSsel = 0;
reg [REG_SEL_WIDTH-1:0] sysREGsel = 0;

wire [(MPS_OUTPUT_COUNT*32)-1:0] acqPerChannelData;
wire      [MPS_OUTPUT_COUNT-1:0] acqPerChannelTripped;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysMPSsel <= sysGPIO_OUT[0+:MPS_SEL_WIDTH];
        sysREGsel <= sysGPIO_OUT[8+:REG_SEL_WIDTH];
    end
    sysData <= acqPerChannelData[sysMPSsel*32+:32];
end
assign sysStatus = { {24-REG_SEL_WIDTH{1'b0}}, sysREGsel,
                      {8-REG_SEL_WIDTH{1'b0}}, sysMPSsel };

///////////////////////////////////////////////////////////////////////////////
// Event receiver clock domain
// Stretch event strobe to ensure it's seen in the acquisition clock domain.
reg [4:0] evrEventStretch = 0;
wire evrClear = evrEventStretch[4];
always @(posedge evrClk) begin
    if (evrClearMPSstrobe) begin
        evrEventStretch <= ~0;
    end
    else if (evrClear) begin
        evrEventStretch <= evrEventStretch - 1;
    end
end

///////////////////////////////////////////////////////////////////////////////
// Acquisition clock domain
(*ASYN_REG="*true"*) reg acqClear_m = 0;
reg acqClear_d0 = 0, acqClear_d1 = 0, acqClearTrip = 0;

reg [(4*ADC_COUNT)-1:0] acqLimitExcursionsLatched = 0;

always @(posedge acqClk) begin
    if (acqLimitExcursionsTVALID) begin
        acqLimitExcursionsLatched <= acqLimitExcursions;
    end

    acqClear_m  <= evrClear;
    acqClear_d0 <= acqClear_m;
    acqClear_d1 <= acqClear_d0;
    acqClearTrip <= (acqClear_d0 != acqClear_d1);
end

// Instantiate each of the MPS output handlers
genvar i;
generate
for (i = 0 ; i < MPS_OUTPUT_COUNT ; i = i + 1) begin : mpsChan
    mpsLocalChannel #(
        .MPS_INPUT_COUNT(MPS_INPUT_COUNT),
        .ADC_COUNT(ADC_COUNT),
        .REG_SEL_WIDTH(REG_SEL_WIDTH),
        .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH),
        .DEBUG(DEBUG))
      mpsLocalChannel_i (
        .sysClk(sysClk),
        .sysREGsel(sysREGsel),
        .sysDataStrobe(sysDataStrobe && (sysMPSsel == i)),
        .sysGPIO_OUT(sysGPIO_OUT),
        .sysData(acqPerChannelData[i*32+:32]),
        .acqClk(acqClk),
        .acqTimestamp(acqTimestamp),
        .mpsInputs_a(mpsInputStates_a),
        .acqLimitExcursions(acqLimitExcursionsLatched),
        .acqTripped(acqPerChannelTripped[i]),
        .acqClearTrip(acqClearTrip));
end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// MGT transmit clock domain
reg [2:0] mpsTxPhase = 0;
(*ASYNC_REG="true"*)  reg [MPS_OUTPUT_COUNT-1:0] mpsTripped_m;
reg [MPS_OUTPUT_COUNT-1:0] mpsTripped;
always @(posedge mgtTxClk) begin
    mpsTripped_m <= acqPerChannelTripped;
    mpsTripped   <= mpsTripped_m;
    mpsTxChars[8+:MPS_OUTPUT_COUNT] <= mpsTripped;
    if (mpsTxPhase[2]) begin
        mpsTxPhase <= 1;
        mpsTxChars[0+:8] <= 8'hBC;
        mpsTxCharIsK <= 1;
    end
    else begin
        mpsTxPhase <= mpsTxPhase + 1;
        mpsTxChars[0+:8] <= 8'h00;
        mpsTxCharIsK <= 0;
    end
end

endmodule

module mpsLocalChannel #(
    parameter MPS_INPUT_COUNT    = -1,
    parameter ADC_COUNT          = -1,
    parameter REG_SEL_WIDTH      = -1,
    parameter TIMESTAMP_WIDTH    = -1,
    parameter DEBUG              = "false"
    ) (
    input  wire                     sysClk,
    input  wire [REG_SEL_WIDTH-1:0] sysREGsel,
    input  wire                     sysDataStrobe,
    input  wire              [31:0] sysGPIO_OUT,
    output reg               [31:0] sysData,

    input  wire                        acqClk,
    input  wire  [TIMESTAMP_WIDTH-1:0] acqTimestamp,
    input  wire  [MPS_INPUT_COUNT-1:0] mpsInputs_a,
    input  wire    [(4*ADC_COUNT)-1:0] acqLimitExcursions,
    output reg                         acqTripped = 0,
    input  wire                        acqClearTrip);

reg [ADC_COUNT-1:0] importantHIHI = 0, firstFaultHIHI = 0;
reg [ADC_COUNT-1:0] importantHI   = 0, firstFaultHI   = 0;
reg [ADC_COUNT-1:0] importantLO   = 0, firstFaultLO   = 0;
reg [ADC_COUNT-1:0] importantLOLO = 0, firstFaultLOLO = 0;
reg [MPS_INPUT_COUNT-1:0] importantDiscrete = 0, firstFaultDiscrete = 0;
reg [MPS_INPUT_COUNT-1:0] discreteGoodState = 0;
reg [TIMESTAMP_WIDTH-1:0] whenFaulted = 0;
reg [MPS_INPUT_COUNT-1:0] mpsInputs = 0, discrete = 0;

/*
 * Registers to and from processor
 * Don't worry about clock-domain crossing since reaback
 * values should be stable and write transients will be
 * cleared up on the next acqClk.
 */
wire trip;  // In other domain, but read here.
always @(posedge sysClk) begin
    if (sysDataStrobe) begin
        case (sysREGsel)
        0:  importantHIHI      <= sysGPIO_OUT[ADC_COUNT-1:0];
        1:  importantHI        <= sysGPIO_OUT[ADC_COUNT-1:0];
        2:  importantLO        <= sysGPIO_OUT[ADC_COUNT-1:0];
        3:  importantLOLO      <= sysGPIO_OUT[ADC_COUNT-1:0];
        4:  importantDiscrete  <= sysGPIO_OUT[MPS_INPUT_COUNT-1:0];
        5:  discreteGoodState  <= sysGPIO_OUT[MPS_INPUT_COUNT-1:0];
        default: ;
        endcase
    end
    sysData <= (sysREGsel ==  0) ? importantHIHI :
               (sysREGsel ==  1) ? importantHI   :
               (sysREGsel ==  2) ? importantLO   :
               (sysREGsel ==  3) ? importantLOLO :
               (sysREGsel ==  4) ? {{32-MPS_INPUT_COUNT{1'b0}},
                                                            importantDiscrete} :
               (sysREGsel ==  5) ? {{32-MPS_INPUT_COUNT{1'b0}},
                                                            discreteGoodState} :
               (sysREGsel ==  6) ? firstFaultHIHI :
               (sysREGsel ==  7) ? firstFaultHI   :
               (sysREGsel ==  8) ? firstFaultLO   :
               (sysREGsel ==  9) ? firstFaultLOLO :
               (sysREGsel == 10) ? {
                               {16-MPS_INPUT_COUNT{1'b0}}, mpsInputs,
                               {16-MPS_INPUT_COUNT{1'b0}}, firstFaultDiscrete} :
               (sysREGsel == 11) ? whenFaulted[32+:32] :
               (sysREGsel == 12) ? whenFaulted[ 0+:32] :
               (sysREGsel == 13) ? {{30{1'b0}}, trip, acqTripped} : 0;
end

/*
 * MPS
 */
(*ASYNC_REG="true"*) reg [MPS_INPUT_COUNT-1:0] mpsInputs_m = 0;

wire[ADC_COUNT-1:0] excursionsHIHI = acqLimitExcursions[ADC_COUNT*0+:ADC_COUNT];
wire[ADC_COUNT-1:0] excursionsHI   = acqLimitExcursions[ADC_COUNT*1+:ADC_COUNT];
wire[ADC_COUNT-1:0] excursionsLO   = acqLimitExcursions[ADC_COUNT*2+:ADC_COUNT];
wire[ADC_COUNT-1:0] excursionsLOLO = acqLimitExcursions[ADC_COUNT*3+:ADC_COUNT];

wire [ADC_COUNT-1:0] faultsHIHI = excursionsHIHI & importantHIHI;
wire [ADC_COUNT-1:0] faultsHI   = excursionsHI   & importantHI  ;
wire [ADC_COUNT-1:0] faultsLO   = excursionsLO   & importantLO  ;
wire [ADC_COUNT-1:0] faultsLOLO = excursionsLOLO & importantLOLO;
wire [MPS_INPUT_COUNT-1:0] faultsDiscrete = (discrete & importantDiscrete);

assign trip = (faultsHIHI     != 0)
           || (faultsHI       != 0)
           || (faultsLO       != 0)
           || (faultsLOLO     != 0)
           || (faultsDiscrete != 0);

always @(posedge acqClk) begin
    mpsInputs_m <= mpsInputs_a;
    mpsInputs   <= mpsInputs_m;
    discrete    <= mpsInputs ^ discreteGoodState;

    if (acqClearTrip && !trip) begin
        acqTripped <= 0;
    end
    else if (trip && (acqClearTrip || !acqTripped)) begin
        firstFaultHIHI     <= faultsHIHI;
        firstFaultHI       <= faultsHI;
        firstFaultLO       <= faultsLO;
        firstFaultLOLO     <= faultsLOLO;
        firstFaultDiscrete <= faultsDiscrete;
        whenFaulted        <= acqTimestamp;
        acqTripped <= 1;
    end
end
endmodule
`default_nettype wire
