package com.example.model

enum class UserRole(val labelAr: String, val labelEn: String) {
    CUSTOMER("عميل", "Customer"),
    SELLER("بائع", "Seller"),
    ADMIN("إدارة المنصة", "Admin")
}

enum class UserStatus(val labelAr: String) {
    ACTIVE("نشط"),
    SUSPENDED("موقوف"),
    PENDING_APPROVAL("قيد المراجعة")
}

data class User(
    val id: Int,
    val email: String,
    val fullName: String,
    val phone: String,
    val role: UserRole,
    val status: UserStatus = UserStatus.ACTIVE,
    val storeId: Int? = null,
    val token: String = ""
)

enum class StoreStatus(val labelAr: String) {
    PENDING_REVIEW("قيد المراجعة"),
    APPROVED("معتمد"),
    REJECTED("مرفوض"),
    SUSPENDED("موقوف مؤقتاً")
}

data class Store(
    val id: Int,
    val ownerId: Int,
    val name: String,
    val description: String,
    val phone: String,
    val status: StoreStatus,
    val rejectionReason: String? = null,
    val commissionRate: Double = 0.10,
    val salesTotal: Double = 0.0
)

enum class ProductReviewStatus(val labelAr: String) {
    DRAFT("مسودة"),
    PENDING_REVIEW("قيد المراجعة"),
    APPROVED("مقبول ومنشور"),
    REJECTED("مرفوض مع ملاحظات")
}

data class Product(
    val id: Int,
    val storeId: Int,
    val storeName: String,
    val name: String,
    val description: String,
    val price: Double,
    val category: String,
    val isAvailable: Boolean = true, // Manual availability toggle - NO stock count
    val reviewStatus: ProductReviewStatus = ProductReviewStatus.APPROVED,
    val rejectionReason: String? = null,
    val rating: Double = 4.8,
    val reviewCount: Int = 12
)

enum class OrderStatus(val labelAr: String) {
    PENDING_CONFIRMATION("بانتظار التأكيد"),
    PROCESSING("قيد التجهيز"),
    OUT_FOR_DELIVERY("خرج للتوصيل"),
    DELIVERED("تم التسليم"),
    CANCELLED("ملغي")
}

data class OrderItem(
    val productId: Int,
    val productName: String,
    val unitPrice: Double,
    val quantity: Int
)

data class VendorOrder(
    val id: Int,
    val orderNumber: String,
    val customerId: Int,
    val customerName: String,
    val customerPhone: String,
    val storeId: Int,
    val storeName: String,
    val items: List<OrderItem>,
    val subtotal: Double,
    val deliveryFee: Double,
    val total: Double,
    val platformCommission: Double,
    val status: OrderStatus,
    val deliveryAddress: String,
    val createdAt: String
)

data class ProductReview(
    val id: Int,
    val productId: Int,
    val customerId: Int,
    val customerName: String,
    val rating: Int,
    val comment: String,
    val date: String
)

data class SecurityAuditEntry(
    val id: Long,
    val timestamp: String,
    val action: String,
    val role: String,
    val path: String,
    val statusCode: Int,
    val isAllowed: Boolean,
    val detailsAr: String,
    val clientIp: String = "192.168.1.42"
)

data class PenetrationTestResult(
    val testName: String,
    val attemptedRole: UserRole,
    val targetEndpoint: String,
    val expectedStatus: Int,
    val actualStatus: Int,
    val passed: Boolean,
    val reasonAr: String
)
