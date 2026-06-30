import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../services/tenant_service.dart';
import '../services/dashboard_service.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/doctor_service.dart';
import '../services/service_service.dart';
import '../services/prescription_service.dart';
import '../services/tenant_website_service.dart';
import '../services/ordonnance_setting_service.dart';
import '../services/medical_record_service.dart';
import '../services/invoice_service.dart';
import '../services/communication_service.dart';
import '../services/notification_service.dart';
import '../services/certificate_service.dart';
import '../services/fcm_service.dart';
import '../services/medication_service.dart';
import '../services/report_service.dart';
import '../services/subscription_service.dart';
import '../services/specialty_service.dart';
import '../services/ocr_service.dart';
import '../services/ai_chat_service.dart';
import '../services/ngap_service.dart';
import '../services/referral_service.dart';

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Service Providers
final tenantServiceProvider = Provider<TenantService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TenantService(apiClient: apiClient);
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardService(apiClient: apiClient);
});

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AppointmentService(apiClient: apiClient);
});

final patientServiceProvider = Provider<PatientService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PatientService(apiClient: apiClient);
});

final doctorServiceProvider = Provider<DoctorService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DoctorService(apiClient: apiClient);
});

final serviceServiceProvider = Provider<ServiceService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ServiceService(apiClient: apiClient);
});

final prescriptionServiceProvider = Provider<PrescriptionService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PrescriptionService(apiClient: apiClient);
});

final tenantWebsiteServiceProvider = Provider<TenantWebsiteService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TenantWebsiteService(apiClient: apiClient);
});

final ordonnanceSettingServiceProvider =
    Provider<OrdonnanceSettingService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrdonnanceSettingService(apiClient: apiClient);
});

final medicalRecordServiceProvider = Provider<MedicalRecordService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MedicalRecordService(apiClient: apiClient);
});

final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InvoiceService(apiClient: apiClient);
});

final communicationServiceProvider = Provider<CommunicationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CommunicationService(apiClient: apiClient);
});

// Notification Service Provider (singleton)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// FCM Service Provider (singleton)
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

final medicationServiceProvider = Provider<MedicationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MedicationService(apiClient: apiClient);
});

final reportServiceProvider = Provider<ReportService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportService(apiClient: apiClient);
});

final certificateServiceProvider = Provider<CertificateService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CertificateService(apiClient: apiClient);
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SubscriptionService(apiClient: apiClient);
});

final specialtyServiceProvider = Provider<SpecialtyService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SpecialtyService(apiClient: apiClient);
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OcrService(apiClient: apiClient);
});

final aiChatServiceProvider = Provider<AiChatService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiChatService(apiClient: apiClient);
});

final ngapServiceProvider = Provider<NgapService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NgapService(apiClient: apiClient);
});

final referralServiceProvider = Provider<ReferralService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReferralService(apiClient: apiClient);
});

// Provider to track which field is currently recording
