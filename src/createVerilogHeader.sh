#!/bin/sh

# Simple sed script to create Verilog version of GPIO indicies

DEST='../../../NASA_ACQ.srcs/sources_1/hdl/gpio.v'

(
echo "// Machine-generated -- do not edit"
sed -n -e '/^ *# *define *GPIO_IDX/s/.*\(GPIO_IDX[^ ]*\) *\([0-9]*\)/parameter \1 = \2,/p' gpio.h
sed -n -e '/^ *# *define *CFG_/s/^ *# *define *\(CFG_[^ ]*\) *\(.*\)/parameter \1 = \2,/p' config.h
) >"$DEST"
