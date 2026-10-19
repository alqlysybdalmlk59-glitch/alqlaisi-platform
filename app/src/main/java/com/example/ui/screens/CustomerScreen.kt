package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.PlatformRepository
import com.example.model.OrderStatus
import com.example.model.Product
import com.example.model.ProductReviewStatus
import com.example.ui.theme.StatusError
import com.example.ui.theme.StatusSuccess
import com.example.ui.theme.StatusWarning

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerScreen(
    repository: PlatformRepository,
    modifier: Modifier = Modifier
) {
    val products by repository.products.collectAsState()
    val orders by repository.orders.collectAsState()
    val cart by repository.cart.collectAsState()
    val currentUser by repository.currentUser.collectAsState()

    var selectedTab by remember { mutableStateOf(0) } // 0: Products, 1: Cart & Split Checkout, 2: My Orders
    var selectedCategory by remember { mutableStateOf("الكل") }
    var searchQuery by remember { mutableStateOf("") }
    var showReviewDialogForProduct by remember { mutableStateOf<Pair<Int, Int>?>(null) } // orderId, productId
    var alertMessage by remember { mutableStateOf<String?>(null) }

    // Filter approved products only (Rule: Customer never sees unapproved products)
    val approvedProducts = products.filter { product ->
        product.reviewStatus == ProductReviewStatus.APPROVED &&
                (selectedCategory == "الكل" || product.category == selectedCategory) &&
                (searchQuery.isBlank() || product.name.contains(searchQuery, ignoreCase = true) || product.storeName.contains(searchQuery, ignoreCase = true))
    }

    // Customer orders only (Order privacy isolation)
    val customerOrders = orders.filter { it.customerId == currentUser.id }

    val categories = listOf("الكل", "إلكترونيات", "ملابس", "عطور", "أحذية")

    Scaffold(
        topBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
            ) {
                // Secondary navigation bar for Customer sections
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.primary
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("المتجر والمنتجات", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Storefront, contentDescription = "Store") },
                        modifier = Modifier.testTag("customer_tab_store")
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = {
                            val count = cart.values.sum()
                            Text(if (count > 0) "عربة التسوق ($count)" else "العربة", fontWeight = FontWeight.Bold)
                        },
                        icon = {
                            BadgedBox(
                                badge = {
                                    val count = cart.values.sum()
                                    if (count > 0) {
                                        Badge { Text("$count") }
                                    }
                                }
                            ) {
                                Icon(Icons.Default.ShoppingCart, contentDescription = "Cart")
                            }
                        },
                        modifier = Modifier.testTag("customer_tab_cart")
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = { Text("طلباتي (${customerOrders.size})", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.LocalShipping, contentDescription = "Orders") },
                        modifier = Modifier.testTag("customer_tab_orders")
                    )
                }
            }
        },
        modifier = modifier
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when (selectedTab) {
                0 -> {
                    // Products Catalog
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // Multi-vendor Platform Hero Card
                        item {
                            Card(
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.primaryContainer
                                ),
                                shape = RoundedCornerShape(18.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(18.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "منصة القليسي للتسوق الموحد",
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "اطلب من عدة متاجر معتمدة في سلة واحدة، مع تقسيم مستقل للطلبات والدفع عند الاستلام.",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.85f)
                                        )
                                    }
                                    Icon(
                                        Icons.Default.ShoppingBag,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(44.dp)
                                    )
                                }
                            }
                        }

                        // Search Field
                        item {
                            OutlinedTextField(
                                value = searchQuery,
                                onValueChange = { searchQuery = it },
                                placeholder = { Text("ابحث عن منتج أو متجر...") },
                                leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                                trailingIcon = {
                                    if (searchQuery.isNotEmpty()) {
                                        IconButton(onClick = { searchQuery = "" }) {
                                            Icon(Icons.Default.Close, contentDescription = "Clear")
                                        }
                                    }
                                },
                                shape = RoundedCornerShape(14.dp),
                                singleLine = true,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("search_input")
                            )
                        }

                        // Categories Horizontal Filter
                        item {
                            LazyRow(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                items(categories) { category ->
                                    val isSelected = selectedCategory == category
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = { selectedCategory = category },
                                        label = { Text(category, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
                                        leadingIcon = if (isSelected) {
                                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                                        } else null,
                                        shape = RoundedCornerShape(12.dp)
                                    )
                                }
                            }
                        }

                        // Section Title
                        item {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(
                                    text = "المنتجات المنشورة المتاحة (${approvedProducts.size})",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "مراجعة واعتماد الإدارة ✓",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }

                        if (approvedProducts.isEmpty()) {
                            item {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 24.dp)
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(24.dp)
                                    ) {
                                        Icon(Icons.Default.SearchOff, contentDescription = null, modifier = Modifier.size(48.dp))
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text("لا توجد منتجات مطابقة لخيارات البحث", fontWeight = FontWeight.Medium)
                                    }
                                }
                            }
                        }

                        // Products Cards
                        items(approvedProducts, key = { it.id }) { product ->
                            ProductCard(
                                product = product,
                                inCartCount = cart[product.id] ?: 0,
                                onAddToCart = {
                                    if (product.isAvailable) {
                                        repository.addToCart(product.id)
                                    } else {
                                        alertMessage = "هذا المنتج غير متاح مؤقتاً للتوريد من قبل البائع."
                                    }
                                }
                            )
                        }
                    }
                }

                1 -> {
                    // Cart & Multi-Vendor Split Checkout
                    CartAndCheckoutView(
                        repository = repository,
                        onNavigateToOrders = { selectedTab = 2 }
                    )
                }

                2 -> {
                    // Customer Orders
                    CustomerOrdersView(
                        orders = customerOrders,
                        onOpenReview = { orderId, productId ->
                            showReviewDialogForProduct = orderId to productId
                        },
                        onReviewBlocked = { msg ->
                            alertMessage = msg
                        }
                    )
                }
            }

            // Review Dialog (Condition: Order must be DELIVERED)
            showReviewDialogForProduct?.let { (orderId, productId) ->
                ReviewDialog(
                    orderId = orderId,
                    productId = productId,
                    repository = repository,
                    onDismiss = { showReviewDialogForProduct = null }
                )
            }

            // Global Feedback Alert
            alertMessage?.let { msg ->
                AlertDialog(
                    onDismissRequest = { alertMessage = null },
                    icon = { Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                    title = { Text("تنبيه الأمان وقواعد المنصة", fontWeight = FontWeight.Bold) },
                    text = { Text(msg) },
                    confirmButton = {
                        TextButton(onClick = { alertMessage = null }) {
                            Text("حسناً")
                        }
                    }
                )
            }
        }
    }
}

