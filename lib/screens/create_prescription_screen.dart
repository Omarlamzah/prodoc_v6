// lib/screens/create_prescription_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../providers/prescription_providers.dart';
import '../providers/auth_providers.dart';
import '../data/models/patient_model.dart';
import '../data/models/medication_model.dart';
import '../data/models/prescription_template_model.dart';
import '../data/models/prescription_model.dart';
import '../core/config/api_constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../services/speech_to_text_service.dart';
import '../providers/api_providers.dart' show aiChatServiceProvider;
import '../widgets/ai_scribe_soap_widget.dart';

enum PrescriptionStep { patient, medical, medications }

/// Helper function to trigger vibration with multiple fallback methods
/// Note: Vibration requires VIBRATE permission (already in AndroidManifest.xml)
/// If vibration doesn't work, check:
/// 1. Device vibration is enabled in system settings
/// 2. App has vibration permission (should be automatic for VIBRATE)
/// 3. Device supports haptic feedback
Future<void> _triggerVibration() async {
  try {
    // Try medium impact first (most common and strongest)
    HapticFeedback.mediumImpact();

    // Also try selection feedback for better compatibility on some devices
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.selectionClick();
  } catch (e) {
    debugPrint('Vibration error: $e');
    // Fallback: try light impact
    try {
      HapticFeedback.lightImpact();
    } catch (e2) {
      debugPrint('Fallback vibration also failed: $e2');
      debugPrint(
          'Note: Check if device vibration is enabled in system settings');
    }
  }
}

