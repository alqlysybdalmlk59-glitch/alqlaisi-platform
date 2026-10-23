"""Regression tests for the local-only .env bootstrap used by run_backend.bat."""
from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from backend import setup_dev


class TestDevelopmentSetup(unittest.TestCase):
    def _run_with_paths(self, env_file: Path, example_file: Path) -> tuple[int, str]:
        stdout = io.StringIO()
        with (
            patch.object(setup_dev, "ENV_FILE", env_file),
            patch.object(setup_dev, "EXAMPLE_FILE", example_file),
            contextlib.redirect_stdout(stdout),
        ):
            code = setup_dev.main()
        return code, stdout.getvalue()

    def test_first_run_generates_random_secret_and_keeps_sqlite_development_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env_file = root / ".env"
            example_file = root / ".env.example"
            example_file.write_text(
                "APP_ENV=development\nDATABASE_URL=\nJWT_SECRET_KEY=REPLACE_WITH_A_LONG_RANDOM_SECRET\n",
                encoding="utf-8",
            )

            code, output = self._run_with_paths(env_file, example_file)

            self.assertEqual(code, 0)
            self.assertTrue(env_file.exists())
            lines = env_file.read_text(encoding="utf-8").splitlines()
            settings = {
                line.split("=", 1)[0]: line.split("=", 1)[1]
                for line in lines
                if "=" in line and not line.lstrip().startswith("#")
            }
            secret = settings["JWT_SECRET_KEY"]
            self.assertGreaterEqual(len(secret), 48)
            self.assertNotIn("replace", secret.lower())
            self.assertEqual(settings["APP_ENV"], "development")
            self.assertEqual(settings["DATABASE_URL"], "")
            self.assertNotIn(secret, output)

    def test_existing_secure_development_secret_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env_file = root / ".env"
            example_file = root / ".env.example"
            secret = "secure-development-secret-" + ("x" * 40)
            before = f"APP_ENV=development\nDATABASE_URL=\nJWT_SECRET_KEY={secret}\nCUSTOM_SETTING=kept\n"
            env_file.write_text(before, encoding="utf-8")
            example_file.write_text("APP_ENV=development\n", encoding="utf-8")

            code, _ = self._run_with_paths(env_file, example_file)

            self.assertEqual(code, 0)
            self.assertEqual(env_file.read_text(encoding="utf-8"), before)

    def test_production_env_is_never_modified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env_file = root / ".env"
            example_file = root / ".env.example"
            before = "APP_ENV=production\nJWT_SECRET_KEY=do-not-touch\n"
            env_file.write_text(before, encoding="utf-8")
            example_file.write_text("APP_ENV=development\nJWT_SECRET_KEY=example\n", encoding="utf-8")

            code, output = self._run_with_paths(env_file, example_file)

            self.assertEqual(code, 2)
            self.assertEqual(env_file.read_text(encoding="utf-8"), before)
            self.assertIn("Refusing to modify", output)


if __name__ == "__main__":
    unittest.main()
