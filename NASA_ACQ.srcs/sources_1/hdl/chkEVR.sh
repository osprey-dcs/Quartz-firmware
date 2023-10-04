#!/bin/sh

set -ex

iverilog -Wall -Pevr.MGT_COUNT=8 -Pevr.EVG_CLK_RATE=125000000 mgtWrapper.v  \
         ../../../NASA_ACQ.gen/sources_1/ip/MGT/MGT_stub.v \
         evr.v \
         tinyEVR.v \
         tinyEVG.v \
         mgt_common.v \
         "$HOME/Xilinx/2023.1/Vivado/2023.1/data/verilog/src/unisim_comp.v"  \
         2>&1 | grep -v timescale
      

