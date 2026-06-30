// lib/screens/tenant_selection_screen.dart - Premium Medical UI
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/tenant_providers.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';
import 'public_appointment_booking_screen.dart';

final tenantSearchQueryProvider = NotifierProvider<TenantSearchQueryNotifier, String>(TenantSearchQueryNotifier.new);

class TenantSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void update(String value) => state = value;
}

class TenantSelectionScreen extends ConsumerStatefulWidget {
  const TenantSelectionScreen({super.key});

  @override
  ConsumerState<TenantSelectionScreen> createState() =>
      _TenantSelectionScreenState();
}

class _TenantSelectionScreenState extends ConsumerState<TenantSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(tenantSearchQueryProvider);
    final tenantListAsync = ref.watch(tenantListProvider(searchQuery));
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
                    const Color(0xFF0A0E27),
                    const Color(0xFF1A1F3A),
                    const Color(0xFF2A2F4A),
                  ]
                : [
                    const Color(0xFFF0F9FF),
                    const Color(0xFFE0F2FE),
                    const Color(0xFFBAE6FD),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background circles
            if (_pulseController != null)
              ...List.generate(3, (index) {
                return Positioned(
                  top: -100 + (index * 200.0),
                  right: -50 + (index * 100.0),
                  child: AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (context, child) {
                      return Container(
                        width: 300 - (index * 50.0),
                        height: 300 - (index * 50.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              primaryColor
                                  .withOpacity(0.1 * _pulseController!.value),
                              primaryColor.withOpacity(0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            SafeArea(
              child: Column(
                children: [
                  // Modern Header with Glass Effect
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Logo with gradient border
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryColor.withOpacity(0.8),
                                          primaryColor,
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.medical_services_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                            .animate(
                                onPlay: (controller) => controller.repeat())
                            .shimmer(
                                delay: 2000.ms,
                                duration: 1500.ms,
                                color: primaryColor.withOpacity(0.3)),
                        const SizedBox(height: 20),
                        // App Name with Gradient
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.7),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'ProDoc',
                            style: GoogleFonts.poppins(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .slideY(begin: 0.2, end: 0),
                        const SizedBox(height: 8),
                        // Subtitle with animation
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.15),
                                primaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Text(
                                'Medical Office Management',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : primaryColor,
                                  letterSpacing: 0.5,
                                ),
                              );
                            },
                          ),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                    ),
                  ),

                  // Search Bar with modern design
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: searchQuery.isNotEmpty
                              ? primaryColor.withOpacity(0.5)
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: searchQuery.isNotEmpty
                                ? primaryColor.withOpacity(0.2)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search for your medical office...',
                          hintStyle: GoogleFonts.poppins(
                            color:
                                isDark ? Colors.white60 : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.7)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                            tenantSearchQueryProvider.notifier)
                                        .update('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          ref.read(tenantSearchQueryProvider.notifier).update(
                              value);
                        },
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 500.ms)
                        .slideY(begin: 0.2, end: 0),
                  ),

                  const SizedBox(height: 24),

                  // Tenant List with enhanced cards
                  Expanded(
                    child: tenantListAsync.when(
                      data: (tenants) {
                        final validTenants = tenants
                            .where((tenant) =>
                                tenant.baseUrl != null &&
                                tenant.baseUrl!.isNotEmpty)
                            .toList();

                        if (validTenants.isEmpty) {
                          return _buildEmptyState(
                              isDark, primaryColor, searchQuery);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: validTenants.length,
                          itemBuilder: (context, index) {
                            final tenant = validTenants[index];
                            return _buildTenantCard(
                              context,
                              tenant,
                              index,
                              isDark,
                              primaryColor,
                            );
                          },
                        );
                      },
                      loading: () => _buildLoadingState(isDark, primaryColor),
                      error: (error, stack) =>
                          _buildErrorState(isDark, primaryColor, searchQuery),
                    ),
                  ),

                  // Modern Footer
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Powered by ',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.7)
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Nextpital.com',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantCard(
    BuildContext context,
    tenant,
    int index,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.white, Colors.white.withOpacity(0.95)],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await ref
                .read(selectedTenantProvider.notifier)
                .selectTenant(tenant);
            if (context.mounted) {
              _showModernOptionsDialog(context, tenant, isDark, primaryColor);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Modern Icon Container
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    size: 35,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // Tenant Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            tenant.name ?? 'Unknown Office',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      if (tenant.city != null) ...[
                        _buildInfoChip(
                          Icons.location_on_rounded,
                          tenant.city!,
                          isDark,
                          primaryColor,
                        ),
                      ],
                      if (tenant.phone != null) ...[
                        const SizedBox(height: 6),
                        _buildInfoChip(
                          Icons.phone_rounded,
                          tenant.phone!,
                          isDark,
                          primaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow with gradient
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (500 + (index * 80)).ms, duration: 500.ms)
        .slideX(begin: 0.2, end: 0)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildInfoChip(
      IconData icon, String text, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: primaryColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryColor, String searchQuery) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  searchQuery.isEmpty
                      ? Icons.business_outlined
                      : Icons.search_off_rounded,
                  size: 80,
                  color: primaryColor,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2000.ms),
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    searchQuery.isEmpty
                        ? 'No office available'
                        : 'No results found',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    searchQuery.isEmpty
                        ? 'Please contact your administrator'
                        : 'Try other keywords',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              if (searchQuery.isNotEmpty) ...[
                const SizedBox(height: 32),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildActionButton(
                        'Clear search',
                        Icons.clear_rounded,
                        primaryColor,
                        () {
                          _searchController.clear();
                          ref.read(tenantSearchQueryProvider.notifier).update('');
                        },
                        isOutlined: true,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark, Color primaryColor) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.2),
                    primaryColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Loading offices...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, Color primaryColor, String searchQuery) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.1),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    'Loading error',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    'Unable to load offices',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.9,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildActionButton(
                            'Retry',
                            Icons.refresh_rounded,
                            primaryColor,
                            () =>
                                ref.invalidate(tenantListProvider(searchQuery)),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color primaryColor,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isOutlined
            ? null
            : LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
              ),
        borderRadius: BorderRadius.circular(16),
        border: isOutlined ? Border.all(color: primaryColor, width: 2) : null,
        boxShadow: isOutlined
            ? null
            : [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isOutlined ? primaryColor : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isOutlined ? primaryColor : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showModernOptionsDialog(
    BuildContext context,
    tenant,
    bool isDark,
    Color primaryColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1A1F3A),
                    const Color(0xFF0A0E27),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8FEFF),
                  ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.5)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Tenant Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.15),
                    primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              tenant.name ?? 'Unknown Office',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            );
                          },
                        ),
                        if (tenant.city != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tenant.city!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
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
            const SizedBox(height: 32),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Choose an option',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'How would you like to continue?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 28),
            // Login Button with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.login_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'I already have an account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0)
                .scale(begin: const Offset(0.95, 0.95)),
            const SizedBox(height: 16),
            // Book Appointment Button with modern design
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryColor.withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PublicAppointmentBookingScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Book Appointment',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'No account required',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0)
                .scale(begin: const Offset(0.95, 0.95)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
