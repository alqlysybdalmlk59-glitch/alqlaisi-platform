"""Integration tests for the customer authentication API using an isolated SQLite DB."""
import os
import unittest
from unittest.mock import patch

os.environ.setdefault("JWT_SECRET_KEY", "test-only-secret-not-for-production-0123456789")

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
import models
import database
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
        app.dependency_overrides[database.get_db] = override_get_db
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        app.dependency_overrides.clear()
        cls.engine.dispose()

    def setUp(self):
        with self.TestSession() as db:
            db.query(models.DBSupportTicket).delete()
            db.query(models.DBOrderStatusHistory).delete()
            db.query(models.DBOrder).delete()
            db.query(models.DBProduct).delete()
            db.query(models.DBVendorStore).delete()
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
        self.assertEqual(self.client.post("/api/orders/checkout", json={
            "recipient_name": "اختبار عميل", "phone": "777000000",
            "delivery_address": "صنعاء الحي الشارع", "items": [{"product_id": "p1", "quantity": 1}],
        }).status_code, 401)
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

    def _register(self, phone):
        response = self.client.post("/auth/register", json={
            "full_name": "مستخدم تجريبي", "phone": phone, "password": "SecurePass123",
        })
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()["access_token"], response.json()["user"]["id"]

    def _admin_token(self):
        with self.TestSession() as db:
            admin = db.query(models.DBUser).filter_by(id="admin_test").first()
            if admin is None:
                admin = models.DBUser(id="admin_test", name="مدير الاختبار",
                    email="admin-test@example.com", role="ADMIN", phone="700000000",
                    address="", password_hash=None, status="active")
                db.add(admin)
                db.commit()
                db.refresh(admin)
            return auth._session(admin)["access_token"]

    def _approved_store_and_product(self, seller_phone="777123470"):
        seller_token, _ = self._register(seller_phone)
        admin_token = self._admin_token()
        app_response = self.client.post("/api/vendors/register",
            headers={"Authorization": f"Bearer {seller_token}"},
            json={"store_name": "متجر اختبار", "phone": seller_phone, "description": "اختبار"})
        self.assertEqual(app_response.status_code, 201, app_response.text)
        store = app_response.json()
        approved = self.client.put(f"/api/vendors/{store['id']}/approve",
            headers={"Authorization": f"Bearer {admin_token}"})
        self.assertEqual(approved.status_code, 200, approved.text)
        created = self.client.post("/api/products/",
            headers={"Authorization": f"Bearer {seller_token}"},
            json={"title": "دفتر اختبار", "description": "وصف", "image_url": "",
                  "category": "قرطاسية", "price": 1, "vendor_id": "forged-store",
                  "review_status": "منشور", "is_available": True})
        self.assertEqual(created.status_code, 201, created.text)
        product = created.json()
        self.assertEqual(product["vendor_id"], store["id"])
        self.assertEqual(product["price"], 0)
        self.assertEqual(product["review_status"], "قيد المراجعة")
        priced = self.client.put(f"/api/products/{product['id']}/approve",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"sale_price": 175, "approved": True, "admin_notes": "سعر الإدارة"})
        self.assertEqual(priced.status_code, 200, priced.text)
        available = self.client.put(f"/api/products/{product['id']}/availability",
            headers={"Authorization": f"Bearer {seller_token}"}, json={"is_available": True})
        self.assertEqual(available.status_code, 200, available.text)
        return seller_token, admin_token, store, product["id"]

    def test_vendor_application_binds_owner_and_approval_promotes_role(self):
        customer_token, user_id = self._register("777123461")
        admin_token = self._admin_token()
        response = self.client.post("/api/vendors/register",
            headers={"Authorization": f"Bearer {customer_token}"},
            json={"store_name": "متجر عبد", "phone": "777123461", "description": "طلب"})
        self.assertEqual(response.status_code, 201, response.text)
        store = response.json()
        with self.TestSession() as db:
            saved = db.query(models.DBVendorStore).filter_by(id=store["id"]).first()
            self.assertEqual(saved.owner_user_id, user_id)
        approved = self.client.put(f"/api/vendors/{store['id']}/approve",
            headers={"Authorization": f"Bearer {admin_token}"})
        self.assertEqual(approved.status_code, 200, approved.text)
        me = self.client.get("/auth/me", headers={"Authorization": f"Bearer {customer_token}"})
        self.assertEqual(me.status_code, 200, me.text)
        self.assertEqual(me.json()["role"], "seller")
        self.assertEqual(me.json()["store_id"], store["id"])

    def test_checkout_uses_server_prices_and_fee_not_client_values(self):
        seller_token, _admin, store, product_id = self._approved_store_and_product()
        buyer_token, buyer_id = self._register("777123471")
        response = self.client.post("/api/checkout",
            headers={"Authorization": f"Bearer {buyer_token}"},
            json={"recipient_name": "عميل الطلب", "phone": "777999000",
                "delivery_address": "صنعاء، الحي، الشارع", "notes": "",
                "payment_method": "cash_on_delivery",
                "items": [{"product_id": product_id, "quantity": 2, "price": 0.5}],
                "total_price": 1, "delivery_fee": 0})
        self.assertEqual(response.status_code, 201, response.text)
        order = response.json()[0]
        self.assertEqual(order["client_id"], buyer_id)
        self.assertEqual(order["vendor_id"], store["id"])
        self.assertEqual(order["items_price"], 350)
        self.assertEqual(order["delivery_fee"], 15)
        self.assertEqual(order["total_price"], 365)
        self.assertEqual(order["payment_method"], "الدفع عند الاستلام")
        self.assertEqual(order["status"], "بانتظار القبول")
        listed = self.client.get(f"/api/orders/vendor/{store['id']}",
            headers={"Authorization": f"Bearer {seller_token}"})
        self.assertEqual(listed.status_code, 200, listed.text)
        self.assertEqual(len(listed.json()), 1)
        status_update = self.client.put(
            f"/api/orders/{order['id']}/status?status=قيد التجهيز",
            headers={"Authorization": f"Bearer {seller_token}"},
        )
        self.assertEqual(status_update.status_code, 200, status_update.text)
        history = self.client.get(
            f"/api/orders/{order['id']}/history",
            headers={"Authorization": f"Bearer {buyer_token}"},
        )
        self.assertEqual(history.status_code, 200, history.text)
        self.assertEqual(len(history.json()), 2)
        self.assertIsNone(history.json()[0]["old_status"])
        self.assertEqual(history.json()[0]["new_status"], "بانتظار القبول")
        self.assertEqual(history.json()[1]["old_status"], "بانتظار القبول")
        self.assertEqual(history.json()[1]["new_status"], "قيد التجهيز")
        other_token, _ = self._register("777123490")
        forbidden = self.client.get(
            f"/api/orders/{order['id']}/history",
            headers={"Authorization": f"Bearer {other_token}"},
        )
        self.assertEqual(forbidden.status_code, 403)

    def test_seller_cannot_access_another_store_products(self):
        seller_a, _admin, _store_a, _product_a = self._approved_store_and_product("777123472")
        seller_b_token, _ = self._register("777123473")
        admin_b = self._admin_token()
        app_b = self.client.post("/api/vendors/register",
            headers={"Authorization": f"Bearer {seller_b_token}"},
            json={"store_name": "متجر ثان", "phone": "777123473", "description": ""})
        self.assertEqual(app_b.status_code, 201, app_b.text)
        store_b = app_b.json()
        approved = self.client.put(f"/api/vendors/{store_b['id']}/approve",
            headers={"Authorization": f"Bearer {admin_b}"})
        self.assertEqual(approved.status_code, 200, approved.text)
        response = self.client.get(f"/api/products/vendor/{store_b['id']}",
            headers={"Authorization": f"Bearer {seller_a}"})
        self.assertEqual(response.status_code, 403, response.text)

    def test_admin_cannot_transfer_store_to_another_account_through_owner_link(self):
        _seller_token, admin_token, store, _product_id = self._approved_store_and_product("777123486")
        _other_token, other_user_id = self._register("777123487")
        response = self.client.put(
            f"/api/vendors/{store['id']}/owner",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"user_id": other_user_id},
        )
        self.assertEqual(response.status_code, 409, response.text)
        with self.TestSession() as db:
            current = db.query(models.DBVendorStore).filter_by(id=store["id"]).first()
            self.assertEqual(current.owner_user_id, "u_777123486")

    def test_admin_can_suspend_account_and_public_store_disappears(self):
        seller_token, seller_id = self._register("777123489")
        admin_token = self._admin_token()
        application = self.client.post(
            "/api/vendors/register",
            headers={"Authorization": f"Bearer {seller_token}"},
            json={"store_name": "متجر حساب سيوقف", "phone": "777123489", "description": ""},
        )
        self.assertEqual(application.status_code, 201, application.text)
        store = application.json()
        approval = self.client.put(
            f"/api/vendors/{store['id']}/approve",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        self.assertEqual(approval.status_code, 200, approval.text)
        before = self.client.get("/api/vendors/public")
        self.assertIn(store["id"], [item["id"] for item in before.json()])

        suspended = self.client.put(
            f"/api/users/{seller_id}/status",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"status": "suspended"},
        )
        self.assertEqual(suspended.status_code, 200, suspended.text)
        current = self.client.get(
            "/auth/me", headers={"Authorization": f"Bearer {seller_token}"}
        )
        self.assertEqual(current.status_code, 403)
        after = self.client.get("/api/vendors/public")
        self.assertNotIn(store["id"], [item["id"] for item in after.json()])

    def test_rejected_store_can_be_resubmitted_without_changing_owner_link(self):
        customer_token, user_id = self._register("777123482")
        admin_token = self._admin_token()
        first = self.client.post("/api/vendors/register",
            headers={"Authorization": f"Bearer {customer_token}"},
            json={"store_name": "متجر يحتاج مراجعة", "phone": "777123482", "description": "الأول"})
        self.assertEqual(first.status_code, 201, first.text)
        store_id = first.json()["id"]
        rejected = self.client.put(f"/api/vendors/{store_id}/reject",
            headers={"Authorization": f"Bearer {admin_token}"})
        self.assertEqual(rejected.status_code, 200, rejected.text)
        second = self.client.post("/api/vendors/register",
            headers={"Authorization": f"Bearer {customer_token}"},
            json={"store_name": "متجر بعد التعديل", "phone": "777123483", "description": "بعد معالجة الملاحظات"})
        self.assertEqual(second.status_code, 201, second.text)
        self.assertEqual(second.json()["id"], store_id)
        self.assertEqual(second.json()["status"], "قيد المراجعة")
        with self.TestSession() as db:
            saved = db.query(models.DBVendorStore).filter_by(id=store_id).first()
            self.assertEqual(saved.owner_user_id, user_id)
            self.assertEqual(saved.store_name, "متجر بعد التعديل")

    def test_google_login_creates_and_reuses_verified_subject(self):
        claims = {
            "sub": "google-subject-test-001",
            "email": "verified.customer@example.com",
            "email_verified": True,
            "name": "Google Customer",
        }
        with patch.dict(os.environ, {"GOOGLE_CLIENT_ID": "test-web-client-id"}), patch.object(
            auth.google_id_token, "verify_oauth2_token", return_value=claims
        ):
            first = self.client.post("/auth/google", json={"id_token": "mocked-google-id-token-123"})
            self.assertEqual(first.status_code, 200, first.text)
            second = self.client.post("/auth/google", json={"id_token": "mocked-google-id-token-123"})
            self.assertEqual(second.status_code, 200, second.text)

        self.assertEqual(first.json()["user"]["id"], second.json()["user"]["id"])
        self.assertEqual(first.json()["user"]["role"], "customer")
        with self.TestSession() as db:
            users = db.query(models.DBUser).filter_by(email="verified.customer@example.com").all()
            self.assertEqual(len(users), 1)
            self.assertEqual(users[0].google_subject, "google-subject-test-001")

    def test_google_login_links_existing_customer_email_once(self):
        registered = self.client.post("/auth/register", json={
            "full_name": "عميل موجود",
            "phone": "777123488",
            "email": "linked.customer@example.com",
            "password": "SecurePass123",
        })
        self.assertEqual(registered.status_code, 201, registered.text)
        original_id = registered.json()["user"]["id"]
        claims = {
            "sub": "google-subject-link-002",
            "email": "linked.customer@example.com",
            "email_verified": True,
            "name": "Google Linked Customer",
        }
        with patch.dict(os.environ, {"GOOGLE_CLIENT_ID": "test-web-client-id"}), patch.object(
            auth.google_id_token, "verify_oauth2_token", return_value=claims
        ):
            first = self.client.post("/auth/google", json={"id_token": "mocked-google-id-token-456"})
            self.assertEqual(first.status_code, 200, first.text)
            self.assertEqual(first.json()["user"]["id"], original_id)
            conflict_claims = {**claims, "sub": "different-google-subject"}
            with patch.object(auth.google_id_token, "verify_oauth2_token", return_value=conflict_claims):
                conflict = self.client.post("/auth/google", json={"id_token": "mocked-google-id-token-789"})
                self.assertEqual(conflict.status_code, 409, conflict.text)

        with self.TestSession() as db:
            account = db.query(models.DBUser).filter_by(id=original_id).first()
            self.assertEqual(account.google_subject, "google-subject-link-002")

    def test_google_login_rejects_unverified_email_and_invalid_token(self):
        unverified = {
            "sub": "google-unverified-subject",
            "email": "unverified@example.com",
            "email_verified": False,
            "name": "Unverified",
        }
        with patch.dict(os.environ, {"GOOGLE_CLIENT_ID": "test-web-client-id"}):
            with patch.object(auth.google_id_token, "verify_oauth2_token", return_value=unverified):
                response = self.client.post("/auth/google", json={"id_token": "mocked-unverified-token"})
                self.assertEqual(response.status_code, 401, response.text)
            with patch.object(auth.google_id_token, "verify_oauth2_token", side_effect=ValueError("bad signature")):
                response = self.client.post("/auth/google", json={"id_token": "mocked-invalid-signature-token-123"})
                self.assertEqual(response.status_code, 401, response.text)

    def test_google_login_cannot_turn_admin_email_into_customer_session(self):
        with self.TestSession() as db:
            db.add(models.DBUser(
                id="google_test_admin", name="مدير", email="admin.google@example.com",
                role="ADMIN", phone="700000001", address="", password_hash=None,
                status="active", google_subject=None,
            ))
            db.commit()
        claims = {
            "sub": "admin-google-subject",
            "email": "admin.google@example.com",
            "email_verified": True,
            "name": "Admin",
        }
        with patch.dict(os.environ, {"GOOGLE_CLIENT_ID": "test-web-client-id"}), patch.object(
            auth.google_id_token, "verify_oauth2_token", return_value=claims
        ):
            response = self.client.post("/auth/google", json={"id_token": "mocked-admin-google-token-123"})
        self.assertEqual(response.status_code, 403, response.text)

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
