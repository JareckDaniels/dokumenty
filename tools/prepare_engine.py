#!/usr/bin/env python3
"""Fetch the pinned ARM64 engine; never include users' documents in the project."""
import argparse
import hashlib
import shutil
import urllib.request
from pathlib import Path, PurePosixPath
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://f-droid.org/repo/org.documentfoundation.libreoffice_131.apk'
SHA256 = '751ac3836890b79a56801bf6d9a2788cda3761ab5131a4f0b6abfbad822bb475'


def verified(path):
    if not path.is_file():
        return False
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() == SHA256


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path, help='Optional local copy of the exact pinned engine APK')
    args = parser.parse_args()
    apk = args.apk or ROOT / '.engine-cache' / 'libreoffice-26.2.6.3-arm64.apk'
    if not verified(apk):
        if args.apk:
            raise SystemExit('Engine checksum mismatch. Refusing to use this file.')
        apk.parent.mkdir(parents=True, exist_ok=True)
        temp = apk.with_suffix('.part')
        request = urllib.request.Request(URL, headers={'User-Agent': 'Dokumenty-build/0.1'})
        with urllib.request.urlopen(request, timeout=180) as response, temp.open('wb') as out:
            shutil.copyfileobj(response, out)
        if not verified(temp):
            temp.unlink(missing_ok=True)
            raise SystemExit('Downloaded engine checksum mismatch; build stopped.')
        temp.replace(apk)
    target = ROOT / 'android/app/src/main'
    if not (target / 'AndroidManifest.xml').is_file():
        raise SystemExit('Run tools/prepare_android.py first.')
    # All generated assets/JNI files belong to this script. A rebuild cannot mix engine versions.
    for folder in ('assets', 'jniLibs'):
        shutil.rmtree(target / folder, ignore_errors=True)
    copied = 0
    with ZipFile(apk) as source:
        for entry in source.infolist():
            name = entry.filename
            if entry.is_dir():
                continue
            if name.startswith('assets/') and not name.startswith('assets/dexopt/'):
                relative = PurePosixPath(name)
            elif name.startswith('lib/arm64-v8a/'):
                relative = PurePosixPath('jniLibs') / PurePosixPath(name).relative_to('lib')
            else:
                continue
            if relative.is_absolute() or '..' in relative.parts:
                raise SystemExit('Unsafe archive path')
            dest = target.joinpath(*relative.parts)
            dest.parent.mkdir(parents=True, exist_ok=True)
            with source.open(entry) as stream, dest.open('wb') as out:
                shutil.copyfileobj(stream, out)
            copied += 1
    for required in ('jniLibs/arm64-v8a/liblo-native-code.so', 'assets/program/fundamentalrc',
                     'assets/unpack/program/sofficerc', 'assets/unpack/program/offapi.rdb'):
        if not (target / required).is_file():
            raise SystemExit('Missing engine component: ' + required)
    notices = target / 'assets/third_party'
    notices.mkdir(parents=True)
    shutil.copyfile(ROOT / 'licenses/NOTICE.txt', notices / 'NOTICE.txt')
    print(f'Prepared LibreOffice 26.2.6.3 ARM64: {copied} files, SHA-256 verified.')


if __name__ == '__main__':
    main()
