// Modern Create Appointment Screen with Enhanced UI/UX
//
// Add these packages to pubspec.yaml:
// dependencies:
//   flutter_riverpod: ^2.4.0
//   intl: ^0.18.1
//   animated_custom_dropdown: ^3.0.0
//   flutter_animate: ^4.3.0
//   google_fonts: ^6.1.0
//   flutter_slidable: ^3.0.0

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../widgets/face_detection_camera.dart';
import '../widgets/authenticated_image.dart';
import '../providers/appointment_providers.dart';
import '../providers/patient_providers.dart';
import '../providers/doctor_providers.dart';
import '../providers/service_providers.dart';
import '../data/models/patient_model.dart';
import '../data/models/service_model.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/add_service_modal.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../providers/api_providers.dart';
import '../services/appointment_notification_helper.dart';
import '../providers/auth_providers.dart';
import '../data/models/appointment_response_model.dart';
import '../providers/dashboard_providers.dart';
import '../services/global_appointment_sync.dart';

enum AppointmentStep { check, select, newPatient, appointment }

// Insurance options list
const List<String> INSURANCE_OPTIONS = [
  "ACMAR",
  "INOMAR",
  "ALLIANZ",
  "AL WATANIYA (RMAWATANYA)",
  "ASSURANCE",
  "ASSURANCE BANCAIRE",
  "ATLANTA",
  "AXA ASSURANCE MAROC",
  "BANK AL-MAGHRIB",
  "BANQUE POPULAIRE",
  "CMIM",
  "CNIA ASSURANCE",
  "CNOPS",
  "CNSS",
  "ESSAADA",
  "FAR",
  "ISSAAF MONDIAL ASSISTANCE",
  "MAMDA",
  "MCMA",
  "MGBM (AVOCAT)",
  "MUTUELLE GENERALE DES BARREAUX DU MAROC",
  "OCP",
  "ONE",
  "RADEEF",
  "RADEM",
  "RIDAL",
  "SAHAM",
  "SANAD",
  "SOCIETE CENTRALE DE REASSURANCE (SCR)",
  "WAFA ASSURANCE",
  "ZURICH ASSURANCES MAROC",
  "Auther",
  "none",
];

class CreateAppointmentScreen extends ConsumerStatefulWidget {
  const CreateAppointmentScreen({super.key});

  @override
  ConsumerState<CreateAppointmentScreen> createState() =>
      _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState
    extends ConsumerState<CreateAppointmentScreen>
    with SingleTickerProviderStateMixin {
  AppointmentStep _currentStep = AppointmentStep.check;
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Patient search state
  List<PatientModel> _foundPatients = [];
  PatientModel? _selectedPatient;
  bool _patientExists = false;
  bool _isCheckingPatient = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _addressController = TextEditingController();
  final _cniController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _invoiceAmountController = TextEditingController();
  final _initialAmountController = TextEditingController();

  // Form values
  String? _gender;
  String? _bloodType;
  String? _insuranceType;
  String? _selectedDoctorId;
  String? _selectedServiceId;
  List<ServiceModel> _servicesCache = [];
  DateTime? _appointmentDate;
  String? _selectedTime;
  String _priority = 'medium';
  bool _generateInvoice = false;
  bool _addInvoiceAmount = false;
  bool _markAsPaid = false;
  bool _addInitialAmount = false;
  bool _sendWhatsAppNotification = false;
  bool _sendEmailNotification = false;
  bool _isSubmitting = false;
  String? _conflictError;
  int? _calculatedAge;

  // OCR scanning state
  bool _isScanningId = false;
  Map<String, dynamic>? _scanResult;
  bool _extractFaceId = true; // Checkbox state for face extraction

  // Face recognition data from OCR
  String? _facePhotoPath;
  String? _faceEmbedding;
  bool _shouldRegisterFacePhoto = true;
  final ImagePicker _imagePicker = ImagePicker();

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdateController.dispose();
    _addressController.dispose();
    _cniController.dispose();
    _insuranceNumberController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _notesController.dispose();
    _invoiceAmountController.dispose();
    _initialAmountController.dispose();
    super.dispose();
  }

  Future<void> _checkPatient() async {
    if (_searchController.text.trim().length < 2) {
      final localizations = AppLocalizations.of(context);
      _showErrorSnackBar('Search term must be at least 2 characters'
          'Search term must be at least 2 characters');
      return;
    }

    setState(() {
      _isCheckingPatient = true;
    });

    final result = await ref.read(
      findPatientsProvider(_searchController.text.trim()).future,
    );

    setState(() {
      _isCheckingPatient = false;
    });

    result.when(
      success: (patients) {
        if (patients.isEmpty) {
          setState(() {
            _patientExists = false;
            _currentStep = AppointmentStep.newPatient;
            _nameController.text = _searchController.text;
            _emailController.text = _searchController.text.contains('@')
                ? _searchController.text
                : 'noemail@patient.com';
          });
          _animationController.forward(from: 0.0);
        } else if (patients.length == 1) {
          _selectPatient(patients.first);
        } else {
          setState(() {
            _patientExists = true;
            _foundPatients = patients;
            _currentStep = AppointmentStep.select;
          });
          _animationController.forward(from: 0.0);
        }
      },
      failure: (message) {
        _showErrorSnackBar(message);
      },
    );
  }

  void _selectPatient(PatientModel patient) {
    setState(() {
      _selectedPatient = patient;
      _patientExists = true;
      _currentStep = AppointmentStep.appointment;
      _nameController.text = patient.user?.name ?? '';
      _emailController.text = patient.user?.email ?? 'noemail@patient.com';
      _phoneController.text = patient.phone ?? patient.phoneNumber ?? '';
      _birthdateController.text = patient.birthdate ?? '';
      _addressController.text = patient.address ?? '';
      _cniController.text = patient.cniNumber ?? '';
      _insuranceNumberController.text = patient.insuranceNumber ?? '';
      _insuranceType = patient.insuranceType;
      _emergencyContactNameController.text = patient.emergencyContactName ?? '';
      _emergencyContactPhoneController.text =
          patient.emergencyContactPhone ?? '';
      _gender = patient.gender;
      _bloodType = patient.bloodType;
      _calculatedAge = patient.calculateAge();
    });
    _animationController.forward(from: 0.0);
  }

  void _calculateAge() {
    if (_birthdateController.text.isNotEmpty) {
      try {
        final birthdate = DateTime.parse(_birthdateController.text);
        final now = DateTime.now();
        int age = now.year - birthdate.year;
        if (now.month < birthdate.month ||
            (now.month == birthdate.month && now.day < birthdate.day)) {
          age--;
        }
        setState(() {
          _calculatedAge = age;
        });
      } catch (e) {
        setState(() {
          _calculatedAge = null;
        });
      }
    } else {
      setState(() {
        _calculatedAge = null;
      });
    }
  }

