// lib/data/models/ngap_model.dart
class NgapModel {
  final String code;
  final String labelFr;
  final String? labelAr;
  final String? category;
  final int? coefficientSurgeon;
  final int? coefficientAnesthesia;
  final double? basePrice;
  final bool isActive;

  NgapModel({
    required this.code,
    required this.labelFr,
    this.labelAr,
    this.category,
    this.coefficientSurgeon,
    this.coefficientAnesthesia,
    this.basePrice,
    this.isActive = true,
  });

  factory NgapModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse int from various types
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    // Helper to parse double from various types
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      if (value is num) return value.toDouble();
      return null;
    }

    // Helper to parse bool from various types
    bool parseBool(dynamic value, {bool defaultValue = true}) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return defaultValue;
    }

    return NgapModel(
      code: json['code']?.toString() ?? '',
      labelFr: json['label_fr']?.toString() ?? '',
      labelAr: json['label_ar']?.toString(),
      category: json['category']?.toString(),
      coefficientSurgeon: parseInt(json['coefficient_surgeon']),
      coefficientAnesthesia: parseInt(json['coefficient_anesthesia']),
      basePrice: parseDouble(json['base_price']),
      isActive: parseBool(json['is_active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label_fr': labelFr,
      if (labelAr != null) 'label_ar': labelAr,
      if (category != null) 'category': category,
      if (coefficientSurgeon != null) 'coefficient_surgeon': coefficientSurgeon,
      if (coefficientAnesthesia != null)
        'coefficient_anesthesia': coefficientAnesthesia,
      if (basePrice != null) 'base_price': basePrice,
      'is_active': isActive,
    };
  }

  // Helper to get first 4 words of label
  String getFirstWords(int count) {
    final words = labelFr.trim().split(RegExp(r'\s+'));
    if (words.length <= count) return labelFr;
    return '${words.take(count).join(' ')}...';
  }
}
