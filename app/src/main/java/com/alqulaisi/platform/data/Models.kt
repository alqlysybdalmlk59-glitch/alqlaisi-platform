package com.alqulaisi.platform.data

enum class UserRole {
    CLIENT, VENDOR, ADMIN
}

data class User(
    val id: String,
    val name: String,
    val email: String,
    val phone: String = "0500000000",
    val role: UserRole,
    val address: String = "صنعاء - شارع الخمسين",
    val token: String = ""
)

enum class ProductReviewStatus {
    DRAFT, PENDING_REVIEW, PUBLISHED, REJECTED
}

data class Product(
    val id: String,
    val title: String,
    val description: String,
    val price: Double,
    val imageUrl: String,
    val vendorId: String,
    val vendorName: String,
    val category: String,
    val isAvailable: Boolean = true, // متاح / غير متاح مؤقتاً (بدون كميات مخزون)
    val reviewStatus: ProductReviewStatus = ProductReviewStatus.PUBLISHED,
    val adminNotes: String = ""
)

data class CartItem(
    val product: Product,
    var quantity: Int
)

data class Order(
    val id: String,
    val clientId: String,
    val clientName: String,
    val vendorId: String,
    val vendorName: String,
    val items: List<CartItem>,
    val itemsPrice: Double,
    val deliveryFee: Double = 15.0,
    val totalPrice: Double,
    val paymentMethod: String = "الدفع عند الاستلام",
    val address: String,
    val status: String, // "بانتظار القبول", "مقبولة وقيد التجهيز", "للتوصيل", "تم الاستلام", "ملغي"
    val date: String
)

data class VendorStore(
    val id: String,
    val storeName: String,
    val ownerName: String,
    val phone: String,
    val logoUrl: String,
    val description: String,
    val status: String, // "مفعل", "قيد المراجعة", "مرفوض"
    val adminNotes: String = ""
)

data class SupportTicket(
    val id: String,
    val userId: String,
    val userName: String,
    val userRole: UserRole,
    val subject: String,
    val details: String,
    val status: String = "مفتوحة", // "مفتوحة", "قيد المعالجة", "مغلقة"
    val response: String = ""
)
