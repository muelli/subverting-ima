#!/usr/bin/env python3

from subprocess import check_call

size = 1024*1024*1024*1  # 1GB
fname = "/usr/local/bin/check.sh"

bytestream = (b'\x00' for i in range(size))
fh = open(fname, 'ab')

for b in bytestream:
    # This is grossly inefficient, but I fear creating a 1GB large string in memory
    # Unfortunately, chunking, i.e. taking also 1MB or so, is surprisingly
    # complicated
    fh.write(b'\x00')


cmd = "systemctl disable appendzeros.service"
check_call(cmd.split())
