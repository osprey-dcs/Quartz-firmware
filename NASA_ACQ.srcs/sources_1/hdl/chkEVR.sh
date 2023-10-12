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
rm a.out

trap "rm jnk[AB]$$" 0 1 2 3

F=jnkA$$
for src in mgtWrapper.v ../../../NASA_ACQ.gen/sources_1/ip/MGT/mgt.veo
do
    sed -n -e 's/^ *\(\.gt[0-9][a-zA-Z0-9_]*\).*/\1/p' "$src" >$F
    F=jnkB$$
done
diff -y --width=80 jnkA$$ jnkB$$
