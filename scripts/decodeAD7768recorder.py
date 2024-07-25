#!/usr/bin/env python3

import argparse
import sys

parser = argparse.ArgumentParser(description='Display contents of AD7768 DCLK/DRDY recorder data file.',
            formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-g', '--gnuplot', action = 'store_true', help='GNUPLOT-friendly format')
parser.add_argument('-i', '--ifile', type=argparse.FileType('rb'), default=None)
parser.add_argument('-o', '--ofile', type=argparse.FileType('w'),
                                                             default=sys.stdout)

args = parser.parse_args()
if args.ifile == None:
    print("Input file must be specified.", file=sys.stderr)
    sys.exit(1)

b=args.ifile.read()

ns = 0
for c in b:
    bit = 0x80
    print("%d" %(ns), file=args.ofile, end='')
    ns += 8
    yOffset = 8
    while bit != 0:
        if (args.gnuplot):
            print(" %d.%d" % (0 if ((c & bit) == 0) else 1, yOffset), file=args.ofile, end='')
            yOffset -= 1
        else:
            print(" %d" % (0 if ((c & bit) == 0) else 1), file=args.ofile, end='')
        bit >>= 1
    print("", file=args.ofile)
