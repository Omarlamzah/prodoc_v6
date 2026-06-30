// lib/data/models/medication_list_response.dart
import 'medication_model.dart';

class MedicationListResponse {
  final List<MedicationModel> medications;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  MedicationListResponse({
    required this.medications,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  bool get hasPagination => lastPage > 1;

  factory MedicationListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    return MedicationListResponse(
      medications: data
          .map((item) => MedicationModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      total: json['total'] as int? ?? 0,
      perPage: json['per_page'] as int? ?? 15,
    );
  }
}
