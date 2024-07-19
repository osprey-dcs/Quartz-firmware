#!/bin/sh

FILE="AD7768_DRDY.txt"

usage() {
    echo "Usage: $0 [datafile]" >&2
    exit 1
}

case "$#" in
    0)  ;;
    1)  FILE="$1" ;;
    *)  usage ;;
esac
FILE="'$FILE'"

gnuplot -e "filename=$FILE" plotAD7768.gnuplot -
