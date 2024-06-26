#!/bin/sh

UNI="$HOME/Xilinx/2023.1/Vivado/2023.1/data/verilog/src"

iverilog -Wall \
         -y"$UNI/unimacro" \
         -y"$UNI/unisims" \
         -PfiberLinks.MGT_COUNT=8 \
         -PfiberLinks.TIMESTAMP_WIDTH=64 \
         -PfiberLinks.EVR_ACQ_START_CODE=96 \
         -PfiberLinks.EVR_ACQ_START_CODE=97 \
         fiberLinks.v \
         mgtWrapper.v \
         tinyEVG.v \
         tinyEVR.v \
         evf.v \
         mpsMerge.v \
         "$UNI/glbl.v" \
         ../../../NASA_ACQ.gen/sources_1/ip/mgtShared/mgtShared_stub.v
