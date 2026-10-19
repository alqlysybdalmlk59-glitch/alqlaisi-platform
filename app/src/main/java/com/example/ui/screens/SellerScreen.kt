package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.PlatformRepository
import com.example.model.OrderStatus
import com.example.model.ProductReviewStatus
import com.example.model.StoreStatus
import com.example.ui.theme.RoleSellerColor
import com.example.ui.theme.StatusError
import com.example.ui.theme.StatusSuccess
import com.example.ui.theme.StatusWarning

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SellerScreen(
    repository: PlatformRepository,
    modifier: Modifier = Modifier
) {
    val currentUser by repository.currentUser.collectAsState()
    val stores by repository.stores.collectAsState()
    val products by repository.products.collectAsState()
    val orders by repository.orders.collectAsState()

    var selectedTab by remember { mutableStateOf(0) } // 0: Products, 1: Orders, 2: Financials
    var showAddProductDialog by remember { mutableStateOf(false) }
    var feedbackMessage by remember { mutableStateOf<String?>(null) }

    // Enforce Tenant Isolation: Seller can ONLY see their own store, products, and orders!
    val currentStore = stores.firstOrNull { it.id == currentUser.storeId }
    val sellerProducts = products.filter { it.storeId == currentUser.storeId }
    val sellerOrders = orders.filter { it.storeId == currentUser.storeId }

    Scaffold(
        topBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
            ) {
                // Secondary Tab Navigation
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = RoleSellerColor
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("المنتجات (${sellerProducts.size})", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Inventory2, contentDescription = "Products") },
                        modifier = Modifier.testTag("seller_tab_products")
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("الطلبات (${sellerOrders.size})", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.ReceiptLong, contentDescription = "Orders") },
                        modifier = Modifier.testTag("seller_tab_orders")
                    )
                    Tab(
                        selected = selectedTab == 2,
                        onClick = { selectedTab = 2 },
                        text = { Text("المالية والعمولات", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.AccountBalanceWallet, contentDescription = "Financials") },
                        modifier = Modifier.testTag("seller_tab_financials")
                    )
                }
            }
        },
        floatingActionButton = {
            if (selectedTab == 0) {
                ExtendedFloatingActionButton(
                    onClick = { showAddProductDialog = true },
                    icon = { Icon(Icons.Default.Add, contentDescription = "Add Product") },
                    text = { Text("إضافة منتج جديد", fontWeight = FontWeight.Bold) },
                    containerColor = RoleSellerColor,
                    contentColor = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.testTag("add_product_fab")
                )
            }
        },
        modifier = modifier
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                // Store Header Card
                item {
                    currentStore?.let { store ->
                        Card(
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = when (store.status) {
                                    StoreStatus.APPROVED -> MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f)
                                    StoreStatus.PENDING_REVIEW -> StatusWarning.copy(alpha = 0.15f)
                                    StoreStatus.REJECTED -> StatusError.copy(alpha = 0.15f)
                                    StoreStatus.SUSPENDED -> MaterialTheme.colorScheme.surfaceVariant
                                }
                            ),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Store, contentDescription = null, tint = RoleSellerColor)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(store.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.ExtraBold)
                                    }

                                    // Store Status Badge
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = when (store.status) {
                                            StoreStatus.APPROVED -> StatusSuccess
                                            StoreStatus.PENDING_REVIEW -> StatusWarning
                                            StoreStatus.REJECTED -> StatusError
                                            StoreStatus.SUSPENDED -> MaterialTheme.colorScheme.outline
                                        }
                                    ) {
                                        Text(
                                            text = store.status.labelAr,
                                            color = MaterialTheme.colorScheme.surface,
                                            fontWeight = FontWeight.Bold,
                                            style = MaterialTheme.typography.labelSmall,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(6.dp))
                                Text(store.description, style = MaterialTheme.typography.bodySmall)

                                if (store.status == StoreStatus.PENDING_REVIEW) {
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        "ملاحظة: المتجر قيد مراجعة الإدارة. لن تظهر المنتجات للعملاء حتى يصدر قرار الاعتماد.",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = StatusWarning,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                }

                when (selectedTab) {
                    0 -> {
                        // Section Rules Banner: NO STOCK COUNT
                        item {
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(12.dp)
                                ) {
                                    Icon(Icons.Default.Info, contentDescription = null, tint = RoleSellerColor, modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "وفق قواعد المنصة: لا توجد كميات مخزون أو عداد قطع. يتم التحكم في توافر المنتج يدوياً فقط (متاح / غير متاح مؤقتاً).",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }

                        if (sellerProducts.isEmpty()) {
                            item {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(32.dp)
                                    ) {
                                        Icon(Icons.Outlined.Inventory, contentDescription = null, modifier = Modifier.size(48.dp))
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text("لم تقم بإضافة منتجات بعد", fontWeight = FontWeight.Bold)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text("اضغط على زر 'إضافة منتج جديد' في الأسفل للبدء.", style = MaterialTheme.typography.bodySmall)
                                    }
                                }
                            }
                        }

                        // Seller Products List
                        items(sellerProducts, key = { it.id }) { product ->
                            Card(
                                shape = RoundedCornerShape(14.dp),
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
                                        Text(
                                            text = product.name,
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.Bold,
                                            modifier = Modifier.weight(1f)
                                        )

                                        // Review Status
                                        val reviewColor = when (product.reviewStatus) {
                                            ProductReviewStatus.APPROVED -> StatusSuccess
                                            ProductReviewStatus.PENDING_REVIEW -> StatusWarning
                                            ProductReviewStatus.REJECTED -> StatusError
                                            ProductReviewStatus.DRAFT -> MaterialTheme.colorScheme.outline
                                        }
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = reviewColor.copy(alpha = 0.15f)
                                        ) {
                                            Text(
                                                text = product.reviewStatus.labelAr,
                                                color = reviewColor,
                                                fontWeight = FontWeight.Bold,
                                                style = MaterialTheme.typography.labelSmall,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(
                                        product.description,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )

                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        "${String.format("%,.0f", product.price)} ر.ي",
                                        fontWeight = FontWeight.ExtraBold,
                                        color = MaterialTheme.colorScheme.primary,
                                        style = MaterialTheme.typography.titleMedium
                                    )

                                    Divider(modifier = Modifier.padding(vertical = 10.dp))

                                    // Manual Availability Toggle Row
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column {
                                            Text(
                                                text = if (product.isAvailable) "حالة التوافر: متاح للعملاء" else "حالة التوافر: غير متاح مؤقتاً",
                                                fontWeight = FontWeight.SemiBold,
                                                style = MaterialTheme.typography.bodySmall,
                                                color = if (product.isAvailable) StatusSuccess else StatusError
                                            )
                                            Text(
                                                text = "تبديل يدوي فوري بدون نظام مخزون",
                                                style = MaterialTheme.typography.labelSmall,
                                                color = MaterialTheme.colorScheme.outline
                                            )
                                        }

                                        Switch(
                                            checked = product.isAvailable,
                                            onCheckedChange = { repository.toggleProductAvailability(product.id) },
                                            modifier = Modifier.testTag("toggle_availability_${product.id}")
                                        )
                                    }
                                }
                            }
                        }
                    }

                    1 -> {
                        // Seller Orders Pipeline
                        item {
                            Text(
                                text = "الطلبات الواردة لمتجرك (${sellerOrders.size})",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        if (sellerOrders.isEmpty()) {
                            item {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(32.dp)
                                    ) {
                                        Icon(Icons.Outlined.ReceiptLong, contentDescription = null, modifier = Modifier.size(48.dp))
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text("لا توجد طلبات جديدة لمتجرك حالياً", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }

                        items(sellerOrders, key = { it.id }) { order ->
                            Card(
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(order.orderNumber, fontWeight = FontWeight.ExtraBold)
                                        Text(order.status.labelAr, fontWeight = FontWeight.Bold, color = RoleSellerColor)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text("العميل: ${order.customerName} (${order.customerPhone})", style = MaterialTheme.typography.bodySmall)
                                    Text("العنوان: ${order.deliveryAddress}", style = MaterialTheme.typography.bodySmall)

                                    Divider(modifier = Modifier.padding(vertical = 10.dp))

                                    order.items.forEach { item ->
                                        Row(
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text("${item.productName} × ${item.quantity}")
                                            Text("${String.format("%,.0f", item.unitPrice * item.quantity)} ر.ي", fontWeight = FontWeight.Bold)
                                        }
                                    }

                                    Divider(modifier = Modifier.padding(vertical = 10.dp))

                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("قيمة المنتجات:", fontWeight = FontWeight.Medium)
                                        Text("${String.format("%,.0f", order.subtotal)} ر.ي", fontWeight = FontWeight.Bold)
                                    }

                                    Spacer(modifier = Modifier.height(12.dp))

                                    // Seller Lifecycle Transition Buttons
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        if (order.status == OrderStatus.PENDING_CONFIRMATION) {
                                            Button(
                                                onClick = { repository.updateOrderStatus(order.id, OrderStatus.PROCESSING) },
                                                colors = ButtonDefaults.buttonColors(containerColor = RoleSellerColor),
                                                shape = RoundedCornerShape(8.dp),
                                                modifier = Modifier.weight(1f)
                                            ) {
                                                Text("قبول وبدء التجهيز")
                                            }
                                        }

                                        if (order.status == OrderStatus.PROCESSING) {
                                            Button(
                                                onClick = { repository.updateOrderStatus(order.id, OrderStatus.OUT_FOR_DELIVERY) },
                                                colors = ButtonDefaults.buttonColors(containerColor = StatusSuccess),
                                                shape = RoundedCornerShape(8.dp),
                                                modifier = Modifier.weight(1f)
                                            ) {
                                                Icon(Icons.Default.DeliveryDining, contentDescription = null, modifier = Modifier.size(18.dp))
                                                Spacer(modifier = Modifier.width(6.dp))
                                                Text("تسليم لموظف التوصيل")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    2 -> {
                        // Financials & Commission Breakdown
                        item {
                            Card(
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(18.dp)) {
                                    Text("الملخص المالي ومستحقات البائع", fontWeight = FontWeight.ExtraBold, style = MaterialTheme.typography.titleMedium)
                                    Spacer(modifier = Modifier.height(14.dp))

                                    val totalSales = sellerOrders.sumOf { it.subtotal }
                                    val totalCommission = sellerOrders.sumOf { it.platformCommission }
                                    val netPayout = totalSales - totalCommission

                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("إجمالي المبيعات:", style = MaterialTheme.typography.bodyMedium)
                                        Text("${String.format("%,.0f", totalSales)} ر.ي", fontWeight = FontWeight.Bold)
                                    }
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("عمولة المنصة المقتطعة:", style = MaterialTheme.typography.bodyMedium)
                                        Text("- ${String.format("%,.0f", totalCommission)} ر.ي", fontWeight = FontWeight.Bold, color = StatusError)
                                    }
                                    Divider(modifier = Modifier.padding(vertical = 12.dp))
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("صافي المستحقات القابلة للتحويل:", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.ExtraBold)
                                        Text(
                                            "${String.format("%,.0f", netPayout)} ر.ي",
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.ExtraBold,
                                            color = StatusSuccess
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Add Product Dialog (Manual availability, strictly NO stock count)
    if (showAddProductDialog) {
        AddProductDialog(
            onDismiss = { showAddProductDialog = false },
            onSubmit = { name, desc, price, cat ->
                val result = repository.addProduct(name, desc, price, cat)
                feedbackMessage = result
                showAddProductDialog = false
            }
        )
    }

    feedbackMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = { feedbackMessage = null },
            icon = { Icon(Icons.Default.Info, contentDescription = null, tint = RoleSellerColor) },
            title = { Text("إشعار إدارة المتجر", fontWeight = FontWeight.Bold) },
            text = { Text(msg) },
            confirmButton = {
                TextButton(onClick = { feedbackMessage = null }) {
                    Text("حسناً")
                }
            }
        )
    }
}

@Composable
fun AddProductDialog(
    onDismiss: () -> Unit,
    onSubmit: (name: String, desc: String, price: Double, category: String) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var desc by remember { mutableStateOf("") }
    var priceStr by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("إلكترونيات") }

    val categories = listOf("إلكترونيات", "ملابس", "عطور", "أحذية")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("إضافة منتج جديد للمراجعة", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("اسم المنتج") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp)
                )

                OutlinedTextField(
                    value = desc,
                    onValueChange = { desc = it },
                    label = { Text("وصف المنتج ومميزاته") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp)
                )

                OutlinedTextField(
                    value = priceStr,
                    onValueChange = { priceStr = it },
                    label = { Text("السعر (ريال يمني)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp)
                )

                // Category Selection
                Text("التصنيف:", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    categories.forEach { cat ->
                        FilterChip(
                            selected = category == cat,
                            onClick = { category = cat },
                            label = { Text(cat, fontSize = 11.sp) }
                        )
                    }
                }

                // Explicit No Stock Count Notice
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Text(
                        text = "ملاحظة: لا يوجد حقل للمخزون. يتم التحكم في توافر المنتج يدوياً بمفتاح التبديل بعد الاعتماد.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(8.dp)
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val price = priceStr.toDoubleOrNull() ?: 0.0
                    onSubmit(name, desc, price, category)
                },
                enabled = name.isNotBlank() && desc.isNotBlank() && (priceStr.toDoubleOrNull() ?: 0.0) > 0
            ) {
                Text("إرسال للمراجعة")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("إلغاء")
            }
        }
    )
}
