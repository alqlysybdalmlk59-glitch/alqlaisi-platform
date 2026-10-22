"""Integration tests for the customer authentication API using an isolated SQLite DB."""
import os
import unittest

os.environ.setdefault("JWT_SECRET_KEY", "test-only-secret-not-for-production-0123456789")

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
import models
from routers import auth, dependencies


class TestAuthAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        cls.TestSession = sessionmaker(autocommit=False, autoflush=False, bind=cls.engine)
        models.Base.metadata.create_all(bind=cls.engine)

        def override_get_db():
            db = cls.TestSession()
            try:
                yield db
            finally:
                db.close()

        app.dependency_overrides[auth.get_db] = override_get_db
        app.dependency_overrides[dependencies.get_db] = override_get_db
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        app.dependency_overrides.clear()
        cls.engine.dispose()

    def setUp(self):
        with self.TestSession() as db:
            db.query(models.DBUser).delete()
            db.commit()

    def test_register_login_and_me(self):
        response = self.client.post("/auth/register", json={
            "full_name": "عميل تجريبي",
            "phone": "777123456",
            "password": "SecurePass123",
        })
        self.assertEqual(response.status_code, 201, response.text)
        body = response.json()
        self.assertEqual(body["user"]["role"], "customer")
        self.assertTrue(body["access_token"])
        self.assertIsNone(body["user"]["email"])

        login = self.client.post("/auth/login", json={
            "phone": "777123456",
            "password": "SecurePass123",
        })
        self.assertEqual(login.status_code, 200, login.text)
        token = login.json()["access_token"]

        me = self.client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(me.status_code, 200, me.text)
        self.assertEqual(me.json()["phone"], "777123456")

    def test_business_routes_require_authentication(self):
        self.assertEqual(self.client.get("/api/vendors/").status_code, 401)
        self.assertEqual(self.client.post("/api/orders/checkout", json=[]).status_code, 401)
        self.assertEqual(self.client.get("/api/support/").status_code, 401)

    def test_customer_cannot_access_admin_vendor_list(self):
        response = self.client.post("/auth/register", json={
            "full_name": "عميل تجريبي",
            "phone": "777123460",
            "password": "SecurePass123",
        })
        self.assertEqual(response.status_code, 201, response.text)
        token = response.json()["access_token"]
        result = self.client.get("/api/vendors/", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(result.status_code, 403, result.text)

    def test_google_login_fails_closed_when_not_configured(self):
        import os
        previous = os.environ.pop("GOOGLE_CLIENT_ID", None)
        try:
            response = self.client.post(
                "/auth/google",
                json={"id_token": "not-a-real-google-token-long-enough"},
            )
            self.assertEqual(response.status_code, 503)
        finally:
            if previous is not None:
                os.environ["GOOGLE_CLIENT_ID"] = previous

    def test_wrong_password_is_rejected(self):
        self.client.post("/auth/register", json={
            "full_name": "عميل تجريبي",
            "phone": "777123457",
            "password": "SecurePass123",
        })
        response = self.client.post("/auth/login", json={
            "phone": "777123457",
            "password": "WrongPass123",
        })
        self.assertEqual(response.status_code, 401)

    def test_duplicate_phone_is_rejected(self):
        payload = {"full_name": "عميل تجريبي", "phone": "777123458", "password": "SecurePass123"}
        self.assertEqual(self.client.post("/auth/register", json=payload).status_code, 201)
        response = self.client.post("/auth/register", json=payload)
        self.assertEqual(response.status_code, 409)

    def test_invalid_or_missing_token_is_rejected(self):
        self.assertEqual(self.client.get("/auth/me").status_code, 401)
        invalid = self.client.get("/auth/me", headers={"Authorization": "Bearer invalid.token.value"})
        self.assertEqual(invalid.status_code, 401)

    def test_inactive_account_cannot_login_or_use_existing_token(self):
        response = self.client.post("/auth/register", json={
            "full_name": "عميل تجريبي",
            "phone": "777123459",
            "password": "SecurePass123",
        })
        self.assertEqual(response.status_code, 201, response.text)
        token = response.json()["access_token"]
        user_id = response.json()["user"]["id"]
        with self.TestSession() as db:
            user = db.query(models.DBUser).filter(models.DBUser.id == user_id).first()
            user.status = "suspended"
            db.commit()

        login = self.client.post("/auth/login", json={
            "phone": "777123459",
            "password": "SecurePass123",
        })
        self.assertEqual(login.status_code, 403)
        me = self.client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(me.status_code, 403)


if __name__ == "__main__":
    unittest.main()
