// lib/screens/splash_screen.dart - ProDoc Splash Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_providers.dart';
import '../providers/tenant_providers.dart';
import '../providers/locale_providers.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'tenant_selection_screen.dart';
import 'language_selection_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for minimum splash duration (2 seconds) for better UX
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if this is the first launch (no language selected)
    final localeNotifier = ref.read(localeProvider.notifier);
    final isFirstLaunch = await localeNotifier.isFirstLaunch();

    if (isFirstLaunch) {
      // Show language selection screen on first launch
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
      );
      return;
    }

    // Wait for tenant to be loaded from storage
    final tenantNotifier = ref.read(selectedTenantProvider.notifier);
    await tenantNotifier.waitForLoad();

    if (!mounted) return;

    // Wait for auth state to be ready (not loading)
    AuthState authState = ref.read(authProvider);
    int maxWaitAttempts = 20; // Wait up to 2 seconds (20 * 100ms)
    int attempts = 0;
    while (authState.isLoading && attempts < maxWaitAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      authState = ref.read(authProvider);
      attempts++;
    }

    if (!mounted) return;

    final selectedTenant = ref.read(selectedTenantProvider);

    // Navigate based on app state
    Widget nextScreen;
    if (authState.isAuth == true) {
      nextScreen = const DashboardScreen();
    } else if (selectedTenant == null) {
      nextScreen = const TenantSelectionScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo Container
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.zero,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      width: 180,
                      height: 180,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medical_services_rounded,
                            size: 100,
                            color: primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 600.ms)
                    .then()
                    .shimmer(
                      delay: 300.ms,
                      duration: 1000.ms,
                      color: primaryColor.withOpacity(0.3),
                    ),

                const SizedBox(height: 40),

                // App Name with Animation
                Text(
                  'ProDoc',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : primaryColor,
                    letterSpacing: 2,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 600.ms,
                        curve: Curves.easeOut)
                    .then()
                    .shimmer(
                      delay: 200.ms,
                      duration: 1200.ms,
                      color: primaryColor.withOpacity(0.2),
                    ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Gestion Cabinet Médical',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOut),

                const SizedBox(height: 60),

                // Loading Indicator
                Container(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1000.ms, duration: 400.ms)
                    .scale(delay: 1000.ms, duration: 400.ms),

                const SizedBox(height: 24),

                // Loading Text
                Text(
                  'Chargement...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 1200.ms, duration: 400.ms),

                const Spacer(),

                // Powered by Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Powered by ',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey.shade500,
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
                  ),
                ).animate().fadeIn(delay: 1400.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
