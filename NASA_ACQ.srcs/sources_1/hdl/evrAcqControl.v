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
 * Act on acquisition start/stop events.
 */
`default_nettype none
module evrAcqControl #(
    parameter DEBUG = "false"
    ) (
                         input  wire evrClk,
    (*MARK_DEBUG=DEBUG*) input  wire evrRxStartACQstrobe,
    (*MARK_DEBUG=DEBUG*) input  wire evrRxStopACQstrobe,

                         input  wire acqClk,
    (*MARK_DEBUG=DEBUG*) output reg  acqEnableAcquisition);

///////////////////////////////////////////////////////////////////////////////
// EVR clock domain
(*MARK_DEBUG=DEBUG*) reg evrEnableAcquisition = 0;
always @(posedge evrClk) begin
    if (evrRxStartACQstrobe) evrEnableAcquisition <= 1;
    if (evrRxStopACQstrobe)  evrEnableAcquisition <= 0;
end

///////////////////////////////////////////////////////////////////////////////
// ACQ clock domain
(*ASYNC_REG="true"*) reg acqEnableAcquisition_m = 0;
always @(posedge acqClk) begin
    acqEnableAcquisition_m <= evrEnableAcquisition;
    acqEnableAcquisition   <= acqEnableAcquisition_m;
end

endmodule
`default_nettype wire
