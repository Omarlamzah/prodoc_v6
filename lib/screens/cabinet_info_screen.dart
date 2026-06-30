import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/tenant_website_providers.dart';
import '../data/models/tenant_website_model.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../core/config/api_constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../providers/api_providers.dart';
import 'prescription_settings_screen.dart';

class CabinetInfoScreen extends ConsumerStatefulWidget {
  const CabinetInfoScreen({super.key});

  @override
  ConsumerState<CabinetInfoScreen> createState() => _CabinetInfoScreenState();
}

class _CabinetInfoScreenState extends ConsumerState<CabinetInfoScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers for edit form
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _contactEmailController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _contactAddressController;
  late TextEditingController _googleMapsLocationController;

  // Social media controllers
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _linkedinController;
  late TextEditingController _twitterController;
  late TextEditingController _youtubeController;

  // Working hours - Map of day -> {open: time, close: time}
  Map<String, Map<String, TextEditingController>> _workHoursControllers = {};
  // Track which days are closed
  Map<String, bool> _closedDays = {};

  // Services list
  List<String> _services = [];
  final List<TextEditingController> _serviceControllers = [];
  final TextEditingController _newServiceController = TextEditingController();

  TenantWebsiteModel? _currentWebsite;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  // Selected images for upload (for mobile/desktop)
  File? _selectedLogo;
  File? _selectedFavicon;
  File? _selectedHeroImage;
  File? _selectedSeoImage;

  // Selected image bytes for upload (for web)
  Uint8List? _selectedLogoBytes;
  Uint8List? _selectedFaviconBytes;
  Uint8List? _selectedHeroImageBytes;
  Uint8List? _selectedSeoImageBytes;
  String? _selectedLogoFileName;
  String? _selectedFaviconFileName;
  String? _selectedHeroImageFileName;
  String? _selectedSeoImageFileName;

  // Uploading states
  bool _uploadingLogo = false;
  bool _uploadingFavicon = false;
  bool _uploadingHeroImage = false;
  bool _uploadingSeoImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _contactAddressController.dispose();
    _googleMapsLocationController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
    _newServiceController.dispose();
    for (var controller in _serviceControllers) {
      controller.dispose();
    }
    // Dispose working hours controllers
    for (var dayControllers in _workHoursControllers.values) {
      dayControllers['open']?.dispose();
      dayControllers['close']?.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(TenantWebsiteModel website) {
    _titleController = TextEditingController(text: website.title ?? '');
    _descriptionController =
        TextEditingController(text: website.description ?? '');
    _contactEmailController =
        TextEditingController(text: website.contactEmail ?? '');
    _contactPhoneController =
        TextEditingController(text: website.contactPhone ?? '');
    _contactAddressController =
        TextEditingController(text: website.contactAddress ?? '');
    _googleMapsLocationController =
        TextEditingController(text: website.googleMapsLocation ?? '');

    // Initialize social media links
    final socialLinks = website.parsedSocialLinks ?? {};
    _facebookController =
        TextEditingController(text: socialLinks['facebook']?.toString() ?? '');
    _instagramController =
        TextEditingController(text: socialLinks['instagram']?.toString() ?? '');
    _linkedinController =
        TextEditingController(text: socialLinks['linkedin']?.toString() ?? '');
    _twitterController = TextEditingController(
        text: socialLinks['twitter']?.toString() ??
            socialLinks['x']?.toString() ??
            '');
    _youtubeController =
        TextEditingController(text: socialLinks['youtube']?.toString() ?? '');

    // Initialize working hours controllers
    _workHoursControllers.clear();
    _closedDays.clear();
    final workHours = website.parsedWorkHours ?? {};
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    for (var day in days) {
      String openTime = '';
      String closeTime = '';
      bool isClosed = true; // Default to closed if no times

      if (workHours[day] != null && workHours[day] is Map) {
        final dayData = workHours[day] as Map<String, dynamic>;
        openTime = dayData['open']?.toString() ?? '';
        closeTime = dayData['close']?.toString() ?? '';
        // Day is open if both times are provided and not empty
        isClosed = openTime.isEmpty || closeTime.isEmpty;
      }

      _workHoursControllers[day] = {
        'open': TextEditingController(text: openTime),
        'close': TextEditingController(text: closeTime),
      };
      _closedDays[day] = isClosed;
    }

    // Initialize services
    _services = [];
    _serviceControllers.clear();
    if (website.contentBlocks != null &&
        website.contentBlocks!['services'] != null) {
      final servicesData = website.contentBlocks!['services'];
      if (servicesData is List) {
        _services = servicesData.map((e) => e.toString()).toList();
      }
    }
    for (var service in _services) {
      _serviceControllers.add(TextEditingController(text: service));
    }

    _currentWebsite = website;
  }

  bool _canEdit() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    return user != null && (user.isAdmin == 1 || user.isDoctor == 1);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tenantWebsiteService = ref.read(tenantWebsiteServiceProvider);

      // Prepare social links
      final socialLinks = <String, String>{};
      if (_facebookController.text.trim().isNotEmpty) {
        socialLinks['facebook'] = _facebookController.text.trim();
      }
      if (_instagramController.text.trim().isNotEmpty) {
        socialLinks['instagram'] = _instagramController.text.trim();
      }
      if (_linkedinController.text.trim().isNotEmpty) {
        socialLinks['linkedin'] = _linkedinController.text.trim();
      }
      if (_twitterController.text.trim().isNotEmpty) {
        socialLinks['twitter'] = _twitterController.text.trim();
      }
      if (_youtubeController.text.trim().isNotEmpty) {
        socialLinks['youtube'] = _youtubeController.text.trim();
      }

      // Prepare working hours - only include days that are not closed
      final workHours = <String, Map<String, String>>{};
      for (var entry in _workHoursControllers.entries) {
        final dayKey = entry.key;
        // Skip closed days
        if (_closedDays[dayKey] == true) {
          continue;
        }

        final openController = entry.value['open'];
        final closeController = entry.value['close'];
        if (openController != null && closeController != null) {
          final openTime = openController.text.trim();
          final closeTime = closeController.text.trim();
          if (openTime.isNotEmpty && closeTime.isNotEmpty) {
            workHours[dayKey] = {
              'open': openTime,
              'close': closeTime,
            };
          }
        }
      }

      // Prepare services
      final services = _serviceControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Prepare update data
      final updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'contact_email': _contactEmailController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim(),
        'contact_address': _contactAddressController.text.trim(),
        'google_maps_location': _googleMapsLocationController.text.trim(),
        'social_links': jsonEncode(socialLinks),
        'work_hours': jsonEncode(workHours),
        'content_blocks': jsonEncode({'services': services}),
      };

      final result =
          await tenantWebsiteService.updateTenantWebsiteConfig(updateData);

      if (result is Success<TenantWebsiteModel>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informations du cabinet mises à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the providers
          ref.invalidate(tenantWebsiteConfigProvider);
          ref.invalidate(publicTenantWebsiteProvider);
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        }
      } else if (result is Failure<TenantWebsiteModel>) {
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

  void _startEditing(TenantWebsiteModel website) {
    _initializeControllers(website);
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
    // Clear selected images
    _selectedLogo = null;
    _selectedFavicon = null;
    _selectedHeroImage = null;
    _selectedSeoImage = null;
    _selectedLogoBytes = null;
    _selectedFaviconBytes = null;
    _selectedHeroImageBytes = null;
    _selectedSeoImageBytes = null;
  }

  Future<void> _pickImage(String fieldName) async {
    try {
      // Use FilePicker instead of ImagePicker to avoid READ_MEDIA permissions
      // FilePicker uses system photo picker on Android 13+ without requiring permissions
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final fileName = file.name;

      if (kIsWeb) {
        if (file.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors du chargement de l\'image')),
          );
          return;
        }
        setState(() {
          switch (fieldName) {
            case 'logo':
              _selectedLogoBytes = file.bytes;
              _selectedLogoFileName = fileName;
              break;
            case 'favicon':
              _selectedFaviconBytes = file.bytes;
              _selectedFaviconFileName = fileName;
              break;
            case 'hero_image':
              _selectedHeroImageBytes = file.bytes;
              _selectedHeroImageFileName = fileName;
              break;
            case 'seo_image':
              _selectedSeoImageBytes = file.bytes;
              _selectedSeoImageFileName = fileName;
              break;
          }
        });
      } else {
        if (file.path == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors du chargement de l\'image')),
          );
          return;
        }
        final fileObj = File(file.path!);
        setState(() {
          switch (fieldName) {
            case 'logo':
              _selectedLogo = fileObj;
              break;
            case 'favicon':
              _selectedFavicon = fileObj;
              break;
            case 'hero_image':
              _selectedHeroImage = fileObj;
              break;
            case 'seo_image':
              _selectedSeoImage = fileObj;
              break;
          }
        });
      }
      // Auto-upload after selection
      await _uploadImage(fieldName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImage(String fieldName) async {
    final tenantWebsiteService = ref.read(tenantWebsiteServiceProvider);

    // Set uploading state
    setState(() {
      switch (fieldName) {
        case 'logo':
          _uploadingLogo = true;
          break;
        case 'favicon':
          _uploadingFavicon = true;
          break;
        case 'hero_image':
          _uploadingHeroImage = true;
          break;
        case 'seo_image':
          _uploadingSeoImage = true;
          break;
      }
    });

    try {
      Result<Map<String, dynamic>> result;
      if (kIsWeb) {
        Uint8List? bytes;
        String? fileName;
        switch (fieldName) {
          case 'logo':
            bytes = _selectedLogoBytes;
            fileName = _selectedLogoFileName;
            break;
          case 'favicon':
            bytes = _selectedFaviconBytes;
            fileName = _selectedFaviconFileName;
            break;
          case 'hero_image':
            bytes = _selectedHeroImageBytes;
            fileName = _selectedHeroImageFileName;
            break;
          case 'seo_image':
            bytes = _selectedSeoImageBytes;
            fileName = _selectedSeoImageFileName;
            break;
        }
        result = await tenantWebsiteService.uploadFile(
          fieldName: fieldName,
          fileBytes: bytes,
          fileName: fileName,
        );
      } else {
        File? file;
        switch (fieldName) {
          case 'logo':
            file = _selectedLogo;
            break;
          case 'favicon':
            file = _selectedFavicon;
            break;
          case 'hero_image':
            file = _selectedHeroImage;
            break;
          case 'seo_image':
            file = _selectedSeoImage;
            break;
        }
        result = await tenantWebsiteService.uploadFile(
          fieldName: fieldName,
          file: file,
          fileName: file?.path.split('/').last,
        );
      }

      if (result is Success<Map<String, dynamic>>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  result.data['message'] ?? 'Image téléchargée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the providers to get updated images
          ref.invalidate(tenantWebsiteConfigProvider);
          ref.invalidate(publicTenantWebsiteProvider);
        }
      } else if (result is Failure<Map<String, dynamic>>) {
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
            content: Text('Erreur lors du téléchargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          switch (fieldName) {
            case 'logo':
              _uploadingLogo = false;
              break;
            case 'favicon':
              _uploadingFavicon = false;
              break;
            case 'hero_image':
              _uploadingHeroImage = false;
              break;
            case 'seo_image':
              _uploadingSeoImage = false;
              break;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantWebsiteAsync = ref.watch(publicTenantWebsiteProvider);
    final authState = ref.watch(authProvider);
    final canEdit = _canEdit();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F23) : const Color(0xFFF0F2F5),
      body: tenantWebsiteAsync.when(
        data: (result) {
          if (result is Success<TenantWebsiteModel>) {
            // Initialize controllers if not already done
            if (_currentWebsite?.id != result.data.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initializeControllers(result.data);
              });
            }
            return _buildContent(
                context, result.data, isDark, primaryColor, canEdit, authState);
          } else if (result is Failure<TenantWebsiteModel>) {
            return CustomErrorWidget(message: result.message);
          }
          return const CustomErrorWidget(message: 'Unknown error occurred');
        },
        loading: () => const LoadingWidget(),
        error: (error, _) => CustomErrorWidget(message: error.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor, bool canEdit, AuthState authState) {
    // Parse Colors
    Color? tenantPrimaryColor;
    if (website.parsedThemeColors != null &&
        website.parsedThemeColors!['primary'] != null) {
      try {
        final colorString = website.parsedThemeColors!['primary'] as String;
        tenantPrimaryColor =
            Color(int.parse(colorString.replaceAll('#', '0xFF')));
      } catch (e) {
        // ignore
      }
    }
    final effectiveColor = tenantPrimaryColor ?? primaryColor;

    if (_isEditing) {
      return _buildEditForm(context, website, isDark, effectiveColor);
    }

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, website, isDark, effectiveColor, canEdit),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, website, isDark, effectiveColor),
                const SizedBox(height: 24),
                _buildContactActions(context, website, effectiveColor, isDark),
                const SizedBox(height: 24),
                if (website.parsedSocialLinks != null &&
                    website.parsedSocialLinks!.isNotEmpty) ...[
                  _buildSocialLinks(context, website.parsedSocialLinks!,
                      effectiveColor, isDark),
                  const SizedBox(height: 24),
                ],
                if (website.contentBlocks != null &&
                    website.contentBlocks!['services'] != null) ...[
                  _buildServices(context, website.contentBlocks!['services'],
                      isDark, effectiveColor),
                  const SizedBox(height: 24),
                ],
                if (website.parsedWorkHours != null) ...[
                  _buildWorkingHours(context, website.parsedWorkHours!, isDark,
                      effectiveColor),
                  const SizedBox(height: 24),
                ],
                // Prescription Settings Link (in view mode)
                if (canEdit)
                  _buildPrescriptionSettingsLink(
                      context, isDark, effectiveColor),
                if (canEdit) const SizedBox(height: 24),
                // Add padding at bottom
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F23) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.edit_rounded, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Modifier le cabinet',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Enregistrer'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Basic Information Section
            _buildSectionCard(
              context: context,
              isDark: isDark,
              icon: Icons.info_rounded,
              title: 'Informations de base',
              children: [
                _buildModernTextField(
                  controller: _titleController,
                  label: 'Nom du cabinet',
                  icon: Icons.local_hospital_rounded,
                  required: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer le nom du cabinet';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  icon: Icons.description_rounded,
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Images Section
            _buildSectionCard(
              context: context,
              isDark: isDark,
              icon: Icons.image_rounded,
              title: 'Images',
              children: [
                _buildImageUploadField(
                  context: context,
                  isDark: isDark,
                  label: 'Logo',
                  fieldName: 'logo',
                  currentImagePath: website.logoPath,
                  selectedFile: _selectedLogo,
                  selectedBytes: _selectedLogoBytes,
                  isUploading: _uploadingLogo,
                  onPick: () => _pickImage('logo'),
                ),
                const SizedBox(height: 16),
                _buildImageUploadField(
                  context: context,
                  isDark: isDark,
                  label: 'Favicon',
                  fieldName: 'favicon',
                  currentImagePath: website.faviconPath,
                  selectedFile: _selectedFavicon,
                  selectedBytes: _selectedFaviconBytes,
                  isUploading: _uploadingFavicon,
                  onPick: () => _pickImage('favicon'),
                ),
                const SizedBox(height: 16),
                _buildImageUploadField(
                  context: context,
                  isDark: isDark,
                  label: 'Image Hero (Bannière)',
                  fieldName: 'hero_image',
                  currentImagePath: website.heroImagePath,
                  selectedFile: _selectedHeroImage,
                  selectedBytes: _selectedHeroImageBytes,
                  isUploading: _uploadingHeroImage,
                  onPick: () => _pickImage('hero_image'),
                ),
                const SizedBox(height: 16),
                _buildImageUploadField(
                  context: context,
                  isDark: isDark,
                  label: 'Image SEO',
                  fieldName: 'seo_image',
                  currentImagePath: website.seoImagePath,
                  selectedFile: _selectedSeoImage,
                  selectedBytes: _selectedSeoImageBytes,
                  isUploading: _uploadingSeoImage,
                  onPick: () => _pickImage('seo_image'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact Information Section
            _buildSectionCard(
              context: context,
              isDark: isDark,
              icon: Icons.contact_mail_rounded,
              title: 'Informations de contact',
              children: [
                _buildModernTextField(
                  controller: _contactEmailController,
                  label: 'Email de contact',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!value.contains('@')) {
                        return 'Veuillez entrer un email valide';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _contactPhoneController,
                  label: 'Téléphone de contact',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _contactAddressController,
                  label: 'Adresse',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _googleMapsLocationController,
                  label: 'Lien Google Maps',
                  icon: Icons.map_rounded,
                  keyboardType: TextInputType.url,
                  hintText: 'https://maps.google.com/...',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Social Media Section
            _buildSectionCard(
              context: context,
              isDark: isDark,
              icon: Icons.share_rounded,
              title: 'Réseaux sociaux',
              children: [
                _buildSocialMediaField(
                  controller: _facebookController,
                  label: 'Facebook',
                  icon: FontAwesomeIcons.facebook,
                  color: const Color(0xFF1877F2),
                ),
                const SizedBox(height: 12),
                _buildSocialMediaField(
                  controller: _instagramController,
                  label: 'Instagram',
                  icon: FontAwesomeIcons.instagram,
                  color: const Color(0xFFE4405F),
                ),
                const SizedBox(height: 12),
                _buildSocialMediaField(
                  controller: _linkedinController,
                  label: 'LinkedIn',
                  icon: FontAwesomeIcons.linkedin,
                  color: const Color(0xFF0A66C2),
                ),
                const SizedBox(height: 12),
                _buildSocialMediaField(
                  controller: _twitterController,
                  label: 'Twitter/X',
                  icon: FontAwesomeIcons.xTwitter,
                  color: Colors.black,
                ),
                const SizedBox(height: 12),
                _buildSocialMediaField(
                  controller: _youtubeController,
                  label: 'YouTube',
                  icon: FontAwesomeIcons.youtube,
                  color: const Color(0xFFFF0000),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Working Hours Section
            _buildSectionCard(
              context: context,
              isDark: isDark,
              icon: Icons.access_time_rounded,
              title: 'Heures d\'ouverture',
              children: _buildWorkingHoursFields(),
            ),
            const SizedBox(height: 16),

            // Services Section
            _buildSectionCard(
              context: context,
              isDark: isDark,
              icon: Icons.medical_services_rounded,
              title: 'Services',
              children: _buildServicesFields(),
            ),
            const SizedBox(height: 16),

            // Prescription Settings Link
            if (_canEdit())
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrescriptionSettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paramètres Ordonnance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configurer les paramètres des ordonnances',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDark ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            if (_canEdit()) const SizedBox(height: 16),

            // Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _cancelEditing,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Annuler'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveChanges,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor, bool canEdit) {
    final heroImage = website.heroImagePath;

    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.5)
              : Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      actions: canEdit
          ? [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.5)
                      : Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _startEditing(website),
                  color: isDark ? Colors.white : Colors.black,
                  tooltip: 'Modifier',
                ),
              ),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (heroImage != null && heroImage.isNotEmpty)
              Builder(
                builder: (context) {
                  // Clean the path logic
                  String cleanPath = heroImage
                      .replaceAll(RegExp(r'\s+'), '')
                      .replaceAll('\n', '')
                      .replaceAll('\r', '')
                      .replaceAll('\t', '')
                      .replaceAll(' ', '')
                      .trim();

                  if (cleanPath.startsWith('/')) {
                    cleanPath = cleanPath.substring(1);
                  }

                  final storageBase = ApiConstants.storageBaseUrl.endsWith('/')
                      ? ApiConstants.storageBaseUrl
                          .substring(0, ApiConstants.storageBaseUrl.length - 1)
                      : ApiConstants.storageBaseUrl;

                  final imageUrl = cleanPath.startsWith('http')
                      ? cleanPath
                      : '$storageBase/storage/$cleanPath'.trim();

                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: primaryColor.withOpacity(0.1),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: primaryColor.withOpacity(0.1),
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: primaryColor.withOpacity(0.5)),
                    ),
                  );
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Icon(Icons.local_hospital_rounded,
                    size: 80, color: Colors.white.withOpacity(0.3)),
              ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (website.logoPath != null && website.logoPath!.isNotEmpty)
          Container(
            width: 100, // Slightly larger
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Builder(
                builder: (context) {
                  String cleanPath = website.logoPath!
                      .replaceAll(RegExp(r'\s+'), '')
                      .replaceAll('\n', '')
                      .replaceAll('\r', '')
                      .replaceAll('\t', '')
                      .replaceAll(' ', '')
                      .trim();

                  if (cleanPath.startsWith('/')) {
                    cleanPath = cleanPath.substring(1);
                  }

                  final storageBase = ApiConstants.storageBaseUrl.endsWith('/')
                      ? ApiConstants.storageBaseUrl
                          .substring(0, ApiConstants.storageBaseUrl.length - 1)
                      : ApiConstants.storageBaseUrl;

                  final imageUrl = cleanPath.startsWith('http')
                      ? cleanPath
                      : '$storageBase/storage/$cleanPath'.trim();

                  return CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.local_hospital, size: 50, color: primaryColor),
          ),
        const SizedBox(height: 16),
        Text(
          website.title ?? 'Clinic Name',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (website.contactAddress != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              if (website.googleMapsLocation != null) {
                _launchURL(website.googleMapsLocation!);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      website.contactAddress!,
                      style: TextStyle(
                        fontSize: 14,
                        color: (website.googleMapsLocation != null)
                            ? Colors.blue
                            : (isDark ? Colors.white70 : Colors.grey[600]),
                        decoration: (website.googleMapsLocation != null)
                            ? TextDecoration.underline
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (website.description != null && website.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              website.description!,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildContactActions(BuildContext context, TenantWebsiteModel website,
      Color color, bool isDark) {
    final localizations = AppLocalizations.of(context);

    // Prepare list of actions
    List<Widget> actions = [];

    // 1. Call
    if (website.contactPhone != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: Icons.call,
        label: localizations?.call ?? 'Call',
        color: Colors.green,
        onTap: () => _launchURL('tel:${website.contactPhone}'),
        isDark: isDark,
      ));
    }

    // 2. Map
    if (website.googleMapsLocation != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: Icons.map,
        label: localizations?.map ?? 'Map',
        color: Colors.orange,
        onTap: () => _launchURL(website.googleMapsLocation!),
        isDark: isDark,
      ));
    }

    // 3. WhatsApp
    if (website.contactPhone != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: FontAwesomeIcons.whatsapp,
        label: 'WhatsApp',
        color: const Color(0xFF25D366),
        onTap: () {
          final phone = website.contactPhone!.replaceAll(RegExp(r'[^0-9]'), '');
          _launchURL('https://wa.me/$phone');
        },
        isDark: isDark,
      ));
    }

    // 4. Email
    if (website.contactEmail != null) {
      actions.add(_buildActionButton(
        context: context,
        icon: Icons.email_outlined,
        label: localizations?.email ?? 'Email',
        color: Colors.blue,
        onTap: () => _launchURL('mailto:${website.contactEmail}'),
        isDark: isDark,
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      // Use GridView or Column of Rows
      return Column(
        children: [
          Row(
            children: [
              if (actions.isNotEmpty) Expanded(child: actions[0]),
              const SizedBox(width: 12),
              if (actions.length > 1)
                Expanded(child: actions[1])
              else
                const Spacer(),
            ],
          ),
          if (actions.length > 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: actions[2]),
                const SizedBox(width: 12),
                if (actions.length > 3)
                  Expanded(child: actions[3])
                else
                  const Spacer(),
              ],
            ),
          ],
        ],
      );
    }).animate().fadeIn(delay: 100.ms).slideX();
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Object icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              icon is FaIconData
                  ? FaIcon(icon, color: color)
                  : Icon(icon as IconData, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinks(BuildContext context, Map<String, dynamic> links,
      Color color, bool isDark) {
    final localizations = AppLocalizations.of(context);
    final validLinks = links.entries
        .where((e) =>
            e.value != null && e.value != '#' && e.value.toString().isNotEmpty)
        .toList();

    if (validLinks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.followUs ?? 'Follow Us',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: validLinks.map((entry) {
            final platform = entry.key.toLowerCase();
            final url = entry.value.toString();

            FaIconData icon;
            Color iconColor;

            switch (platform) {
              case 'facebook':
                icon = FontAwesomeIcons.facebook;
                iconColor = const Color(0xFF1877F2);
                break;
              case 'instagram':
                icon = FontAwesomeIcons.instagram;
                iconColor = const Color(0xFFE4405F);
                break;
              case 'linkedin':
                icon = FontAwesomeIcons.linkedin;
                iconColor = const Color(0xFF0A66C2);
                break;
              case 'twitter':
              case 'x':
                icon = FontAwesomeIcons.xTwitter;
                iconColor = isDark ? Colors.white : Colors.black;
                break;
              case 'youtube':
                icon = FontAwesomeIcons.youtube;
                iconColor = const Color(0xFFFF0000);
                break;
              default:
                icon = FontAwesomeIcons.globe;
                iconColor = color;
            }

            return InkWell(
              onTap: () => _launchURL(url),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey[200]!),
                ),
                child: Center(
                  child: FaIcon(icon, color: iconColor, size: 24),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildServices(
      BuildContext context, dynamic servicesData, bool isDark, Color color) {
    final localizations = AppLocalizations.of(context);
    List<String> services = [];
    if (servicesData is List) {
      services = servicesData.map((e) => e.toString()).toList();
    }

    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.ourServices ?? 'Our Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: services.map((service) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                            color: color.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2)),
                      ],
              ),
              child: Text(
                service,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildWorkingHours(BuildContext context, Map<String, dynamic> hours,
      bool isDark, Color color) {
    if (hours.isEmpty) return const SizedBox.shrink();

    final localizations = AppLocalizations.of(context);
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations?.workingHours ?? 'Working Hours',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
          ),
          child: Column(
            children: days.map((day) {
              final dayData = hours[day];
              String timeDisplay = localizations?.closed ?? 'Closed';
              bool isOpen = false;

              if (dayData != null && dayData is Map) {
                final open = dayData['open'];
                final close = dayData['close'];
                if (open != null && close != null) {
                  timeDisplay = '$open - $close';
                  isOpen = true;
                }
              }

              // Localize day name
              String dayName = day;
              switch (day) {
                case 'monday':
                  dayName = localizations?.monday ?? 'Monday';
                  break;
                case 'tuesday':
                  dayName = localizations?.tuesday ?? 'Tuesday';
                  break;
                case 'wednesday':
                  dayName = localizations?.wednesday ?? 'Wednesday';
                  break;
                case 'thursday':
                  dayName = localizations?.thursday ?? 'Thursday';
                  break;
                case 'friday':
                  dayName = localizations?.friday ?? 'Friday';
                  break;
                case 'saturday':
                  dayName = localizations?.saturday ?? 'Saturday';
                  break;
                case 'sunday':
                  dayName = localizations?.sunday ?? 'Sunday';
                  break;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      timeDisplay,
                      style: TextStyle(
                        fontSize: 15,
                        color: isOpen
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.red.withOpacity(0.7),
                        fontWeight: isOpen ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F0F23)
            : Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildSocialMediaField({
    required TextEditingController controller,
    required String label,
    required FaIconData icon,
    required Color color,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'https://...',
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(icon, color: color, size: 18),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F0F23)
            : Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: TextInputType.url,
    );
  }

  List<Widget> _buildWorkingHoursFields() {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = [
      {'key': 'monday', 'label': localizations?.monday ?? 'Monday'},
      {'key': 'tuesday', 'label': localizations?.tuesday ?? 'Tuesday'},
      {'key': 'wednesday', 'label': localizations?.wednesday ?? 'Wednesday'},
      {'key': 'thursday', 'label': localizations?.thursday ?? 'Thursday'},
      {'key': 'friday', 'label': localizations?.friday ?? 'Friday'},
      {'key': 'saturday', 'label': localizations?.saturday ?? 'Saturday'},
      {'key': 'sunday', 'label': localizations?.sunday ?? 'Sunday'},
    ];

    return days.map((day) {
      final dayKey = day['key'] as String;
      final dayLabel = day['label'] as String;
      final dayControllers = _workHoursControllers[dayKey];
      final openController = dayControllers?['open'];
      final closeController = dayControllers?['close'];

      TimeOfDay? _parseTime(String? timeStr) {
        if (timeStr == null || timeStr.isEmpty) return null;
        try {
          final parts = timeStr.split(':');
          if (parts.length >= 2) {
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        } catch (e) {
          return null;
        }
        return null;
      }

      String _formatTime(TimeOfDay time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }

      final isClosed = _closedDays[dayKey] ?? false;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F23) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isClosed
                  ? (isDark
                      ? Colors.red.withOpacity(0.3)
                      : Colors.red.withOpacity(0.2))
                  : (isDark ? Colors.white10 : Colors.grey[200]!),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: isClosed
                          ? (isDark ? Colors.red.withOpacity(0.7) : Colors.red)
                          : (isDark ? Colors.white70 : Colors.grey[600]),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isClosed
                              ? (isDark
                                  ? Colors.red.withOpacity(0.7)
                                  : Colors.red)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Opacity(
                  opacity: isClosed ? 0.5 : 1.0,
                  child: InkWell(
                    onTap: isClosed
                        ? null
                        : () async {
                            final initialTime =
                                _parseTime(openController?.text) ??
                                    const TimeOfDay(hour: 9, minute: 0);
                            final time = await showTimePicker(
                              context: context,
                              initialTime: initialTime,
                            );
                            if (time != null && openController != null) {
                              setState(() {
                                openController.text = _formatTime(time);
                                // Auto-uncheck closed when time is set
                                if (_closedDays[dayKey] == true) {
                                  _closedDays[dayKey] = false;
                                }
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isClosed
                                  ? 'Fermé'
                                  : (openController?.text.isEmpty ?? true
                                      ? 'Ouverture'
                                      : openController!.text),
                              style: TextStyle(
                                fontSize: 13,
                                color: isClosed
                                    ? (isDark
                                        ? Colors.white38
                                        : Colors.grey[400])
                                    : (openController?.text.isEmpty ?? true
                                        ? (isDark
                                            ? Colors.white38
                                            : Colors.grey[400])
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87)),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Opacity(
                  opacity: isClosed ? 0.5 : 1.0,
                  child: InkWell(
                    onTap: isClosed
                        ? null
                        : () async {
                            final initialTime =
                                _parseTime(closeController?.text) ??
                                    const TimeOfDay(hour: 18, minute: 0);
                            final time = await showTimePicker(
                              context: context,
                              initialTime: initialTime,
                            );
                            if (time != null && closeController != null) {
                              setState(() {
                                closeController.text = _formatTime(time);
                                // Auto-uncheck closed when time is set
                                if (_closedDays[dayKey] == true) {
                                  _closedDays[dayKey] = false;
                                }
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isClosed
                                  ? 'Fermé'
                                  : (closeController?.text.isEmpty ?? true
                                      ? 'Fermeture'
                                      : closeController!.text),
                              style: TextStyle(
                                fontSize: 13,
                                color: isClosed
                                    ? (isDark
                                        ? Colors.white38
                                        : Colors.grey[400])
                                    : (closeController?.text.isEmpty ?? true
                                        ? (isDark
                                            ? Colors.white38
                                            : Colors.grey[400])
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87)),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Closed checkbox
              Tooltip(
                message: isClosed ? 'Jour fermé' : 'Marquer comme fermé',
                child: Container(
                  decoration: BoxDecoration(
                    color: isClosed
                        ? (isDark
                            ? Colors.red.withOpacity(0.2)
                            : Colors.red.withOpacity(0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: isClosed,
                        onChanged: (value) {
                          setState(() {
                            _closedDays[dayKey] = value ?? false;
                            // Clear times when marking as closed
                            if (value == true) {
                              openController?.clear();
                              closeController?.clear();
                            }
                          });
                        },
                        activeColor: Colors.red,
                        checkColor: Colors.white,
                      ),
                      if (isClosed)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            'Fermé',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildServicesFields() {
    final widgets = <Widget>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Existing services
    if (_serviceControllers.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Services existants',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < _serviceControllers.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F23) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Icon(
                    Icons.medical_services_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _serviceControllers[i],
                    decoration: InputDecoration(
                      hintText: 'Nom du service',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () {
                    setState(() {
                      if (i < _serviceControllers.length) {
                        _serviceControllers[i].dispose();
                        _serviceControllers.removeAt(i);
                      }
                      if (i < _services.length) {
                        _services.removeAt(i);
                      }
                    });
                  },
                  color: Colors.red,
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Add new service field
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Icon(
                  Icons.add_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _newServiceController,
                  decoration: InputDecoration(
                    hintText: 'Ajouter un nouveau service',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onFieldSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _addService(value.trim());
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_newServiceController.text.trim().isNotEmpty) {
                      _addService(_newServiceController.text.trim());
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return widgets;
  }

  void _addService(String service) {
    setState(() {
      _services.add(service);
      _serviceControllers.add(TextEditingController(text: service));
      _newServiceController.clear();
    });
  }

  Widget _buildPrescriptionSettingsLink(
      BuildContext context, bool isDark, Color primaryColor) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PrescriptionSettingsScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_rounded,
                color: primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paramètres Ordonnance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configurer les paramètres des ordonnances',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideX();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Handle error
      debugPrint('Could not launch $urlString');
    }
  }

  Widget _buildImageUploadField({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String fieldName,
    String? currentImagePath,
    File? selectedFile,
    Uint8List? selectedBytes,
    required bool isUploading,
    required VoidCallback onPick,
  }) {
    final hasCurrentImage =
        currentImagePath != null && currentImagePath.isNotEmpty;
    final hasSelectedImage = selectedFile != null || selectedBytes != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F23) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Current or selected image preview
              if (hasCurrentImage || hasSelectedImage)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey[300]!,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasSelectedImage
                        ? (kIsWeb && selectedBytes != null
                            ? Image.memory(
                                selectedBytes,
                                fit: BoxFit.cover,
                              )
                            : selectedFile != null
                                ? Image.file(
                                    selectedFile,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox())
                        : hasCurrentImage
                            ? Builder(
                                builder: (context) {
                                  String cleanPath = currentImagePath!
                                      .replaceAll(RegExp(r'\s+'), '')
                                      .replaceAll('\n', '')
                                      .replaceAll('\r', '')
                                      .replaceAll('\t', '')
                                      .replaceAll(' ', '')
                                      .trim();

                                  if (cleanPath.startsWith('/')) {
                                    cleanPath = cleanPath.substring(1);
                                  }

                                  final storageBase = ApiConstants
                                          .storageBaseUrl
                                          .endsWith('/')
                                      ? ApiConstants.storageBaseUrl.substring(
                                          0,
                                          ApiConstants.storageBaseUrl.length -
                                              1)
                                      : ApiConstants.storageBaseUrl;

                                  final imageUrl = cleanPath.startsWith('http')
                                      ? cleanPath
                                      : '$storageBase/storage/$cleanPath'
                                          .trim();

                                  return CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  );
                                },
                              )
                            : const SizedBox(),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasCurrentImage)
                      Text(
                        'Image actuelle',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    if (hasSelectedImage)
                      Text(
                        'Nouvelle image sélectionnée',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: isUploading ? null : onPick,
                      icon: isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                        isUploading
                            ? 'Téléchargement...'
                            : hasSelectedImage
                                ? 'Changer l\'image'
                                : 'Sélectionner une image',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
