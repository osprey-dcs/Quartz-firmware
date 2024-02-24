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
 * Send acquisition start/stop events at gap between acquired samples.
 * This removes any race conditions in the acquisition nodes.
 */
`default_nettype none
module evgAcqControl #(
    parameter EVCODE_ACQ_START = 0,
    parameter EVCODE_ACQ_STOP  = 0,
    parameter EVG_CLK_RATE     = 125000000,
    parameter DEBUG            = "false"
    ) (
                         input  wire        sysClk,
    (*MARK_DEBUG=DEBUG*) input  wire        sysCsrStrobe,
    (*MARK_DEBUG=DEBUG*) input  wire [31:0] sysGPIO_OUT,
    (*MARK_DEBUG=DEBUG*) output wire [31:0] sysStatus,

                         input  wire        evgClk,
    (*MARK_DEBUG=DEBUG*) output reg   [7:0] evgEventCode,
    (*MARK_DEBUG=DEBUG*) output reg         evgEventCodeValid,

                         input  wire        acqClk,
    (*MARK_DEBUG=DEBUG*) input  wire        acqStrobe);


function integer ns2ticks;
    input integer ns;
    begin
        ns2ticks = (((ns) * (EVG_CLK_RATE/100)) + 9999999) / 10000000;
    end
endfunction
localparam DELAY_TICKS = ns2ticks(800);

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg sysAcqEnabled = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysAcqEnabled <= sysGPIO_OUT[0];
    end
end
assign sysStatus = { {31{1'b0}}, sysAcqEnabled };

///////////////////////////////////////////////////////////////////////////////
// ACQ clock domain

/*
 * Stretch acqStrobe to ensure it can be seen in EVG clock domain.
 */
reg [4:0] acqStretchCounter = 0;
(*MARK_DEBUG=DEBUG*) wire acqStretched = acqStretchCounter[4];
always @(posedge acqClk) begin
    if (acqStrobe) begin
        acqStretchCounter <= ~0;
    end
    else if (acqStretched) begin
        acqStretchCounter <= acqStretchCounter - 1;
    end
end

///////////////////////////////////////////////////////////////////////////////
// EVG clock domain

// Clock domain crossing
(*ASYNC_REG="true"*) reg evgAcqEnabled_m = 0;
(*MARK_DEBUG=DEBUG*) reg evgAcqEnabled = 0;
(*ASYNC_REG="true"*) reg evgAcqStretched_m = 0;
(*MARK_DEBUG=DEBUG*) reg evgAcqStretched = 0, evgAcqStretched_d = 0;

// Event generation state machine
localparam ST_AWAIT_ENABLE  = 3'd0,
           ST_AWAIT_ACQ     = 3'd1,
           ST_DELAY_1       = 3'd2,
           ST_SEND_START    = 3'd3,
           ST_DELAY_2       = 3'd4,
           ST_AWAIT_DISABLE = 3'd5,
           ST_SEND_STOP     = 3'd6;
(*MARK_DEBUG=DEBUG*) reg [2:0] state = ST_AWAIT_ENABLE;

localparam DELAY_LOAD = DELAY_TICKS - 1;
localparam DELAY_WIDTH = $clog2(DELAY_LOAD+1) + 1;
reg [DELAY_WIDTH-1:0] delay = DELAY_LOAD;
(*MARK_DEBUG=DEBUG*) wire delayDone = delay[DELAY_WIDTH-1];

always @(posedge evgClk) begin
    evgAcqEnabled_m <= sysAcqEnabled;
    evgAcqEnabled   <= evgAcqEnabled_m;
    evgAcqStretched_m <= acqStretched;
    evgAcqStretched   <= evgAcqStretched_m;
    evgAcqStretched_d <= evgAcqStretched;

    // Send START code in gap between ADC data strobes
    case (state)
    ST_AWAIT_ENABLE: begin
        evgEventCodeValid <= 0;
        if (evgAcqEnabled) begin
            state <= ST_AWAIT_ACQ;
        end
    end
    ST_AWAIT_ACQ: begin
        delay <= DELAY_LOAD;
        evgEventCodeValid <= 0;
        if (!evgAcqEnabled) begin
            state <= ST_AWAIT_ENABLE;
        end
        if (evgAcqStretched && !evgAcqStretched_d) begin
            state <= ST_DELAY_1;
        end
    end
    ST_DELAY_1: begin
        if (!evgAcqEnabled) begin
            state <= ST_AWAIT_ENABLE;
        end
        delay <= delay - 1;
        if (delayDone) begin
            state <= ST_SEND_START;
        end
    end
    ST_SEND_START: begin
        delay <= DELAY_LOAD;
        evgEventCode <= EVCODE_ACQ_START;
        evgEventCodeValid <= 1;
        state <= ST_DELAY_2;
    end
    ST_DELAY_2: begin
        evgEventCodeValid <= 0;
        delay <= delay - 1;
        if (delayDone) begin
            state <= ST_AWAIT_DISABLE;
        end
    end
    ST_AWAIT_DISABLE: begin
        if (!evgAcqEnabled) begin
            state <= ST_SEND_STOP;
        end
    end
    ST_SEND_STOP: begin
        evgEventCode <= EVCODE_ACQ_STOP;
        evgEventCodeValid <= 1;
        state <= ST_AWAIT_ENABLE;
    end
    default: ;
    endcase
end

endmodule
`default_nettype wire
