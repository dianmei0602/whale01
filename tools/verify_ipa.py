"""Verify IPA identity and distribution boundaries without printing secret values.

Usage:
    python scripts/verify_ipa.py build/App-Sideload.ipa --sha "$GITHUB_SHA"
    python scripts/verify_ipa.py build/App.ipa --sha abc123 --public \
        --credential-keys APIKey,APIToken,SecretKey

Writes <ipa>.manifest.json next to the IPA and prints the same JSON.
Exit code is non-zero on any mismatch, so it is safe to gate a workflow on it.
"""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("ipa", type=Path)
parser.add_argument("--sha", required=True, help="Expected source commit SHA")
parser.add_argument("--public", action="store_true",
                    help="Refuse any build with an embedded long-lived credential")
parser.add_argument("--identity", default="build-identity.json",
                    help="Identity file name inside the .app bundle")
parser.add_argument("--manifest", default="content-manifest.v1.json",
                    help="Content manifest name inside the .app bundle")
parser.add_argument("--credential-keys",
                    default="DeepSeekAPIKey,APIToken,APIKey,API_SECRET",
                    help="Comma-separated plist keys that must stay empty")
args = parser.parse_args()

blocked_keys = [key.strip() for key in args.credential_keys.split(",") if key.strip()]

with zipfile.ZipFile(args.ipa) as archive:
    roots = [name for name in archive.namelist()
             if name.count("/") == 2 and name.startswith("Payload/") and name.endswith(".app/Info.plist")]
    if len(roots) != 1:
        raise SystemExit("Expected exactly one application bundle, found %d" % len(roots))

    app = roots[0].rsplit("/", 1)[0]
    info = plistlib.loads(archive.read(roots[0]))

    identity_name = app + "/" + args.identity
    manifest_name = app + "/" + args.manifest
    if identity_name not in archive.namelist():
        raise SystemExit("Missing " + args.identity + " in the bundle; run build_identity.py before archiving")
    identity = json.loads(archive.read(identity_name))
    manifest = archive.read(manifest_name)

    def present(value):
        # Empty, whitespace, or an unexpanded build setting all count as absent.
        return isinstance(value, str) and bool(value.strip()) and not value.startswith("$(")

    embedded = any(present(info.get(key)) for key in blocked_keys)

    assert identity["gitSHA"] == args.sha, "IPA source SHA mismatch"
    assert info["CFBundleShortVersionString"] == identity["version"], "IPA version mismatch"
    assert hashlib.sha256(manifest).hexdigest() == identity["manifestSHA256"], "Content manifest mismatch"
    decoded_manifest = json.loads(manifest)
    assert decoded_manifest["dynastyCount"] == identity["dynastyCount"], "Dynasty count mismatch"
    assert decoded_manifest["eventCount"] == identity["eventCount"], "Event count mismatch"
    assert decoded_manifest["sourceCount"] == identity["sourceCount"], "Source count mismatch"
    assert decoded_manifest["personCount"] == identity["personCount"], "Person count mismatch"
    assert decoded_manifest["placeCount"] == identity["placeCount"], "Place count mismatch"
    assert decoded_manifest["topicCount"] == identity["topicCount"], "Topic count mismatch"

    if (args.public or identity.get("distribution") == "public") and embedded:
        raise SystemExit("Public distribution blocked: embedded long-lived credential detected")

    result = {
        **identity,
        "bundleId": info["CFBundleIdentifier"],
        "installedBuild": info["CFBundleVersion"],
        "ipaSHA256": hashlib.sha256(args.ipa.read_bytes()).hexdigest(),
        "bytes": args.ipa.stat().st_size,
        "embeddedCredentialPresent": embedded,
        "publicDistributionAllowed": not embedded,
    }
    output = args.ipa.with_suffix(".manifest.json")
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
