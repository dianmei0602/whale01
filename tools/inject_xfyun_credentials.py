"""Inject CI-only Xunfei credentials into a temporary app Info.plist.

The values come from GitHub Actions secrets. They are intentionally embedded in
the personal sideload IPA because the app calls Xunfei directly from the device.
The artifact must therefore remain encrypted.
"""

from pathlib import Path
import os
import plistlib
import sys


KEYS = ("XFYUN_APP_ID", "XFYUN_API_KEY", "XFYUN_API_SECRET")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: inject_xfyun_credentials.py <Info.plist>", file=sys.stderr)
        return 2

    values = {}
    for key in KEYS:
        value = os.environ.get(key, "").strip()
        if not value:
            print(f"missing required secret: {key}", file=sys.stderr)
            return 1
        values[key] = value

    path = Path(sys.argv[1])
    with path.open("rb") as source:
        info = plistlib.load(source)
    info.update(values)
    with path.open("wb") as target:
        plistlib.dump(info, target, sort_keys=False)

    print("Injected Xunfei credentials: " + ", ".join(f"{key}={len(value)}" for key, value in values.items()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
