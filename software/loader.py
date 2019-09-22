#!/usr/bin/env python3

import sys
import serial
from sys import argv

COM = argv[1]
binFile = argv[2]

with open(binFile, "rb") as f:
    bindata = f.read()
    lenbin = len(bindata)

print("------------------------------------------------------------")
print("Serial bootloader.")
print("Executable file: {}. Size: {} bytes".format(binFile, lenbin))
print("Opening COM port: {}".format(COM))
with serial.Serial(COM, 1000000, timeout=0) as ser:
    x = ser.read(10)
    ser.timeout = 5
    print("Waiting for 0xFF. Please, reset the board :) (Timeout = 5 seconds)")
    x = ser.read()
    if x == b'\xff':
        print("0xFF received. Sending file size")
        sz = (lenbin).to_bytes(2, 'big')
        ser.write(sz)
        x = ser.read(2)
        if (sz != x):
            print("Invalid echo in size packet: {} != {}".format(sz, x))
            exit(-1)

        print("Sending payload")
        chunksz = 32
        payload = [ bindata[i:i+chunksz] for i in range(0, lenbin, chunksz) ]
        for chunk in payload:
            ser.write(chunk)
            x = ser.read(len(chunk))
            if chunk != x:
                print("Error. Payload mismatch:")
                print(chunk)
                print(x)
                exit(1)

        # boot
        print("Booting...")
        print("------------------------------------------------------------")
        ser.timeout = 0
        while(1):
            x = ser.read().decode('ascii')
            print(x, end='')
            sys.stdout.flush()
    else:
        print("Invalid character from SoC: {}".format(x))
