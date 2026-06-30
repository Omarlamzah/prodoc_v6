// lib/data/models/tenant_model.dart - Update to build baseUrl from domain
class TenantModel {
  final int? id;
  final String? name;
  final String? domain;
  final String? phone;
  final String? email;
  final String? city;
  final String? baseUrl;
  final Map<String, dynamic>? additionalData;

  TenantModel({
    this.id,
    this.name,
    this.domain,
    this.phone,
    this.email,
    this.city,
    this.baseUrl,
    this.additionalData,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    // Build baseUrl from domain if not provided
    String? calculatedBaseUrl;
    final domain = json['domain'] as String?;
    
    if (domain != null && domain.isNotEmpty) {
      // Convert domain like "dentairealami.nextpital.com" to "https://dentairealami.nextpital.com/api/public"
      calculatedBaseUrl = 'https://$domain/api/public';
    }
    
    return TenantModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
      domain: domain,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      city: json['city'] as String?,
      baseUrl: json['base_url'] as String? ?? calculatedBaseUrl,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'domain': domain,
      'phone': phone,
      'email': email,
      'city': city,
      'base_url': baseUrl,
      ...?additionalData,
    };
  }

  TenantModel copyWith({
    int? id,
    String? name,
    String? domain,
    String? phone,
    String? email,
    String? city,
    String? baseUrl,
    Map<String, dynamic>? additionalData,
  }) {
    return TenantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      domain: domain ?? this.domain,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
      baseUrl: baseUrl ?? this.baseUrl,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}