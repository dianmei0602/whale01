import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ReleaseIdentityTests(unittest.TestCase):
    def test_release_identity_check_passes(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "release_identity.py"), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_codemagic_does_not_override_project_identity(self):
        content = (ROOT / "codemagic.yaml").read_text(encoding="utf-8")

        self.assertNotIn("MARKETING_VERSION:", content)
        self.assertNotIn("CURRENT_PROJECT_VERSION=", content)


if __name__ == "__main__":
    unittest.main()