  /// Clean extracted name by removing common Moroccan city names
  String _cleanExtractedName(String name) {
    // List of common Moroccan cities (case-insensitive matching)
    final moroccanCities = [
      'ouarzazate',
      'casablanca',
      'rabat',
      'marrakech',
      'fes',
      'fès',
      'tanger',
      'agadir',
      'meknes',
      'oujda',
      'kenitra',
      'tetouan',
      'safi',
      'mohammedia',
      'khouribga',
      'beni mellal',
      'taza',
      'el jadida',
      'nador',
      'settat',
      'larache',
      'ksar el kebir',
      'berkane',
      'taourirt',
      'benslimane',
      'al hoceima',
      'errachidia',
      'taroudant',
      'sidi kacem',
      'tiflet',
      'sidi sliman',
      'youssoufia',
      'tan tan',
      'sidi ifni',
      'guelmim',
      'dakhla',
      'laayoune',
      'sale',
      'temara',
      'mohammedia',
      'berrechid',
      'fnideq',
      'ait melloul',
      'driouch',
      'midelt',
      'azrou',
      'khénifra',
      'khemisset',
      'el kelaa des sraghna',
      'ouazzane',
      'sidi bennour',
      'martil',
      'fnideq',
      'chefchaouen',
      'asilah',
      'tiznit',
      'guelta zemmur',
      'boujdour',
      'smara',
      'bir lehlou',
    ];

    // Split name into words
    final words = name.trim().split(RegExp(r'\s+'));
    final cleanedWords = <String>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final wordLower = word.toLowerCase().trim();
      
      // Special handling for "El" - don't remove it if it's part of a name like "El Alami"
      // "El" is a common prefix in Moroccan names (e.g., "El Alami", "El Fassi")
      if (wordLower == 'el' && i < words.length - 1) {
        // If "El" is followed by another word, keep it (it's part of the name)
        cleanedWords.add(word);
        continue;
      }
      
      // Check if word is a city name (exact match or word is contained in city name)
      // But don't match if the city name is just a substring (e.g., "el" in "el jadida")
      bool isCity = false;
      for (final city in moroccanCities) {
        final cityLower = city.toLowerCase();
        // Exact match
        if (wordLower == cityLower) {
          isCity = true;
          print('[CNI Scanner] Removed city name from name: "$word"');
          break;
        }
        // Word is contained in city name (e.g., "jadida" in "el jadida")
        // But only if the word is substantial (at least 4 chars) to avoid false matches
        if (wordLower.length >= 4 && cityLower.contains(wordLower)) {
          isCity = true;
          print('[CNI Scanner] Removed city name from name: "$word" (part of "$city")');
          break;
        }
      }

      // Keep the word if it's not a city
      if (!isCity && word.isNotEmpty) {
        cleanedWords.add(word);
      }
    }

    final cleanedName = cleanedWords.join(' ').trim();

    if (cleanedName.isEmpty) {
      // If all words were cities, return original name
      print(
          '[CNI Scanner] Warning: All words were cities, using original name');
      return name.trim();
    }

    if (cleanedName != name.trim()) {
      print('[CNI Scanner] Cleaned name: "$name" -> "$cleanedName"');
    }

