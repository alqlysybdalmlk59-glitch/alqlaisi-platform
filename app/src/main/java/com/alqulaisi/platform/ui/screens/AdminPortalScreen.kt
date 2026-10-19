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
                title = { Text(when(selectedTab) { 0 -> "المتاجر والمنتجات"; 1 -> "التوصيل والطلبات"; 2 -> "تذاكر الدعم والشكاوى"; else -> "مساعد Gemini AI والرؤى" }) },
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
                    label = { Text("الذكاء الاصطناعي") }
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
                    onApproveProduct = { EcommerceRepository.approveProduct(it) }
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
                        aiResponse = "تحليل الذكاء الاصطناعي (Gemini AI): أداء المبيعات ممتاز هذا الأسبوع مع نمو بنسبة 22% في قطاع الإلكترونيات والأزياء. يُنصح بتقديم عروض ترويجية للبائعين الجدد."
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
    onApproveProduct: (String) -> Unit
) {
    val pendingProducts = products.filter { it.reviewStatus == ProductReviewStatus.PENDING_REVIEW }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Text("طلبات فتح المتاجر الجديدة", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        items(vendors) { vendor ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(vendor.storeName, fontWeight = FontWeight.Bold)
                        Text("المالك: ${vendor.ownerName} | ${vendor.phone}")
                        Text("الحالة: ${vendor.status}", color = if (vendor.status == "مفعل") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
                    }
                    if (vendor.status != "مفعل") {
                        Button(onClick = { onApproveVendor(vendor.id) }) {
                            Text("تفعيل المتجر")
                        }
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(8.dp))
            Text("المنتجات المعلقة والمعروضة للمراجعة", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        if (pendingProducts.isEmpty()) {
            item {
                Text("لا توجد منتجات قيد المراجعة حالياً", color = MaterialTheme.colorScheme.secondary, fontSize = 14.sp)
            }
        } else {
            items(pendingProducts) { product ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(product.title, fontWeight = FontWeight.Bold)
                            Text("المتجر: ${product.vendorName} | السعر: ${product.price} ر.ي")
                        }
                        Button(onClick = { onApproveProduct(product.id) }) {
                            Text("اعتماد ونشر")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AdminDeliveryOrdersView(orders: List<Order>, onUpdateStatus: (String, String) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(orders) { order ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("طلب #: ${order.id}", fontWeight = FontWeight.Bold)
                    Text("العميل: ${order.clientName} | العنوان: ${order.address}")
                    Text("المتجر: ${order.vendorName}")
                    Text("الحالة: ${order.status}", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))

                    if (order.status == "للتوصيل") {
                        Button(onClick = { onUpdateStatus(order.id, "تم الاستلام") }) {
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
