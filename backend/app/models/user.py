from enum import Enum
from datetime import datetime
from typing import Optional, List
try:
    from pydantic import BaseModel, EmailStr, Field
except ImportError:
    class BaseModel:
        def __init__(self, **kwargs):
            for k, v in kwargs.items():
                setattr(self, k, v)
        def model_dump(self):
            return self.__dict__
        def dict(self):
            return self.__dict__
    def Field(default=None, **kwargs):
        return default
    EmailStr = str


class UserRole(str, Enum):
    """
    User roles for Al-Qulaisi Multi-Vendor E-Commerce Platform.
    Enforces strict server-side Role-Based Access Control (RBAC).
    """
    CUSTOMER = "customer"  # العميل: التسوق والطلبات والعناوين والملف الشخصي والتقييمات المسموح بها
    SELLER = "seller"      # البائع: متجره ومنتجاته وطلباته ومبيعاته وعمولاته وإعداداته
    ADMIN = "admin"        # الإدارة: العمليات الإدارية وفق الدور والصلاحيات الممنوحة


class UserStatus(str, Enum):
    """Account status managed by system and administrators."""
    ACTIVE = "active"
    SUSPENDED = "suspended"
    PENDING_APPROVAL = "pending_approval"


class AdminSubRole(str, Enum):
    """Sub-roles for administrative staff."""
    SUPER_ADMIN = "super_admin"
    OPERATIONS = "operations"
    SUPPORT = "support"


# ---------------------------------------------------------
# Pydantic Schemas for API Validation & Serialization
# ---------------------------------------------------------

class UserBase(BaseModel):
    email: EmailStr
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., min_length=8, max_length=20)
    role: UserRole = UserRole.CUSTOMER
    avatar_url: Optional[str] = None


class UserCreate(UserBase):
    password: str = Field(..., min_length=6, max_length=100)
    # If registering as seller, store name is provided
    store_name: Optional[str] = None
    store_description: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    avatar_url: Optional[str] = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6)


class UserResponse(UserBase):
    id: int
    status: UserStatus
    store_id: Optional[int] = None
    admin_subrole: Optional[AdminSubRole] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TokenPayload(BaseModel):
    sub: str  # user id as string
    email: str
    role: UserRole
    store_id: Optional[int] = None
    status: UserStatus
    exp: int


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# ---------------------------------------------------------
# User Domain Entity / Helper
# ---------------------------------------------------------

class UserDomain:
    """
    Domain entity encapsulating business security logic for a user.
    """
    def __init__(
        self,
        id: int,
        email: str,
        full_name: str,
        phone_number: str,
        hashed_password: str,
        role: UserRole,
        status: UserStatus = UserStatus.ACTIVE,
        store_id: Optional[int] = None,
        admin_subrole: Optional[AdminSubRole] = None,
        avatar_url: Optional[str] = None,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None
    ):
        self.id = id
        self.email = email
        self.full_name = full_name
        self.phone_number = phone_number
        self.hashed_password = hashed_password
        self.role = role
        self.status = status
        self.store_id = store_id
        self.admin_subrole = admin_subrole
        self.avatar_url = avatar_url
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()

    @property
    def is_active(self) -> bool:
        return self.status == UserStatus.ACTIVE

    @property
    def is_customer(self) -> bool:
        return self.role == UserRole.CUSTOMER

    @property
    def is_seller(self) -> bool:
        return self.role == UserRole.SELLER

    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN

    def can_access_store(self, target_store_id: int) -> bool:
        """
        Enforce tenant isolation:
        - Admin can access any store for oversight.
        - Seller can ONLY access their own assigned store.
        - Customer has no store management access.
        """
        if self.is_admin:
            return True
        if self.is_seller and self.store_id == target_store_id:
            return True
        return False
