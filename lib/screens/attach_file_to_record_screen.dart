// lib/screens/attach_file_to_record_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';
import '../data/models/patient_model.dart';
import '../data/models/medical_record_model.dart';
import '../providers/patient_providers.dart';
import '../providers/medical_record_providers.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'patient_detail_screen.dart';
import 'medical_record_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../providers/api_providers.dart' hide medicalRecordServiceProvider;
import 'create_medical_record_screen.dart';
import 'image_annotation_screen.dart';

enum AttachFileStep {
  selectPatient,
  selectRecord,
  uploadFiles,
}

class _SelectedFile {
  final File? file;
  final Uint8List? fileBytes;
  final String fileName;
  final int fileSize;
  final bool isAnnotated;

  _SelectedFile({
    this.file,
    this.fileBytes,
    required this.fileName,
    required this.fileSize,
    this.isAnnotated = false,
  });

  _SelectedFile copyWith({
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    int? fileSize,
    bool? isAnnotated,
  }) {
    return _SelectedFile(
      file: file ?? this.file,
      fileBytes: fileBytes ?? this.fileBytes,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isAnnotated: isAnnotated ?? this.isAnnotated,
    );
  }
}

class AttachFileToRecordScreen extends ConsumerStatefulWidget {
  const AttachFileToRecordScreen({super.key});

  @override
  ConsumerState<AttachFileToRecordScreen> createState() =>
      _AttachFileToRecordScreenState();
}

