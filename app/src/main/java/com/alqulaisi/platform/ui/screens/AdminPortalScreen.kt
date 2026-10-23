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
fun AdminPortalScreen(onLogout: () -> Unit) {
    var selectedTab by remember { mutableStateOf(0) }
    val vendors by EcommerceRepository.vendors.collectAsState()
    val products by EcommerceRepository.products.collectAsState()
    val orders by EcommerceRepository.orders.collectAsState()
    val supportTickets by EcommerceRepository.supportTickets.collectAsState()

    var aiQuery by remember { mutableStateOf("") }
    var aiResponse by remember { mutableStateOf("مرحباً بك في مساعد الذكاء الاصطناعي للإدارة. اسأل عن تحليل المبيعات أو تحسين أداء المنصة.") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(when(selectedTab) { 0 -> "المتاجر والمنتجات"; 1 -> "التوصيل والطلبات"; 2 -> "تذاكر الدعم والشكاوى"; else -> "مساعد التحليل المحلي" }) },
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
                    icon = { Icon(Icons.Default.Storefront, contentDescription = null) },
                    label = { Text("المتاجر والمنتجات") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.LocalShipping, contentDescription = null) },
                    label = { Text("التوصيل") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Default.ConfirmationNumber, contentDescription = null) },
                    label = { Text("الدعم") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Default.SmartToy, contentDescription = null) },
                    label = { Text("التحليلات") }
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (selectedTab) {
                0 -> AdminModerationView(
                    vendors = vendors,
                    products = products,
                    onApproveVendor = { EcommerceRepository.approveVendor(it) },
                    onRejectVendor = { id, notes -> EcommerceRepository.rejectVendor(id, notes) },
                    onApproveProduct = { id, price -> EcommerceRepository.approveProduct(id, price) },
                    onRejectProduct = { id, notes -> EcommerceRepository.rejectProduct(id, notes) }
                )
                1 -> AdminDeliveryOrdersView(
                    orders = orders,
                    onUpdateStatus = { id, status -> EcommerceRepository.updateOrderStatus(id, status) }
                )
                2 -> AdminSupportTicketsView(
                    tickets = supportTickets,
                    onRespond = { id, response -> EcommerceRepository.respondSupportTicket(id, response) }
                )
                3 -> AiAssistantView(
                    query = aiQuery,
                    response = aiResponse,
                    onQueryChange = { aiQuery = it },
                    onAsk = {
                        val completedOrders = orders.filter { it.status == OrderStatus.COMPLETED }
                        val completedValue = completedOrders.sumOf { it.totalPrice }
                        val pendingProducts = products.count { it.reviewStatus == ProductReviewStatus.PENDING_REVIEW }
                        val pendingStores = vendors.count { it.status == "قيد المراجعة" }
                        aiResponse = "ملخص محلي للبيانات التجريبية، وليس استجابة من Gemini: " +
                            "عدد الطلبات المكتملة ${completedOrders.size}، وقيمة الطلبات المكتملة ${completedValue} ر.ي، " +
                            "والمنتجات المعلقة ${pendingProducts}، وطلبات المتاجر المعلقة ${pendingStores}. " +
                            "لن تُعرض توقعات أو نسب نمو قبل ربط خدمة التحليلات ببيانات فعلية."
                    }
                )
            }
        }
    }
}

