// lib/data/models/prescription_model.dart
import 'patient_model.dart';
import 'medical_record_model.dart';
import 'prescription_item_model.dart';

class PrescriptionModel {
  final int? id;
  final int? patientId;
  final int? medicalRecordId;
  final PatientModel? patient;
  final MedicalRecordModel? medicalRecord;
  final List<PrescriptionItemModel>? medications;
  final String? followUpDate;
  final String? notes;
  final String? pdfPath;
  final String? pdfUrl;
  final bool? sendWhatsapp;
  final bool? sendEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  PrescriptionModel({
    this.id,
    this.patientId,
    this.medicalRecordId,
    this.patient,
    this.medicalRecord,
    this.medications,
    this.followUpDate,
    this.notes,
    this.pdfPath,
    this.pdfUrl,
    this.sendWhatsapp,
    this.sendEmail,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: json['id'] as int?,
      patientId: json['patient_id'] as int?,
      medicalRecordId: json['medical_record_id'] as int?,
      patient: json['patient'] != null
          ? PatientModel.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
      medicalRecord: json['medical_record'] != null
          ? MedicalRecordModel.fromJson(
              json['medical_record'] as Map<String, dynamic>)
          : null,
      medications: json['medications'] != null
          ? (json['medications'] as List<dynamic>)
              .map((item) =>
                  PrescriptionItemModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      followUpDate: json['follow_up_date'] as String?,
      notes: json['notes'] as String?,
      pdfPath: json['pdf_path'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      sendWhatsapp: json['send_whatsapp'] as bool?,
      sendEmail: json['send_email'] as bool?,
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
      'patient_id': patientId,
      'medical_record_id': medicalRecordId,
      'patient': patient?.toJson(),
      'medical_record': medicalRecord?.toJson(),
      'medications': medications?.map((m) => m.toJson()).toList(),
      'follow_up_date': followUpDate,
      'notes': notes,
      'pdf_path': pdfPath,
      'pdf_url': pdfUrl,
      'send_whatsapp': sendWhatsapp,
      'send_email': sendEmail,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      ...?additionalData,
    };
  }
}
