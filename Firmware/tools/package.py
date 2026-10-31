#!/usr/bin/env python3
"""Validate Intel HEX and make build artifacts. Never opens a device."""
import hashlib
import json
import sys
from pathlib import Path
source, output = Path(sys.argv[1]), Path(sys.argv[2])
memory = {}
base = 0
ended = False
for line in source.read_text().splitlines():
    if not line: continue
    assert not ended and line.startswith(':'), 'Invalid HEX record order'
    record = bytes.fromhex(line[1:])
    count, hi, lo, kind = record[:4]
    assert len(record) == count + 5 and sum(record) % 256 == 0, 'Invalid HEX checksum/length'
    data = record[4:-1]
    if kind == 0:
        start = base + (hi << 8) + lo
        for index, value in enumerate(data):
            address = start + index
            assert 0 <= address < 0x3800, 'Image overlaps bootloader or exceeds CH552 application area'
            assert address not in memory, 'Overlapping HEX records'
            memory[address] = value
    elif kind == 1:
        assert count == 0
        ended = True
    elif kind == 4:
        assert count == 2
        base = int.from_bytes(data, 'big') << 16
    else:
        raise AssertionError(f'Unsupported HEX record {kind}')
assert ended and memory and 0 in memory, 'Missing firmware entrypoint/EOF'
binary = bytes(memory.get(i, 0xff) for i in range(max(memory)+1))
output.with_suffix('.bin').write_bytes(binary)
output.with_suffix('.hex').write_text(source.read_text())
manifest = {
    'experimental': True, 'hardware_verified': False, 'protocol': 'KPHL/1',
    'mcu': 'CH552G', 'application_limit': 0x3800,
    'binary_bytes': len(binary), 'binary_sha256': hashlib.sha256(binary).hexdigest(),
    'note': 'Build-only artifact. No flashing or device commands have been executed.'
}
output.with_suffix('.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(f'Built {len(binary)} bytes; application range checked; hardware not verified.')
