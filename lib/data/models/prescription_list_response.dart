// lib/data/models/prescription_list_response.dart
import 'prescription_model.dart';

class PrescriptionListResponse {
  final List<PrescriptionModel> prescriptions;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PrescriptionListResponse({
    required this.prescriptions,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasPagination => lastPage > 1;

  factory PrescriptionListResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> rawPrescriptions = [];
    int currentPage = 1;
    int lastPage = 1;
    int perPage = 0;
    int total = 0;

    if (json['data'] is Map<String, dynamic>) {
      final data = json['data'] as Map<String, dynamic>;

      if (data['data'] is List) {
        rawPrescriptions = data['data'] as List<dynamic>;
      }

      currentPage = (data['current_page'] as num?)?.toInt() ?? 1;
      lastPage = (data['last_page'] as num?)?.toInt() ?? 1;
      perPage = (data['per_page'] as num?)?.toInt() ?? 0;
      total = (data['total'] as num?)?.toInt() ?? 0;
    } else if (json['data'] is List) {
      rawPrescriptions = json['data'] as List<dynamic>;
      perPage = rawPrescriptions.length;
      total = rawPrescriptions.length;
    }

    final prescriptions = rawPrescriptions
        .map((item) => PrescriptionModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return PrescriptionListResponse(
      prescriptions: prescriptions,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
    );
  }
}
