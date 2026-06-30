import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';
import '../data/models/medical_certificate_model.dart';
import '../data/models/certificate_template_model.dart';

class CertificateService {
  final ApiClient apiClient;

  CertificateService({required this.apiClient});

  Future<Result<List<MedicalCertificateModel>>> fetchCertificates({
    required int patientId,
  }) async {
    try {
      final response = await apiClient.get(
        ApiConstants.certificates,
        queryParameters: {'patient_id': patientId.toString()},
        requireAuth: true,
      );

      final data = response['data'] as List<dynamic>? ?? [];
      final certs = data
          .map((c) =>
              MedicalCertificateModel.fromJson(c as Map<String, dynamic>))
          .toList();
      return Success(certs);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch certificates: $e');
    }
  }

  Future<Result<List<CertificateTemplateModel>>> fetchTemplates() async {
    try {
      final response = await apiClient.get(
        ApiConstants.certificateTemplates,
        requireAuth: true,
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final templates = data
          .map((t) =>
              CertificateTemplateModel.fromJson(t as Map<String, dynamic>))
          .toList();
      return Success(templates);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch templates: $e');
    }
  }

  Future<Result<MedicalCertificateModel>> createCertificate(
      Map<String, dynamic> body) async {
    try {
      final response = await apiClient.post(
        ApiConstants.certificates,
        body: body,
        requireAuth: true,
      );
      final cert = response is Map<String, dynamic>
          ? MedicalCertificateModel.fromJson(
              (response['data'] ?? response) as Map<String, dynamic>)
          : throw ApiException(message: 'Invalid response format');
      return Success(cert);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create certificate: $e');
    }
  }

  Future<Result<MedicalCertificateModel>> updateCertificate(
      int id, Map<String, dynamic> body) async {
    try {
      final response = await apiClient.put(
        ApiConstants.certificate(id),
        body: body,
        requireAuth: true,
      );
      final cert = response is Map<String, dynamic>
          ? MedicalCertificateModel.fromJson(
              (response['data'] ?? response) as Map<String, dynamic>)
          : throw ApiException(message: 'Invalid response format');
      return Success(cert);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update certificate: $e');
    }
  }

  Future<Result<String>> deleteCertificate(int id) async {
    try {
      await apiClient.delete(
        ApiConstants.certificate(id),
        requireAuth: true,
      );
      return const Success('Deleted');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to delete certificate: $e');
    }
  }

  Future<Result<MedicalCertificateModel>> generatePdf(int id) async {
    try {
      final response = await apiClient.post(
        ApiConstants.certificateGeneratePdf(id),
        requireAuth: true,
      );
      final cert = response is Map<String, dynamic>
          ? MedicalCertificateModel.fromJson(
              (response['data']?['certificate'] ?? response['data'] ?? response)
                  as Map<String, dynamic>)
          : throw ApiException(message: 'Invalid response format');
      return Success(cert);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to generate PDF: $e');
    }
  }

  String buildPdfUrl(String path) {
    final cleanPath = path.startsWith('storage/')
        ? path.substring(8)
        : path.replaceFirst(RegExp('^/'), '');
    return '${ApiConstants.storageBaseUrl}/storage/$cleanPath';
  }
}
