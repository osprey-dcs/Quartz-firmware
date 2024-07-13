#!/bin/sh

set -ex


trap "rm jnk[AB]$$" 0 1 2 3
F=jnkA$$
for src in mgtWrapper.v ../../../NASA_ACQ.gen/sources_1/ip/mgtShared/mgtshared.veo
do
    sed -n -e 's/^ *\(\.gt[0-9][a-zA-Z0-9_]*\).*/\1/p' \
           -e 's/^ *\(\.soft[a-zA-Z0-9_]*\).*/\1/p' \
           -e 's/^ *\(\.sysclk[a-zA-Z0-9_]*\).*/\1/p' \
           -e '/^  *\/\//p' \
           "$src" >$F
    F=jnkB$$
done
diff -s -b -y --width=180 jnkA$$ jnkB$$
echo done
