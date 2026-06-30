// lib/providers/prescription_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import '../services/prescription_service.dart';
import '../data/models/prescription_model.dart';
import '../data/models/prescription_list_response.dart';
import '../data/models/patient_model.dart';
import '../data/models/medication_model.dart';
import '../data/models/prescription_template_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Search Prescription Patients Provider
final searchPrescriptionPatientsProvider =
    FutureProvider.autoDispose.family<Result<List<PatientModel>>, String>(
  (ref, search) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    if (search.length < 3) {
      return const Success([]);
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    return await prescriptionService.searchPatients(search);
  },
);

// Search Medications Provider
final searchMedicationsProvider =
    FutureProvider.autoDispose.family<Result<List<MedicationModel>>, String>(
  (ref, search) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    if (search.length < 3) {
      return const Success([]);
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    return await prescriptionService.searchMedications(search);
  },
);

// Search Templates Provider
final searchPrescriptionTemplatesProvider = FutureProvider.autoDispose
    .family<Result<List<PrescriptionTemplateModel>>, String>(
  (ref, search) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    if (search.length < 3) {
      return const Success([]);
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    return await prescriptionService.searchTemplates(search);
  },
);

// Create Prescription Provider
final createPrescriptionProvider = FutureProvider.autoDispose
    .family<Result<PrescriptionModel>, Map<String, dynamic>>(
  (ref, prescriptionData) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    return await prescriptionService.createPrescription(prescriptionData);
  },
);

// Prescription List Filters
@immutable
class PrescriptionListFilters {
  final int page;
  final String? search;
  final String timeRange;

  const PrescriptionListFilters({
    this.page = 1,
    this.search,
    this.timeRange = 'all',
  });

  PrescriptionListFilters copyWith({
    int? page,
    String? search,
    String? timeRange,
  }) {
    return PrescriptionListFilters(
      page: page ?? this.page,
      search: search ?? this.search,
      timeRange: timeRange ?? this.timeRange,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrescriptionListFilters &&
        other.page == page &&
        other.search == search &&
        other.timeRange == timeRange;
  }

  @override
  int get hashCode => Object.hash(page, search, timeRange);
}

class PrescriptionListFilterNotifier
    extends Notifier<PrescriptionListFilters> {
  @override
  PrescriptionListFilters build() => const PrescriptionListFilters();

  void setSearch(String? search) {
    state = state.copyWith(search: search, page: 1);
  }

  void setTimeRange(String timeRange) {
    state = state.copyWith(timeRange: timeRange, page: 1);
  }

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void goToNextPage(int lastPage) {
    if (state.page < lastPage) {
      state = state.copyWith(page: state.page + 1);
    }
  }

  void goToPreviousPage() {
    if (state.page > 1) {
      state = state.copyWith(page: state.page - 1);
    }
  }
}

final prescriptionListFiltersProvider = NotifierProvider<
    PrescriptionListFilterNotifier, PrescriptionListFilters>(
  PrescriptionListFilterNotifier.new,
);

final prescriptionListProvider = FutureProvider.autoDispose
    .family<Result<PrescriptionListResponse>, PrescriptionListFilters>(
  (ref, filters) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    return await prescriptionService.fetchPrescriptions(
      page: filters.page,
      search: filters.search,
      timeRange: filters.timeRange,
    );
  },
);

// Delete Prescription Provider
final deletePrescriptionProvider =
    FutureProvider.autoDispose.family<Result<void>, int>(
  (ref, prescriptionId) async {
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final prescriptionService = ref.watch(prescriptionServiceProvider);
    return await prescriptionService.deletePrescription(prescriptionId);
  },
);
