#!/usr/bin/env python3
"""Test source validation and package signing, not Apple Wallet trust/hardware."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


spec = importlib.util.spec_from_file_location("signer", Path(__file__).with_name("sign-wallet-pass.py"))
signer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signer)


def source_fixture():
    return {
        "formatVersion": 1,
        "serialNumber": "nfccard-11111111-2222-3333-4444-555555555555",
        "organizationName": "NFCCard", "description": "NFC card information — display only",
        "logoText": "NFCCard", "backgroundColor": "rgb(15, 18, 24)",
        "foregroundColor": "rgb(255, 255, 255)", "labelColor": "rgb(0, 145, 255)",
        "generic": {
            "headerFields": [{"key": "purpose", "label": "PURPOSE", "value": "DISPLAY ONLY"}],
            "primaryFields": [{"key": "name", "label": "CARD", "value": "Test Card"}],
            "secondaryFields": [], "auxiliaryFields": [],
            "backFields": [{"key": "limitation", "label": "NOT AN ACCESS CREDENTIAL",
                            "value": "This pass does not emulate the scanned card."}],
        },
    }


class SourceTests(unittest.TestCase):
    def test_valid_source(self):
        self.assertEqual(signer.validate_source(source_fixture()), source_fixture())

    def test_rejects_nfc_and_remote_service_fields(self):
        for key in ("nfc", "barcodes", "barcode", "authenticationToken", "webServiceURL"):
            source = source_fixture()
            source[key] = "not allowed"
            with self.assertRaises(ValueError):
                signer.validate_source(source)

    def test_requires_display_marker_and_limitation(self):
        for group in ("headerFields", "backFields"):
            source = source_fixture()
            source["generic"][group] = []
            with self.assertRaises(ValueError):
                signer.validate_source(source)

    def test_rejects_duplicate_field_keys_and_invalid_version(self):
        source = source_fixture()
        source["generic"]["secondaryFields"] = copy.deepcopy(source["generic"]["primaryFields"])
        with self.assertRaises(ValueError):
            signer.validate_source(source)
        source = source_fixture()
        source["formatVersion"] = True
        with self.assertRaises(ValueError):
            signer.validate_source(source)


class SigningTests(unittest.TestCase):
    def test_cms_signature_manifest_and_no_private_material_in_package(self):
        # Deliberately self-signed: verifies CMS packaging only, NOT Wallet acceptance.
        with tempfile.TemporaryDirectory(prefix="nfccard-sign-test-") as temporary:
            root = Path(temporary)
            key, cert = root / "test.key", root / "test.pem"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                            "-subj", "/CN=NFCCard Test Only/UID=pass.com.example.test/OU=TESTTEAM01",
                            "-keyout", str(key), "-out", str(cert)], check=True, capture_output=True)
            signer.check_identity(cert, key, cert, "pass.com.example.test", "TESTTEAM01", "pass:")
            with self.assertRaises(ValueError):
                signer.check_identity(cert, key, cert, "pass.com.example.wrong", "TESTTEAM01", "pass:")
            source = {**source_fixture(), "passTypeIdentifier": "pass.com.example.test", "teamIdentifier": "TESTTEAM01"}
            assets = signer.icon_assets(Path(__file__).resolve().parents[1] / "design/AppIconSource.png", root)
            # The same self-signed cert cannot appear twice in CMS. Use a distinct
            # test intermediate; the test still does not represent Apple trust.
            intermediate = root / "intermediate.pem"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                            "-subj", "/CN=NFCCard Test Intermediate", "-keyout", str(root / "ca.key"),
                            "-out", str(intermediate)], check=True, capture_output=True)
            result = signer.build_bundle(source, assets, cert, key, intermediate, "pass:", root)
            with zipfile.ZipFile(io.BytesIO(result)) as archive:
                self.assertEqual(set(archive.namelist()), {"pass.json", "icon.png", "icon@2x.png", "icon@3x.png", "manifest.json", "signature"})
                manifest_bytes = archive.read("manifest.json")
                manifest = json.loads(manifest_bytes)
                self.assertEqual(set(manifest), {"pass.json", "icon.png", "icon@2x.png", "icon@3x.png"})
                for name, digest in manifest.items():
                    self.assertEqual(digest, hashlib.sha1(archive.read(name)).hexdigest())
                self.assertEqual(json.loads(archive.read("pass.json")), source)
                self.assertNotIn(b"PRIVATE KEY", result)
                (root / "signature").write_bytes(archive.read("signature"))
                (root / "manifest.json").write_bytes(manifest_bytes)
            signer.run_openssl("cms", "-verify", "-binary", "-inform", "DER", "-in", root / "signature",
                               "-content", root / "manifest.json", "-CAfile", cert, "-purpose", "any", "-out", root / "verified")
            self.assertEqual((root / "verified").read_bytes(), manifest_bytes)
            (root / "manifest.json").write_bytes(b"tampered")
            with self.assertRaises(ValueError):
                signer.run_openssl("cms", "-verify", "-binary", "-inform", "DER", "-in", root / "signature",
                                   "-content", root / "manifest.json", "-CAfile", cert, "-purpose", "any", "-out", root / "verified")


if __name__ == "__main__":
    unittest.main()
