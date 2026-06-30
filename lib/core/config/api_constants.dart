// lib/core/config/api_constants.dart
class ApiConstants {
  // Static instance for dynamic tenant configuration
  static String? _baseUrl;
  static String? _storageBaseUrl;

  // Default/Master tenant URL for getting tenant list
  static const String masterBaseUrl = 'https://prodoc.ma/api/public/api';
  static const String masterStorageUrl =
      'https://dentairealami.nextpital.com/api/public';

  // Getters that return dynamic or master URL
  static String get baseUrl => _baseUrl ?? masterBaseUrl;
  static String get storageBaseUrl => _storageBaseUrl ?? masterStorageUrl;

  // Check if tenant is selected
  static bool get hasTenantSelected => _baseUrl != null;

  // Set tenant URLs dynamically
  static void setTenantUrls(String tenantUrl) {
    // Assuming tenantUrl is like: https://tenant.nextpital.com/api/public
    _baseUrl = '$tenantUrl/api';
    _storageBaseUrl = tenantUrl;
  }

  // Reset to master tenant
  static void resetToMaster() {
    _baseUrl = null;
    _storageBaseUrl = null;
  }

  // API Endpoints
  static const String getAllTenants = '/getalltenants';
  static const String systemTenants = '/system/tenants';
  static String systemTenant(int id) => '/system/tenants/$id';
  static const String login = '/login';
  static const String register = '/register';
  static const String logout = '/logout';
  static const String getUser = '/user';
  static const String accountDelete = '/account/delete';
  static const String forgotPassword = '/forgot-password';
  static const String updateProfile = '/profile';
  static const String csrfCookie = '/sanctum/csrf-cookie';
  static const String dashboard = '/dashboard';
  static const String sendMessage = '/send-message';
  static const String sendEmergency = '/send-emergency';

  // Appointment Endpoints
  static const String appointments = '/appointments';
  static String appointment(int id) => '/appointments/$id';
  static const String getAvailableTimeSlots =
      '/appointments/getAvailableTimeSlots';
  static const String appointmentsByDate = '/appointments/bydate';
  static String updateAppointmentStatus(int id) => '/appointments/status/$id';
  static const String sendWhatsAppReminder =
      '/reminders/send-whatsapp-reminder';
  static const String whatsAppMessageStatus =
      '/whatsapp/message-status-by-client';
  static const String waitingRoom = '/appointments/waitingroom';

  // Appointment Request Endpoints (for admin/doctor/receptionist)
  static const String appointmentRequests = '/appointments/requests';
  static String confirmAppointmentRequest(int id) =>
      '/appointments/requests/$id/confirm';
  static String rejectAppointmentRequest(int id) =>
      '/appointments/requests/$id/reject';
  static String updateAppointmentRequest(int id) =>
      '/appointments/requests/$id/update';

  // Public Appointment Endpoints (no auth required)
  static const String publicAppointmentRequest = '/appointment/request';
  static const String publicGetAvailableTimeSlots =
      '/appointments/getAvailableTimeSlots';
  static const String publicDoctors = '/doctors';
  static const String publicServices = '/services';

  // Patient Endpoints
  static const String patients = '/patients';
  static String patient(int id) => '/patients/$id';
  static String patientExport(int id) => '/patients/$id/export';
  static const String patientExportOwn = '/patient/export';
  static const String findPatients = '/patients/find';
  static String patientPhoto(int id) => '/patients/$id/photo';
  static String generateFaceEmbedding(int id) =>
      '/patients/$id/photo/generate-embedding';

  // Doctor Endpoints
  static const String doctors = '/doctors';

  // Service Endpoints
  static const String services = '/services';

  // NGAP Code Endpoints
  static const String ngapCodes = '/ngap-codes';
  static const String ngapCodesSearch = '/ngap-codes/search';
  static const String ngapCodesCategories = '/ngap-codes/categories';
  static String ngapCode(String code) => '/ngap-codes/$code';

  // Prescription Endpoints
  static const String prescriptions = '/prescriptions';
  static String prescription(int id) => '/prescriptions/$id';
  static String prescriptionPdf(int id) => '/prescriptions/$id/download';
  static const String searchPrescriptionPatients =
      '/prescriptions/patients/search';
  static const String searchMedications = '/prescriptions/medications/search';
  static const String prescriptionTemplates = '/prescription-templates';
  static const String prescriptionItems = '/prescription-items';

  // Prescription Settings Endpoints
  static const String ordonnanceSettings = '/ordonnance-settings';
  static const String ordonnanceSettingsReset = '/ordonnance-settings/reset';

  // Tenant Website Endpoints
  static const String tenantWebsiteConfig = '/tenant-website/mysite';
  static const String publicTenantWebsiteGetDefault =
      '/tenant-website/get_default_website';
  static const String updateTenantWebsiteConfig = '/tenant-website/buildmysite';
  static const String uploadTenantWebsiteFile = '/uploadfile';

  // Medical Record Endpoints

