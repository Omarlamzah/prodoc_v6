// lib/data/models/service_model.dart
class ServiceModel {
  final int? id;
  final String? title;
  final String? description;
  final double? price;
  final String? ngapCode;
  final bool? status;
  final Map<String, dynamic>? additionalData;

  ServiceModel({
    this.id,
    this.title,
    this.description,
    this.price,
    this.ngapCode,
    this.status,
    this.additionalData,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    // Handle status which can be int (0/1) or bool
    bool? parseStatus(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return null;
    }

    return ServiceModel(
      id: json['id'] as int?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      ngapCode: json['ngap_code'] as String?,
      status: parseStatus(json['status']),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      if (ngapCode != null) 'ngap_code': ngapCode,
      if (status != null) 'status': status,
      ...?additionalData,
    };
  }
}

