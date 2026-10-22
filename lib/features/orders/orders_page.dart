import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.token});
  final String token;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final ApiClient _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  final Map<String, Future<List<Map<String, dynamic>>>> _historyFutures = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _reviewFutures = {};

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _historyFutures.clear();
      _reviewFutures.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final me = await _api.get('/auth/me', token: widget.token);
      if (me is! Map || (me['id'] ?? '').toString().isEmpty) {
        throw const FormatException('Invalid current-user response.');
      }
      final result = await _api.get(
        '/orders/client/${Uri.encodeComponent(me['id'].toString())}',
        token: widget.token,
      );
      if (result is! List) throw const FormatException('Invalid orders response.');
      if (mounted) {
        setState(() => _orders = result.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item)).toList());
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل الطلبات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadHistory(String orderId) async {
    final result = await _api.get(
      '/orders/${Uri.encodeComponent(orderId)}/history',
      token: widget.token,
    );
    if (result is! List) throw const FormatException('Invalid order history response.');
    return result.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<List<Map<String, dynamic>>> _historyFuture(String orderId) =>
      _historyFutures.putIfAbsent(orderId, () => _loadHistory(orderId));


  Future<List<Map<String, dynamic>>> _loadReviews(String orderId) async {
    final result = await _api.get(
      '/orders/${Uri.encodeComponent(orderId)}/reviews',
      token: widget.token,
    );
    if (result is! List) throw const FormatException('Invalid reviews response.');
    return result.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> _reviewsFor(String orderId) =>
      _reviewFutures.putIfAbsent(orderId, () => _loadReviews(orderId));

  Widget _reviewSection(String orderId, String productId, String productName, bool delivered) {
    if (!delivered) {
      return const Padding(
        padding: EdgeInsets.only(right: 16, bottom: 8),
        child: Text('يمكن تقييم المنتج بعد تسليم الطلب فقط.',
            style: TextStyle(color: AppTheme.muted)),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviewsFor(orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(() => _reviewFutures.remove(orderId)),
            child: const Text('تعذر تحميل التقييم؛ اضغط لإعادة المحاولة'),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: LinearProgressIndicator(),
          );
        }
        Map<String, dynamic>? existing;
        for (final review in snapshot.data ?? const <Map<String, dynamic>>[]) {
          if (review['product_id']?.toString() == productId) {
            existing = review;
            break;
          }
        }
        if (existing != null) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.star, color: Colors.amber),
            title: Text('تقييمك: ${existing['rating']}/5'),
            subtitle: Text((existing['comment'] ?? '').toString()),
          );
        }
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showReviewDialog(orderId, productId, productName),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('تقييم المنتج'),
          ),
        );
      },
    );
  }

  Future<void> _showReviewDialog(String orderId, String productId, String productName) async {
    int rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('تقييم $productName'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('التقييم متاح بعد استلام الطلب وتسجيله كـ «تم التسليم».'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: rating,
                  decoration: const InputDecoration(labelText: 'التقييم'),
                  items: List.generate(5, (index) {
                    final value = 5 - index;
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value / 5 ${List.filled(value, '★').join()}'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => rating = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: comment,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'تعليق اختياري',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('إرسال التقييم'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      try {
        await _api.post(
          '/orders/${Uri.encodeComponent(orderId)}/reviews',
          token: widget.token,
          body: {
            'product_id': productId,
            'rating': rating,
            'comment': comment.text.trim(),
          },
        );
        _reviewFutures.remove(orderId);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ تقييمك للمنتج.')),
          );
        }
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر حفظ التقييم؛ لم يتم تأكيد التغيير.')),
          );
        }
      }
    }
    comment.dispose();
  }

  String _status(String value) => value.isEmpty ? 'قيد المعالجة' : value;

  String _date(String value) {
    try {
      return DateTime.parse(value).toLocal().toString().substring(0, 16);
    } catch (_) {
      return value;
    }
  }

  Widget _historyWidget(String orderId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('تعذر تحميل سجل الحالة: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error)),
          );
        }
        final history = snapshot.data ?? const <Map<String, dynamic>>[];
        if (history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('لا يوجد سجل حالة محفوظ لهذا الطلب القديم.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text('سجل تغييرات الحالة',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...history.map((entry) {
              final oldStatus = entry['old_status'] == null
                  ? 'إنشاء الطلب'
                  : entry['old_status'].toString();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, color: AppTheme.primary),
                title: Text('$oldStatus ← ${entry['new_status'] ?? ''}'),
                subtitle: Text(
                  '${_date((entry['created_at'] ?? '').toString())}\n'
                  'بواسطة: ${entry['changed_by_role'] ?? ''} · ${entry['note'] ?? ''}',
                ),
                isThreeLine: true,
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading && _orders.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _orders.isEmpty) {
      content = ListView(children: [
        const SizedBox(height: 100),
        Center(child: Text(_error!)),
        const SizedBox(height: 12),
        Center(child: FilledButton(onPressed: _load, child: const Text('إعادة المحاولة'))),
      ]);
    } else if (_orders.isEmpty) {
      content = ListView(children: [
        const SizedBox(height: 140),
        Icon(Icons.receipt_long_outlined, size: 58, color: AppTheme.muted),
        const SizedBox(height: 12),
        const Center(child: Text('لا توجد طلبات حتى الآن.')),
      ]);
    } else {
      content = ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = _orders[index];
          final orderId = (order['id'] ?? '').toString();
          List<dynamic> items = [];
          try {
            final parsed = jsonDecode((order['items_json'] ?? '[]').toString());
            if (parsed is List) items = parsed;
          } catch (_) {}
          final total = (order['total_price'] as num?)?.toDouble() ?? 0;
          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.receipt_long, color: AppTheme.primary),
              title: Text('طلب $orderId'),
              subtitle: Text(
                '${_status((order['status'] ?? '').toString())} · '
                'الإجمالي ${total.toStringAsFixed(0)} ريال',
              ),
              onExpansionChanged: (expanded) {
                if (expanded) {
                  setState(() { _historyFuture(orderId); });
                }
              },
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('المتجر: ${order['vendor_name'] ?? ''}'),
                ),
                const SizedBox(height: 6),
                ...items.whereType<Map>().map((item) {
                  final productId = (item['product_id'] ?? '').toString();
                  final productName = (item['title'] ?? 'منتج').toString();
                  final delivered = (order['status'] ?? '').toString() == 'تم التسليم';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        dense: true,
                        title: Text(productName),
                        subtitle: Text('الكمية: ${item['quantity'] ?? 1}'),
                        trailing: Text('${item['line_total'] ?? 0} ريال'),
                      ),
                      if (productId.isNotEmpty)
                        _reviewSection(orderId, productId, productName, delivered),
                    ],
                  );
                }),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('التوصيل: ${order['delivery_fee'] ?? 0} ريال'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('طريقة الدفع: ${order['payment_method'] ?? 'الدفع عند الاستلام'}'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('العنوان: ${order['address'] ?? ''}'),
                ),
                _historyWidget(orderId),
              ],
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(onRefresh: _load, child: content),
    );
  }
}
