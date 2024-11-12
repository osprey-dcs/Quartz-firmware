#!/bin/sh

IP=192.168.19.101
BOOT=quartzV1.bit
TARGET=BOOT.bin

usage()
{
    echo "Usage: $0 [-a] [<TARGET_ADDRESS>] [<BOOTFILE>]" >&2
    exit 1
}

for i
do
    case "$i" in
    -a)        TARGET=BOOT_A.bin ;;
    *.bi[nt])  BOOT="$i" ;;
    [0-9][.0-9]*)  IP="$i" ;;
    *) usage ;;
    esac
done

set -- `wc -c "$BOOT"`
CMPLEN="$1"

tftp "$IP" <<!!!
verbose
bin
put $BOOT $TARGET
get $TARGET chk$$.bin
!!!
truncate -s "$CMPLEN" chk$$.bin
if cmp "$BOOT" chk$$.bin
then
    echo "$0: Flash write succeeded." >&2
    rm chk$$.bin   
else
    echo "$0: Warning -- boot image in flash may be corrupt." >&2
    exit 2
fi
