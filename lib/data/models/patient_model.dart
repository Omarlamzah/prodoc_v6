// lib/data/models/patient_model.dart
import 'user_model.dart';

class PatientModel {
  final int? id;
  final UserModel? user;
  final String? phone;
  final String? phoneNumber;
  final String? gender;
  final String? birthdate;
  final String? address;
  final String? bloodType;
  final String? cniNumber;
  final String? insuranceNumber;
  final String? insuranceType;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? photoPath;
  final String? photoUrl;
  final List<dynamic>? medicalRecords;
  final List<dynamic>? appointments;
  final Map<String, dynamic>? additionalData;

  PatientModel({
    this.id,
    this.user,
    this.phone,
    this.phoneNumber,
    this.gender,
    this.birthdate,
    this.address,
    this.bloodType,
    this.cniNumber,
    this.insuranceNumber,
    this.insuranceType,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.photoPath,
    this.photoUrl,
    this.medicalRecords,
    this.appointments,
    this.additionalData,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as int?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      phone: json['phone'] as String?,
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String?,
      gender: json['gender'] as String?,
      birthdate: json['birthdate'] as String?,
      address: json['address'] as String?,
      bloodType: json['blood_type'] as String?,
      cniNumber: json['cni_number'] as String?,
      insuranceNumber: json['insurance_number'] as String?,
      insuranceType: json['insurance_type'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      photoPath: json['photo_path'] as String?,
      photoUrl: json['photo_url'] as String?,
      medicalRecords: json['medical_records'] as List<dynamic>?,
      appointments: json['appointments'] as List<dynamic>?,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user?.toJson(),
      'phone': phone ?? phoneNumber,
      'phone_number': phoneNumber ?? phone,
      'gender': gender,
      'birthdate': birthdate,
      'address': address,
      'blood_type': bloodType,
      'cni_number': cniNumber,
      'insurance_number': insuranceNumber,
      'insurance_type': insuranceType,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'photo_path': photoPath,
      'photo_url': photoUrl,
      ...?additionalData,
    };
  }

  int? calculateAge() {
    if (birthdate == null) return null;
    try {
      final birth = DateTime.parse(birthdate!);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }
}
