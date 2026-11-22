"""Keep the source version, CI build settings and release notes in sync."""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "2.1.0"
EXPECTED_BUILD_BASE = "210"
EXPECTED_EXYTE_VERSION = "3.3.7"

VERSION_PATTERN = re.compile(r'MARKETING_VERSION:\s*"([^"]+)"')
BUILD_PATTERN = re.compile(r'CURRENT_PROJECT_VERSION:\s*"([^"]+)"')
EXYTE_PATTERN = re.compile(
    r"ExyteChat:\s*\n\s+url:\s*https://github\.com/exyte/Chat\s*\n"
    r"\s+exactVersion:\s*([^\s]+)"
)


def _read(root: Path, relative_path: str) -> str:
    path = root / relative_path
    if not path.is_file():
        raise FileNotFoundError(relative_path)
    return path.read_text(encoding="utf-8")


def load_project_identity(root: Path = ROOT) -> dict[str, str]:
    project = _read(root, "ios/project.yml")
    version_match = VERSION_PATTERN.search(project)
    build_match = BUILD_PATTERN.search(project)
    exyte_match = EXYTE_PATTERN.search(project)
    if not version_match or not build_match or not exyte_match:
        raise ValueError(
            "ios/project.yml must contain MARKETING_VERSION, "
            "CURRENT_PROJECT_VERSION and a pinned ExyteChat version"
        )
    return {
        "version": version_match.group(1),
        "build_base": build_match.group(1),
        "exyte_version": exyte_match.group(1).strip('"'),
    }


def check_repository(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    try:
        identity = load_project_identity(root)
    except (FileNotFoundError, ValueError) as error:
        return [str(error)]

    if identity["version"] != EXPECTED_VERSION:
        errors.append(
            f"ios/project.yml version is {identity['version']}, "
            f"expected {EXPECTED_VERSION}"
        )
    if identity["build_base"] != EXPECTED_BUILD_BASE:
        errors.append(
            f"ios/project.yml build base is {identity['build_base']}, "
            f"expected {EXPECTED_BUILD_BASE}"
        )
    if identity["exyte_version"] != EXPECTED_EXYTE_VERSION:
        errors.append(
            f"ExyteChat is {identity['exyte_version']}, "
            f"expected {EXPECTED_EXYTE_VERSION}"
        )

    workflow_dir = root / ".github" / "workflows"
    for path in sorted(workflow_dir.glob("*.yml")):
        workflow = path.read_text(encoding="utf-8")
        if "xcodebuild" not in workflow:
            continue
        relative = path.relative_to(root).as_posix()
        if "release_identity.py --check --github-env" not in workflow:
            errors.append(
                f"{relative} must validate release identity before xcodebuild"
            )
        if re.search(r"MARKETING_VERSION\s*=\s*['\"]?\d", workflow):
            errors.append(f"{relative} hardcodes MARKETING_VERSION")
        if re.search(r'CURRENT_PROJECT_VERSION="\d+\.[^"]*"', workflow):
            errors.append(f"{relative} hardcodes the CI build base")

    codemagic = _read(root, "codemagic.yaml")
    if "release_identity.py --check" not in codemagic:
        errors.append("codemagic.yaml must validate release identity")
    if "MARKETING_VERSION:" in codemagic or "CURRENT_PROJECT_VERSION=" in codemagic:
        errors.append("codemagic.yaml must use the project version without overrides")

    required_fragments = {
        "README.md": [
            f"最新版本：`{EXPECTED_VERSION} ({EXPECTED_BUILD_BASE}.1)`",
            "构建源码：`fdcd72b`",
            "docs/logs/2026-11-22-v2.1.0-life-agent-p0.md",
        ],
        "CHANGELOG.md": [
            f"## {EXPECTED_VERSION} — 2026-11-22",
            f"ExyteChat {EXPECTED_EXYTE_VERSION}",
            "讯飞语音入口",
            "侧载构建",
        ],
        "docs/README.md": [
            "2026-11-22-v2.1.0-life-agent-p0.md",
            "superpowers/plans/2026-11-22-whale-3.0-p0-closure.md",
        ],
        "00_执行看板.md": [
            f"版本 `{EXPECTED_VERSION} ({EXPECTED_BUILD_BASE}.1)`",
            "Life Agent 侧载构建",
        ],
        "docs/logs/2026-11-22-v2.1.0-life-agent-p0.md": [
            f"版本：`{EXPECTED_VERSION} ({EXPECTED_BUILD_BASE}.1)`",
            "ExyteChat `3.3.7`",
            "构建源码：`fdcd72b3a0346cfc102ca05d99ee77eb44dc8c18`",
            "尚未完成",
        ],
    }
    for relative, fragments in required_fragments.items():
        try:
            content = _read(root, relative)
        except FileNotFoundError:
            errors.append(f"{relative} is missing")
            continue
        for fragment in fragments:
            if fragment not in content:
                errors.append(f"{relative} is missing: {fragment}")

    readme = _read(root, "README.md")
    if "最新版本：`2.0.4" in readme:
        errors.append("README.md still presents 2.0.4 as the current version")

    return errors


def write_github_env(path: Path, identity: dict[str, str]) -> None:
    with path.open("a", encoding="utf-8") as stream:
        stream.write(f"WHALE_MARKETING_VERSION={identity['version']}\n")
        stream.write(f"WHALE_BUILD_BASE={identity['build_base']}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--github-env", action="store_true")
    args = parser.parse_args()

    errors = check_repository()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    identity = load_project_identity()
    if args.github_env:
        github_env = os.environ.get("GITHUB_ENV")
        if not github_env:
            print("ERROR: GITHUB_ENV is not set")
            return 1
        write_github_env(Path(github_env), identity)

    print(
        "release identity OK: "
        f"{identity['version']} ({identity['build_base']}.x), "
        f"ExyteChat {identity['exyte_version']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
