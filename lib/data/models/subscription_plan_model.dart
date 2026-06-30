class SubscriptionPlanModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String interval;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.interval,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: _parseDouble(json['price']),
      interval: json['interval']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
