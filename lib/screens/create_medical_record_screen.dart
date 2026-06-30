// lib/screens/create_medical_record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/utils/result.dart';
import '../data/models/medical_record_model.dart';
import '../data/models/patient_model.dart';
import '../data/models/doctor_model.dart';
import '../data/models/appointment_model.dart';
import '../providers/medical_record_providers.dart';
import '../providers/patient_providers.dart';
import '../providers/doctor_providers.dart';
import '../providers/api_providers.dart' show aiChatServiceProvider, patientServiceProvider;
import '../providers/locale_providers.dart';
import '../widgets/loading_widget.dart';
import '../widgets/ai_scribe_soap_widget.dart';
import '../l10n/app_localizations.dart';
import '../services/speech_to_text_service.dart';
import '../services/patient_service.dart';
import 'specialties_screen.dart';
import 'specialty_fields_screen.dart';
import 'create_appointment_screen.dart';
import '../providers/specialty_providers.dart' show specialtyNotifierProvider;

enum MedicalRecordStep {
  patientDoctor,
  vitalSigns,
  medicalDetails,
  review,
}

class CreateMedicalRecordScreen extends ConsumerStatefulWidget {
  final int? recordId;
  final int? patientId;

  const CreateMedicalRecordScreen({
    super.key,
    this.recordId,
    this.patientId,
  });

  @override
  ConsumerState<CreateMedicalRecordScreen> createState() =>
      _CreateMedicalRecordScreenState();
}

