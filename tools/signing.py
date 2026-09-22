#!/usr/bin/env python3
"""Restore optional signing credentials from environment variables, never from shell text."""
import base64
import os
from pathlib import Path

names = ('KEYSTORE_BASE64', 'KEYSTORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS')
values = {name: os.environ.get(name, '') for name in names}
root = Path(__file__).resolve().parents[1]
if any(values.values()) and not all(values.values()):
    raise SystemExit('Set all four signing secrets or remove all four for a test build.')
if all(values.values()):
    (root / 'android/app/release.jks').write_bytes(base64.b64decode(values['KEYSTORE_BASE64'], validate=True))
    def esc(s):
        s = s.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace(' ', '\\ ')
        result = ''
        for char in s:
            if ord(char) < 128:
                result += char
            else:
                raw = char.encode('utf-16-be')
                result += ''.join('\\u' + raw[i:i + 2].hex() for i in range(0, len(raw), 2))
        return result
    props = {'storeFile': 'release.jks', 'storePassword': values['KEYSTORE_PASSWORD'],
             'keyPassword': values['KEY_PASSWORD'], 'keyAlias': values['KEY_ALIAS']}
    (root / 'android/key.properties').write_text(''.join(k + '=' + esc(v) + '\n' for k, v in props.items()), encoding='ascii')
    print('Release signing configured.')
else:
    print('TEST BUILD: temporary debug signature. Set four secrets before relying on in-place updates.')
