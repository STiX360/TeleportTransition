"""Build a production archive by default, or the separate development test kit."""
import argparse
from pathlib import Path
import zipfile
import re

ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_FILES = (
    'README.md', 'CHANGELOG.md', 'PUBLISHING.md', 'TeleportTransition.omwscripts',
    'L10n/TeleportTransition/en.yaml', 'Shaders/teleport_transition.omwfx',
    'scripts/teleport_transition/player.lua',
)


def validate_version(root):
    version = (root / 'VERSION').read_text(encoding='utf-8').strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('VERSION must be X.Y.Z')
    if not (root / 'README.md').read_text(encoding='utf-8').startswith(f'# Teleport Transition {version}\n'):
        raise ValueError('README version must match VERSION')
    shader = (root / 'Shaders/teleport_transition.omwfx').read_text(encoding='utf-8')
    if re.findall(r'\bversion\s*=\s*"([^"]+)"\s*;', shader) != [version]:
        raise ValueError('Shader version must match VERSION')
    return version


def build(root=ROOT, test=False):
    version = validate_version(root)
    files = set(PRODUCTION_FILES)
    if test:
        files.update(('Test-Teleport-Transition.cmd', 'Test-Teleport-Transition-POTI-Shaders.cmd',
                      'Test-Teleport-Transition-MultiMark.cmd',
                      'Test-Teleport-Transition-Daisy.cmd', 'Test-Teleport-Transition-Kyne.cmd',
                      'TeleportTransitionDaisyTest.omwscripts', 'TeleportTransitionDaisySmoke.omwscripts',
                      'TeleportTransitionKyneTest.omwscripts',
                      'TeleportTransitionKyneSmoke.omwscripts',
                      'TeleportTransitionTest.omwscripts', 'TeleportTransitionSmoke.omwscripts',
                      'TESTING.md', 'VERSION', 'requirements-dev.txt'))
        for directory in ('scripts', 'L10n', 'tests', 'tools', 'reports'):
            files.update(p.relative_to(root).as_posix() for p in (root / directory).rglob('*')
                         if p.is_file() and '__pycache__' not in p.parts)
    prefix = 'Teleport-Transition-Test' if test else 'Teleport-Transition'
    output = root / 'dist' / f'{prefix}-{version}.zip'
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(files):
            # Stable timestamps and permissions make retries byte-identical.
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, (root / name).read_bytes())
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None or set(archive.namelist()) != files:
            raise ValueError('Archive integrity check failed')
    print(f'{output}: {len(files)} files; archive integrity verified')
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true', help='Include the disposable development test kit')
    build(test=parser.parse_args().test)
