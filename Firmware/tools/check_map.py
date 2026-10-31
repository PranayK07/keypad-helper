#!/usr/bin/env python3
"""Reject unsafe SDCC RAM reuse before emitting a firmware artifact."""
import re
import sys
from pathlib import Path
base = Path(sys.argv[1])
map_text = base.with_suffix('.map').read_text()
mem_text = base.with_suffix('.mem').read_text()
def require(ok, message):
    if not ok:
        raise SystemExit(message)
require('__gptrput' not in map_text and '__gptrget' not in map_text,
        'Generic pointer runtime helpers are forbidden across main/USB ISR; use KPH_XDATA.')
params = re.findall(r'^\s+([0-9A-F]{8})\s+(_kph_\w+_PARM_\d+)\s', map_text, re.M)
require(len(params) >= 10, 'Missing core parameter symbols; inspect this linker format.')
require(len({address for address, _ in params}) == len(params),
        'Core function parameters overlap: compile every source with --nooverlay.')
stack = re.search(r'with (\d+) bytes available', mem_text)
require(stack is not None and int(stack.group(1)) >= 128,
        'Less than 128 bytes remain for main-loop and interrupt stack.')
print('Embedded memory: distinct core parameters, no generic-pointer helpers, sufficient stack.')
