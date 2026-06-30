// lib/providers/patient_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import '../data/models/patient_model.dart';
import '../data/models/patient_list_response.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

@immutable
class PatientListFilters {
  final int page;
  final String filter;
  final String sortColumn;
  final String sortDirection;

  const PatientListFilters({
    this.page = 1,
    this.filter = 'today',
    this.sortColumn = 'id',
    this.sortDirection = 'asc',
  });

  PatientListFilters copyWith({
    int? page,
    String? filter,
    String? sortColumn,
    String? sortDirection,
  }) {
    return PatientListFilters(
      page: page ?? this.page,
      filter: filter ?? this.filter,
      sortColumn: sortColumn ?? this.sortColumn,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatientListFilters &&
        other.page == page &&
        other.filter == filter &&
        other.sortColumn == sortColumn &&
        other.sortDirection == sortDirection;
  }

  @override
  int get hashCode => Object.hash(page, filter, sortColumn, sortDirection);
}

class PatientListFilterNotifier extends Notifier<PatientListFilters> {
  @override
  PatientListFilters build() => const PatientListFilters();

  void setFilter(String filter) {
    state = state.copyWith(filter: filter, page: 1);
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

  void setSortColumn(String column) {
    if (state.sortColumn == column) {
      // toggle direction
      final newDirection = state.sortDirection == 'asc' ? 'desc' : 'asc';
      state = state.copyWith(sortDirection: newDirection);
    } else {
      state = state.copyWith(sortColumn: column, sortDirection: 'asc', page: 1);
    }
  }

  void setSortDirection(String direction) {
    state = state.copyWith(sortDirection: direction, page: 1);
  }
}

final patientListFiltersProvider =
    NotifierProvider<PatientListFilterNotifier, PatientListFilters>(
  PatientListFilterNotifier.new,
);

final patientListProvider = FutureProvider.autoDispose
    .family<Result<PatientListResponse>, PatientListFilters>(
  (ref, filters) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final patientService = ref.watch(patientServiceProvider);
    return patientService.fetchPatients(
      page: filters.page,
      filter: filters.filter,
      sortColumn: filters.sortColumn,
      sortDirection: filters.sortDirection,
    );
  },
);

// Find Patients Provider (search suggestions / quick lookup)
final findPatientsProvider =
    FutureProvider.autoDispose.family<Result<List<PatientModel>>, String>(
  (ref, search) async {
    final trimmed = search.trim();
    final authState = ref.watch(authProvider);

    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    if (trimmed.length < 2) {
      return const Success(<PatientModel>[]);
    }

    final patientService = ref.watch(patientServiceProvider);
    return patientService.findPatients(trimmed);
  },
);

// Single Patient Provider
final patientProvider = FutureProvider.autoDispose
    .family<Result<PatientModel>, int>(
  (ref, patientId) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final patientService = ref.watch(patientServiceProvider);
    return patientService.fetchPatient(patientId);
  },
);

