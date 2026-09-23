#!/usr/bin/env python3
"""Signing gate tests with a throwaway key; never loads production secrets."""
import base64
import contextlib
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import secrets
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('signing', project / 'tools/signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)

with tempfile.TemporaryDirectory(prefix='signing-test-') as folder:
    root = Path(folder)
    (root / 'tools').mkdir()
    (root / 'android/app').mkdir(parents=True)
    env = os.environ.copy()
    for name in signing.NAMES:
        env.pop(name, None)
    env['KEYSTORE_PASSWORD'] = secrets.token_urlsafe(20)
    env['KEY_PASSWORD'] = secrets.token_urlsafe(20)
    env['KEY_ALIAS'] = 'fixture'
    key = root / 'fixture.jks'
    subprocess.run(['keytool', '-genkeypair', '-noprompt', '-storetype', 'JKS', '-keystore', str(key),
                    '-alias', 'fixture', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '1',
                    '-dname', 'CN=Signing test only', '-storepass:env', 'KEYSTORE_PASSWORD',
                    '-keypass:env', 'KEY_PASSWORD'], env=env, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    cert = subprocess.run(['keytool', '-exportcert', '-keystore', str(key), '-alias', 'fixture',
                           '-storepass:env', 'KEYSTORE_PASSWORD'], env=env, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    expected = hashlib.sha256(cert).hexdigest()
    (root / 'tools/signing_certificate.sha256').write_text(expected)
    env['KEYSTORE_BASE64'] = base64.b64encode(key.read_bytes()).decode()

    def reject(values):
        (root / 'android/key.properties').write_text('stale signing configuration')
        (root / 'android/app/release.jks').write_bytes(b'stale key')
        try:
            signing.configure(root, values)
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid signing configuration accepted')
        assert not (root / 'android/key.properties').exists()
        assert not (root / 'android/app/release.jks').exists()

    reject({k: v for k, v in env.items() if k not in signing.NAMES})
    reject({k: v for k, v in env.items() if k != 'KEY_ALIAS'})
    for name, value in [('KEYSTORE_BASE64', '@@bad@@'), ('KEYSTORE_PASSWORD', 'incorrect-password'),
                        ('KEY_PASSWORD', 'incorrect-password'), ('KEY_ALIAS', 'absent')]:
        reject({**env, name: value})
    (root / 'tools/signing_certificate.sha256').write_text('0' * 64)
    reject(env)
    (root / 'tools/signing_certificate.sha256').write_text(expected)
    with contextlib.redirect_stdout(io.StringIO()):
        signing.configure(root, {**env, 'KEYSTORE_BASE64': '\n' + env['KEYSTORE_BASE64'] + '\n'})
    assert (root / 'android/app/release.jks').read_bytes() == key.read_bytes()
    properties = (root / 'android/key.properties').read_text()
    assert 'keyAlias=fixture\n' in properties
    assert 'keyPassword=' + env['KEY_PASSWORD'] + '\n' in properties
    assert 'else signingConfigs.getByName("debug")' not in (project / 'szablony/app_build.gradle.kts').read_text()
print('Signing: missing secrets, malformed data, wrong passwords/alias/certificate, stale cleanup and valid key OK')
