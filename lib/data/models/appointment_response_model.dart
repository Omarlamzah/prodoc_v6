// lib/data/models/appointment_response_model.dart
import 'appointment_model.dart';

class AppointmentResponseModel {
  final AppointmentModel appointment;
  final Map<String, dynamic>? invoice;
  final String? message;

  AppointmentResponseModel({
    required this.appointment,
    this.invoice,
    this.message,
  });

  factory AppointmentResponseModel.fromJson(Map<String, dynamic> json) {
    return AppointmentResponseModel(
      appointment: AppointmentModel.fromJson(
        json['appointment'] as Map<String, dynamic>,
      ),
      invoice: json['invoice'] as Map<String, dynamic>?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointment': appointment.toJson(),
      'invoice': invoice,
      'message': message,
    };
  }
}

