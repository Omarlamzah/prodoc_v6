// lib/data/models/appointment_request_model.dart
import 'doctor_model.dart';

class AppointmentRequestModel {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final DoctorModel? doctor;
  final String? service; // Service code
  final String? serviceName;
  final String? date;
  final String? time;
  final String? notes;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  AppointmentRequestModel({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.doctor,
    this.service,
    this.serviceName,
    this.date,
    this.time,
    this.notes,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory AppointmentRequestModel.fromJson(Map<String, dynamic> json) {
    return AppointmentRequestModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      doctor: json['doctor'] != null
          ? DoctorModel.fromJson(json['doctor'] as Map<String, dynamic>)
          : null,
      service: json['service'] as String?,
      serviceName: json['service_name'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String?,
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
      'name': name,
      'email': email,
      'phone': phone,
      'doctor': doctor?.toJson(),
      'service': service,
      'service_name': serviceName,
      'date': date,
      'time': time,
      'notes': notes,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      ...?additionalData,
    };
  }
}