class _CreateMedicalRecordScreenState
    extends ConsumerState<CreateMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  MedicalRecordStep _currentStep = MedicalRecordStep.patientDoctor;

  // Step 1: Patient & Doctor
  final _patientSearchController = TextEditingController();
  PatientModel? _selectedPatient;
  DoctorModel? _selectedDoctor;
  AppointmentModel? _selectedAppointment;
  int? _selectedSpecialtyId;
  Specialty? _selectedSpecialty;
  List<PatientModel> _foundPatients = [];
  bool _isSearchingPatients = false;
  bool _isLoadingSpecialtyFields = false;

  // Step 2: Vital Signs & Allergies
  final _bloodPressureController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _bmiController = TextEditingController();
  bool? _hasAllergies;
  final _allergyDetailsController = TextEditingController();
  Map<String, dynamic> _specialtyData = {};

  // Step 3: Medical Details
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();

  // Speech-to-text for medical detail fields
  final SpeechToTextService _speechService = SpeechToTextService();
  TextEditingController? _activeVoiceController;
  String _voiceBaseText = '';

  // Visibility
  String _visibility = 'private';

  bool _isSubmitting = false;
  bool _isLoadingRecord = false;
  bool _isCreateSpecialtyDialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _loadPatient(widget.patientId!);
    }
    if (widget.recordId != null) {
      _loadRecord(widget.recordId!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speechService.initialize(context);
    });
  }

  @override
  void dispose() {
    if (_activeVoiceController != null) {
      _speechService.stopListening();
    }
    _patientSearchController.dispose();
    _bloodPressureController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _temperatureController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _bmiController.dispose();
    _allergyDetailsController.dispose();
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPatient(int patientId) async {
    final patientAsync = ref.read(patientProvider(patientId));
    patientAsync.whenData((result) {
      if (result is Success<PatientModel>) {
        setState(() {
          _selectedPatient = result.data;
        });
      }
    });
  }

  Future<void> _loadRecord(int recordId) async {
    setState(() => _isLoadingRecord = true);
    final recordAsync = ref.read(medicalRecordProvider(recordId));
    recordAsync.whenData((result) {
      if (result is Success<MedicalRecordModel>) {
        final record = result.data;
        setState(() {
          _selectedPatient = record.patient;
          _selectedDoctor = record.doctor;
          _selectedAppointment = record.appointment;
          _selectedSpecialtyId = record.specialtyId;
          _selectedSpecialty = record.specialty;

          _bloodPressureController.text = record.bloodPressure ?? '';
          _weightController.text = record.weight?.toString() ?? '';
          _heightController.text = record.height?.toString() ?? '';
          _temperatureController.text = record.temperature?.toString() ?? '';
          _heartRateController.text = record.heartRate?.toString() ?? '';
          _respiratoryRateController.text =
              record.respiratoryRate?.toString() ?? '';
          _bmiController.text = record.bmi ?? '';
          _hasAllergies = record.hasAllergies;
          _allergyDetailsController.text = record.allergyDetails ?? '';
          _specialtyData = record.specialtyData ?? {};

          _symptomsController.text = record.symptoms ?? '';
          _diagnosisController.text = record.diagnosis ?? '';
          _treatmentController.text = record.treatment ?? '';
          _notesController.text = record.notes ?? '';
          _visibility = record.visibility ?? 'private';
        });
        if (_selectedSpecialtyId != null) {
          _loadSpecialtyFields(_selectedSpecialtyId!);
        }
      }
      setState(() => _isLoadingRecord = false);
    });
  }

  Future<void> _loadSpecialtyFields(int specialtyId) async {
    setState(() => _isLoadingSpecialtyFields = true);

    try {
      final result =
          await ref.read(specialtyFieldsProvider(specialtyId).future);

      if (mounted) {
        if (result is Success<Map<String, dynamic>>) {
          setState(() {
            _selectedSpecialty = Specialty.fromJson(result.data);
            _isLoadingSpecialtyFields = false;
            // Clear specialty data when changing specialty (unless editing existing record)
            if (widget.recordId == null) {
              _specialtyData = {};
            }
          });
        } else if (result is Failure<Map<String, dynamic>>) {
          setState(() => _isLoadingSpecialtyFields = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${result.message}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSpecialtyFields = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fields: $e')),
        );
      }
    }
  }

  Future<void> _showCreatePatientDialog() async {
    final doctorsResult = await ref.read(doctorsProvider.future);
    if (doctorsResult is! Success<List<DoctorModel>> ||
        doctorsResult.data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noDoctorAvailable)),
        );
      }
      return;
    }
    final firstDoctorId = doctorsResult.data.first.id!;
    final patientService = ref.read(patientServiceProvider);
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreatePatientDialogContent(
        initialName: _patientSearchController.text.trim(),
        patientService: patientService,
        doctorId: firstDoctorId,
        appointmentDate: dateStr,
        appointmentTime: '09:00',
        onCreated: (PatientModel patient, String createdName) {
          setState(() {
            _selectedPatient = patient;
            final displayName = patient.user?.name ?? createdName;
            _patientSearchController.text = displayName;
            _foundPatients = [];
          });
          Navigator.of(ctx).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      AppLocalizations.of(context)!.patientCreatedContinueRecord)),
            );
          }
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() {
        _foundPatients = [];
        _isSearchingPatients = false;
      });
      return;
    }

    setState(() => _isSearchingPatients = true);

    try {
      final result = await ref.read(findPatientsProvider(query).future);

      if (mounted) {
        if (result is Success<List<PatientModel>>) {
          setState(() {
            _foundPatients = result.data;
            _isSearchingPatients = false;
          });
        } else if (result is Failure<List<PatientModel>>) {
          setState(() {
            _foundPatients = [];
            _isSearchingPatients = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foundPatients = [];
          _isSearchingPatients = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  bool _validateStep(MedicalRecordStep step) {
    // Validate form fields first
    if (!(_formKey.currentState?.validate() ?? true)) {
      return false;
    }

    switch (step) {
      case MedicalRecordStep.patientDoctor:
        if (_selectedPatient == null ||
            _selectedDoctor == null ||
            _selectedSpecialtyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppLocalizations.of(context)!.pleaseSelectPatientDoctorSpecialty)),
          );
          return false;
        }
        return true;
      case MedicalRecordStep.vitalSigns:
        return true; // Optional fields
      case MedicalRecordStep.medicalDetails:
        // Symptoms, diagnosis, treatment are optional
        // Validate required specialty fields only
        if (_selectedSpecialty != null && _selectedSpecialty!.fields != null) {
          for (final field in _selectedSpecialty!.fields!) {
            if (field.required == true) {
              final fieldValue = _specialtyData[field.fieldName];
              if (fieldValue == null ||
                  (fieldValue is String && fieldValue.trim().isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(AppLocalizations.of(context)!.pleaseFillRequiredField(field.fieldLabel ?? '')),
                  ),
                );
                return false;
              }
            }
          }
        }
        return true;
      case MedicalRecordStep.review:
        return true;
    }
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      setState(() {
        switch (_currentStep) {
          case MedicalRecordStep.patientDoctor:
            _currentStep = MedicalRecordStep.vitalSigns;
            break;
          case MedicalRecordStep.vitalSigns:
            _currentStep = MedicalRecordStep.medicalDetails;
            break;
          case MedicalRecordStep.medicalDetails:
            _currentStep = MedicalRecordStep.review;
            break;
          case MedicalRecordStep.review:
            break;
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      switch (_currentStep) {
        case MedicalRecordStep.patientDoctor:
          break;
        case MedicalRecordStep.vitalSigns:
          _currentStep = MedicalRecordStep.patientDoctor;
          break;
        case MedicalRecordStep.medicalDetails:
          _currentStep = MedicalRecordStep.vitalSigns;
          break;
        case MedicalRecordStep.review:
          _currentStep = MedicalRecordStep.medicalDetails;
          break;
      }
    });
  }

  Future<void> _submit() async {
    if (!_validateStep(_currentStep)) return;

    setState(() => _isSubmitting = true);

    final recordData = <String, dynamic>{
      'patient_id': _selectedPatient!.id,
      'doctor_id': _selectedDoctor!.id,
      'specialty_id': _selectedSpecialtyId,
      if (_selectedAppointment != null)
        'appointment_id': _selectedAppointment!.id,
      'symptoms': _symptomsController.text.trim(),
      'diagnosis': _diagnosisController.text.trim(),
      'treatment': _treatmentController.text.trim(),
      // Always include notes (backend expects it)
      'notes': _notesController.text.trim(),
      // Always include vital signs fields (backend expects them)
      // Send empty string for text fields
      'blood_pressure': _bloodPressureController.text.trim(),
      'bmi': _bmiController.text.trim(),
      // Always send numeric values - backend expects these keys to always be present
      // Send 0/0.0 for empty fields to avoid "Undefined array key" errors
      'weight': _weightController.text.trim().isNotEmpty
          ? (double.tryParse(_weightController.text) ?? 0.0)
          : 0.0,
      'height': _heightController.text.trim().isNotEmpty
          ? (double.tryParse(_heightController.text) ?? 0.0)
          : 0.0,
      'temperature': _temperatureController.text.trim().isNotEmpty
          ? (double.tryParse(_temperatureController.text) ?? 0.0)
          : 0.0,
      'heart_rate': _heartRateController.text.trim().isNotEmpty
          ? (int.tryParse(_heartRateController.text) ?? 0)
          : 0,
      'respiratory_rate': _respiratoryRateController.text.trim().isNotEmpty
          ? (int.tryParse(_respiratoryRateController.text) ?? 0)
          : 0,
      // Always include has_allergies (backend expects it)
      'has_allergies': _hasAllergies ?? false,
      // Always include allergy_details (backend might expect it)
      'allergy_details': _allergyDetailsController.text.trim(),
      if (_selectedSpecialtyId != null) 'specialty_data': _specialtyData,
      'visibility': _visibility,
    };

    final service = ref.read(medicalRecordServiceProvider);
    Result result;

    if (widget.recordId != null) {
      result = await service.updateMedicalRecord(
        recordId: widget.recordId!,
        recordData: recordData,
      );
    } else {
      result = await service.createMedicalRecord(recordData);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result is Success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recordId != null
                ? AppLocalizations.of(context)!.medicalRecordUpdatedSuccess
                : AppLocalizations.of(context)!.medicalRecordCreatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (result is Failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRecord) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.loading,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: const LoadingWidget(),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AsyncValue<Result<String>>>(specialtyNotifierProvider,
        (previous, next) {
      next.whenData((result) {
        if (result is Success<String>) {
          ref.invalidate(medicalRecordSpecialtiesProvider);
          ref.read(specialtyNotifierProvider.notifier).reset();
          if (_isCreateSpecialtyDialogOpen && mounted) {
            _isCreateSpecialtyDialogOpen = false;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.data),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (result is Failure<String>) {
          ref.read(specialtyNotifierProvider.notifier).reset();
          if (_isCreateSpecialtyDialogOpen && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Builder(
          builder: (context) {
            return Text(
              widget.recordId != null
                  ? AppLocalizations.of(context)!.editMedicalRecord
                  : AppLocalizations.of(context)!.newMedicalRecord,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            );
          },
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ]
                : [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
          ),
        ),
        child: Column(
          children: [
            _buildModernStepIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            _buildModernNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStepIndicator() {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      {'title': l10n.patientAndDoctor, 'icon': Icons.person},
      {'title': l10n.vitalSigns, 'icon': Icons.favorite},
      {'title': l10n.medicalDetails, 'icon': Icons.medical_services},
      {'title': l10n.review, 'icon': Icons.check_circle},
    ];

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedColor = Colors.teal.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final stepIndex = _currentStep.index;
          final isActive = index == stepIndex;
          final isCompleted = index < stepIndex;
          final step = entry.value;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? completedColor
                              : isActive
                                  ? primaryColor
                                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? completedColor
                                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? primaryColor
                            : isCompleted
                                ? completedColor
                                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : isCompleted
                                ? [
                                    BoxShadow(
                                      color: completedColor.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : Icon(
                                step['icon'] as IconData,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                    if (isActive && !isCompleted)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step['title'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? primaryColor
                        : isCompleted
                            ? completedColor
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case MedicalRecordStep.patientDoctor:
        return _buildPatientDoctorStep();
      case MedicalRecordStep.vitalSigns:
        return _buildVitalSignsStep();
      case MedicalRecordStep.medicalDetails:
        return _buildMedicalDetailsStep();
      case MedicalRecordStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildPatientDoctorStep() {
    final doctorsAsync = ref.watch(doctorsProvider);
    final specialtiesAsync = ref.watch(medicalRecordSpecialtiesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return Text(
              AppLocalizations.of(context)!.selectPatientDoctorAndSpecialty,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 24),
        // Patient Selection
        TextFormField(
          controller: _patientSearchController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.patient,
            hintText: AppLocalizations.of(context)!.searchForPatient,
            prefixIcon: const Icon(Icons.person),
            suffixIcon: _selectedPatient != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedPatient = null),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _searchPatients,
          readOnly: widget.patientId != null,
        ),
        if (_isSearchingPatients)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        if (_foundPatients.isNotEmpty && _selectedPatient == null)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _foundPatients.length,
              itemBuilder: (context, index) {
                final patient = _foundPatients[index];
                return ListTile(
                  title: Text(patient.user?.name ?? 'Patient #${patient.id}'),
                  subtitle: Text(patient.user?.email ?? ''),
                  onTap: () {
                    setState(() {
                      _selectedPatient = patient;
                      _patientSearchController.text = patient.user?.name ?? '';
                      _foundPatients = [];
                    });
                  },
                );
              },
            ),
          ),
        if (!_isSearchingPatients &&
            _patientSearchController.text.length >= 2 &&
            _foundPatients.isEmpty &&
            _selectedPatient == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.noPatientFound,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.createPatientHint,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showCreatePatientDialog(),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: Text(AppLocalizations.of(context)!.createPatientButton),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateAppointmentScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(AppLocalizations.of(context)!.createAppointment),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_selectedPatient != null) ...[
          const SizedBox(height: 8),
          Chip(
            label: Text(
              _selectedPatient!.user?.name?.trim().isNotEmpty == true
                  ? _selectedPatient!.user!.name!
                  : _patientSearchController.text.trim().isNotEmpty
                      ? _patientSearchController.text.trim()
                      : (_selectedPatient!.id != null
                          ? '${AppLocalizations.of(context)!.patient} #${_selectedPatient!.id}'
                          : AppLocalizations.of(context)!.patient),
            ),
            onDeleted: () => setState(() => _selectedPatient = null),
          ),
        ],
        const SizedBox(height: 16),
        // Doctor Selection
        doctorsAsync.when(
          data: (doctors) {
            if (doctors is Success<List<DoctorModel>>) {
              // Find the matching doctor from the list if we have a selected doctor
              // This ensures the dropdown can find the matching item by object reference
              DoctorModel? matchingDoctor;
              if (_selectedDoctor != null && _selectedDoctor!.id != null) {
                try {
                  matchingDoctor = doctors.data.firstWhere(
                    (doctor) => doctor.id == _selectedDoctor!.id,
                  );
                } catch (e) {
                  // Doctor not found in list, set to null
                  // The dropdown will show no selection, user can select again
                  matchingDoctor = null;
                }
              }

              return DropdownButtonFormField<DoctorModel>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.doctor,
                  prefixIcon: const Icon(Icons.medical_services),
                  border: const OutlineInputBorder(),
                ),
                value: matchingDoctor,
                items: doctors.data.map((doctor) {
                  return DropdownMenuItem(
                    value: doctor,
                    child: Text(doctor.user?.name ?? 'Doctor #${doctor.id}'),
                  );
                }).toList(),
                onChanged: (doctor) => setState(() => _selectedDoctor = doctor),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => Text(AppLocalizations.of(context)!.errorLoadingDoctors),
        ),
        const SizedBox(height: 24),
        // Specialty Selection - Grid Layout
        // Title with inline link: "Select a Specialty · Manage"
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              AppLocalizations.of(context)!.selectASpecialty,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
            Text(
              '·',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SpecialtiesScreen(),
                  ),
                );
              },
              child: Text(
                AppLocalizations.of(context)!.manageSpecialties,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (_selectedSpecialty != null && _selectedSpecialtyId != null) ...[
              Text(
                '·',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SpecialtyFieldsScreen(
                        specialtyId: _selectedSpecialtyId!,
                        specialtyName: _selectedSpecialty!.name ?? 'Specialty',
                      ),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.editSpecialtyFields(_selectedSpecialty!.name ?? AppLocalizations.of(context)!.specialty),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.secondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        specialtiesAsync.when(
          data: (result) {
            if (result is Success<List<dynamic>>) {
              return _buildSpecialtyGrid(result.data);
            }
            return const SizedBox.shrink();
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppLocalizations.of(context)!.errorLoadingSpecialties,
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ),
        if (_isLoadingSpecialtyFields && _selectedSpecialtyId != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.loadingSpecialtyFields),
              ],
            ),
          ),
        ],
        // Bottom: Can't find your specialty? Create one or go to specialties screen
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.cantFindSpecialty,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showCreateSpecialtyDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context)!.createOne),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SpecialtiesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: Text(AppLocalizations.of(context)!.goToSpecialtiesScreen),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateSpecialtyDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    _isCreateSpecialtyDialogOpen = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.createSpecialtyTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.nameRequiredLabel,
                  hintText: 'e.g., Cardiology',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.descriptionLabel,
                  hintText: AppLocalizations.of(context)!.specialtyDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isCreateSpecialtyDialogOpen = false;
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.nameIsRequired)),
                );
                return;
              }
              ref.read(specialtyNotifierProvider.notifier).createSpecialty(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );
            },
            child: Text(AppLocalizations.of(context)!.createButton),
          ),
        ],
      ),
    ).then((_) {
      _isCreateSpecialtyDialogOpen = false;
    });
  }

  Widget _buildSpecialtyGrid(List<dynamic> specialties) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Map specialty names to medical icons
    IconData getSpecialtyIcon(String name) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('cardio') || lowerName.contains('heart')) {
        return Icons.favorite;
      } else if (lowerName.contains('neuro')) {
        return Icons.psychology;
      } else if (lowerName.contains('ortho') || lowerName.contains('bone')) {
        return Icons.healing;
      } else if (lowerName.contains('derm') || lowerName.contains('skin')) {
        return Icons.face;
      } else if (lowerName.contains('pediat') || lowerName.contains('child')) {
        return Icons.child_care;
      } else if (lowerName.contains('gyneco') || lowerName.contains('women')) {
        return Icons.pregnant_woman;
      } else if (lowerName.contains('ophtalmo') || lowerName.contains('eye')) {
        return Icons.remove_red_eye;
      } else if (lowerName.contains('dent') || lowerName.contains('tooth')) {
        return Icons.medical_information;
      } else if (lowerName.contains('kinesi') || lowerName.contains('physio')) {
        return Icons.fitness_center;
      } else if (lowerName.contains('psych') || lowerName.contains('mental')) {
        return Icons.psychology;
      } else if (lowerName.contains('general') ||
          lowerName.contains('family')) {
        return Icons.local_hospital;
      } else {
        return Icons.medical_services;
      }
    }

    // Get color for specialty
    Color getSpecialtyColor(String name, int index) {
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.red,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
        Colors.cyan,
        Colors.amber,
      ];
      return colors[index % colors.length];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: specialties.length,
      itemBuilder: (context, index) {
        final specialty = specialties[index];
        final id = specialty['id'] as int;
        final name = specialty['name'] as String;
        final isSelected = _selectedSpecialtyId == id;
        final icon = getSpecialtyIcon(name);
        final color = getSpecialtyColor(name, index);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedSpecialtyId = id;
                _selectedSpecialty = null;
                _specialtyData = {};
              });
              _loadSpecialtyFields(id);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : isDark
                        ? Colors.grey.shade800
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? color
                      : isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? color : color.withOpacity(0.7),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? color
                            : isDark
                                ? Colors.white
                                : Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle,
                        color: color,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shared input decoration for medical record form (vital signs, allergies, specialty fields).
  /// [prefixIconColor] when set gives the prefix icon a semantic color (e.g. red for heart).
  InputDecoration _medicalInputDecoration({
    String? labelText,
    String? hintText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? prefixIconColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final iconColor = prefixIconColor ??
        (isDark ? Colors.white54 : Colors.grey.shade600);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? Colors.white24 : Colors.grey.shade300,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primary, width: 1.5),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon != null
          ? IconTheme.merge(
              data: IconThemeData(color: iconColor, size: 22),
              child: prefixIcon,
            )
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.shade50,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      labelStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white70 : Colors.grey.shade700,
        fontSize: 14,
      ),
      hintStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white38 : Colors.grey.shade500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildVitalSignsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with accent
        Container(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primary.withValues(alpha: 0.8),
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.vitalSignsAndHistory,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context)!.enterPatientVitalSigns,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bloodPressureController,
                decoration: _medicalInputDecoration(
                  labelText: AppLocalizations.of(context)!.bloodPressure,
                  hintText: AppLocalizations.of(context)!.bloodPressureHint,
                  prefixIcon: const Icon(Icons.favorite, size: 22),
                  prefixIconColor: Colors.red.shade600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: _medicalInputDecoration(
                  labelText: AppLocalizations.of(context)!.weightKg,
                  prefixIcon: const Icon(Icons.monitor_weight, size: 22),
                  prefixIconColor: Colors.brown.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: _medicalInputDecoration(
                  labelText: AppLocalizations.of(context)!.heightCm,
                  prefixIcon: const Icon(Icons.height, size: 22),
                  prefixIconColor: Colors.teal.shade600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _temperatureController,
                keyboardType: TextInputType.number,
                decoration: _medicalInputDecoration(
                  labelText: AppLocalizations.of(context)!.temperatureC,
                  prefixIcon: const Icon(Icons.thermostat, size: 22),
                  prefixIconColor: Colors.orange.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _heartRateController,
                keyboardType: TextInputType.number,
                decoration: _medicalInputDecoration(
                  labelText: AppLocalizations.of(context)!.heartRateBpm,
                  prefixIcon: const Icon(Icons.favorite_border, size: 22),
                  prefixIconColor: Colors.red.shade500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _respiratoryRateController,
                keyboardType: TextInputType.number,
                decoration: _medicalInputDecoration(
                  labelText: AppLocalizations.of(context)!.respiratoryRatePerMin,
                  prefixIcon: const Icon(Icons.air, size: 22),
                  prefixIconColor: Colors.cyan.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bmiController,
          keyboardType: TextInputType.number,
          decoration: _medicalInputDecoration(
            labelText: AppLocalizations.of(context)!.bmiLabel,
            prefixIcon: const Icon(Icons.calculate, size: 22),
            prefixIconColor: Colors.indigo.shade600,
          ),
        ),
        const SizedBox(height: 28),
        // Allergies section
        Container(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primary.withValues(alpha: 0.6),
                width: 4,
              ),
            ),
          ),
          child: Text(
            AppLocalizations.of(context)!.allergies,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          decoration: _medicalInputDecoration(
            labelText: AppLocalizations.of(context)!.doesPatientHaveAllergies,
          ),
          value: _hasAllergies,
          items: [
            DropdownMenuItem(value: true, child: Text(AppLocalizations.of(context)!.yes)),
            DropdownMenuItem(value: false, child: Text(AppLocalizations.of(context)!.no)),
          ],
          onChanged: (value) => setState(() => _hasAllergies = value),
        ),
        if (_hasAllergies == true) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _allergyDetailsController,
            decoration: _medicalInputDecoration(
              labelText: AppLocalizations.of(context)!.allergyDetails,
              hintText: AppLocalizations.of(context)!.describeKnownAllergies,
            ),
            maxLines: 3,
          ),
        ],
        if (_isLoadingSpecialtyFields && _selectedSpecialtyId != null) ...[
          const SizedBox(height: 24),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.loadingSpecialtyFields),
                ],
              ),
            ),
          ),
        ] else if (_selectedSpecialty != null &&
            _selectedSpecialty!.fields != null &&
            _selectedSpecialty!.fields!.isNotEmpty) ...[
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  width: 4,
                ),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.specialtySpecificFields,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...[
            ...List<SpecialtyField>.from(_selectedSpecialty!.fields!)
              ..sort((a, b) => (a.fieldOrder ?? 0).compareTo(b.fieldOrder ?? 0))
          ].map((field) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSpecialtyField(field),
            );
          }),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SpecialtyFieldsScreen(
                    specialtyId: _selectedSpecialtyId!,
                    specialtyName: _selectedSpecialty!.name ?? 'Specialty',
                  ),
                ),
              );
              if (!mounted) return;
              await _loadSpecialtyFields(_selectedSpecialtyId!);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(
              AppLocalizations.of(context)!.addNewFieldFor(_selectedSpecialty!.name ?? AppLocalizations.of(context)!.specialty),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpecialtyField(SpecialtyField field) {
    final currentValue = _specialtyData[field.fieldName];
    final isRequired = field.required == true;
    final labelText = isRequired ? '${field.fieldLabel} *' : field.fieldLabel;

    switch (field.fieldType) {
      case 'textarea':
        return TextFormField(
          initialValue: currentValue?.toString(),
          decoration: _medicalInputDecoration(
            labelText: labelText,
            helperText: isRequired ? AppLocalizations.of(context)!.requiredField : null,
          ),
          maxLines: 4,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppLocalizations.of(context)!.thisFieldRequired;
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            setState(() {
              if (value.isNotEmpty) {
                _specialtyData[field.fieldName!] = value;
              } else {
                _specialtyData.remove(field.fieldName!);
              }
            });
          },
        );
      case 'select':
        final options = field.options ?? [];
        if (options.isEmpty) {
          // If no options, show as text field
          return TextFormField(
            initialValue: currentValue?.toString(),
            decoration: _medicalInputDecoration(
              labelText: labelText,
              helperText: isRequired ? AppLocalizations.of(context)!.requiredField : null,
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context)!.thisFieldRequired;
                    }
                    return null;
                  }
                : null,
            onChanged: (value) {
              setState(() {
                if (value.isNotEmpty) {
                  _specialtyData[field.fieldName!] = value;
                } else {
                  _specialtyData.remove(field.fieldName!);
                }
              });
            },
          );
        }
        return DropdownButtonFormField<String>(
          decoration: _medicalInputDecoration(
            labelText: labelText,
            helperText: isRequired ? AppLocalizations.of(context)!.requiredField : null,
          ),
          value: currentValue?.toString(),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.thisFieldRequired;
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            setState(() {
              if (value != null) {
                _specialtyData[field.fieldName!] = value;
              } else {
                _specialtyData.remove(field.fieldName!);
              }
            });
          },
        );
      case 'checkbox':
        return CheckboxListTile(
          title: Text(
              isRequired ? '${field.fieldLabel} *' : (field.fieldLabel ?? '')),
          value: currentValue == true,
          onChanged: (value) {
            setState(() {
              _specialtyData[field.fieldName!] = value ?? false;
            });
          },
        );
      case 'date':
        return TextFormField(
          initialValue: currentValue?.toString(),
          decoration: _medicalInputDecoration(
            labelText: labelText,
            helperText: isRequired ? AppLocalizations.of(context)!.requiredField : null,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          readOnly: true,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppLocalizations.of(context)!.thisFieldRequired;
                  }
                  return null;
                }
              : null,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: currentValue != null
                  ? DateTime.tryParse(currentValue.toString()) ?? DateTime.now()
                  : DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                final locale = ref.read(localeProvider).locale;
                _specialtyData[field.fieldName!] =
                    DateFormat('yyyy-MM-dd', locale.toString()).format(date);
              });
            }
          },
        );
      default:
        // Handle 'text' and 'number' field types
        return TextFormField(
          initialValue: currentValue?.toString(),
          decoration: _medicalInputDecoration(
            labelText: labelText,
            helperText: isRequired ? AppLocalizations.of(context)!.requiredField : null,
          ),
          keyboardType: field.fieldType == 'number'
              ? TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppLocalizations.of(context)!.thisFieldRequired;
                  }
                  if (field.fieldType == 'number') {
                    final numValue = double.tryParse(value);
                    if (numValue == null) {
                      return AppLocalizations.of(context)!.pleaseEnterValidNumber;
                    }
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            setState(() {
              if (field.fieldType == 'number') {
                final numValue = double.tryParse(value);
                if (numValue != null) {
                  _specialtyData[field.fieldName!] = numValue;
                } else if (value.isEmpty) {
                  _specialtyData.remove(field.fieldName!);
                }
              } else {
                if (value.isNotEmpty) {
                  _specialtyData[field.fieldName!] = value;
                } else {
                  _specialtyData.remove(field.fieldName!);
                }
              }
            });
          },
        );
    }
  }

  Widget _buildMedicalDetailsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.medicalInformation,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.describeSymptomsDiagnosisTreatment,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
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
        _buildMedicalDetailField(
          controller: _symptomsController,
          label: AppLocalizations.of(context)!.symptoms,
          hint: AppLocalizations.of(context)!.symptomsHint,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildMedicalDetailField(
          controller: _diagnosisController,
          label: AppLocalizations.of(context)!.diagnosis,
          hint: AppLocalizations.of(context)!.diagnosisHint,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildMedicalDetailField(
          controller: _treatmentController,
          label: AppLocalizations.of(context)!.treatment,
          hint: AppLocalizations.of(context)!.treatmentHint,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildMedicalDetailField(
          controller: _notesController,
          label: AppLocalizations.of(context)!.additionalNotes,
          hint: AppLocalizations.of(context)!.additionalNotesHint,
          maxLines: 3,
        ),
      ],
    );
  }

  Future<void> _handleVoiceInputForField(TextEditingController controller) async {
    if (_activeVoiceController == controller && _speechService.isListening) {
      HapticFeedback.mediumImpact();
      await _speechService.stopListening(onDone: () {
        if (mounted) setState(() {
          _activeVoiceController = null;
          _voiceBaseText = '';
        });
      });
      if (mounted) setState(() => _activeVoiceController = null);
      return;
    }
    if (_activeVoiceController != null && _activeVoiceController != controller) {
      await _speechService.stopListening();
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _activeVoiceController = null;
        _voiceBaseText = '';
      });
    }
    if (!_speechService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnaissance vocale indisponible. Vérifiez les permissions du microphone.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    _voiceBaseText = controller.text.trim();
    setState(() => _activeVoiceController = controller);
    HapticFeedback.mediumImpact();
    final locale = ref.read(localeProvider).locale;
    final localeId = locale.toString().replaceAll('-', '_');
    await _speechService.startListening(
      context: context,
      localeId: localeId.isNotEmpty ? localeId : 'fr_FR',
      onResult: (text, _) {
        if (!mounted || _activeVoiceController != controller) return;
        setState(() {
          final base = _voiceBaseText;
          controller.text = base.isEmpty ? text.trim() : '$base ${text.trim()}';
        });
      },
      onError: () {
        if (mounted) {
          setState(() => _activeVoiceController = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur de reconnaissance vocale. Vérifiez le micro.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onDone: () {
        if (mounted) setState(() {
          _activeVoiceController = null;
          _voiceBaseText = '';
        });
      },
      onListeningStateChanged: (listening) {
        if (!mounted) return;
        // Only update UI when value actually changes to avoid rebuild storm from plugin firing repeatedly.
        // Keep Stop visible until user taps stop (onDone); ignore spurious 'false' from plugin (e.g. pause).
        final currentlyShowingListening = _activeVoiceController == controller;
        if (listening && !currentlyShowingListening) {
          setState(() => _activeVoiceController = controller);
        }
      },
    );
  }

  Widget _buildMedicalDetailField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 3,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isListening = _activeVoiceController == controller;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: isListening ? 'Arrêter' : 'Parler (reconnaissance vocale)',
            icon: Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: isListening ? Colors.red : (isDark ? Colors.white70 : Colors.grey.shade600),
              size: 22,
            ),
            onPressed: () => _handleVoiceInputForField(controller),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isListening ? Colors.red.withOpacity(0.5) : (isDark ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return Text(
              AppLocalizations.of(context)!.reviewAndSubmit,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
_buildReviewItem(AppLocalizations.of(context)!.patient,
                            _selectedPatient?.user?.name ?? AppLocalizations.of(context)!.notSelected),
                            _buildReviewItem(AppLocalizations.of(context)!.doctor,
                            _selectedDoctor?.user?.name ?? AppLocalizations.of(context)!.notSelected),
                            _buildReviewItem(AppLocalizations.of(context)!.specialty,
                            _selectedSpecialty?.name ?? AppLocalizations.of(context)!.notSelected),
                        _buildReviewItem(
                            AppLocalizations.of(context)!.symptoms,
                            _symptomsController.text.isEmpty
                                ? AppLocalizations.of(context)!.notEntered
                                : _symptomsController.text),
                        _buildReviewItem(
                            AppLocalizations.of(context)!.diagnosis,
                            _diagnosisController.text.isEmpty
                                ? AppLocalizations.of(context)!.notEntered
                                : _diagnosisController.text),
                        _buildReviewItem(
                            AppLocalizations.of(context)!.treatment,
                            _treatmentController.text.isEmpty
                                ? AppLocalizations.of(context)!.notEntered
                                : _treatmentController.text),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Visibility',
                            prefixIcon: Icon(Icons.visibility),
                            border: OutlineInputBorder(),
                            helperText:
                                'Public: Visible to all authorized users. Private: Only visible to assigned doctor and admin.',
                          ),
                          value: _visibility,
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 18),
                                  SizedBox(width: 8),
                                  Text('Public'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Row(
                                children: [
                                  Icon(Icons.lock, size: 18),
                                  SizedBox(width: 8),
                                  Text('Private'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _visibility = value);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNavigationButtons() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep != MedicalRecordStep.patientDoctor)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  label: Builder(
                    builder: (context) {
                      return Text(
                        AppLocalizations.of(context)!.previous,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              )
            else
              const SizedBox(),
            if (_currentStep != MedicalRecordStep.patientDoctor)
              const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == MedicalRecordStep.patientDoctor ? 1 : 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _currentStep == MedicalRecordStep.review
                      ? (_isSubmitting ? null : _submit)
                      : _nextStep,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _currentStep == MedicalRecordStep.review
                              ? Icons.check_circle
                              : Icons.arrow_forward_ios,
                          size: 18,
                        ),
                  label: Builder(
                    builder: (context) {
                      return Text(
                        _isSubmitting
                            ? AppLocalizations.of(context)!.processing
                            : _currentStep == MedicalRecordStep.review
                                ? (widget.recordId != null
                                    ? AppLocalizations.of(context)!.updateButton
                                    : AppLocalizations.of(context)!.createRecordButton)
                                : AppLocalizations.of(context)!.next,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog content for creating a new patient when none found in medical record flow.
class _CreatePatientDialogContent extends StatefulWidget {
  final String initialName;
  final PatientService patientService;
  final int doctorId;
  final String appointmentDate;
  final String appointmentTime;
  final void Function(PatientModel patient, String createdName) onCreated;
  final VoidCallback onCancel;

  const _CreatePatientDialogContent({
    required this.initialName,
    required this.patientService,
    required this.doctorId,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.onCreated,
    required this.onCancel,
  });

  @override
  State<_CreatePatientDialogContent> createState() =>
      _CreatePatientDialogContentState();
}

class _CreatePatientDialogContentState extends State<_CreatePatientDialogContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await widget.patientService.createPatient(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      doctorId: widget.doctorId,
      appointmentDate: widget.appointmentDate,
      appointmentTime: widget.appointmentTime,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result is Success<PatientModel>) {
      final name = _nameController.text.trim();
      widget.onCreated(result.data, name.isNotEmpty ? name : (result.data.user?.name ?? ''));
    } else if (result is Failure<PatientModel>) {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create patient'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'No patient found. Create a new patient to continue.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isSubmitting ? null : widget.onCancel,
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create patient'),
        ),
      ],
    );
  }
}
