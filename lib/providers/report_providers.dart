// lib/providers/report_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

@immutable
class ReportFilters {
  final String reportType;
  final String? startDate;
  final String? endDate;
  final String? doctorId;
  final String? status;
  final String? gender;
  final String? bloodType;
  final String? insuranceType;
  final String? medicationCode;
  final bool lowStock;
  final bool expiringSoon;
  final String? search;
  final String? sortBy;
  final String sortDirection;
  final int perPage;
  final int page;

  const ReportFilters({
    required this.reportType,
    this.startDate,
    this.endDate,
    this.doctorId,
    this.status,
    this.gender,
    this.bloodType,
    this.insuranceType,
    this.medicationCode,
    this.lowStock = false,
    this.expiringSoon = false,
    this.search,
    this.sortBy,
    this.sortDirection = 'desc',
    this.perPage = 10,
    this.page = 1,
  });

  ReportFilters copyWith({
    String? reportType,
    String? startDate,
    String? endDate,
    String? doctorId,
    String? status,
    String? gender,
    String? bloodType,
    String? insuranceType,
    String? medicationCode,
    bool? lowStock,
    bool? expiringSoon,
    String? search,
    String? sortBy,
    String? sortDirection,
    int? perPage,
    int? page,
  }) {
    return ReportFilters(
      reportType: reportType ?? this.reportType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      doctorId: doctorId ?? this.doctorId,
      status: status ?? this.status,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      insuranceType: insuranceType ?? this.insuranceType,
      medicationCode: medicationCode ?? this.medicationCode,
      lowStock: lowStock ?? this.lowStock,
      expiringSoon: expiringSoon ?? this.expiringSoon,
      search: search ?? this.search,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      perPage: perPage ?? this.perPage,
      page: page ?? this.page,
    );
  }

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'per_page': perPage.toString(),
      'page': page.toString(),
      'sort_direction': sortDirection,
    };

    if (startDate != null && startDate!.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate!.isNotEmpty) {
      params['end_date'] = endDate;
    }
    if (doctorId != null && doctorId!.isNotEmpty) {
      params['doctor_id'] = doctorId;
    }
    if (status != null && status!.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (gender != null && gender!.isNotEmpty && gender != 'all') {
      params['gender'] = gender;
    }
    if (bloodType != null && bloodType!.isNotEmpty) {
      params['blood_type'] = bloodType;
    }
    if (insuranceType != null &&
        insuranceType!.isNotEmpty &&
        insuranceType != 'all') {
      params['insurance_type'] = insuranceType;
    }
    if (medicationCode != null && medicationCode!.isNotEmpty) {
      params['medication_code'] = medicationCode;
    }
    if (lowStock) {
      params['low_stock'] = '1';
    }
    if (expiringSoon) {
      params['expiring_soon'] = '1';
    }
    if (search != null && search!.isNotEmpty) {
      params['search'] = search;
    }
    if (sortBy != null && sortBy!.isNotEmpty) {
      params['sort_by'] = sortBy;
    }

    return params;
  }
}

class ReportFiltersNotifier extends Notifier<ReportFilters> {
  @override
  ReportFilters build() => const ReportFilters(reportType: 'appointments');

  void setReportType(String reportType) {
    state = ReportFilters(reportType: reportType);
  }

  void updateFilter(String key, dynamic value) {
    switch (key) {
      case 'start_date':
        state = state.copyWith(startDate: value as String?, page: 1);
        break;
      case 'end_date':
        state = state.copyWith(endDate: value as String?, page: 1);
        break;
      case 'doctor_id':
        state = state.copyWith(doctorId: value as String?, page: 1);
        break;
      case 'status':
        state = state.copyWith(status: value as String?, page: 1);
        break;
      case 'gender':
        state = state.copyWith(gender: value as String?, page: 1);
        break;
      case 'blood_type':
        state = state.copyWith(bloodType: value as String?, page: 1);
        break;
      case 'insurance_type':
        state = state.copyWith(insuranceType: value as String?, page: 1);
        break;
      case 'medication_code':
        state = state.copyWith(medicationCode: value as String?, page: 1);
        break;
      case 'low_stock':
        state = state.copyWith(lowStock: value as bool, page: 1);
        break;
      case 'expiring_soon':
        state = state.copyWith(expiringSoon: value as bool, page: 1);
        break;
      case 'search':
        state = state.copyWith(search: value as String?, page: 1);
        break;
      default:
        break;
    }
  }

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void setPerPage(int perPage) {
    state = state.copyWith(perPage: perPage, page: 1);
  }

  void setSort(String sortBy) {
    final newDirection =
        state.sortBy == sortBy && state.sortDirection == 'asc' ? 'desc' : 'asc';
    state =
        state.copyWith(sortBy: sortBy, sortDirection: newDirection, page: 1);
  }

  void resetFilters() {
    state = ReportFilters(reportType: state.reportType);
  }
}

final reportFiltersProvider =
    NotifierProvider<ReportFiltersNotifier, ReportFilters>(
  ReportFiltersNotifier.new,
);

final reportDataProvider = FutureProvider.autoDispose
    .family<Result<Map<String, dynamic>>, ReportFilters>(
  (ref, filters) async {
    final authState = ref.watch(authProvider);
    if (authState.isAuth != true) {
      return const Failure('Not authenticated');
    }

    final reportService = ref.watch(reportServiceProvider);
    return reportService.fetchReport(
      reportType: filters.reportType,
      filters: filters.toQueryParams(),
    );
  },
);