@Composable
fun AdminModerationView(
    vendors: List<VendorStore>,
    products: List<Product>,
    onApproveVendor: (String) -> Unit,
    onRejectVendor: (String, String) -> Unit,
    onApproveProduct: (String, Double) -> Unit,
    onRejectProduct: (String, String) -> Unit
) {
    val pendingProducts = products.filter { it.reviewStatus == ProductReviewStatus.PENDING_REVIEW }
    val pendingVendors = vendors.filter { it.status == "قيد المراجعة" }

    var selectedProductForApproval by remember { mutableStateOf<Product?>(null) }
    var salePriceText by remember { mutableStateOf("") }
    var selectedProductForRejection by remember { mutableStateOf<Product?>(null) }
    var productRejectNote by remember { mutableStateOf("") }
    var selectedVendorForRejection by remember { mutableStateOf<VendorStore?>(null) }
    var vendorRejectNote by remember { mutableStateOf("") }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Text("طلبات فتح المتاجر الجديدة", fontWeight = FontWeight.Bold, fontSize = 18.sp)
            if (pendingVendors.isEmpty()) {
                Text("لا توجد طلبات متاجر معلقة.", color = MaterialTheme.colorScheme.secondary)
            }
        }
        items(vendors) { vendor ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(vendor.storeName, fontWeight = FontWeight.Bold)
                    Text("المالك: ${vendor.ownerName} | ${vendor.phone}")
                    Text(
                        "الحالة: ${vendor.status}",
                        color = if (vendor.status == "مفعل") MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.error
                    )
                    if (vendor.adminNotes.isNotBlank()) {
                        Text("ملاحظة الإدارة: ${vendor.adminNotes}", color = MaterialTheme.colorScheme.error)
                    }
                    if (vendor.status == "قيد المراجعة") {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = { onApproveVendor(vendor.id) }) {
                                Text("اعتماد المتجر")
                            }
                            OutlinedButton(onClick = {
                                selectedVendorForRejection = vendor
                                vendorRejectNote = ""
                            }) {
                                Text("رفض الطلب")
                            }
                        }
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(8.dp))
            Text("المنتجات التي تنتظر المراجعة والتسعير", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        if (pendingProducts.isEmpty()) {
            item {
                Text("لا توجد منتجات قيد المراجعة حالياً", color = MaterialTheme.colorScheme.secondary, fontSize = 14.sp)
            }
        } else {
            items(pendingProducts) { product ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(product.title, fontWeight = FontWeight.Bold)
                        Text("المتجر: ${product.vendorName}")
                        Text("التصنيف: ${product.category}")
                        Text("سعر الشراء المتفق عليه: ${product.purchasePrice ?: "غير محدد"} ر.ي")
                        Text("سعر البيع النهائي: لم يُحدد بعد", color = MaterialTheme.colorScheme.secondary)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = {
                                selectedProductForApproval = product
                                salePriceText = ""
                            }) {
                                Text("تحديد السعر واعتماد")
                            }
                            OutlinedButton(onClick = {
                                selectedProductForRejection = product
                                productRejectNote = ""
                            }) {
                                Text("رفض المنتج")
                            }
                        }
                    }
                }
            }
        }
    }

    selectedProductForApproval?.let { product ->
        AlertDialog(
            onDismissRequest = { selectedProductForApproval = null },
            title = { Text("تحديد سعر البيع واعتماد المنتج") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(product.title, fontWeight = FontWeight.Bold)
                    Text("سعر الشراء المتفق عليه: ${product.purchasePrice ?: "غير محدد"} ر.ي")
                    OutlinedTextField(
                        value = salePriceText,
                        onValueChange = { value ->
                            if (value.isEmpty() || value.matches(Regex("^\\d{0,9}(\\.\\d{0,2})?$"))) {
                                salePriceText = value
                            }
                        },
                        label = { Text("سعر البيع للعميل (ريال يمني)") },
                        singleLine = true,
                        isError = salePriceText.isNotBlank() && (salePriceText.toDoubleOrNull() ?: 0.0) <= 0.0
                    )
                    Text("بعد الاعتماد سيبقى المنتج غير متاح حتى يفعّل البائع التوفر يدوياً.", color = MaterialTheme.colorScheme.secondary, fontSize = 12.sp)
                }
            },
            confirmButton = {
                Button(
                    enabled = (salePriceText.toDoubleOrNull() ?: 0.0) > 0.0,
                    onClick = {
                        val price = salePriceText.toDoubleOrNull()
                        if (price != null && price > 0.0) {
                            onApproveProduct(product.id, price)
                            selectedProductForApproval = null
                            salePriceText = ""
                        }
                    }
                ) { Text("اعتماد ونشر") }
            },
            dismissButton = {
                TextButton(onClick = { selectedProductForApproval = null }) { Text("إلغاء") }
            }
        )
    }

    selectedProductForRejection?.let { product ->
        AlertDialog(
            onDismissRequest = { selectedProductForRejection = null },
            title = { Text("رفض المنتج") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(product.title)
                    OutlinedTextField(
                        value = productRejectNote,
                        onValueChange = { productRejectNote = it },
                        label = { Text("سبب الرفض والملاحظات") },
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    enabled = productRejectNote.isNotBlank(),
                    onClick = {
                        onRejectProduct(product.id, productRejectNote.trim())
                        selectedProductForRejection = null
                        productRejectNote = ""
                    }
                ) { Text("تأكيد الرفض") }
            },
            dismissButton = {
                TextButton(onClick = { selectedProductForRejection = null }) { Text("إلغاء") }
            }
        )
    }

    selectedVendorForRejection?.let { vendor ->
        AlertDialog(
            onDismissRequest = { selectedVendorForRejection = null },
            title = { Text("رفض طلب المتجر") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(vendor.storeName, fontWeight = FontWeight.Bold)
                    OutlinedTextField(
                        value = vendorRejectNote,
                        onValueChange = { vendorRejectNote = it },
                        label = { Text("سبب الرفض والملاحظات") },
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    enabled = vendorRejectNote.isNotBlank(),
                    onClick = {
                        onRejectVendor(vendor.id, vendorRejectNote.trim())
                        selectedVendorForRejection = null
                        vendorRejectNote = ""
                    }
                ) { Text("تأكيد الرفض") }
            },
            dismissButton = {
                TextButton(onClick = { selectedVendorForRejection = null }) { Text("إلغاء") }
            }
        )
    }
}

