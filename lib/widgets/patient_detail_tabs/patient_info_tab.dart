import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../data/models/patient_model.dart';
import '../../providers/patient_providers.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_providers.dart';
import '../../core/utils/result.dart';
import '../authenticated_image.dart';

class PatientInfoTab extends ConsumerStatefulWidget {
  final PatientModel patient;

  const PatientInfoTab({super.key, required this.patient});

  @override
  ConsumerState<PatientInfoTab> createState() => _PatientInfoTabState();
}

class _PatientInfoTabState extends ConsumerState<PatientInfoTab> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _birthdateController;
  late TextEditingController _addressController;
  late TextEditingController _cniController;
  late TextEditingController _insuranceNumberController;
  late TextEditingController _insuranceTypeController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactPhoneController;
  String? _gender;
  String? _bloodType;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isDeletingPhoto = false;
  bool _isGeneratingEmbedding = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController =
        TextEditingController(text: widget.patient.user?.name ?? '');
    _emailController =
        TextEditingController(text: widget.patient.user?.email ?? '');
    _phoneController = TextEditingController(
      text: widget.patient.phoneNumber ?? widget.patient.phone ?? '',
    );
    _birthdateController =
        TextEditingController(text: widget.patient.birthdate ?? '');
    _addressController =
        TextEditingController(text: widget.patient.address ?? '');
    _cniController =
        TextEditingController(text: widget.patient.cniNumber ?? '');
    _insuranceNumberController = TextEditingController(
      text: widget.patient.insuranceNumber ?? '',
    );
    _insuranceTypeController = TextEditingController(
      text: widget.patient.insuranceType ?? '',
    );
    _emergencyContactNameController = TextEditingController(
      text: widget.patient.emergencyContactName ?? '',
    );
    _emergencyContactPhoneController = TextEditingController(
      text: widget.patient.emergencyContactPhone ?? '',
    );
    _gender = widget.patient.gender;
    _bloodType = widget.patient.bloodType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdateController.dispose();
    _addressController.dispose();
    _cniController.dispose();
    _insuranceNumberController.dispose();
    _insuranceTypeController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final patientService = ref.read(patientServiceProvider);
      final patientData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'birthdate': _birthdateController.text.trim(),
        'address': _addressController.text.trim(),
        'cni_number': _cniController.text.trim(),
        'insurance_number': _insuranceNumberController.text.trim(),
        'insurance_type': _insuranceTypeController.text.trim(),
        'emergency_contact_name': _emergencyContactNameController.text.trim(),
        'emergency_contact_phone': _emergencyContactPhoneController.text.trim(),
        'gender': _gender,
        'blood_type': _bloodType,
      };

      final result = await patientService.updatePatient(
        patientId: widget.patient.id!,
        patientData: patientData,
      );

      if (result is Success<PatientModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informations du patient mises à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          ref.refresh(patientProvider(widget.patient.id!));
          setState(() => _isEditing = false);
        }
      } else if (result is Failure<PatientModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    _initializeControllers();
    setState(() => _isEditing = false);
  }

  int? _calculateAge() {
    if (widget.patient.birthdate == null) return null;
    try {
      final birth = DateTime.parse(widget.patient.birthdate!);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Non spécifié';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final age = _calculateAge();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Edit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Informations Personnelles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                if (!_isEditing)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Modifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : _cancelEdit,
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePatient,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Photo Section
            _buildPhotoSection(context),

            const SizedBox(height: 24),

            // Personal Information Section
            _buildSection(
              context,
              'Informations Personnelles',
              Icons.person_rounded,
              [
                _buildInfoField(
                  context,
                  'Nom Complet',
                  Icons.person_outline_rounded,
                  _nameController,
                  isEditable: _isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est requis';
                    }
                    return null;
                  },
                ),
                _buildInfoField(
                  context,
                  'Email',
                  Icons.email_outlined,
                  _emailController,
                  isEditable: _isEditing,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'L\'email est requis';
                    }
                    if (!value.contains('@')) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                _buildInfoField(
                  context,
                  'Téléphone',
                  Icons.phone_outlined,
                  _phoneController,
                  isEditable: _isEditing,
                  keyboardType: TextInputType.phone,
                ),
                _buildInfoField(
                  context,
                  'Date de Naissance',
                  Icons.cake_outlined,
                  _birthdateController,
                  isEditable: _isEditing,
                  onTap: _isEditing
                      ? () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _birthdateController.text.isNotEmpty
                                ? DateTime.tryParse(
                                        _birthdateController.text) ??
                                    DateTime.now()
                                : DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            _birthdateController.text =
                                DateFormat('yyyy-MM-dd').format(date);
                          }
                        }
                      : null,
                  readOnly: _isEditing,
                  suffixIcon: _isEditing ? Icons.calendar_today_rounded : null,
                ),
                if (!_isEditing && age != null)
                  _buildDisplayField(
                    context,
                    'Âge',
                    Icons.cake_rounded,
                    '$age ans',
                  ),
                _buildDropdownField(
                  context,
                  'Genre',
                  Icons.wc_rounded,
                  _gender,
                  ['male', 'female', 'other'],
                  {'male': 'Homme', 'female': 'Femme', 'other': 'Autre'},
                  isEditable: _isEditing,
                  onChanged: (value) => setState(() => _gender = value),
                ),
                _buildDropdownField(
                  context,
                  'Groupe Sanguin',
                  Icons.bloodtype_rounded,
                  _bloodType,
                  ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                  null,
                  isEditable: _isEditing,
                  onChanged: (value) => setState(() => _bloodType = value),
                ),
                _buildInfoField(
                  context,
                  'Adresse',
                  Icons.home_outlined,
                  _addressController,
                  isEditable: _isEditing,
                  maxLines: 2,
                ),
              ],
              isDark,
            ),

            const SizedBox(height: 24),

            // Insurance & Identification Section
            _buildSection(
              context,
              'Assurance & Identification',
              Icons.badge_rounded,
              [
                _buildInfoField(
                  context,
                  'Numéro CNI',
                  Icons.credit_card_outlined,
                  _cniController,
                  isEditable: _isEditing,
                ),
                _buildInfoField(
                  context,
                  'Type d\'Assurance',
                  Icons.shield_outlined,
                  _insuranceTypeController,
                  isEditable: _isEditing,
                ),
                _buildInfoField(
                  context,
                  'Numéro d\'Assurance',
                  Icons.numbers_outlined,
                  _insuranceNumberController,
                  isEditable: _isEditing,
                ),
              ],
              isDark,
            ),

            const SizedBox(height: 24),

            // Emergency Contact Section
            _buildSection(
              context,
              'Contact d\'Urgence',
              Icons.emergency_rounded,
              [
                _buildInfoField(
                  context,
                  'Nom du Contact',
                  Icons.person_add_outlined,
                  _emergencyContactNameController,
                  isEditable: _isEditing,
                ),
                _buildInfoField(
                  context,
                  'Téléphone du Contact',
                  Icons.phone_outlined,
                  _emergencyContactPhoneController,
                  isEditable: _isEditing,
                  keyboardType: TextInputType.phone,
                ),
              ],
              isDark,
            ),

            const SizedBox(height: 24),

            // Appointments Summary
            if (!_isEditing && widget.patient.appointments != null)
              _buildSection(
                context,
                'Résumé des Rendez-vous',
                Icons.calendar_today_rounded,
                [
                  _buildDisplayField(
                    context,
                    'Total des Rendez-vous',
                    Icons.event_note_rounded,
                    '${widget.patient.appointments!.length}',
                  ),
                ],
                isDark,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoField(
    BuildContext context,
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isEditable = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
    IconData? suffixIcon,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isEditable) {
      return _buildDisplayField(
        context,
        label,
        icon,
        controller.text.isEmpty ? 'Non spécifié' : controller.text,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1F1F25) : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayField(
    BuildContext context,
    String label,
    IconData icon,
    String value,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.grey[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    BuildContext context,
    String label,
    IconData icon,
    String? value,
    List<String> options,
    Map<String, String>? labels, {
    required bool isEditable,
    required Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isEditable) {
      return _buildDisplayField(
        context,
        label,
        icon,
        labels?[value] ?? value ?? 'Non spécifié',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F1F25) : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(labels?[option] ?? option),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final canManagePhoto =
        authState.user?.isAdmin == 1 || authState.user?.isDoctor == 1;
    final patient = widget.patient;

    final String? photoUrl = patient.photoUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(Icons.photo_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Photo du Patient',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: AuthenticatedImage(
                          photoUrl: photoUrl,
                          fit: BoxFit.cover,
                          fallback: Container(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Center(
                              child: Text(
                                (patient.user?.name ?? 'P')[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (canManagePhoto &&
                        (_isUploadingPhoto || _isDeletingPhoto))
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (canManagePhoto)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isUploadingPhoto || _isDeletingPhoto
                            ? null
                            : () => _pickAndUploadPhoto(),
                        icon: const Icon(Icons.photo_camera_rounded, size: 18),
                        label: Text(_isUploadingPhoto
                            ? 'Chargement...'
                            : 'Changer la photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (photoUrl != null && photoUrl.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        // Show generate embedding button if patient has photo
                        // (We'll check on the backend if embedding exists)
                        ...[
                          OutlinedButton.icon(
                            onPressed: _isUploadingPhoto ||
                                    _isDeletingPhoto ||
                                    _isGeneratingEmbedding
                                ? null
                                : () => _generateFaceEmbedding(),
                            icon: _isGeneratingEmbedding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.face_rounded, size: 18),
                            label: Text(_isGeneratingEmbedding
                                ? 'Génération...'
                                : 'Générer embedding'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        OutlinedButton.icon(
                          onPressed: _isUploadingPhoto ||
                                  _isDeletingPhoto ||
                                  _isGeneratingEmbedding
                              ? null
                              : () => _deletePhoto(),
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: Text(_isDeletingPhoto
                              ? 'Suppression...'
                              : 'Supprimer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
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
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    // Show dialog to choose source
    final String? source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Caméra'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      XFile? pickedFile;
      String fileName = '';
      
      if (source == 'camera') {
        // Use ImagePicker for camera (requires CAMERA permission, not READ_MEDIA)
        final ImagePicker picker = ImagePicker();
        pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          fileName = pickedFile.name;
        }
      } else if (source == 'gallery') {
        // Use FilePicker for gallery (no READ_MEDIA permissions needed)
        // FilePicker uses system photo picker on Android 13+ without requiring permissions
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.single;
          fileName = file.name;
          
          if (kIsWeb) {
            if (file.bytes != null) {
              // For web, create a temporary file-like object
              final bytes = file.bytes!;
              // Convert to XFile for compatibility
              pickedFile = XFile.fromData(bytes, mimeType: 'image/jpeg', name: fileName);
            }
          } else {
            if (file.path != null) {
              // For mobile, use the file path
              pickedFile = XFile(file.path!, name: fileName);
            }
          }
        }
      }

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final patientService = ref.read(patientServiceProvider);

      if (kIsWeb) {
        // For web, read as bytes
        final bytes = await pickedFile.readAsBytes();
        final result = await patientService.uploadPatientPhoto(
          patientId: widget.patient.id!,
          fileBytes: bytes,
          fileName: pickedFile.name,
        );

        if (result is Success<PatientModel>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo téléchargée avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            ref.refresh(patientProvider(widget.patient.id!));
          }
        } else if (result is Failure<PatientModel>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // For mobile/desktop, use File
        final file = File(pickedFile.path);
        final result = await patientService.uploadPatientPhoto(
          patientId: widget.patient.id!,
          file: file,
          fileName: pickedFile.name,
        );

        if (result is Success<PatientModel>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo téléchargée avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            ref.refresh(patientProvider(widget.patient.id!));
          }
        } else if (result is Failure<PatientModel>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de la photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeletingPhoto = true);

    try {
      final patientService = ref.read(patientServiceProvider);
      final result =
          await patientService.deletePatientPhoto(widget.patient.id!);

      if (result is Success<String>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo supprimée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          ref.refresh(patientProvider(widget.patient.id!));
        }
      } else if (result is Failure<String>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingPhoto = false);
      }
    }
  }

  Future<void> _generateFaceEmbedding() async {
    if (widget.patient.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if patient has a photo
    final photoUrl = widget.patient.photoUrl ?? widget.patient.photoPath;
    if (photoUrl == null || photoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient does not have a photo. Please upload a photo first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingEmbedding = true);

    try {
      final patientService = ref.read(patientServiceProvider);
      final result = await patientService.generateFaceEmbedding(widget.patient.id!);

      if (mounted) {
        setState(() => _isGeneratingEmbedding = false);

        result.when(
          success: (response) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] ?? 'Face embedding generated successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh patient data to get updated embedding
            ref.refresh(patientProvider(widget.patient.id!));
          },
          failure: (message) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $message'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingEmbedding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating face embedding: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
