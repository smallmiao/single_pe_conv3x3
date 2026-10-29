#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_result.py - Compare RTL simulation output against golden vectors
=========================================================================
Reads two .hex files (signed 16-bit) and reports:
  - overall PASS/FAIL
  - number of mismatches
  - max absolute error
  - first mismatch location & values

Usage:
  python check_result.py <rtl_out.hex> <golden_out.hex>
"""
import sys

def load_hex(path, bits=16):
    vals = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            v = int(line, 16)
            if v >= (1 << (bits - 1)):
                v -= (1 << bits)
            vals.append(v)
    return vals

def main():
    if len(sys.argv) != 3:
        print("usage: check_result.py <rtl_out.hex> <golden_out.hex>")
        sys.exit(2)

    rtl = load_hex(sys.argv[1])
    gol = load_hex(sys.argv[2])

    if len(rtl) != len(gol):
        print(f"FAIL: length mismatch rtl={len(rtl)} golden={len(gol)}")
        sys.exit(1)

    mismatches = 0
    max_err = 0
    first = None
    for i, (r, g) in enumerate(zip(rtl, gol)):
        err = abs(r - g)
        if r != g:
            mismatches += 1
            max_err = max(max_err, err)
            if first is None:
                first = (i, r, g, err)

    if mismatches == 0:
        print(f"PASS: all {len(rtl)} samples match golden")
    else:
        print(f"FAIL: {mismatches}/{len(rtl)} mismatches, max_err={max_err}")
        if first:
            print(f"  first mismatch: idx={first[0]} rtl={first[1]} golden={first[2]} err={first[3]}")

    sys.exit(0 if mismatches == 0 else 1)

if __name__ == "__main__":
    main()
