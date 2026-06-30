import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/result.dart';
import '../data/models/lab_test_model.dart';
import '../services/lab_test_service.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

final labTestServiceProvider = Provider<LabTestService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LabTestService(apiClient: apiClient);
});

final patientLabTestsProvider = FutureProvider.autoDispose
    .family<Result<List<LabTestModel>>, int>((ref, patientId) async {
  final authState = ref.watch(authProvider);
  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final service = ref.watch(labTestServiceProvider);
  return service.fetchPatientLabTests(patientId);
});

final labTestProvider =
    FutureProvider.autoDispose.family<Result<LabTestModel>, int>(
  (ref, labTestId) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final service = ref.watch(labTestServiceProvider);
    return service.fetchLabTest(labTestId);
  },
);
