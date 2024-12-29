#!/bin/sh
set -e -x

[ -f "NASA_ACQ.xpr" ] || exit 1

git clean -xdf && git checkout -f

git submodule foreach 'git clean -xdf && git checkout -f'