@Composable
fun ProductCard(
    product: Product,
    inCartCount: Int,
    onAddToCart: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                // Store Name Badge
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            Icons.Default.Store,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.onSecondaryContainer
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = product.storeName,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSecondaryContainer
                        )
                    }
                }

                // Manual Availability Badge (NO stock count!)
                if (product.isAvailable) {
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = StatusSuccess.copy(alpha = 0.15f)
                    ) {
                        Text(
                            text = "متاح للطلب",
                            color = StatusSuccess,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                } else {
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = StatusError.copy(alpha = 0.15f)
                    ) {
                        Text(
                            text = "غير متاح مؤقتاً",
                            color = StatusError,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            Text(
                text = product.name,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = product.description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    Text(
                        text = "${String.format("%,.0f", product.price)} ر.ي",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.Star,
                            contentDescription = null,
                            tint = StatusWarning,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(2.dp))
                        Text(
                            text = "${product.rating} (${product.reviewCount} تقييم)",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Button(
                    onClick = onAddToCart,
                    enabled = product.isAvailable,
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (product.isAvailable) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
                    ),
                    modifier = Modifier.testTag("add_to_cart_${product.id}")
                ) {
                    Icon(
                        if (inCartCount > 0) Icons.Default.Check else Icons.Default.AddShoppingCart,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (!product.isAvailable) "غير متاح" else if (inCartCount > 0) "في العربة ($inCartCount)" else "إضافة للسلة",
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
fun CartAndCheckoutView(
    repository: PlatformRepository,
    onNavigateToOrders: () -> Unit
) {
    val cart by repository.cart.collectAsState()
    val products by repository.products.collectAsState()
    val stores by repository.stores.collectAsState()

    var deliveryAddress by remember { mutableStateOf("صنعاء - شارع حدة - بجوار سيتي ستارز") }
    var orderCreatedMessage by remember { mutableStateOf<String?>(null) }

    val productsMap = products.associateBy { it.id }

    // Group cart items by store
    val storeGroups = cart.mapNotNull { (productId, qty) ->
        productsMap[productId]?.let { product ->
            product to qty
        }
    }.groupBy { it.first.storeId }

    if (cart.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(32.dp)
            ) {
                Icon(
                    Icons.Outlined.ShoppingCart,
                    contentDescription = null,
                    modifier = Modifier.size(72.dp),
                    tint = MaterialTheme.colorScheme.outline
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "عربة التسوق فارغة",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "تصفح المتاجر المعتمدة وأضف ما ترغب به إلى سلتك.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        }
        return
    }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        // Multi-Vendor Architecture Explanation Notice
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.4f)),
                shape = RoundedCornerShape(14.dp)
            ) {
                Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CallSplit, contentDescription = null, tint = MaterialTheme.colorScheme.secondary)
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "نظام متعدد البائعين: يتم تلقائياً تقسيم سلتك إلى ${storeGroups.size} طلبات مستقلة، مع احتساب رسوم توصيل منفصلة لكل متجر.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }

        // Each Store's Sub-Order
        storeGroups.forEach { (storeId, items) ->
            val store = stores.firstOrNull { it.id == storeId }
            val storeSubtotal = items.sumOf { (product, qty) -> product.price * qty }
            val storeDeliveryFee = 2000.0 // Standard per-vendor delivery fee

            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.Storefront, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = store?.name ?: "متجر #$storeId",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        Divider(modifier = Modifier.padding(vertical = 10.dp))

                        items.forEach { (product, qty) ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 6.dp)
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(product.name, fontWeight = FontWeight.SemiBold, maxLines = 1)
                                    Text(
                                        "${String.format("%,.0f", product.price)} ر.ي × $qty",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(
                                        onClick = { repository.removeFromCart(product.id) },
                                        modifier = Modifier.size(32.dp)
                                    ) {
                                        Icon(Icons.Default.RemoveCircleOutline, contentDescription = "Decrease")
                                    }
                                    Text(
                                        text = "$qty",
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier.padding(horizontal = 6.dp)
                                    )
                                    IconButton(
                                        onClick = { repository.addToCart(product.id) },
                                        modifier = Modifier.size(32.dp)
                                    ) {
                                        Icon(Icons.Default.AddCircleOutline, contentDescription = "Increase")
                                    }
                                }
                            }
                        }

                        Divider(modifier = Modifier.padding(vertical = 10.dp))

                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("المجموع الفرعي للمتجر:", style = MaterialTheme.typography.bodySmall)
                            Text("${String.format("%,.0f", storeSubtotal)} ر.ي", fontWeight = FontWeight.Bold)
                        }

                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("رسوم التوصيل الخاصة بالطلب:", style = MaterialTheme.typography.bodySmall)
                            Text("${String.format("%,.0f", storeDeliveryFee)} ر.ي", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // Delivery Address & Payment Method
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "بيانات التوصيل والدفع",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = deliveryAddress,
                        onValueChange = { deliveryAddress = it },
                        label = { Text("عنوان التوصيل بالتفصيل") },
                        leadingIcon = { Icon(Icons.Default.LocationOn, contentDescription = null) },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp)
                        ) {
                            Icon(Icons.Default.Payments, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = "طريقة الدفع: الدفع عند الاستلام (COD)",
                                    fontWeight = FontWeight.Bold,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                Text(
                                    text = "الطريقة المعتمدة حالياً في المنصة",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }

        // Grand Total & Submit Order Button
        item {
            val totalProductsCost = storeGroups.values.sumOf { list -> list.sumOf { (p, qty) -> p.price * qty } }
            val totalDeliveryCost = storeGroups.size * 2000.0
            val grandTotal = totalProductsCost + totalDeliveryCost

            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("إجمالي المنتجات:", fontWeight = FontWeight.Medium)
                        Text("${String.format("%,.0f", totalProductsCost)} ر.ي", fontWeight = FontWeight.Bold)
                    }
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("إجمالي رسوم التوصيل (${storeGroups.size} متاجر):", fontWeight = FontWeight.Medium)
                        Text("${String.format("%,.0f", totalDeliveryCost)} ر.ي", fontWeight = FontWeight.Bold)
                    }
                    Divider(modifier = Modifier.padding(vertical = 10.dp), color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.2f))
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("المجموع النهائي الكلي:", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.ExtraBold)
                        Text(
                            "${String.format("%,.0f", grandTotal)} ر.ي",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                    Button(
                        onClick = {
                            val result = repository.checkout(deliveryAddress)
                            orderCreatedMessage = result
                        },
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .testTag("confirm_order_button")
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("تأكيد وإنشاء الطلبات (${storeGroups.size} طلبات)", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }
            }
        }
    }

    orderCreatedMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = {
                orderCreatedMessage = null
                onNavigateToOrders()
            },
            icon = { Icon(Icons.Default.CheckCircle, contentDescription = null, tint = StatusSuccess) },
            title = { Text("تم إنشاء الطلبات بنجاح", fontWeight = FontWeight.Bold) },
            text = { Text(msg) },
            confirmButton = {
                Button(
                    onClick = {
                        orderCreatedMessage = null
                        onNavigateToOrders()
                    }
                ) {
                    Text("عرض ومتابعة طلباتي")
                }
            }
        )
    }
}

