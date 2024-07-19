#!/bin/sh

IP="192.168.19.101"
FILE="AD7768_DRDY.bin"

usage()
{
    echo "Usage: $0 [<TARGET_ADDRESS>] [<FILE>]" >&2
    exit 1
}

for i
do
    case "$i" in
    *.bi[nt])  FILE="$i" ;;
    [0-9][.0-9]*)  IP="$i" ;;
    *) usage ;;
    esac
done

tftp "$IP" <<!!!
verbose
bin
get AD7768_DRDY.bin $FILE
!!!
