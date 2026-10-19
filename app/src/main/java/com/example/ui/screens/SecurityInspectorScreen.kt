package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.PlatformRepository
import com.example.model.PenetrationTestResult
import com.example.ui.theme.StatusError
import com.example.ui.theme.StatusSuccess
import com.example.ui.theme.StatusWarning

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SecurityInspectorScreen(
    repository: PlatformRepository,
    modifier: Modifier = Modifier
) {
    val currentUser by repository.currentUser.collectAsState()
    val auditLogs by repository.auditLogs.collectAsState()

    var activeInspectorTab by remember { mutableStateOf(0) } // 0: Pen Tests, 1: Live JWT Claims, 2: Server Audit Trail, 3: Python Code
    var testResult by remember { mutableStateOf<PenetrationTestResult?>(null) }

    Scaffold(
        topBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
            ) {
                TabRow(
                    selectedTabIndex = activeInspectorTab,
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.primary
                ) {
                    Tab(
                        selected = activeInspectorTab == 0,
                        onClick = { activeInspectorTab = 0 },
                        text = { Text("مختبر الاختراق", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Security, contentDescription = "Security Tests") },
                        modifier = Modifier.testTag("sec_tab_tests")
                    )
                    Tab(
                        selected = activeInspectorTab == 1,
                        onClick = { activeInspectorTab = 1 },
                        text = { Text("توكن JWT", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Key, contentDescription = "JWT") },
                        modifier = Modifier.testTag("sec_tab_jwt")
                    )
                    Tab(
                        selected = activeInspectorTab == 2,
                        onClick = { activeInspectorTab = 2 },
                        text = { Text("سجل الأمان (${auditLogs.size})", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.HistoryEdu, contentDescription = "Audit") },
                        modifier = Modifier.testTag("sec_tab_audit")
                    )
                    Tab(
                        selected = activeInspectorTab == 3,
                        onClick = { activeInspectorTab = 3 },
                        text = { Text("كود FastAPI", fontWeight = FontWeight.Bold) },
                        icon = { Icon(Icons.Default.Code, contentDescription = "Code") },
                        modifier = Modifier.testTag("sec_tab_code")
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
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                // Header Banner
                item {
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(16.dp)
                        ) {
                            Icon(Icons.Default.Shield, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(36.dp))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = "مفتش الأمان والوسيط البرمجي (RBAC Inspector)",
                                    fontWeight = FontWeight.ExtraBold,
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Text(
                                    text = "فحص حي لمعمارية FastAPI AccessControlMiddleware وعزل صلاحيات العميل والبائع والإدارة.",
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                        }
                    }
                }

                when (activeInspectorTab) {
                    0 -> {
                        // Interactive Penetration Tests
                        item {
                            Text(
                                text = "اختبارات كفاءة الوسيط وقواعد الأمان السحابية",
                                fontWeight = FontWeight.Bold,
                                style = MaterialTheme.typography.titleMedium
                            )
                        }

                        item {
                            Card(
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    verticalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Text("اختر هجمة أو سيناريو لاختبار رد فعل الوسيط الخادمي:", fontWeight = FontWeight.SemiBold)

                                    // Attack 1: Customer calls Admin
                                    Button(
                                        onClick = { testResult = repository.runPenetrationTest(1) },
                                        colors = ButtonDefaults.buttonColors(containerColor = StatusError),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("test_attack_admin_route")
                                    ) {
                                        Icon(Icons.Default.Block, contentDescription = null)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text("1. محاولة عميل الوصول لمسار الإدارة /api/admin", fontWeight = FontWeight.Bold)
                                    }

                                    // Attack 2: Cross-Tenant Seller Hijack
                                    Button(
                                        onClick = { testResult = repository.runPenetrationTest(2) },
                                        colors = ButtonDefaults.buttonColors(containerColor = StatusWarning),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("test_cross_tenant_hijack")
                                    ) {
                                        Icon(Icons.Default.SecurityUpdateWarning, contentDescription = null)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text("2. محاولة بائع التعديل على متجر بائع آخر (Cross-Tenant)", fontWeight = FontWeight.Bold)
                                    }

                                    // Attack 3: Unauthenticated / Missing Token
                                    Button(
                                        onClick = { testResult = repository.runPenetrationTest(3) },
                                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("test_unauthenticated_request")
                                    ) {
                                        Icon(Icons.Default.KeyOff, contentDescription = null)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text("3. طلب مسار محمي بدون توكن توثيق (401 Unauthorized)", fontWeight = FontWeight.Bold)
                                    }

                                    // Attack 4: Review before delivery
                                    Button(
                                        onClick = { testResult = repository.runPenetrationTest(4) },
                                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("test_review_before_delivery")
                                    ) {
                                        Icon(Icons.Default.RateReview, contentDescription = null)
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text("4. محاولة تقييم منتج لطلب ما زال قيد التجهيز", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }

                        // Test Execution Result Card
                        testResult?.let { res ->
                            item {
                                Card(
                                    shape = RoundedCornerShape(14.dp),
                                    colors = CardDefaults.cardColors(
                                        containerColor = if (res.passed) StatusSuccess.copy(alpha = 0.12f) else StatusError.copy(alpha = 0.12f)
                                    ),
                                    border = CardDefaults.outlinedCardBorder().copy(
                                        brush = androidx.compose.ui.graphics.SolidColor(if (res.passed) StatusSuccess else StatusError)
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
                                                Icon(
                                                    if (res.passed) Icons.Default.CheckCircle else Icons.Default.Cancel,
                                                    contentDescription = null,
                                                    tint = if (res.passed) StatusSuccess else StatusError
                                                )
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Text(
                                                    "نتيجة الاختبار: ${if (res.passed) "نجح الحظر والحماية ✓" else "فشل الأمان ✗"}",
                                                    fontWeight = FontWeight.ExtraBold,
                                                    color = if (res.passed) StatusSuccess else StatusError
                                                )
                                            }
                                            Text("رمز: ${res.actualStatus}", fontWeight = FontWeight.Bold)
                                        }

                                        Spacer(modifier = Modifier.height(10.dp))
                                        Text("الهدف: ${res.testName}", fontWeight = FontWeight.Bold)
                                        Text("المسار المستهدف: ${res.targetEndpoint}", style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace)
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text("تحليل الوسيط: ${res.reasonAr}", style = MaterialTheme.typography.bodySmall)
                                    }
                                }
                            }
                        }
                    }

                    1 -> {
                        // Current Session JWT Claims
                        item {
                            Text("بيانات جلسة الدخول النشطة وتوكن التوثيق", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                        }

                        item {
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
                                        Text(currentUser.fullName, fontWeight = FontWeight.ExtraBold, style = MaterialTheme.typography.titleMedium)
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = MaterialTheme.colorScheme.primaryContainer
                                        ) {
                                            Text(
                                                text = currentUser.role.labelAr,
                                                fontWeight = FontWeight.Bold,
                                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text("البريد الإلكتروني: ${currentUser.email}", style = MaterialTheme.typography.bodySmall)
                                    Text("معرف المستخدم (sub): ${currentUser.id}", style = MaterialTheme.typography.bodySmall)
                                    Text("معرف المتجر التابع له: ${currentUser.storeId ?: "لا يوجد (عميل أو إدارة)"}", style = MaterialTheme.typography.bodySmall)
                                    Text("حالة الحساب: ${currentUser.status.labelAr}", style = MaterialTheme.typography.bodySmall)

                                    Divider(modifier = Modifier.padding(vertical = 12.dp))

                                    Text("حمولة توكن JWT الخادمي (Decoded Claims):", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodySmall)
                                    Spacer(modifier = Modifier.height(6.dp))

                                    val claimsJson = """
                                        {
                                          "sub": "${currentUser.id}",
                                          "email": "${currentUser.email}",
                                          "role": "${currentUser.role.name.lowercase()}",
                                          "store_id": ${currentUser.storeId ?: "null"},
                                          "status": "${currentUser.status.name.lowercase()}",
                                          "exp": 1792400000,
                                          "iat": 1792313600
                                        }
                                    """.trimIndent()

                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = Color(0xFF1E1E1E),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(
                                            text = claimsJson,
                                            color = Color(0xFF4EC9B0),
                                            fontFamily = FontFamily.Monospace,
                                            fontSize = 12.sp,
                                            modifier = Modifier.padding(12.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    2 -> {
                        // Audit Logs
                        item {
                            Text("سجل أحداث الأمان والوسيط الخادمي (Real-time Audit Trail)", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                        }

                        items(auditLogs, key = { it.id }) { log ->
                            Card(
                                shape = RoundedCornerShape(12.dp),
                                colors = CardDefaults.cardColors(
                                    containerColor = if (log.isAllowed) MaterialTheme.colorScheme.surface else StatusError.copy(alpha = 0.08f)
                                ),
                                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(
                                                if (log.isAllowed) Icons.Default.CheckCircleOutline else Icons.Default.HighlightOff,
                                                contentDescription = null,
                                                tint = if (log.isAllowed) StatusSuccess else StatusError,
                                                modifier = Modifier.size(18.dp)
                                            )
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text(log.action, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                                        }
                                        Text(log.timestamp, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
                                    }

                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        "${log.statusCode}  |  ${log.path}  |  دور: ${log.role}",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontFamily = FontFamily.Monospace,
                                        color = if (log.isAllowed) MaterialTheme.colorScheme.primary else StatusError
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(log.detailsAr, style = MaterialTheme.typography.bodySmall)
                                }
                            }
                        }
                    }

                    3 -> {
                        // Python FastAPI Source Code Viewer
                        item {
                            Text("كود نموذج المستخدم والوسيط الأمني المعتمد في المشروع", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                        }

                        item {
                            val codeSnippet = """
# backend/app/models/user.py
class UserRole(str, Enum):
    CUSTOMER = "customer"
    SELLER = "seller"
    ADMIN = "admin"

class AccessControlMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 1. Block unauthorized access to /api/admin
        if request.url.path.startswith("/api/admin"):
            if user_role != UserRole.ADMIN:
                return create_security_error(403, "ADMIN_REQUIRED")
        # 2. Block unauthorized access to /api/seller
        if request.url.path.startswith("/api/seller"):
            if user_role not in [UserRole.SELLER, UserRole.ADMIN]:
                return create_security_error(403, "SELLER_REQUIRED")
        return await call_next(request)

def verify_seller_store_ownership(store_id: int, current_user: dict):
    if current_user.get("role") != "admin":
        if current_user.get("store_id") != store_id:
            raise HTTPException(403, "Cross-tenant access forbidden!")
                            """.trimIndent()

                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = Color(0xFF1E1E1E),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Box(
                                    modifier = Modifier
                                        .horizontalScroll(rememberScrollState())
                                        .padding(14.dp)
                                ) {
                                    Text(
                                        text = codeSnippet,
                                        color = Color(0xFFCE9178),
                                        fontFamily = FontFamily.Monospace,
                                        fontSize = 12.sp
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
