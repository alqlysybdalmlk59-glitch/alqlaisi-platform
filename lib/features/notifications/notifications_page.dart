import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.token});
  final String token;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  late final ApiClient _api;
  Timer? _pollTimer;
  bool _loading = true;
  bool _requestInProgress = false;
  String? _error;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _api.close();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_requestInProgress) return;
    _requestInProgress = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _api.get('/orders/notifications/mine', token: widget.token);
      if (data is! List) throw const FormatException('Invalid orders response.');
      if (mounted) {
        setState(() {
          _orders = data.whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row)).toList();
          _error = null;
          _lastUpdated = DateTime.now();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل تحديثات الطلبات.');
    } finally {
      _requestInProgress = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String status) {
    if (status == 'تم التسليم') return Icons.check_circle_outline;
    if (status == 'ملغي') return Icons.cancel_outlined;
    if (status == 'قيد التوصيل') return Icons.local_shipping_outlined;
    if (status == 'قيد التجهيز' || status == 'جاهز للتوصيل') {
      return Icons.inventory_2_outlined;
    }
    return Icons.receipt_long_outlined;
  }

  String _lastUpdatedText() {
    final value = _lastUpdated;
    if (value == null) return 'لم يتم التحديث بعد';
    final local = value.toLocal();
    final date = local.toString();
    return 'آخر تحديث: ${date.substring(0, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading && _orders.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _orders.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _load(),
              child: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );
    } else if (_orders.isEmpty) {
      content = const Center(child: Text('لا توجد تحديثات بعد.'));
    } else {
      content = RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = _orders[index];
            final status = (order['status'] ?? 'بانتظار القبول').toString();
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: .1),
                  child: Icon(_icon(status), color: AppTheme.primary),
                ),
                title: Text('تحديث الطلب ${order['order_id'] ?? ''}'),
                subtitle: Text(
                  '${order['old_status'] == null ? 'تم إنشاء الطلب' : order['old_status']} ← $status\\n'
                  'المتجر: ${order['vendor_name'] ?? ''} · الإجمالي: ${order['total_price'] ?? 0} ريال\\n'
                  '${order['note'] ?? ''} · ${order['created_at'] ?? ''}',
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديثات الطلبات'),
        actions: [
          IconButton(
            tooltip: 'تحديث الآن',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          MaterialBanner(
            content: Text(
              'تُحدّث حالات الطلبات تلقائياً كل 30 ثانية أثناء فتح الصفحة. '
              'يعرض هذا السجل أحداث تغيير الحالة المحفوظة على الخادم؛ إشعارات نظام التشغيل Push غير مفعّلة بعد.\n${_lastUpdatedText()}',
            ),
            actions: const [SizedBox.shrink()],
          ),
          if (_error != null && _orders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'تعذر تحديث آخر حالة: $_error',
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
