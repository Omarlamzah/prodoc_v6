// lib/data/models/dashboard_model.dart
class DashboardModel {
  final Map<String, dynamic>? admin;
  final Map<String, dynamic>? doctor;
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? receptionist;

  DashboardModel({
    this.admin,
    this.doctor,
    this.patient,
    this.receptionist,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    // Check if data is nested under 'dashboard' key
    final dashboardData = json['dashboard'] ?? json;
    
    return DashboardModel(
      admin: dashboardData['admin'] as Map<String, dynamic>?,
      doctor: dashboardData['doctor'] as Map<String, dynamic>?,
      patient: dashboardData['patient'] as Map<String, dynamic>?,
      receptionist: dashboardData['receptionist'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin': admin,
      'doctor': doctor,
      'patient': patient,
      'receptionist': receptionist,
    };
  }
}