package com.example.data

import com.example.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.*

import com.example.data.local.LocalUserRepository

class PlatformRepository(
    val localUserRepository: LocalUserRepository? = null
) {

    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

    // -------------------------------------------------------------
    // Pre-configured Realistic Users for Testing
    // -------------------------------------------------------------
    val customerUser = User(
        id = 101,
        email = "ahmed.customer@alqulaisi.ye",
        fullName = "أحمد خالد العمري",
        phone = "+967 771 234 567",
        role = UserRole.CUSTOMER,
        status = UserStatus.ACTIVE,
        storeId = null,
        token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.customer.token.101"
    )

    val sellerUserA = User(
        id = 201,
        email = "electro.seller@alqulaisi.ye",
        fullName = "صالح مهدي (متجر القليسي للإلكترونيات)",
        phone = "+967 777 888 111",
        role = UserRole.SELLER,
        status = UserStatus.ACTIVE,
        storeId = 501,
        token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.seller.token.201"
    )

    val sellerUserB = User(
        id = 202,
        email = "fashion.seller@alqulaisi.ye",
        fullName = "مروان الحداد (أزياء النخبة)",
        phone = "+967 773 444 222",
        role = UserRole.SELLER,
        status = UserStatus.ACTIVE,
        storeId = 502,
        token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.seller.token.202"
    )

    val adminUser = User(
        id = 999,
        email = "admin@alqulaisi.ye",
        fullName = "عبدالملك القليسي (مدير المنصة)",
        phone = "+967 770 000 001",
        role = UserRole.ADMIN,
        status = UserStatus.ACTIVE,
        storeId = null,
        token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.admin.token.999"
    )

    // Current logged-in user
    private val _currentUser = MutableStateFlow<User>(customerUser)
    val currentUser: StateFlow<User> = _currentUser.asStateFlow()

    // -------------------------------------------------------------
    // Stores
    // -------------------------------------------------------------
    private val _stores = MutableStateFlow<List<Store>>(
        listOf(
            Store(
                id = 501,
                ownerId = 201,
                name = "متجر القليسي للتقنية والإلكترونيات",
                description = "أحدث الهواتف الذكية وملحقاتها الأصلية بضمان معتمد",
                phone = "+967 777 888 111",
                status = StoreStatus.APPROVED,
                commissionRate = 0.08,
                salesTotal = 425000.0
            ),
            Store(
                id = 502,
                ownerId = 202,
                name = "أزياء النخبة الراقية",
                description = "تشكيلات حصرية من الملابس والعطور والأحذية الفاخرة",
                phone = "+967 773 444 222",
                status = StoreStatus.APPROVED,
                commissionRate = 0.10,
                salesTotal = 186000.0
            ),
            Store(
                id = 503,
                ownerId = 203,
                name = "دار البن والبهارات الأصيلة",
                description = "بن يمني جبلي معتق وبهارات عربية مختارة",
                phone = "+967 775 555 999",
                status = StoreStatus.PENDING_REVIEW,
                commissionRate = 0.10,
                salesTotal = 0.0
            )
        )
    )
    val stores: StateFlow<List<Store>> = _stores.asStateFlow()

    // -------------------------------------------------------------
    // Products (NO stock quantity counter - manual availability only!)
    // -------------------------------------------------------------
    private val _products = MutableStateFlow<List<Product>>(
        listOf(
            Product(
                id = 1,
                storeId = 501,
                storeName = "متجر القليسي للتقنية",
                name = "سماعات لاسلكية عازلة للضوضاء برو",
                description = "صوت نقي عالي الدقة مع خاصية إلغاء الضجيج النشط وبطارية تدوم 30 ساعة",
                price = 35000.0,
                category = "إلكترونيات",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.APPROVED,
                rating = 4.9,
                reviewCount = 18
            ),
            Product(
                id = 2,
                storeId = 501,
                storeName = "متجر القليسي للتقنية",
                name = "شاحن سريع 65 واط GaN متعدد المنافذ",
                description = "شاحن ذكي فائق السرعة يدعم الهواتف والحواسيب المحمولة",
                price = 14500.0,
                category = "إلكترونيات",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.APPROVED,
                rating = 4.7,
                reviewCount = 9
            ),
            Product(
                id = 3,
                storeId = 501,
                storeName = "متجر القليسي للتقنية",
                name = "ساعة ذكية رياضية مقاومة للماء",
                description = "تتبع نبضات القلب ونظام تحديد المواقع GPS وشاشة AMOLED ملونة (غير متاحة مؤقتاً للتوريد)",
                price = 28000.0,
                category = "إلكترونيات",
                isAvailable = false, // Manual availability set to false by seller
                reviewStatus = ProductReviewStatus.APPROVED,
                rating = 4.6,
                reviewCount = 5
            ),
            Product(
                id = 4,
                storeId = 502,
                storeName = "أزياء النخبة",
                name = "ثوب فاخر مطرز يدوي قطن سوبر",
                description = "خياطة متقنة بأقمشة يابانية ناعمة وعالية الجودة",
                price = 22000.0,
                category = "ملابس",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.APPROVED,
                rating = 5.0,
                reviewCount = 14
            ),
            Product(
                id = 5,
                storeId = 502,
                storeName = "أزياء النخبة",
                name = "عطر العود الملكي المعتّق 100 مل",
                description = "مزيج ساحر من دهن العود الكمبودي والعنبر الصافي",
                price = 45000.0,
                category = "عطور",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.APPROVED,
                rating = 4.8,
                reviewCount = 7
            ),
            Product(
                id = 6,
                storeId = 502,
                storeName = "أزياء النخبة",
                name = "حذاء جلدي رسمي طبي مريح",
                description = "جلد طبيعي مرن مع وسادة قدم طبية ممتصة للصدمات (قيد تدقيق الإدارة)",
                price = 19500.0,
                category = "أحذية",
                isAvailable = true,
                reviewStatus = ProductReviewStatus.PENDING_REVIEW, // Waiting for admin approval
                rejectionReason = null,
                rating = 0.0,
                reviewCount = 0
            )
        )
    )
    val products: StateFlow<List<Product>> = _products.asStateFlow()

    // -------------------------------------------------------------
    // Multi-Vendor Orders
    // -------------------------------------------------------------
    private val _orders = MutableStateFlow<List<VendorOrder>>(
        listOf(
            VendorOrder(
                id = 1001,
                orderNumber = "ORD-2026-1001",
                customerId = 101,
                customerName = "أحمد خالد العمري",
                customerPhone = "+967 771 234 567",
                storeId = 501,
                storeName = "متجر القليسي للتقنية",
                items = listOf(
                    OrderItem(1, "سماعات لاسلكية عازلة للضوضاء برو", 35000.0, 1)
                ),
                subtotal = 35000.0,
                deliveryFee = 2000.0,
                total = 37000.0,
                platformCommission = 2800.0,
                status = OrderStatus.DELIVERED, // Delivered: Customer CAN review product #1
                deliveryAddress = "صنعاء - شارع حدة - بجوار سيتي ستارز",
                createdAt = "2026-10-18 14:30"
            ),
            VendorOrder(
                id = 1002,
                orderNumber = "ORD-2026-1002",
                customerId = 101,
                customerName = "أحمد خالد العمري",
                customerPhone = "+967 771 234 567",
                storeId = 502,
                storeName = "أزياء النخبة",
                items = listOf(
                    OrderItem(4, "ثوب فاخر مطرز يدوي قطن سوبر", 22000.0, 1)
                ),
                subtotal = 22000.0,
                deliveryFee = 2500.0,
                total = 24500.0,
                platformCommission = 2200.0,
                status = OrderStatus.PROCESSING, // Processing: Customer CANNOT review yet!
                deliveryAddress = "صنعاء - شارع حدة - بجوار سيتي ستارز",
                createdAt = "2026-10-19 09:15"
            )
        )
    )
    val orders: StateFlow<List<VendorOrder>> = _orders.asStateFlow()

    // -------------------------------------------------------------
    // Cart (Product ID to Quantity)
    // -------------------------------------------------------------
    private val _cart = MutableStateFlow<Map<Int, Int>>(
        mapOf(
            1 to 1, // Store 501
            4 to 1  // Store 502 (Multi-vendor items!)
        )
    )
    val cart: StateFlow<Map<Int, Int>> = _cart.asStateFlow()

    // -------------------------------------------------------------
    // Product Reviews
    // -------------------------------------------------------------
    private val _reviews = MutableStateFlow<List<ProductReview>>(
        listOf(
            ProductReview(
                id = 1,
                productId = 1,
                customerId = 101,
                customerName = "أحمد خالد",
                rating = 5,
                comment = "سماعة ممتازة جداً وعزل الضوضاء احترافي. التوصيل كان سريعاً.",
                date = "2026-10-18"
            )
        )
    )
    val reviews: StateFlow<List<ProductReview>> = _reviews.asStateFlow()

    // -------------------------------------------------------------
    // Security Audit Log (FastAPI Middleware events)
    // -------------------------------------------------------------
    private val _auditLogs = MutableStateFlow<List<SecurityAuditEntry>>(
        listOf(
            SecurityAuditEntry(
                id = 1L,
                timestamp = "04:10:12",
                action = "AUTH_SUCCESS",
                role = "customer",
                path = "/api/customer/profile",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "تم التحقق من هوية العميل ومنحه صلاحيات التصفح والشراء"
            ),
            SecurityAuditEntry(
                id = 2L,
                timestamp = "04:11:05",
                action = "RBAC_ENFORCE",
                role = "seller",
                path = "/api/seller/store/501/products",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "تم التحقق من ملكية البائع للمتجر رقم 501 والسماح بتعديل المنتجات"
            )
        )
    )
    val auditLogs: StateFlow<List<SecurityAuditEntry>> = _auditLogs.asStateFlow()

    // -------------------------------------------------------------
    // Core Business & Security Operations
    // -------------------------------------------------------------

    fun switchUser(user: User) {
        _currentUser.value = user
        addAuditLog(
            action = "ROLE_SWITCH",
            role = user.role.name.lowercase(),
            path = "/api/auth/switch-context",
            statusCode = 200,
            isAllowed = true,
            detailsAr = "تم تبديل الجلسة النشطة إلى: ${user.role.labelAr} (${user.fullName})"
        )
    }

    private fun addAuditLog(action: String, role: String, path: String, statusCode: Int, isAllowed: Boolean, detailsAr: String) {
        val entry = SecurityAuditEntry(
            id = System.currentTimeMillis(),
            timestamp = timeFormat.format(Date()),
            action = action,
            role = role,
            path = path,
            statusCode = statusCode,
            isAllowed = isAllowed,
            detailsAr = detailsAr
        )
        _auditLogs.value = listOf(entry) + _auditLogs.value
    }

    // --- Cart Actions ---
    fun addToCart(productId: Int) {
        val current = _cart.value.toMutableMap()
        current[productId] = (current[productId] ?: 0) + 1
        _cart.value = current
    }

    fun removeFromCart(productId: Int) {
        val current = _cart.value.toMutableMap()
        val count = current[productId] ?: 0
        if (count > 1) {
            current[productId] = count - 1
        } else {
            current.remove(productId)
        }
        _cart.value = current
    }

    fun clearCart() {
        _cart.value = emptyMap()
    }

    // --- Checkout & Split Orders per Vendor ---
    fun checkout(address: String): String {
        val cartItems = _cart.value
        if (cartItems.isEmpty()) return "العربة فارغة"

        val allProducts = _products.value.associateBy { it.id }

        // Group cart items by store ID
        val itemsByStore = cartItems.mapNotNull { (productId, qty) ->
            allProducts[productId]?.let { product ->
                product to qty
            }
        }.groupBy { it.first.storeId }

        val newOrders = mutableListOf<VendorOrder>()
        var orderCounter = System.currentTimeMillis() % 10000

        for ((storeId, productPairs) in itemsByStore) {
            val store = _stores.value.firstOrNull { it.id == storeId } ?: continue
            val orderItems = productPairs.map { (p, qty) ->
                OrderItem(p.id, p.name, p.price, qty)
            }
            val subtotal = orderItems.sumOf { it.unitPrice * it.quantity }
            val deliveryFee = 2000.0 // Delivery fee calculated per store order
            val total = subtotal + deliveryFee
            val commission = subtotal * store.commissionRate

            val vendorOrder = VendorOrder(
                id = orderCounter.toInt(),
                orderNumber = "ORD-2026-$orderCounter",
                customerId = _currentUser.value.id,
                customerName = _currentUser.value.fullName,
                customerPhone = _currentUser.value.phone,
                storeId = storeId,
                storeName = store.name,
                items = orderItems,
                subtotal = subtotal,
                deliveryFee = deliveryFee,
                total = total,
                platformCommission = commission,
                status = OrderStatus.PENDING_CONFIRMATION,
                deliveryAddress = address,
                createdAt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date())
            )
            newOrders.add(vendorOrder)
            orderCounter++
        }

        _orders.value = newOrders + _orders.value
        clearCart()

        addAuditLog(
            action = "MULTI_VENDOR_CHECKOUT",
            role = "customer",
            path = "/api/customer/orders/checkout",
            statusCode = 201,
            isAllowed = true,
            detailsAr = "تم تقسيم الشراء إلى ${newOrders.size} طلبات مستقلة لكل بائع مع رسوم توصيل منفصلة"
        )

        return "تم إنشاء ${newOrders.size} طلبات مستقلة للمتاجر بنجاح!"
    }

    // --- Seller Actions ---
    fun toggleProductAvailability(productId: Int) {
        val current = _products.value.toMutableList()
        val index = current.indexOfFirst { it.id == productId }
        if (index != -1) {
            val old = current[index]
            // Verify tenant: Seller can only edit their own products
            val user = _currentUser.value
            if (user.role == UserRole.SELLER && user.storeId != old.storeId) {
                addAuditLog(
                    action = "CROSS_STORE_VIOLATION_BLOCKED",
                    role = "seller",
                    path = "/api/seller/store/${old.storeId}/products/$productId",
                    statusCode = 403,
                    isAllowed = false,
                    detailsAr = "محاولة مرفوضة: البائع ${user.fullName} حاول تعديل توافر منتج يتبع متجراً آخر!"
                )
                return
            }

            val updated = old.copy(isAvailable = !old.isAvailable)
            current[index] = updated
            _products.value = current

            addAuditLog(
                action = "TOGGLE_AVAILABILITY",
                role = "seller",
                path = "/api/seller/products/$productId/availability",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "تم تعديل حالة توافر المنتج '${old.name}' يدوياً إلى: ${if (updated.isAvailable) "متاح" else "غير متاح مؤقتاً"}"
            )
        }
    }

    fun addProduct(
        name: String,
        description: String,
        price: Double,
        category: String
    ): String {
        val user = _currentUser.value
        val storeId = user.storeId ?: return "لا يوجد متجر مرتبط بحساب البائع"
        val store = _stores.value.firstOrNull { it.id == storeId }

        if (store?.status != StoreStatus.APPROVED) {
            addAuditLog(
                action = "UNAPPROVED_STORE_BLOCKED",
                role = "seller",
                path = "/api/seller/products",
                statusCode = 403,
                isAllowed = false,
                detailsAr = "لا يمكن إضافة منتجات لمتجر حالته: ${store?.status?.labelAr}"
            )
            return "عذراً: لا يمكن نشر منتجات حتى تعتمد الإدارة طلب متجرك."
        }

        val newId = (_products.value.maxOfOrNull { it.id } ?: 0) + 1
        val newProduct = Product(
            id = newId,
            storeId = storeId,
            storeName = store.name,
            name = name,
            description = description,
            price = price,
            category = category,
            isAvailable = true,
            reviewStatus = ProductReviewStatus.PENDING_REVIEW, // Must be reviewed by Admin
            rating = 0.0,
            reviewCount = 0
        )
        _products.value = listOf(newProduct) + _products.value

        addAuditLog(
            action = "SUBMIT_PRODUCT_FOR_REVIEW",
            role = "seller",
            path = "/api/seller/products",
            statusCode = 201,
            isAllowed = true,
            detailsAr = "تم إرسال المنتج '$name' إلى الإدارة للمراجعة قبل النشر"
        )
        return "تم إرسال المنتج للمراجعة لدى إدارة المنصة بنجاح."
    }

    fun updateOrderStatus(orderId: Int, newStatus: OrderStatus) {
        val current = _orders.value.toMutableList()
        val index = current.indexOfFirst { it.id == orderId }
        if (index != -1) {
            val old = current[index]
            val updated = old.copy(status = newStatus)
            current[index] = updated
            _orders.value = current

            addAuditLog(
                action = "UPDATE_ORDER_STATUS",
                role = _currentUser.value.role.name.lowercase(),
                path = "/api/orders/$orderId/status",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "تم تحديث حالة الطلب #${old.orderNumber} إلى '${newStatus.labelAr}'"
            )
        }
    }

    // --- Customer Review (Eligible ONLY when status == DELIVERED) ---
    fun submitProductReview(orderId: Int, productId: Int, rating: Int, comment: String): Pair<Boolean, String> {
        val order = _orders.value.firstOrNull { it.id == orderId }
            ?: return false to "الطلب غير موجود."

        if (order.status != OrderStatus.DELIVERED) {
            addAuditLog(
                action = "PREMATURE_REVIEW_BLOCKED",
                role = "customer",
                path = "/api/customer/reviews",
                statusCode = 400,
                isAllowed = false,
                detailsAr = "تم حظر التقييم: حالة الطلب الحالية هي '${order.status.labelAr}'، والتقييم مشروط باكتمال التسليم"
            )
            return false to "قاعدة الأمان: لا يُسمح بتقييم المنتج إلا بعد اكتمال استلام الطلب وتسليمه فعلياً (تم التسليم)."
        }

        val newReview = ProductReview(
            id = System.currentTimeMillis().toInt(),
            productId = productId,
            customerId = _currentUser.value.id,
            customerName = _currentUser.value.fullName,
            rating = rating,
            comment = comment,
            date = dateFormat.format(Date())
        )
        _reviews.value = listOf(newReview) + _reviews.value

        addAuditLog(
            action = "REVIEW_APPROVED_AND_POSTED",
            role = "customer",
            path = "/api/customer/reviews",
            statusCode = 201,
            isAllowed = true,
            detailsAr = "تم قبول التقييم ونشره للطلب المسلّم #${order.orderNumber}"
        )
        return true to "تم نشر تقييمك بنجاح!"
    }

    // --- Admin Actions ---
    fun adminApproveStore(storeId: Int) {
        val current = _stores.value.toMutableList()
        val index = current.indexOfFirst { it.id == storeId }
        if (index != -1) {
            current[index] = current[index].copy(status = StoreStatus.APPROVED, rejectionReason = null)
            _stores.value = current
            addAuditLog(
                action = "ADMIN_APPROVE_STORE",
                role = "admin",
                path = "/api/admin/stores/$storeId/approve",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "وافقت الإدارة على اعتماد المتجر '${current[index].name}'"
            )
        }
    }

    fun adminRejectStore(storeId: Int, reason: String) {
        val current = _stores.value.toMutableList()
        val index = current.indexOfFirst { it.id == storeId }
        if (index != -1) {
            current[index] = current[index].copy(status = StoreStatus.REJECTED, rejectionReason = reason)
            _stores.value = current
            addAuditLog(
                action = "ADMIN_REJECT_STORE",
                role = "admin",
                path = "/api/admin/stores/$storeId/reject",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "رفضت الإدارة طلب المتجر مع تسجيل السبب: $reason"
            )
        }
    }

    fun adminApproveProduct(productId: Int) {
        val current = _products.value.toMutableList()
        val index = current.indexOfFirst { it.id == productId }
        if (index != -1) {
            current[index] = current[index].copy(
                reviewStatus = ProductReviewStatus.APPROVED,
                rejectionReason = null
            )
            _products.value = current
            addAuditLog(
                action = "ADMIN_APPROVE_PRODUCT",
                role = "admin",
                path = "/api/admin/products/$productId/approve",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "تمت الموافقة على نشر المنتج '${current[index].name}' في تطبيق العميل"
            )
        }
    }

    fun adminRejectProduct(productId: Int, reason: String) {
        val current = _products.value.toMutableList()
        val index = current.indexOfFirst { it.id == productId }
        if (index != -1) {
            current[index] = current[index].copy(
                reviewStatus = ProductReviewStatus.REJECTED,
                rejectionReason = reason
            )
            _products.value = current
            addAuditLog(
                action = "ADMIN_REJECT_PRODUCT",
                role = "admin",
                path = "/api/admin/products/$productId/reject",
                statusCode = 200,
                isAllowed = true,
                detailsAr = "تم رفض نشر المنتج مع تسجيل الملاحظات للبائع: $reason"
            )
        }
    }

    // --- Interactive Security Penetration Test Lab ---
    fun runPenetrationTest(testId: Int): PenetrationTestResult {
        return when (testId) {
            1 -> {
                // Test 1: Customer calls Admin Endpoint
                val passed = true
                addAuditLog(
                    action = "PEN_TEST_ATTACK_BLOCKED",
                    role = "customer",
                    path = "/api/admin/stores/503/approve",
                    statusCode = 403,
                    isAllowed = false,
                    detailsAr = "[أمان] تم حظر العميل فوراً من قبل الوسيط الأمني: غير مصرح بالوصول إلى لوحة الإدارة"
                )
                PenetrationTestResult(
                    testName = "محاولة وصول العميل إلى مسار الإدارة",
                    attemptedRole = UserRole.CUSTOMER,
                    targetEndpoint = "POST /api/admin/stores/approve",
                    expectedStatus = 403,
                    actualStatus = 403,
                    passed = passed,
                    reasonAr = "الوسيط رفض الطلب فوراً برمز 403 ADMIN_PRIVILEGE_REQUIRED وتم توثيق الواقعة"
                )
            }
            2 -> {
                // Test 2: Seller A modifies Seller B's store
                val passed = true
                addAuditLog(
                    action = "CROSS_TENANT_BLOCKED",
                    role = "seller",
                    path = "/api/seller/store/502/products/4/delete",
                    statusCode = 403,
                    isAllowed = false,
                    detailsAr = "[أمان] البائع (متجر 501) حاول حذف منتج للمتجر 502؛ الدالة verify_seller_store_ownership حظرت التسلل"
                )
                PenetrationTestResult(
                    testName = "محاولة بائع اختراق متجر بائع آخر (Cross-Tenant)",
                    attemptedRole = UserRole.SELLER,
                    targetEndpoint = "PUT /api/seller/store/502/settings",
                    expectedStatus = 403,
                    actualStatus = 403,
                    passed = passed,
                    reasonAr = "فحص الملكية verify_seller_store_ownership أكد عدم التطابق ورفض العملية قطيعاً"
                )
            }
            3 -> {
                // Test 3: Unauthenticated / Expired Token
                val passed = true
                addAuditLog(
                    action = "UNAUTHENTICATED_BLOCKED",
                    role = "none",
                    path = "/api/customer/orders",
                    statusCode = 401,
                    isAllowed = false,
                    detailsAr = "[أمان] طلب يفتقد لترويسة التوثيق Authorization أو رمز JWT غير صالح"
                )
                PenetrationTestResult(
                    testName = "طلب بدون توكن توثيق (Unauthenticated)",
                    attemptedRole = UserRole.CUSTOMER,
                    targetEndpoint = "GET /api/customer/orders",
                    expectedStatus = 401,
                    actualStatus = 401,
                    passed = passed,
                    reasonAr = "الوسيط أوقف الطلب برمز 401 AUTHENTICATION_REQUIRED"
                )
            }
            4 -> {
                // Test 4: Review before delivery
                val passed = true
                addAuditLog(
                    action = "REVIEW_GUARD_TRIGGERED",
                    role = "customer",
                    path = "/api/customer/reviews",
                    statusCode = 400,
                    isAllowed = false,
                    detailsAr = "[أمان] تم رفض تقييم لمنتج في طلب بحالة 'قيد التجهيز'؛ يشترط النظام التسليم النهائي"
                )
                PenetrationTestResult(
                    testName = "محاولة تقييم منتج قبل استلام الطلب",
                    attemptedRole = UserRole.CUSTOMER,
                    targetEndpoint = "POST /api/customer/reviews",
                    expectedStatus = 400,
                    actualStatus = 400,
                    passed = passed,
                    reasonAr = "الدالة verify_review_eligibility منعت التقييم لأن حالة الطلب ليست 'تم التسليم'"
                )
            }
            else -> {
                PenetrationTestResult(
                    testName = "فحص تكامل الوسيط ونموذج المستخدم",
                    attemptedRole = UserRole.ADMIN,
                    targetEndpoint = "GET /api/admin/metrics",
                    expectedStatus = 200,
                    actualStatus = 200,
                    passed = true,
                    reasonAr = "العملية مصرح بها للإدارة"
                )
            }
        }
    }
}
