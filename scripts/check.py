#!/usr/bin/env python3
"""Offline verification; does not run Roblox or an executor."""
from pathlib import Path
import argparse
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--luau', default='luau')
p.add_argument('--compiler', default='luau-compile')
a = p.parse_args()
def run(args):
    subprocess.run(args, cwd=ROOT, check=True)

run([sys.executable, 'scripts/build.py', '--check'])
for test in sorted((ROOT/'tests').glob('*.test.luau')):
    run([a.luau, str(test.relative_to(ROOT))])
sources = ['main.lua'] + [str(x.relative_to(ROOT)) for x in sorted((ROOT/'src').glob('*.lua'))]
run([a.compiler, '--null', *sources])
active = '\n'.join((ROOT/x).read_text() for x in sources)
for pattern in (r'\bgetgc\s*\(', r'\bhookmetamethod\s*\(', r'\bgetrawmetatable\s*\(', r':GetDescendants\s*\('):
    assert not re.search(pattern, active), f'Forbidden expensive/global operation: {pattern}'
for pattern in (r'\b[Ll]oader\.init\s*\(', r'\b[Ll]oader\.load_client_service\s*\('):
    assert not re.search(pattern, active), f'Unexpected service initializer/getter call: {pattern}'
assert 'HttpGet' not in active, 'Unexpected secondary HTTP loader'
assert '/AA-Adaptive-Autofarm-v5/main/main.lua' in (ROOT/'loadstring.txt').read_text()
print('PASS active API constraints, unchanged loader, syntax and reproducible bundle')
