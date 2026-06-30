// lib/screens/login_screen.dart - Modern Medical UI with Logo
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_providers.dart';
import '../providers/tenant_providers.dart';
import '../services/storage_service.dart';
import '../widgets/google_logo_widget.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'tenant_selection_screen.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String _loginMethod = 'email'; // 'email' or 'phone'
  bool _showPassword = false;
  bool _showResetForm = false;
  bool _rememberMe = false;
  bool _isLoadingSavedCredentials = true;
  final _resetEmailController = TextEditingController();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final rememberMe = await _storageService.getRememberMe();
    if (rememberMe) {
      final savedIdentifier = await _storageService.getSavedIdentifier();
      final savedPassword = await _storageService.getSavedPassword();

      if (savedIdentifier != null && savedPassword != null) {
        setState(() {
          _identifierController.text = savedIdentifier;
          _loginMethod =
              _detectInputType(savedIdentifier); // set toggle based on value
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    }
    setState(() {
      _isLoadingSavedCredentials = false;
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  String _detectInputType(String value) {
    if (value.isEmpty) {
      print('🔍 _detectInputType: Empty value, defaulting to email');
      return 'email';
    }
    if (value.contains('@')) {
      print('🔍 _detectInputType: Contains @, detected as email');
      return 'email';
    }
    final numbersOnly = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    print('🔍 _detectInputType: Numbers only: $numbersOnly');
    if (RegExp(r'^\d{8,}$').hasMatch(numbersOnly)) {
      print('🔍 _detectInputType: Detected as phone');
      return 'phone';
    }
    print('🔍 _detectInputType: Defaulting to email');
    return 'email';
  }

  void _handleIdentifierChange(String value) {
    final detected = _detectInputType(value);
    setState(() {
      _loginMethod = detected;
    });
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    final identifier = _identifierController.text.trim();
    final effectiveMethod = _loginMethod == 'phone'
        ? 'phone'
        : _detectInputType(
            identifier); // auto-detect if user switched mid-typing
    final sanitizedPhone =
        identifier.replaceAll(RegExp(r'[^\d\+]'), ''); // keep + for intl

    print('🔍 Login Debug:');
    print('  - Login Method: $_loginMethod');
    print('  - Effective Method: $effectiveMethod');
    print('  - Identifier: $identifier');
    print('  - Sanitized Phone: $sanitizedPhone');
    print('  - Email: ${effectiveMethod == 'email' ? identifier : null}');
    print('  - Phone: ${effectiveMethod == 'phone' ? sanitizedPhone : null}');

    ref.read(authProvider.notifier).login(
          email: effectiveMethod == 'email' ? identifier : null,
          phone: effectiveMethod == 'phone' ? sanitizedPhone : null,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  void _handleForgotPassword() {
    if (_resetEmailController.text.trim().isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseEnterEmail ??
                'Please enter your email address',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.read(authProvider.notifier).forgotPassword(
          _resetEmailController.text.trim(),
        );
  }

  void _changeTenant() {
    ref.read(selectedTenantProvider.notifier).clearTenant();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TenantSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final selectedTenant = ref.watch(selectedTenantProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    // Redirect to dashboard if authenticated
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuth == true && previous?.isAuth != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          }
        });
      }
    });

    // Redirect immediately if already authenticated
    if (authState.isAuth == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      });
      return Scaffold(
        body: Container(
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
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // Show success/error messages
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.successMessage!,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(authProvider.notifier).resetSuccessMessage();
        if (_showResetForm) {
          setState(() {
            _showResetForm = false;
            _resetEmailController.clear();
          });
        }
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error!,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authProvider.notifier).resetError();
      }
    });

    if (_isLoadingSavedCredentials) {
      return Scaffold(
        body: Container(
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
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

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
          image: DecorationImage(
            image: AssetImage('assets/icon/doc.jpg'),
            fit: BoxFit.cover,
            opacity: isDark ? 0.25 : 0.30,
          ),
        ),
        child: Stack(
          children: [
            // Main Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tenant Display Card
                      if (selectedTenant != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.business_rounded,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizations?.organization ??
                                            'Organization',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedTenant.name ?? 'Unknown',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _changeTenant,
                                  child: Text(
                                    localizations?.change ?? 'Change',
                                    style: GoogleFonts.poppins(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: -0.1, end: 0),
                      const SizedBox(height: 20),

                      // Logo & App Title
                      Column(
                        children: [
                          // Logo
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.zero,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                width: 150,
                                height: 150,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 150,
                                    height: 150,
                                    color: Colors.white,
                                    child: Icon(
                                      Icons.medical_services_rounded,
                                      size: 80,
                                      color: primaryColor,
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                              .animate()
                              .scale(delay: 100.ms, duration: 400.ms)
                              .fadeIn(duration: 300.ms),
                          const SizedBox(height: 24),

                          // App Name
                          Text(
                            'ProDoc',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : primaryColor,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 400.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            localizations?.medicalPracticeManagement ??
                                'Medical Practice Management',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                          const SizedBox(height: 4),

                          // Powered by
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${localizations?.poweredBy ?? 'Powered by'} ',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                'Nextpital.com',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Welcome Text
                      Text(
                        localizations?.welcome ?? 'Welcome',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 400.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        localizations?.signInToContinue ??
                            'Sign in to continue',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                      const SizedBox(height: 40),

                      if (_showResetForm) ...[
                        // Reset Password Form
                        _buildResetPasswordForm(
                            isDark, primaryColor, authState, localizations),
                      ] else ...[
                        // Login Form
                        _buildLoginForm(
                            isDark, primaryColor, authState, localizations),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(bool isDark, Color primaryColor, AuthState authState,
      AppLocalizations? localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Login method toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: Text(
                localizations?.email ?? 'Email',
                style: GoogleFonts.poppins(),
              ),
              selected: _loginMethod == 'email',
              onSelected: (_) {
                setState(() {
                  _loginMethod = 'email';
                });
              },
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: Text(
                localizations?.phone ?? 'Phone',
                style: GoogleFonts.poppins(),
              ),
              selected: _loginMethod == 'phone',
              onSelected: (_) {
                setState(() {
                  _loginMethod = 'phone';
                });
              },
            ),
          ],
        )
            .animate()
            .fadeIn(delay: 450.ms, duration: 400.ms)
            .slideX(begin: -0.05, end: 0),
        const SizedBox(height: 16),

        // Identifier Field (Email or Phone)
        Container(
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
            controller: _identifierController,
            keyboardType: _loginMethod == 'phone'
                ? TextInputType.phone
                : TextInputType.emailAddress,
            style: GoogleFonts.poppins(),
            onChanged: _handleIdentifierChange,
            decoration: InputDecoration(
              labelText: _loginMethod == 'phone'
                  ? (localizations?.phone ?? 'Phone Number')
                  : (localizations?.email ?? 'Email Address'),
              labelStyle: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(
                _loginMethod == 'phone'
                    ? Icons.phone_rounded
                    : Icons.email_rounded,
                color: primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
            validator: (value) {
              print('🔍 Validator Debug:');
              print('  - Login Method: $_loginMethod');
              print('  - Value: $value');

              if (value == null || value.isEmpty) {
                final error = _loginMethod == 'phone'
                    ? 'Please enter your phone number'
                    : (localizations?.pleaseEnterEmail ??
                        'Please enter your email');
                print('  - Validation Error (empty): $error');
                return error;
              }

              if (_loginMethod == 'phone') {
                final numbersOnly =
                    value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
                print('  - Numbers only: $numbersOnly');
                if (!RegExp(r'^\d{8,}$').hasMatch(numbersOnly)) {
                  final error = 'Please enter a valid phone number';
                  print('  - Validation Error (invalid phone): $error');
                  return error;
                }
                print('  - Phone validation passed');
              } else {
                if (!value.contains('@')) {
                  final error = localizations?.pleaseEnterValidEmail ??
                      'Please enter a valid email';
                  print('  - Validation Error (invalid email): $error');
                  return error;
                }
                print('  - Email validation passed');
              }
              print('  - Validation passed');
              return null;
            },
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 400.ms)
            .slideX(begin: -0.1, end: 0),
        const SizedBox(height: 20),

        // Password Field
        Container(
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
            controller: _passwordController,
            obscureText: !_showPassword,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: localizations?.password ?? 'Password',
              labelStyle: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(
                Icons.lock_rounded,
                color: primaryColor,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations?.pleaseEnterPassword ??
                    'Please enter your password';
              }
              return null;
            },
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideX(begin: -0.1, end: 0),
        const SizedBox(height: 16),

        // Remember Me & Forgot Password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                  activeColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _rememberMe = !_rememberMe;
                    });
                  },
                  child: Text(
                    localizations?.rememberMe ?? 'Remember me',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showResetForm = true;
                });
              },
              child: Text(
                localizations?.forgotPassword ?? 'Forgot Password?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
        const SizedBox(height: 24),

        // Login Button
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
              onTap: authState.isLoading ? null : _handleLogin,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: authState.isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        localizations?.login ?? 'Login',
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
        )
            .animate()
            .fadeIn(delay: 800.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 24),

        // Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.shade300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                localizations?.or ?? 'OR',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.shade300,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
        const SizedBox(height: 24),

        // Google Sign-In Button
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: authState.isLoading
                  ? null
                  : () {
                      ref.read(authProvider.notifier).registerWithGoogle();
                    },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google Logo
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const GoogleLogoWidget(size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      localizations?.continueWithGoogle ??
                          'Continue with Google',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 1000.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),

        // Apple Sign-In Button
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: authState.isLoading
                  ? null
                  : () {
                      ref.read(authProvider.notifier).registerWithApple();
                    },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Apple Logo
                    Icon(
                      Icons.apple,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Apple',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 1100.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 24),

        // Sign Up Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${localizations?.dontHaveAccount ?? "Don't have an account?"} ",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RegisterScreen(),
                  ),
                );
              },
              child: Text(
                localizations?.register ?? 'Register',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 1100.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildResetPasswordForm(bool isDark, Color primaryColor,
      AuthState authState, AppLocalizations? localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
            controller: _resetEmailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: localizations?.email ?? 'Email Address',
              labelStyle: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(
                Icons.email_rounded,
                color: primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations?.pleaseEnterEmail ??
                    'Please enter your email';
              }
              if (!value.contains('@')) {
                return localizations?.pleaseEnterValidEmail ??
                    'Please enter a valid email';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
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
              onTap: authState.isLoading ? null : _handleForgotPassword,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: authState.isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        localizations?.sendResetLink ?? 'Send Reset Link',
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
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _showResetForm = false;
              _resetEmailController.clear();
            });
          },
          child: Text(
            '← ${localizations?.backToLogin ?? 'Back to Login'}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
