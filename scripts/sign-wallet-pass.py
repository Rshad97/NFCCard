#!/usr/bin/env python3
"""Offline DISPLAY pass signer. Never uploads snapshots or signing keys.

Requires a real Apple Pass Type ID certificate/private key and its WWDR
intermediate. A self-signed test certificate will NOT be accepted by Wallet.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile


MAX_SOURCE_BYTES = 64 * 1024
SOURCE_KEYS = {
    "formatVersion", "serialNumber", "organizationName", "description", "logoText",
    "backgroundColor", "foregroundColor", "labelColor", "generic",
}
GROUP_LIMITS = {"headerFields": 3, "primaryFields": 1, "secondaryFields": 4,
                "auxiliaryFields": 4, "backFields": 12}


def validate_source(source):
    if not isinstance(source, dict) or set(source) != SOURCE_KEYS:
        raise ValueError("Expected an NFCCard display source; NFC, barcode, URL and other extra fields are not accepted.")
    if type(source["formatVersion"]) is not int or source["formatVersion"] != 1:
        raise ValueError("Unsupported pass source version.")
    for key in SOURCE_KEYS - {"formatVersion", "generic"}:
        value = source[key]
        if not isinstance(value, str) or not value or len(value) > 1024:
            raise ValueError("Invalid pass source string: " + key)
    if not re.fullmatch(r"nfccard-[0-9a-fA-F-]{36}", source["serialNumber"]):
        raise ValueError("Expected a snapshot UUID pass serial number.")
    groups = source["generic"]
    if not isinstance(groups, dict) or set(groups) != set(GROUP_LIMITS):
        raise ValueError("Invalid generic pass layout.")
    keys = set()
    for group, limit in GROUP_LIMITS.items():
        fields = groups[group]
        if not isinstance(fields, list) or len(fields) > limit:
            raise ValueError("Too many fields: " + group)
        for field in fields:
            if not isinstance(field, dict) or set(field) != {"key", "label", "value"}:
                raise ValueError("Invalid display field.")
            if any(not isinstance(v, str) or len(v) > 2048 for v in field.values()):
                raise ValueError("Invalid display field text.")
            if not field["key"] or field["key"] in keys:
                raise ValueError("Duplicate or empty field key.")
            keys.add(field["key"])
    if not any(f["key"] == "purpose" and f["value"] == "DISPLAY ONLY" for f in groups["headerFields"]):
        raise ValueError("The DISPLAY ONLY marker is required.")
    if not any(f["key"] == "limitation" and "does not emulate" in f["value"] for f in groups["backFields"]):
        raise ValueError("The access-credential limitation is required.")
    return source


def run_openssl(*args):
    result = subprocess.run(["openssl", *map(str, args)], capture_output=True, timeout=45)
    if result.returncode:
        # Do not echo key data, passphrases or raw command output into logs.
        raise ValueError("OpenSSL " + str(args[0]) + " failed. Check certificate, key, password and intermediate.")
    return result.stdout


def check_identity(certificate, private_key, wwdr, pass_type_id, team_id, password_source):
    if not re.fullmatch(r"pass\.[A-Za-z0-9.-]+", pass_type_id):
        raise ValueError("Use your registered pass.* identifier.")
    if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise ValueError("Use your 10-character Apple Team ID.")
    subject = run_openssl("x509", "-in", certificate, "-noout", "-subject", "-nameopt", "RFC2253").decode()
    fields = dict(re.findall(r"(?:^|,)(UID|OU)=([^,\r\n]+)", subject.removeprefix("subject=").strip()))
    if fields.get("UID") != pass_type_id or fields.get("OU") != team_id:
        raise ValueError("Pass Type ID / Team ID do not match the supplied signing certificate.")
    run_openssl("x509", "-in", certificate, "-noout", "-checkend", "0")
    run_openssl("verify", "-partial_chain", "-CAfile", wwdr, certificate)
    certificate_key = run_openssl("x509", "-in", certificate, "-pubkey", "-noout")
    signing_key = run_openssl("pkey", "-in", private_key, "-passin", password_source, "-pubout")
    if certificate_key.strip() != signing_key.strip():
        raise ValueError("The private key does not match the certificate.")


def icon_assets(icon, directory):
    """Resize the existing approved artwork, without changing the app icon."""
    assets = {}
    for scale in (1, 2, 3):
        name = "icon" + (f"@{scale}x" if scale > 1 else "") + ".png"
        target = directory / name
        size = 29 * scale
        if shutil.which("sips"):
            subprocess.run(["sips", "-s", "format", "png", "-z", str(size), str(size),
                            str(icon), "--out", str(target)], check=True, capture_output=True, timeout=30)
        else:
            try:
                from PIL import Image
            except ImportError as error:
                raise ValueError("Use macOS (sips), or install Pillow to resize the pass icons.") from error
            with Image.open(icon) as image:
                image.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS).save(target)
        assets[name] = target.read_bytes()
    return assets


def build_bundle(source, assets, certificate, private_key, wwdr, password_source, directory):
    files = {"pass.json": json.dumps(source, ensure_ascii=False, sort_keys=True).encode("utf-8"), **assets}
    manifest = {name: hashlib.sha1(data).hexdigest() for name, data in files.items()}
    files["manifest.json"] = json.dumps(manifest, sort_keys=True).encode("utf-8")
    manifest_path = directory / "manifest.json"
    signature_path = directory / "signature"
    manifest_path.write_bytes(files["manifest.json"])
    run_openssl("cms", "-sign", "-binary", "-md", "sha256", "-in", manifest_path,
                "-signer", certificate, "-inkey", private_key, "-passin", password_source,
                "-certfile", wwdr, "-outform", "DER", "-out", signature_path)
    files["signature"] = signature_path.read_bytes()
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for name, data in files.items():
            package.writestr(name, data)
    return buffer.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--certificate", type=Path, required=True, help="Apple Pass Type ID certificate (PEM)")
    parser.add_argument("--private-key", type=Path, required=True, help="Matching private key (PEM); stays on this computer")
    parser.add_argument("--wwdr", type=Path, required=True, help="Matching Apple WWDR intermediate (PEM)")
    parser.add_argument("--pass-type-id", required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--icon", type=Path, default=Path(__file__).resolve().parents[1] / "design/AppIconSource.png")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.output.suffix.lower() != ".pkpass":
            raise ValueError("Output must use the .pkpass extension.")
        if args.output.exists():
            raise ValueError("Output already exists; choose a new filename.")
        with args.source.open("rb") as file:
            data = file.read(MAX_SOURCE_BYTES + 1)
        if len(data) > MAX_SOURCE_BYTES:
            raise ValueError("Pass source is too large.")
        source = validate_source(json.loads(data))
        password_source = "env:NFCCARD_WALLET_KEY_PASSWORD" if "NFCCARD_WALLET_KEY_PASSWORD" in os.environ else "pass:"
        check_identity(args.certificate, args.private_key, args.wwdr, args.pass_type_id, args.team_id, password_source)
        source = {**source, "passTypeIdentifier": args.pass_type_id, "teamIdentifier": args.team_id}
        with tempfile.TemporaryDirectory(prefix="nfccard-pass-") as temporary:
            directory = Path(temporary)
            assets = icon_assets(args.icon, directory)
            package = build_bundle(source, assets, args.certificate, args.private_key, args.wwdr, password_source, directory)
        # Do not overwrite any user file, even if one appears after validation.
        descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "wb") as file:
            file.write(package)
        print("Signed display package created: " + str(args.output))
        print("Apple Wallet still validates the Apple certificate chain. This is not NFC emulation or an ACID credential.")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, "Could not create Wallet pass: " + str(error) + "\n")


if __name__ == "__main__":
    main()
