#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_golden.py - Golden-vector generator for the single-PE 3x3 conv accelerator
===============================================================================
Generates:
  - ifm.hex        : 256 x int16 (Q8.7) input feature map (16x16)
  - wgt.hex        : 10  x int16 (Q8.7) weights: index0..8 = 3x3 kernel,
                     index9 = bias
  - golden_output.hex : 256 x int16 expected convolution result

The fixed-point rules here MUST match the RTL exactly:
  acc  = sum( ifm[r,c] * wgt[r,c] , 9 taps ) + bias   (32-bit int)
  res  = arithmetic_right_shift( acc, SHIFT_BITS )    (Python >> is arithmetic)
  out  = saturate_to_int16( res )

Padding = 1: for output pixel (row,col), window covers ifm(row-1+r, col-1+c),
             r,c in 0..2; out-of-range coordinates read as 0.
"""
import random

# ---------------------------- Configuration ---------------------------------
IMG_H   = 16
IMG_W   = 16
K_SIZE  = 3
PAD     = 1
SHIFT_BITS = 4
SEED    = 42
VALUE_RANGE = 127   # max magnitude for random int16 data

OUT_HEX_W = 4       # 16-bit -> 4 hex digits

# ---------------------------- Helpers ---------------------------------------
def to_int16(val):
    """Wrap a Python int into signed 16-bit range."""
    val = val & 0xFFFF
    if val >= 0x8000:
        val -= 0x10000
    return val

def saturate_to_int16(val):
    """Saturate to signed 16-bit."""
    if val > 0x7FFF:
        return 0x7FFF
    if val < -0x8000:
        return -0x8000
    return val

def signed_to_hex(val, hex_w=OUT_HEX_W, bits=16):
    """Signed int -> lowercase hex string (two's complement)."""
    val &= (1 << bits) - 1
    return f"{val:0{hex_w}X}"

def write_hex(path, data, bits=16):
    with open(path, "w") as f:
        for v in data:
            f.write(signed_to_hex(v, bits=bits) + "\n")
    print(f"wrote {path} ({len(data)} entries)")

# ---------------------------- Data generation --------------------------------
random.seed(SEED)

# input feature map, row-major
ifm = [to_int16(random.randint(-VALUE_RANGE, VALUE_RANGE)) for _ in range(IMG_H * IMG_W)]

# 3x3 kernel weights + bias (index 9)
wgt = [to_int16(random.randint(-VALUE_RANGE, VALUE_RANGE)) for _ in range(K_SIZE * K_SIZE)]
bias = to_int16(random.randint(-VALUE_RANGE, VALUE_RANGE))
wgt_full = wgt + [bias]

# ---------------------------- Golden computation -----------------------------
def ifm_at(r, c):
    """Read ifm with padding; out-of-range -> 0."""
    if 0 <= r < IMG_H and 0 <= c < IMG_W:
        return ifm[r * IMG_W + c]
    return 0

golden = []
for row in range(IMG_H):
    for col in range(IMG_W):
        acc = 0
        idx = 0
        for r in range(K_SIZE):
            for c in range(K_SIZE):
                acc += ifm_at(row - PAD + r, col - PAD + c) * wgt[idx]
                idx += 1
        acc += bias
        res = acc >> SHIFT_BITS          # arithmetic shift
        golden.append(saturate_to_int16(res))

# ---------------------------- Write outputs ----------------------------------
write_hex("ifm.hex", ifm)
write_hex("wgt.hex", wgt_full)
write_hex("golden_output.hex", golden)

print("golden vectors generated (seed=%d)" % SEED)
