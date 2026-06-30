// lib/data/models/specialty_model.dart
class SpecialtyFieldModel {
  final int? id;
  final int? specialtyId;
  final String? fieldName;
  final String? fieldLabel;
  final String? fieldType;
  final int? fieldOrder;
  final List<String>? options;
  final bool? required;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SpecialtyFieldModel({
    this.id,
    this.specialtyId,
    this.fieldName,
    this.fieldLabel,
    this.fieldType,
    this.fieldOrder,
    this.options,
    this.required,
    this.createdAt,
    this.updatedAt,
  });

  factory SpecialtyFieldModel.fromJson(Map<String, dynamic> json) {
    return SpecialtyFieldModel(
      id: _parseInt(json['id']),
      specialtyId: _parseInt(json['specialty_id']),
      fieldName: json['field_name'] as String?,
      fieldLabel: json['field_label'] as String?,
      fieldType: json['field_type'] as String?,
      fieldOrder: _parseInt(json['field_order'] ?? json['order']),
      options: _parseOptions(json['options']),
      required: _parseBool(json['required']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'specialty_id': specialtyId,
      'field_name': fieldName,
      'field_label': fieldLabel,
      'field_type': fieldType,
      'field_order': fieldOrder,
      'options': options != null && options!.isNotEmpty
          ? (fieldType == 'select' ? options!.join(',') : null)
          : null,
      'required': required,
    };
  }

  SpecialtyFieldModel copyWith({
    int? id,
    int? specialtyId,
    String? fieldName,
    String? fieldLabel,
    String? fieldType,
    int? fieldOrder,
    List<String>? options,
    bool? required,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpecialtyFieldModel(
      id: id ?? this.id,
      specialtyId: specialtyId ?? this.specialtyId,
      fieldName: fieldName ?? this.fieldName,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldType: fieldType ?? this.fieldType,
      fieldOrder: fieldOrder ?? this.fieldOrder,
      options: options ?? this.options,
      required: required ?? this.required,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SpecialtyModel {
  final int? id;
  final String? name;
  final String? description;
  final List<SpecialtyFieldModel>? fields;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SpecialtyModel({
    this.id,
    this.name,
    this.description,
    this.fields,
    this.createdAt,
    this.updatedAt,
  });

  factory SpecialtyModel.fromJson(Map<String, dynamic> json) {
    return SpecialtyModel(
      id: _parseInt(json['id']),
      name: json['name'] as String?,
      description: json['description'] as String?,
      fields: json['fields'] != null
          ? (json['fields'] as List<dynamic>)
              .map((f) =>
                  SpecialtyFieldModel.fromJson(f as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fields': fields?.map((f) => f.toJson()).toList(),
    };
  }

  SpecialtyModel copyWith({
    int? id,
    String? name,
    String? description,
    List<SpecialtyFieldModel>? fields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpecialtyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<String>? _parseOptions(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
  }
  return null;
}

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed;
  }
  return null;
}
