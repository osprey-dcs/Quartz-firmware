#!/bin/sh

set -ex

DEST="$HOME/src/Osprey/src/ospreyEventTest/Workspace"

for d in \
  "$DEST/ospreyEventTest_platform/microblaze_0/standalone_microblaze_0/bsp/microblaze_0/libsrc/ospreyEVG_v1_0/src" \
  "$DEST/ospreyEventTest_platform/hw/drivers/ospreyEVG_v1_0/src"
do
  for f in \
      drivers/ospreyEVG_v1_0/src/ospreyEVG.c \
      drivers/ospreyEVG_v1_0/src/ospreyEVG.h \
      drivers/ospreyEVG_v1_0/src/ospreyEVG_selftest.c
  do
    cp "$f" "$d"
  done
done
