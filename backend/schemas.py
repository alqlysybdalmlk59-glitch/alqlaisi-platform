from typing import Optional
from pydantic import BaseModel, Field, ConfigDict
from typing import Literal

class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="ignore")

class UserSchema(ORMModel):
    id: str
    name: str
    email: str
    role: str
    phone: str = ""
    address: str = ""
    store_id: Optional[str] = None

class ProductSchema(ORMModel):
    id: str
    title: str
    description: str = ""
    price: float
    image_url: str = ""
    vendor_id: str
    vendor_name: str
    category: str = "عام"
    is_available: bool = False
    review_status: str = "قيد المراجعة"
    admin_notes: Optional[str] = ""

class ProductCreateRequest(BaseModel):
    title: str = Field(min_length=2, max_length=180)
    description: str = Field(default="", max_length=5000)
    image_url: str = Field(default="", max_length=2048)
    category: str = Field(default="عام", min_length=1, max_length=100)
    vendor_id: Optional[str] = None  # Admin-only; seller store is derived from account.

class ProductUpdateRequest(BaseModel):
    title: str = Field(min_length=2, max_length=180)
    description: str = Field(default="", max_length=5000)
    image_url: str = Field(default="", max_length=2048)
    category: str = Field(default="عام", min_length=1, max_length=100)


class ProductApprovalRequest(BaseModel):
    sale_price: float = Field(gt=0, le=100000000, allow_inf_nan=False)
    approved: bool = True
    admin_notes: str = Field(default="", max_length=2000)

class ProductAvailabilityRequest(BaseModel):
    is_available: bool

class OrderSchema(ORMModel):
    id: str
    client_id: str
    client_name: str
    vendor_id: str
    vendor_name: str
    items_json: str
    items_price: float
    delivery_fee: float = 15.0
    total_price: float
    payment_method: str = "الدفع عند الاستلام"
    address: str
    status: str
    date: str
    delivery_agent_name: Optional[str] = None
    delivery_agent_phone: Optional[str] = None
    delivery_notes: Optional[str] = None
    delivery_assigned_at: Optional[str] = None
    delivery_delivered_at: Optional[str] = None

class DeliveryAssignmentRequest(BaseModel):
    """Admin-only assignment to the platform's manually managed delivery team."""
    delivery_agent_name: str = Field(min_length=2, max_length=120)
    delivery_agent_phone: str = Field(min_length=7, max_length=20, pattern=r"^\+?[0-9][0-9 ()-]{5,18}[0-9]$")
    delivery_notes: str = Field(default="", max_length=1000)

class CheckoutItem(BaseModel):
    product_id: str = Field(min_length=1, max_length=100)
    quantity: int = Field(ge=1, le=100)

class CheckoutRequest(BaseModel):
    recipient_name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=7, max_length=20)
    delivery_address: str = Field(min_length=5, max_length=1000)
    notes: str = Field(default="", max_length=1000)
    payment_method: str = "cash_on_delivery"
    items: list[CheckoutItem] = Field(min_length=1, max_length=100)

class OrderStatusHistorySchema(ORMModel):
    id: str
    order_id: str
    old_status: Optional[str] = None
    new_status: str
    changed_by_user_id: str
    changed_by_role: str
    note: str = ""
    created_at: str


class VendorStoreSchema(ORMModel):
    id: str
    store_name: str
    owner_name: str
    phone: str
    description: str = ""
    status: str
    admin_notes: Optional[str] = ""
    delivery_fee: float = 15.0

class AdminVendorStoreSchema(VendorStoreSchema):
    # Owner identity is exposed only in the authenticated administration route.
    owner_user_id: Optional[str] = None


class UserStatusRequest(BaseModel):
    status: Literal["active", "suspended"]


class VendorApplicationRequest(BaseModel):
    store_name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=7, max_length=20)
    description: str = Field(default="", max_length=2000)

class VendorOwnerLinkRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=100)
    verification_note: str = Field(min_length=10, max_length=1000)

class DeliveryFeeRequest(BaseModel):
    delivery_fee: float = Field(ge=0, le=100000, allow_inf_nan=False)

class SupportTicketCreateRequest(BaseModel):
    subject: str = Field(min_length=2, max_length=180)
    details: str = Field(min_length=5, max_length=5000)

class SupportTicketSchema(ORMModel):
    id: str
    user_id: str
    user_name: str
    user_role: str
    subject: str
    details: str
    status: str = "مفتوحة"
    response: Optional[str] = ""


class VendorOwnershipHistorySchema(ORMModel):
    id: str
    store_id: str
    previous_owner_user_id: Optional[str] = None
    new_owner_user_id: Optional[str] = None
    actor_user_id: str
    action: str
    verification_note: str
    created_at: str


class ProductReviewCreateRequest(BaseModel):
    product_id: str = Field(min_length=1, max_length=100)
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=1000)


class ProductReviewSchema(ORMModel):
    id: str
    product_id: str
    reviewer_name: str
    rating: int
    comment: str = ""
    created_at: str
