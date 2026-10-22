import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../cart/services/cart_service.dart';
import '../orders/models/order_result.dart';
import '../orders/services/order_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.cartService, required this.token});

  final CartService cartService;
  final String token;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  late final ApiClient _apiClient;
  late final OrderService _orderService;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _orderService = OrderService(_apiClient);
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _apiClient.close();
    super.dispose();
  }

  String _money(num amount) {
    final rounded = amount.round();
    return '${rounded.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    )} ريال';
  }

  Future<void> _submitOrder() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final cart = widget.cartService;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة. أضف منتجات أولاً.')),
      );
      return;
    }
    if (cart.hasUnavailableItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أزل المنتجات غير المتوفرة قبل تأكيد الطلب.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final orders = await _orderService.checkout(
        cart: cart,
        token: widget.token,
        recipientName: _recipientController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        notes: _notesController.text,
      );
      if (!mounted) return;
      cart.clear();
      final closeCheckout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 44),
          title: const Text('تم إرسال طلبك بنجاح'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('قسّم الخادم مشترياتك إلى طلب مستقل لكل متجر:'),
                  const SizedBox(height: 12),
                  ...orders.map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم الطلب: ${order.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('الإجمالي مع التوصيل: ${_money(order.total)}'),
                            Text('الحالة: ${order.status}'),
                          ],
                        )),
                      ],
                    ),
                  )),
                  const Text('الدفع نقدًا عند الاستلام، بعد تأكيد الطلب من المنصة.'),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      if (mounted && closeCheckout == true) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تأكيد الطلب. تحقق من الاتصال وحاول مجددًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cartService;
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الطلب')),
      body: cart.isEmpty
          ? const Center(child: Text('السلة فارغة. أضف منتجات أولاً.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('عنوان التوصيل', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recipientController,
                    decoration: const InputDecoration(labelText: 'اسم المستلم', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().length < 2 ? 'أدخل اسم المستلم.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: (v) => v == null || v.trim().length < 9 ? 'تحقق من رقم الهاتف (9 أرقام على الأقل).' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'العنوان بالتفصيل', hintText: 'المدينة، الحي، الشارع، وأقرب معلم', prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) => v == null || v.trim().length < 5 ? 'أدخل عنوان التوصيل بالتفصيل.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظات التوصيل (اختياري)', prefixIcon: Icon(Icons.notes_outlined)),
                  ),
                  const SizedBox(height: 24),
                  Text('المنتجات حسب المتجر', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ...cart.itemsByStore.entries.map((entry) {
                    final items = entry.value;
                    final storeName = items.first.product.storeName;
                    final storeTotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(storeName.isEmpty ? 'متجر' : storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Divider(),
                            ...items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(children: [
                                Expanded(child: Text('${item.product.name} × ${item.quantity}')),
                                Text(_money(item.lineTotal)),
                              ]),
                            )),
                            const Divider(),
                            Row(children: [
                              const Expanded(child: Text('المجموع الفرعي')),
                              Text(_money(storeTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _SummaryRow(label: 'المجموع الفرعي', value: _money(cart.subtotal)),
                        const SizedBox(height: 8),
                        const _SummaryRow(label: 'رسوم التوصيل', value: 'يحسبها الخادم لكل متجر'),
                        const Divider(height: 24),
                        _SummaryRow(label: 'الإجمالي النهائي', value: 'يؤكد بعد مراجعة الخادم', bold: true),
                        const SizedBox(height: 6),
                        const Text('ستظهر الإجماليات النهائية لكل متجر بعد احتساب الرسوم المعتمدة من الخادم.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('طريقة الدفع', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  const Card(child: ListTile(
                    leading: Icon(Icons.payments_outlined, color: AppTheme.primary),
                    title: Text('الدفع عند الاستلام'),
                    subtitle: Text('تدفع عند استلام الطلب وفق إجراءات المنصة.'),
                    trailing: Icon(Icons.check_circle, color: AppTheme.primary),
                  )),
                  if (cart.hasUnavailableItems) ...[
                    const SizedBox(height: 12),
                    const Text('توجد منتجات غير متوفرة. ارجع إلى السلة وأزلها قبل المتابعة.',
                      style: TextStyle(color: AppTheme.error)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _submitting || cart.hasUnavailableItems ? null : _submitOrder,
                    icon: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_outline),
                    label: Text(_submitting ? 'جارٍ تأكيد الطلب...' : 'تأكيد الطلب'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? AppTheme.primary : null);
    return Row(children: [
      Expanded(child: Text(label, style: style)),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: style)),
    ]);
  }
}