class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  final PatientModel? currentPatient;

  const CreatePrescriptionScreen({super.key, this.currentPatient});

  @override
  ConsumerState<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState
    extends ConsumerState<CreatePrescriptionScreen>
    with TickerProviderStateMixin {
  PrescriptionStep _currentStep = PrescriptionStep.patient;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _listeningAnimationController;
  late Animation<double> _listeningPulseAnimation;
  final ScrollController _scrollController = ScrollController();

  // Patient search
  final _patientSearchController = TextEditingController();
  PatientModel? _selectedPatient;
  dynamic _selectedMedicalRecord;
  List<PatientModel> _foundPatients = [];
  bool _isSearchingPatients = false;

  // Medical information
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _followUpDateController = TextEditingController();

  // Medications
  final List<Map<String, dynamic>> _medications = [];
  final List<TextEditingController> _medicationSearchControllers = [];
  final List<List<MedicationModel>> _foundMedications = [];
  final List<bool> _isSearchingMedications = [];

  // Templates
  final _templateSearchController = TextEditingController();
  List<PrescriptionTemplateModel> _foundTemplates = [];
  bool _isSearchingTemplates = false;
  PrescriptionTemplateModel? _selectedTemplate;

  // Form data
  bool _sendWhatsapp = false;
  bool _sendEmail = false;
  bool _isSubmitting = false;
  final Map<String, String> _errors = {};

  // Speech-to-text
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isListening = false;
  TextEditingController? _currentListeningController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Listening animation controller
    _listeningAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _listeningPulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _listeningAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.currentPatient != null) {
      _selectedPatient = widget.currentPatient;
      _currentStep = PrescriptionStep.medical;
    }

    // Initialize with one medication
    _addMedication();

    // Initialize speech-to-text service with context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _speechService.initialize(context);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _listeningAnimationController.dispose();
    _scrollController.dispose();
    _patientSearchController.dispose();
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    _followUpDateController.dispose();
    _templateSearchController.dispose();
    for (var controller in _medicationSearchControllers) {
      controller.dispose();
    }
    _speechService.dispose();
    super.dispose();
  }

  void _addMedication() {
    setState(() {
      _medications.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'medication_code': '',
        'medication_name': '',
        'dosage': '',
        'frequency': '',
        'duration': '',
        'refills': 1,
        'notes': '',
      });
      _medicationSearchControllers.add(TextEditingController());
      _foundMedications.add([]);
      _isSearchingMedications.add(false);
    });
  }

  void _removeMedication(int index) {
    if (_medications.length <= 1) {
      _showErrorSnackBar('At least one medication is required');
      return;
    }
    setState(() {
      _medicationSearchControllers[index].dispose();
      _medicationSearchControllers.removeAt(index);
      _medications.removeAt(index);
      _foundMedications.removeAt(index);
      _isSearchingMedications.removeAt(index);
    });
  }

  String? _calculateTimeDifference(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final followUp = DateTime.parse(dateString);
      final today = DateTime.now();
      if (followUp.isBefore(today)) return 'Past date';

      final diff = followUp.difference(today).inDays;
      if (diff == 0) return 'Today';
      if (diff < 30) return '$diff day${diff > 1 ? 's' : ''}';

      final months =
          (followUp.year - today.year) * 12 + (followUp.month - today.month);
      final days = followUp.day - today.day;

      if (months == 0) return '$days day${days > 1 ? 's' : ''}';
      if (days == 0) return '$months month${months > 1 ? 's' : ''}';
      return '$months month${months > 1 ? 's' : ''} and $days day${days > 1 ? 's' : ''}';
    } catch (e) {
      return null;
    }
  }

  Future<void> _searchPatients() async {
    if (_patientSearchController.text.trim().length < 3) {
      setState(() {
        _foundPatients = [];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearchingPatients = true;
    });

    final result = await ref.read(
      searchPrescriptionPatientsProvider(_patientSearchController.text.trim())
          .future,
    );

    if (!mounted) return;
    setState(() {
      _isSearchingPatients = false;
    });

    result.when(
      success: (patients) {
        if (mounted) {
          setState(() {
            _foundPatients = patients;
          });
        }
      },
      failure: (message) {
        if (mounted) {
          _showErrorSnackBar(message);
        }
      },
    );
  }

  Future<void> _searchMedications(int index) async {
    final searchTerm = _medicationSearchControllers[index].text.trim();
    if (searchTerm.length < 3) {
      setState(() {
        _foundMedications[index] = [];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearchingMedications[index] = true;
    });

    final result = await ref.read(searchMedicationsProvider(searchTerm).future);

    if (!mounted) return;
    setState(() {
      _isSearchingMedications[index] = false;
    });

    result.when(
      success: (medications) {
        if (mounted) {
          setState(() {
            _foundMedications[index] = medications;
          });
        }
      },
      failure: (message) {
        if (mounted) {
          _showErrorSnackBar(message);
        }
      },
    );
  }

  void _selectMedication(String code, int index) {
    final medication =
        _foundMedications[index].firstWhere((m) => m.code == code);
    setState(() {
      _medications[index] = {
        ..._medications[index],
        'medication_code': code,
        'medication_name': medication.nom ?? '',
        'dosage': medication.dosage1 != null && medication.uniteDosage1 != null
            ? '${medication.dosage1} ${medication.uniteDosage1}'
            : _medications[index]['dosage'],
        'notes': medication.forme ?? _medications[index]['notes'],
      };
      _medicationSearchControllers[index].text = medication.nom ?? '';
    });
  }

  Future<void> _searchTemplates() async {
    if (_templateSearchController.text.trim().length < 3) {
      setState(() {
        _foundTemplates = [];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearchingTemplates = true;
    });

    final result = await ref.read(
      searchPrescriptionTemplatesProvider(_templateSearchController.text.trim())
          .future,
    );

    if (!mounted) return;
    setState(() {
      _isSearchingTemplates = false;
    });

    result.when(
      success: (templates) {
        if (mounted) {
          setState(() {
            _foundTemplates = templates;
          });
        }
      },
      failure: (message) {
        if (mounted) {
          _showErrorSnackBar('Error searching: $message');
        }
      },
    );
  }

  void _selectTemplate(PrescriptionTemplateModel template) {
    if (template.items == null || template.items!.isEmpty) {
      _showErrorSnackBar('Template does not contain any valid medications');
      return;
    }

    setState(() {
      _selectedTemplate = template;
      _medications.clear();
      for (var controller in _medicationSearchControllers) {
        controller.dispose();
      }
      _medicationSearchControllers.clear();
      _foundMedications.clear();
      _isSearchingMedications.clear();

      for (var item in template.items!) {
        _medications.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'medication_code': item.medicationCode ?? '',
          'medication_name': item.medicationName ?? '',
          'dosage': item.dosage ?? '',
          'frequency': item.frequency ?? '',
          'duration': item.duration ?? '',
          'refills': item.refills ?? 1,
          'notes': item.notes ?? '',
        });
        _medicationSearchControllers
            .add(TextEditingController(text: item.medicationName ?? ''));
        _foundMedications.add([]);
        _isSearchingMedications.add(false);
      }

      if (_selectedMedicalRecord == null) {
        _diagnosisController.text =
            template.defaultDiagnosis ?? _diagnosisController.text;
        _notesController.text = template.defaultNotes ?? _notesController.text;
      }

      _templateSearchController.clear();
      _foundTemplates = [];
    });

    _showSuccessSnackBar(
        'Template "${template.templateName}" applied successfully');
  }

  Future<void> _createPrescription() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields');
      return;
    }

    if (_selectedPatient == null) {
      _showErrorSnackBar('Please select a patient');
      return;
    }

    final validMedications = _medications
        .where((m) =>
            m['medication_code'] != null &&
            m['medication_code'].toString().isNotEmpty)
        .toList();
    if (validMedications.isEmpty) {
      _showErrorSnackBar('Please add at least one valid medication');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    final payload = <String, dynamic>{
      'patient_id': _selectedPatient!.id,
      'medications': validMedications
          .map((med) => {
                'medication_code': med['medication_code'],
                'dosage': med['dosage']?.toString().isEmpty == true
                    ? null
                    : med['dosage'],
                'frequency': med['frequency']?.toString().isEmpty == true
                    ? null
                    : med['frequency'],
                'duration': med['duration']?.toString().isEmpty == true
                    ? null
                    : med['duration'],
                'refills': med['refills'] ?? 1,
                'notes': med['notes']?.toString().isEmpty == true
                    ? null
                    : med['notes'],
              })
          .toList(),
      'send_whatsapp': _sendWhatsapp,
      'send_email': _sendEmail,
    };

    if (_selectedMedicalRecord != null) {
      payload['medical_record_id'] = _selectedMedicalRecord['id'].toString();
      payload['follow_up_date'] = _followUpDateController.text.trim().isEmpty
          ? null
          : _followUpDateController.text.trim();
      payload['notes'] = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
    } else {
      payload['symptoms'] = _symptomsController.text.trim().isEmpty
          ? null
          : _symptomsController.text.trim();
      payload['diagnosis'] = _diagnosisController.text.trim().isEmpty
          ? null
          : _diagnosisController.text.trim();
      payload['treatment'] = _treatmentController.text.trim().isEmpty
          ? null
          : _treatmentController.text.trim();
      payload['follow_up_date'] = _followUpDateController.text.trim().isEmpty
          ? null
          : _followUpDateController.text.trim();
      payload['notes'] = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
    }

    final result = await ref.read(createPrescriptionProvider(payload).future);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    result.when(
      success: (prescription) {
        if (mounted) {
          _showSuccessDialog(prescription);
        }
      },
      failure: (message) {
        if (mounted) {
          _showErrorDialog(message);
        }
      },
    );
  }

  void _showSuccessDialog(PrescriptionModel prescription) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return const Text(
                    'Prescription Created!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.person_rounded, 'Patient',
                        prescription.patient?.user?.name ?? "N/A"),
                    if (prescription.id != null)
                      _buildInfoRow(Icons.numbers_rounded, 'ID',
                          prescription.id.toString()),
                    if (prescription.followUpDate != null)
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          final locale = ref.read(localeProvider).locale;
                          return _buildInfoRow(
                            Icons.calendar_today_rounded,
                            'Follow-up Date',
                            '${DateFormat('dd/MM/yyyy', locale.toString()).format(DateTime.parse(prescription.followUpDate!))} (${_calculateTimeDifference(prescription.followUpDate) ?? ''})',
                          );
                        },
                      ),
                    if (prescription.medications != null &&
                        prescription.medications!.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildInfoRow(
                            Icons.medication_rounded,
                            'Medications',
                            prescription.medications!
                                .map((m) => m.medicationName ?? '')
                                .join(', '),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Text('Close');
                        },
                      ),
                    ),
                  ),
                  if (prescription.pdfPath != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _downloadPrescriptionPdf(
                            prescription.pdfPath!, prescription.id),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return const Text('Download PDF');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_rounded,
                    color: Colors.red, size: 50),
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return const Text(
                    'Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text('New Prescription',
                style: TextStyle(fontWeight: FontWeight.w600));
          },
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressSteps(),
                    const SizedBox(height: 32),
                    if (_currentStep == PrescriptionStep.patient)
                      _buildPatientStep(),
                    if (_currentStep == PrescriptionStep.medical)
                      _buildMedicalStep(),
                    if (_currentStep == PrescriptionStep.medications)
                      _buildMedicationsStep(),
                  ],
                ),
              ),
            ),
          ),
          // Listening indicator overlay
          if (_isListening) _buildListeningIndicator(),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = [
      {'icon': Icons.person_rounded, 'title': 'Patient'},
      {'icon': Icons.medical_services_rounded, 'title': 'Diagnosis'},
      {'icon': Icons.medication_rounded, 'title': 'Medications'},
    ];

    final currentIndex = _currentStep == PrescriptionStep.patient
        ? 0
        : _currentStep == PrescriptionStep.medical
            ? 1
            : 2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF18181B)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == currentIndex;
          final isCompleted = index < currentIndex;
          final step = steps[index];

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green
                              : isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300],
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : step['icon'] as IconData,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : isCompleted
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: index < currentIndex
                              ? [Colors.green, Colors.green]
                              : [Colors.grey[300]!, Colors.grey[300]!],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPatientStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Patient Selection',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Search for a patient',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _patientSearchController,
            decoration: InputDecoration(
              labelText: 'Search for a patient',
              hintText: 'Type at least 3 letters',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _isSearchingPatients
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _searchPatients(),
          ),
          const SizedBox(height: 16),
          if (_foundPatients.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      'Patients Found (${_foundPatients.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ..._foundPatients.map((patient) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPatient?.id == patient.id
                              ? Theme.of(context).colorScheme.primary
                              : isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.2),
                          width: _selectedPatient?.id == patient.id ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          child: Text(
                            (patient.user?.name ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          patient.user?.name ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(patient.user?.email ?? ''),
                            if (patient.phone != null ||
                                patient.phoneNumber != null)
                              Text(patient.phone ?? patient.phoneNumber ?? ''),
                            if (patient.birthdate != null)
                              Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Text(
                                      '${patient.calculateAge()} years');
                                },
                              ),
                          ],
                        ),
                        trailing: _selectedPatient?.id == patient.id
                            ? const Icon(Icons.check_circle_rounded,
                                color: Colors.green)
                            : const Icon(Icons.arrow_forward_ios_rounded,
                                size: 18),
                        onTap: () {
                          setState(() {
                            _selectedPatient = patient;
                            _selectedMedicalRecord = null;
                          });
                        },
                      ),
                    )),
              ],
            ),
          if (_patientSearchController.text.length >= 3 &&
              _foundPatients.isEmpty &&
              !_isSearchingPatients)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return const Text(
                          'No patients found',
                          style: TextStyle(color: Colors.orange),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedPatient != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.1),
                    Colors.green.withOpacity(0.05)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return const Text(
                              'Patient Selected',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600),
                            );
                          },
                        ),
                        Text(
                          _selectedPatient!.user?.name ?? "N/A",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _selectedPatient!.user?.email ?? '',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedPatient!.medicalRecords != null &&
                (_selectedPatient!.medicalRecords as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return const Text(
                    'Existing Medical Records',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  );
                },
              ),
              const SizedBox(height: 8),
              ...(_selectedPatient!.medicalRecords as List).map((record) {
                final recordData = record as Map<String, dynamic>;
                final isSelected =
                    _selectedMedicalRecord?['id'] == recordData['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.description_rounded),
                    title: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        final locale = ref.read(localeProvider).locale;
                        return Text(
                          'Record from ${DateFormat('dd/MM/yyyy', locale.toString()).format(DateTime.parse(recordData['created_at']))}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recordData['diagnosis'] != null)
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Text(
                                  'Diagnosis: ${recordData['diagnosis']}');
                            },
                          ),
                        if (recordData['treatment'] != null)
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Text(
                                  'Treatment: ${recordData['treatment']}');
                            },
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMedicalRecord = recordData;
                        if (recordData['notes'] != null) {
                          _notesController.text = recordData['notes'];
                        }
                      });
                    },
                  ),
                );
              }),
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.add_circle_rounded, color: Colors.green),
                  title: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.createNewMedicalRecord ??
                            'Create New Medical Record',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  subtitle: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.startWithEmptyForm ??
                          'Start with empty form');
                    },
                  ),
                  trailing: _selectedMedicalRecord == null
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedMedicalRecord = null;
                      _notesController.clear();
                    });
                  },
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedPatient == null
                  ? null
                  : () {
                      setState(() {
                        _currentStep = PrescriptionStep.medical;
                      });
                      _animationController.forward(from: 0.0);
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text('Continue',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600));
                    },
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.medical_services_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations Médicales',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remplissez les informations médicales du patient',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_selectedMedicalRecord != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_rounded, color: Colors.blue),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Text(
                            'Medical Record Selected',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedMedicalRecord['diagnosis'] != null)
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                            'Diagnosis: ${_selectedMedicalRecord['diagnosis']}');
                      },
                    ),
                  if (_selectedMedicalRecord['treatment'] != null)
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                            'Treatment: ${_selectedMedicalRecord['treatment']}');
                      },
                    ),
                ],
              ),
            ),
          if (_selectedMedicalRecord == null) ...[
            // AI Medical Scribe (Pr. Prodoc) - SOAP extraction
            AiScribeSoapWidget(
              aiChatService: ref.read(aiChatServiceProvider),
              onSoapGenerated: (soap) {
                setState(() {
                  final s = soap['symptoms']?.toString();
                  final d = soap['diagnosis']?.toString();
                  final t = soap['treatment']?.toString();
                  final n = soap['notes']?.toString();
                  if (s != null && s.isNotEmpty) _symptomsController.text = s;
                  if (d != null && d.isNotEmpty) _diagnosisController.text = d;
                  if (t != null && t.isNotEmpty) _treatmentController.text = t;
                  if (n != null && n.isNotEmpty) _notesController.text = n;
                });
              },
            ),
            const SizedBox(height: 24),
            // Symptoms Section
            _buildFieldSection(
              title: 'Symptômes',
              icon: Icons.sick_rounded,
              color: Colors.orange,
              fieldName: 'symptoms',
              child: _buildTextField(
                controller: _symptomsController,
                label: 'Décrivez les symptômes du patient',
                icon: Icons.sick_rounded,
                maxLines: 4,
                enableVoiceInput: true,
              ),
            ),
            const SizedBox(height: 24),
            // Diagnosis Section
            _buildFieldSection(
              title: 'Diagnostic',
              icon: Icons.assignment_rounded,
              color: Colors.blue,
              fieldName: 'diagnosis',
              child: _buildTextField(
                controller: _diagnosisController,
                label: 'Entrez le diagnostic',
                icon: Icons.assignment_rounded,
                maxLines: 4,
                enableVoiceInput: true,
              ),
            ),
            const SizedBox(height: 24),
            // Treatment Section
            _buildFieldSection(
              title: 'Traitement',
              icon: Icons.medical_services_rounded,
              color: Colors.green,
              fieldName: 'treatment',
              child: _buildTextField(
                controller: _treatmentController,
                label: 'Décrivez le traitement prescrit',
                icon: Icons.medical_services_rounded,
                maxLines: 4,
                enableVoiceInput: true,
              ),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _followUpDateController,
            label: 'Follow-up Date (Check-up)',
            icon: Icons.calendar_today_rounded,
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                final locale = ref.read(localeProvider).locale;
                _followUpDateController.text =
                    DateFormat('yyyy-MM-dd', locale.toString()).format(date);
                setState(() {});
              }
            },
          ),
          if (_followUpDateController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'In ${_calculateTimeDifference(_followUpDateController.text) ?? ''}',
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _notesController,
            label: 'Additional Notes',
            icon: Icons.note_rounded,
            maxLines: 3,
            enableVoiceInput: true,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = PrescriptionStep.patient;
                    });
                    _animationController.forward(from: 0.0);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return const Text('Back');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = PrescriptionStep.medications;
                    });
                    _animationController.forward(from: 0.0);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text('Continue',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600));
                        },
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return const Text(
                      'Prescribed Medications',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addMedication,
                icon: const Icon(Icons.add_rounded),
                label: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return const Text('Add');
                  },
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Template Search
          TextFormField(
            controller: _templateSearchController,
            decoration: InputDecoration(
              labelText: 'Search prescription template',
              hintText: 'Type at least 3 letters',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _isSearchingTemplates
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _searchTemplates(),
          ),
          if (_foundTemplates.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._foundTemplates.map((template) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.description_rounded),
                    title: Text(template.templateName ?? ''),
                    subtitle: template.description != null
                        ? Text(template.description!)
                        : null,
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onTap: () => _selectTemplate(template),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          // Medications List
          ...List.generate(_medications.length, (index) {
            return _buildMedicationCard(index);
          }),
          const SizedBox(height: 24),
          // Notifications
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildSectionHeader(
                  'Notifications', Icons.notifications_rounded);
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildModernCheckbox(
                    value: _sendWhatsapp,
                    title: 'Send via WhatsApp',
                    icon: Icons.phone_android_rounded,
                    onChanged: (value) {
                      setState(() {
                        _sendWhatsapp = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildModernCheckbox(
                    value: _sendEmail,
                    title: 'Send via Email',
                    icon: Icons.email_rounded,
                    onChanged: (value) {
                      setState(() {
                        _sendEmail = value ?? false;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _currentStep = PrescriptionStep.medical;
                          });
                          _animationController.forward(from: 0.0);
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return const Text('Back');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createPrescription,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text('Create Prescription',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600));
                              },
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final med = _medications[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ),
              const Spacer(),
              if (_medications.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  onPressed: () => _removeMedication(index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _medicationSearchControllers[index],
            decoration: InputDecoration(
              labelText: 'Search for a medication *',
              hintText: 'Type at least 3 letters',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _isSearchingMedications[index]
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _searchMedications(index),
          ),
          if (_foundMedications[index].isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: med['medication_code']?.toString().isEmpty == true
                  ? null
                  : med['medication_code']?.toString(),
              decoration: InputDecoration(
                labelText: 'Select a medication *',
                filled: true,
                fillColor:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _foundMedications[index].map((medication) {
                return DropdownMenuItem(
                  value: medication.code,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medication.nom ?? ''),
                      if (medication.dci1 != null || medication.dosage1 != null)
                        Text(
                          '${medication.dci1 ?? ''} • ${medication.dosage1 ?? ''} ${medication.uniteDosage1 ?? ''}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _selectMedication(value, index);
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Desktop/Tablet: Show in a row
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Dosage',
                          hintText: 'e.g: 200 mg',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _medications[index]['dosage'] = value;
                            });
                          }
                        },
                        controller: TextEditingController(
                            text: med['dosage']?.toString() ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          hintText: 'e.g: 3 times per day',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _medications[index]['frequency'] = value;
                            });
                          }
                        },
                        controller: TextEditingController(
                            text: med['frequency']?.toString() ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Duration',
                          hintText: 'e.g: 7 days',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _medications[index]['duration'] = value;
                            });
                          }
                        },
                        controller: TextEditingController(
                            text: med['duration']?.toString() ?? ''),
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile: Show in a column
                return Column(
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'ex: 200 mg',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _medications[index]['dosage'] = value;
                          });
                        }
                      },
                      controller: TextEditingController(
                          text: med['dosage']?.toString() ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Fréquence',
                        hintText: 'ex: 3 fois par jour',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _medications[index]['frequency'] = value;
                          });
                        }
                      },
                      controller: TextEditingController(
                          text: med['frequency']?.toString() ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Durée',
                        hintText: 'ex: 7 jours',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _medications[index]['duration'] = value;
                          });
                        }
                      },
                      controller: TextEditingController(
                          text: med['duration']?.toString() ?? ''),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Special Instructions',
              hintText: 'e.g: Take with meals',
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _medications[index]['notes'] = value;
              });
            },
            controller:
                TextEditingController(text: med['notes']?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    bool enableVoiceInput = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isListeningToThis =
        _isListening && _currentListeningController == controller;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines > 1 ? (maxLines > 5 ? maxLines : 5) : maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      onTap: onTap,
      textAlignVertical: TextAlignVertical.top,
      expands: false,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        prefixIcon: Icon(icon),
        suffixIcon: enableVoiceInput && !readOnly
            ? IconButton(
                icon: Icon(
                  isListeningToThis ? Icons.mic : Icons.mic_none,
                  color: isListeningToThis
                      ? Colors.red
                      : (isDark ? Colors.white70 : Colors.grey[600]),
                ),
                onPressed: () => _handleVoiceInput(controller),
                tooltip:
                    isListeningToThis ? 'Stop listening' : 'Start voice input',
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isListeningToThis
                  ? Colors.red.withOpacity(0.5)
                  : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2))),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildFieldSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    String? fieldName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  /// Handle voice input for a text field
  Future<void> _handleVoiceInput(TextEditingController controller) async {
    // If already listening for this controller, stop it
    if (_isListening && _currentListeningController == controller) {
      debugPrint('Stopping voice input for current controller');
      // Add vibration feedback when stopping
      _triggerVibration();
      _listeningAnimationController.stop();
      await _speechService.stopListening(onDone: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _currentListeningController = null;
          });
        }
      });
      // Wait a moment to ensure it's fully stopped
      await Future.delayed(const Duration(milliseconds: 200));
      return;
    }

    // IMPORTANT: Stop any existing listening from other controllers FIRST
    if (_isListening &&
        _currentListeningController != null &&
        _currentListeningController != controller) {
      debugPrint(
          'Stopping voice input from previous controller before starting new one');
      await _speechService.stopListening();
      // Wait a moment to ensure previous session is fully stopped and cleared
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isListening = false;
          _currentListeningController = null;
        });
      }
    }

    // Store the text that's currently in the field when we start
    // This is crucial to prevent mixing text from previous voice sessions
    final textAtStart = controller.text.trim();

    setState(() {
      _isListening = true;
      _currentListeningController = controller;
    });

    // Add vibration feedback when starting to listen
    _triggerVibration();

    // Start listening animation
    _listeningAnimationController.forward();

    try {
      await _speechService.startListening(
        context: context,
        onResult: (text, isFinal) {
          if (!mounted) return;

          setState(() {
            // The speech service accumulates text across sessions
            // We need to extract only the NEW text from this session
            final recognizedText = text.trim();

            // If field was empty when we started, use recognized text directly
            if (textAtStart.isEmpty) {
              controller.text = recognizedText;
            } else {
              // Field had existing text - check if recognized text contains it
              if (recognizedText.startsWith(textAtStart)) {
                // Extract only the new part (text after what we started with)
                final newText =
                    recognizedText.substring(textAtStart.length).trim();
                if (newText.isNotEmpty) {
                  // Append only the new text
                  controller.text = '$textAtStart $newText';
                }
              } else {
                // Recognized text doesn't start with our original text
                // This means it's from a new session - use it directly
                // This handles the case where speech service was cleared between sessions
                controller.text = recognizedText;
              }
            }
          });
        },
        onError: () {
          if (mounted) {
            _showErrorSnackBar(
                'Speech recognition error. Please check microphone permissions.');
          }
          // Add vibration feedback on error (stopping)
          _triggerVibration();
          _listeningAnimationController.stop();
          setState(() {
            _isListening = false;
            _currentListeningController = null;
          });
        },
        onListeningStateChanged: (isListening) {
          // Update UI state when listening state changes
          if (mounted) {
            setState(() {
              _isListening = isListening;
              if (!isListening) {
                _listeningAnimationController.stop();
                // Only clear controller if we're not switching to a new one
                if (_currentListeningController == controller ||
                    _currentListeningController == null) {
                  _currentListeningController = null;
                }
              } else {
                // When starting to listen, set the current controller
                _currentListeningController = controller;
                _listeningAnimationController.repeat(reverse: true);
              }
            });
          }
        },
        onDone: () {
          // onDone is called when user manually stops
          // Add vibration feedback when stopping
          _triggerVibration();
          _listeningAnimationController.stop();
          setState(() {
            _isListening = false;
            _currentListeningController = null;
          });
        },
      );
    } catch (e) {
      // Add vibration feedback on error (stopping)
      _triggerVibration();
      _listeningAnimationController.stop();
      setState(() {
        _isListening = false;
        _currentListeningController = null;
      });
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  /// Build listening indicator overlay
  Widget _buildListeningIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: GestureDetector(
          onTap: () async {
            // Stop recording when tapping the indicator
            if (_isListening && _currentListeningController != null) {
              // Add vibration feedback when stopping via tap
              _triggerVibration();
              _listeningAnimationController.stop();
              await _speechService.stopListening(onDone: () {
                if (mounted) {
                  setState(() {
                    _isListening = false;
                    _currentListeningController = null;
                  });
                }
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _listeningPulseAnimation,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'I am listening... (Tap to stop)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    bool enableVoiceInput = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isListeningToThis =
        _isListening && _currentListeningController == controller;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines > 1 ? (maxLines > 5 ? maxLines : 5) : maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      onTap: onTap,
      textAlignVertical: TextAlignVertical.top,
      expands: false,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        hintText: label,
        prefixIcon: Icon(icon),
        suffixIcon: enableVoiceInput && !readOnly
            ? IconButton(
                icon: Icon(
                  isListeningToThis ? Icons.mic : Icons.mic_none,
                  color: isListeningToThis
                      ? Colors.red
                      : (isDark ? Colors.white70 : Colors.grey[600]),
                ),
                onPressed: () => _handleVoiceInput(controller),
                tooltip:
                    isListeningToThis ? 'Stop listening' : 'Start voice input',
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isListeningToThis
                  ? Colors.red.withOpacity(0.5)
                  : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2))),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isListeningToThis
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              width: 2),
        ),
        contentPadding: const EdgeInsets.only(
          left: 12,
          top: 16,
          bottom: 16,
          right: 16,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildModernCheckbox({
    required bool value,
    required String title,
    IconData? icon,
    required void Function(bool?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(title),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Future<void> _downloadPrescriptionPdf(
      String pdfPath, int? prescriptionId) async {
    if (prescriptionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription ID not available')),
        );
      }
      return;
    }

    // Use API endpoint instead of storage URL
    final url = '${ApiConstants.baseUrl}${ApiConstants.prescriptionPdf(prescriptionId)}';

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      final uri = Uri.parse(url);

      // Get auth token if available
      final authState = ref.read(authProvider);
      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the file
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // Get file name from URL or use prescription ID
        String fileName =
            'ordonnance_${prescriptionId ?? DateTime.now().millisecondsSinceEpoch}.pdf';
        final urlPath = uri.path;
        if (urlPath.isNotEmpty) {
          final urlFileName = urlPath.split('/').last;
          if (urlFileName.isNotEmpty && urlFileName.endsWith('.pdf')) {
            fileName = urlFileName;
          }
        }

        if (kIsWeb) {
          // For web, trigger browser download
          final blob = response.bodyBytes;
          final blobUrl = Uri.dataFromBytes(blob, mimeType: 'application/pdf');
          await launchUrl(blobUrl, mode: LaunchMode.platformDefault);

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF downloaded: $fileName'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // For mobile, save to Downloads directory
          Directory? directory;
          try {
            if (Platform.isAndroid) {
              // For Android, use external storage downloads directory
              directory = Directory('/storage/emulated/0/Download');
              if (!await directory.exists()) {
                // Fallback to app documents directory
                directory = await getApplicationDocumentsDirectory();
              }
            } else if (Platform.isIOS) {
              // For iOS, use app documents directory
              directory = await getApplicationDocumentsDirectory();
            } else {
              // For other platforms
              directory = await getApplicationDocumentsDirectory();
            }
          } catch (e) {
            // Fallback to app documents directory
            directory = await getApplicationDocumentsDirectory();
          }

          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF downloaded: $fileName'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading: ${response.statusCode}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
