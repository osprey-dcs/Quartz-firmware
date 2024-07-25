#!/usr/bin/env python3

import argparse
import struct
import sys

parser = argparse.ArgumentParser(description='Display contents of AD7768 DCLK/DRDY recorder data file.',
            formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-b', '--binary', action = 'store_true',
                    help='Show data as 1/0 rather than GNUPLOT-friendly format')
parser.add_argument('-m', '--mclk', action = 'store_true',
                                 help='Provide fake MCLK (old 8-bit data file)')
parser.add_argument('-i', '--ifile', type=argparse.FileType('rb'), default=None,
                                                              help='Input file')
parser.add_argument('-o', '--ofile', type=argparse.FileType('w'),
                                         default=sys.stdout, help='Output file')

args = parser.parse_args()
if args.ifile == None:
    print("Input file must be specified.", file=sys.stderr)
    sys.exit(1)

b=args.ifile.read()

ns = 0
offset = 0
while (offset < len(b)):
    if (args.mclk):
        t = struct.unpack_from("<B", b, offset)
        offset += 1
    else:
        t = struct.unpack_from("<H", b, offset)
        offset += 2
    v = t[0]
    print("%d" %(ns), file=args.ofile, end='')
    ns += 8
    yOffset = 8
    bit = 0x100
    while bit != 0:
        if (args.binary):
            print(" %d" % (0 if ((v & bit) == 0) else 1), file=args.ofile, end='')
        else:
            if (bit == 0x100):
                print(" %s" % ("0.95" if ((v & bit) == 0) else "1.05"), file=args.ofile, end='')
            else:
                print(" %d.%d" % (0 if ((v & bit) == 0) else 1, yOffset), file=args.ofile, end='')
                yOffset -= 1
        bit >>= 1
    print("", file=args.ofile)
