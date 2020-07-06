#!/usr/bin/env python3

import sys

fname = sys.argv[1]
needle = sys.argv[2].encode('ascii')
start_at = int(sys.argv[3])
break_when_found = True

needle_len = len(needle)
i = 0

found = False
old_buf = b''
with open(fname, 'rb') as f:
    f.seek(start_at)
    buf = old_buf + f.read(1024*1024)
    while buf:
        r = buf.find(needle)
        if r >= 0:
            print ("Found {} at {}".format(needle, i+r))
            found = True
            if break_when_found:
                break
        i += len(buf)
        old_buf = buf[-needle_len:]
        buf = f.read(needle_len)

if not found:
    print ("Could not find {}".format(needle))
    sys.exit(1)
