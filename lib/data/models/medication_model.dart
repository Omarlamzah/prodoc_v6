// lib/data/models/medication_model.dart
class MedicationModel {
  final String? code;
  final String? nom;
  final String? dci1;
  final String? dosage1;
  final String? uniteDosage1;
  final String? forme;
  final String? presentation;
  final String? ppv;
  final String? ph;
  final String? prixBr;
  final String? princepsGenerique;
  final String? tauxRemboursement;
  final Map<String, dynamic>? additionalData;

  MedicationModel({
    this.code,
    this.nom,
    this.dci1,
    this.dosage1,
    this.uniteDosage1,
    this.forme,
    this.presentation,
    this.ppv,
    this.ph,
    this.prixBr,
    this.princepsGenerique,
    this.tauxRemboursement,
    this.additionalData,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    // Handle CODE as either int or String
    String? codeValue;
    if (json['CODE'] != null) {
      if (json['CODE'] is int) {
        codeValue = json['CODE'].toString();
      } else if (json['CODE'] is String) {
        codeValue = json['CODE'] as String;
      }
    }

    // Helper function to safely convert values to String
    String? _toString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    return MedicationModel(
      code: codeValue,
      nom: _toString(json['NOM']),
      dci1: _toString(json['DCI1']),
      dosage1: _toString(json['DOSAGE1']),
      uniteDosage1: _toString(json['UNITE_DOSAGE1']),
      forme: _toString(json['FORME']),
      presentation: _toString(json['PRESENTATION']),
      ppv: _toString(json['PPV']),
      ph: _toString(json['PH']),
      prixBr: _toString(json['PRIX_BR']),
      princepsGenerique: _toString(json['PRINCEPS_GENERIQUE']),
      tauxRemboursement: _toString(json['TAUX_REMBOURSEMENT']),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (code != null) map['CODE'] = code;
    if (nom != null) map['NOM'] = nom;
    if (dci1 != null) map['DCI1'] = dci1;
    if (dosage1 != null) map['DOSAGE1'] = dosage1;
    if (uniteDosage1 != null) map['UNITE_DOSAGE1'] = uniteDosage1;
    if (forme != null) map['FORME'] = forme;
    if (presentation != null) map['PRESENTATION'] = presentation;
    if (ppv != null) map['PPV'] = ppv;
    if (ph != null) map['PH'] = ph;
    if (prixBr != null) map['PRIX_BR'] = prixBr;
    if (princepsGenerique != null)
      map['PRINCEPS_GENERIQUE'] = princepsGenerique;
    if (tauxRemboursement != null)
      map['TAUX_REMBOURSEMENT'] = tauxRemboursement;
    return map;
  }

  MedicationModel copyWith({
    String? code,
    String? nom,
    String? dci1,
    String? dosage1,
    String? uniteDosage1,
    String? forme,
    String? presentation,
    String? ppv,
    String? ph,
    String? prixBr,
    String? princepsGenerique,
    String? tauxRemboursement,
  }) {
    return MedicationModel(
      code: code ?? this.code,
      nom: nom ?? this.nom,
      dci1: dci1 ?? this.dci1,
      dosage1: dosage1 ?? this.dosage1,
      uniteDosage1: uniteDosage1 ?? this.uniteDosage1,
      forme: forme ?? this.forme,
      presentation: presentation ?? this.presentation,
      ppv: ppv ?? this.ppv,
      ph: ph ?? this.ph,
      prixBr: prixBr ?? this.prixBr,
      princepsGenerique: princepsGenerique ?? this.princepsGenerique,
      tauxRemboursement: tauxRemboursement ?? this.tauxRemboursement,
    );
  }
}
