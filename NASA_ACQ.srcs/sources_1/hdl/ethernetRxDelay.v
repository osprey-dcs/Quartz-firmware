
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
 * Delay data value from ethernet PHY
 * The IDELAY_VALUE was determined emperically by placing the
 * delay blocks in VAR_LOAD mode and seeing what values 
 * corresponded to correct network operation.
 */
`default_nettype none
module ethernetRxDelay #(
    parameter IDELAY_VALUE = 11
    ) (
    input  wire       refClk200,
    input  wire       rst,
    input  wire [4:0] phyDataIn,
    output wire [4:0] phyDataOut);

IDELAYCTRL ethernetPHYdelayCTRL (
    .REFCLK(refClk200),
    .RST(rst),
    .RDY()
);

genvar i;
generate
for (i = 0 ; i < 5 ; i = i + 1) begin : ethernetPHYdelay
  IDELAYE2 #(
    .IDELAY_TYPE("FIXED"),
    .DELAY_SRC("IDATAIN"),
    .IDELAY_VALUE(IDELAY_VALUE),
    .SIGNAL_PATTERN("DATA"),
    .REFCLK_FREQUENCY(200))
  phy_rxd_idelay (
    .IDATAIN(phyDataIn[i]),
    .DATAOUT(phyDataOut[i]),
    .DATAIN(1'b0),
    .C(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'd0),
    .CNTVALUEOUT(),
    .LD(1'b0),
    .LDPIPEEN(1'b0),
    .REGRST(1'b0)
);
end
endgenerate

endmodule
`default_nettype wire