@Composable
fun AdminDeliveryOrdersView(orders: List<Order>, onUpdateStatus: (String, OrderStatus) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(orders) { order ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("طلب #: ${order.id}", fontWeight = FontWeight.Bold)
                    Text("العميل: ${order.clientName} | العنوان: ${order.address}")
                    Text("المتجر: ${order.vendorName}")
                    Text("الحالة: ${order.status.label}", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))

                    if (order.status == OrderStatus.DELIVERING) {
                        Button(onClick = { onUpdateStatus(order.id, OrderStatus.COMPLETED) }) {
                            Text("تأكيد التسليم للعميل وتلقي المبلغ")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AdminSupportTicketsView(tickets: List<SupportTicket>, onRespond: (String, String) -> Unit) {
    var responseText by remember { mutableStateOf("") }
    var selectedTicketId by remember { mutableStateOf<String?>(null) }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(tickets) { ticket ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("تذكرة #: ${ticket.id}", fontWeight = FontWeight.Bold)
                    Text("من: ${ticket.userName} (${ticket.userRole})")
                    Text("العنوان: ${ticket.subject}", fontWeight = FontWeight.SemiBold)
                    Text("التفاصيل: ${ticket.details}")
                    Text("الحالة: ${ticket.status}", color = MaterialTheme.colorScheme.primary)
                    if (ticket.response.isNotBlank()) {
                        Text("الرد: ${ticket.response}", color = MaterialTheme.colorScheme.secondary)
                    } else {
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { selectedTicketId = ticket.id }) {
                            Text("الرد على التذكرة")
                        }
                    }
                }
            }
        }
    }

    selectedTicketId?.let { id ->
        AlertDialog(
            onDismissRequest = { selectedTicketId = null },
            title = { Text("الرد على طلب الدعم") },
            text = {
                OutlinedTextField(
                    value = responseText,
                    onValueChange = { responseText = it },
                    label = { Text("نص الرد والإجراء المتخذ") }
                )
            },
            confirmButton = {
                Button(onClick = {
                    if (responseText.isNotBlank()) {
                        onRespond(id, responseText)
                        selectedTicketId = null
                        responseText = ""
                    }
                }) { Text("حفظ وإغلاق") }
            },
            dismissButton = {
                TextButton(onClick = { selectedTicketId = null }) { Text("إلغاء") }
            }
        )
    }
}


@Composable
fun AiAssistantView(
    query: String,
    response: String,
    onQueryChange: (String) -> Unit,
    onAsk: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("مساعد التحليل المحلي", fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text(
            "يعرض هذا القسم ملخصاً من بيانات العرض التجريبية. لا توجد خدمة Gemini متصلة في هذه النسخة.",
            color = MaterialTheme.colorScheme.secondary
        )
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            label = { Text("اكتب سؤالاً عن مؤشرات المنصة") },
            placeholder = { Text("مثال: كم طلباً اكتمل؟") },
            minLines = 2,
            modifier = Modifier.fillMaxWidth()
        )
        Button(
            onClick = onAsk,
            enabled = query.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Default.Analytics, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("عرض ملخص البيانات التجريبية")
        }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("النتيجة", fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                Text(response)
            }
        }
    }
}
