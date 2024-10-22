Block of 32-bit I/O points.

In the C application use something like this to define the register indexes:
gpio.h:
    /*
     * Indices into the big general purpose I/O block.
     * Used to generate Verilog parameter statements too, so be careful with
     * the syntax:
     *     Spaces only (no tabs).
     *     Index defines must be valid Verilog parameter expressions.
     */
    #ifndef _GPIO_H_
    #define _GPIO_H_

    #define GPIO_IDX_COUNT 64

    #define GPIO_IDX_FIRMWARE_BUILD_DATE      0 // Firmware build POSIX seconds (R)
    #define GPIO_IDX_MICROSECONDS_SINCE_BOOT  1 // Microseconds since boot (R)
    #define GPIO_IDX_SECONDS_SINCE_BOOT       2 // Seconds since boot (R)
    #define GPIO_IDX_USER_GPIO_CSR            3 // Diagnostic LEDS/switches
    #define GPIO_IDX_MGT_CSR                  4 // MGT control/status
    #define GPIO_IDX_FREQ_MONITOR_CSR         5 // Frequency measurement CSR
    . . .
    #include <xil_io.h>
    #include <xparameters.h>
    #include "config.h"
    #define GPIO_READ(i)    Xil_In32(XPAR_AXI_LITE_GENERIC_REG_S_AXI_BASEADDR+(4*(i)))
    #define GPIO_WRITE(i,x) Xil_Out32(XPAR_AXI_LITE_GENERIC_REG_S_AXI_BASEADDR+(4*(i)),(x))
    #endif

Then run a version of this script to produce the corresponding set of Verilog parameters:
#!/bin/sh

# Simple sed script to create Verilog version of GPIO indicies and configuration parameters

DEST='../../../MPEX_ACQ.srcs/sources_1/hdl/gpio.v'

(
echo "// Machine-generated -- do not edit"
sed -n -e '/^ *# *define *GPIO_IDX/s/.*\(GPIO_IDX[^ ]*\) *\([0-9]*\)/parameter \1 = \2,/p' gpio.h
sed -n -e '/^ *# *define *CFG_/s/.*\(CFG_[^ ]*\) *\([0-9]*\)/parameter \1 = \2,/p' config.h
) >"$DEST"


And in the application top-level Verilog file:
//////////////////////////////////////////////////////////////////////////////
// General-purpose I/O block
// Include file is machine generated from C header
`include "gpioIDX.v"
wire                    [31:0] GPIO_IN[0:GPIO_IDX_COUNT-1];
wire                    [31:0] GPIO_OUT;
wire      [GPIO_IDX_COUNT-1:0] GPIO_STROBES;
wire [(GPIO_IDX_COUNT*32)-1:0] GPIO_IN_FLATTENED;
genvar i;
generate
for (i = 0 ; i < GPIO_IDX_COUNT ; i = i + 1) begin : gpio_flatten
    assign GPIO_IN_FLATTENED[i*32+:32] = GPIO_IN[i];
end
endgenerate
assign GPIO_IN[GPIO_IDX_FIRMWARE_BUILD_DATE] = FIRMWARE_BUILD_DATE;
. . .
// Block diagram instantiation
system system_i (
    . . .
    .GPIO_IN(GPIO_IN_FLATTENED),
    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBES(GPIO_STROBES),
