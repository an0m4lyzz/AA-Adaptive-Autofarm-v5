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
entry_fixture = ROOT/'tests/_entry_snapshot.luau'
entry_source = (ROOT/'src/entry.lua').read_text()
entry_source = re.sub(r"require\('\./([a-z]+)'\)", r'imports.\1', entry_source)
entry_fixture.write_text('return function(imports, globals)\nlocal function run()\n' + entry_source +
    '\nend\nsetfenv(run,globals)\nreturn run()\nend\n')
try:
    for test in sorted((ROOT/'tests').glob('*.test.luau')):
        run([a.luau, str(test.relative_to(ROOT))])
finally:
    entry_fixture.unlink(missing_ok=True)
sources = ['main.lua'] + [str(x.relative_to(ROOT)) for x in sorted((ROOT/'src').glob('*.lua'))]
run([a.compiler, '--null', *sources])
active = '\n'.join((ROOT/x).read_text() for x in sources)
for pattern in (r'\bgetgc\s*\(', r'\bhookmetamethod\s*\(', r'\bgetrawmetatable\s*\(', r':GetDescendants\s*\('):
    assert not re.search(pattern, active), f'Forbidden expensive/global operation: {pattern}'
for pattern in (r'\b[Ll]oader\.init\s*\(', r'\b[Ll]oader\.load_client_service\s*\(',
                r'\b[Ll]oader\.load_core_service\s*\(', r'\b[Ll]oader\.load_data\s*\('):
    assert not re.search(pattern, active), f'Unexpected service initializer/getter call: {pattern}'
entry_url = 'https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua'
session = (ROOT/'src/session.lua').read_text()
assert session.count('HttpGet') == 1 and ("game:HttpGet('" + entry_url + "')") in session, 'Unexpected continuation loader'
for path in sources:
    if path not in ('main.lua','src/session.lua'):
        assert 'HttpGet' not in (ROOT/path).read_text(), 'Unexpected secondary HTTP loader'
assert 'dungeon_start' not in (ROOT/'src/roblox.lua').read_text(), 'Unexpected automatic key-consuming endpoint'
assert '/AA-Adaptive-Autofarm-v5/main/main.lua' in (ROOT/'loadstring.txt').read_text()
print('PASS active API constraints, unchanged loader, syntax and reproducible bundle')
