// lib/screens/public_appointment_booking_screen.dart - Public Appointment Booking
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/public_appointment_providers.dart';
import '../providers/tenant_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../data/models/doctor_model.dart';
import '../data/models/service_model.dart';
import '../providers/auth_providers.dart';

class PublicAppointmentBookingScreen extends ConsumerStatefulWidget {
  final bool isBookingForSelf;

  const PublicAppointmentBookingScreen({
    super.key,
    this.isBookingForSelf = true,
  });

  @override
  ConsumerState<PublicAppointmentBookingScreen> createState() =>
      _PublicAppointmentBookingScreenState();
}

class _PublicAppointmentBookingScreenState
    extends ConsumerState<PublicAppointmentBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedServiceId;
  int? _selectedDoctorId;
  String? _selectedDate;
  String? _selectedTime;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  late bool _bookingForSelf;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bookingForSelf = widget.isBookingForSelf;
    // Pre-fill user info if authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillUserInfo();
    });
  }

  void _prefillUserInfo() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null && _bookingForSelf) {
      setState(() {
        _nameController.text = user.name ?? '';
        _emailController.text = user.email ?? '';
        // Check both direct phone field and additionalData if any
        _phoneController.text =
            (user.additionalData?['phone'] ?? user.additionalData?['phone_number'] ?? '').toString();
      });
    } else {
      setState(() {
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: ref.watch(localeProvider).locale,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  Future<void> _submitForm() async {
    final localizations = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectService ?? 'Please select a service',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectDoctor ?? 'Please select a doctor',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectDate ?? 'Please select a date',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectTimeSlot ?? 'Please select a time slot',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Get selected tenant for recipient email
    final selectedTenant = ref.read(selectedTenantProvider);
    final recipientEmail = selectedTenant?.email ?? '';
    final authState = ref.read(authProvider);

    print('DEBUG: Selected Tenant: ${selectedTenant?.name ?? 'NULL'}');
    print('DEBUG: Recipient Email: $recipientEmail');
    print('DEBUG: Auth State - Is Authenticated: ${authState.user != null}');
    print('DEBUG: Auth State - User Role: ${authState.user?.role ?? 'NULL'}');

    final appointmentData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim().isEmpty 
          ? ((_bookingForSelf && authState.user != null) ? null : 'noemail@patient.com') 
          : _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'service': _selectedServiceId?.toString(),
      'doctor': _selectedDoctorId?.toString(),
      'date': _selectedDate,
      'time': _selectedTime,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'recipient': recipientEmail,
      if (authState.user != null && _bookingForSelf) 'user_id': authState.user!.id,
    };

    print('DEBUG: Sending appointment data: $appointmentData');

    final result = await ref.read(
      publicAppointmentRequestProvider(appointmentData).future,
    );

    setState(() {
      _isSubmitting = false;
    });

    result.when(
      success: (data) {
        print('DEBUG: Appointment requested successfully: $data');
        setState(() {
          _isSubmitted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.appointmentRequestSentSuccess ?? 'Your appointment request has been sent successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      },
      failure: (error) {
        print('DEBUG: Appointment request failed: $error');
        setState(() {
          _errorMessage = error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctorsAsync = ref.watch(publicDoctorsProvider);
    final servicesAsync = ref.watch(publicServicesProvider);
    final localizations = AppLocalizations.of(context);

    if (_isSubmitted) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F3460),
                    ]
                  : [
                      const Color(0xFFF8FEFF),
                      const Color(0xFFE8F4F8),
                      Colors.white,
                    ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 60,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Text(
                          localizations?.appointmentConfirmedTitle ?? 'Appointment Confirmed!',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations?.appointmentRequestSentDetails ?? 'Your appointment request has been sent successfully! We will confirm your appointment as soon as possible.',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              localizations?.back ?? 'Back',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations?.bookAppointment ?? 'Book Appointment',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ]
                : [
                    const Color(0xFFF8FEFF),
                    const Color(0xFFE8F4F8),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Column(
                    children: [
                      Text(
                        localizations?.onlineBooking ?? 'Online Booking',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations?.onlineBookingSubheader ?? 'Schedule your consultation in just a few clicks',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Booking Type Selection (Only for authenticated patients)
                  Builder(
                    builder: (context) {
                      final authState = ref.watch(authProvider);
                      final user = authState.user;
                      final isPatient = user?.isPatient == 1;

                      if (!isPatient) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildBookingTypeOption(
                                  label: localizations?.bookForMe ?? 'Book for me',
                                  icon: Icons.how_to_reg_rounded,
                                  isSelected: _bookingForSelf,
                                  onTap: () {
                                    setState(() => _bookingForSelf = true);
                                    _prefillUserInfo();
                                  },
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildBookingTypeOption(
                                  label: localizations?.someoneElse ?? 'Someone else',
                                  icon: Icons.people_outline_rounded,
                                  isSelected: !_bookingForSelf,
                                  onTap: () {
                                    setState(() => _bookingForSelf = false);
                                    _prefillUserInfo();
                                  },
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // Error Message
                  if (_errorMessage != null)
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
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Personal Information Section
                  Builder(
                    builder: (context) {
                      final authState = ref.read(authProvider);
                      final user = authState.user;
                      
                      // Hide personal info section if booking for self and authenticated
                      if (_bookingForSelf && user != null) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations?.personalInformation ?? 'Personal Information',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: localizations?.fullNameLabel ?? 'Full Name',
                            icon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations?.nameRequired ?? 'Name is required';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 16),

                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            label: localizations?.emailAddressOptional ?? 'Email Address (Optional)',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return null;
                              }
                              if (!value.contains('@')) {
                                return localizations?.invalidEmail ?? 'Invalid email address';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 16),

                          // Phone Field
                          _buildTextField(
                            controller: _phoneController,
                            label: localizations?.phoneNumberLabel ?? 'Phone Number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations?.phoneRequired ?? 'Phone number is required';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // Service Selection
                  Text(
                    localizations?.desiredService ?? 'Desired Service',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  servicesAsync.when(
                    data: (result) => result.when(
                      success: (services) => _buildServiceDropdown(
                        services,
                        isDark,
                        primaryColor,
                      ),
                      failure: (error) => _buildErrorWidget(error, isDark),
                    ),
                    loading: () => _buildLoadingWidget(isDark, localizations),
                    error: (error, stack) => _buildErrorWidget(
                      error.toString(),
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Doctor Selection
                  Text(
                    localizations?.doctorOrResponsible ?? 'Doctor / Responsible',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  doctorsAsync.when(
                    data: (result) => result.when(
                      success: (doctors) => _buildDoctorDropdown(
                        doctors,
                        isDark,
                        primaryColor,
                      ),
                      failure: (error) => _buildErrorWidget(error, isDark),
                    ),
                    loading: () => _buildLoadingWidget(isDark, localizations),
                    error: (error, stack) => _buildErrorWidget(
                      error.toString(),
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Date Selection
                  Text(
                    localizations?.appointmentDate ?? 'Appointment Date',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(isDark, primaryColor, localizations),
                  const SizedBox(height: 24),

                  // Time Slots
                  if (_selectedDoctorId != null && _selectedDate != null) ...[
                    Text(
                      localizations?.availableTimeSlots ?? 'Available Time Slots',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeSlotsGrid(isDark, primaryColor, localizations),
                    const SizedBox(height: 24),
                  ],

                  // Notes Field
                  Text(
                    localizations?.additionalNotesOptional ?? 'Additional Notes (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNotesField(isDark, primaryColor, localizations),
                  const SizedBox(height: 32),

                  // Submit Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSubmitting ? null : _submitForm,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: _isSubmitting
                              ? Center(
                                  child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      localizations?.confirmAppointment ?? 'Confirm Appointment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
          prefixIcon: Icon(icon, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildServiceDropdown(
    List<ServiceModel> services,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedServiceId,
        decoration: InputDecoration(
          labelText: 'Choose a service',
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
          prefixIcon: Icon(Icons.medical_services_rounded, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : Colors.black87,
        ),
        dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        items: services.map((service) {
          return DropdownMenuItem<int>(
            value: service.id,
            child: Text(service.title ?? 'Service'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedServiceId = value;
          });
        },
      ),
    );
  }

  Widget _buildDoctorDropdown(
    List<DoctorModel> doctors,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedDoctorId,
        decoration: InputDecoration(
          labelText: 'Select a doctor',
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
          prefixIcon: Icon(Icons.person_rounded, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : Colors.black87,
        ),
        dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        items: doctors.map((doctor) {
          return DropdownMenuItem<int>(
            value: doctor.id,
            child: Text(
              '${doctor.user?.name ?? 'Doctor'}${doctor.specialty != null ? ' - ${doctor.specialty}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedDoctorId = value;
            _selectedTime = null; // Reset time when doctor changes
          });
        },
      ),
    );
  }

  Widget _buildDatePicker(
    bool isDark,
    Color primaryColor,
    AppLocalizations? localizations,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _selectDate(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selectedDate != null
                      ? DateFormat('EEEE d MMMM yyyy',
                              ref.watch(localeProvider).locale.toString())
                          .format(DateTime.parse(_selectedDate!))
                      : localizations?.selectDate ?? 'Select a date',
                  style: GoogleFonts.poppins(
                    color: _selectedDate != null
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white70 : Colors.grey.shade600),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotsGrid(
    bool isDark,
    Color primaryColor,
    AppLocalizations? localizations,
  ) {
    final timeSlotsAsync = ref.watch(publicTimeSlotsProvider(PublicTimeSlotsParams(
      doctorId: _selectedDoctorId ?? 0,
      date: _selectedDate ?? '',
    )));

    return timeSlotsAsync.when(
      data: (result) => result.when(
        success: (timeSlots) {
          if (timeSlots.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 48,
                    color: isDark ? Colors.white70 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Text(
                        localizations?.noTimeSlotsAvailable ??
                            'No time slots available',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations?.pleaseSelectAnotherDate ??
                            'Please select another date',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: timeSlots.map((slot) {
              final isSelected = _selectedTime == slot.time;
              final isAvailable = slot.available;

              return InkWell(
                onTap: isAvailable
                    ? () {
                        setState(() {
                          _selectedTime = slot.time;
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isAvailable
                            ? (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.green.shade50)
                            : (isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isAvailable
                              ? Colors.green.shade300
                              : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isAvailable
                                ? primaryColor
                                : Colors.grey.shade400),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slot.time,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isAvailable
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey.shade400),
                        ),
                      ),
                      if (!isAvailable) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
        failure: (error) => _buildErrorWidget(error, isDark),
      ),
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                localizations?.loadingTimeSlots ?? 'Loading time slots...',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => _buildErrorWidget(error.toString(), isDark),
    );
  }

  Widget _buildNotesField(
    bool isDark,
    Color primaryColor,
    AppLocalizations? localizations,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _notesController,
        maxLines: 4,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          labelText: localizations?.describeSymptoms ?? 'Describe your symptoms or reasons for consultation...',
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
          prefixIcon: Icon(Icons.note_rounded, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(bool isDark, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              localizations?.loading ?? 'Loading...',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTypeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(isDark ? 0.2 : 0.1)
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                width: 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.grey.shade600),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : primaryColor)
                        : (isDark ? Colors.white70 : Colors.grey.shade600),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
