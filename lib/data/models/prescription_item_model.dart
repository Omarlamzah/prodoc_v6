// lib/data/models/prescription_item_model.dart
import 'medication_model.dart';

class PrescriptionItemModel {
  final int? id;
  final int? prescriptionId;
  final String? medicationCode;
  final String? medicationName;
  final MedicationModel? medication;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final int? refills;
  final String? notes;
  final Map<String, dynamic>? additionalData;

  PrescriptionItemModel({
    this.id,
    this.prescriptionId,
    this.medicationCode,
    this.medicationName,
    this.medication,
    this.dosage,
    this.frequency,
    this.duration,
    this.refills,
    this.notes,
    this.additionalData,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
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

    return PrescriptionItemModel(
      id: parseInt(json['id']),
      prescriptionId: parseInt(json['prescription_id']),
      medicationCode: json['medication_code'] as String?,
      medicationName: json['medication_name'] as String?,
      medication: json['medication'] != null
          ? MedicationModel.fromJson(json['medication'] as Map<String, dynamic>)
          : null,
      dosage: json['dosage']?.toString(),
      frequency: json['frequency']?.toString(),
      duration: json['duration']?.toString(),
      refills: parseInt(json['refills']) ?? 1,
      notes: json['notes']?.toString() ?? json['instructions']?.toString(),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prescription_id': prescriptionId,
      'medication_code': medicationCode,
      'medication_name': medicationName,
      'medication': medication?.toJson(),
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'refills': refills ?? 1,
      'notes': notes,
      ...?additionalData,
    };
  }
}

