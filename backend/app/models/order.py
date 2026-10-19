from enum import Enum
from datetime import datetime
from typing import List, Optional
try:
    from pydantic import BaseModel, Field
except ImportError:
    class BaseModel:
        def __init__(self, **kwargs):
            for k, v in kwargs.items():
                setattr(self, k, v)
    def Field(default=None, **kwargs):
        return default


class OrderStatus(str, Enum):
    PENDING_CONFIRMATION = "pending_confirmation"  # بانتظار التأكيد
    PROCESSING = "processing"                      # مقبول أو قيد التجهيز
    OUT_FOR_DELIVERY = "out_for_delivery"          # خرج للتوصيل (توصيل داخلي)
    DELIVERED = "delivered"                        # تم التسليم
    CANCELLED = "cancelled"                        # ملغي


class PaymentMethod(str, Enum):
    CASH_ON_DELIVERY = "cash_on_delivery"          # الدفع عند الاستلام (الأساس الأولي المعتمد)


class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(1, ge=1)


class OrderItemResponse(BaseModel):
    id: int
    product_id: int
    product_name: str
    unit_price: float
    quantity: int
    total_price: float


class SingleStoreOrderCreate(BaseModel):
    store_id: int
    items: List[OrderItemCreate] = Field(..., min_items=1)
    delivery_fee: float = Field(default=15.0, ge=0)


class MultiVendorCheckoutRequest(BaseModel):
    """
    Checkout request supporting multiple vendors.
    The system splits this request into independent orders per seller,
    calculating individual delivery fees.
    """
    delivery_address: str = Field(..., min_length=5, max_length=255)
    customer_phone: str = Field(..., min_length=8, max_length=20)
    customer_notes: Optional[str] = None
    payment_method: PaymentMethod = PaymentMethod.CASH_ON_DELIVERY
    vendor_orders: List[SingleStoreOrderCreate] = Field(..., min_items=1)


class OrderResponse(BaseModel):
    id: int
    order_number: str
    customer_id: int
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    store_id: int
    store_name: Optional[str] = None
    items: List[OrderItemResponse]
    subtotal: float
    delivery_fee: float
    total: float
    platform_commission: float
    status: OrderStatus
    delivery_address: str
    payment_method: PaymentMethod
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class OrderStatusUpdate(BaseModel):
    status: OrderStatus
    internal_delivery_notes: Optional[str] = None


class ProductReviewCreate(BaseModel):
    product_id: int
    order_id: int
    rating: int = Field(..., ge=1, le=5)
    comment: str = Field(..., min_length=3, max_length=500)


class ProductReviewResponse(BaseModel):
    id: int
    product_id: int
    customer_id: int
    customer_name: str
    rating: int
    comment: str
    created_at: datetime
