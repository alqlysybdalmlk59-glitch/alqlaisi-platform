import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';

class CustomerAddressesPage extends StatefulWidget {
  const CustomerAddressesPage({super.key, required this.token});
  final String token;

  @override
  State<CustomerAddressesPage> createState() => _CustomerAddressesPageState();
}

class _CustomerAddressesPageState extends State<CustomerAddressesPage> {
  late final ApiClient _api;
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;
  String? _error;
  String? _workingId;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.get(ApiEndpoints.customerAddresses, token: widget.token);
      if (result is! List) throw const ApiException(message: 'قائمة العناوين غير صحيحة.');
      final rows = result.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      if (mounted) setState(() { _addresses = rows; _loading = false; });
    } on ApiException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'تعذر تحميل العناوين. تحقق من اتصال الخادم.'; _loading = false; });
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  Map<String, dynamic> _payload(Map<String, dynamic> row, {bool? isDefault}) => {
    'label': (row['label'] ?? 'المنزل').toString(),
    'recipient_name': (row['recipient_name'] ?? '').toString(),
    'phone': (row['phone'] ?? '').toString(),
    'address': (row['address'] ?? '').toString(),
    'notes': (row['notes'] ?? '').toString(),
    'is_default': isDefault ?? row['is_default'] == true,
  };

  Future<void> _setDefault(Map<String, dynamic> row) async {
    final id = row['id'].toString();
    setState(() => _workingId = id);
    try {
      await _api.put('${ApiEndpoints.customerAddresses}/$id', token: widget.token, body: _payload(row, isDefault: true));
      await _load();
      _message('تم تعيين العنوان الافتراضي.');
    } on ApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = row['id'].toString();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف عنوان التوصيل'),
        content: Text("هل تريد حذف العنوان «${row['label'] ?? 'عنوان'}»؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _workingId = id);
    try {
      await _api.delete('${ApiEndpoints.customerAddresses}/$id', token: widget.token);
      await _load();
      _message('تم حذف العنوان.');
    } on ApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    final key = GlobalKey<FormState>();
    final label = TextEditingController(text: (existing?['label'] ?? 'المنزل').toString());
    final recipient = TextEditingController(text: (existing?['recipient_name'] ?? '').toString());
    final phone = TextEditingController(text: (existing?['phone'] ?? '').toString());
    final address = TextEditingController(text: (existing?['address'] ?? '').toString());
    final notes = TextEditingController(text: (existing?['notes'] ?? '').toString());
    bool makeDefault = existing?['is_default'] == true || _addresses.isEmpty;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshDialog) => AlertDialog(
          title: Text(existing == null ? 'إضافة عنوان' : 'تعديل العنوان'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: label, decoration: const InputDecoration(labelText: 'اسم العنوان'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم العنوان.' : null),
                  TextFormField(controller: recipient, decoration: const InputDecoration(labelText: 'اسم المستلم'), validator: (v) => v == null || v.trim().length < 2 ? 'أدخل اسم المستلم.' : null),
                  TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (v) => v == null || v.trim().length < 7 ? 'تحقق من رقم الهاتف.' : null),
                  TextFormField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'العنوان بالتفصيل'), validator: (v) => v == null || v.trim().length < 5 ? 'أدخل عنوانًا تفصيليًا.' : null),
                  TextFormField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
                  CheckboxListTile(contentPadding: EdgeInsets.zero, value: makeDefault, title: const Text('العنوان الافتراضي'), onChanged: (v) => refreshDialog(() => makeDefault = v ?? false)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (!key.currentState!.validate()) return;
              Navigator.pop(dialogContext, <String, dynamic>{
                'label': label.text.trim(), 'recipient_name': recipient.text.trim(),
                'phone': phone.text.trim(), 'address': address.text.trim(),
                'notes': notes.text.trim(), 'is_default': makeDefault,
              });
            }, child: const Text('حفظ')),
          ],
        ),
      ),
    );

    label.dispose();
    recipient.dispose();
    phone.dispose();
    address.dispose();
    notes.dispose();
    if (result == null || !mounted) return;

    final id = existing?['id']?.toString();
    setState(() => _workingId = id ?? 'new');
    try {
      if (id == null) {
        await _api.post(ApiEndpoints.customerAddresses, token: widget.token, body: result);
      } else {
        await _api.put('${ApiEndpoints.customerAddresses}/$id', token: widget.token, body: result);
      }
      await _load();
      _message(id == null ? 'تم إضافة العنوان.' : 'تم تعديل العنوان.');
    } on ApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('دفتر عناوين التوصيل'),
      actions: [IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _workingId == 'new' ? null : () => _edit(),
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('إضافة عنوان'),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ]),
        ))
      : _addresses.isEmpty ? const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا توجد عناوين محفوظة. اضغط «إضافة عنوان» لحفظ عنوانك الأول.', textAlign: TextAlign.center),
        ))
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: _addresses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = _addresses[index];
            final id = row['id'].toString();
            final isWorking = _workingId == id;
            final isDefault = row['is_default'] == true;
            return Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((row['label'] ?? 'عنوان').toString(), style: Theme.of(context).textTheme.titleMedium)),
                  if (isDefault) const Chip(avatar: Icon(Icons.check_circle, size: 16), label: Text('افتراضي')),
                ]),
                Text((row['recipient_name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text((row['phone'] ?? '').toString()),
                const SizedBox(height: 4),
                Text((row['address'] ?? '').toString()),
                if ((row['notes'] ?? '').toString().trim().isNotEmpty)
                  Text("ملاحظات: ${row['notes']}", style: const TextStyle(color: Colors.grey)),
                Wrap(spacing: 4, children: [
                  if (!isDefault) TextButton.icon(onPressed: isWorking ? null : () => _setDefault(row), icon: const Icon(Icons.star_outline), label: const Text('جعله افتراضيًا')),
                  TextButton.icon(onPressed: isWorking ? null : () => _edit(existing: row), icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')),
                  TextButton.icon(onPressed: isWorking ? null : () => _delete(row), icon: const Icon(Icons.delete_outline), label: const Text('حذف')),
                ]),
                if (isWorking) const LinearProgressIndicator(),
              ]),
            ));
          },
        ),
  );
}
