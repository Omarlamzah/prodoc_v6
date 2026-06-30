import 'patient_model.dart';

class PatientListResponse {
  final List<PatientModel> patients;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PatientListResponse({
    required this.patients,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasPagination => lastPage > 1;

  factory PatientListResponse.fromJson(dynamic json) {
    List<dynamic> rawPatients = [];
    int currentPage = 1;
    int lastPage = 1;
    int perPage = 0;
    int total = 0;

    if (json is List) {
      rawPatients = json;
      perPage = rawPatients.length;
      total = rawPatients.length;
    } else if (json is Map<String, dynamic>) {
      if (json['data'] is List) {
        rawPatients = json['data'] as List<dynamic>;
      } else if (json['patients'] is List) {
        rawPatients = json['patients'] as List<dynamic>;
      }

      // Laravel pagination style
      if (json.containsKey('current_page')) {
        currentPage = (json['current_page'] as num?)?.toInt() ?? 1;
      } else if (json['meta'] is Map<String, dynamic>) {
        final meta = json['meta'] as Map<String, dynamic>;
        currentPage = (meta['current_page'] as num?)?.toInt() ?? 1;
      }

      if (json.containsKey('last_page')) {
        lastPage = (json['last_page'] as num?)?.toInt() ?? 1;
      } else if (json['meta'] is Map<String, dynamic>) {
        final meta = json['meta'] as Map<String, dynamic>;
        lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
      }

      if (json.containsKey('per_page')) {
        perPage = (json['per_page'] as num?)?.toInt() ?? 0;
      } else if (json['meta'] is Map<String, dynamic>) {
        final meta = json['meta'] as Map<String, dynamic>;
        perPage = (meta['per_page'] as num?)?.toInt() ?? 0;
      }

      if (json.containsKey('total')) {
        total = (json['total'] as num?)?.toInt() ?? rawPatients.length;
      } else if (json['meta'] is Map<String, dynamic>) {
        final meta = json['meta'] as Map<String, dynamic>;
        total = (meta['total'] as num?)?.toInt() ?? rawPatients.length;
      } else {
        total = rawPatients.length;
      }
    }

    final patients = rawPatients
        .map((item) => PatientModel.fromJson(item as Map<String, dynamic>))
        .toList();

    perPage = perPage == 0 ? patients.length : perPage;
    total = total == 0 ? patients.length : total;

    return PatientListResponse(
      patients: patients,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
    );
  }
}

