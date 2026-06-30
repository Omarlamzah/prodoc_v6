// lib/screens/profile_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../core/config/api_constants.dart';
import '../data/models/user_model.dart';
import 'login_screen.dart';
import 'tenant_management_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deleteFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  
  // Profile update form controllers
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _previewImageUrl;
  
  bool _isDeleting = false;
  bool _isUpdating = false;
  bool _showDeleteDialog = false;
  bool _showPasswordFields = false;
  String? _deleteError;
  String? _updateError;
  String? _updateSuccess;

  static const String DELETE_CONFIRMATION_TEXT = 'DELETE MY ACCOUNT';

  void _initializeNameController(UserModel? user) {
    if (user != null && user.name != null && _nameController.text.isEmpty) {
      _nameController.text = user.name!;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showDeleteAccountDialog() {
    setState(() {
      _showDeleteDialog = true;
      _deleteError = null;
      _passwordController.clear();
      _confirmationController.clear();
    });
  }

  void _hideDeleteAccountDialog() {
    setState(() {
      _showDeleteDialog = false;
      _deleteError = null;
      _passwordController.clear();
      _confirmationController.clear();
    });
  }

  Future<void> _handleDeleteAccount() async {
    if (!_deleteFormKey.currentState!.validate()) {
      return;
    }

    if (_confirmationController.text.trim() != DELETE_CONFIRMATION_TEXT) {
      setState(() {
        _deleteError = 'Please type "$DELETE_CONFIRMATION_TEXT" to confirm.';
      });
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _deleteError = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _deleteError = null;
    });

    final authNotifier = ref.read(authProvider.notifier);
    final error = await authNotifier.deleteAccount(
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (error == null) {
      // Account deleted successfully, user is logged out
      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deactivated.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isDeleting = false;
        _deleteError = error;
      });
    }
  }

  String? _getAvatarUrl() {
    final user = ref.read(authProvider).user;
    if (user == null) return null;

    // Try multiple possible field names for profile image
    final avatarUrl = user.additionalData?['avatar_url'] as String?;
    final imgSrc = user.additionalData?['img_src'] as String?;
    final profilePhotoPath =
        user.additionalData?['profile_photo_path'] as String?;
    final imageUrl = avatarUrl ?? imgSrc ?? profilePhotoPath;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // If it's already a full URL, return it
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return imageUrl;
      }
      // Otherwise, construct the full URL
      return '${ApiConstants.storageBaseUrl}/storage/$imageUrl';
    }

    return null;
  }

  String? _getPhone() {
    final user = ref.read(authProvider).user;
    if (user == null) return null;
    return user.additionalData?['phone'] as String?;
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Use FilePicker for web
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.single.bytes != null) {
          setState(() {
            _selectedImageBytes = result.files.single.bytes;
            _selectedImageFileName = result.files.single.name;
            _previewImageUrl = null; // Will use bytes for preview
          });
        }
      } else {
        // Use ImagePicker for mobile (camera)
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          setState(() {
            _selectedImageFile = File(pickedFile.path);
            _selectedImageFileName = pickedFile.name;
            _previewImageUrl = pickedFile.path;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      if (kIsWeb) {
        // Use FilePicker for web
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.single.bytes != null) {
          setState(() {
            _selectedImageBytes = result.files.single.bytes;
            _selectedImageFileName = result.files.single.name;
            _previewImageUrl = null; // Will use bytes for preview
          });
        }
      } else {
        // Use FilePicker for mobile (gallery - no permissions needed)
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedImageFile = File(result.files.single.path!);
            _selectedImageFileName = result.files.single.name;
            _previewImageUrl = result.files.single.path;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _selectedImageFileName = null;
      _previewImageUrl = null;
    });
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate password fields if password change is requested
    if (_newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        setState(() {
          _updateError = 'Current password is required to change password';
        });
        return;
      }
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _updateError = 'New passwords do not match';
        });
        return;
      }
      if (_newPasswordController.text.length < 8) {
        setState(() {
          _updateError = 'New password must be at least 8 characters';
        });
        return;
      }
    }

    setState(() {
      _isUpdating = true;
      _updateError = null;
      _updateSuccess = null;
    });

    final authNotifier = ref.read(authProvider.notifier);
    final error = await authNotifier.updateProfile(
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
      currentPassword: _currentPasswordController.text.trim().isNotEmpty
          ? _currentPasswordController.text.trim()
          : null,
      newPassword: _newPasswordController.text.trim().isNotEmpty
          ? _newPasswordController.text.trim()
          : null,
      passwordConfirmation: _confirmPasswordController.text.trim().isNotEmpty
          ? _confirmPasswordController.text.trim()
          : null,
      imageFile: _selectedImageFile,
      imageBytes: _selectedImageBytes,
      imageFileName: _selectedImageFileName,
    );

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _isUpdating = false;
        _updateSuccess = 'Profile updated successfully';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _showPasswordFields = false;
        _removeImage();
      });

      // Clear success message after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _updateSuccess = null;
          });
        }
      });
    } else {
      setState(() {
        _isUpdating = false;
        _updateError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F23) : const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'No user data available.',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Initialize name controller with current user name
    _initializeNameController(user);

    final avatarUrl = _getAvatarUrl();
    final roles = <String>[];
    if (user.isAdmin == 1) roles.add('Admin');
    if (user.isDoctor == 1) roles.add('Doctor');
    if (user.isReceptionist == 1) roles.add('Receptionist');
    if (user.isPatient == 1) roles.add('Patient');
    if (user.isAccountant == 1) roles.add('Accountant');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F23) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.person_outline, size: 24),
            SizedBox(width: 8),
            Text('Profile'),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF0F0F23) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-width Account Info Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1A1A2E),
                              const Color(0xFF16213E),
                            ]
                          : [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        children: [
                          // Avatar with edit button
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  backgroundImage: _previewImageUrl != null
                                      ? (_previewImageUrl!.startsWith('http')
                                          ? CachedNetworkImageProvider(_previewImageUrl!)
                                          : FileImage(File(_previewImageUrl!)) as ImageProvider)
                                      : (_selectedImageBytes != null
                                          ? MemoryImage(_selectedImageBytes!)
                                          : (avatarUrl != null
                                              ? CachedNetworkImageProvider(avatarUrl)
                                              : null)),
                                  child: (_previewImageUrl == null &&
                                          _selectedImageBytes == null &&
                                          avatarUrl == null)
                                      ? Text(
                                          (user.name != null && user.name!.isNotEmpty)
                                              ? user.name![0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: _isUpdating
                                          ? null
                                          : () {
                                              showModalBottomSheet(
                                                context: context,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) => Container(
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? const Color(0xFF1A1A2E)
                                                        : Colors.white,
                                                    borderRadius: const BorderRadius.vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: SafeArea(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          margin: const EdgeInsets.only(top: 12),
                                                          width: 40,
                                                          height: 4,
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey[300],
                                                            borderRadius: BorderRadius.circular(2),
                                                          ),
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(Icons.camera_alt),
                                                          title: const Text('Take Photo'),
                                                          onTap: () {
                                                            Navigator.pop(context);
                                                            _pickImage();
                                                          },
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(Icons.photo_library),
                                                          title: const Text('Choose from Gallery'),
                                                          onTap: () {
                                                            Navigator.pop(context);
                                                            _pickImageFromGallery();
                                                          },
                                                        ),
                                                        if (_selectedImageFile != null ||
                                                            _selectedImageBytes != null)
                                                          ListTile(
                                                            leading: const Icon(Icons.delete,
                                                                color: Colors.red),
                                                            title: const Text('Remove Photo',
                                                                style: TextStyle(color: Colors.red)),
                                                            onTap: () {
                                                              Navigator.pop(context);
                                                              _removeImage();
                                                            },
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.camera_alt,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Name
                          Text(
                            user.name ?? 'User',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Email
                          if (user.email != null && user.email!.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.email_outlined,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  user.email!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          
                          // Phone
                          if (_getPhone() != null && _getPhone()!.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone_outlined,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _getPhone()!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          
                          // Roles
                          if (roles.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: roles.map((role) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    role,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Content Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Profile Update Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 24,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Update Profile',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Success/Error messages
                                if (_updateSuccess != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.green, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _updateSuccess!,
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_updateError != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.red, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _updateError!,
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Name field
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    hintText: 'Enter your full name',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey.shade50,
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Name is required';
                                    }
                                    return null;
                                  },
                                  enabled: !_isUpdating,
                                ),
                                const SizedBox(height: 20),

                                // Password change section
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.blue.shade50.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade100.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Change Password',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text(
                                          'Update password',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        value: _showPasswordFields,
                                        onChanged: _isUpdating
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _showPasswordFields = value;
                                                  if (!_showPasswordFields) {
                                                    _currentPasswordController.clear();
                                                    _newPasswordController.clear();
                                                    _confirmPasswordController.clear();
                                                  }
                                                });
                                              },
                                      ),
                                    ],
                                  ),
                                ),

                                // Password fields (shown when toggle is on)
                                if (_showPasswordFields) ...[
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _currentPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Current Password',
                                      hintText: 'Enter your current password',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.shade50,
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                    enabled: !_isUpdating,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _newPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'New Password',
                                      hintText: 'Enter new password (min 8 characters)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.shade50,
                                      prefixIcon: Icon(
                                        Icons.lock,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                    enabled: !_isUpdating,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm New Password',
                                      hintText: 'Confirm your new password',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.shade50,
                                      prefixIcon: Icon(
                                        Icons.lock,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                    enabled: !_isUpdating,
                                  ),
                                ],

                                const SizedBox(height: 32),

                                // Update button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isUpdating ? null : _handleUpdateProfile,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isUpdating
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.save, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Update Profile',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tenant Management Section (Admin-only)
                      if (user.isAdmin == 1)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business_outlined,
                                        color: Colors.purple,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Your clinic',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'View your clinic details or delete your clinic account.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TenantManagementScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.business_outlined, size: 20),
                                    label: const Text(
                                      'Manage your clinic',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
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
                      if (user.isAdmin == 1) const SizedBox(height: 20),

                      // Danger Zone Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.red.shade300,
                            width: 1.5,
                          ),
                        ),
                        color: isDark
                            ? Colors.red.shade900.withOpacity(0.15)
                            : Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Danger Zone',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Deactivate your account permanently. You will no longer be able to sign in. Data is retained for legal compliance.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'By deleting your account, your profile and access will be deactivated. Medical history and appointment records may be retained by the clinic for legal reasons.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _showDeleteAccountDialog,
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  label: const Text(
                                    'Delete My Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red, width: 2),
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
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Delete Account Dialog
          if (_showDeleteDialog)
            _buildDeleteAccountDialog(context, localizations, isDark),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountDialog(
    BuildContext context,
    AppLocalizations? localizations,
    bool isDark,
  ) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _deleteFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: const Text(
                          'Delete My Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _isDeleting ? null : _hideDeleteAccountDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'This will deactivate your account. You will no longer be able to sign in.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To confirm, enter your password and type the phrase below.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error message
                  if (_deleteError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _deleteError!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Your Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                    enabled: !_isDeleting,
                  ),
                  const SizedBox(height: 16),

                  // Confirmation field
                  TextFormField(
                    controller: _confirmationController,
                    decoration: InputDecoration(
                      labelText: 'Type "$DELETE_CONFIRMATION_TEXT" to confirm',
                      hintText: DELETE_CONFIRMATION_TEXT,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _confirmationController.text.isNotEmpty &&
                                  _confirmationController.text != DELETE_CONFIRMATION_TEXT
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.text_fields),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                    ),
                    validator: (value) {
                      if (value == null || value.trim() != DELETE_CONFIRMATION_TEXT) {
                        return 'Please type "$DELETE_CONFIRMATION_TEXT" to confirm';
                      }
                      return null;
                    },
                    enabled: !_isDeleting,
                    onChanged: (value) {
                      setState(() {
                        _deleteError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isDeleting ? null : _hideDeleteAccountDialog,
                        child: Text(localizations?.cancel ?? 'Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isDeleting ? null : _handleDeleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Delete My Account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
