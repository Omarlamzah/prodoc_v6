class UserModel {
  final int? id;
  final String? name;
  final String? email;
  final String? role;
  final int? isAdmin;
  final int? isDoctor;
  final int? isNurse;
  final int? isReceptionist;
  final int? isPharmacist;
  final int? isLabTechnician;
  final int? isAccountant;
  final int? isPatient;
  final Map<String, dynamic>? additionalData;

  UserModel({
    this.id,
    this.name,
    this.email,
    this.role,
    this.isAdmin,
    this.isDoctor,
    this.isNurse,
    this.isReceptionist,
    this.isPharmacist,
    this.isLabTechnician,
    this.isAccountant,
    this.isPatient,
    this.additionalData,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      isAdmin: json['is_admin'] as int?,
      isDoctor: json['is_doctor'] as int?,
      isNurse: json['is_nurse'] as int?,
      isReceptionist: json['is_receptionist'] as int?,
      isPharmacist: json['is_pharmacist'] as int?,
      isLabTechnician: json['is_lab_technician'] as int?,
      isAccountant: json['is_accountant'] as int?,
      isPatient: json['is_patient'] as int?,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_admin': isAdmin,
      'is_doctor': isDoctor,
      'is_nurse': isNurse,
      'is_receptionist': isReceptionist,
      'is_pharmacist': isPharmacist,
      'is_lab_technician': isLabTechnician,
      'is_accountant': isAccountant,
      'is_patient': isPatient,
      ...?additionalData,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    int? isAdmin,
    int? isDoctor,
    int? isNurse,
    int? isReceptionist,
    int? isPharmacist,
    int? isLabTechnician,
    int? isAccountant,
    int? isPatient,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      isDoctor: isDoctor ?? this.isDoctor,
      isNurse: isNurse ?? this.isNurse,
      isReceptionist: isReceptionist ?? this.isReceptionist,
      isPharmacist: isPharmacist ?? this.isPharmacist,
      isLabTechnician: isLabTechnician ?? this.isLabTechnician,
      isAccountant: isAccountant ?? this.isAccountant,
      isPatient: isPatient ?? this.isPatient,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}

