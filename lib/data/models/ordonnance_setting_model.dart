// lib/data/models/ordonnance_setting_model.dart
class OrdonnanceSettingModel {
  final int? id;
  final String? headerText;
  final String? footerText;
  final String? doctorName;
  final String? doctorTitle;
  final String? clinicName;
  final String? clinicAddress;
  final String? clinicPhone;
  final String? clinicEmail;
  final bool? showHeader;
  final bool? showFooter;
  final bool? showPrescriptionNumber;
  final bool? showPrescriptionDate;
  final bool? showPatientInfo;
  final bool? showPatientAddress;
  final bool? showPatientAge;
  final bool? showMedicationsTable;
  final bool? showDosageInstructions;
  final bool? showRenewalInfo;
  final bool? showPatientSignature;
  final bool? showDoctorSignature;
  final bool? showStamp;
  final bool? showDoctorSpecialty;
  final bool? showDoctorAvailability;
  final bool? showDoctorBiography;
  final bool? showLogo;
  final String? logoPath;
  final bool? showQRCode;
  final bool? showBarcode;
  final bool? showGenerationInfo;
  final String? templateStyle;
  final Map<String, dynamic>? additionalData;

  OrdonnanceSettingModel({
    this.id,
    this.headerText,
    this.footerText,
    this.doctorName,
    this.doctorTitle,
    this.clinicName,
    this.clinicAddress,
    this.clinicPhone,
    this.clinicEmail,
    this.showHeader,
    this.showFooter,
    this.showPrescriptionNumber,
    this.showPrescriptionDate,
    this.showPatientInfo,
    this.showPatientAddress,
    this.showPatientAge,
    this.showMedicationsTable,
    this.showDosageInstructions,
    this.showRenewalInfo,
    this.showPatientSignature,
    this.showDoctorSignature,
    this.showStamp,
    this.showDoctorSpecialty,
    this.showDoctorAvailability,
    this.showDoctorBiography,
    this.showLogo,
    this.logoPath,
    this.showQRCode,
    this.showBarcode,
    this.showGenerationInfo,
    this.templateStyle,
    this.additionalData,
  });

  factory OrdonnanceSettingModel.fromJson(Map<String, dynamic> json) {
    return OrdonnanceSettingModel(
      id: json['id'] as int?,
      headerText: json['header_text'] as String?,
      footerText: json['footer_text'] as String?,
      doctorName: json['doctor_name'] as String?,
      doctorTitle: json['doctor_title'] as String?,
      clinicName: json['clinic_name'] as String?,
      clinicAddress: json['clinic_address'] as String?,
      clinicPhone: json['clinic_phone'] as String?,
      clinicEmail: json['clinic_email'] as String?,
      showHeader: json['show_header'] == 1 || json['show_header'] == true,
      showFooter: json['show_footer'] == 1 || json['show_footer'] == true,
      showPrescriptionNumber: json['show_prescription_number'] == 1 ||
          json['show_prescription_number'] == true,
      showPrescriptionDate: json['show_prescription_date'] == 1 ||
          json['show_prescription_date'] == true,
      showPatientInfo:
          json['show_patient_info'] == 1 || json['show_patient_info'] == true,
      showPatientAddress: json['show_patient_address'] == 1 ||
          json['show_patient_address'] == true,
      showPatientAge:
          json['show_patient_age'] == 1 || json['show_patient_age'] == true,
      showMedicationsTable: json['show_medications_table'] == 1 ||
          json['show_medications_table'] == true,
      showDosageInstructions: json['show_dosage_instructions'] == 1 ||
          json['show_dosage_instructions'] == true,
      showRenewalInfo:
          json['show_renewal_info'] == 1 || json['show_renewal_info'] == true,
      showPatientSignature: json['show_patient_signature'] == 1 ||
          json['show_patient_signature'] == true,
      showDoctorSignature: json['show_doctor_signature'] == 1 ||
          json['show_doctor_signature'] == true,
      showStamp: json['show_stamp'] == 1 || json['show_stamp'] == true,
      showDoctorSpecialty: json['show_doctor_specialty'] == 1 ||
          json['show_doctor_specialty'] == true,
      showDoctorAvailability: json['show_doctor_availability'] == 1 ||
          json['show_doctor_availability'] == true,
      showDoctorBiography: json['show_doctor_biography'] == 1 ||
          json['show_doctor_biography'] == true,
      showLogo: json['show_logo'] == 1 || json['show_logo'] == true,
      logoPath: json['logo_path'] as String?,
      showQRCode: json['show_qr_code'] == 1 || json['show_qr_code'] == true,
      showBarcode: json['show_barcode'] == 1 || json['show_barcode'] == true,
      showGenerationInfo: json['show_generation_info'] == 1 ||
          json['show_generation_info'] == true,
      templateStyle: json['template_style'] as String?,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header_text': headerText,
      'footer_text': footerText,
      'doctor_name': doctorName,
      'doctor_title': doctorTitle,
      'clinic_name': clinicName,
      'clinic_address': clinicAddress,
      'clinic_phone': clinicPhone,
      'clinic_email': clinicEmail,
      'show_header': showHeader == true ? 1 : 0,
      'show_footer': showFooter == true ? 1 : 0,
      'show_prescription_number': showPrescriptionNumber == true ? 1 : 0,
      'show_prescription_date': showPrescriptionDate == true ? 1 : 0,
      'show_patient_info': showPatientInfo == true ? 1 : 0,
      'show_patient_address': showPatientAddress == true ? 1 : 0,
      'show_patient_age': showPatientAge == true ? 1 : 0,
      'show_medications_table': showMedicationsTable == true ? 1 : 0,
      'show_dosage_instructions': showDosageInstructions == true ? 1 : 0,
      'show_renewal_info': showRenewalInfo == true ? 1 : 0,
      'show_patient_signature': showPatientSignature == true ? 1 : 0,
      'show_doctor_signature': showDoctorSignature == true ? 1 : 0,
      'show_stamp': showStamp == true ? 1 : 0,
      'show_doctor_specialty': showDoctorSpecialty == true ? 1 : 0,
      'show_doctor_availability': showDoctorAvailability == true ? 1 : 0,
      'show_doctor_biography': showDoctorBiography == true ? 1 : 0,
      'show_logo': showLogo == true ? 1 : 0,
      'logo_path': logoPath,
      'show_qr_code': showQRCode == true ? 1 : 0,
      'show_barcode': showBarcode == true ? 1 : 0,
      'show_generation_info': showGenerationInfo == true ? 1 : 0,
      'template_style': templateStyle,
      ...?additionalData,
    };
  }
}
