// lib/data/models/medical_record_model.dart
import 'patient_model.dart';
import 'doctor_model.dart';
import 'appointment_model.dart';
import 'prescription_model.dart';

class MedicalRecordAttachment {
  final int? id;
  final int? medicalRecordId;
  final String? fileName;
  final String? filePath;
  final String? fileType;
  final int? fileSize;
  final String? fileUrl;
  final String? visibility;
  final int? uploadedByUserId;
  final DateTime? createdAt;

  MedicalRecordAttachment({
    this.id,
    this.medicalRecordId,
    this.fileName,
    this.filePath,
    this.fileType,
    this.fileSize,
    this.fileUrl,
    this.visibility,
    this.uploadedByUserId,
    this.createdAt,
  });

  factory MedicalRecordAttachment.fromJson(Map<String, dynamic> json) {
    return MedicalRecordAttachment(
      id: _parseInt(json['id']),
      medicalRecordId: _parseInt(json['medical_record_id']),
      fileName: json['file_name'] as String?,
      filePath: json['file_path'] as String?,
      fileType: json['file_type'] as String?,
      fileSize: _parseInt(json['file_size']),
      fileUrl: json['file_url'] as String?,
      // Handle missing visibility field gracefully - default to 'public' if not present
      visibility: json['visibility'] as String? ?? 'public',
      uploadedByUserId: _parseInt(json['uploaded_by_user_id']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medical_record_id': medicalRecordId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'file_size': fileSize,
      'file_url': fileUrl,
      'visibility': visibility,
      'uploaded_by_user_id': uploadedByUserId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class SpecialtyField {
  final String? fieldName;
  final String? fieldLabel;
  final String? fieldType;
  final int? fieldOrder;
  final List<String>? options;
  final bool? required;

  SpecialtyField({
    this.fieldName,
    this.fieldLabel,
    this.fieldType,
    this.fieldOrder,
    this.options,
    this.required,
  });

  factory SpecialtyField.fromJson(Map<String, dynamic> json) {
    return SpecialtyField(
      fieldName: json['field_name'] as String?,
      fieldLabel: json['field_label'] as String?,
      fieldType: json['field_type'] as String?,
      // Support both 'order' and 'field_order' from API
      fieldOrder: (json['order'] ?? json['field_order']) as int?,
      options: _parseOptions(json['options']),
      // Support both boolean and int (0/1) for required
      required: _parseBool(json['required']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'field_label': fieldLabel,
      'field_type': fieldType,
      'order': fieldOrder,
      'options': options,
      'required': required,
    };
  }
}

class Specialty {
  final int? id;
  final String? name;
  final List<SpecialtyField>? fields;

  Specialty({
    this.id,
    this.name,
    this.fields,
  });

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(
      id: json['id'] as int?,
      name: json['name'] as String?,
      fields: json['fields'] != null
          ? (json['fields'] as List<dynamic>)
              .map((f) => SpecialtyField.fromJson(f as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fields': fields?.map((f) => f.toJson()).toList(),
    };
  }
}

class MedicalRecordModel {
  final int? id;
  final int? patientId;
  final int? doctorId;
  final int? appointmentId;
  final int? specialtyId;
  final PatientModel? patient;
  final DoctorModel? doctor;
  final AppointmentModel? appointment;
  final Specialty? specialty;
  final String? symptoms;
  final String? diagnosis;
  final String? treatment;
  final String? notes;

  // Vital Signs
  final String? bloodPressure;
  final double? weight;
  final double? height;
  final double? temperature;
  final int? heartRate;
  final int? respiratoryRate;
  final String? bmi;

  // Allergies
  final bool? hasAllergies;
  final String? allergyDetails;

  // Specialty Data
  final Map<String, dynamic>? specialtyData;

  // Visibility
  final String? visibility;

  // Related Data
  final List<PrescriptionModel>? prescriptions;
  final List<MedicalRecordAttachment>? attachments;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  MedicalRecordModel({
    this.id,
    this.patientId,
    this.doctorId,
    this.appointmentId,
    this.specialtyId,
    this.patient,
    this.doctor,
    this.appointment,
    this.specialty,
    this.symptoms,
    this.diagnosis,
    this.treatment,
    this.notes,
    this.bloodPressure,
    this.weight,
    this.height,
    this.temperature,
    this.heartRate,
    this.respiratoryRate,
    this.bmi,
    this.hasAllergies,
    this.allergyDetails,
    this.specialtyData,
    this.visibility,
    this.prescriptions,
    this.attachments,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory MedicalRecordModel.fromJson(Map<String, dynamic> json) {
    return MedicalRecordModel(
      id: json['id'] as int?,
      patientId: json['patient_id'] as int?,
      doctorId: json['doctor_id'] as int?,
      appointmentId: json['appointment_id'] as int?,
      specialtyId: json['specialty_id'] as int?,
      patient: json['patient'] != null
          ? PatientModel.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
      doctor: json['doctor'] != null
          ? DoctorModel.fromJson(json['doctor'] as Map<String, dynamic>)
          : null,
      appointment: json['appointment'] != null
          ? AppointmentModel.fromJson(
              json['appointment'] as Map<String, dynamic>)
          : null,
      specialty: json['specialty'] != null
          ? Specialty.fromJson(json['specialty'] as Map<String, dynamic>)
          : null,
      symptoms: json['symptoms'] as String?,
      diagnosis: json['diagnosis'] as String?,
      treatment: json['treatment'] as String?,
      notes: json['notes'] as String?,
      bloodPressure: json['blood_pressure'] as String?,
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      height:
          json['height'] != null ? (json['height'] as num).toDouble() : null,
      temperature: json['temperature'] != null
          ? (json['temperature'] as num).toDouble()
          : null,
      heartRate: json['heart_rate'] as int?,
      respiratoryRate: json['respiratory_rate'] as int?,
      bmi: json['bmi']?.toString(),
      hasAllergies: _parseBool(json['has_allergies']),
      allergyDetails: json['allergy_details'] as String?,
      specialtyData: _parseSpecialtyData(json['specialty_data']),
      visibility: json['visibility'] as String? ?? 'private',
      prescriptions: json['prescriptions'] != null
          ? (json['prescriptions'] as List<dynamic>)
              .map((p) => PrescriptionModel.fromJson(p as Map<String, dynamic>))
              .toList()
          : null,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List<dynamic>)
              .map((a) {
                try {
                  return MedicalRecordAttachment.fromJson(
                      a as Map<String, dynamic>);
                } catch (e) {
                  // Handle parsing errors gracefully - skip invalid attachments
                  print('Warning: Failed to parse attachment: $e');
                  return null;
                }
              })
              .whereType<MedicalRecordAttachment>()
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
      'patient_id': patientId,
      'doctor_id': doctorId,
      'appointment_id': appointmentId,
      'specialty_id': specialtyId,
      'patient': patient?.toJson(),
      'doctor': doctor?.toJson(),
      'appointment': appointment?.toJson(),
      'specialty': specialty?.toJson(),
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'notes': notes,
      'blood_pressure': bloodPressure,
      'weight': weight,
      'height': height,
      'temperature': temperature,
      'heart_rate': heartRate,
      'respiratory_rate': respiratoryRate,
      'bmi': bmi,
      'has_allergies': hasAllergies,
      'allergy_details': allergyDetails,
      'specialty_data': specialtyData,
      'visibility': visibility,
      'prescriptions': prescriptions?.map((p) => p.toJson()).toList(),
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      ...?additionalData,
    };
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

Map<String, dynamic>? _parseSpecialtyData(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    // Handle non-String key maps by converting
    return Map<String, dynamic>.from(value);
  }
  if (value is List) {
    // If it's an array (empty or not), return empty map
    // This handles cases where API returns [] instead of {}
    return {};
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