@Composable
fun CustomerOrdersView(
    orders: List<com.example.model.VendorOrder>,
    onOpenReview: (orderId: Int, productId: Int) -> Unit,
    onReviewBlocked: (String) -> Unit
) {
    if (orders.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
                Icon(Icons.Outlined.LocalShipping, contentDescription = null, modifier = Modifier.size(64.dp), tint = MaterialTheme.colorScheme.outline)
                Spacer(modifier = Modifier.height(12.dp))
                Text("لا توجد طلبات سابقة حتى الآن", fontWeight = FontWeight.Bold)
            }
        }
        return
    }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        item {
            Text(
                text = "قائمة الطلبات ومتابعة الحالة (${orders.size})",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }

        items(orders, key = { it.id }) { order ->
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column {
                            Text(order.orderNumber, fontWeight = FontWeight.ExtraBold, style = MaterialTheme.typography.titleMedium)
                            Text(order.createdAt, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }

                        // Order Status Pill
                        val (statusColor, statusBg) = when (order.status) {
                            OrderStatus.PENDING_CONFIRMATION -> StatusWarning to StatusWarning.copy(alpha = 0.15f)
                            OrderStatus.PROCESSING -> Color(0xFF2563EB) to Color(0xFF2563EB).copy(alpha = 0.15f)
                            OrderStatus.OUT_FOR_DELIVERY -> Color(0xFF7C3AED) to Color(0xFF7C3AED).copy(alpha = 0.15f)
                            OrderStatus.DELIVERED -> StatusSuccess to StatusSuccess.copy(alpha = 0.15f)
                            OrderStatus.CANCELLED -> StatusError to StatusError.copy(alpha = 0.15f)
                        }

                        Surface(shape = RoundedCornerShape(8.dp), color = statusBg) {
                            Text(
                                text = order.status.labelAr,
                                color = statusColor,
                                fontWeight = FontWeight.Bold,
                                style = MaterialTheme.typography.labelSmall,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Storefront, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(order.storeName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                    }

                    Divider(modifier = Modifier.padding(vertical = 10.dp))

                    order.items.forEach { item ->
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                        ) {
                            Text("${item.productName} (×${item.quantity})", modifier = Modifier.weight(1f))
                            Text("${String.format("%,.0f", item.unitPrice * item.quantity)} ر.ي", fontWeight = FontWeight.Bold)
                        }

                        // Review Button Guard Check (Rule 3.8: Can ONLY review if order status == DELIVERED)
                        Row(
                            horizontalArrangement = Arrangement.End,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            if (order.status == OrderStatus.DELIVERED) {
                                OutlinedButton(
                                    onClick = { onOpenReview(order.id, item.productId) },
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.testTag("review_btn_${order.id}")
                                ) {
                                    Icon(Icons.Default.StarRate, contentDescription = null, modifier = Modifier.size(16.dp), tint = StatusWarning)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("تقييم المنتج", fontSize = 12.sp)
                                }
                            } else {
                                TextButton(
                                    onClick = {
                                        onReviewBlocked("قاعدة الأمان: لا يمكن تقييم هذا المنتج لأن الطلب ما زال بحالة '${order.status.labelAr}'. التقييم متاح فقط بعد اكتمال التسليم (تم التسليم).")
                                    }
                                ) {
                                    Icon(Icons.Default.Lock, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.outline)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("التقييم مقفل (حتى التسليم)", fontSize = 11.sp, color = MaterialTheme.colorScheme.outline)
                                }
                            }
                        }
                    }

                    Divider(modifier = Modifier.padding(vertical = 10.dp))

                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("الإجمالي مع التوصيل (${String.format("%,.0f", order.deliveryFee)} ر.ي):", style = MaterialTheme.typography.bodySmall)
                        Text("${String.format("%,.0f", order.total)} ر.ي", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
    }
}

@Composable
fun ReviewDialog(
    orderId: Int,
    productId: Int,
    repository: PlatformRepository,
    onDismiss: () -> Unit
) {
    var rating by remember { mutableStateOf(5) }
    var comment by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("تقييم المنتج (طلب مسلّم)", fontWeight = FontWeight.Bold) },
        text = {
            Column {
                Text("اختر تقييمك من 1 إلى 5 نجوم:")
                Spacer(modifier = Modifier.height(8.dp))
                Row {
                    for (i in 1..5) {
                        IconButton(onClick = { rating = i }) {
                            Icon(
                                Icons.Default.Star,
                                contentDescription = null,
                                tint = if (i <= rating) StatusWarning else MaterialTheme.colorScheme.outlineVariant
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedTextField(
                    value = comment,
                    onValueChange = { comment = it },
                    label = { Text("اكتب رأيك الصادق في المنتج...") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    shape = RoundedCornerShape(12.dp)
                )

                errorMessage?.let {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(it, color = StatusError, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val (success, msg) = repository.submitProductReview(orderId, productId, rating, comment)
                    if (success) {
                        onDismiss()
                    } else {
                        errorMessage = msg
                    }
                },
                enabled = comment.length >= 3
            ) {
                Text("إرسال التقييم")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("إلغاء")
            }
        }
    )
}