    return cleanedName;
  }

  /// Compress image file to reduce size (target: max 2MB)
  Future<File> _compressImageFile(File imageFile) async {
    try {
      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 1920, // Max width for CNI scanning (good quality)
        targetHeight: 1080, // Max height
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convert to PNG bytes with compression
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // If still too large, try JPEG compression
      if (pngBytes.length > 2 * 1024 * 1024) {
        print(
            '[CNI Scanner] PNG too large (${pngBytes.length} bytes), reducing dimensions...');

        // Create a temporary file for compressed image
        final tempDir = await getTemporaryDirectory();
        final compressedPath =
            '${tempDir.path}/cni_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final compressedFile = File(compressedPath);

        // Write compressed bytes (we'll use a simple approach - save as is)
        // For better compression, we'd need a JPEG encoder, but for now we'll use PNG with lower quality
        await compressedFile.writeAsBytes(pngBytes);

        // If still too large, reduce quality further
        if (await compressedFile.length() > 2 * 1024 * 1024) {
          print(
              '[CNI Scanner] Still too large, reducing dimensions further...');
          final smallerCodec = await ui.instantiateImageCodec(
            imageBytes,
            targetWidth: 1280,
            targetHeight: 720,
          );
          final smallerFrame = await smallerCodec.getNextFrame();
          final smallerImage = smallerFrame.image;
          final smallerByteData =
              await smallerImage.toByteData(format: ui.ImageByteFormat.png);
          final smallerPngBytes = smallerByteData!.buffer.asUint8List();
          await compressedFile.writeAsBytes(smallerPngBytes);
        }

        image.dispose();
        return compressedFile;
      }

      // Save compressed PNG
      final tempDir = await getTemporaryDirectory();
      final compressedPath =
          '${tempDir.path}/cni_compressed_${DateTime.now().millisecondsSinceEpoch}.png';
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(pngBytes);

      image.dispose();
      return compressedFile;
    } catch (e) {
      print('[CNI Scanner] ⚠ Compression failed: $e, using original file');
      return imageFile; // Return original if compression fails
    }
  }

  /// Compress image bytes for web platform
  Future<Uint8List> _compressImageBytes(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 1920,
        targetHeight: 1080,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convert to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // If still too large, reduce dimensions further
      if (pngBytes.length > 2 * 1024 * 1024) {
        print('[CNI Scanner] PNG too large, reducing dimensions...');
        final smallerCodec = await ui.instantiateImageCodec(
          imageBytes,
          targetWidth: 1280,
          targetHeight: 720,
        );
        final smallerFrame = await smallerCodec.getNextFrame();
        final smallerImage = smallerFrame.image;
        final smallerByteData =
            await smallerImage.toByteData(format: ui.ImageByteFormat.png);
        final smallerPngBytes = smallerByteData!.buffer.asUint8List();

        image.dispose();
        smallerImage.dispose();
        return smallerPngBytes;
      }

      image.dispose();
      return pngBytes;
    } catch (e) {
      print('[CNI Scanner] ⚠ Compression failed: $e, using original bytes');
      return imageBytes; // Return original if compression fails
    }
  }

  /// Scan CNI card from patient search step - automatically searches for patient
  Future<void> _scanCniCardForSearch() async {
    print('[CNI Scanner] ==========================================');
    print('[CNI Scanner] Starting CNI card scanning for patient search...');

    try {
      // Use face detection camera for automatic capture
      print('[CNI Scanner] Opening face detection camera...');
      File? capturedImage;

      if (kIsWeb) {
        // Web: fallback to regular image picker
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (image == null) {
          print('[CNI Scanner] ✗ User cancelled camera capture');
          return;
        }
        capturedImage = File(image.path);
      } else {
        // Mobile: use face detection camera
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FaceDetectionCamera(
              onImageCaptured: (File image) {
                capturedImage = image;
              },
              onCancel: () {
                print('[CNI Scanner] ✗ User cancelled camera capture');
              },
            ),
          ),
        );

        if (capturedImage == null) {
          print('[CNI Scanner] ✗ No image captured');
          return;
        }
      }

      print('[CNI Scanner] ✓ Image captured successfully');
      final originalSize = await capturedImage!.length();
      print(
          '[CNI Scanner] Original image size: $originalSize bytes (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      setState(() {
        _isScanningId = true;
      });

      // Use original image without compression
      dynamic imageFile;
      if (kIsWeb) {
        final originalBytes = await capturedImage!.readAsBytes();
        imageFile = originalBytes;
      } else {
        imageFile = capturedImage!;
      }

      // Call OCR service
      final ocrService = ref.read(ocrServiceProvider);
      final result = await ocrService.extractMoroccanId(
        imageFile,
        extractFace: _extractFaceId,
      );

      setState(() {
        _isScanningId = false;
      });

      result.when(
        success: (data) {
          setState(() {
            _scanResult = data;
          });

          // Store face recognition data if available - safely extract
          Map<String, dynamic>? faceRecognition;
          if (data is Map) {
            final faceRecognitionValue = data['face_recognition'];
            if (faceRecognitionValue != null && faceRecognitionValue is Map) {
              faceRecognition = Map<String, dynamic>.from(faceRecognitionValue);
            }
          }

          if (faceRecognition != null) {
            final faceData = faceRecognition;
            setState(() {
              _facePhotoPath = faceData['photo_path'] as String?;
              _faceEmbedding = faceData['face_embedding'] as String?;
            });
            print('[CNI Scanner] ✓ Face recognition data stored');
            print('[CNI Scanner]   - Photo path: $_facePhotoPath');

            // Check if validation failed (face match found but text doesn't match)
            if (faceData['match_validation_failed'] == true) {
              final similarPatients = faceData['similar_patients'] as List?;
              if (similarPatients != null && similarPatients.isNotEmpty) {
                final bestMatch = similarPatients[0] as Map<String, dynamic>;
                final patientName = bestMatch['name'] ?? 'Unknown';
                final similarity = bestMatch['similarity'] ?? 0.0;

                print('[CNI Scanner] ⚠ Face match found but validation failed');
                print('[CNI Scanner]   - Matched patient: $patientName');
                print('[CNI Scanner]   - Similarity: $similarity');
                print(
                    '[CNI Scanner]   - Reasons: ${faceData['validation_reasons']}');

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '⚠️ Face match found ($patientName) but ID card data doesn\'t match. Please verify manually.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
                // Don't auto-select - let user verify manually
              }
            }

            // Handle matched_patient - if a patient is directly matched and validated, select it automatically
            if (faceData['matched_patient'] != null &&
                faceData['match_validation_failed'] != true) {
              try {
                final matchedPatientData =
                    faceData['matched_patient'] as Map<String, dynamic>;
                final matchedPatient =
                    PatientModel.fromJson(matchedPatientData);
                print(
                    '[CNI Scanner] ✓ Matched patient found and validated via face recognition: ${matchedPatient.user?.name}');
                _selectPatient(matchedPatient);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Patient matched and selected via face recognition'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return; // Exit early since patient is already selected
              } catch (e) {
                print('[CNI Scanner] ✗ Error parsing matched_patient: $e');
              }
            }
          }

          // Safely extract parsed data
          Map<String, dynamic>? parsed;
          if (data is Map) {
            final parsedValue = data['parsed'];
            if (parsedValue is Map) {
              parsed = Map<String, dynamic>.from(parsedValue);
            } else {
              print(
                  '[CNI Scanner] ⚠ Parsed data is not a Map: ${parsedValue?.runtimeType ?? 'null'}');
            }
          } else {
            print(
                '[CNI Scanner] ⚠ Response data is not a Map: ${data.runtimeType}');
          }

          if (parsed != null && parsed['name'] != null) {
            final extractedName = parsed['name'].toString().trim();
            if (extractedName.isNotEmpty) {
              print('[CNI Scanner] Extracted name (raw): $extractedName');
              // Clean the name to remove city names
              final cleanedName = _cleanExtractedName(extractedName);
              print('[CNI Scanner] Extracted name (cleaned): $cleanedName');
              // Set search controller with cleaned name
              _searchController.text = cleanedName;
              print(
                  '[CNI Scanner] Searching for patient by name: $cleanedName');
              // Automatically search for patient by OCR text
              _checkPatientWithOcrData(parsed);
            } else {
              _showErrorSnackBar('Could not extract name from CNI card');
            }
          } else {
            print(
                '[CNI Scanner] ⚠ No parsed data or name found in OCR response');
            if (parsed != null) {
              print('[CNI Scanner] Parsed data keys: ${parsed.keys}');
            }
            _showErrorSnackBar('Could not extract information from CNI card');
          }
        },
        failure: (message) {
          print('[CNI Scanner] ✗ OCR extraction failed: $message');
          _showErrorSnackBar('Failed to extract CNI information: $message');
        },
      );
    } catch (e, stackTrace) {
      print('[CNI Scanner] ✗ Exception occurred: $e');
      print('[CNI Scanner] Stack trace: $stackTrace');
      setState(() {
        _isScanningId = false;
      });
      _showErrorSnackBar('Error scanning CNI card: $e');
    }
  }

  /// Check patient with OCR extracted data
  /// Search patient by CNI number only (most reliable identifier)
  /// If CNI is not found, create a new patient instead of falling back to name search
  /// This prevents matching wrong patients when face recognition finds a different person
  Future<void> _checkPatientWithOcrData(Map<String, dynamic> ocrData) async {
    setState(() {
      _isCheckingPatient = true;
    });

    List<PatientModel>? foundPatients;

    // Only search by CNI number - the most reliable unique identifier
    // DO NOT fall back to name search as it can match wrong patients
    if (ocrData['cni_number'] != null) {
      final cniNumber = ocrData['cni_number'].toString().trim().toUpperCase();
      if (cniNumber.length >= 2) {
        print('[CNI Scanner] Searching by CNI number: $cniNumber');
        final cniResult = await ref.read(
          findPatientsProvider(cniNumber).future,
        );

        cniResult.when(
          success: (patients) {
            if (patients.isNotEmpty) {
              foundPatients = patients;
              print(
                  '[CNI Scanner] ✓ Found ${patients.length} patient(s) by CNI number');
            } else {
              print('[CNI Scanner] ✗ No patient found by CNI number');
              print('[CNI Scanner]   - Will create new patient (not searching by name to avoid wrong matches)');
            }
          },
          failure: (message) {
            print('[CNI Scanner] ✗ CNI search failed: $message');
            print('[CNI Scanner]   - Will create new patient (not searching by name to avoid wrong matches)');
          },
        );
      } else {
        print('[CNI Scanner] ⚠ CNI number too short or invalid: $cniNumber');
        print('[CNI Scanner]   - Will create new patient');
      }
    } else {
      print('[CNI Scanner] ⚠ No CNI number found in OCR data');
      print('[CNI Scanner]   - Will create new patient');
    }

    setState(() {
      _isCheckingPatient = false;
    });

    // Process results
    final patients = foundPatients ?? [];

    if (patients.isEmpty) {
      // Patient not found by CNI - use OCR data and move to new patient step
      // DO NOT search by name as it can match wrong patients (e.g., face recognition matches)
      print('[CNI Scanner] ✓ Patient search completed: No patient found by CNI');
      print(
          '[CNI Scanner]   - Searched by CNI: ${ocrData['cni_number'] ?? 'N/A'}');
      print('[CNI Scanner]   - Will create new patient with OCR data');
      setState(() {
        _patientExists = false;
        _currentStep = AppointmentStep.newPatient;
      });

      // Populate fields with OCR data
      if (ocrData['name'] != null) {
        _nameController.text = ocrData['name'].toString();
        print('[CNI Scanner] ✓ Name populated: ${ocrData['name']}');
      }
      // Set default email when patient not found
      _emailController.text = 'noemail@patient.com';
      if (ocrData['birthdate'] != null) {
        _birthdateController.text = ocrData['birthdate'].toString();
        _calculateAge();
        print('[CNI Scanner] ✓ Birthdate populated: ${ocrData['birthdate']}');
      }
      if (ocrData['address'] != null) {
        _addressController.text = ocrData['address'].toString();
        print('[CNI Scanner] ✓ Address populated: ${ocrData['address']}');
      }
      if (ocrData['cni_number'] != null) {
        _cniController.text = ocrData['cni_number'].toString();
        print('[CNI Scanner] ✓ CNI number populated: ${ocrData['cni_number']}');
      }

      _animationController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✓ Patient not found. Form filled with CNI data for: ${ocrData['name'] ?? 'new patient'}'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (patients.length == 1) {
      // Single patient found - select it
      print('[CNI Scanner] Patient found, selecting patient');
      _selectPatient(patients.first);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Patient found and selected'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Multiple patients found - show selection
      print('[CNI Scanner] Multiple patients found');
      setState(() {
        _patientExists = true;
        _foundPatients = patients;
        _currentStep = AppointmentStep.select;
      });
      _animationController.forward(from: 0.0);
    }
  }

  Future<void> _scanCniCard() async {
    print('[CNI Scanner] ==========================================');
    print('[CNI Scanner] Starting CNI card scanning...');

    try {
      // Use face detection camera for automatic capture
      print('[CNI Scanner] Opening face detection camera...');
      File? capturedImage;

      if (kIsWeb) {
        // Web: fallback to regular image picker
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (image == null) {
          print('[CNI Scanner] ✗ User cancelled camera capture');
          print('[CNI Scanner] ==========================================');
          return;
        }
        capturedImage = File(image.path);
      } else {
        // Mobile: use face detection camera
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FaceDetectionCamera(
              onImageCaptured: (File image) {
                capturedImage = image;
              },
              onCancel: () {
                print('[CNI Scanner] ✗ User cancelled camera capture');
              },
            ),
          ),
        );

        if (capturedImage == null) {
          print('[CNI Scanner] ✗ No image captured');
          print('[CNI Scanner] ==========================================');
          return;
        }
      }

      print('[CNI Scanner] ✓ Image captured successfully');
      print('[CNI Scanner] Image path: ${capturedImage!.path}');
      final originalSize = await capturedImage!.length();
      print(
          '[CNI Scanner] Original image size: $originalSize bytes (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      setState(() {
        _isScanningId = true;
        _scanResult = null;
      });
      print('[CNI Scanner] UI state updated: scanning = true');

      // Use original image without compression
      print('[CNI Scanner] Using original image without compression...');
      dynamic imageFile;
      if (kIsWeb) {
        // Web: read as bytes, use original bytes
        print('[CNI Scanner] Platform: Web - using original image bytes...');
        final originalBytes = await capturedImage!.readAsBytes();
        print(
            '[CNI Scanner] Original bytes: ${originalBytes.length} bytes (${(originalBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
        imageFile = originalBytes;
        print('[CNI Scanner] ✓ Using original image bytes (no compression)');
      } else {
        // Mobile/Desktop: use original image file
        print(
            '[CNI Scanner] Platform: Mobile/Desktop - using original image file...');
        imageFile = capturedImage!;
        print(
            '[CNI Scanner] ✓ Using original image file: ${capturedImage!.path}');
        print(
            '[CNI Scanner] Original size: $originalSize bytes (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)');
        print('[CNI Scanner] No compression applied');
      }

      // Call OCR service
      // Use the same base URL as other API calls
      print('[CNI Scanner] Calling OCR service...');
      print(
          '[CNI Scanner] Using configured API base URL (same as other API calls)');

      // Get OCR service from provider (uses shared ApiClient with auth token)
      final ocrService = ref.read(ocrServiceProvider);

      final startTime = DateTime.now();
      final result = await ocrService.extractMoroccanId(
        imageFile,
        extractFace: _extractFaceId,
      );
      final duration = DateTime.now().difference(startTime);

      print(
          '[CNI Scanner] OCR service completed in ${duration.inMilliseconds}ms');

      result.when(
        success: (data) {
          print('[CNI Scanner] ✓ OCR extraction successful!');
          print('[CNI Scanner] Response data type: ${data.runtimeType}');
          if (data is Map) {
            print('[CNI Scanner] Response data keys: ${data.keys.toList()}');
          }

          setState(() {
            _scanResult = data;
            _isScanningId = false;
          });
          print(
              '[CNI Scanner] UI state updated: scanning = false, result stored');

          // Parse and populate form fields - safely extract parsed data
          Map<String, dynamic>? parsed;
          if (data is Map) {
            final parsedValue = data['parsed'];
            if (parsedValue is Map) {
              parsed = Map<String, dynamic>.from(parsedValue);
            } else {
              print(
                  '[CNI Scanner] ⚠ Parsed data is not a Map: ${parsedValue?.runtimeType ?? 'null'}');
            }
          }
          if (parsed != null) {
            print('[CNI Scanner] Parsing extracted data...');
            print('[CNI Scanner] Parsed data: $parsed');

            // Populate CNI number (always populate if found, even if field has value)
            if (parsed['cni_number'] != null) {
              final extractedCni = parsed['cni_number'].toString().trim();
              if (extractedCni.isNotEmpty) {
                _cniController.text = extractedCni;
                print(
                    '[CNI Scanner] ✓ CNI number populated: ${parsed['cni_number']}');
                print(
                    '[CNI Scanner] CNI number field value after population: "${_cniController.text}"');
              } else {
                print('[CNI Scanner] ⚠ CNI number is empty, not populating');
              }
            } else {
              print('[CNI Scanner] ⚠ No CNI number found in parsed data');
            }

            // Populate birthdate
            if (parsed['birthdate'] != null &&
                _birthdateController.text.isEmpty) {
              _birthdateController.text = parsed['birthdate'].toString();
              print(
                  '[CNI Scanner] ✓ Birthdate populated: ${parsed['birthdate']}');
              _calculateAge();
              print('[CNI Scanner] ✓ Age calculated: $_calculatedAge');
            } else if (parsed['birthdate'] != null) {
              print(
                  '[CNI Scanner] ⚠ Birthdate not populated (field already has value)');
            }

            // Populate name (always populate if found, even if field has value)
            if (parsed['name'] != null) {
              final extractedName = parsed['name'].toString().trim();
              if (extractedName.isNotEmpty) {
                // Clean the name to remove city names
                final cleanedName = _cleanExtractedName(extractedName);
                _nameController.text = cleanedName;
                print(
                    '[CNI Scanner] ✓ Name populated (raw: ${parsed['name']}, cleaned: $cleanedName)');
                print(
                    '[CNI Scanner] Name field value after population: "${_nameController.text}"');
              } else {
                print('[CNI Scanner] ⚠ Name is empty, not populating');
              }
            } else {
              print('[CNI Scanner] ⚠ No name found in parsed data');
            }

            // Populate address (always populate if found, even if field has value)
            if (parsed['address'] != null) {
              final extractedAddress = parsed['address'].toString().trim();
              if (extractedAddress.isNotEmpty) {
                _addressController.text = extractedAddress;
                print(
                    '[CNI Scanner] ✓ Address populated: ${parsed['address']}');
                print(
                    '[CNI Scanner] Address field value after population: "${_addressController.text}"');
              } else {
                print('[CNI Scanner] ⚠ Address is empty, not populating');
              }
            } else {
              print('[CNI Scanner] ⚠ No address found in parsed data');
            }
          } else {
            print('[CNI Scanner] ⚠ No parsed data in response');
          }

          // Store face recognition data if available - safely extract
          Map<String, dynamic>? faceRecognition;
          if (data is Map) {
            final faceRecognitionValue = data['face_recognition'];
            if (faceRecognitionValue != null && faceRecognitionValue is Map) {
              faceRecognition = Map<String, dynamic>.from(faceRecognitionValue);
            }
          }
          if (faceRecognition != null) {
            final faceData = faceRecognition;
            setState(() {
              _facePhotoPath = faceData['photo_path'] as String?;
              _faceEmbedding = faceData['face_embedding'] as String?;
            });
            print('[CNI Scanner] ✓ Face recognition data stored');
            print('[CNI Scanner]   - Photo path: $_facePhotoPath');
            print(
                '[CNI Scanner]   - Has duplicate: ${faceData['has_duplicate'] ?? false}');

            // Check if validation failed (face match found but text doesn't match)
            if (faceData['match_validation_failed'] == true) {
              final similarPatients = faceData['similar_patients'] as List?;
              if (similarPatients != null && similarPatients.isNotEmpty) {
                final bestMatch = similarPatients[0] as Map<String, dynamic>;
                final patientName = bestMatch['name'] ?? 'Unknown';
                final similarity = bestMatch['similarity'] ?? 0.0;

                print('[CNI Scanner] ⚠ Face match found but validation failed');
                print('[CNI Scanner]   - Matched patient: $patientName');
                print('[CNI Scanner]   - Similarity: $similarity');
                print(
                    '[CNI Scanner]   - Reasons: ${faceData['validation_reasons']}');

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '⚠️ Face match found ($patientName) but ID card data doesn\'t match. Using ID card information...'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
                // Continue to use OCR text - don't auto-select face match
              }
            }

            // Handle matched_patient - if a patient is directly matched and validated, select it automatically
            if (faceData['matched_patient'] != null &&
                faceData['match_validation_failed'] != true) {
              try {
                final matchedPatientData =
                    faceData['matched_patient'] as Map<String, dynamic>;
                final matchedPatient =
                    PatientModel.fromJson(matchedPatientData);
                print(
                    '[CNI Scanner] ✓ Matched patient found and validated via face recognition: ${matchedPatient.user?.name}');
                _selectPatient(matchedPatient);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Patient matched and selected via face recognition'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return; // Exit early since patient is already selected
              } catch (e) {
                print('[CNI Scanner] ✗ Error parsing matched_patient: $e');
              }
            }

            // Handle face search - if similar patients found, offer to search for them
            if (faceData['has_duplicate'] == true) {
              final similarPatients = faceData['similar_patients'] as List?;
              if (similarPatients != null && similarPatients.isNotEmpty) {
                final similarPatient =
                    similarPatients[0] as Map<String, dynamic>;
                final patientName = similarPatient['name'] ?? 'Unknown';
                final similarity = similarPatient['similarity'] ?? 0.0;

                // Extract patient information
                final userData =
                    similarPatient['user'] as Map<String, dynamic>?;
                final email = userData?['email'] ?? similarPatient['email'];
                final phone = similarPatient['phone_number'] ??
                    similarPatient['phone'] ??
                    userData?['phone'];
                final photoUrl = similarPatient['photo_url'] ??
                    similarPatient['photo_path'] ??
                    userData?['photo_url'];

                print(
                    '[CNI Scanner] ⚠ Duplicate patient detected via face recognition: $patientName (similarity: $similarity)');

                // Show dialog to search for similar patient
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.face_rounded, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        const Text('Similar Patient Found'),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Face recognition detected a similar patient:',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          // Patient Photo and Info Container
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Patient Photo
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _buildSimilarPatientAvatar(
                                      photoUrl,
                                      patientName,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Patient Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        patientName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Similarity: ${(similarity * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (email != null &&
                                          email.toString().isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email_outlined,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                email.toString(),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (phone != null &&
                                          phone.toString().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone_outlined,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                phone.toString(),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Would you like to search for this patient?',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('No, Continue'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Search for the patient by name
                          _searchController.text = patientName;
                          _checkPatient();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Yes, Search'),
                      ),
                    ],
                  ),
                );
              }
            }
          } else {
            print('[CNI Scanner] ⚠ No face recognition data in response');
            setState(() {
              _facePhotoPath = null;
              _faceEmbedding = null;
            });
          }

          // Show success message
          print('[CNI Scanner] Showing success message to user');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('CNI information extracted successfully'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          print('[CNI Scanner] ==========================================');
        },
        failure: (message) {
          print('[CNI Scanner] ✗ OCR extraction failed');
          print('[CNI Scanner] Error message: $message');

          setState(() {
            _isScanningId = false;
          });
          print('[CNI Scanner] UI state updated: scanning = false');

          print('[CNI Scanner] Showing error message to user');
          _showErrorSnackBar(message);
          print('[CNI Scanner] ==========================================');
        },
      );
    } catch (e, stackTrace) {
      print('[CNI Scanner] ✗ Exception occurred during scanning');
      print('[CNI Scanner] Error: $e');
      print('[CNI Scanner] Stack trace: $stackTrace');

      setState(() {
        _isScanningId = false;
      });
      print('[CNI Scanner] UI state updated: scanning = false');

      print('[CNI Scanner] Showing error message to user');
      _showErrorSnackBar('Failed to scan CNI: ${e.toString()}');
      print('[CNI Scanner] ==========================================');
    }
  }

  ServiceModel? _findSelectedService() {
    if (_selectedServiceId == null) return null;
    try {
      return _servicesCache.firstWhere(
        (service) => service.id?.toString() == _selectedServiceId,
      );
    } catch (_) {
      return null;
    }
  }

  void _prefillInvoiceAmountFromService({ServiceModel? service}) {
    final selectedService = service ?? _findSelectedService();
    final servicePrice = selectedService?.price;

    if (servicePrice != null &&
        _generateInvoice &&
        _addInvoiceAmount &&
        (_invoiceAmountController.text.isEmpty ||
            _invoiceAmountController.text == '0')) {
      _invoiceAmountController.text = servicePrice.toStringAsFixed(2);
    }
  }

  Future<void> _showAddServiceModal(BuildContext context) async {
    final createdService = await AddServiceModal.show(context, ref);

    if (createdService != null && createdService.id != null) {
      // Refresh services list
      ref.invalidate(servicesProvider);

      // Wait a bit for the refresh to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the updated services
      final servicesResult = await ref.read(servicesProvider.future);

      servicesResult.when(
        success: (services) {
          // Find the newly created service and select it
          final newService = services.firstWhere(
            (service) => service.id == createdService.id,
            orElse: () => createdService,
          );

          setState(() {
            _selectedServiceId = newService.id?.toString();
            _servicesCache = services;
          });

          // Prefill invoice amount if needed
          _prefillInvoiceAmountFromService(service: newService);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Service "${newService.title}" created and selected'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        failure: (message) {
          // Even if refresh fails, try to use the created service
          setState(() {
            _selectedServiceId = createdService.id?.toString();
          });
          _prefillInvoiceAmountFromService(service: createdService);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Service created but failed to refresh list: $message'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );
    }
  }

  Future<void> _createAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDoctorId == null ||
        _selectedServiceId == null ||
        _appointmentDate == null ||
        _selectedTime == null) {
      final localizations = AppLocalizations.of(context);
      _showErrorSnackBar('Please fill all required fields'
          'Please fill all required fields');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    final normalizedTime = _normalizeTime(_selectedTime);

    final appointmentData = <String, dynamic>{
      'doctor_id': int.parse(_selectedDoctorId!),
      'appointment_date': DateFormat('yyyy-MM-dd').format(_appointmentDate!),
      'appointment_time': normalizedTime,
      'priority': _priority,
      'status': 'scheduled',
      'service_id': int.parse(_selectedServiceId!),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'generate_invoice': _generateInvoice,
      'invoice_amount': _generateInvoice && _addInvoiceAmount
          ? (double.tryParse(_invoiceAmountController.text))
          : null,
      'mark_as_paid': _generateInvoice ? _markAsPaid : false,
      'initial_amount': _generateInvoice && _addInitialAmount && !_markAsPaid
          ? (double.tryParse(_initialAmountController.text))
          : null,
      'send_whatsapp_notification': _sendWhatsAppNotification,
      'send_email_notification': _sendEmailNotification,
    };

    if (_patientExists && _selectedPatient != null) {
      appointmentData['patient_id'] = _selectedPatient!.id;
    } else {
      appointmentData['patient'] = {
        'email': _emailController.text.trim().isEmpty
            ? 'noemail@patient.com'
            : _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'gender': _gender,
        'birthdate': _birthdateController.text.trim().isEmpty
            ? null
            : _birthdateController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'blood_type': _bloodType,
        'cni_number': _cniController.text.trim().isEmpty
            ? null
            : _cniController.text.trim(),
        'insurance_number': _insuranceNumberController.text.trim().isEmpty
            ? null
            : _insuranceNumberController.text.trim(),
        'insurance_type': _insuranceType?.trim().isEmpty ?? true
            ? null
            : _insuranceType?.trim(),
        'emergency_contact_name':
            _emergencyContactNameController.text.trim().isEmpty
                ? null
                : _emergencyContactNameController.text.trim(),
        'emergency_contact_phone':
            _emergencyContactPhoneController.text.trim().isEmpty
                ? null
                : _emergencyContactPhoneController.text.trim(),
        // Include face recognition data if available and enabled
        if (_shouldRegisterFacePhoto && _facePhotoPath != null)
          'photo_path': _facePhotoPath,
        if (_shouldRegisterFacePhoto && _faceEmbedding != null)
          'face_embedding': _faceEmbedding,
      };
    }

    final result =
        await ref.read(createAppointmentProvider(appointmentData).future);

    setState(() {
      _isSubmitting = false;
    });

    result.when(
      success: (response) {
        // Schedule local notification reminder 1 hour before appointment
        _scheduleAppointmentReminder(response);

        // Refresh dashboard data to show the new appointment
        _refreshDashboard();

        // Force sync appointments to update all appointment lists
        _forceSyncAppointments();

        _showSuccessDialog(response);
      },
      failure: (message) {
        setState(() {
          _conflictError = message;
        });
        _showErrorDialog(message);
      },
    );
  }

  /// Refresh dashboard data after appointment creation
  void _refreshDashboard() {
    try {
      final timeRange = ref.read(timeRangeProvider);
      ref.read(dashboardRefreshProvider)(timeRange);
      debugPrint('[CreateAppointmentScreen] Dashboard data refreshed');
    } catch (e) {
      debugPrint('[CreateAppointmentScreen] Error refreshing dashboard: $e');
    }
  }

  /// Force sync appointments after appointment creation
  void _forceSyncAppointments() {
    try {
      final syncService = ref.read(globalAppointmentSyncProvider);
      syncService.forceSync(ref);
      debugPrint('[CreateAppointmentScreen] Appointments synced');
    } catch (e) {
      debugPrint('[CreateAppointmentScreen] Error syncing appointments: $e');
    }
  }

  /// Schedule local notification reminder 1 hour before appointment
  /// Or show immediate notification if appointment is less than 1 hour away
  Future<void> _scheduleAppointmentReminder(
      AppointmentResponseModel response) async {
    try {
      final helper = AppointmentNotificationHelper();
      final appointment = response.appointment;

      // Check if appointment is less than 1 hour away
      if (appointment.appointmentDate != null &&
          appointment.appointmentTime != null) {
        final appointmentDateTime = _parseAppointmentDateTime(
          appointment.appointmentDate!,
          appointment.appointmentTime!,
        );

        if (appointmentDateTime != null) {
          final timeUntil = appointmentDateTime.difference(DateTime.now());

          // If less than 1 hour away, show immediate notification
          if (timeUntil.inHours < 1 && timeUntil.inMinutes > 0) {
            await helper.notifyPatientAppointmentSoon(appointment);
          } else if (timeUntil.inHours >= 1) {
            // If more than 1 hour away, schedule reminder
            await helper.scheduleAppointmentReminder(
              appointment: appointment,
              reminderBefore: const Duration(hours: 1),
            );
          }
        }
      }

      // Also notify doctor about new appointment (if current user is admin/receptionist)
      final authState = ref.read(authProvider);
      if (authState.user?.isAdmin == 1 || authState.user?.isReceptionist == 1) {
        await helper.notifyDoctorNewAppointment(appointment);
      }

      // Notify patient if they have an account (confirmation)
      if (appointment.patient?.user != null) {
        await helper.notifyPatientAppointmentConfirmed(appointment);
      }
    } catch (e) {
      debugPrint('[CreateAppointmentScreen] Error scheduling reminder: $e');
      // Don't show error to user, just log it
    }
  }

  /// Parse appointment date and time strings into DateTime
  DateTime? _parseAppointmentDateTime(String dateStr, String timeStr) {
    try {
      // Parse date (format: yyyy-MM-dd)
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) {
        return null;
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Parse time (format: HH:mm or HH:mm:ss)
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) {
        return null;
      }

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('[CreateAppointmentScreen] Error parsing date/time: $e');
      return null;
    }
  }

  void _showSuccessDialog(dynamic response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                    return Text(
                      localizations?.appointmentCreated ??
                          'Appointment Created!',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              final locale = ref.watch(localeProvider).locale;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                      Icons.person_rounded,
                                      localizations?.patient ?? 'Patient',
                                      response.appointment.patient?.user
                                              ?.name ??
                                          "N/A"),
                                  _buildInfoRow(
                                      Icons.email_rounded,
                                      localizations?.email ?? 'Email',
                                      response.appointment.patient?.user
                                              ?.email ??
                                          "N/A"),
                                  if (response.appointment.patient?.phone !=
                                      null)
                                    _buildInfoRow(
                                        Icons.phone_rounded,
                                        localizations?.phone ?? 'Phone',
                                        response.appointment.patient?.phone ??
                                            ""),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                      Icons.medical_services_rounded,
                                      localizations?.doctor ?? 'Doctor',
                                      response.appointment.doctor?.user?.name ??
                                          "N/A"),
                                  if (response.appointment.appointmentDate !=
                                      null)
                                    _buildInfoRow(
                                        Icons.calendar_today_rounded,
                                        localizations?.date ?? 'Date',
                                        DateFormat(
                                                'dd/MM/yyyy', locale.toString())
                                            .format(DateTime.parse(response
                                                .appointment
                                                .appointmentDate!))),
                                  _buildInfoRow(
                                      Icons.access_time_rounded,
                                      localizations?.time ?? 'Time',
                                      response.appointment.appointmentTime ??
                                          "N/A"),
                                  if (response.invoice != null) ...[
                                    const Divider(height: 24),
                                    _buildInfoRow(
                                        Icons.receipt_rounded,
                                        localizations?.invoice ?? 'Invoice',
                                        '#${response.invoice!['id']}'),
                                    _buildInfoRow(
                                        Icons.attach_money_rounded,
                                        localizations?.amount ?? 'Amount',
                                        '${response.invoice!['amount']} MAD'),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations?.close ?? 'Close',
                          style: const TextStyle(fontSize: 16),
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
                  return Text(
                    localizations?.error ?? 'Error',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
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
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.ok ?? 'OK',
                        style: const TextStyle(fontSize: 16),
                      );
                    },
                  ),
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

  String? _normalizeTime(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return time;
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
            return Text(
              localizations?.newAppointment ?? 'New Appointment',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernProgressSteps(),
                const SizedBox(height: 32),
                if (_currentStep == AppointmentStep.check) _buildCheckStep(),
                if (_currentStep == AppointmentStep.select) _buildSelectStep(),
                if (_currentStep == AppointmentStep.newPatient)
                  _buildNewPatientStep(),
                if (_currentStep == AppointmentStep.appointment)
                  _buildAppointmentStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernProgressSteps() {
    final localizations = AppLocalizations.of(context);
    final steps = [
      {
        'icon': Icons.search_rounded,
        'title': localizations?.search ?? 'Search'
      },
      {'icon': Icons.person_rounded, 'title': 'Patient'},
      {'icon': Icons.event_rounded, 'title': 'Appointment'},
    ];

    final currentIndex = _getStepIndex(_currentStep);

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

  int _getStepIndex(AppointmentStep step) {
    switch (step) {
      case AppointmentStep.check:
        return 0;
      case AppointmentStep.select:
      case AppointmentStep.newPatient:
        return 1;
      case AppointmentStep.appointment:
        return 2;
    }
  }

  Widget _buildCheckStep() {
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
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations?.enterPatientName ??
                              'Enter Patient Name',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          localizations?.enterPatientNameDescription ??
                              'Enter patient name, email or CNI number',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: localizations?.patientName ?? 'Patient Name',
                  hintText: localizations?.enterPatientNameHint ??
                      'Enter patient name, email or CNI',
                  prefixIcon: const Icon(Icons.person_rounded),
                  filled: true,
                  fillColor:
                      isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 2) {
                    return localizations?.atLeast2CharactersRequired ??
                        'At least 2 characters required';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 20),
          // OCR Scan Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan CNI Card',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan CNI to auto-search patient',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Checkbox for face extraction option
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _extractFaceId,
                        onChanged: (_isScanningId || _isCheckingPatient)
                            ? null
                            : (value) {
                                setState(() {
                                  _extractFaceId = value ?? true;
                                });
                              },
                        activeColor: Colors.blue,
                      ),
                      Expanded(
                        child: Text(
                          'Extract face ID (for duplicate detection)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isScanningId || _isCheckingPatient)
                        ? null
                        : _scanCniCardForSearch,
                    icon: _isScanningId
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label:
                        Text(_isScanningId ? 'Scanning...' : 'Scan CNI Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCheckingPatient ? null : _checkPatient,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isCheckingPatient
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_rounded),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              localizations?.findPatient ?? 'Find Patient',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              '${'Patients Found'} (${_foundPatients.length})',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            );
          },
        ),
        const SizedBox(height: 16),
        ..._foundPatients.map((patient) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                    if (patient.user?.email != null &&
                        patient.user!.email!.isNotEmpty)
                      Text(patient.user!.email!),
                    if (patient.phone != null ||
                        patient.phoneNumber != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(patient.phone ?? patient.phoneNumber ?? ''),
                        ],
                      ),
                    ],
                    if (patient.cniNumber != null &&
                        patient.cniNumber!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('CNI: ${patient.cniNumber}'),
                        ],
                      ),
                    ],
                    if (patient.birthdate != null) ...[
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${patient.calculateAge()} ${localizations?.years ?? 'years'}',
                          );
                        },
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onTap: () => _selectPatient(patient),
              ),
            )),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = AppointmentStep.check;
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
                    return Text(localizations?.back ?? 'Back');
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _patientExists = false;
                    _currentStep = AppointmentStep.newPatient;
                    _nameController.text = _searchController.text;
                    _emailController.text = _searchController.text.contains('@')
                        ? _searchController.text
                        : 'noemail@patient.com';
                  });
                  _animationController.forward(from: 0.0);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(localizations?.newPatient ?? 'New Patient');
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewPatientStep() {
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
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                'New Patient',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              );
            },
          ),
          const SizedBox(height: 24),
          // CNI Scanning Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.indigo.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Moroccan CNI Card',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Take a photo to auto-fill name, CNI number, and birthdate',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Checkbox for face extraction option
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _extractFaceId,
                        onChanged: _isScanningId
                            ? null
                            : (value) {
                                setState(() {
                                  _extractFaceId = value ?? true;
                                });
                              },
                        activeColor: Colors.blue,
                      ),
                      Expanded(
                        child: Text(
                          'Extract face ID (for duplicate detection)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isScanningId ? null : _scanCniCard,
                    icon: _isScanningId
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      _isScanningId ? 'Scanning...' : 'Take Photo',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_scanResult != null && _scanResult!['parsed'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'CNI information extracted successfully',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Display face image if available
                  if (_facePhotoPath != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.face_rounded,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Face Extracted from ID Card',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AuthenticatedImage(
                                photoUrl: _facePhotoPath,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                fallback: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.face_rounded, size: 48, color: Colors.grey[400]),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Material(
                            color: Colors.transparent,
                            child: _buildModernCheckbox(
                              value: _shouldRegisterFacePhoto,
                              title: 'Register face photo with patient profile',
                              icon: Icons.person_add_alt_1_rounded,
                              onChanged: (value) {
                                setState(() {
                                  _shouldRegisterFacePhoto = value ?? true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_scanResult!['parsed']?['cni_number'] != null)
                        Chip(
                          label: Text(
                            'CNI: ${_scanResult!['parsed']['cni_number']}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      if (_scanResult!['parsed']?['name'] != null)
                        Chip(
                          label: Text(
                            'Name: ${_scanResult!['parsed']['name']}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      if (_scanResult!['parsed']?['birthdate'] != null)
                        Chip(
                          label: Text(
                            'Birthdate: ${_scanResult!['parsed']['birthdate']}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _nameController,
                label: localizations?.fullName ?? 'Full Name',
                icon: Icons.person_rounded,
                required: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations?.nameRequired ?? 'Name is required';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _emailController,
                label: localizations?.email ?? 'Email',
                icon: Icons.email_rounded,
                required: true,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _phoneController,
                label: localizations?.phone ?? 'Phone',
                icon: Icons.phone_rounded,
                required: true,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _birthdateController,
                label: localizations?.birthDate ?? 'Birthdate',
                icon: Icons.cake_rounded,
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().subtract(const Duration(days: 365 * 30)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    _birthdateController.text =
                        DateFormat('yyyy-MM-dd').format(date);
                    _calculateAge();
                  }
                },
              );
            },
          ),
          if (_calculatedAge != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        '${'Calculated Age'}: $_calculatedAge ${'years'}',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return _buildModernDropdown(
                value: _gender,
                label: localizations?.gender ?? 'Gender',
                icon: Icons.wc_rounded,
                items: [
                  DropdownMenuItem(
                    value: 'male',
                    child: Text(
                      localizations?.male ?? 'Male',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'female',
                    child: Text(
                      localizations?.female ?? 'Female',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _addressController,
                label: localizations?.address ?? 'Address',
                icon: Icons.location_on_rounded,
                maxLines: 2,
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _cniController,
                label: localizations?.cniNumber ?? 'CNI Number',
                icon: Icons.badge_rounded,
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return _buildModernDropdown(
                value: _insuranceType,
                label: localizations?.insuranceType ?? 'Insurance Type',
                icon: Icons.health_and_safety_rounded,
                items: INSURANCE_OPTIONS.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _insuranceType = value;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _insuranceNumberController,
                label: localizations?.insuranceNumber ?? 'Insurance Number',
                icon: Icons.numbers_rounded,
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = AppointmentStep.check;
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
                      return Text(localizations?.back ?? 'Back');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _currentStep = AppointmentStep.appointment;
                      });
                      _animationController.forward(from: 0.0);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue' 'Continue',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctorsAsync = ref.watch(doctorsProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final timeSlotsAsync = _selectedDoctorId != null && _appointmentDate != null
        ? ref.watch(
            timeSlotsProvider(
              TimeSlotsParams(
                doctorId: int.parse(_selectedDoctorId!),
                date: DateFormat('yyyy-MM-dd').format(_appointmentDate!),
              ),
            ),
          )
        : null;

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
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                'Appointment Details',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_patientExists && _selectedPatient != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
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
              child: Column(
                children: [
                  // Patient info row
                  Row(
                    children: [
                      // Patient Photo with Check Badge
                      Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildSelectedPatientAvatar(
                                  _selectedPatient!),
                            ),
                          ),
                          // Check badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Patient Selected',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedPatient!.user?.name ?? "N/A",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (_selectedPatient!.user?.email != null &&
                                _selectedPatient!.user!.email!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _selectedPatient!.user!.email!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if ((_selectedPatient!.phone != null &&
                                    _selectedPatient!.phone!.isNotEmpty) ||
                                (_selectedPatient!.phoneNumber != null &&
                                    _selectedPatient!
                                        .phoneNumber!.isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _selectedPatient!.phoneNumber ??
                                          _selectedPatient!.phone ??
                                          '',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_selectedPatient!.cniNumber != null &&
                                _selectedPatient!.cniNumber!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'CNI: ${_selectedPatient!.cniNumber}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // "Not this patient?" button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Reset patient selection and go back to search
                        setState(() {
                          _selectedPatient = null;
                          _patientExists = false;
                          _currentStep = AppointmentStep.check;
                          _searchController.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Patient selection cleared. You can search again or add manually.'),
                            backgroundColor: Colors.blue,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                        foregroundColor: Colors.orange[700],
                      ),
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_remove_outlined,
                                  size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  localizations?.notThisPatient ??
                                      'Not this patient? Search again or add manually',
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_conflictError != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_rounded, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _conflictError!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          doctorsAsync.when(
            data: (result) => result.when(
              success: (doctors) => Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildModernDropdown(
                    value: _selectedDoctorId,
                    label: localizations?.doctor ?? 'Doctor',
                    icon: Icons.medical_services_rounded,
                    required: true,
                    items: doctors.map((doctor) {
                      final doctorName = doctor.user?.name ?? "N/A";
                      final specialization =
                          doctor.specialization ?? doctor.specialty ?? "N/A";
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return DropdownMenuItem(
                        value: doctor.id.toString(),
                        child: Text(
                          '$doctorName - $specialization',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDoctorId = value;
                        _selectedTime = null;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Doctor is required';
                      }
                      return null;
                    },
                  );
                },
              ),
              failure: (message) => Text('Erreur: $message',
                  style: const TextStyle(color: Colors.red)),
            ),
            loading: () => const LoadingWidget(),
            error: (error, stack) =>
                CustomErrorWidget(message: error.toString()),
          ),
          const SizedBox(height: 16),
          servicesAsync.when(
            data: (result) => result.when(
              success: (services) => Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  _servicesCache = services;
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernDropdown(
                              value: _selectedServiceId,
                              label: localizations?.service ?? 'Service',
                              icon: Icons.medical_information_rounded,
                              required: true,
                              items: services.map((service) {
                                final price = service.price ?? 0.0;
                                return DropdownMenuItem(
                                  value: service.id.toString(),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          service.title ?? 'N/A',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '${price.toStringAsFixed(2)} MAD',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedServiceId = value;
                                });
                                ServiceModel? selectedService;
                                try {
                                  selectedService = services.firstWhere(
                                    (service) =>
                                        service.id?.toString() == value,
                                  );
                                } catch (_) {
                                  selectedService = null;
                                }
                                _prefillInvoiceAmountFromService(
                                  service: selectedService,
                                );
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Service is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.add_circle_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _showAddServiceModal(context),
                              tooltip: 'Add New Service',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddServiceModal(context),
                        icon: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          'Add New Service',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              failure: (message) => Text('Erreur: $message',
                  style: const TextStyle(color: Colors.red)),
            ),
            loading: () => const LoadingWidget(),
            error: (error, stack) =>
                CustomErrorWidget(message: error.toString()),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              final locale = ref.watch(localeProvider).locale;
              return _buildModernTextField(
                controller: TextEditingController(
                  text: _appointmentDate != null
                      ? DateFormat('dd/MM/yyyy', locale.toString())
                          .format(_appointmentDate!)
                      : '',
                ),
                label: localizations?.date ?? 'Date',
                icon: Icons.calendar_today_rounded,
                required: true,
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _appointmentDate = date;
                      _selectedTime = null;
                    });
                  }
                },
                validator: (value) {
                  if (_appointmentDate == null) {
                    return 'Date is required';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedDoctorId != null && _appointmentDate != null) ...[
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.availableTimeSlots ?? 'Available Time Slots',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                );
              },
            ),
            const SizedBox(height: 12),
            timeSlotsAsync != null
                ? timeSlotsAsync.when(
                    data: (result) => result.when(
                      success: (timeSlots) => timeSlots.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_rounded,
                                      color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final localizations =
                                            AppLocalizations.of(context);
                                        return Text(
                                          localizations?.noTimeSlotsAvailable ??
                                              'No time slots available for this date',
                                          style: const TextStyle(
                                              color: Colors.orange),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                              ),
                              child: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: timeSlots.map((slot) {
                                    final isSelected =
                                        _selectedTime == slot.time;
                                    final isAvailable = slot.available;
                                    return InkWell(
                                      onTap: isAvailable
                                          ? () {
                                              setState(() {
                                                _selectedTime = slot.time;
                                              });
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? (isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.green
                                                      .withOpacity(0.1))
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isAvailable
                                                ? (isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.green)
                                                : Colors.red,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          slot.time,
                                          style: TextStyle(
                                            color: isAvailable
                                                ? (isSelected
                                                    ? Colors.white
                                                    : Colors.green)
                                                : Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                      failure: (message) => Text('Erreur: $message',
                          style: const TextStyle(color: Colors.red)),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        CustomErrorWidget(message: error.toString()),
                  )
                : const SizedBox(),
            const SizedBox(height: 16),
          ],
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: TextEditingController(text: _selectedTime ?? ''),
                label: localizations?.time ?? 'Time',
                icon: Icons.access_time_rounded,
                required: true,
                readOnly: true,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _selectedTime =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                validator: (value) {
                  if (_selectedTime == null || _selectedTime!.isEmpty) {
                    return 'Time is required';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return _buildModernDropdown(
                value: _priority,
                label: localizations?.priority ?? 'Priority',
                icon: Icons.priority_high_rounded,
                required: true,
                items: [
                  DropdownMenuItem(
                      value: 'high',
                      child: Row(children: [
                        const Text('🔴'),
                        const SizedBox(width: 8),
                        Text(
                          localizations?.highPriority ?? 'High',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      ])),
                  DropdownMenuItem(
                      value: 'medium',
                      child: Row(children: [
                        const Text('🟡'),
                        const SizedBox(width: 8),
                        Text(
                          localizations?.mediumPriority ?? 'Medium',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      ])),
                  DropdownMenuItem(
                      value: 'low',
                      child: Row(children: [
                        const Text('🟢'),
                        const SizedBox(width: 8),
                        Text(
                          localizations?.lowPriority ?? 'Low',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      ])),
                ],
                onChanged: (value) {
                  setState(() {
                    _priority = value ?? 'medium';
                  });
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildSectionHeader(
                  localizations?.billingOptions ?? 'Billing Options',
                  Icons.receipt_long_rounded);
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernCheckbox(
                value: _generateInvoice,
                title: localizations?.generateInvoice ?? 'Generate Invoice',
                onChanged: (value) {
                  setState(() {
                    _generateInvoice = value ?? false;
                    if (!_generateInvoice) {
                      _addInvoiceAmount = false;
                      _markAsPaid = false;
                      _addInitialAmount = false;
                      _invoiceAmountController.clear();
                      _initialAmountController.clear();
                    }
                  });
                  if (value == true) {
                    _prefillInvoiceAmountFromService();
                  }
                },
              );
            },
          ),
          if (_generateInvoice) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return _buildModernCheckbox(
                  value: _addInvoiceAmount,
                  title: localizations?.addAmount ?? 'Add Amount',
                  onChanged: (value) {
                    setState(() {
                      _addInvoiceAmount = value ?? false;
                      if (!_addInvoiceAmount) {
                        _invoiceAmountController.clear();
                      }
                    });
                    if (value == true) {
                      _prefillInvoiceAmountFromService();
                    }
                  },
                );
              },
            ),
            if (_addInvoiceAmount) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildModernTextField(
                    controller: _invoiceAmountController,
                    label: '${localizations?.amount ?? 'Amount'} (MAD)',
                    icon: Icons.attach_money_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_addInvoiceAmount &&
                          (value == null || value.isEmpty)) {
                        return 'Amount is required';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final selectedService = _findSelectedService();
                  final servicePrice = selectedService?.price;
                  if (servicePrice == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    'Using service price: ${servicePrice.toStringAsFixed(2)} MAD',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return _buildModernCheckbox(
                  value: _markAsPaid,
                  title: localizations?.markAsPaid ?? 'Mark as Paid',
                  onChanged: (value) {
                    setState(() {
                      _markAsPaid = value ?? false;
                      if (_markAsPaid) {
                        _addInitialAmount = false;
                      }
                    });
                  },
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildSectionHeader(
                  localizations?.notifications ?? 'Notifications',
                  Icons.notifications_rounded);
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernCheckbox(
                value: _sendWhatsAppNotification,
                title: localizations?.whatsapp ?? 'WhatsApp',
                icon: Icons.phone_android_rounded,
                onChanged: (value) {
                  setState(() {
                    _sendWhatsAppNotification = value ?? false;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernCheckbox(
                value: _sendEmailNotification,
                title: localizations?.email ?? 'Email',
                icon: Icons.email_rounded,
                onChanged: (value) {
                  setState(() {
                    _sendEmailNotification = value ?? false;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _buildModernTextField(
                controller: _notesController,
                label:
                    '${localizations?.notes ?? 'Notes'} (${localizations?.optional ?? 'Optional'})',
                icon: Icons.note_rounded,
                maxLines: 3,
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
                            _currentStep = _patientExists
                                ? AppointmentStep.check
                                : AppointmentStep.newPatient;
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
                      return Text(localizations?.back ?? 'Back');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createAppointment,
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
                      : Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  localizations?.create ?? 'Create',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarPatientAvatar(String? photoUrl, String patientName) {
    final fallback = Container(
      color: Colors.orange,
      child: Center(
        child: Text(
          (patientName.isNotEmpty ? patientName[0] : 'P').toUpperCase(),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
    return AuthenticatedImage(
      photoUrl: photoUrl,
      fit: BoxFit.cover,
      fallback: fallback,
      errorFallback: fallback,
    );
  }

  Widget _buildSelectedPatientAvatar(PatientModel patient) {
    final patientName = patient.user?.name ?? 'P';
    final fallback = Container(
      color: Colors.green,
      child: Center(
        child: Text(
          patientName[0].toUpperCase(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
    return AuthenticatedImage(
      photoUrl: patient.photoUrl,
      fit: BoxFit.cover,
      fallback: fallback,
      errorFallback: fallback,
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildModernDropdown({
    required String? value,
    required String label,
    required IconData icon,
    bool required = false,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        fontSize: 16,
        overflow: TextOverflow.ellipsis,
        color: isDark ? Colors.white : Colors.black87,
      ),
      menuMaxHeight: 300,
      iconSize: 24,
      dropdownColor: isDark ? Colors.grey[900] : Colors.white,
      iconEnabledColor: isDark ? Colors.white70 : Colors.black54,
      iconDisabledColor: isDark ? Colors.white30 : Colors.black26,
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
}
