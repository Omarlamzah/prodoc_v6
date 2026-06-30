// lib/data/models/doctor_model.dart
import 'user_model.dart';

class DoctorModel {
  final int? id;
  final UserModel? user;
  final String? specialization;
  final String? specialty;
  final double? consultationFee;
  final Map<String, dynamic>? additionalData;

  DoctorModel({
    this.id,
    this.user,
    this.specialization,
    this.specialty,
    this.consultationFee,
    this.additionalData,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    // Handle consultation_fee which can be a string or number
    double? consultationFee;
    final feeValue = json['consultation_fee'];
    if (feeValue != null) {
      if (feeValue is num) {
        consultationFee = feeValue.toDouble();
      } else if (feeValue is String) {
        consultationFee = double.tryParse(feeValue);
      }
    }

    // Handle user object - if not present but name is at top level, create a user object
    UserModel? user;
    if (json['user'] != null) {
      user = UserModel.fromJson(json['user'] as Map<String, dynamic>);
    } else if (json['name'] != null) {
      // If user object is missing but name exists at top level, create a minimal user
      user = UserModel(
        id: json['user_id'] as int?,
        name: json['name'] as String?,
        email: null,
      );
    }

    return DoctorModel(
      id: json['id'] as int?,
      user: user,
      specialization:
          json['specialization'] as String? ?? json['specialty'] as String?,
      specialty:
          json['specialty'] as String? ?? json['specialization'] as String?,
      consultationFee: consultationFee,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user?.toJson(),
      'specialization': specialization ?? specialty,
      'specialty': specialty ?? specialization,
      'consultation_fee': consultationFee,
      ...?additionalData,
    };
  }
}
