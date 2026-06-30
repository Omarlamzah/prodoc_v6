// lib/providers/medication_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import '../data/models/medication_model.dart';
import '../data/models/medication_list_response.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import '../services/medication_service.dart';

@immutable
class MedicationListFilters {
  final int page;
  final String? search;

  const MedicationListFilters({
    this.page = 1,
    this.search,
  });

  MedicationListFilters copyWith({
    int? page,
    String? search,
  }) {
    return MedicationListFilters(
      page: page ?? this.page,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicationListFilters &&
        other.page == page &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(page, search);
}

class MedicationListFilterNotifier extends Notifier<MedicationListFilters> {
  @override
  MedicationListFilters build() => const MedicationListFilters();

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void setSearch(String? search) {
    state = state.copyWith(search: search, page: 1);
  }

  void clearSearch() {
    state = state.copyWith(search: null, page: 1);
  }
}

final medicationServiceProvider = Provider<MedicationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MedicationService(apiClient: apiClient);
});

final medicationListFiltersProvider =
    NotifierProvider<MedicationListFilterNotifier, MedicationListFilters>(
  MedicationListFilterNotifier.new,
);

final medicationListProvider = FutureProvider.autoDispose
    .family<Result<MedicationListResponse>, MedicationListFilters>(
  (ref, filters) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final medicationService = ref.watch(medicationServiceProvider);
    return medicationService.fetchMedications(
      page: filters.page,
      search: filters.search,
    );
  },
);

