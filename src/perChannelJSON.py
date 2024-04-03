#!/usr/bin/env python
def block(name, base):
    for chan in range(1,33):
        print('    "ACQ:%s:%02d": {' % (name, chan))
        print('        "access": "rw",')
        print('        "addr_width": 0,')
        print('        "base_addr": %d,' % (base - 1 + chan))
        print('        "data_width": 16,')
        print('        "sign": "unsigned",')
        print('    },')

block("enable", 400)
block("coupling", 500)
