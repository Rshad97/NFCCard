#!/usr/bin/env python3
"""Validate the installed payload's identity and actual Mach-O entitlements."""
import plistlib
from pathlib import Path
import struct
import sys


def signature(binary):
    data = Path(binary).read_bytes()
    if data[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected a thin little-endian arm64 Mach-O')
    if struct.unpack_from('<I', data, 4)[0] != 0x100000c:
        raise ValueError('Expected the device arm64 executable')
    offset = 32
    identities, entitlements = [], None
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, size = struct.unpack_from('<II', data, offset)
        if size < 8 or offset + size > len(data):
            raise ValueError('Malformed Mach-O load command')
        if command == 0x1d:  # LC_CODE_SIGNATURE
            start, length = struct.unpack_from('<II', data, offset + 8)
            blob = data[start:start + length]
            magic, total, count = struct.unpack_from('>III', blob)
            if magic != 0xfade0cc0 or total > len(blob):
                raise ValueError('Invalid code-signature superblob')
            for index in range(count):
                _, position = struct.unpack_from('>II', blob, 12 + index * 8)
                magic, length = struct.unpack_from('>II', blob, position)
                if position + length > total:
                    raise ValueError('Signature slot outside superblob')
                if magic == 0xfade0c02:  # CodeDirectory, including alternate hashes
                    ident = position + struct.unpack_from('>I', blob, position + 20)[0]
                    identities.append(blob[ident:blob.index(b'\0', ident, position + length)].decode())
                elif magic == 0xfade7171:  # Embedded XML entitlements
                    entitlements = plistlib.loads(blob[position + 8:position + length])
        offset += size
    if not identities or entitlements is None:
        raise ValueError('Executable is missing identity or signed entitlements')
    return identities, entitlements


def verify(app, expected_entitlements, source_info):
    app = Path(app)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    source = plistlib.loads(Path(source_info).read_bytes())
    expected = plistlib.loads(Path(expected_entitlements).read_bytes())
    identities, entitlements = signature(app / info['CFBundleExecutable'])
    bundle_id = info['CFBundleIdentifier']
    if bundle_id != 'com.rashad.nfccard' or any(value != bundle_id for value in identities):
        raise ValueError(f'Signing identity {identities} does not match bundle {bundle_id}')
    if entitlements != expected:
        raise ValueError(f'Unexpected signed entitlements: {entitlements}')
    if entitlements.get('com.apple.developer.nfc.readersession.formats') != ['TAG']:
        raise ValueError('NFC TAG permission missing')
    if entitlements.get('platform-application') is not True:
        raise ValueError('Jailbreak platform-application entitlement missing')
    for key in ('CFBundleShortVersionString', 'CFBundleVersion', 'NFCReaderUsageDescription',
                'com.apple.developer.nfc.readersession.iso7816.select-identifiers',
                'com.apple.developer.nfc.readersession.felica.systemcodes'):
        if not info.get(key) or info[key] != source[key]:
            raise ValueError(f'Packaged metadata does not match source: {key}')
    if not (app / 'Assets.car').is_file():
        raise ValueError('Compiled icon asset catalog missing')
    print(f'Verified NFCCard {info["CFBundleShortVersionString"]}: signing identity={bundle_id}, TAG, jailbreak platform entitlement, metadata and assets')


if __name__ == '__main__':
    verify(*sys.argv[1:])
