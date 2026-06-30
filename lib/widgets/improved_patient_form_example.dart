// Example: Improved Patient Form with Step-by-Step Wizard
// This is a reference implementation showing best practices

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ImprovedPatientFormExample extends StatefulWidget {
  const ImprovedPatientFormExample({super.key});

  @override
  State<ImprovedPatientFormExample> createState() =>
      _ImprovedPatientFormExampleState();
}

class _ImprovedPatientFormExampleState
    extends State<ImprovedPatientFormExample> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _addressController = TextEditingController();
  final _cniController = TextEditingController();

  String? _gender;
  String? _bloodType;
  int? _calculatedAge;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthdateController.dispose();
    _addressController.dispose();
    _cniController.dispose();
    _pageController.dispose();
    super.dispose();
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
        setState(() => _calculatedAge = age);
      } catch (e) {
        setState(() => _calculatedAge = null);
      }
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _nameController.text.isNotEmpty;
      case 1:
        return true; // Optional step
      case 2:
        return true; // Optional step
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < 2) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submitForm();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submitForm() {
    // Handle form submission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient created successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Patient'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(primaryColor),

          // Form Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(isDark, primaryColor),
                _buildStep2(isDark, primaryColor),
                _buildStep3(isDark, primaryColor),
              ],
            ),
          ),

          // Navigation Buttons
          _buildNavigationButtons(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          // Step Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStepIndicator(0, 'Basic Info', primaryColor),
              _buildStepIndicator(1, 'Details', primaryColor),
              _buildStepIndicator(2, 'Medical', primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, Color primaryColor) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? primaryColor
                : isActive
                    ? primaryColor.withOpacity(0.2)
                    : Colors.grey[300],
            border: Border.all(
              color: isActive ? primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? primaryColor : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? primaryColor : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_add, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Required fields',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Name Field
          _buildModernTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person,
            hint: 'Enter patient full name',
            required: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Phone Field with Formatting
          _buildPhoneField(isDark, primaryColor),
          const SizedBox(height: 20),

          // Email Field
          _buildModernTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email,
            hint: 'patient@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty && !value.contains('@')) {
                return 'Invalid email format';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Details',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Optional - can skip',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Birthdate with Age Calculator
          _buildBirthdateField(isDark, primaryColor),
          if (_calculatedAge != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Age: $_calculatedAge years',
                    style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Gender Selection
          _buildGenderSelector(primaryColor),
          const SizedBox(height: 20),

          // Address
          _buildModernTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.location_on,
            hint: 'Enter patient address',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.medical_services, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Information',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Optional - can skip',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // CNI Number
          _buildModernTextField(
            controller: _cniController,
            label: 'CNI Number',
            icon: Icons.badge,
            hint: 'AB123456',
            validator: (value) {
              if (value != null && value.isNotEmpty && value.length < 6) {
                return 'CNI number must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Blood Type
          _buildBloodTypeSelector(primaryColor),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = validator != null &&
        controller.text.isNotEmpty &&
        validator(controller.text) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: hasError ? Colors.red : Colors.grey[700],
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: hasError ? Colors.red : Colors.grey),
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? Colors.red
                    : isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Phone Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Text('(optional)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Country Code
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border(
                  right: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇲🇦', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Text('+212',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Phone Input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '6XX-XXXXXX',
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBirthdateField(bool isDark, Color primaryColor) {
    return _buildModernTextField(
      controller: _birthdateController,
      label: 'Birthdate',
      icon: Icons.calendar_today,
      hint: 'Select birthdate',
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          _birthdateController.text = DateFormat('yyyy-MM-dd').format(date);
          _calculateAge();
        }
      },
    );
  }

  Widget _buildGenderSelector(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child:
                  _buildGenderOption('male', 'Male', Icons.male, primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption(
                  'female', 'Female', Icons.female, primaryColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(
      String value, String label, IconData icon, Color primaryColor) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? primaryColor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypeSelector(Color primaryColor) {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Blood Type',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bloodTypes.map((type) {
            final isSelected = _bloodType == type;
            return GestureDetector(
              onTap: () => setState(() => _bloodType = type),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.poppins(
                    color: isSelected ? primaryColor : Colors.grey[700],
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 2 ? 'Create Patient' : 'Next',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