  static const String medicalRecords = '/medical-record';
  static String medicalRecord(int id) => '/medical-record/$id';
  static String medicalRecordVisibility(int id) =>
      '/medical-record/$id/visibility';
//  static String patientMedicalRecords(int patientId) => '/medical-record/patient/$patientId';
  static String patientMedicalRecords(int patientId, {int page = 1}) =>
      '/medical-record?page=$page&patient_id=$patientId';

  static const String medicalRecordSpecialties = '/medical-record/specialties';
  static String medicalRecordSpecialtyFields(int specialtyId) =>
      '/medical-record/specialties/$specialtyId/fields';
  static const String medicalRecordAttachments = '/medical-record/attachments';
  static String medicalRecordAttachment(int id) =>
      '/medical-record/attachments/$id';
  static String medicalRecordAttachmentDownload(int id) =>
      '/medical-record/attachments/$id/download';

  // Invoice Endpoints
  static const String invoices = '/invoices';
  static String invoice(int id) => '/invoices/$id';
  static String invoicePayments(int invoiceId) =>
      '/invoices/$invoiceId/payments';
  static String invoicePdf(int invoiceId) => '/invoices/$invoiceId/pdf';
  static String invoiceReminder(int invoiceId) =>
      '/invoices/$invoiceId/send-due-reminder';
  static const String invoiceSearch = '/invoices/search';

  // Subscription / Billing Endpoints
  static const String subscriptions = '/subscriptions';
  static const String subscriptionPlans = '/paypal/plans';
  static const String createSubscription = '/paypal/create-subscription';
  static String cancelSubscription(int id) => '/paypal/cancel-subscription/$id';

  // PayPal one-time checkout (same as Next.js: create order → capture)
  static const String paypalConfig = '/paypal/config';
  static const String paypalClientToken = '/paypal/checkout/client-token';
  static const String paypalCreateOrder = '/paypal/checkout/orders';
  static String paypalCaptureOrder(String orderId) =>
      '/paypal/checkout/orders/$orderId/capture';

  // Referral / Marketing Endpoints
  static const String referralMyCode = '/referrals/my-code';
  static const String referralHistory = '/referrals/history';
  static const String referralApply = '/referrals/apply';
  static const String referralValidate = '/referrals/validate';

  // Medication Endpoints
  static const String medications = '/medications';
  static String medication(String code) => '/medications/$code';

  // Reports Endpoints
  static String report(String reportType) => '/reports/$reportType';

  // Lab Test Endpoints
  static const String labTests = '/lab-tests';
  static String labTest(int id) => '/lab-tests/$id';
  static String patientLabTests(int patientId) =>
      '/patients/$patientId/lab-tests';
  static const String labTestAttachments = '/lab-test-attachments';
  static String labTestAttachment(int id) => '/lab-test-attachments/$id';
  static String labTestAttachmentDownload(int id) =>
      '/lab-test-attachments/$id/download';

  // Certificate Endpoints
  static const String certificates = '/certificates';
  static String certificate(int id) => '/certificates/$id';
  static const String certificateTemplates = '/certificates/templates';
  static String certificateTemplate(int id) => '/certificates/templates/$id';
  static String certificateGeneratePdf(int id) =>
      '/certificates/$id/generate-pdf';
  static String certificateDownload(int id) => '/certificates/$id/download';

  // OCR Endpoints
  static const String ocrMoroccanId = '/ocr/moroccan-id';

  // AI Chat Endpoints
  static const String aiChat = '/ai/chat';
  static const String aiAnalyzeImage = '/ai/analyze-image';

  // Notification Endpoints
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsMarkAllAsRead = '/notifications/read-all';
  static const String notificationsDeleteRead = '/notifications/read/all';
  static String notificationMarkAsRead(String id) => '/notifications/$id/read';
  static String notificationDelete(String id) => '/notifications/$id';

  // Specialty Management Endpoints
  static const String specialties = '/specialties';
  static String specialty(int id) => '/specialties/$id';
  static String specialtyFields(int specialtyId) =>
      '/specialties/$specialtyId/fields';
  static String specialtyField(int specialtyId, int fieldId) =>
      '/specialties/$specialtyId/fields/$fieldId';
  static String cleanupSpecialtyField(int specialtyId, String fieldName) =>
      '/specialties/$specialtyId/cleanup-field/$fieldName';

  // Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> headersWithAuth(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // Google OAuth Client IDs
  // Web Client ID (prodoc project)
  static const String googleClientIdWeb =
      '281736921626-llhhenole4r8kist13882k4fvtn9f08l.apps.googleusercontent.com';
  // Android Client ID (for reference - Android auto-detects based on SHA-1 and package name)
  static const String googleClientIdAndroid =
      '1048263640434-ebt5gt0g1ip2seth6hvjh47nuekn8cl9.apps.googleusercontent.com';

  // Default to web client ID for backward compatibility
  static const String googleClientId = googleClientIdWeb;
}
