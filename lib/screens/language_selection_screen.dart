// lib/screens/language_selection_screen.dart - Language Selection Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/locale_providers.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  Locale? _selectedLocale;

  final List<Map<String, dynamic>> _languages = [
    {
      'locale': const Locale('en', 'US'),
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇬🇧',
    },
    {
      'locale': const Locale('fr', 'FR'),
      'name': 'French',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
    {
      'locale': const Locale('ar', 'SA'),
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set default selection to English
    _selectedLocale = _languages[0]['locale'] as Locale;
  }

  Future<void> _onContinue() async {
    if (_selectedLocale != null) {
      final localeNotifier = ref.read(localeProvider.notifier);
      await localeNotifier.setLocale(_selectedLocale!);

      if (!mounted) return;

      // Navigate back to splash screen which will handle the rest
      // Use pushAndRemoveUntil to clear the stack and go to splash
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/splash',
        (route) => false,
      );
    }
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.zero,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medical_services_rounded,
                            size: 70,
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
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 40),

                // Welcome Text
                Text(
                  'Welcome',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : primaryColor,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
                    begin: 0.3,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOut),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Please select your preferred language',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOut),

                const SizedBox(height: 48),

                // Language Options
                ..._languages.map((language) {
                  final locale = language['locale'] as Locale;
                  final name = language['name'] as String;
                  final nativeName = language['nativeName'] as String;
                  final flag = language['flag'] as String;
                  final isSelected = _selectedLocale == locale;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _LanguageOptionCard(
                      flag: flag,
                      name: name,
                      nativeName: nativeName,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedLocale = locale;
                        });
                      },
                    )
                        .animate()
                        .fadeIn(
                            delay: 600.ms +
                                (_languages.indexOf(language) * 100).ms,
                            duration: 400.ms)
                        .slideX(
                            begin: -0.2,
                            end: 0,
                            delay: 600.ms +
                                (_languages.indexOf(language) * 100).ms,
                            duration: 400.ms,
                            curve: Curves.easeOut),
                  );
                }).toList(),

                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1000.ms, duration: 400.ms)
                    .scale(delay: 1000.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOptionCard extends StatelessWidget {
  final String flag;
  final String name;
  final String nativeName;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionCard({
    required this.flag,
    required this.name,
    required this.nativeName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Flag
            Text(
              flag,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            // Language Names
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nativeName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Selection Indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: primaryColor,
                size: 28,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
