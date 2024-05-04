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
 * AC/DC coupling
 */
`default_nettype none
module inputCoupling #(
    parameter CHANNEL_COUNT = 1,
    parameter DATA_WIDTH    = 24,
    parameter DEBUG         = "false"
    ) (
    input  wire        sysClk,
    input  wire        sysCsrStrobe,
    input  wire [31:0] sysGPIO_OUT,
    output wire [31:0] sysStatus,

    input  wire                                         clk,
    input  wire signed [(CHANNEL_COUNT*DATA_WIDTH)-1:0] inTDATA,
    input  wire                                         inTVALID,
    output wire signed [(CHANNEL_COUNT*DATA_WIDTH)-1:0] outTDATA,
    output wire                                         outTVALID);

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg [CHANNEL_COUNT-1:0] sysCoupling;
reg                     sysCouplingToggle = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        sysCoupling <= sysGPIO_OUT[CHANNEL_COUNT-1:0];
        sysCouplingToggle <= !sysCouplingToggle;
    end
end

assign sysStatus = sysCoupling;

//////////////////////////////////////////////////////////////////////////////
// Signal processing clock domain

(*ASYNC_REG="true"*) reg couplingToggle_m = 0;
(*MARK_DEBUG=DEBUG*) reg couplingToggle = 0, couplingToggle_d = 0;
(*MARK_DEBUG=DEBUG*) reg [CHANNEL_COUNT-1:0] dcCoupled;

always @(posedge clk) begin
    couplingToggle_m <= sysCouplingToggle;
    couplingToggle   <= couplingToggle_m;
    couplingToggle_d <= couplingToggle;
    if (couplingToggle != couplingToggle_d) begin
        dcCoupled <= sysCoupling;
    end
end

genvar i;
generate
for (i = 0 ; i < CHANNEL_COUNT ; i = i + 1) begin : inputCoupler
    (*MARK_DEBUG=DEBUG*) wire signed [DATA_WIDTH-1:0] inData =
                                              inTDATA[i*DATA_WIDTH+:DATA_WIDTH];
    (*MARK_DEBUG=DEBUG*) reg  signed [DATA_WIDTH-1:0] dcData;
    (*MARK_DEBUG=DEBUG*) wire signed [DATA_WIDTH-1:0] acData;
    (*MARK_DEBUG=DEBUG*) wire                         acDataValid;
    (*MARK_DEBUG=DEBUG*) reg  signed [DATA_WIDTH-1:0] outData;
    (*MARK_DEBUG=DEBUG*) reg  signed                  outValid = 0;

    iirHighpass #(
        .TDATA_WIDTH(DATA_WIDTH),
        .LOG2_ALPHA(15))
      iirHigPass_i (
        .clk(clk),
        .S_TDATA(inData),
        .S_TVALID(inTVALID),
        .M_TDATA(acData),
        .M_TVALID(acDataValid));
    always @(posedge clk) begin
        if (inTVALID) begin
            dcData <= inData;
        end
        if (acDataValid) begin
            outData <= dcCoupled[i] ? dcData : acData;
            outValid <= 1;
        end
        else begin
            outValid <= 0;
        end
    end
    assign outTDATA[i*DATA_WIDTH+:DATA_WIDTH] = outData;
    if (i == 0) begin
        assign outTVALID = outValid;
    end
end
endgenerate
endmodule
