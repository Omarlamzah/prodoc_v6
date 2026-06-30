// lib/data/models/appointment_model.dart
import 'patient_model.dart';
import 'doctor_model.dart';
import 'service_model.dart';

class AppointmentModel {
  final int? id;
  final PatientModel? patient;
  final DoctorModel? doctor;
  final ServiceModel? service;
  final String? appointmentDate;
  final String? appointmentTime;
  final String? priority;
  final String? status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  AppointmentModel({
    this.id,
    this.patient,
    this.doctor,
    this.service,
    this.appointmentDate,
    this.appointmentTime,
    this.priority,
    this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as int?,
      patient: json['patient'] != null
          ? PatientModel.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
      doctor: json['doctor'] != null
          ? DoctorModel.fromJson(json['doctor'] as Map<String, dynamic>)
          : null,
      service: json['service'] != null
          ? ServiceModel.fromJson(json['service'] as Map<String, dynamic>)
          : null,
      appointmentDate: json['appointment_date'] as String?,
      appointmentTime: json['appointment_time'] as String?,
      priority: json['priority'] as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
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
      'patient': patient?.toJson(),
      'doctor': doctor?.toJson(),
      'service': service?.toJson(),
      'appointment_date': appointmentDate,
      'appointment_time': appointmentTime,
      'priority': priority,
      'status': status,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      ...?additionalData,
    };
  }
}

