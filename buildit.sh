#!/bin/sh
set -e -x

die() {
    cat <<EOF >&2
Usage: $0 <project.xpr>

EOF
    echo "Error: $1" >&2
    exit 1
}

XPR="$1"
NPROC="$2"

BASE="${XPR%.xpr}"

[ -f "${XPR}" ] \
|| die "Must by XPR: ${XPR}"

[ -f "Workspace/NASA_ACQ/src/nasaAcq.json" ] \
|| die "Must checkout sub-module at: Workspace/NASA_ACQ"

[ "$NPROC" ] || NPROC="2"
echo "Using $NPROC CPUs"

CNAME="$(git log -n1 --format=format:%cd-%h HEAD --date=format:%Y%m%d)"

# scratch space for script fragments
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' INT QUIT EXIT

if [ -e "${BASE}.xsa" ]
then
    echo "Use existing HDL from ${BASE}.xsa"
    echo "  To regenerate, delete that file and re-run."

else
    echo "Build HDL into ${BASE}.xsa"

    # Run code generators
    ( cd Workspace/NASA_ACQ/src && sh createVerilogHeader.sh && make)

# vivado: Generate .XSA file

    cat <<EOF > "$SCRATCH/xsa.tcl"
open_project "${XPR}"

# The first time through, the DCP files are not present.
# However, vivado will barf if they are still referenced :(
# Will be automatically re-added after a successful run.
foreach dcp [get_files -quiet -filter file_type=="Design\ Checkpoint"] {
    if {[get_property IS_AVAILABLE \$dcp] == 0} {
        puts "Remove reference to missing DCP \$dcp"
        remove_files \$dcp
    } else {
        puts "Found DCP: \$dcp"
    }
}

validate_ip -verbose [get_ips]

generate_target all [get_files *.bd]
generate_target all [get_files "*/NASA_ACQ.srcs/sources_1/ip/*/*.xci"]

reset_run synth_1
reset_run impl_1

# slow part...
launch_runs synth_1 -jobs $NPROC
wait_on_run -verbose synth_1

# zzzz....
launch_runs impl_1 -jobs $NPROC -to_step write_bitstream
wait_on_run -verbose impl_1

write_hw_platform -force -include_bit -fixed -verbose ${BASE}.xsa
EOF

    vivado -mode batch -source "$SCRATCH/xsa.tcl"

    [ -f "${BASE}.xsa" ] || die "${BASE}.xsa successfully not created?!?"
fi

# vitis: build ublaze application (.ELF file)

# difficult to make vitis idempotent, so remove and recreate the project meta-data.
rm -rf \
 "Workspace/.metadata" \
 "Workspace/${BASE}_platform" \
 "Workspace/${BASE}_app_system" \
 "Workspace/${BASE}_app"

cat <<EOF > "$SCRATCH/platform.tcl"
setws Workspace
platform create -name ${BASE}_platform -hw ${BASE}.xsa
domain create -name foo -os standalone -proc microblaze_0
app create -name ${BASE}_app -platform ${BASE}_platform -domain foo -template "Empty Application(C)"
importsources -name ${BASE}_app -path Workspace/NASA_ACQ/src -linker-script
app config -name ${BASE}_app build-config Release
app build -name ${BASE}_app
EOF

xsct "$SCRATCH/platform.tcl"

# insert ELF into ublaze ROM for final BIT file

# updatemem exits with 0 on error :(
# so absense of output is the only sign of failure
rm -f "$BASE-$CNAME.bit"

updatemem \
 --meminfo ${BASE}.runs/impl_1/${BASE}.mmi \
 --proc bd_i/microblaze_0 \
 --data Workspace/${BASE}_app/Release/${BASE}_app.elf \
 --bit ${BASE}.runs/impl_1/${BASE}.bit \
 --force \
 --out "${BASE}-$CNAME.bit"

echo "All done!"

ls -lh "$BASE-$CNAME.bit"