class _AttachFileToRecordScreenState
    extends ConsumerState<AttachFileToRecordScreen> {
  AttachFileStep _currentStep = AttachFileStep.selectPatient;

  // Step 1: Patient selection
  final _patientSearchController = TextEditingController();
  PatientModel? _selectedPatient;
  String _patientSearchQuery = '';

  // Step 2: Medical record selection
  MedicalRecordModel? _selectedRecord;
  int? _selectedPatientId;

  // Step 3: File upload
  List<_SelectedFile> _selectedFiles = [];
  bool _isUploading = false;
  bool _isAutoCreating = false;

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  void _handlePatientSearch(String query) {
    setState(() {
      _patientSearchQuery = query;
    });
  }

  void _handlePatientSelect(PatientModel patient) {
    if (patient.id == null) return;

    setState(() {
      _selectedPatient = patient;
      _patientSearchController.clear();
      _patientSearchQuery = '';
      _selectedRecord = null;
      _selectedFiles = [];
    });

    _loadMedicalRecords(patient.id!);
  }

  Future<void> _handleQuickUpload() async {
    if (_selectedPatient?.id == null) return;
    setState(() => _isAutoCreating = true);
    try {
      final medicalRecordService = ref.read(medicalRecordServiceProvider);
      final doctorService = ref.read(doctorServiceProvider);

      // Get first available doctor
      final doctorsResult = await doctorService.fetchDoctors();
      if (doctorsResult is! Success || (doctorsResult as Success).data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No doctor found to assign record')),
          );
        }
        return;
      }
      final doctorId = (doctorsResult as Success).data.first.id!;

      final result = await medicalRecordService.createMedicalRecord({
        'patient_id': _selectedPatient!.id,
        'doctor_id': doctorId,
      });

      if (result is Success<MedicalRecordModel>) {
        setState(() {
          _selectedRecord = result.data;
          _currentStep = AttachFileStep.uploadFiles;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((result as Failure).message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoCreating = false);
    }
  }

  Future<void> _showCreatePatientDialog(BuildContext context) async {
    final nameController = TextEditingController(text: _patientSearchQuery);
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add_rounded, color: Colors.blue.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'New Patient',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isCreating = true);
                          try {
                            final patientService = ref.read(patientServiceProvider);
                            final doctorService = ref.read(doctorServiceProvider);

                            final doctorsResult = await doctorService.fetchDoctors();
                            if (doctorsResult is! Success || (doctorsResult as Success).data.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No doctor found to assign patient')),
                                );
                              }
                              setDialogState(() => isCreating = false);
                              return;
                            }
                            final doctorId = (doctorsResult as Success).data.first.id!;

                            final now = DateTime.now();
                            final appointmentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                            const appointmentTime = '09:00';

                            final result = await patientService.createPatient(
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                              doctorId: doctorId,
                              appointmentDate: appointmentDate,
                              appointmentTime: appointmentTime,
                            );

                            if (!mounted) return;

                            if (result is Success<PatientModel>) {
                              Navigator.of(dialogContext).pop();
                              _handlePatientSelect(result.data);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text((result as Failure).message)),
                              );
                              setDialogState(() => isCreating = false);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                            setDialogState(() => isCreating = false);
                          }
                        },
                  child: isCreating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Create & Select', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPatientSearchResults(BuildContext context, bool isDark) {
    // Only search if query is at least 2 characters
    if (_patientSearchQuery.length < 2) {
      return const SizedBox.shrink();
    }

    final searchAsync = ref.watch(findPatientsProvider(_patientSearchQuery));

    return searchAsync.when(
      data: (result) {
        if (result is Success<List<PatientModel>>) {
          final patients = result.data;
          if (patients.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  // No results message
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '"$_patientSearchQuery" not found',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quick create option
                  InkWell(
                    onTap: () => _showCreatePatientDialog(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create new patient',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue.shade800, fontSize: 13),
                                ),
                                Text(
                                  'Add "$_patientSearchQuery" as a new patient',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.blue.shade400),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person, color: Colors.blue.shade600),
                    ),
                    title: Text(
                      patient.user?.name ?? 'Patient #${patient.id}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: patient.cniNumber != null
                        ? Text('CNI: ${patient.cniNumber}')
                        : null,
                    onTap: () => _handlePatientSelect(patient),
                  ),
                );
              },
            ),
          );
        } else if (result is Failure<List<PatientModel>>) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Erreur: ${result.message}',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade600,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Erreur: $error',
            style: GoogleFonts.poppins(
              color: Colors.red.shade600,
            ),
          ),
        ),
      ),
    );
  }

  void _loadMedicalRecords(int patientId) {
    setState(() {
      _selectedPatientId = patientId;
      _currentStep = AttachFileStep.selectRecord;
    });
  }

  Widget _buildMedicalRecordsList(BuildContext context, bool isDark) {
    if (_selectedPatientId == null) {
      return const SizedBox.shrink();
    }

    final recordsAsync =
        ref.watch(patientMedicalRecordsProvider(_selectedPatientId!));

    return recordsAsync.when(
      data: (result) {
        if (result is Success<List<MedicalRecordModel>>) {
          final records = result.data;
          if (records.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No medical records found',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an option to continue',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),

                  // Option 1 — Quick Upload
                  InkWell(
                    onTap: _isAutoCreating ? null : _handleQuickUpload,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isAutoCreating
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.upload_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Upload directly', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.green.shade800)),
                                Text('Auto-creates a blank record and goes to upload', style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Option 2 — Full record form
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateMedicalRecordScreen(patientId: _selectedPatient?.id),
                        ),
                      ).then((_) => _loadMedicalRecords(_selectedPatient!.id!));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.note_add_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Create full medical record', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
                                Text('Fill in diagnosis, symptoms etc. before uploading', style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final isSelected = _selectedRecord?.id == record.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected
                      ? Colors.blue.shade50
                      : (isDark ? Colors.grey.shade800 : Colors.white),
                  child: ListTile(
                    leading: Icon(
                      Icons.description,
                      color: isSelected
                          ? Colors.blue.shade600
                          : Colors.grey.shade600,
                    ),
                    title: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          '${localizations?.recordId ?? 'Record ID'}: ${record.id}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (record.diagnosis != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.medical_services,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    record.diagnosis!,
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (record.createdAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                    ref.watch(localeProvider).locale.toString(),
                                  ).format(record.createdAt!),
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.blue.shade600)
                        : null,
                    onTap: () => _handleRecordSelect(record),
                  ),
                );
              },
            ),
          );
        } else if (result is Failure<List<MedicalRecordModel>>) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Erreur: ${result.message}',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade600,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: LoadingWidget(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Erreur: $error',
            style: GoogleFonts.poppins(
              color: Colors.red.shade600,
            ),
          ),
        ),
      ),
    );
  }

  void _handleRecordSelect(MedicalRecordModel record) {
    setState(() {
      _selectedRecord = record;
      _currentStep = AttachFileStep.uploadFiles;
    });
  }

  Future<void> _pickFiles() async {
    final source = await _showUploadOptionsBottomSheet();
    if (source == null) return;

    try {
      File? pickedFile;
      Uint8List? fileBytes;
      String fileName = '';

      if (source == 'camera') {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (photo == null) return;

        if (photo.name.isEmpty || !photo.name.contains('.')) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          fileName = 'camera_$timestamp.jpg';
        } else {
          fileName = photo.name;
        }

        if (kIsWeb) {
          fileBytes = await photo.readAsBytes();
        } else {
          pickedFile = File(photo.path);
          if (!fileName.toLowerCase().endsWith('.jpg') &&
              !fileName.toLowerCase().endsWith('.jpeg')) {
            fileName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '') + '.jpg';
          }
        }
      } else if (source == 'gallery') {
        // Use FilePicker instead of ImagePicker to avoid READ_MEDIA permissions
        // FilePicker uses system photo picker on Android 13+ without requiring permissions
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return;

        final file = result.files.single;
        fileName = file.name;

        if (kIsWeb) {
          if (file.bytes == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Erreur lors du chargement de l\'image')),
            );
            return;
          }
          fileBytes = file.bytes;
        } else {
          if (file.path == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Erreur lors du chargement de l\'image')),
            );
            return;
          }
          pickedFile = File(file.path!);

          // Generate filename if empty
          if (fileName.isEmpty || !fileName.contains('.')) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final pathExtension = file.path!.split('.').last.toLowerCase();
            if (pathExtension == 'jpg' ||
                pathExtension == 'jpeg' ||
                pathExtension == 'png') {
              fileName = 'image_$timestamp.$pathExtension';
            } else {
              fileName = 'image_$timestamp.jpg';
            }
          }
        }
      } else if (source == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return;

        final file = result.files.single;
        fileName = file.name;

        if (kIsWeb) {
          if (file.bytes == null) {
            if (mounted) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations?.cannotReadFile ??
                        'Cannot read file. Please try again.',
                  ),
                ),
              );
            }
            return;
          }
          fileBytes = file.bytes;
        } else {
          if (file.path == null || file.path!.isEmpty) {
            if (mounted) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations?.filePathNotAvailable ??
                        'File path not available. Please try again.',
                  ),
                ),
              );
            }
            return;
          }

          pickedFile = File(file.path!);

          if (!await pickedFile.exists()) {
            if (mounted) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${localizations?.fileDoesNotExist ?? 'File does not exist'}: ${file.path}',
                  ),
                ),
              );
            }
            return;
          }

          if (fileName.isEmpty) {
            fileName = file.path!.split('/').last;
            if (fileName.isEmpty) {
              fileName = 'file_${DateTime.now().millisecondsSinceEpoch}';
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedFiles.add(_SelectedFile(
            file: pickedFile,
            fileBytes: fileBytes,
            fileName: fileName,
            fileSize: fileBytes?.length ??
                (pickedFile != null ? pickedFile.lengthSync() : 0),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  '${localizations?.errorSelectingFiles ?? 'Error selecting files'}: $e',
                );
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _annotateFile(int index) async {
    final selectedFile = _selectedFiles[index];
    final fileName = selectedFile.fileName;
    final ext = fileName.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return;

    Uint8List? imageBytes = selectedFile.fileBytes;
    if (imageBytes == null && selectedFile.file != null) {
      imageBytes = await selectedFile.file!.readAsBytes();
    }
    if (imageBytes == null || !mounted) return;

    final annotated = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageAnnotationScreen(
          imageBytes: imageBytes,
          fileName: fileName,
        ),
      ),
    );

    if (annotated != null && mounted) {
      setState(() {
        _selectedFiles[index] = selectedFile.copyWith(
          fileBytes: annotated,
          file: null, // use bytes from now on
          fileSize: annotated.length,
          isAnnotated: true,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Annotation saved', style: GoogleFonts.poppins()),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _analyzeFileWithAI(int index) async {
    final selectedFile = _selectedFiles[index];
    final ext = selectedFile.fileName.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return;

    // Get image bytes
    Uint8List? imageBytes = selectedFile.fileBytes;
    if (imageBytes == null && selectedFile.file != null) {
      imageBytes = await selectedFile.file!.readAsBytes();
    }
    if (imageBytes == null || !mounted) return;

    final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
    final aiService = ref.read(aiChatServiceProvider);

    // Show bottom sheet immediately with loading state
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiAnalysisSheet(
        fileName: selectedFile.fileName,
        imageBytes: imageBytes!,
        mime: mime,
        aiService: aiService,
      ),
    );
  }

  Future<String?> _showUploadOptionsBottomSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          localizations?.addAttachment ?? 'Add Attachment',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations?.chooseOption ??
                              'Choose an option to add a file',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color:
                                isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.camera_alt_rounded,
                            title: localizations?.camera ?? 'Camera',
                            subtitle:
                                localizations?.takePhoto ?? 'Take a photo',
                            color: Colors.blue,
                            onTap: () => Navigator.pop(context, 'camera'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.photo_library_rounded,
                            title: localizations?.gallery ?? 'Gallery',
                            subtitle:
                                localizations?.chooseImage ?? 'Choose an image',
                            color: Colors.green,
                            onTap: () => Navigator.pop(context, 'gallery'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.insert_drive_file_rounded,
                            title: localizations?.file ?? 'File',
                            subtitle:
                                localizations?.chooseFile ?? 'Choose a file',
                            color: Colors.orange,
                            onTap: () => Navigator.pop(context, 'file'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations?.cancel ?? 'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(
      _SelectedFile selectedFile, int index, bool isDark) {
    final fileName = selectedFile.fileName;
    final fileExtension = fileName.split('.').last.toLowerCase();
    final isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension);
    final isPdf = fileExtension == 'pdf';

    Color getFileColor() {
      if (isImage) return Colors.blue;
      if (isPdf) return Colors.red;
      return Colors.orange;
    }

    IconData getFileIcon() {
      if (isImage) return Icons.image_rounded;
      if (isPdf) return Icons.picture_as_pdf_rounded;
      return Icons.insert_drive_file_rounded;
    }

    final fileColor = getFileColor();
    final fileIcon = getFileIcon();
    final fileSizeKB = (selectedFile.fileSize / 1024).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedFile.isAnnotated
              ? Colors.orange.shade300
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          width: selectedFile.isAnnotated ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── File info row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                // Thumbnail or icon
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: fileColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isImage && selectedFile.fileBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                selectedFile.fileBytes!,
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                              ),
                            )
                          : Icon(fileIcon, color: fileColor, size: 28),
                    ),
                    if (selectedFile.isAnnotated)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$fileSizeKB KB',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (selectedFile.isAnnotated) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Annoté',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Action buttons — Wrap so they never overflow ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (isImage) ...[
                  _ActionChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Analyse IA',
                    color: Colors.purple,
                    onTap: () => _analyzeFileWithAI(index),
                  ),
                  _ActionChip(
                    icon: Icons.edit_rounded,
                    label: selectedFile.isAnnotated ? 'Ré-annoter' : 'Annoter',
                    color: selectedFile.isAnnotated ? Colors.orange : Colors.blue,
                    onTap: () => _annotateFile(index),
                  ),
                ],
                _ActionChip(
                  icon: Icons.delete_rounded,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () => _removeFile(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFiles() async {
    if (_selectedRecord == null || _selectedFiles.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectRecordAndFiles ??
                'Please select a record and files',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final service = ref.read(medicalRecordServiceProvider);
    int successCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    for (var selectedFile in _selectedFiles) {
      try {
        Result<MedicalRecordAttachment> uploadResult;

        if (kIsWeb) {
          if (selectedFile.fileBytes == null) {
            errorCount++;
            errors
                .add('${selectedFile.fileName}: Impossible de lire le fichier');
            continue;
          }
          uploadResult = await service.uploadAttachment(
            medicalRecordId: _selectedRecord!.id!,
            fileBytes: selectedFile.fileBytes,
            fileName: selectedFile.fileName,
          );
        } else {
          if (selectedFile.file == null) {
            errorCount++;
            errors.add(
                '${selectedFile.fileName}: Chemin du fichier non disponible');
            continue;
          }
          if (!await selectedFile.file!.exists()) {
            errorCount++;
            errors.add('${selectedFile.fileName}: Le fichier n\'existe pas');
            continue;
          }
          uploadResult = await service.uploadAttachment(
            medicalRecordId: _selectedRecord!.id!,
            file: selectedFile.file,
            fileName:
                selectedFile.fileName.isNotEmpty ? selectedFile.fileName : null,
          );
        }

        uploadResult.when(
          success: (_) => successCount++,
          failure: (message) {
            errorCount++;
            errors.add('${selectedFile.fileName}: $message');
          },
        );
      } catch (e) {
        errorCount++;
        errors.add('${selectedFile.fileName}: $e');
      }
    }

    setState(() {
      _isUploading = false;
    });

    if (mounted) {
      if (successCount > 0) {
        final locale = ref.watch(localeProvider).locale;
        final dateFormat =
            DateFormat('dd MMMM yyyy \'à\' HH:mm', locale.toString());
        final uploadDate = dateFormat.format(DateTime.now());

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.filesAttachedSuccessfully ??
                            'Files attached successfully',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      '${successCount} ${localizations?.filesUploadedSuccessfully ?? 'file(s) uploaded successfully'}${errorCount > 0 ? '\n\n$errorCount ${localizations?.filesFailed ?? 'file(s) failed'}' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.person,
                                localizations?.patient ?? 'Patient',
                                _selectedPatient?.user?.name ??
                                    '${localizations?.patient ?? 'Patient'} #${_selectedPatient?.id}',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.description,
                                localizations?.recordId ?? 'Record ID',
                                '${_selectedRecord!.id}',
                              ),
                              if (_selectedRecord!.diagnosis != null) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.medical_services,
                                  localizations?.diagnosis ?? 'Diagnosis',
                                  _selectedRecord!.diagnosis!,
                                ),
                              ],
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.calendar_today,
                                localizations?.date ?? 'Date',
                                uploadDate,
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
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Close attach file screen
                },
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.close ?? 'Close',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    );
                  },
                ),
              ),
              if (_selectedRecord?.id != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close attach file screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicalRecordDetailScreen(
                          recordId: _selectedRecord!.id!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.viewRecord ?? 'View Record');
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_selectedPatient?.id != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close attach file screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailScreen(
                          patientId: _selectedPatient!.id!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.viewProfile ?? 'View Profile');
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        );
      } else {
        final localizations = AppLocalizations.of(context);
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: localizations?.error ?? 'Error',
          desc:
              '${localizations?.fileUploadFailed ?? 'File upload failed'}.\n\n${errors.join('\n')}',
          btnOkText: 'Close',
          btnOkColor: Colors.red,
        ).show();
      }
    }
  }

  void _handleBack() {
    if (_currentStep == AttachFileStep.uploadFiles) {
      setState(() {
        _currentStep = AttachFileStep.selectRecord;
        _selectedFiles = [];
      });
    } else if (_currentStep == AttachFileStep.selectRecord) {
      setState(() {
        _currentStep = AttachFileStep.selectPatient;
        _selectedRecord = null;
        _selectedPatientId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.attachFiles ?? 'Attach Files',
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
                Colors.green.shade600,
                Colors.green.shade700,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0F0F23),
                    const Color(0xFF1A1A2E),
                  ]
                : [
                    const Color(0xFFF0F2F5),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Indicator
                _buildStepIndicator(context, isDark, primaryColor),
                const SizedBox(height: 32),

                // Step Content
                if (_currentStep == AttachFileStep.selectPatient)
                  _buildSelectPatientStep(context, isDark)
                else if (_currentStep == AttachFileStep.selectRecord)
                  _buildSelectRecordStep(context, isDark)
                else if (_currentStep == AttachFileStep.uploadFiles)
                  _buildUploadFilesStep(context, isDark),

                const SizedBox(height: 32),

                // Navigation Buttons
                _buildNavigationButtons(context, isDark, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(
      BuildContext context, bool isDark, Color primaryColor) {
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildStepCircle(
            context,
            step: 1,
            isActive: _currentStep.index >= 0,
            isCompleted: _currentStep.index > 0,
            label: localizations?.selectPatient ?? 'Select Patient',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ),
        SizedBox(
          width: 12,
          child: Center(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: _currentStep.index >= 1
                    ? primaryColor
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildStepCircle(
            context,
            step: 2,
            isActive: _currentStep.index >= 1,
            isCompleted: _currentStep.index > 1,
            label: localizations?.selectRecord ?? 'Select Record',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ),
        SizedBox(
          width: 12,
          child: Center(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: _currentStep.index >= 2
                    ? primaryColor
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildStepCircle(
            context,
            step: 3,
            isActive: _currentStep.index >= 2,
            isCompleted: false,
            label: localizations?.uploadFiles ?? 'Upload Files',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStepCircle(
    BuildContext context, {
    required int step,
    required bool isActive,
    required bool isCompleted,
    required String label,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? primaryColor : Colors.grey.withOpacity(0.3),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : Text(
                    '$step',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? primaryColor
                : (isDark ? Colors.white70 : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectPatientStep(BuildContext context, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.selectPatient ?? 'Select Patient',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextField(
                  controller: _patientSearchController,
                  decoration: InputDecoration(
                    hintText: localizations?.searchForPatient ??
                        'Search for a patient...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  ),
                  onChanged: _handlePatientSearch,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildPatientSearchResults(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectRecordStep(BuildContext context, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description,
                    color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.selectMedicalRecord ??
                          'Select Medical Record',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedPatient != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          '${localizations?.patient ?? 'Patient'}: ${_selectedPatient!.user?.name ?? '${localizations?.patient ?? 'Patient'} #${_selectedPatient!.id}'}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildMedicalRecordsList(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFilesStep(BuildContext context, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.green.shade600, size: 24),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.uploadFiles ?? 'Upload Files',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedRecord != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.purple.shade600),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              '${localizations?.recordId ?? 'Record ID'}: ${_selectedRecord!.id}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade900,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_selectedRecord!.diagnosis != null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${localizations?.diagnosis ?? 'Diagnosis'}: ${_selectedRecord!.diagnosis}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(localizations?.addFiles ?? 'Add Files');
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedFiles.isNotEmpty) ...[
              // File count header
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Row(
                    children: [
                      Text(
                        '${localizations?.selectedFiles ?? 'Selected Files'}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selectedFiles.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // File list (no fixed height — expands naturally)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  return _buildSelectedFileCard(
                      _selectedFiles[index], index, isDark);
                },
              ),
              const SizedBox(height: 8),
              // Upload button — inside same bordered container style as file cards
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isUploading
                        ? Colors.green.shade300
                        : Colors.green.shade400,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: (!_isUploading && _selectedFiles.isNotEmpty) ? _uploadFiles : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          // Icon container matching file card icon style
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: _isUploading
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.green.shade600,
                                    ),
                                  )
                                : Icon(Icons.cloud_upload_rounded,
                                    color: Colors.green.shade600, size: 24),
                          ),
                          const SizedBox(width: 16),
                          // Label
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(context);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isUploading
                                          ? (localizations?.uploading ?? 'Uploading...')
                                          : (localizations?.uploadFiles ?? 'Upload Files'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      _isUploading
                                          ? 'Please wait...'
                                          : '${_selectedFiles.length} file${_selectedFiles.length > 1 ? 's' : ''} ready to upload',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.green.shade500,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          // Arrow
                          if (!_isUploading)
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 16, color: Colors.green.shade400),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.cloud_upload,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.noFilesSelected ??
                                'No files selected',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(
      BuildContext context, bool isDark, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: _currentStep == AttachFileStep.selectPatient
              ? () => Navigator.pop(context)
              : _handleBack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                _currentStep == AttachFileStep.selectPatient
                    ? (localizations?.cancel ?? 'Cancel')
                    : (localizations?.back ?? 'Back'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        if (_currentStep == AttachFileStep.selectPatient)
          ElevatedButton(
            onPressed: _selectedPatient != null
                ? () {
                    if (_selectedPatientId != null) {
                      setState(() {
                        _currentStep = AttachFileStep.selectRecord;
                      });
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Next',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                );
              },
            ),
          )
        else if (_currentStep == AttachFileStep.selectRecord)
          ElevatedButton(
            onPressed: _selectedRecord != null
                ? () {
                    setState(() {
                      _currentStep = AttachFileStep.uploadFiles;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Next',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                );
              },
            ),
          )
        // Upload step: button is embedded in the file list — no nav button needed
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon+label chip button used in the file card action row
// ─────────────────────────────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Analysis bottom sheet — auto-analyzes on open, supports follow-up Q&A
// ─────────────────────────────────────────────────────────────────────────────
class _AiAnalysisSheet extends StatefulWidget {
  final String fileName;
  final Uint8List imageBytes;
  final String mime;
  final AiChatService aiService;

  const _AiAnalysisSheet({
    required this.fileName,
    required this.imageBytes,
    required this.mime,
    required this.aiService,
  });

  @override
  State<_AiAnalysisSheet> createState() => _AiAnalysisSheetState();
}

class _AiAnalysisSheetState extends State<_AiAnalysisSheet> {
  String? _response;
  String? _error;
  bool _loading = true;
  final _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analyze('');
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _analyze(String question) async {
    setState(() { _loading = true; _error = null; });
    final result = await widget.aiService.analyzeImage(
      widget.imageBytes,
      mimeType: widget.mime,
      question: question,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result is Success<String>) {
        _response = result.data;
      } else {
        _error = (result as Failure).message;
      }
    });
  }

  // Simple inline markdown: **bold** and bullet lines
  List<InlineSpan> _renderMarkdown(String text) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[i];
      final isBullet = line.trimLeft().startsWith('- ');
      final content = isBullet ? line.replaceFirst(RegExp(r'^\s*-\s'), '') : line;
      if (isBullet) spans.add(const TextSpan(text: '• '));
      // bold segments
      final parts = content.split(RegExp(r'\*\*'));
      for (var j = 0; j < parts.length; j++) {
        spans.add(TextSpan(
          text: parts[j],
          style: j.isOdd
              ? const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
              : null,
        ));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0f1929),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.purpleAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analyse IA',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Text(widget.fileName,
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1e3a5f), height: 1),
            // Body
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                  color: Colors.purpleAccent),
                              const SizedBox(height: 16),
                              Text('Analyse en cours…',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(_error!,
                            style: GoogleFonts.poppins(
                                color: Colors.redAccent, fontSize: 13)),
                      )
                    else if (_response != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_rounded,
                              color: Colors.purpleAccent, size: 16),
                          const SizedBox(width: 6),
                          Text('Résultat',
                              style: GoogleFonts.poppins(
                                  color: Colors.purpleAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          const Spacer(),
                          // Copy button
                          IconButton(
                            icon: const Icon(Icons.copy_rounded,
                                color: Colors.white38, size: 16),
                            tooltip: 'Copier',
                            onPressed: () {
                              // Copy to clipboard
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.purple.withOpacity(0.2)),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.6),
                            children: _renderMarkdown(_response!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assistance IA uniquement — le jugement clinique du médecin reste prioritaire.',
                        style: GoogleFonts.poppins(
                            color: Colors.white24, fontSize: 10),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Follow-up question
                    if (!_loading) ...[
                      Text('Poser une question complémentaire',
                          style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _questionController,
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText:
                                    'Ex. : Y a-t-il une fracture visible ?',
                                hintStyle: GoogleFonts.poppins(
                                    color: Colors.white30, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFF080c14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1e3a5f)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1e3a5f)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.purpleAccent),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onSubmitted: (q) {
                                if (q.trim().isNotEmpty) {
                                  _analyze(q.trim());
                                  _questionController.clear();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              final q = _questionController.text.trim();
                              if (q.isNotEmpty) {
                                _analyze(q);
                                _questionController.clear();
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
