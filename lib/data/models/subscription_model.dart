class SubscriptionModel {
  final int id;
  final int planId;
  final String planName;
  final double planPrice;
  final String planInterval;
  final String status;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? trialEndsAt;
  final int? maxUsers;
  final int? maxDoctors;

  const SubscriptionModel({
    required this.id,
    required this.planId,
    required this.planName,
    required this.planPrice,
    required this.planInterval,
    required this.status,
    required this.isActive,
    this.createdAt,
    this.startedAt,
    this.endsAt,
    this.trialEndsAt,
    this.maxUsers,
    this.maxDoctors,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] is String
          ? int.tryParse(json['id']) ?? 0
          : json['id'] ?? 0,
      planId: json['plan_id'] is String
          ? int.tryParse(json['plan_id']) ?? 0
          : json['plan_id'] ?? 0,
      planName: json['plan_name']?.toString() ?? '',
      planPrice: _parseDouble(json['plan_price']),
      planInterval: json['plan_interval']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active']?.toString() == 'true',
      createdAt: _parseDate(json['created_at'] ?? json['started_at']),
      startedAt: _parseDate(json['started_at']),
      endsAt: _parseDate(json['ends_at']),
      trialEndsAt: _parseDate(json['trial_ends_at']),
      maxUsers: _parseInt(json['max_users']),
      maxDoctors: _parseInt(json['max_doctors']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
