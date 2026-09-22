#!/usr/bin/env python3
"""Fast source/package checks; not a substitute for Flutter analysis or device tests."""
import ast
import re
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
for folder in ('lib', 'test'):
    for path in (root / folder).rglob('*.dart'):
        code = re.sub(r'''//[^\n]*|/\*.*?\*/|r?'(?:\\.|[^'\\])*'|r?"(?:\\.|[^"\\])*"''', '', path.read_text(), flags=re.S)
        stack = []
        for char in code:
            if char in '({[':
                stack.append(char)
            elif char in ')}]':
                assert stack and stack.pop() == '({['[')}]'.index(char)], f'Unbalanced: {path}'
        assert not stack, f'Unbalanced: {path}'
        print('Dart delimiters:', path.relative_to(root))
for path in (root / 'tools').glob('*.py'):
    ast.parse(path.read_text())
for path in (root / 'native').rglob('*.xml'):
    ET.parse(path)
manifest = ET.parse(root / 'native/src/main/AndroidManifest.xml')
ns = '{http://schemas.android.com/apk/res/android}'
assert not any(p.get(ns + 'name') == 'android.permission.INTERNET' for p in manifest.findall('uses-permission'))
assert '0.3.0+4' in (root / 'pubspec.yaml').read_text()
assert (root / 'licenses/NOTICE.txt').stat().st_size > 200000
print('Python syntax, XML, offline manifest and notices: OK')
