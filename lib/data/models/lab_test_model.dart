import 'patient_model.dart';
import 'doctor_model.dart';

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class LabTestAttachmentModel {
  final int? id;
  final int? labTestId;
  final String? fileName;
  final String? filePath;
  final String? fileType;
  final int? fileSize;
  final DateTime? uploadedAt;

  LabTestAttachmentModel({
    this.id,
    this.labTestId,
    this.fileName,
    this.filePath,
    this.fileType,
    this.fileSize,
    this.uploadedAt,
  });

  factory LabTestAttachmentModel.fromJson(Map<String, dynamic> json) {
    return LabTestAttachmentModel(
      id: _parseInt(json['id']),
      labTestId: _parseInt(json['lab_test_id']),
      fileName: json['file_name'] as String?,
      filePath: json['file_path'] as String?,
      fileType: json['file_type'] as String?,
      fileSize: _parseInt(json['file_size']),
      uploadedAt: _parseDate(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lab_test_id': labTestId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }
}

class LabTestModel {
  final int? id;
  final int? patientId;
  final int? doctorId;
  final String? testName;
  final DateTime? testDate;
  final String? result;
  final String? status;
  final PatientModel? patient;
  final DoctorModel? doctor;
  final List<LabTestAttachmentModel>? attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  LabTestModel({
    this.id,
    this.patientId,
    this.doctorId,
    this.testName,
    this.testDate,
    this.result,
    this.status,
    this.patient,
    this.doctor,
    this.attachments,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory LabTestModel.fromJson(Map<String, dynamic> json) {
    return LabTestModel(
      id: _parseInt(json['id']),
      patientId: _parseInt(json['patient_id']),
      doctorId: _parseInt(json['doctor_id']),
      testName: json['test_name'] as String?,
      testDate: _parseDate(json['test_date']),
      result: json['result'] as String?,
      status: json['status'] as String?,
      patient: json['patient'] != null
          ? PatientModel.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
      doctor: json['doctor'] != null
          ? DoctorModel.fromJson(json['doctor'] as Map<String, dynamic>)
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map(
              (a) => LabTestAttachmentModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'test_name': testName,
      'test_date': testDate?.toIso8601String(),
      'result': result,
      'status': status,
      'patient': patient?.toJson(),
      'doctor': doctor?.toJson(),
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      ...?additionalData,
    };
  }
}
