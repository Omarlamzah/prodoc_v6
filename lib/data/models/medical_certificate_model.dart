import 'patient_model.dart';
import 'doctor_model.dart';
import 'medical_record_model.dart';
import 'certificate_template_model.dart';

class MedicalCertificateModel {
  final int? id;
  final int? patientId;
  final int? doctorId;
  final int? medicalRecordId;
  final int? templateId;
  final String? content;
  final bool? isFinalized;
  final String? pdfPath;
  final String? priority;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final PatientModel? patient;
  final DoctorModel? doctor;
  final MedicalRecordModel? medicalRecord;
  final CertificateTemplateModel? template;

  MedicalCertificateModel({
    this.id,
    this.patientId,
    this.doctorId,
    this.medicalRecordId,
    this.templateId,
    this.content,
    this.isFinalized,
    this.pdfPath,
    this.priority,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.patient,
    this.doctor,
    this.medicalRecord,
    this.template,
  });

  factory MedicalCertificateModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v is String ? DateTime.tryParse(v) : null;

    bool? parseBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v == 1;
      return null;
    }

    return MedicalCertificateModel(
      id: json['id'] as int?,
      patientId: json['patient_id'] as int?,
      doctorId: json['doctor_id'] as int?,
      medicalRecordId: json['medical_record_id'] as int?,
      templateId: json['template_id'] as int?,
      content: json['content'] as String?,
      isFinalized: parseBool(json['is_finalized']),
      pdfPath: json['pdf_path'] as String?,
      priority: json['priority'] as String?,
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      patient: json['patient'] != null
          ? PatientModel.fromJson(json['patient'] as Map<String, dynamic>)
          : json['medical_record']?['patient'] != null
              ? PatientModel.fromJson(
                  json['medical_record']['patient'] as Map<String, dynamic>)
              : null,
      doctor: json['doctor'] != null
          ? DoctorModel.fromJson(json['doctor'] as Map<String, dynamic>)
          : json['medical_record']?['doctor'] != null
              ? DoctorModel.fromJson(
                  json['medical_record']['doctor'] as Map<String, dynamic>)
              : null,
      medicalRecord: json['medical_record'] != null
          ? MedicalRecordModel.fromJson(
              json['medical_record'] as Map<String, dynamic>)
          : null,
      template: json['template'] != null
          ? CertificateTemplateModel.fromJson(
              json['template'] as Map<String, dynamic>)
          : null,
    );
  }
}
