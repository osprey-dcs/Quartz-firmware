#!/bin/sh
set -e -x

die() {
    echo "Error: $1" >&2
    exit 1
}

[ -f "NASA_ACQ.xpr" ] \
|| die "Must run in git checkout containing NASA_ACQ.xpr"

[ -f "Workspace/NASA_ACQ/src/nasaAcq.json" ] \
|| die "Must checkout sub-module at: Workspace/NASA_ACQ"

CNAME="$(git log -n1 --format=format:%cd-%h HEAD --date=format:%Y%m%d)"

# scratch space for script fragments
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' INT QUIT EXIT

# Run code generators
( cd Workspace/NASA_ACQ/src && sh createVerilogHeader.sh && make)

# vivado: Generate .XSA file

cat <<EOF > "$SCRATCH/xsa.tcl"
open_project "NASA_ACQ.xpr"

validate_ip -verbose [get_ips]

generate_target all [get_files *.bd]
generate_target all [get_files "*/NASA_ACQ.srcs/sources_1/ip/*/*.xci"]

write_hw_platform -minimal -fixed NASA_ACQ.xsa
EOF

vivado -mode batch -source "$SCRATCH/xsa.tcl"

# vitis: build ublaze application (.ELF file)

cat <<EOF > "$SCRATCH/platform.tcl"
setws Workspace
platform create -name NASA_ACQ_platform -hw NASA_ACQ.xsa
domain create -name foo -os standalone -proc microblaze_0
app create -name bar -platform NASA_ACQ_platform -domain foo -template "Empty Application(C)"
importsources -name bar -path Workspace/NASA_ACQ/src -linker-script
app config -name bar build-config Release
app build -name bar
EOF

xsct "$SCRATCH/platform.tcl"

# vivado: generate .BIT file

cat <<EOF > "$SCRATCH/bit.tcl"
open_project "NASA_ACQ.xpr"

reset_run synth_1
reset_run impl_1

# slow part...
launch_runs synth_1 -jobs 2
wait_on_run -verbose synth_1

# zzzz....
launch_runs impl_1 -jobs 2 -to_step write_bitstream
wait_on_run -verbose impl_1

# insert .elf into ublaze BRAM for final .bit
exec updatemem \
 --meminfo ./NASA_ACQ.runs/impl_1/NASA_ACQ.mmi \
 --proc bd_i/microblaze_0 \
 --data Workspace/bar/Release/bar.elf \
 --bit NASA_ACQ.runs/impl_1/NASA_ACQ.bit \
 --force \
 --out "quartzV1-$CNAME.bit"

EOF

vivado -mode batch -source "$SCRATCH/bit.tcl"

echo "All done!"

ls -lh quartzV1*.bit
