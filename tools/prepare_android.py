#!/usr/bin/env python3
"""Generate Android with the pinned Flutter SDK, then apply versioned custom sources."""
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skeleton = root / '.skeleton'
shutil.rmtree(skeleton, ignore_errors=True)
subprocess.run(['flutter', 'create', '--no-pub', '--platforms=android', '--org',
                'pl.jarekgadzina', '--project-name', 'dokumenty', str(skeleton)], check=True)
android = root / 'android'
shutil.rmtree(android, ignore_errors=True)
shutil.copytree(skeleton / 'android', android)
# The generated Kotlin MainActivity would duplicate our Java MainActivity.
shutil.rmtree(android / 'app/src/main/kotlin', ignore_errors=True)
shutil.copytree(root / 'native/src/main', android / 'app/src/main', dirs_exist_ok=True)
shutil.copyfile(root / 'szablony/app_build.gradle.kts', android / 'app/build.gradle.kts')
(android / 'app/build.gradle').unlink(missing_ok=True)
shutil.rmtree(skeleton)
print('Android generated; custom manifest, Java bridge and icon restored.')
