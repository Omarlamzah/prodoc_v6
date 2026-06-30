// lib/data/models/prescription_template_model.dart
import 'prescription_item_model.dart';

class PrescriptionTemplateModel {
  final int? id;
  final String? templateName;
  final String? description;
  final String? defaultDiagnosis;
  final String? defaultNotes;
  final List<PrescriptionItemModel>? items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  PrescriptionTemplateModel({
    this.id,
    this.templateName,
    this.description,
    this.defaultDiagnosis,
    this.defaultNotes,
    this.items,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory PrescriptionTemplateModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert to int
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed;
      }
      return null;
    }

    return PrescriptionTemplateModel(
      id: parseInt(json['id']),
      templateName: json['template_name'] as String?,
      description: json['description'] as String?,
      defaultDiagnosis: json['default_diagnosis'] as String?,
      defaultNotes: json['default_notes'] as String?,
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
              .map((item) {
                try {
                  return PrescriptionItemModel.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  // Skip invalid items
                  return null;
                }
              })
              .whereType<PrescriptionItemModel>()
              .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_name': templateName,
      'description': description,
      'default_diagnosis': defaultDiagnosis,
      'default_notes': defaultNotes,
      'items': items?.map((i) => i.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      ...?additionalData,
    };
  }
}

