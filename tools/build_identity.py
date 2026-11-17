"""Write a non-secret source identity file before XcodeGen builds.

The app verifies its own provenance at runtime, and verify_ipa.py checks that the
IPA actually contains this file, so a stale or mixed-up build cannot be shipped
silently.

Usage:
    python3 scripts/build_identity.py
    python3 scripts/build_identity.py --project ios/project.yml \
        --contract ios/ChineseChronicles/Resources/content-manifest.v1.json \
        --output ios/ChineseChronicles/Resources/build-identity.json
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--project", default="ios/project.yml")
parser.add_argument("--contract", default="ios/ChineseChronicles/Resources/content-manifest.v1.json")
parser.add_argument("--output", default="ios/ChineseChronicles/Resources/build-identity.json")
parser.add_argument("--distribution-env", default="APP_DISTRIBUTION")
parser.add_argument("--default-distribution", default="personal")
args = parser.parse_args()

root = args.root.resolve()
config = (root / args.project).read_text(encoding="utf-8")
contract_path = root / args.contract
contract = json.loads(contract_path.read_text(encoding="utf-8-sig"))

version = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', config)
build = re.search(r'CURRENT_PROJECT_VERSION:\s*"([^"]+)"', config)
if not version or not build:
    raise SystemExit("MARKETING_VERSION / CURRENT_PROJECT_VERSION not found in " + args.project)

try:
    git_sha = os.environ.get("GITHUB_SHA") or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True
    ).strip()
except (subprocess.CalledProcessError, FileNotFoundError):
    git_sha = "local-uncommitted"

identity = {
    "gitSHA": git_sha,
    "builtAt": datetime.now(timezone.utc).isoformat(),
    "version": version.group(1),
    "sourceBuild": build.group(1),
    "contentVersion": contract["contentVersion"],
    "dynastyCount": contract["dynastyCount"],
    "eventCount": contract["eventCount"],
    "sourceCount": contract["sourceCount"],
    "personCount": contract["personCount"],
    "placeCount": contract["placeCount"],
    "topicCount": contract["topicCount"],
    "manifestSHA256": hashlib.sha256(contract_path.read_bytes()).hexdigest(),
    "distribution": os.environ.get(args.distribution_env, args.default_distribution),
    "runId": os.environ.get("GITHUB_RUN_ID", "local"),
}

path = root / args.output
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(identity, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(identity, ensure_ascii=False))
