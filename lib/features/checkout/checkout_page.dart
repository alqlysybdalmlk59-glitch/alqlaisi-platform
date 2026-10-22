import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../cart/services/cart_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.cartService,
  });

  final CartService cartService;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _money(int amount) {
    return '${amount.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        )} ريال';
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cartService;

    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الطلب')),
      body: cart.isEmpty
          ? const Center(child: Text('السلة فارغة. أضف منتجات أولًا.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'عنوان التوصيل',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recipientController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستلم',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل اسم المستلم.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل رقم الهاتف.';
                      }
                      if (value.trim().length < 9) {
                        return 'تحقق من رقم الهاتف.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'العنوان بالتفصيل',
                      hintText: 'المدينة، الحي، الشارع، وأقرب معلم',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل عنوان التوصيل.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات التوصيل (اختياري)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'المنتجات حسب المتجر',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  ...cart.itemsByStore.entries.map((entry) {
                    final items = entry.value;
                    final storeName = items.first.product.storeName;
                    final storeTotal = items.fold<int>(
                      0,
                      (sum, item) => sum + item.lineTotal,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName.isEmpty ? 'متجر' : storeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            ...items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.product.name} × ${item.quantity}',
                                      ),
                                    ),
                                    Text(_money(item.lineTotal)),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(),
                            Row(
                              children: [
                                const Expanded(child: Text('مجموع المتجر')),
                                Text(
                                  _money(storeTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: 'المجموع الفرعي',
                            value: _money(cart.subtotal),
                          ),
                          const SizedBox(height: 8),
                          const _SummaryRow(
                            label: 'رسوم التوصيل',
                            value: 'تحدد من الخادم لكل متجر',
                          ),
                          const Divider(height: 24),
                          _SummaryRow(
                            label: 'الإجمالي النهائي',
                            value: _money(cart.subtotal),
                            bold: true,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'الإجمالي أعلاه لا يشمل رسوم التوصيل بعد.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'طريقة الدفع',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.payments_outlined,
                        color: AppTheme.primary,
                      ),
                      title: Text('الدفع عند الاستلام'),
                      subtitle: Text(
                        'تدفع عند استلام الطلب وفق إجراءات المنصة.',
                      ),
                      trailing: Icon(
                        Icons.check_circle,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (cart.hasUnavailableItems)
                    const Text(
                      'توجد منتجات غير متوفرة. ارجع إلى السلة وأزلها قبل المتابعة.',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ElevatedButton(
                    onPressed: null,
                    child: const Text('تأكيد الطلب — بانتظار ربط الخادم'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? AppTheme.primary : null,
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: style,
          ),
        ),
      ],
    );
  }
}
