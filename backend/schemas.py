from pydantic import BaseModel
from typing import List, Optional

class UserSchema(BaseModel):
    id: str
    name: str
    email: str
    role: str
    phone: str
    address: str

    class Config:
        from_attributes = True

class ProductSchema(BaseModel):
    id: str
    title: str
    description: str
    price: float
    image_url: str
    vendor_id: str
    vendor_name: str
    category: str
    is_available: bool = True
    review_status: str = "منشور"
    admin_notes: Optional[str] = ""

    class Config:
        from_attributes = True

class OrderSchema(BaseModel):
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

    class Config:
        from_attributes = True

class VendorStoreSchema(BaseModel):
    id: str
    store_name: str
    owner_name: str
    phone: str
    description: str
    status: str
    admin_notes: Optional[str] = ""

    class Config:
        from_attributes = True

class SupportTicketSchema(BaseModel):
    id: str
    user_id: str
    user_name: str
    user_role: str
    subject: str
    details: str
    status: str = "مفتوحة"
    response: Optional[str] = ""

    class Config:
        from_attributes = True
