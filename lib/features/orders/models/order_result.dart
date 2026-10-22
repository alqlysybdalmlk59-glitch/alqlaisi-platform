class OrderResult {
  const OrderResult({
    required this.id,
    required this.status,
    required this.total,
    required this.paymentMethod,
  });

  final String id;
  final String status;
  final int total;
  final String paymentMethod;

  factory OrderResult.fromJson(Map<String, dynamic> json) {
    final rawTotal = json['total'] ?? json['total_amount'] ?? 0;

    return OrderResult(
      id: (json['id'] ?? json['order_id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      total: rawTotal is num
          ? rawTotal.toInt()
          : int.tryParse(rawTotal.toString()) ?? 0,
      paymentMethod: (json['payment_method'] ?? 'cash_on_delivery').toString(),
    );
  }
}
