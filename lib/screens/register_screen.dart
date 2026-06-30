// lib/screens/register_screen.dart - Modern Medical UI with Logo
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/google_logo_widget.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                'Passwords do not match',
                style: GoogleFonts.poppins(),
              );
            },
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _confirmPasswordController.text,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Redirect to dashboard if authenticated
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuth == true && previous?.isAuth != true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    });

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
            opacity: isDark ? 0.15 : 0.20,
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
                      const SizedBox(height: 20),

                      // Logo & App Title
                      Column(
                        children: [
                          // Logo
                          Container(
                            width: 100,
                            height: 100,
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
                                width: 100,
                                height: 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.white,
                                    child: Icon(
                                      Icons.person_add_rounded,
                                      size: 50,
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
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : primaryColor,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 150.ms, duration: 400.ms)
                              .slideY(begin: 0.1, end: 0),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Welcome Text
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Column(
                            children: [
                              Text(
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              )
                                  .animate()
                                  .fadeIn(delay: 200.ms, duration: 400.ms)
                                  .slideY(begin: 0.1, end: 0),
                              const SizedBox(height: 8),
                              Text(
                                'Sign up to get started',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              )
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 400.ms),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Name Field
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                            delay: 400,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                            delay: 500,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Phone Field (Optional)
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildTextField(
                            controller: _phoneController,
                            label: 'Phone (optional)',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: null,
                            isDark: isDark,
                            primaryColor: primaryColor,
                            delay: 600,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildPasswordField(
                            controller: _passwordController,
                            label: 'Password',
                            showPassword: _showPassword,
                            onTogglePassword: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must contain at least 6 characters';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                            delay: 700,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Confirm Password Field
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            showPassword: _showConfirmPassword,
                            onTogglePassword: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            isDark: isDark,
                            primaryColor: primaryColor,
                            delay: 800,
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Register Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8)
                            ],
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
                            onTap: authState.isLoading ? null : _handleRegister,
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
                                  : Builder(
                                      builder: (context) {
                                        final localizations =
                                            AppLocalizations.of(context);
                                        return Text(
                                          'Sign Up',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 900.ms, duration: 400.ms)
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
                            child: Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'OR',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
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
                      ).animate().fadeIn(delay: 950.ms, duration: 400.ms),
                      const SizedBox(height: 24),

                      // Google Sign-In Button
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.grey.shade300,
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
                                    ref
                                        .read(authProvider.notifier)
                                        .registerWithGoogle();
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
                                  Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return Text(
                                        'Continue with Google',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      );
                                    },
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
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.grey.shade300,
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
                                    ref
                                        .read(authProvider.notifier)
                                        .registerWithApple();
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
                                  Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return Text(
                                        'Continue with Apple',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      );
                                    },
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

                      // Sign In Link
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  'Sign In',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 1000.ms, duration: 400.ms);
                        },
                      ),

                      const SizedBox(height: 20),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required bool isDark,
    required Color primaryColor,
    required int delay,
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
          prefixIcon: Icon(
            icon,
            color: primaryColor,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        validator: validator,
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideX(begin: -0.1, end: 0);
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onTogglePassword,
    String? Function(String?)? validator,
    required bool isDark,
    required Color primaryColor,
    required int delay,
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
        obscureText: !showPassword,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
          prefixIcon: Icon(
            Icons.lock_rounded,
            color: primaryColor,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              showPassword
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
            onPressed: onTogglePassword,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        validator: validator,
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideX(begin: -0.1, end: 0);
  }
}
