import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/result.dart';
import '../data/models/medical_certificate_model.dart';
import '../data/models/certificate_template_model.dart';
import '../services/certificate_service.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

final certificateTemplatesProvider =
    FutureProvider.autoDispose<Result<List<CertificateTemplateModel>>>(
  (ref) async {
    final auth = ref.watch(authProvider);
    if (auth.isAuth != true) {
      return const Failure('Not authenticated');
    }
    final service = ref.watch(certificateServiceProvider);
    return service.fetchTemplates();
  },
);

final certificatesByPatientProvider = FutureProvider.autoDispose
    .family<Result<List<MedicalCertificateModel>>, int>((ref, patientId) async {
  final auth = ref.watch(authProvider);
  if (auth.isAuth != true) {
    return const Failure('Not authenticated');
  }
  final service = ref.watch(certificateServiceProvider);
  return service.fetchCertificates(patientId: patientId);
});

