#!/usr/bin/env python3
"""Restore the permanent signing key from GitHub secrets; never fall back to debug."""
import base64
import binascii
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile

NAMES = ('KEYSTORE_BASE64', 'KEYSTORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS')


def esc(value):
    value = value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace(' ', '\\ ')
    result = ''
    for char in value:
        if ord(char) < 128:
            result += char
        else:
            raw = char.encode('utf-16-be')
            result += ''.join('\\u' + raw[i:i + 2].hex() for i in range(0, len(raw), 2))
    return result


def configure(root, env):
    target = root / 'android/app/release.jks'
    properties = root / 'android/key.properties'
    # A failed check must not leave an earlier signing configuration active.
    target.unlink(missing_ok=True)
    properties.unlink(missing_ok=True)
    missing = [name for name in NAMES if not env.get(name)]
    if missing:
        raise ValueError('Brak sekretow GitHub: ' + ', '.join(missing) +
                         '. Dodaj je w Settings > Secrets and variables > Actions. Podpis testowy jest wylaczony.')
    try:
        data = base64.b64decode(''.join(env['KEYSTORE_BASE64'].split()), validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError('KEYSTORE_BASE64 nie jest poprawnym Base64. Wklej cala zawartosc pliku TXT.') from error
    expected = (root / 'tools/signing_certificate.sha256').read_text().strip().lower()
    if len(expected) != 64 or any(c not in '0123456789abcdef' for c in expected):
        raise ValueError('Nieprawidlowy odcisk certyfikatu w projekcie.')
    if not target.parent.is_dir():
        raise ValueError('Najpierw uruchom tools/prepare_android.py.')
    with tempfile.TemporaryDirectory(prefix='plikownik-signing-') as folder:
        key = Path(folder) / 'release.jks'
        key.write_bytes(data)
        key.chmod(0o600)
        command = ['keytool', '-keystore', str(key), '-alias', env['KEY_ALIAS'],
                   '-storepass:env', 'KEYSTORE_PASSWORD']
        certificate = subprocess.run(command + ['-exportcert'], env=env,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if certificate.returncode:
            raise ValueError('Nie mozna odczytac klucza. Sprawdz KEYSTORE_BASE64, KEYSTORE_PASSWORD i KEY_ALIAS.')
        if hashlib.sha256(certificate.stdout).hexdigest() != expected:
            raise ValueError('To inny klucz niz staly klucz Plikownika. Uzyj przekazanej paczki prywatnego klucza.')
        request = subprocess.run(command + ['-certreq', '-keypass:env', 'KEY_PASSWORD',
                                           '-file', str(Path(folder) / 'check.csr')],
                                 env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if request.returncode:
            raise ValueError('Nie mozna uzyc klucza prywatnego. Sprawdz KEY_PASSWORD.')
    target.write_bytes(data)
    target.chmod(0o600)
    props = {'storeFile': 'release.jks', 'storePassword': env['KEYSTORE_PASSWORD'],
             'keyPassword': env['KEY_PASSWORD'], 'keyAlias': env['KEY_ALIAS']}
    try:
        properties.write_text(''.join(k + '=' + esc(v) + '\n' for k, v in props.items()), encoding='ascii')
        properties.chmod(0o600)
    except OSError:
        target.unlink(missing_ok=True)
        properties.unlink(missing_ok=True)
        raise
    print('Staly podpis Plikownika: certyfikat i klucz prywatny sprawdzone.')


if __name__ == '__main__':
    try:
        configure(Path(__file__).resolve().parents[1], os.environ.copy())
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from None
