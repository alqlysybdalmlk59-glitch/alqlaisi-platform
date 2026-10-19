"""
Security & Role-Based Access Control Verification Tests for Al-Qulaisi Platform.
Uses standard Python library (no external dependencies required) to verify core security rules.
"""

import unittest
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app.models.user import UserRole, UserStatus, UserDomain
from backend.app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token
)
from backend.app.middleware.access_control import (
    verify_seller_store_ownership,
    verify_order_access,
    verify_review_eligibility,
    HTTPException
)


class TestAlQulaisiSecurityRules(unittest.TestCase):

    def setUp(self):
        # Sample test users
        self.customer = UserDomain(
            id=101,
            email="customer@example.com",
            full_name="أحمد العمري",
            phone_number="967771234567",
            hashed_password=hash_password("Pass123!"),
            role=UserRole.CUSTOMER,
            status=UserStatus.ACTIVE
        )

        self.seller_a = UserDomain(
            id=201,
            email="seller_a@example.com",
            full_name="متجر الإلكترونيات",
            phone_number="967772223344",
            hashed_password=hash_password("SellerPass1!"),
            role=UserRole.SELLER,
            status=UserStatus.ACTIVE,
            store_id=501
        )

        self.seller_b = UserDomain(
            id=202,
            email="seller_b@example.com",
            full_name="متجر الملابس",
            phone_number="967773334455",
            hashed_password=hash_password("SellerPass2!"),
            role=UserRole.SELLER,
            status=UserStatus.ACTIVE,
            store_id=502
        )

        self.admin = UserDomain(
            id=999,
            email="admin@alqulaisi.com",
            full_name="مدير النظام",
            phone_number="967770000000",
            hashed_password=hash_password("AdminSecure!"),
            role=UserRole.ADMIN,
            status=UserStatus.ACTIVE
        )

    def test_password_hashing_and_verification(self):
        """Test PBKDF2 hashing security and rejection of wrong passwords."""
        plain = "SuperSecret123!"
        hashed = hash_password(plain)
        self.assertTrue(verify_password(plain, hashed))
        self.assertFalse(verify_password("WrongPassword", hashed))

    def test_jwt_token_claims_and_signature(self):
        """Test JWT token encoding, claim extraction, and expiration/tampering detection."""
        token = create_access_token({
            "sub": str(self.seller_a.id),
            "email": self.seller_a.email,
            "role": self.seller_a.role.value,
            "store_id": self.seller_a.store_id,
            "status": self.seller_a.status.value
        })
        decoded = decode_access_token(token)
        self.assertEqual(decoded["sub"], str(self.seller_a.id))
        self.assertEqual(decoded["role"], "seller")
        self.assertEqual(decoded["store_id"], 501)

        # Tampered token must fail
        tampered = token[:-4] + "AAAA"
        with self.assertRaises(ValueError):
            decode_access_token(tampered)

    def test_seller_cannot_access_another_seller_store(self):
        """
        Rule 2.2: لا يجوز للبائع تعديل بيانات متجر آخر أو الاطلاع على طلباته الخاصة.
        """
        # Seller A accessing their own store: MUST SUCCEED
        user_dict_a = {"sub": "201", "role": "seller", "store_id": 501}
        self.assertTrue(verify_seller_store_ownership(501, user_dict_a))

        # Seller A attempting to access Seller B's store (502): MUST RAISE 403
        with self.assertRaises(HTTPException) as ctx:
            verify_seller_store_ownership(502, user_dict_a)
        self.assertEqual(ctx.exception.status_code, 403)

        # Admin accessing any store: MUST SUCCEED
        admin_dict = {"sub": "999", "role": "admin", "store_id": None}
        self.assertTrue(verify_seller_store_ownership(502, admin_dict))

    def test_customer_cannot_manage_store(self):
        """Customer attempting store management MUST RAISE 403."""
        customer_dict = {"sub": "101", "role": "customer", "store_id": None}
        with self.assertRaises(HTTPException) as ctx:
            verify_seller_store_ownership(501, customer_dict)
        self.assertEqual(ctx.exception.status_code, 403)

    def test_order_privacy_isolation(self):
        """
        Test that customers only see their orders, sellers only see their store's orders,
        and unauthorized parties are blocked.
        """
        order_customer_id = 101
        order_store_id = 501

        # Customer viewing their own order
        customer_dict = {"sub": "101", "role": "customer"}
        self.assertTrue(verify_order_access(order_customer_id, order_store_id, customer_dict))

        # Different customer (102) viewing customer 101's order -> MUST FAIL
        other_customer = {"sub": "102", "role": "customer"}
        with self.assertRaises(HTTPException):
            verify_order_access(order_customer_id, order_store_id, other_customer)

        # Seller A (Store 501) viewing order belonging to Store 501 -> MUST SUCCEED
        seller_a_dict = {"sub": "201", "role": "seller", "store_id": 501}
        self.assertTrue(verify_order_access(order_customer_id, order_store_id, seller_a_dict))

        # Seller B (Store 502) viewing order belonging to Store 501 -> MUST FAIL
        seller_b_dict = {"sub": "202", "role": "seller", "store_id": 502}
        with self.assertRaises(HTTPException):
            verify_order_access(order_customer_id, order_store_id, seller_b_dict)

    def test_review_eligibility_only_after_delivered(self):
        """
        Rule 3.8:
        يستطيع العميل تقييم المنتج بعد استلام الطلب واكتماله (تم التسليم).
        لا يسمح النظام بتقييم منتج لمجرد فتحه أو إضافته إلى العربة أو وهو قيد التجهيز.
        """
        customer_dict = {"sub": "101", "role": "customer"}

        # Attempt to review while order is still in "processing" -> MUST FAIL
        with self.assertRaises(HTTPException) as ctx:
            verify_review_eligibility(
                order_status="processing",
                order_customer_id=101,
                current_user=customer_dict
            )
        self.assertEqual(ctx.exception.status_code, 400)

        # Attempt to review when order is "delivered" -> MUST SUCCEED
        self.assertTrue(
            verify_review_eligibility(
                order_status="delivered",
                order_customer_id=101,
                current_user=customer_dict
            )
        )


if __name__ == "__main__":
    unittest.main()
