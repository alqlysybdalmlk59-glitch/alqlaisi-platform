"""Security tests for fail-closed production configuration."""
import os
import unittest
from unittest.mock import patch

from backend.app.core import runtime_config


class TestProductionRuntimeConfig(unittest.TestCase):
    def setUp(self):
        self.good_env = {
            "APP_ENV": "production",
            "DATABASE_URL": "postgresql+psycopg://alqlaisi:password@db.example.net:5432/alqlaisi?sslmode=require",
            "JWT_SECRET_KEY": "a" * 64,
            "GOOGLE_CLIENT_ID": "1234567890-testclient.apps.googleusercontent.com",
            "ALLOWED_HOSTS": "api.example.net",
            "FORWARDED_ALLOW_IPS": "127.0.0.1",
        }

    def test_valid_production_settings_are_accepted(self):
        with patch.dict(os.environ, self.good_env, clear=False), \
             patch.object(runtime_config, "IS_PRODUCTION", True), \
             patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
             patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
            runtime_config.validate_production_configuration()

    def test_production_rejects_sqlite_database(self):
        env = {**self.good_env, "DATABASE_URL": "sqlite:///unsafe.db"}
        with patch.dict(os.environ, env, clear=False), \
             patch.object(runtime_config, "IS_PRODUCTION", True), \
             patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
             patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
            with self.assertRaisesRegex(RuntimeError, "PostgreSQL"):
                runtime_config.validate_production_configuration()

    def test_production_rejects_database_without_tls(self):
        env = {**self.good_env, "DATABASE_URL": "postgresql+psycopg://user:pass@db.example.net:5432/platform"}
        with patch.dict(os.environ, env, clear=False), \
             patch.object(runtime_config, "IS_PRODUCTION", True), \
             patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
             patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
            with self.assertRaisesRegex(RuntimeError, "TLS"):
                runtime_config.validate_production_configuration()

    def test_production_rejects_missing_google_client_id(self):
        env = {**self.good_env, "GOOGLE_CLIENT_ID": ""}
        with patch.dict(os.environ, env, clear=False), \
             patch.object(runtime_config, "IS_PRODUCTION", True), \
             patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
             patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
            with self.assertRaisesRegex(RuntimeError, "Google Web OAuth client ID"):
                runtime_config.validate_production_configuration()

    def test_production_rejects_placeholder_google_client_ids(self):
        for client_id in ("", "YOUR_WEB_CLIENT_ID", "example.apps.googleusercontent.com"):
            env = {**self.good_env, "GOOGLE_CLIENT_ID": client_id}
            with patch.dict(os.environ, env, clear=False), \
                 patch.object(runtime_config, "IS_PRODUCTION", True), \
                 patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
                 patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
                with self.assertRaisesRegex(RuntimeError, "Google Web OAuth client ID"):
                    runtime_config.validate_production_configuration()

    def test_production_rejects_missing_explicit_allowed_hosts(self):
        env = {**self.good_env, "ALLOWED_HOSTS": ""}
        with (
            patch.dict(os.environ, env, clear=False),
            patch.object(runtime_config, "IS_PRODUCTION", True),
            patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]),
            patch.object(runtime_config, "ALLOWED_HOSTS", ["localhost", "127.0.0.1"]),
        ):
            with self.assertRaisesRegex(RuntimeError, "ALLOWED_HOSTS.*explicitly"):
                runtime_config.validate_production_configuration()

    def test_production_rejects_wildcard_cors_and_hosts(self):
        with patch.dict(os.environ, self.good_env, clear=False), \
             patch.object(runtime_config, "IS_PRODUCTION", True), \
             patch.object(runtime_config, "CORS_ORIGINS", ["*"]), \
             patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
            with self.assertRaisesRegex(RuntimeError, "wildcard"):
                runtime_config.validate_production_configuration()

        with patch.dict(os.environ, self.good_env, clear=False), \
             patch.object(runtime_config, "IS_PRODUCTION", True), \
             patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
             patch.object(runtime_config, "ALLOWED_HOSTS", ["*"]):
            with self.assertRaisesRegex(RuntimeError, "ALLOWED_HOSTS"):
                runtime_config.validate_production_configuration()

    def test_production_requires_explicit_trusted_proxy_ips(self):
        for proxy_value in ("", "*", "127.0.0.1,*"):
            env = {**self.good_env, "FORWARDED_ALLOW_IPS": proxy_value}
            with patch.dict(os.environ, env, clear=False), \
                 patch.object(runtime_config, "IS_PRODUCTION", True), \
                 patch.object(runtime_config, "CORS_ORIGINS", ["https://admin.example.net"]), \
                 patch.object(runtime_config, "ALLOWED_HOSTS", ["api.example.net"]):
                with self.assertRaisesRegex(RuntimeError, "FORWARDED_ALLOW_IPS"):
                    runtime_config.validate_production_configuration()

    def test_development_does_not_require_production_secrets(self):
        with patch.object(runtime_config, "IS_PRODUCTION", False):
            runtime_config.validate_production_configuration()


if __name__ == "__main__":
    unittest.main()
