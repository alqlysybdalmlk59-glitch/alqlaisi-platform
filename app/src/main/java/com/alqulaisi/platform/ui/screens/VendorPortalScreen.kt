package com.alqulaisi.platform.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.alqulaisi.platform.data.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VendorPortalScreen(onLogout: () -> Unit) {
    var selectedTab by remember { mutableStateOf(0) }
    val products by EcommerceRepository.products.collectAsState()
    val orders by EcommerceRepository.orders.collectAsState()
    val vendors by EcommerceRepository.vendors.collectAsState()
    val currentUser by EcommerceRepository.currentUser.collectAsState()

    val myVendorStore = vendors.find { store ->
        store.ownerId == currentUser?.id || (store.ownerId.isBlank() && store.id == currentUser?.id)
    }
    val currentStoreId = myVendorStore?.id
    val myProducts = products.filter { it.vendorId == currentStoreId }
    val myOrders = orders.filter { it.vendorId == currentStoreId }

    var showAddProductDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(when(selectedTab) { 0 -> "لوحة تحكم البائع"; 1 -> "إدارة المنتجات"; 2 -> "طلبات المتجر" else -> "المبيعات والتقارير" }) },
                actions = {
                    IconButton(onClick = onLogout) {
                        Icon(Icons.Default.ExitToApp, contentDescription = "تسجيل خروج")
                    }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Dashboard, contentDescription = null) },
                    label = { Text("الرئيسية") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Inventory, contentDescription = null) },
                    label = { Text("المنتجات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.Assignment, contentDescription = null) },
                    label = { Text("الطلبات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Default.BarChart, contentDescription = null) },
                    label = { Text("المبيعات") }
                )
            }
        },
        floatingActionButton = {
            if (myVendorStore?.status == "مفعل") {
                FloatingActionButton(onClick = { showAddProductDialog = true }) {
                    Icon(Icons.Default.Add, contentDescription = "إضافة منتج جديد")
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (myVendorStore == null) {
                VendorStoreRequestView(
                    ownerName = currentUser?.name.orEmpty(),
                    onSubmit = { storeName, phone, description ->
                        EcommerceRepository.registerVendorStore(
                            storeName = storeName,
                            ownerName = currentUser?.name.orEmpty(),
                            phone = phone,
                            desc = description
                        )
                    }
                )
            } else if (myVendorStore.status != "مفعل") {
                Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Default.HourglassTop, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(16.dp))
                            Text("حالة المتجر: ${myVendorStore.status}", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                if (myVendorStore.status == "مرفوض") {
                                    "تم رفض طلب المتجر. راجع ملاحظة الإدارة قبل تقديم طلب جديد."
                                } else {
                                    "طلب فتح المتجر قيد المراجعة. ستتمكن من إدارة المنتجات والطلبات بعد اعتماد الإدارة."
                                },
                                fontSize = 14.sp
                            )
                            if (myVendorStore.adminNotes.isNotBlank()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text("ملاحظة الإدارة: ${myVendorStore.adminNotes}", color = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            } else {
                when (selectedTab) {
                    0 -> VendorDashboardOverview(myOrders, myProducts)
                    1 -> VendorProductsView(
                        products = myProducts,
                        onToggleAvailability = { EcommerceRepository.toggleProductAvailability(it) }
                    )
                    2 -> VendorOrdersView(
                        orders = myOrders,
                        onUpdateStatus = { orderId, status -> EcommerceRepository.updateOrderStatus(orderId, status) }
                    )
                    3 -> VendorSalesReportView(myOrders)
                }
            }

            if (showAddProductDialog) {
                AddProductDialog(onDismiss = { showAddProductDialog = false }) { title, price, desc, category ->
                    val store = myVendorStore ?: return@AddProductDialog
                    val newProduct = Product(
                        id = "p-${System.currentTimeMillis()}",
                        title = title,
                        description = desc,
                        price = 0.0,
                        imageUrl = "https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=500",
                        vendorId = store.id,
                        vendorName = store.storeName,
                        category = category,
                        isAvailable = false,
                        reviewStatus = ProductReviewStatus.PENDING_REVIEW,
                        purchasePrice = price.toDoubleOrNull()
                    )
                    if (EcommerceRepository.addProduct(newProduct)) {
                        showAddProductDialog = false
                    }
                }
            }
        }
    }
}

@Composable
fun VendorDashboardOverview(orders: List<Order>, products: List<Product>) {
    val totalRevenue = orders.filter { it.status == OrderStatus.COMPLETED }.sumOf { it.totalPrice }
    val totalOrders = orders.size
    val publishedCount = products.count { it.reviewStatus == ProductReviewStatus.PUBLISHED }
    val pendingCount = products.count { it.reviewStatus == ProductReviewStatus.PENDING_REVIEW }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Text("نظرة عامة على المتجر", fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Spacer(modifier = Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Card(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("إجمالي المبيعات", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        Text("$totalRevenue ر.ي", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.primary)
                    }
                }
                Card(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("إجمالي الطلبات", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        Text("$totalOrders", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Card(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("منتجات منشورة", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        Text("$publishedCount", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.primary)
                    }
                }
                Card(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("بانتظار المراجعة", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        Text("$pendingCount", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }

        item {
            Text("الطلبات الأخيرة", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }

        items(orders) { order ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("طلب رقم: ${order.id}", fontWeight = FontWeight.Bold)
                        Text(order.status.label, color = MaterialTheme.colorScheme.primary)
                    }
                    Text("العميل: ${order.clientName} | المبلغ: ${order.totalPrice} ر.ي", fontSize = 13.sp)
                }
            }
        }
    }
}

@Composable
fun VendorProductsView(products: List<Product>, onToggleAvailability: (String) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Text("إدارة منتجات المتجر", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        items(products) { product ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    AsyncImage(
                        model = product.imageUrl,
                        contentDescription = null,
                        modifier = Modifier.size(70.dp).clip(RoundedCornerShape(8.dp)),
                        contentScale = ContentScale.Crop
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(product.title, fontWeight = FontWeight.Bold)
                        if (product.reviewStatus == ProductReviewStatus.PENDING_REVIEW) {
                            Text("سعر الشراء للمراجعة: ${product.purchasePrice ?: "غير محدد"} ر.ي", fontSize = 13.sp, color = MaterialTheme.colorScheme.secondary)
                            Text("السعر النهائي تحدده الإدارة بعد المراجعة", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        } else {
                            Text("سعر البيع المعتمد: ${product.price} ر.ي", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
                        }
                        Text("حالة المراجعة: ${product.reviewStatus.name}", fontSize = 12.sp, color = MaterialTheme.colorScheme.secondary)
                        if (product.adminNotes.isNotBlank()) {
                            Text("ملاحظة الإدارة: ${product.adminNotes}", fontSize = 12.sp, color = MaterialTheme.colorScheme.error)
                        }
                        Text(
                            text = if (product.isAvailable) "الحالة: متاح" else "الحالة: غير متاح مؤقتاً",
                            fontSize = 12.sp,
                            color = if (product.isAvailable) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                        )
                    }
                    Switch(
                        checked = product.isAvailable,
                        onCheckedChange = { onToggleAvailability(product.id) },
                        enabled = product.reviewStatus == ProductReviewStatus.PUBLISHED
                    )
                }
            }
        }
    }
}

@Composable
fun VendorOrdersView(orders: List<Order>, onUpdateStatus: (String, OrderStatus) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Text("طلبات المتجر الواردة", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        items(orders) { order ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("رقم الطلب: ${order.id}", fontWeight = FontWeight.Bold)
                        Text(order.status.label, color = MaterialTheme.colorScheme.primary)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("العميل: ${order.clientName}")
                    Text("العنوان: ${order.address}")
                    Text("الإجمالي: ${order.totalPrice} ر.ي")
                    Spacer(modifier = Modifier.height(12.dp))
                    when (order.status) {
                        OrderStatus.PENDING -> Button(onClick = { onUpdateStatus(order.id, OrderStatus.ACCEPTED) }) {
                            Text("قبول الطلب وبدء التجهيز")
                        }
                        OrderStatus.ACCEPTED -> Button(onClick = { onUpdateStatus(order.id, OrderStatus.DELIVERING) }) {
                            Text("جاهز للتوصيل الداخلي")
                        }
                        OrderStatus.DELIVERING -> Text("الطلب لدى موظف التوصيل الداخلي")
                        OrderStatus.COMPLETED -> Text("تم استلام الطلب")
                        OrderStatus.CANCELLED -> Text("تم إلغاء الطلب", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }
}

@Composable
fun VendorSalesReportView(orders: List<Order>) {
    val completedOrders = orders.filter { it.status == OrderStatus.COMPLETED }
    val totalSales = completedOrders.sumOf { it.totalPrice }
    val completedCount = completedOrders.size
    val inProgressCount = orders.count {
        it.status == OrderStatus.PENDING || it.status == OrderStatus.ACCEPTED || it.status == OrderStatus.DELIVERING
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("تقارير المبيعات والأرباح", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(modifier = Modifier.height(16.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text("قيمة الطلبات التي اكتمل تسليمها", color = MaterialTheme.colorScheme.secondary)
                Text("$totalSales ر.ي", fontWeight = FontWeight.Bold, fontSize = 24.sp, color = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.height(12.dp))
                Text("الطلبات المكتملة: $completedCount")
                Text("الطلبات قيد التنفيذ: $inProgressCount")
                Text("العمولات غير محسوبة حتى تعتمد سياسة المنصة.")
            }
        }
    }
}

@Composable
fun AddProductDialog(onDismiss: () -> Unit, onAdd: (String, String, String, String) -> Unit) {
    var title by remember { mutableStateOf("") }
    var price by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("دفاتر وكراسات") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("إضافة منتج جديد للمتجر", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("اسم المنتج") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = price, onValueChange = { price = it }, label = { Text("سعر الشراء المتفق عليه (ر.ي) — ليس سعر البيع النهائي") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = description, onValueChange = { description = it }, label = { Text("وصف المنتج ومواصفاته") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = category, onValueChange = { category = it }, label = { Text("التصنيف") }, modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = {
            Button(onClick = { if (title.isNotBlank() && price.isNotBlank()) onAdd(title, price, description, category) }) {
                Text("إرسال المنتج للمراجعة")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("إلغاء") }
        }
    )
}


@Composable
fun VendorStoreRequestView(
    ownerName: String,
    onSubmit: (String, String, String) -> Boolean
) {
    var storeName by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            Icons.Default.Storefront,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Text("طلب فتح متجر في منصة القليسي", fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text(
            "أدخل بيانات متجرك. لن يظهر المتجر للعملاء ولن تتمكن من نشر المنتجات إلا بعد موافقة الإدارة.",
            color = MaterialTheme.colorScheme.secondary
        )
        OutlinedTextField(
            value = storeName,
            onValueChange = { storeName = it },
            label = { Text("اسم المتجر") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = ownerName,
            onValueChange = {},
            readOnly = true,
            label = { Text("اسم مالك الحساب") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = phone,
            onValueChange = { phone = it },
            label = { Text("رقم التواصل") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = description,
            onValueChange = { description = it },
            label = { Text("وصف المتجر والمنتجات التي يقدمها") },
            minLines = 3,
            modifier = Modifier.fillMaxWidth()
        )
        Button(
            enabled = storeName.isNotBlank() && phone.isNotBlank() && description.isNotBlank(),
            onClick = {
                val accepted = onSubmit(storeName.trim(), phone.trim(), description.trim())
                message = if (accepted) {
                    "تم إرسال طلب المتجر إلى الإدارة."
                } else {
                    "تعذر إرسال الطلب. تحقق من البيانات وحالة الحساب."
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("إرسال طلب المراجعة")
        }
        if (message.isNotBlank()) {
            Text(
                message,
                color = if (message.startsWith("تم")) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.error
            )
        }
    }
}
