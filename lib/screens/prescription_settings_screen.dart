// lib/screens/prescription_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ordonnance_setting_providers.dart';
import '../providers/api_providers.dart';
import '../data/models/ordonnance_setting_model.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as custom;
import '../providers/auth_providers.dart';

class PrescriptionSettingsScreen extends ConsumerStatefulWidget {
  const PrescriptionSettingsScreen({super.key});

  @override
  ConsumerState<PrescriptionSettingsScreen> createState() =>
      _PrescriptionSettingsScreenState();
}

class _PrescriptionSettingsScreenState
    extends ConsumerState<PrescriptionSettingsScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _headerTextController;
  late TextEditingController _footerTextController;
  late TextEditingController _doctorNameController;
  late TextEditingController _doctorTitleController;
  late TextEditingController _clinicNameController;
  late TextEditingController _clinicAddressController;
  late TextEditingController _clinicPhoneController;
  late TextEditingController _clinicEmailController;

  // Boolean values for display options
  bool _showHeader = true;
  bool _showFooter = true;
  bool _showPrescriptionNumber = true;
  bool _showPrescriptionDate = true;
  bool _showPatientInfo = true;
  bool _showPatientAddress = true;
  bool _showPatientAge = true;
  bool _showMedicationsTable = true;
  bool _showDosageInstructions = true;
  bool _showRenewalInfo = true;
  bool _showPatientSignature = false;
  bool _showDoctorSignature = true;
  bool _showStamp = false;
  bool _showDoctorSpecialty = false;
  bool _showDoctorAvailability = false;
  bool _showDoctorBiography = false;
  bool _showLogo = false;
  bool _showQRCode = false;
  bool _showBarcode = false;
  bool _showGenerationInfo = false;

  OrdonnanceSettingModel? _currentSettings;

  @override
  void dispose() {
    _headerTextController.dispose();
    _footerTextController.dispose();
    _doctorNameController.dispose();
    _doctorTitleController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _clinicEmailController.dispose();
    super.dispose();
  }

  void _initializeControllers(OrdonnanceSettingModel settings) {
    _headerTextController =
        TextEditingController(text: settings.headerText ?? '');
    _footerTextController =
        TextEditingController(text: settings.footerText ?? '');
    _doctorNameController =
        TextEditingController(text: settings.doctorName ?? '');
    _doctorTitleController =
        TextEditingController(text: settings.doctorTitle ?? '');
    _clinicNameController =
        TextEditingController(text: settings.clinicName ?? '');
    _clinicAddressController =
        TextEditingController(text: settings.clinicAddress ?? '');
    _clinicPhoneController =
        TextEditingController(text: settings.clinicPhone ?? '');
    _clinicEmailController =
        TextEditingController(text: settings.clinicEmail ?? '');

    _showHeader = settings.showHeader ?? true;
    _showFooter = settings.showFooter ?? true;
    _showPrescriptionNumber = settings.showPrescriptionNumber ?? true;
    _showPrescriptionDate = settings.showPrescriptionDate ?? true;
    _showPatientInfo = settings.showPatientInfo ?? true;
    _showPatientAddress = settings.showPatientAddress ?? true;
    _showPatientAge = settings.showPatientAge ?? true;
    _showMedicationsTable = settings.showMedicationsTable ?? true;
    _showDosageInstructions = settings.showDosageInstructions ?? true;
    _showRenewalInfo = settings.showRenewalInfo ?? true;
    _showPatientSignature = settings.showPatientSignature ?? false;
    _showDoctorSignature = settings.showDoctorSignature ?? true;
    _showStamp = settings.showStamp ?? false;
    _showDoctorSpecialty = settings.showDoctorSpecialty ?? false;
    _showDoctorAvailability = settings.showDoctorAvailability ?? false;
    _showDoctorBiography = settings.showDoctorBiography ?? false;
    _showLogo = settings.showLogo ?? false;
    _showQRCode = settings.showQRCode ?? false;
    _showBarcode = settings.showBarcode ?? false;
    _showGenerationInfo = settings.showGenerationInfo ?? false;

    _currentSettings = settings;
  }

  bool _canEdit() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    return user != null &&
        (user.isAdmin == 1 || user.isDoctor == 1 || user.isReceptionist == 1);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final ordonnanceSettingService =
          ref.read(ordonnanceSettingServiceProvider);

      final updateData = {
        'header_text': _headerTextController.text.trim(),
        'footer_text': _footerTextController.text.trim(),
        'doctor_name': _doctorNameController.text.trim(),
        'doctor_title': _doctorTitleController.text.trim(),
        'clinic_name': _clinicNameController.text.trim(),
        'clinic_address': _clinicAddressController.text.trim(),
        'clinic_phone': _clinicPhoneController.text.trim(),
        'clinic_email': _clinicEmailController.text.trim(),
        'show_header': _showHeader ? 1 : 0,
        'show_footer': _showFooter ? 1 : 0,
        'show_prescription_number': _showPrescriptionNumber ? 1 : 0,
        'show_prescription_date': _showPrescriptionDate ? 1 : 0,
        'show_patient_info': _showPatientInfo ? 1 : 0,
        'show_patient_address': _showPatientAddress ? 1 : 0,
        'show_patient_age': _showPatientAge ? 1 : 0,
        'show_medications_table': _showMedicationsTable ? 1 : 0,
        'show_dosage_instructions': _showDosageInstructions ? 1 : 0,
        'show_renewal_info': _showRenewalInfo ? 1 : 0,
        'show_patient_signature': _showPatientSignature ? 1 : 0,
        'show_doctor_signature': _showDoctorSignature ? 1 : 0,
        'show_stamp': _showStamp ? 1 : 0,
        'show_doctor_specialty': _showDoctorSpecialty ? 1 : 0,
        'show_doctor_availability': _showDoctorAvailability ? 1 : 0,
        'show_doctor_biography': _showDoctorBiography ? 1 : 0,
        'show_logo': _showLogo ? 1 : 0,
        'show_qr_code': _showQRCode ? 1 : 0,
        'show_barcode': _showBarcode ? 1 : 0,
        'show_generation_info': _showGenerationInfo ? 1 : 0,
      };

      final result =
          await ordonnanceSettingService.updateOrdonnanceSettings(updateData);

      if (result is Success<OrdonnanceSettingModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Paramètres de l\'ordonnance mis à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(ordonnanceSettingsProvider);
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        }
      } else if (result is Failure<OrdonnanceSettingModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser les paramètres'),
        content: const Text(
          'Êtes-vous sûr de vouloir réinitialiser tous les paramètres aux valeurs par défaut ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final ordonnanceSettingService =
          ref.read(ordonnanceSettingServiceProvider);
      final result = await ordonnanceSettingService.resetOrdonnanceSettings();

      if (result is Success<OrdonnanceSettingModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paramètres réinitialisés avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(ordonnanceSettingsProvider);
          setState(() => _isSaving = false);
        }
      } else if (result is Failure<OrdonnanceSettingModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _startEditing(OrdonnanceSettingModel settings) {
    _initializeControllers(settings);
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(ordonnanceSettingsProvider);
    final canEdit = _canEdit();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F23) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.description_rounded, size: 24),
            SizedBox(width: 8),
            Text('Paramètres Ordonnance'),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: canEdit && !_isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () {
                    settingsAsync.whenData((result) {
                      if (result is Success<OrdonnanceSettingModel>) {
                        _startEditing(result.data);
                      }
                    });
                  },
                  tooltip: 'Modifier',
                ),
              ]
            : null,
      ),
      body: settingsAsync.when(
        data: (result) {
          if (result is Success<OrdonnanceSettingModel>) {
            if (_currentSettings?.id != result.data.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_isEditing) {
                  _initializeControllers(result.data);
                }
              });
            }
            return _buildContent(context, result.data, isDark, canEdit);
          } else if (result is Failure<OrdonnanceSettingModel>) {
            return custom.CustomErrorWidget(message: result.message);
          }
          return const custom.CustomErrorWidget(
              message: 'Unknown error occurred');
        },
        loading: () => const LoadingWidget(),
        error: (error, _) =>
            custom.CustomErrorWidget(message: error.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrdonnanceSettingModel settings,
      bool isDark, bool canEdit) {
    if (_isEditing) {
      return _buildEditForm(context, settings, isDark);
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionCard(
          context: context,
          isDark: isDark,
          icon: Icons.text_fields_rounded,
          title: 'En-tête et Pied de page',
          children: [
            _buildInfoRow('Texte d\'en-tête',
                settings.headerText ?? 'Non défini', isDark),
            const SizedBox(height: 12),
            _buildInfoRow('Texte de pied de page',
                settings.footerText ?? 'Non défini', isDark),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          context: context,
          isDark: isDark,
          icon: Icons.person_rounded,
          title: 'Informations Médecin',
          children: [
            _buildInfoRow(
                'Nom du médecin', settings.doctorName ?? 'Non défini', isDark),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Titre', settings.doctorTitle ?? 'Non défini', isDark),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          context: context,
          isDark: isDark,
          icon: Icons.local_hospital_rounded,
          title: 'Informations Cabinet',
          children: [
            _buildInfoRow(
                'Nom du cabinet', settings.clinicName ?? 'Non défini', isDark),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Adresse', settings.clinicAddress ?? 'Non défini', isDark),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Téléphone', settings.clinicPhone ?? 'Non défini', isDark),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Email', settings.clinicEmail ?? 'Non défini', isDark),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          context: context,
          isDark: isDark,
          icon: Icons.visibility_rounded,
          title: 'Éléments d\'Affichage',
          subtitle: 'Choisissez quels éléments afficher sur l\'ordonnance',
          children: [
            _buildDisplayOptionsTable(settings, isDark),
          ],
        ),
        if (canEdit) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _resetSettings,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Réinitialiser aux valeurs par défaut'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEditForm(
      BuildContext context, OrdonnanceSettingModel settings, bool isDark) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionCard(
            context: context,
            isDark: isDark,
            icon: Icons.text_fields_rounded,
            title: 'En-tête et Pied de page',
            children: [
              TextFormField(
                controller: _headerTextController,
                decoration: const InputDecoration(
                  labelText: 'Texte d\'en-tête',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _footerTextController,
                decoration: const InputDecoration(
                  labelText: 'Texte de pied de page',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            isDark: isDark,
            icon: Icons.person_rounded,
            title: 'Informations Médecin',
            children: [
              TextFormField(
                controller: _doctorNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du médecin',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doctorTitleController,
                decoration: const InputDecoration(
                  labelText: 'Titre (ex: Dr., Pr.)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            isDark: isDark,
            icon: Icons.local_hospital_rounded,
            title: 'Informations Cabinet',
            children: [
              TextFormField(
                controller: _clinicNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du cabinet',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clinicAddressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clinicPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clinicEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            isDark: isDark,
            icon: Icons.visibility_rounded,
            title: 'Éléments d\'Affichage',
            subtitle: 'Choisissez quels éléments afficher sur l\'ordonnance',
            children: [
              _buildDisplayOptionsEditTable(isDark),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _cancelEditing,
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayOptionsTable(
      OrdonnanceSettingModel settings, bool isDark) {
    final options = [
      {
        'label': 'En-tête',
        'icon': Icons.text_fields_rounded,
        'value': settings.showHeader ?? true
      },
      {
        'label': 'Pied de page',
        'icon': Icons.text_fields_rounded,
        'value': settings.showFooter ?? true
      },
      {
        'label': 'Numéro d\'ordonnance',
        'icon': Icons.numbers_rounded,
        'value': settings.showPrescriptionNumber ?? true
      },
      {
        'label': 'Date d\'ordonnance',
        'icon': Icons.calendar_today_rounded,
        'value': settings.showPrescriptionDate ?? true
      },
      {
        'label': 'Informations patient',
        'icon': Icons.person_rounded,
        'value': settings.showPatientInfo ?? true
      },
      {
        'label': 'Adresse patient',
        'icon': Icons.location_on_rounded,
        'value': settings.showPatientAddress ?? true
      },
      {
        'label': 'Âge patient',
        'icon': Icons.cake_rounded,
        'value': settings.showPatientAge ?? true
      },
      {
        'label': 'Tableau des médicaments',
        'icon': Icons.medication_rounded,
        'value': settings.showMedicationsTable ?? true
      },
      {
        'label': 'Instructions de dosage',
        'icon': Icons.info_rounded,
        'value': settings.showDosageInstructions ?? true
      },
      {
        'label': 'Info renouvellement',
        'icon': Icons.refresh_rounded,
        'value': settings.showRenewalInfo ?? true
      },
      {
        'label': 'Signature patient',
        'icon': Icons.edit_rounded,
        'value': settings.showPatientSignature ?? false
      },
      {
        'label': 'Signature médecin',
        'icon': Icons.draw_rounded,
        'value': settings.showDoctorSignature ?? true
      },
      {
        'label': 'Tampon',
        'icon': Icons.verified_rounded,
        'value': settings.showStamp ?? false
      },
      {
        'label': 'Spécialité médecin',
        'icon': Icons.medical_services_rounded,
        'value': settings.showDoctorSpecialty ?? false
      },
      {
        'label': 'Disponibilité médecin',
        'icon': Icons.access_time_rounded,
        'value': settings.showDoctorAvailability ?? false
      },
      {
        'label': 'Biographie médecin',
        'icon': Icons.description_rounded,
        'value': settings.showDoctorBiography ?? false
      },
      {
        'label': 'Logo',
        'icon': Icons.image_rounded,
        'value': settings.showLogo ?? false
      },
      {
        'label': 'Code QR',
        'icon': Icons.qr_code_rounded,
        'value': settings.showQRCode ?? false
      },
      {
        'label': 'Code-barres',
        'icon': Icons.qr_code_scanner_rounded,
        'value': settings.showBarcode ?? false
      },
      {
        'label': 'Info génération',
        'icon': Icons.info_outline_rounded,
        'value': settings.showGenerationInfo ?? false
      },
    ];

    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(
                option['icon'] as IconData,
                size: 20,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option['label'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Switch(
                value: option['value'] as bool,
                onChanged: null, // Read-only in view mode
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDisplayOptionsEditTable(bool isDark) {
    final options = [
      {
        'label': 'En-tête',
        'icon': Icons.text_fields_rounded,
        'value': _showHeader,
        'onChanged': (bool v) => setState(() => _showHeader = v)
      },
      {
        'label': 'Pied de page',
        'icon': Icons.text_fields_rounded,
        'value': _showFooter,
        'onChanged': (bool v) => setState(() => _showFooter = v)
      },
      {
        'label': 'Numéro d\'ordonnance',
        'icon': Icons.numbers_rounded,
        'value': _showPrescriptionNumber,
        'onChanged': (bool v) => setState(() => _showPrescriptionNumber = v)
      },
      {
        'label': 'Date d\'ordonnance',
        'icon': Icons.calendar_today_rounded,
        'value': _showPrescriptionDate,
        'onChanged': (bool v) => setState(() => _showPrescriptionDate = v)
      },
      {
        'label': 'Informations patient',
        'icon': Icons.person_rounded,
        'value': _showPatientInfo,
        'onChanged': (bool v) => setState(() => _showPatientInfo = v)
      },
      {
        'label': 'Adresse patient',
        'icon': Icons.location_on_rounded,
        'value': _showPatientAddress,
        'onChanged': (bool v) => setState(() => _showPatientAddress = v)
      },
      {
        'label': 'Âge patient',
        'icon': Icons.cake_rounded,
        'value': _showPatientAge,
        'onChanged': (bool v) => setState(() => _showPatientAge = v)
      },
      {
        'label': 'Tableau des médicaments',
        'icon': Icons.medication_rounded,
        'value': _showMedicationsTable,
        'onChanged': (bool v) => setState(() => _showMedicationsTable = v)
      },
      {
        'label': 'Instructions de dosage',
        'icon': Icons.info_rounded,
        'value': _showDosageInstructions,
        'onChanged': (bool v) => setState(() => _showDosageInstructions = v)
      },
      {
        'label': 'Info renouvellement',
        'icon': Icons.refresh_rounded,
        'value': _showRenewalInfo,
        'onChanged': (bool v) => setState(() => _showRenewalInfo = v)
      },
      {
        'label': 'Signature patient',
        'icon': Icons.edit_rounded,
        'value': _showPatientSignature,
        'onChanged': (bool v) => setState(() => _showPatientSignature = v)
      },
      {
        'label': 'Signature médecin',
        'icon': Icons.draw_rounded,
        'value': _showDoctorSignature,
        'onChanged': (bool v) => setState(() => _showDoctorSignature = v)
      },
      {
        'label': 'Tampon',
        'icon': Icons.verified_rounded,
        'value': _showStamp,
        'onChanged': (bool v) => setState(() => _showStamp = v)
      },
      {
        'label': 'Spécialité médecin',
        'icon': Icons.medical_services_rounded,
        'value': _showDoctorSpecialty,
        'onChanged': (bool v) => setState(() => _showDoctorSpecialty = v)
      },
      {
        'label': 'Disponibilité médecin',
        'icon': Icons.access_time_rounded,
        'value': _showDoctorAvailability,
        'onChanged': (bool v) => setState(() => _showDoctorAvailability = v)
      },
      {
        'label': 'Biographie médecin',
        'icon': Icons.description_rounded,
        'value': _showDoctorBiography,
        'onChanged': (bool v) => setState(() => _showDoctorBiography = v)
      },
      {
        'label': 'Logo',
        'icon': Icons.image_rounded,
        'value': _showLogo,
        'onChanged': (bool v) => setState(() => _showLogo = v)
      },
      {
        'label': 'Code QR',
        'icon': Icons.qr_code_rounded,
        'value': _showQRCode,
        'onChanged': (bool v) => setState(() => _showQRCode = v)
      },
      {
        'label': 'Code-barres',
        'icon': Icons.qr_code_scanner_rounded,
        'value': _showBarcode,
        'onChanged': (bool v) => setState(() => _showBarcode = v)
      },
      {
        'label': 'Info génération',
        'icon': Icons.info_outline_rounded,
        'value': _showGenerationInfo,
        'onChanged': (bool v) => setState(() => _showGenerationInfo = v)
      },
    ];

    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(
                option['icon'] as IconData,
                size: 20,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option['label'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Switch(
                value: option['value'] as bool,
                onChanged: option['onChanged'] as Function(bool),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
