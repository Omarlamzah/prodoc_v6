// lib/providers/medical_record_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import '../services/medical_record_service.dart';
import '../data/models/medical_record_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

final medicalRecordServiceProvider = Provider<MedicalRecordService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MedicalRecordService(apiClient: apiClient);
});

@immutable
class MedicalRecordFilters {
  final int? patientId;
  final int? doctorId;
  final String? date;
  final String? cniNumber;
  final String? globalSearch;

  const MedicalRecordFilters({
    this.patientId,
    this.doctorId,
    this.date,
    this.cniNumber,
    this.globalSearch,
  });

  MedicalRecordFilters copyWith({
    int? patientId,
    int? doctorId,
    String? date,
    String? cniNumber,
    String? globalSearch,
  }) {
    return MedicalRecordFilters(
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      cniNumber: cniNumber ?? this.cniNumber,
      globalSearch: globalSearch ?? this.globalSearch,
    );
  }

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (patientId != null) params['patient_id'] = patientId.toString();
    if (doctorId != null) params['doctor_id'] = doctorId.toString();
    if (date != null && date!.isNotEmpty) params['date'] = date;
    if (cniNumber != null && cniNumber!.isNotEmpty) params['cni_number'] = cniNumber;
    if (globalSearch != null && globalSearch!.isNotEmpty) params['global'] = globalSearch;
    return params;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicalRecordFilters &&
        other.patientId == patientId &&
        other.doctorId == doctorId &&
        other.date == date &&
        other.cniNumber == cniNumber &&
        other.globalSearch == globalSearch;
  }

  @override
  int get hashCode => Object.hash(patientId, doctorId, date, cniNumber, globalSearch);
}

@immutable
class MedicalRecordListState {
  final int page;
  final MedicalRecordFilters filters;

  const MedicalRecordListState({
    this.page = 1,
    this.filters = const MedicalRecordFilters(),
  });

  MedicalRecordListState copyWith({
    int? page,
    MedicalRecordFilters? filters,
  }) {
    return MedicalRecordListState(
      page: page ?? this.page,
      filters: filters ?? this.filters,
    );
  }
}

class MedicalRecordListNotifier extends Notifier<MedicalRecordListState> {
  @override
  MedicalRecordListState build() => const MedicalRecordListState();

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void setFilters(MedicalRecordFilters filters) {
    state = state.copyWith(filters: filters, page: 1);
  }

  void updateFilter({
    int? patientId,
    int? doctorId,
    String? date,
    String? cniNumber,
    String? globalSearch,
  }) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        patientId: patientId,
        doctorId: doctorId,
        date: date,
        cniNumber: cniNumber,
        globalSearch: globalSearch,
      ),
      page: 1,
    );
  }

  void clearFilters() {
    state = const MedicalRecordListState();
  }
}

final medicalRecordListStateProvider =
    NotifierProvider<MedicalRecordListNotifier, MedicalRecordListState>(
  MedicalRecordListNotifier.new,
);

final medicalRecordListProvider = FutureProvider.autoDispose
    .family<Result<List<MedicalRecordModel>>, MedicalRecordListState>(
  (ref, listState) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final medicalRecordService = ref.watch(medicalRecordServiceProvider);
    return medicalRecordService.fetchMedicalRecords(
      page: listState.page,
      filters: listState.filters.toQueryParams(),
    );
  },
);

// Single Medical Record Provider
final medicalRecordProvider = FutureProvider.autoDispose
    .family<Result<MedicalRecordModel>, int>(
  (ref, recordId) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final medicalRecordService = ref.watch(medicalRecordServiceProvider);
    return medicalRecordService.fetchMedicalRecord(recordId);
  },
);

// Patient History Provider
final patientMedicalRecordsProvider = FutureProvider.autoDispose
    .family<Result<List<MedicalRecordModel>>, int>(
  (ref, patientId) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final medicalRecordService = ref.watch(medicalRecordServiceProvider);
    return medicalRecordService.fetchPatientHistory(patientId);
  },
);

// Specialties Provider
final medicalRecordSpecialtiesProvider = FutureProvider.autoDispose<Result<List<dynamic>>>(
  (ref) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final medicalRecordService = ref.watch(medicalRecordServiceProvider);
    return medicalRecordService.fetchSpecialties();
  },
);

// Specialty Fields Provider
final specialtyFieldsProvider = FutureProvider.autoDispose
    .family<Result<Map<String, dynamic>>, int>(
  (ref, specialtyId) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final medicalRecordService = ref.watch(medicalRecordServiceProvider);
    return medicalRecordService.fetchSpecialtyFields(specialtyId);
  },
);

