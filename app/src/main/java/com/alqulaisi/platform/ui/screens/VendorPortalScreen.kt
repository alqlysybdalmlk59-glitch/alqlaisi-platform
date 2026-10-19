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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alqulaisi.platform.data.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VendorPortalScreen(onLogout: () -> Unit) {
    var selectedTab by remember { mutableStateOf(0) }
    val products by EcommerceRepository.products.collectAsState()
    val orders by EcommerceRepository.orders.collectAsState()
    val vendors by EcommerceRepository.vendors.collectAsState()
    val currentUser by EcommerceRepository.currentUser.collectAsState()

    val myVendorStore = vendors.find { it.id == "v1" }
    val myProducts = products.filter { it.vendorId == "v1" }
    val myOrders = orders.filter { it.vendorId == "v1" }

    var showAddProductDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(when(selectedTab) { 0 -> "منتجات المتجر"; 1 -> "طلبات المتجر الواردة"; else -> "تقارير المبيعات والدعم" }) },
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
                    icon = { Icon(Icons.Default.Inventory, contentDescription = null) },
                    label = { Text("المنتجات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Assignment, contentDescription = null) },
                    label = { Text("الطلبات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.BarChart, contentDescription = null) },
                    label = { Text("المبيعات") }
                )
            }
        },
        floatingActionButton = {
            if (selectedTab == 0 && myVendorStore?.status == "مفعل") {
                FloatingActionButton(onClick = { showAddProductDialog = true }) {
                    Icon(Icons.Default.Add, contentDescription = "إضافة منتج")
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (myVendorStore?.status != "مفعل") {
                Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Default.HourglassTop, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(16.dp))
                            Text("حالة المتجر: ${myVendorStore?.status ?: "قيد المراجعة"}", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("طلب فتح المتجر قيد المراجعة من قبل إدارة منصة القليسي. ستتمكن من إضافة وتعديل المنتجات فور الموافقة.", fontSize = 14.sp)
                        }
                    }
                }
            } else {
                when (selectedTab) {
                    0 -> VendorProductsView(
                        products = myProducts,
                        onToggleAvailability = { EcommerceRepository.toggleProductAvailability(it) }
                    )
                    1 -> VendorOrdersView(
                        orders = myOrders,
                        onUpdateStatus = { orderId, status -> EcommerceRepository.updateOrderStatus(orderId, status) }
                    )
                    2 -> VendorSalesReportView(myOrders)
                }
            }

            if (showAddProductDialog) {
                AddProductDialog(onDismiss = { showAddProductDialog = false }) { title, price, desc, category ->
                    val newProduct = Product(
                        id = "p-${System.currentTimeMillis()}",
                        title = title,
                        description = desc,
                        price = price.toDoubleOrNull() ?: 50.0,
                        imageUrl = "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500",
                        vendorId = "v1",
                        vendorName = myVendorStore?.storeName ?: "متجر التقنية",
                        category = category,
                        isAvailable = true,
                        reviewStatus = ProductReviewStatus.PENDING_REVIEW
                    )
                    EcommerceRepository.addProduct(newProduct)
                    showAddProductDialog = false
                }
            }
        }
    }
}

@Composable
fun VendorProductsView(products: List<Product>, onToggleAvailability: (String) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(products) { product ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(product.title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(
                            text = when(product.reviewStatus) {
                                ProductReviewStatus.PUBLISHED -> "منشور"
                                ProductReviewStatus.PENDING_REVIEW -> "قيد المراجعة الإدارية"
                                ProductReviewStatus.REJECTED -> "مرفوض"
                                ProductReviewStatus.DRAFT -> "مسودة"
                            },
                            fontSize = 12.sp,
                            color = if (product.reviewStatus == ProductReviewStatus.PUBLISHED) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("السعر: ${product.price} ر.ي | التصنيف: ${product.category}", fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("حالة التوفر اليدوي:")
                        Switch(
                            checked = product.isAvailable,
                            onCheckedChange = { onToggleAvailability(product.id) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun VendorOrdersView(orders: List<Order>, onUpdateStatus: (String, String) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(orders) { order ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("طلب #: ${order.id}", fontWeight = FontWeight.Bold)
                    Text("العميل: ${order.clientName}")
                    Text("المبلغ المطلوب: ${order.itemsPrice} ر.ي")
                    Text("الحالة الحالية: ${order.status}", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (order.status == "بانتظار القبول") {
                            Button(onClick = { onUpdateStatus(order.id, "مقبولة وقيد التجهيز") }) {
                                Text("قبول الطلب وتجهيزه")
                            }
                        }
                        if (order.status == "مقبولة وقيد التجهيز") {
                            Button(onClick = { onUpdateStatus(order.id, "للتوصيل") }) {
                                Text("تسليم موظف التوصيل")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun VendorSalesReportView(orders: List<Order>) {
    val completedOrders = orders.filter { it.status == "تم الاستلام" }
    val totalSales = completedOrders.sumOf { it.itemsPrice }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("إجمالي قيمة المبيعات المكتملة", fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                Text("$totalSales ر.ي", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("عدد الطلبات المكتملة", fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                Text("${completedOrders.size} طلبات", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun AddProductDialog(onDismiss: () -> Unit, onAdd: (String, String, String, String) -> Unit) {
    var title by remember { mutableStateOf("") }
    var price by remember { mutableStateOf("") }
    var desc by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("إلكترونيات") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("إضافة منتج جديد للمراجعة") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("اسم المنتج") })
                OutlinedTextField(value = price, onValueChange = { price = it }, label = { Text("السعر (ر.ي)") })
                OutlinedTextField(value = desc, onValueChange = { desc = it }, label = { Text("الوصف التفصيلي") })
                OutlinedTextField(value = category, onValueChange = { category = it }, label = { Text("التصنيف") })
            }
        },
        confirmButton = {
            Button(onClick = { if (title.isNotBlank() && price.isNotBlank()) onAdd(title, price, desc, category) }) {
                Text("إرسال للمراجعة")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("إلغاء") }
        }
    )
}
