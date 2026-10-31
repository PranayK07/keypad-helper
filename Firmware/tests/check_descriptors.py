#!/usr/bin/env python3
"""Inspect the descriptor bytes that are compiled into the device, without USB access."""
import re
from pathlib import Path
source = re.sub(r'/\*.*?\*/', '', Path('src/usb_descr.c').read_text(), flags=re.S)
arrays = {}
for name, size, body in re.findall(r'uint8_t (\w+)\[(\d+)\]\s*=\s*\{(.*?)\}', source, re.S):
    values = bytes(int(x.strip(), 0) for x in body.split(',') if x.strip())
    assert len(values) == int(size), (name, len(values), size)
    arrays[name] = values
config = arrays['CfgDescr']
assert config[2] == len(config) and config[3] == 0 and config[4] == 2
assert config[18:27] == bytes([9, 0x21, 0x11, 1, 0, 1, 0x22, len(arrays['KeyboardReportDescr']), 0])
assert config[43:52] == bytes([9, 0x21, 0x11, 1, 0, 1, 0x22, len(arrays['LightingReportDescr']), 0])
assert config[34:43] == bytes([9, 4, 1, 0, 0, 3, 0, 0, 0])
assert arrays['LightingReportDescr'] == bytes([6,0x60,0xff,9,0x61,0xa1,1,0x15,0,0x26,0xff,0,0x75,8,0x95,32,9,0x62,0xb1,2,0xc0])
assert arrays['KeyboardReportDescr'][-1] == 0xc0
assert arrays['DevDescr'][8:12] == bytes([0x89,0x11,0x90,0x88])
assert "'K','e','y','p','a','d',' ','H','e','l','p','e','r',' ','R','G','B'" in source
print('Composite descriptors: keyboard + exact vendor Feature interface validated.')
