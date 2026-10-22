import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.token});
  final String token;
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}
class _NotificationsPageState extends State<NotificationsPage> {
  late final ApiClient _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  @override void initState() { super.initState(); _api = ApiClient(); _load(); }
  @override void dispose() { _api.close(); super.dispose(); }
  @override void didUpdateWidget(covariant NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _load();
  }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = await _api.get('/auth/me', token: widget.token);
      if (user is! Map || (user['id'] ?? '').toString().isEmpty) throw const FormatException();
      final data = await _api.get('/orders/client/${Uri.encodeComponent(user['id'].toString())}', token: widget.token);
      if (data is! List) throw const FormatException();
      if (mounted) setState(() => _orders = data.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row)).toList());
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل تحديثات الطلبات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  IconData _icon(String status) {
    if (status == 'تم التسليم') return Icons.check_circle_outline;
    if (status == 'ملغي') return Icons.cancel_outlined;
    if (status == 'قيد التوصيل') return Icons.local_shipping_outlined;
    if (status == 'قيد التجهيز' || status == 'جاهز للتوصيل') return Icons.inventory_2_outlined;
    return Icons.receipt_long_outlined;
  }
  @override Widget build(BuildContext context) {
    Widget content;
    if (_loading && _orders.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _orders.isEmpty) {
      content = Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ],
      )));
    } else if (_orders.isEmpty) {
      content = const Center(child: Text('لا توجد تحديثات بعد.'));
    } else {
      content = RefreshIndicator(onRefresh: _load, child: ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = _orders[index];
          final status = (order['status'] ?? 'بانتظار القبول').toString();
          return Card(child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: .1),
              child: Icon(_icon(status), color: AppTheme.primary)),
            title: Text('تحديث الطلب ${order['id'] ?? ''}'),
            subtitle: Text('المتجر: ${order['vendor_name'] ?? ''}\nالحالة الحالية: $status\nالإجمالي: ${order['total_price'] ?? 0} ريال'),
            isThreeLine: true,
          ));
        },
      ));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('تحديثات الطلبات'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        const MaterialBanner(
          content: Text('تعرض هذه الصفحة أحدث حالات الطلبات من الخادم؛ إشعارات الدفع الفوري غير مفعلة بعد.'),
          actions: [SizedBox.shrink()],
        ),
        Expanded(child: content),
      ]),
    );
  }
}
