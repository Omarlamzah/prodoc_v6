import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

import '../core/utils/result.dart';
import '../data/models/appointment_model.dart';
import '../data/models/service_model.dart';
import '../models/invoice.dart';
import '../providers/appointment_providers.dart';
import '../core/config/api_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/locale_providers.dart';
import '../providers/service_providers.dart';
import '../providers/api_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/whatsapp_status_badge.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';
import 'create_appointment_screen.dart';
import 'public_appointment_booking_screen.dart';
import 'doctor_calendar_screen.dart';
import 'patient_detail_screen.dart';
import '../data/models/time_slot_model.dart';
import '../providers/appointment_calendar_providers.dart';
import '../providers/tenant_website_providers.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'create_invoice_screen.dart';
import 'invoices_screen.dart';

// Helper extension to safely access localization strings
extension AppLocalizationsExtension on AppLocalizations? {
  // Helper method to safely get a string with fallback
  // This allows us to use keys that may not exist yet in AppLocalizations
  String getString(String key, String fallback) {
    if (this == null) return fallback;
    // For now, just return fallback since many keys don't exist yet
    // This will be replaced when keys are added to AppLocalizations
    return fallback;
  }
}

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedAppointments = <int>{};
  Timer? _debounce;

  String _searchTerm = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _serviceFilter = 'all';
  String _timeFilter = 'day';
  bool _showStatistics = false;
  bool _showAdvancedFilters = false; // New: Collapsible advanced filters
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  bool _isGridView = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController
      _filtersController; // New: For filter expansion animation
  late Animation<double> _filtersAnimation;

  // Suggested Color Scheme for good UI/UX in medical/appointment app:
  // Primary: Calm blue for trust/actions (#1976D2)
  // Secondary: Soft green for success/completed (#388E3C)
  // Error: Red for warnings/cancelled (#D32F2F)
  // Background: Light neutral (#FAFAFA)
  // Surface: White (#FFFFFF)
  // OnPrimary: White text on primary (#FFFFFF)
  // These can be set in your ThemeData if not already.

  DateFormat _getDateFormatter() {
    final locale = ref.watch(localeProvider).locale;
    return DateFormat('dd MMM yyyy', locale.toString());
  }

  DateFormat _getDateTimeFormatter() {
    final locale = ref.watch(localeProvider).locale;
    return DateFormat('dd MMM yyyy HH:mm', locale.toString());
  }

  static final DateFormat _apiFormatter = DateFormat('yyyy-MM-dd');

  // Format date with relative time (like Next.js formatDateWithRelative)
  String _formatDateWithRelative(AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    if (appointment.appointmentDate == null ||
        appointment.appointmentTime == null) {
      return 'Unknown date';
    }

    try {
      final dateStr = appointment.appointmentDate!;
      final timeStr = appointment.appointmentTime!.substring(0, 5); // Get HH:mm
      final dateTimeStr = '$dateStr $timeStr:00';
      final appointmentDateTime = DateTime.parse(dateTimeStr);

      final formattedDate = _getDateTimeFormatter().format(appointmentDateTime);
      final now = DateTime.now();
      final difference = now.difference(appointmentDateTime);

      String relativeTime;
      final isFrench = ref.watch(localeProvider).locale.languageCode == 'fr';

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        relativeTime = isFrench
            ? (years == 1 ? 'il y a 1 an' : 'il y a $years ans')
            : (years == 1 ? '1 year ago' : '$years years ago');
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        relativeTime = isFrench
            ? (months == 1 ? 'il y a 1 mois' : 'il y a $months mois')
            : (months == 1 ? '1 month ago' : '$months months ago');
      } else if (difference.inDays > 0) {
        relativeTime = isFrench
            ? (difference.inDays == 1
                ? 'il y a 1 jour'
                : 'il y a ${difference.inDays} jours')
            : (difference.inDays == 1
                ? '1 day ago'
                : '${difference.inDays} days ago');
      } else if (difference.inHours > 0) {
        relativeTime = isFrench
            ? (difference.inHours == 1
                ? 'il y a 1 heure'
                : 'il y a ${difference.inHours} heures')
            : (difference.inHours == 1
                ? '1 hour ago'
                : '${difference.inHours} hours ago');
      } else if (difference.inMinutes > 0) {
        relativeTime = isFrench
            ? (difference.inMinutes == 1
                ? 'il y a 1 minute'
                : 'il y a ${difference.inMinutes} minutes')
            : (difference.inMinutes == 1
                ? '1 minute ago'
                : '${difference.inMinutes} minutes ago');
      } else {
        relativeTime = isFrench ? 'à l\'instant' : 'just now';
      }

      // For future dates
      if (appointmentDateTime.isAfter(now)) {
        final futureDiff = appointmentDateTime.difference(now);
        if (futureDiff.inDays > 0) {
          relativeTime = isFrench
              ? (futureDiff.inDays == 1
                  ? 'dans 1 jour'
                  : 'dans ${futureDiff.inDays} jours')
              : (futureDiff.inDays == 1
                  ? 'in 1 day'
                  : 'in ${futureDiff.inDays} days');
        } else if (futureDiff.inHours > 0) {
          relativeTime = isFrench
              ? (futureDiff.inHours == 1
                  ? 'dans 1 heure'
                  : 'dans ${futureDiff.inHours} heures')
              : (futureDiff.inHours == 1
                  ? 'in 1 hour'
                  : 'in ${futureDiff.inHours} hours');
        } else {
          relativeTime = isFrench ? 'bientôt' : 'soon';
        }
      }

      return '$formattedDate ($relativeTime)';
    } catch (e) {
      final localizations = AppLocalizations.of(context);
      return localizations?.invalidDate ?? 'Invalid date';
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _filtersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _filtersAnimation = CurvedAnimation(
      parent: _filtersController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _filtersController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  AppointmentsParams _currentParams() {
    return AppointmentsParams(
      page: _currentPage,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      status: _statusFilter == 'all' ? null : _statusFilter,
      priority: _priorityFilter == 'all' ? null : _priorityFilter,
      startDate: _startDate != null ? _apiFormatter.format(_startDate!) : null,
      endDate: _endDate != null ? _apiFormatter.format(_endDate!) : null,
    );
  }

  Future<void> _refreshAppointments() async {
    await ref.refresh(appointmentsProvider(_currentParams()).future);
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchTerm = value.trim();
          _currentPage = 1;
          _selectedAppointments.clear();
        });
      }
    });
  }

  void _resetFilters() {
    if (mounted) {
      setState(() {
        _searchController.clear();
        _searchTerm = '';
        _statusFilter = 'all';
        _priorityFilter = 'all';
        _serviceFilter = 'all';
        _timeFilter = 'day';
        _startDate = null;
        _endDate = null;
        _currentPage = 1;
        _selectedAppointments.clear();
      });
    }
  }

  void _toggleSelection(int? appointmentId) {
    if (appointmentId == null || !mounted) return;
    if (mounted) {
      setState(() {
        if (_selectedAppointments.contains(appointmentId)) {
          _selectedAppointments.remove(appointmentId);
        } else {
          _selectedAppointments.add(appointmentId);
        }
      });
    }
  }

  List<AppointmentModel> _applyClientFilters(
      List<AppointmentModel> appointments) {
    final now = DateTime.now();
    return appointments.where((appointment) {
      final serviceMatches = _serviceFilter == 'all' ||
          appointment.service?.id?.toString() == _serviceFilter;

      final localSearch = _searchTerm.toLowerCase();
      final matchesSearch = _searchTerm.isEmpty ||
          [
            appointment.patient?.user?.name,
            appointment.patient?.cniNumber,
            appointment.doctor?.user?.name,
            appointment.service?.title,
            appointment.notes,
            appointment.id?.toString(),
          ]
              .whereType<String>()
              .any((entry) => entry.toLowerCase().contains(localSearch));

      final appointmentDate = _parseAppointmentDate(appointment);

      bool matchesTime = true;
      if (_startDate != null || _endDate != null) {
        final start = _startDate ?? appointmentDate;
        final end = _endDate ?? appointmentDate;
        if (appointmentDate != null && start != null && end != null) {
          matchesTime =
              !appointmentDate.isBefore(start) && !appointmentDate.isAfter(end);
        }
      } else if (_timeFilter != 'all') {
        if (appointmentDate == null) {
          matchesTime = false;
        } else {
          switch (_timeFilter) {
            case 'day':
              matchesTime = appointmentDate.year == now.year &&
                  appointmentDate.month == now.month &&
                  appointmentDate.day == now.day;
              break;
            case 'week':
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              final weekEnd = weekStart.add(const Duration(days: 6));
              matchesTime = !appointmentDate.isBefore(weekStart) &&
                  !appointmentDate.isAfter(weekEnd);
              break;
            case 'month':
              matchesTime = appointmentDate.year == now.year &&
                  appointmentDate.month == now.month;
              break;
          }
        }
      }

      return serviceMatches && matchesSearch && matchesTime;
    }).toList()
      ..sort((a, b) {
        final dateA = _parseAppointmentDate(a) ?? DateTime(1900);
        final dateB = _parseAppointmentDate(b) ?? DateTime(1900);
        final comparison = dateB.compareTo(dateA);
        if (comparison != 0) return comparison;
        return (b.appointmentTime ?? '').compareTo(a.appointmentTime ?? '');
      });
  }

  DateTime? _parseAppointmentDate(AppointmentModel appointment) {
    if (appointment.appointmentDate == null) return null;
    try {
      return DateTime.parse(appointment.appointmentDate!);
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _computeStatusCounts(List<AppointmentModel> appointments) {
    final counts = <String, int>{
      'scheduled': 0,
      'completed': 0,
      'cancelled': 0,
      'no_show': 0,
    };
    for (final appointment in appointments) {
      final status = appointment.status ?? 'scheduled';
      counts.update(status, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> _computePriorityCounts(List<AppointmentModel> appointments) {
    final counts = <String, int>{
      'high': 0,
      'medium': 0,
      'low': 0,
    };
    for (final appointment in appointments) {
      final priority = appointment.priority ?? 'medium';
      counts.update(priority, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale provider to rebuild when language changes
    ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider(_currentParams()));
    final servicesAsync = ref.watch(servicesProvider);

    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600 && size.width < 900;
    final isDesktop = size.width >= 900;
    final isMobile = size.width < 600;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      floatingActionButton: _buildModernFAB(context, authState),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, authState, isDesktop, isMobile),
            // Compact Filters Section
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: 8,
                ),
                child: _buildCompactFiltersCard(
                    context,
                    _extractServices(servicesAsync),
                    isDark,
                    isDesktop,
                    isTablet,
                    isMobile),
              ),
            ),
            // Advanced filters as collapsible section
            if (_showAdvancedFilters)
              SliverToBoxAdapter(
                child: SizeTransition(
                  sizeFactor: _filtersAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                      vertical: 8,
                    ),
                    child: _buildAdvancedFiltersCard(
                        context,
                        _extractServices(servicesAsync),
                        isDark,
                        isDesktop,
                        isTablet,
                        isMobile),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
              ),
              sliver: appointmentsAsync.when(
                data: (result) {
                  if (result is Failure<List<AppointmentModel>>) {
                    return SliverToBoxAdapter(
                      child: CustomErrorWidget(
                        message: result.message,
                        onRetry: _refreshAppointments,
                      ),
                    );
                  }
                  if (result is Success<List<AppointmentModel>>) {
                    final filteredAppointments =
                        _applyClientFilters(result.data);
                    return SliverMainAxisGroup(
                      slivers: [
                        if (_showStatistics)
                          SliverToBoxAdapter(
                            child: _buildStatisticsSection(
                                filteredAppointments, isDark, isDesktop),
                          ),
                        if (_selectedAppointments.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildSelectionToolbar(isDark),
                          ),
                        if (filteredAppointments.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody:
                                false, // Add this to prevent child scrolling issues
                            child: _buildEmptyState(isDark),
                          )
                        else
                          _buildAppointmentsList(
                            filteredAppointments,
                            isDesktop,
                            isTablet,
                            isMobile,
                          ),
                        SliverToBoxAdapter(
                          child: _buildPaginationControls(
                              result.data.isEmpty, isDesktop),
                        ),
                      ],
                    );
                  }
                  return const SliverFillRemaining(child: SizedBox.shrink());
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: LoadingWidget()),
                ),
                error: (error, stackTrace) => SliverToBoxAdapter(
                  child: CustomErrorWidget(
                    message: error.toString(),
                    onRetry: _refreshAppointments,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    AuthState authState,
    bool isDesktop,
    bool isMobile,
  ) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        localizations?.appointments ?? 'Appointments',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        if (isDesktop)
          IconButton(
            icon: Icon(_isGridView
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
            tooltip: _isGridView
                ? (localizations?.listView ?? 'List view')
                : (localizations?.gridView ?? 'Grid view'),
            onPressed: () {
              if (mounted) setState(() => _isGridView = !_isGridView);
            },
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: localizations?.refresh ?? 'Refresh',
          onPressed: _refreshAppointments,
        ),
      ],
    );
  }

  Widget _buildModernFAB(BuildContext context, AuthState authState) {
    final localizations = AppLocalizations.of(context);
    return FloatingActionButton.extended(
      onPressed: () => _showQuickActionsSheet(context, authState),
      label: Text(localizations?.quickActions ?? 'Quick Actions'),
      icon: const Icon(Icons.add_rounded),
      elevation: 4,
      backgroundColor: const Color(0xFF1976D2),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? const Color(0xFF1F1F25) : const Color(0xFFFFFFFF),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: const Color(0xFF1976D2)),
              const SizedBox(height: 6),
              Text(
                label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context, AuthState authState) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A2E).withOpacity(0.98)
              : Colors.white.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flash_on_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    localizations?.quickActions ?? 'Quick Actions',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Quick Actions Grid
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    // Nouveau Rendez-vous
                    if (authState.user?.isAdmin == 1 ||
                        authState.user?.isReceptionist == 1 ||
                        authState.user?.isPatient == 1)
                      _buildQuickActionCard(
                        context: ctx,
                        icon: Icons.add_circle_rounded,
                        title: localizations?.createAppointment ??
                            'New Appointment',
                        subtitle: localizations?.newAppointment ??
                            'Create appointment',
                        color: const Color(0xFF1976D2),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (authState.user?.isPatient == 1) {
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const PublicAppointmentBookingScreen(),
                              ),
                            );
                          } else {
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const CreateAppointmentScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    // Calendrier
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.calendar_month_rounded,
                      title: localizations?.calendar ?? 'Calendar',
                      subtitle: localizations?.calendarView ?? 'View calendar',
                      color: const Color(0xFF388E3C),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => const CalendarScreen(),
                          ),
                        );
                      },
                    ),
                    // Filtres
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.filter_list_rounded,
                      title:
                          localizations?.advancedFilters ?? 'Advanced Filters',
                      subtitle: 'Show filters',
                      color: const Color(0xFFFF9800),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                          if (_showAdvancedFilters) {
                            _filtersController.forward();
                          } else {
                            _filtersController.reverse();
                          }
                        });
                      },
                    ),
                    // Statistiques
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.bar_chart_rounded,
                      title: localizations?.statistics ?? 'Statistics',
                      subtitle:
                          localizations?.viewStatistics ?? 'View statistics',
                      color: const Color(0xFF9C27B0),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _showStatistics = !_showStatistics);
                      },
                    ),
                    // Actualiser
                    _buildQuickActionCard(
                      context: ctx,
                      icon: Icons.refresh_rounded,
                      title: localizations?.refresh ?? 'Refresh',
                      subtitle: localizations?.refreshList ?? 'Refresh list',
                      color: Colors.grey[600]!,
                      onTap: () {
                        Navigator.pop(ctx);
                        _refreshAppointments();
                        final localizations = AppLocalizations.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(localizations?.listRefreshed ??
                                'List refreshed'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width =
        (MediaQuery.of(context).size.width - 52) / 2; // 2 columns with spacing

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                  isDark ? const Color(0xFF1A1A2E) : Colors.white,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Compact filters card - Simplified design
  Widget _buildCompactFiltersCard(
    BuildContext context,
    List<ServiceModel> services,
    bool isDark,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF15151C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchField(context),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(
                    context,
                    label: localizations?.all ?? 'All',
                    isSelected: _statusFilter == 'all',
                    onTap: () => _updateFilter('status', 'all'),
                  ),
                  _buildFilterChip(
                    context,
                    label: _statusLabel('scheduled', localizations),
                    isSelected: _statusFilter == 'scheduled',
                    onTap: () => _updateFilter('status', 'scheduled'),
                  ),
                  _buildFilterChip(
                    context,
                    label: _statusLabel('completed', localizations),
                    isSelected: _statusFilter == 'completed',
                    onTap: () => _updateFilter('status', 'completed'),
                  ),
                  _buildFilterChip(
                    context,
                    label: _statusLabel('cancelled', localizations),
                    isSelected: _statusFilter == 'cancelled',
                    onTap: () => _updateFilter('status', 'cancelled'),
                  ),
                  // Advanced filters button with text
                  Material(
                    color: _showAdvancedFilters
                        ? const Color(0xFF1976D2).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                          if (_showAdvancedFilters) {
                            _filtersController.forward();
                          } else {
                            _filtersController.reverse();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: _showAdvancedFilters
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showAdvancedFilters
                                  ? (localizations?.hideAdvancedFilters ??
                                      'Hide Advanced Filters')
                                  : (localizations?.showAdvancedFilters ??
                                      'Show Advanced Filters'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _showAdvancedFilters
                                    ? const Color(0xFF1976D2)
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAdvancedFilters
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: _showAdvancedFilters
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Legacy method - keeping for compatibility
  Widget _buildBasicFiltersCard(
    BuildContext context,
    List<ServiceModel> services,
    bool isDark,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF15151C) : const Color(0xFFFFFFFF),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search or filter appointments',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // More visible advanced filters button
              Material(
                color: _showAdvancedFilters
                    ? const Color(0xFF1976D2).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _showAdvancedFilters = !_showAdvancedFilters;
                      if (_showAdvancedFilters) {
                        _filtersController.forward();
                      } else {
                        _filtersController.reverse();
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _showAdvancedFilters
                              ? const Color(0xFF1976D2)
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Advanced',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _showAdvancedFilters
                                ? const Color(0xFF1976D2)
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showAdvancedFilters
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: _showAdvancedFilters
                              ? const Color(0xFF1976D2)
                              : Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(context),
          const SizedBox(height: 12),
          // Quick status chips instead of full dropdown for basic view
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFilterChip(
                context,
                label: localizations?.all ?? 'All',
                isSelected: _statusFilter == 'all',
                onTap: () => _updateFilter('status', 'all'),
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip(
                        context,
                        label: localizations?.all ?? 'All',
                        isSelected: _statusFilter == 'all',
                        onTap: () => _updateFilter('status', 'all'),
                      ),
                      _buildFilterChip(
                        context,
                        label: _statusLabel('scheduled', localizations),
                        isSelected: _statusFilter == 'scheduled',
                        onTap: () => _updateFilter('status', 'scheduled'),
                      ),
                      _buildFilterChip(
                        context,
                        label: _statusLabel('completed', localizations),
                        isSelected: _statusFilter == 'completed',
                        onTap: () => _updateFilter('status', 'completed'),
                      ),
                      _buildFilterChip(
                        context,
                        label: _statusLabel('cancelled', localizations),
                        isSelected: _statusFilter == 'cancelled',
                        onTap: () => _updateFilter('status', 'cancelled'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh),
                label: Text(localizations?.reset ?? 'Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2)
                      .withOpacity(0.15), // Suggested primary
                  foregroundColor: const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showComingSoon(
                    context,
                    'Export available soon.'
                    'Export available soon.'),
                icon: const Icon(Icons.download),
                label: Text('Export'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // New: Advanced filters in separate card
  Widget _buildAdvancedFiltersCard(
    BuildContext context,
    List<ServiceModel> services,
    bool isDark,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
        border: Border.all(
            color:
                const Color(0xFF1976D2).withOpacity(0.1)), // Suggested primary
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Advanced Filters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1976D2),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Priority, Service, Time dropdowns
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterDropdown(
                context,
                label: localizations?.priority ?? 'Priority',
                value: _priorityFilter,
                items: [
                  DropdownMenuItem(
                      value: 'all', child: Text(localizations?.all ?? 'All')),
                  DropdownMenuItem(
                      value: 'high',
                      child: Text(localizations?.high ?? 'High')),
                  DropdownMenuItem(
                      value: 'medium',
                      child: Text(localizations?.medium ?? 'Medium')),
                  DropdownMenuItem(
                      value: 'low', child: Text(localizations?.low ?? 'Low')),
                ],
                onChanged: (value) => _updateFilter('priority', value ?? 'all'),
              ),
              _buildFilterDropdown(
                context,
                label: localizations?.services ?? 'Service',
                value: _serviceFilter,
                items: [
                  DropdownMenuItem(
                      value: 'all', child: Text(localizations?.all ?? 'All')),
                  ...services.map(
                    (service) => DropdownMenuItem(
                      value: service.id?.toString(),
                      child: Text(service.title ?? 'Service'),
                    ),
                  ),
                ],
                onChanged: (value) => _updateFilter('service', value ?? 'all'),
              ),
              _buildFilterDropdown(
                context,
                label: localizations?.period ?? 'Period',
                value: _timeFilter,
                enabled: _startDate == null && _endDate == null,
                items: [
                  DropdownMenuItem(
                      value: 'day',
                      child: Text(localizations?.today ?? 'Today')),
                  DropdownMenuItem(
                      value: 'week',
                      child: Text(localizations?.thisWeek ?? 'This Week')),
                  DropdownMenuItem(
                      value: 'month',
                      child: Text(localizations?.thisMonth ?? 'This Month')),
                  DropdownMenuItem(
                      value: 'all', child: Text(localizations?.all ?? 'All')),
                ],
                onChanged: (value) => _updateFilter('time', value ?? 'day'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date pickers - Simplified layout
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(
                  context,
                  label: localizations?.start ?? 'Start',
                  date: _startDate,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePickerField(
                  context,
                  label: localizations?.end ?? 'End',
                  date: _endDate,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // New helper: Update filter with page reset
  void _updateFilter(String type, String value) {
    if (!mounted) return;
    setState(() {
      switch (type) {
        case 'status':
          _statusFilter = value;
          break;
        case 'priority':
          _priorityFilter = value;
          break;
        case 'service':
          _serviceFilter = value;
          break;
        case 'time':
          _timeFilter = value;
          break;
      }
      _currentPage = 1;
      _selectedAppointments.clear();
    });
  }

  // New: Filter chip for quick selection - Smaller text
  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 10), // Smaller text as requested
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor:
          const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
      selectedColor: const Color(0xFF1976D2).withOpacity(0.2),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: localizations?.searchPatientDoctorService ??
              'Search patient, doctor, service...',
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(Icons.search_rounded,
                color: Color(0xFF1976D2), size: 22),
          ),
          suffixIcon: _searchTerm.isEmpty
              ? IconButton(
                  icon: const Icon(Icons.mic_rounded, size: 20),
                  color: Colors.grey[600],
                  onPressed: () {
                    // Voice search placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice search coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Voice search',
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchTerm.isNotEmpty)
                      Text(
                        '${_searchTerm.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      color: Colors.grey[600],
                      onPressed: () {
                        _searchController.clear();
                        _handleSearchChanged('');
                      },
                      tooltip: localizations?.clear ?? 'Clear',
                    ),
                  ],
                ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F1F25) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1976D2),
              width: 2.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: _handleSearchChanged,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  List<ServiceModel> _extractServices(
      AsyncValue<Result<List<ServiceModel>>> servicesAsync) {
    return servicesAsync.when(
      data: (result) {
        if (result is Success<List<ServiceModel>>) {
          return result.data;
        }
        return <ServiceModel>[];
      },
      loading: () => <ServiceModel>[],
      error: (_, __) => <ServiceModel>[],
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: MediaQuery.of(context).size.width > 720
          ? 160
          : double.infinity, // Slightly smaller
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              onChanged: enabled ? onChanged : null,
              items: items,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2), // Suggested primary
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF6F7FB),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date == null
                        ? ('Select')
                        : _getDateFormatter().format(date),
                    style: TextStyle(
                      color: date == null
                          ? Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.6)
                          : null,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1976D2), // Suggested primary
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
        _currentPage = 1;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1976D2), // Suggested primary
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!)) {
          _startDate = picked;
        }
        _currentPage = 1;
      });
    }
  }

  Widget _buildStatisticsSection(
      List<AppointmentModel> appointments, bool isDark, bool isDesktop) {
    final localizations = AppLocalizations.of(context);
    final statusCounts = _computeStatusCounts(appointments);
    final priorityCounts = _computePriorityCounts(appointments);
    final total = appointments.length;

    Widget buildStatCard({
      required String label,
      required int value,
      required Color color,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFFFFFFF),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  total == 0
                      ? '0%'
                      : '${((value / total) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
            const Color(0xFF1976D2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations?.quickStatistics ?? 'Quick Statistics',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Switch.adaptive(
                value: _showStatistics,
                onChanged: (value) {
                  if (mounted) setState(() => _showStatistics = value);
                },
                activeColor: const Color(0xFF1976D2), // Suggested primary
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Responsive stats: Stack on mobile, row on desktop
          isDesktop
              ? Row(
                  children: [
                    Expanded(
                        child: buildStatCard(
                            label: localizations?.scheduled ?? 'Scheduled',
                            value: statusCounts['scheduled'] ?? 0,
                            color:
                                const Color(0xFF1976D2))), // Blue for scheduled
                    const SizedBox(width: 12),
                    Expanded(
                        child: buildStatCard(
                            label: localizations?.completed ?? 'Completed',
                            value: statusCounts['completed'] ?? 0,
                            color: const Color(
                                0xFF388E3C))), // Green for completed
                    const SizedBox(width: 12),
                    Expanded(
                        child: buildStatCard(
                            label: localizations?.cancelled ?? 'Cancelled',
                            value: statusCounts['cancelled'] ?? 0,
                            color:
                                const Color(0xFFD32F2F))), // Red for cancelled
                  ],
                )
              : Column(
                  children: [
                    buildStatCard(
                        label: localizations?.scheduled ?? 'Scheduled',
                        value: statusCounts['scheduled'] ?? 0,
                        color: const Color(0xFF1976D2)),
                    const SizedBox(height: 8),
                    buildStatCard(
                        label: localizations?.completed ?? 'Completed',
                        value: statusCounts['completed'] ?? 0,
                        color: const Color(0xFF388E3C)),
                    const SizedBox(height: 8),
                    buildStatCard(
                        label: localizations?.cancelled ?? 'Cancelled',
                        value: statusCounts['cancelled'] ?? 0,
                        color: const Color(0xFFD32F2F)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar(bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? const Color(0xFF1F1F25) : const Color(0xFFFFFFFF),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
              Expanded(
                child: Text(
                  '${_selectedAppointments.length} ${'selected'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (mounted) setState(() => _selectedAppointments.clear());
                },
                icon: const Icon(Icons.clear_all),
                label: Text(localizations?.clear ?? 'Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBulkStatusButton(
                context,
                label: localizations?.markAsCompleted ?? 'Mark as Completed',
                status: 'completed',
                color: const Color(0xFF388E3C),
                icon: Icons.check_circle_outline,
              ),
              _buildBulkStatusButton(
                context,
                label: localizations?.cancel ?? 'Cancel',
                status: 'cancelled',
                color: const Color(0xFFD32F2F),
                icon: Icons.cancel_outlined,
              ),
              _buildBulkStatusButton(
                context,
                label: localizations?.reschedule ?? 'Reschedule',
                status: 'scheduled',
                color: const Color(0xFF1976D2),
                icon: Icons.schedule,
              ),
              _buildBulkStatusButton(
                context,
                label: localizations?.noShow ?? 'No Show',
                status: 'no_show',
                color: Colors.grey,
                icon: Icons.person_off_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkStatusButton(
    BuildContext context, {
    required String label,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return OutlinedButton.icon(
      onPressed: _selectedAppointments.isEmpty
          ? null
          : () => _handleBulkStatusUpdate(status),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: color),
        foregroundColor: color,
      ),
    );
  }

  Future<void> _handleBulkStatusUpdate(String status) async {
    if (_selectedAppointments.isEmpty) return;

    final localizations = AppLocalizations.of(context);
    final statusLabel = _statusLabel(status, localizations);
    final count = _selectedAppointments.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.confirmation ?? 'Confirm'),
        content: Text(
          '${localizations?.doYouWantToChangeStatusOf ?? 'Do you really want to change the status of'} $count ${localizations?.appointmentsTo ?? 'appointments to'} "$statusLabel"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'cancelled'
                  ? const Color(0xFFD32F2F)
                  : status == 'completed'
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF1976D2),
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await ref.read(
        bulkUpdateAppointmentStatusProvider(
          BulkUpdateStatusParams(
            appointmentIds: _selectedAppointments.toList(),
            status: status,
          ),
        ).future,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      result.when(
        success: (data) {
          final updatedCount = data['updated_count'] as int? ?? 0;
          final failedCount = data['failed_count'] as int? ?? 0;

          final localizations = AppLocalizations.of(context);
          if (failedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$updatedCount ${localizations?.appointmentsUpdated ?? 'appointments updated'}, $failedCount ${localizations?.errorTitle ?? 'failed'}',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${localizations?.statusOfAppointmentsChanged ?? 'Status of'} $updatedCount ${localizations?.appointmentsTo ?? 'appointments changed to'} "$statusLabel"',
                ),
                backgroundColor: const Color(0xFF388E3C),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          // Clear selection and refresh
          if (mounted) {
            setState(() => _selectedAppointments.clear());
            _refreshAppointments();
          }
        },
        failure: (error) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localizations?.error ?? 'Error'}: $error'),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations?.error ?? 'Error'}: ${e.toString()}'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAppointmentsList(
    List<AppointmentModel> appointments,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    if (isDesktop) {
      return _isGridView
          ? _buildAppointmentGrid(appointments, 2)
          : _buildAppointmentsTable(appointments);
    }
    if (isTablet) {
      return _buildAppointmentGrid(appointments, 1);
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final appointment = appointments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEnhancedAppointmentCard(
              context,
              appointment,
              Theme.of(context).brightness == Brightness.dark,
              _selectedAppointments.contains(appointment.id),
              index,
            ),
          );
        },
        childCount: appointments.length,
      ),
    );
  }

  Widget _buildAppointmentGrid(
      List<AppointmentModel> appointments, int crossAxisCount) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final appointment = appointments[index];
            return _buildEnhancedAppointmentCard(
              context,
              appointment,
              Theme.of(context).brightness == Brightness.dark,
              _selectedAppointments.contains(appointment.id),
              index,
            );
          },
          childCount: appointments.length,
        ),
      ),
    );
  }

  Widget _buildAppointmentsTable(List<AppointmentModel> appointments) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.read(authProvider);
    final user = authState.user;
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
            ),
            columns: [
              DataColumn(
                label: Checkbox(
                  value: appointments.isNotEmpty &&
                      _selectedAppointments.length == appointments.length &&
                      appointments.every((appt) =>
                          appt.id != null &&
                          _selectedAppointments.contains(appt.id)),
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        if (value == true) {
                          _selectedAppointments.addAll(
                            appointments
                                .where((appt) => appt.id != null)
                                .map((appt) => appt.id!),
                          );
                        } else {
                          _selectedAppointments.removeAll(
                            appointments
                                .where((appt) => appt.id != null)
                                .map((appt) => appt.id!),
                          );
                        }
                      });
                    }
                  },
                ),
              ),
              DataColumn(
                  label: Text('ID',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.patient ?? 'Patient',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.phone ?? 'Phone',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Doctor',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.services ?? 'Service',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.date ?? 'Date',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Time',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Status',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text(localizations?.priority ?? 'Priority',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(
                  label: Text('Actions',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: appointments.map((appointment) {
              final dateWithRelative = _formatDateWithRelative(appointment);
              final timeLabel =
                  appointment.appointmentTime?.substring(0, 5) ?? '—';
              final statusColor = _getStatusColor(appointment.status);
              final priorityColor = _getPriorityColor(appointment.priority);
              final isSelected = appointment.id != null &&
                  _selectedAppointments.contains(appointment.id);

              // Only staff (admin/doctor/receptionist) can see edit and WhatsApp buttons
              // Patients should NOT see these options
              final canEditAsStaff = user != null &&
                  (user.isAdmin == 1 ||
                      user.isDoctor == 1 ||
                      user.isReceptionist == 1);

              return DataRow(
                selected: isSelected,
                onSelectChanged: (selected) {
                  if (appointment.id != null) {
                    _toggleSelection(appointment.id);
                  }
                },
                cells: [
                  DataCell(
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        if (appointment.id != null) {
                          _toggleSelection(appointment.id);
                        }
                      },
                    ),
                  ),
                  DataCell(Text(appointment.id?.toString() ?? '—',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.patient?.user?.name ??
                          (localizations?.unknown ?? 'Unknown'),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.patient?.phoneNumber ??
                          appointment.patient?.phone ??
                          '—',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.doctor?.user?.name ??
                          (localizations?.unknown ?? 'Unknown'),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(
                      appointment.service?.title ??
                          (localizations?.unknownService ?? 'Unknown service'),
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text(dateWithRelative,
                      style: const TextStyle(fontSize: 11))),
                  DataCell(
                      Text(timeLabel, style: const TextStyle(fontSize: 12))),
                  DataCell(_buildStatusChip(
                      _statusLabel(appointment.status, localizations),
                      statusColor)),
                  DataCell(_buildPriorityChip(
                      _priorityLabel(appointment.priority), priorityColor)),
                  DataCell(
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: (value) =>
                          _handleTableAction(value, appointment),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                  localizations?.viewDetails ?? 'View Details'),
                            ],
                          ),
                        ),
                        // Show Edit, status update, and WhatsApp options ONLY for staff (not for patients)
                        if (canEditAsStaff) ...[
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 18),
                                const SizedBox(width: 8),
                                Text(localizations?.edit ?? 'Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 18, color: Color(0xFF388E3C)),
                                const SizedBox(width: 8),
                                Text(localizations?.markAsCompleted ??
                                    'Mark as Completed'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'cancelled',
                            child: Row(
                              children: [
                                const Icon(Icons.cancel,
                                    size: 18, color: Color(0xFFD32F2F)),
                                const SizedBox(width: 8),
                                Text(localizations?.cancel ?? 'Cancel'),
                              ],
                            ),
                          ),
                          // Show WhatsApp option only for staff
                          if (appointment.status != 'completed' &&
                              appointment.status != 'cancelled' &&
                              appointment.id != null)
                            PopupMenuItem(
                              value: 'reminder',
                              child: Row(
                                children: [
                                  const Icon(Icons.message_rounded,
                                      size: 18, color: Color(0xFF25D366)),
                                  const SizedBox(width: 8),
                                  Text(localizations?.sendWhatsAppReminder ??
                                      'Send WhatsApp Reminder'),
                                ],
                              ),
                            ),
                          // Thank you + location + review (opens WhatsApp with pre-filled message)
                          if (canEditAsStaff &&
                              (appointment.patient?.phoneNumber != null ||
                                  appointment.patient?.phone != null))
                            PopupMenuItem(
                              value: 'thank_you',
                              child: Row(
                                children: [
                                  const Icon(Icons.thumb_up_rounded,
                                      size: 18, color: Color(0xFF25D366)),
                                  const SizedBox(width: 8),
                                  Text('Send thank you + review (WhatsApp)'),
                                ],
                              ),
                            ),
                        ],
                        PopupMenuItem(
                          value: 'prescriptions',
                          child: Row(
                            children: [
                              const Icon(Icons.description, size: 18),
                              const SizedBox(width: 8),
                              Text(localizations?.viewPrescriptions ??
                                  'View Prescriptions'),
                            ],
                          ),
                        ),
                        if (appointment.additionalData?['invoice'] != null)
                          PopupMenuItem(
                            value: 'invoice',
                            child: Row(
                              children: [
                                const Icon(Icons.receipt, size: 18),
                                const SizedBox(width: 8),
                                Text(localizations?.accessInvoice ??
                                    'Access Invoice'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAppointmentCard(
    BuildContext context,
    AppointmentModel appointment,
    bool isDark,
    bool isSelected,
    int index,
  ) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Only staff (admin/doctor/receptionist) can see edit and WhatsApp buttons
    // Patients should NOT see these options
    final canEditAsStaff = user != null &&
        (user.isAdmin == 1 || user.isDoctor == 1 || user.isReceptionist == 1);

    final appointmentDate = _parseAppointmentDate(appointment);
    final dateLabel = appointmentDate != null
        ? _getDateFormatter().format(appointmentDate)
        : (localizations?.unknownDate ?? 'Unknown date');
    final rawTime = appointment.appointmentTime ?? '';
    final timeLabel = rawTime.isEmpty
        ? '--'
        : rawTime.substring(0, rawTime.length >= 5 ? 5 : rawTime.length);

    final statusColor = _getStatusColor(appointment.status);
    final priorityColor = _getPriorityColor(appointment.priority);

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutBack, // Smoother animation
      builder: (context, double value, child) {
        // Clamp opacity to valid range
        final clampedOpacity = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clampedOpacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - clampedOpacity)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSelection(appointment.id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? [
                        const Color(0xFF1976D2).withOpacity(0.15),
                        const Color(0xFF1976D2).withOpacity(0.08),
                      ]
                    : isDark
                        ? [
                            const Color(0xFF1F1F25),
                            const Color(0xFF15151C),
                          ]
                        : [
                            Colors.white,
                            Colors.grey[50]!,
                          ],
              ),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1976D2)
                    : isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[200]!.withOpacity(0.5),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF1976D2).withOpacity(0.3)
                      : Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: isSelected ? 20 : 15,
                  offset: const Offset(0, 8),
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (appointment.id != null)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(appointment.id),
                          visualDensity:
                              VisualDensity.compact, // Smaller checkbox
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${localizations?.appointmentNumber ?? 'Appointment'} #${appointment.id ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return _buildStatusChip(
                              _statusLabel(appointment.status, loc),
                              statusColor);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Simplified info rows: Use ListView for better scrolling if needed, but keep wrap for now
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                          Icons.person_rounded,
                          appointment.patient?.user?.name ??
                              (localizations?.unknown ??
                                  'Unknown')), // Simplified to chips
                      if (appointment.patient?.phoneNumber != null ||
                          appointment.patient?.phone != null)
                        _buildPhoneChipWithActions(
                            appointment.patient?.phoneNumber ??
                                appointment.patient?.phone ??
                                '',
                            appointment),
                      _buildInfoChip(
                          Icons.local_hospital_rounded,
                          appointment.doctor?.user?.name ??
                              (localizations?.unknown ?? 'Unknown')),
                      // WhatsApp Status Badge in card (compact)
                      if (appointment.patient?.id != null ||
                          appointment.id != null)
                        _buildWhatsAppStatusBadgeCompact(
                            appointment.patient?.id,
                            appointment.id,
                            appointment),
                      _buildInfoChip(
                          Icons.medical_services_rounded,
                          appointment.service?.title ??
                              (localizations?.unknownService ??
                                  'Unknown service')),
                      _buildInfoChip(Icons.event, dateLabel),
                      _buildInfoChip(Icons.schedule_rounded, timeLabel),
                      // Time remaining indicator
                      if (appointment.appointmentDate != null &&
                          appointment.appointmentTime != null)
                        _buildTimeRemainingChip(appointment.appointmentDate!,
                            appointment.appointmentTime!),
                      _buildPriorityChip(
                          _priorityLabel(appointment.priority), priorityColor),
                    ],
                  ),
                  if ((appointment.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2)
                            .withOpacity(0.05), // Suggested primary
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes_rounded,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(appointment.notes!,
                                  style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Actions: Horizontal scroll if many, but limit to 3-4 primary
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Details button - Always first
                        _buildActionButton(
                          icon: Icons.visibility_rounded,
                          label: localizations?.details ?? 'Details',
                          onTap: () => _showDetailsSheet(appointment),
                        ),
                        // WhatsApp button - Second position (if available)
                        if (appointment.status != 'completed' &&
                            appointment.status != 'cancelled' &&
                            appointment.id != null) ...[
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.message_rounded,
                            label: localizations?.whatsApp ?? 'WhatsApp',
                            onTap: () =>
                                _handleSendWhatsAppReminder(appointment),
                            color: const Color(0xFF25D366), // WhatsApp green
                          ),
                        ],
                        // Thank you + location + review (opens WhatsApp with pre-filled message)
                        if (canEditAsStaff &&
                            (appointment.patient?.phoneNumber != null ||
                                appointment.patient?.phone != null)) ...[
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.thumb_up_rounded,
                            label: 'Thank you + review',
                            onTap: () => _openThankYouWhatsApp(appointment),
                            color: const Color(0xFF25D366),
                          ),
                        ],
                        // Show Edit, Invoice buttons ONLY for staff (not for patients)
                        if (canEditAsStaff) ...[
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.edit_outlined,
                            label: localizations?.edit ?? 'Edit',
                            onTap: () => _handleEditAppointment(appointment),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            icon: Icons.receipt_long_rounded,
                            label: localizations?.invoice ?? 'Invoice',
                            onTap: () => _handleInvoice(appointment),
                            color: const Color(0xFF388E3C), // Suggested green
                          ),
                        ],
                      ],
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

  // New: Simplified info chip
  Widget _buildInfoChip(IconData icon, String value) {
    if (value == '—' || value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withOpacity(0.08), // Suggested primary
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1976D2)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Phone chip with quick actions
  Widget _buildPhoneChipWithActions(String phoneNumber, [AppointmentModel? appointment]) {
    if (phoneNumber.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_rounded, size: 14, color: const Color(0xFF1976D2)),
          const SizedBox(width: 4),
          Text(
            phoneNumber,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          ),
          const SizedBox(width: 8),
          // Quick call button - Larger and more spaced
          Material(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _handlePhoneCall(phoneNumber),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.phone_rounded,
                    size: 18, color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Quick WhatsApp button - Larger and more spaced
          Material(
            color: const Color(0xFF25D366).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _handleWhatsAppMessage(phoneNumber, appointment),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.message_rounded,
                    size: 18, color: Color(0xFF25D366)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Time remaining chip
  Widget _buildTimeRemainingChip(String appointmentDate, String time) {
    final timeRemaining = _calculateTimeRemainingForList(appointmentDate, time);
    if (timeRemaining == null) return const SizedBox.shrink();

    final isPast = timeRemaining['isPast'] == true;
    final isToday = timeRemaining['isToday'] == true;

    Color chipColor;
    if (isPast) {
      chipColor = Colors.red;
    } else if (isToday) {
      chipColor = Colors.orange;
    } else {
      chipColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPast ? Icons.schedule_rounded : Icons.access_time_rounded,
            size: 12,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            timeRemaining['text'] as String,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  // Calculate time remaining for list (simplified version)
  Map<String, dynamic>? _calculateTimeRemainingForList(
      String appointmentDate, String time) {
    try {
      final date = DateTime.parse(appointmentDate);
      final timeParts = time.split(':');
      if (timeParts.length < 2) return null;

      final appointmentDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final now = DateTime.now();
      final difference = appointmentDateTime.difference(now);

      final isPast = difference.isNegative;
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      String text;
      if (isPast) {
        final hoursAgo = difference.inHours.abs();
        if (hoursAgo < 24) {
          text = '${hoursAgo}h ago';
        } else {
          final daysAgo = difference.inDays.abs();
          text = '$daysAgo days ago';
        }
      } else if (isToday) {
        if (difference.inHours < 1) {
          text = '${difference.inMinutes}m';
        } else {
          text = '${difference.inHours}h';
        }
      } else {
        final days = difference.inDays;
        text = '${days}d';
      }

      return {
        'text': text,
        'isPast': isPast,
        'isToday': isToday,
      };
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF388E3C); // Suggested green
      case 'cancelled':
        return const Color(0xFFD32F2F); // Suggested red
      case 'no_show':
        return Colors.grey;
      default:
        return const Color(0xFF1976D2); // Suggested blue
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFD32F2F); // Suggested red
      case 'low':
        return const Color(0xFF388E3C); // Suggested green
      default:
        return Colors.orange;
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: color != null
            ? BorderSide(color: color)
            : const BorderSide(color: Color(0xFF1976D2)),
        foregroundColor: color ?? const Color(0xFF1976D2),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Center(
      // <-- Now returns just the Center widget
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF15151C) : const Color(0xFFFFFFFF),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: const Color(0xFF1976D2).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.noAppointments ?? 'No Appointments',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              localizations?.adjustYourFilters ??
                  'Adjust your filters or create a new one.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateAppointmentScreen()),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                    localizations?.createAppointment ?? 'Create Appointment'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(bool isCurrentPageEmpty, bool isDesktop) {
    final localizations = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(
          top: 16, bottom: 100), // Increased bottom margin for FAB
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _currentPage > 1
                ? () {
                    if (mounted) {
                      setState(() {
                        _currentPage -= 1;
                        _selectedAppointments.clear();
                      });
                    }
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            label: Text(
                isDesktop
                    ? (localizations?.previous ?? 'Previous')
                    : (localizations?.previous ?? 'Prev.'),
                style: const TextStyle(fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF1976D2).withOpacity(0.1), // Suggested primary
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${localizations?.page ?? 'Page'} $_currentPage',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1976D2), // Suggested primary
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (isCurrentPageEmpty) {
                final localizations = AppLocalizations.of(context);
                _showComingSoon(
                    context, localizations?.endOfResults ?? 'End of results.');
                return;
              }
              if (mounted) {
                setState(() {
                  _currentPage += 1;
                  _selectedAppointments.clear();
                });
              }
            },
            icon: const Icon(Icons.chevron_right),
            label: Text(localizations?.next ?? 'Next',
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFF9800), // Orange for info
      ),
    );
  }

  Future<void> _handleInvoice(AppointmentModel appointment) async {
    if (!mounted) return;

    final patientId = appointment.patient?.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient information not available'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if invoice exists in additionalData (linked to this appointment)
    final appointmentInvoice = appointment.additionalData?['invoice'];

    // Fetch all invoices for this patient
    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.getInvoices(
        page: 1,
        userId: appointment.patient?.user?.id,
      );

      if (!mounted) return;

      result.when(
        success: (data) {
          // Safely extract invoices from the response
          List<dynamic> invoices = [];
          try {
            if (data is Map<String, dynamic>) {
              final invoicesData = data['invoices'];
              if (invoicesData is List) {
                invoices = invoicesData;
              } else {
                // invoicesData is not a list, show no invoice dialog
                _showNoInvoiceDialog(context, appointment);
                return;
              }
            } else {
              // Unknown data type, show no invoice dialog
              _showNoInvoiceDialog(context, appointment);
              return;
            }
          } catch (e) {
            // If parsing fails, show no invoice dialog
            _showNoInvoiceDialog(context, appointment);
            return;
          }

          // Convert Invoice objects to Maps and filter for this patient
          final patientInvoices = <Map<String, dynamic>>[];
          for (final inv in invoices) {
            try {
              Map<String, dynamic>? invoiceMap;
              if (inv is Invoice) {
                invoiceMap = inv.toJson();
              } else if (inv is Map<String, dynamic>) {
                invoiceMap = inv;
              }

              if (invoiceMap != null && invoiceMap['patient_id'] == patientId) {
                patientInvoices.add(invoiceMap);
              }
            } catch (e) {
              // Skip invalid invoice entries
              continue;
            }
          }

          // Check if we have appointment-linked invoice
          if (appointmentInvoice != null) {
            // If we have appointment invoice, show it or add to list
            final appointmentInvoiceId = appointmentInvoice['id'];
            final hasAppointmentInvoice = patientInvoices.any(
              (inv) => inv['id'] == appointmentInvoiceId,
            );

            if (!hasAppointmentInvoice) {
              patientInvoices.insert(0, appointmentInvoice);
            }
          }

          if (patientInvoices.isEmpty) {
            // No invoices - show dialog with options
            _showNoInvoiceDialog(context, appointment);
            return;
          }

          // If only one invoice, show it directly
          if (patientInvoices.length == 1) {
            final invoiceData = patientInvoices[0] as Map<String, dynamic>;
            _showInvoiceDialog(context, appointment, invoiceData);
            return;
          }

          // Multiple invoices - show selection dialog
          _showInvoiceSelectionDialog(
              context, appointment, patientInvoices, appointmentInvoice);
        },
        failure: (message) {
          // Fallback to appointment invoice if available
          if (appointmentInvoice != null) {
            _showInvoiceDialog(context, appointment, appointmentInvoice);
          } else {
            // No invoice available - show dialog with options
            _showNoInvoiceDialog(context, appointment);
          }
        },
      );
    } catch (e) {
      // Fallback to appointment invoice if available
      if (appointmentInvoice != null) {
        _showInvoiceDialog(context, appointment, appointmentInvoice);
      } else {
        // No invoice available - show dialog with options
        if (mounted) {
          _showNoInvoiceDialog(context, appointment);
        }
      }
    }
  }

  void _showNoInvoiceDialog(
    BuildContext context,
    AppointmentModel appointment,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patientName = appointment.patient?.user?.name ?? 'Patient';
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFFF9800),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No Invoice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$patientName has no invoices',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[800]?.withOpacity(0.5)
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This appointment does not have an invoice. You can create a new invoice or view all invoices.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InvoicesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_rounded, size: 20),
                      label: const Text('View All Invoices'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateInvoiceScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Create Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceSelectionDialog(
    BuildContext context,
    AppointmentModel appointment,
    List<dynamic> invoices,
    Map<String, dynamic>? appointmentInvoice,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patientName = appointment.patient?.user?.name ?? 'Patient';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF388E3C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Invoice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$patientName has ${invoices.length} invoices',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Invoice List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index] as Map<String, dynamic>;
                    final invoiceId = invoice['id'];
                    final amount =
                        double.tryParse(invoice['amount']?.toString() ?? '0') ??
                            0.0;
                    final paid =
                        double.tryParse(invoice['paid']?.toString() ?? '0') ??
                            0.0;
                    final status = invoice['status'] as String? ?? 'unpaid';
                    final dueDate = invoice['due_date'] as String?;
                    final isLinkedToAppointment = appointmentInvoice != null &&
                        appointmentInvoice['id'] == invoiceId;

                    // Status color
                    Color statusColor;
                    String statusLabel;
                    switch (status) {
                      case 'paid':
                        statusColor = Colors.green;
                        statusLabel = 'Payée';
                        break;
                      case 'partial':
                        statusColor = Colors.orange;
                        statusLabel = 'Partielle';
                        break;
                      default:
                        statusColor = Colors.red;
                        statusLabel = 'Non payée';
                    }

                    // Format due date
                    String formattedDueDate = '—';
                    if (dueDate != null) {
                      try {
                        final date = DateTime.parse(dueDate);
                        formattedDueDate =
                            DateFormat('dd MMM yyyy').format(date);
                      } catch (e) {
                        formattedDueDate = dueDate;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isLinkedToAppointment
                            ? (isDark
                                ? Colors.blue[900]?.withOpacity(0.3)
                                : Colors.blue[50])
                            : (isDark
                                ? const Color(0xFF1E1E2E)
                                : Colors.grey[50]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLinkedToAppointment
                              ? Colors.blue
                              : (isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!),
                          width: isLinkedToAppointment ? 2 : 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showInvoiceDialog(context, appointment, invoice);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.receipt_rounded,
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Facture #$invoiceId',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isLinkedToAppointment) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'This Appointment',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '\$${amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  statusColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Échéance: $formattedDueDate',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDialog(BuildContext context, AppointmentModel appointment,
      Map<String, dynamic> invoiceData) {
    final localizations = AppLocalizations.of(context);
    final invoiceId = invoiceData['id'];
    final invoiceAmount =
        double.tryParse(invoiceData['amount']?.toString() ?? '0') ?? 0.0;
    final invoicePaid =
        double.tryParse(invoiceData['paid']?.toString() ?? '0') ?? 0.0;
    final invoiceDue = invoiceAmount - invoicePaid;
    final invoiceStatus = invoiceData['status'] as String? ?? 'unpaid';
    final dueDate = invoiceData['due_date'] as String?;
    final createdAt = invoiceData['created_at'] as String?;
    final pdfPath = invoiceData['pdf_path'] as String?;
    final items = invoiceData['items'] as List<dynamic>? ?? [];
    final payments = invoiceData['payments'] as List<dynamic>? ?? [];
    final patientName = appointment.patient?.user?.name ?? 'Inconnu';
    final authState = ref.read(authProvider);
    final user = authState.user;
    final canManageInvoices = user?.isAdmin == 1 ||
        user?.isAccountant == 1 ||
        user?.isReceptionist == 1;

    // Format dates
    String formattedCreatedAt = '—';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedCreatedAt = DateFormat('dd MMMM yyyy', 'fr').format(date);
      } catch (e) {
        formattedCreatedAt = createdAt;
      }
    }

    String formattedDueDate = '—';
    if (dueDate != null) {
      try {
        final date = DateTime.parse(dueDate);
        formattedDueDate = DateFormat('dd MMMM yyyy', 'fr').format(date);
      } catch (e) {
        formattedDueDate = dueDate;
      }
    }

    // Status label
    String statusLabel;
    Color statusColor;
    switch (invoiceStatus) {
      case 'paid':
        statusLabel = 'Payée';
        statusColor = Colors.green;
        break;
      case 'partial':
        statusLabel = 'Partiellement payée';
        statusColor = Colors.orange;
        break;
      default:
        statusLabel = 'Non payée';
        statusColor = Colors.red;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact Header with close button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF388E3C),
                      const Color(0xFF388E3C).withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Facture #$invoiceId',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Émise le $formattedCreatedAt',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice Info Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildInvoiceInfoCard(
                              'Patient',
                              patientName,
                              Icons.person_rounded,
                              Colors.blue,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInvoiceInfoCard(
                              'Statut',
                              statusLabel,
                              Icons.info_rounded,
                              statusColor,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInvoiceInfoCard(
                              'Montant',
                              '\$${invoiceAmount.toStringAsFixed(2)}',
                              Icons.attach_money_rounded,
                              Colors.green,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInvoiceInfoCard(
                              'Payé',
                              '\$${invoicePaid.toStringAsFixed(2)}',
                              Icons.check_circle_rounded,
                              Colors.blue,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInvoiceInfoCard(
                              'Dû',
                              '\$${invoiceDue.toStringAsFixed(2)}',
                              Icons.pending_rounded,
                              invoiceDue > 0 ? Colors.orange : Colors.green,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInvoiceInfoCard(
                              'Date d\'échéance',
                              formattedDueDate,
                              Icons.calendar_today_rounded,
                              Colors.purple,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Invoice Items Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.list_alt_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Articles de la facture',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (items.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Aucun article trouvé.',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      isDark ? Colors.grey[900] : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!,
                                  ),
                                ),
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(3),
                                    1: FlexColumnWidth(1),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.5),
                                  },
                                  children: [
                                    // Header
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[200],
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8),
                                        ),
                                      ),
                                      children: [
                                        _buildTableCell('Description',
                                            isHeader: true, isDark: isDark),
                                        _buildTableCell('Quantité',
                                            isHeader: true, isDark: isDark),
                                        _buildTableCell('Prix unitaire',
                                            isHeader: true, isDark: isDark),
                                        _buildTableCell('Total',
                                            isHeader: true, isDark: isDark),
                                      ],
                                    ),
                                    // Items
                                    ...items.map((item) {
                                      final description =
                                          item['description'] ?? '—';
                                      final quantity = item['quantity'] ?? 0;
                                      final unitPrice = double.tryParse(
                                              item['unit_price']?.toString() ??
                                                  '0') ??
                                          0.0;
                                      final total = double.tryParse(
                                              item['total']?.toString() ??
                                                  '0') ??
                                          0.0;
                                      return TableRow(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isDark
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[200]!,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        children: [
                                          _buildTableCell(
                                              description.toString(),
                                              isDark: isDark),
                                          _buildTableCell(quantity.toString(),
                                              isDark: isDark),
                                          _buildTableCell(
                                              '\$${unitPrice.toStringAsFixed(2)}',
                                              isDark: isDark),
                                          _buildTableCell(
                                              '\$${total.toStringAsFixed(2)}',
                                              isDark: isDark),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Payments Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.payment_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Historique des paiements',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (canManageInvoices &&
                                invoiceStatus != 'paid' &&
                                invoiceDue > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () {
                                    _showAddPaymentDialog(
                                      context,
                                      invoiceId,
                                      invoiceAmount,
                                      invoicePaid,
                                      () {
                                        // Refresh invoice data
                                        Navigator.of(context).pop();
                                        _handleInvoice(appointment);
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Ajouter un paiement'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF388E3C),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    alignment: Alignment.centerLeft,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (payments.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.payment_outlined,
                                        size: 48,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Aucun paiement enregistré',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...payments.map((payment) {
                                final paymentAmount = double.tryParse(
                                        payment['amount']?.toString() ?? '0') ??
                                    0.0;
                                final paymentDate =
                                    payment['payment_date'] as String?;
                                final paymentMethod =
                                    payment['payment_method'] as String? ??
                                        'cash';

                                String formattedPaymentDate = '—';
                                if (paymentDate != null) {
                                  try {
                                    final date = DateTime.parse(paymentDate);
                                    formattedPaymentDate =
                                        DateFormat('dd MMM yyyy', 'fr')
                                            .format(date);
                                  } catch (e) {
                                    formattedPaymentDate = paymentDate;
                                  }
                                }

                                String methodLabel;
                                IconData methodIcon;
                                switch (paymentMethod) {
                                  case 'cash':
                                    methodLabel = 'Espèces';
                                    methodIcon = Icons.money_rounded;
                                    break;
                                  case 'credit_card':
                                    methodLabel = 'Carte de crédit';
                                    methodIcon = Icons.credit_card_rounded;
                                    break;
                                  case 'bank_transfer':
                                    methodLabel = 'Virement bancaire';
                                    methodIcon = Icons.account_balance_rounded;
                                    break;
                                  case 'insurance':
                                    methodLabel = 'Assurance';
                                    methodIcon = Icons.local_hospital_rounded;
                                    break;
                                  case 'mobile_payment':
                                    methodLabel = 'Paiement mobile';
                                    methodIcon = Icons.phone_android_rounded;
                                    break;
                                  default:
                                    methodLabel = paymentMethod;
                                    methodIcon = Icons.payment_rounded;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[900]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '\$${paymentAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  methodIcon,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  methodLabel,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formattedPaymentDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer buttons
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (pdfPath != null && invoiceId != null) ...[
                      _buildCompactActionButton(
                        context,
                        icon: Icons.download_rounded,
                        label: 'Télécharger PDF',
                        color: const Color(0xFF1976D2),
                        onPressed: () => _downloadInvoicePdf(invoiceId),
                      ),
                      const SizedBox(width: 8),
                      _buildCompactActionButton(
                        context,
                        icon: Icons.print_rounded,
                        label: 'Imprimer',
                        color: const Color(0xFF1976D2),
                        onPressed: () => _printInvoice(invoiceId),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildCompactActionButton(
                      context,
                      icon: Icons.close_rounded,
                      label: 'Fermer',
                      color: Colors.grey,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceInfoCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text,
      {bool isHeader = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 12 : 13,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color: isHeader
              ? (isDark ? Colors.grey[300] : Colors.black87)
              : (isDark ? Colors.grey[400] : Colors.black54),
        ),
      ),
    );
  }

  Future<void> _downloadInvoicePdf(int invoiceId) async {
    await _downloadAndShareInvoicePdf(invoiceId, openAfterDownload: false);
  }

  Future<void> _printInvoice(int invoiceId) async {
    await _downloadAndShareInvoicePdf(invoiceId, openAfterDownload: true);
  }

  Future<void> _downloadAndShareInvoicePdf(int invoiceId,
      {required bool openAfterDownload}) async {
    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      // Get auth token
      final authState = ref.read(authProvider);
      final apiUrl =
          '${ApiConstants.baseUrl}${ApiConstants.invoicePdf(invoiceId)}';
      final uri = Uri.parse(apiUrl);

      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the PDF
      final response = await http.get(uri, headers: headers);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (response.statusCode == 200) {
        final fileName = 'facture_$invoiceId.pdf';

        if (kIsWeb) {
          // For web, trigger browser download
          final blobUrl = Uri.dataFromBytes(
            response.bodyBytes,
            mimeType: 'application/pdf',
          );
          await launchUrl(blobUrl, mode: LaunchMode.platformDefault);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  openAfterDownload
                      ? 'PDF ouvert dans le navigateur'
                      : 'PDF téléchargé avec succès',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // For mobile, save to temporary directory first, then share/open
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            // Use share_plus to share/open the file
            final xFile = XFile(filePath, mimeType: 'application/pdf');

            if (openAfterDownload) {
              // Share with option to open
              await Share.shareXFiles(
                [xFile],
                text: 'Facture #$invoiceId',
                subject: 'Facture PDF',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ouvrez le PDF depuis le menu de partage'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              // Share for saving
              await Share.shareXFiles(
                [xFile],
                text: 'Facture #$invoiceId',
                subject: 'Facture PDF',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sauvegardez le PDF depuis le menu de partage'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Erreur lors du téléchargement: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close loading dialog if still open
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddPaymentDialog(
    BuildContext context,
    int invoiceId,
    double invoiceAmount,
    double invoicePaid,
    VoidCallback onPaymentAdded,
  ) {
    final remaining = invoiceAmount - invoicePaid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _formKey = GlobalKey<FormState>();
    final _amountController = TextEditingController();
    final _dateController = TextEditingController();
    String _paymentMethod = 'cash';
    bool _isLoading = false;

    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _amountController.text = remaining.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.05),
                  Colors.green.withOpacity(0.05),
                ],
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payment_rounded,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enregistrer un paiement',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Facture #$invoiceId',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Remaining Amount Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_rounded, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Montant restant',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                '\$${remaining.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Amount Field
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant (MAD) *',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le montant est requis';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Montant invalide';
                      }
                      if (amount > remaining) {
                        return 'Le montant dépasse le solde restant';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Date Field
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date de paiement *',
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _dateController.text =
                            DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Payment Method
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: InputDecoration(
                      labelText: 'Méthode de paiement',
                      prefixIcon: const Icon(Icons.payment_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'cash', child: Text('💵 Espèces')),
                      DropdownMenuItem(
                          value: 'credit_card',
                          child: Text('💳 Carte de crédit')),
                      DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('🏦 Virement bancaire')),
                      DropdownMenuItem(
                          value: 'insurance', child: Text('🏥 Assurance')),
                      DropdownMenuItem(
                          value: 'mobile_payment',
                          child: Text('📱 Paiement mobile')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _paymentMethod = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate())
                                    return;

                                  setDialogState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final invoiceService =
                                        ref.read(invoiceServiceProvider);
                                    final result =
                                        await invoiceService.recordPayment(
                                      invoiceId: invoiceId,
                                      amount:
                                          double.parse(_amountController.text),
                                      paymentDate: _dateController.text,
                                      paymentMethod: _paymentMethod,
                                    );

                                    if (mounted) {
                                      if (result is Success) {
                                        Navigator.of(dialogContext).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                '✅ Paiement enregistré avec succès'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        onPaymentAdded();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '❌ Erreur: ${(result as Failure).message}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('❌ Erreur: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setDialogState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF388E3C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enregistrer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
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

  void _handleTableAction(String action, AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    switch (action) {
      case 'view':
        _showDetailsSheet(appointment);
        break;
      case 'edit':
        _handleEditAppointment(appointment);
        break;
      case 'completed':
        _handleSingleStatusUpdate(appointment, 'completed');
        break;
      case 'cancelled':
        _handleSingleStatusUpdate(appointment, 'cancelled');
        break;
      case 'reminder':
        _handleSendWhatsAppReminder(appointment);
        break;
      case 'thank_you':
        _openThankYouWhatsApp(appointment);
        break;
      case 'prescriptions':
        final localizations = AppLocalizations.of(context);
        _showComingSoon(
            context,
            localizations?.viewPrescriptionsAvailableSoon ??
                'View prescriptions available soon.');
        break;
      case 'invoice':
        final localizations = AppLocalizations.of(context);
        _showComingSoon(
            context,
            localizations?.invoiceAccessAvailableSoon ??
                'Invoice access available soon.');
        break;
    }
  }

  Future<void> _handleSingleStatusUpdate(
      AppointmentModel appointment, String status) async {
    if (appointment.id == null) return;

    final localizations = AppLocalizations.of(context);
    final statusLabel = _statusLabel(status, localizations);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.confirmation ?? 'Confirm'),
        content: Text(
            '${localizations?.doYouWantToChangeStatus ?? 'Do you really want to change the status to'} "$statusLabel"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'cancelled'
                  ? const Color(0xFFD32F2F)
                  : status == 'completed'
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF1976D2),
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ref.read(
      updateAppointmentStatusProvider(
        UpdateStatusParams(
          appointmentId: appointment.id!,
          status: status,
        ),
      ).future,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${localizations?.statusChangedTo ?? 'Status changed to'} "$statusLabel"'),
            backgroundColor: const Color(0xFF388E3C),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshAppointments();
      },
      failure: (error) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $error'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _handleSendReminder(AppointmentModel appointment) async {
    if (appointment.id == null || !mounted) return;

    final patientName = appointment.patient?.user?.name ?? 'the patient';

    // Show loading dialog
    final localizations = AppLocalizations.of(context);
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: localizations?.sending ?? 'Sending...',
      desc: localizations?.sendingWhatsAppReminder ??
          'Sending WhatsApp reminder...',
      dismissOnTouchOutside: false,
    ).show();

    final result = await ref.read(
      sendWhatsAppReminderProvider(appointment.id!).future,
    );

    // Close loading dialog
    if (mounted) {
      final navigator = Navigator.of(context, rootNavigator: false);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (!mounted) return;

    result.when(
      success: (_) {
        if (!mounted) return;

        // Build success message with patient name
        String successMessage;
        if (localizations?.localeName == 'fr') {
          successMessage =
              'Rappel WhatsApp envoyé avec succès !\n\nÀ: $patientName';
        } else if (localizations?.localeName == 'ar') {
          successMessage =
              'تم إرسال تذكير WhatsApp بنجاح!\n\nإلى: $patientName';
        } else {
          successMessage =
              'WhatsApp reminder sent successfully!\n\nTo: $patientName';
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: localizations?.success ?? 'Success',
          desc: successMessage,
          btnOkText: localizations?.ok ?? 'OK',
          btnOkColor: const Color(0xFF25D366), // WhatsApp green
          btnOkOnPress: () {},
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          descTextStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
          padding: const EdgeInsets.all(20),
        ).show();
      },
      failure: (error) {
        if (!mounted) return;

        String errorMessage = error;
        if (error.contains('Daily message limit') || error.contains('429')) {
          errorMessage = localizations?.dailyMessageLimitReached ??
              'Daily message limit reached. Please try again tomorrow.';
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: localizations?.error ?? 'Error',
          desc: errorMessage,
          btnOkText: localizations?.ok ?? 'OK',
          btnOkColor: Colors.red,
          btnOkOnPress: () {},
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          descTextStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
          padding: const EdgeInsets.all(20),
        ).show();
      },
    );
  }

  void _showDetailsSheet(AppointmentModel appointment) {
    debugPrint(
        '📋📋📋 [Details Sheet] OPENING - appointment #${appointment.id}, patientId: ${appointment.patient?.id}');
    debugPrint(
        '📋 [Details Sheet] Patient phone: ${appointment.patient?.phone ?? appointment.patient?.phoneNumber ?? "N/A"}');
    final localizations = AppLocalizations.of(context);
    final appointmentDate = _parseAppointmentDate(appointment);
    final isCompleted = appointment.status == 'completed';
    final isCancelled = appointment.status == 'cancelled';
    final patientId = appointment.patient?.id;
    final appointmentId = appointment.id;

    // Status colors
    Color statusColor;
    IconData statusIcon;
    String statusText;
    switch (appointment.status?.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusText = localizations?.completed ?? 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusText = localizations?.cancelled ?? 'Cancelled';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_rounded;
        statusText = localizations?.pending ?? 'Pending';
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule_rounded;
        statusText = localizations?.scheduled ?? 'Scheduled';
    }

    Color priorityColor;
    String priorityText;
    switch (appointment.priority?.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        priorityText = '🔴 ${localizations?.high ?? 'High'}';
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityText = '🟡 ${localizations?.medium ?? 'Medium'}';
        break;
      default:
        priorityColor = Colors.green;
        priorityText = '🟢 ${localizations?.low ?? 'Low'}';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${localizations?.appointmentNumber ?? 'Appointment'} #${appointment.id ?? '—'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        minimumSize: const Size(32, 32),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status and Priority badges
                          Row(
                            children: [
                              _buildCompactBadge(
                                  statusColor, statusIcon, statusText),
                              const SizedBox(width: 8),
                              _buildCompactBadge(
                                  priorityColor, null, priorityText,
                                  isIcon: false),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Patient Information Section
                          if (appointment.patient != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations?.patient ?? 'Patient',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCompactInfoRow(
                                    Icons.person_outline_rounded,
                                    appointment.patient?.user?.name ?? '—',
                                  ),
                                  if (appointment.patient?.phone != null ||
                                      appointment.patient?.phoneNumber !=
                                          null) ...[
                                    const SizedBox(height: 8),
                                    _buildCompactPhoneRowWithActions(
                                      appointment.patient?.phoneNumber ??
                                          appointment.patient?.phone ??
                                          '',
                                      appointment,
                                    ),
                                  ],
                                  // WhatsApp Status
                                  if (patientId != null ||
                                      appointmentId != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF25D366)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final statusParams =
                                              WhatsAppStatusParams(
                                            clientId: patientId,
                                            appointmentId: appointmentId,
                                          );
                                          final statusStream = ref.watch(
                                              whatsAppStatusProvider(
                                                  statusParams));
                                          return statusStream.when(
                                            data: (result) {
                                              return result.when(
                                                success: (data) {
                                                  final status =
                                                      data['status'] as String?;
                                                  if (status == null ||
                                                      status == 'not_found') {
                                                    return Row(
                                                      children: [
                                                        Icon(
                                                          Icons.message_rounded,
                                                          color:
                                                              Colors.grey[600],
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            'No WhatsApp message sent',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                  return Row(
                                                    children: [
                                                      Icon(
                                                        Icons.message_rounded,
                                                        color: const Color(
                                                            0xFF25D366),
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Text(
                                                        'Status: ',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      WhatsAppStatusBadge(
                                                        status: status,
                                                        showLabel: true,
                                                      ),
                                                    ],
                                                  );
                                                },
                                                failure: (_) =>
                                                    const SizedBox.shrink(),
                                              );
                                            },
                                            loading: () => Row(
                                              children: [
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      const Color(0xFF25D366),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Loading...',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            error: (_, __) =>
                                                const SizedBox.shrink(),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                  if (appointment.patient?.user?.email !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    _buildCompactInfoRow(
                                      Icons.email_outlined,
                                      appointment.patient!.user!.email!,
                                    ),
                                  ],
                                  if (appointment.patient?.cniNumber !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    _buildCompactInfoRow(
                                      Icons.badge_outlined,
                                      appointment.patient!.cniNumber!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Doctor Information
                          if (appointment.doctor != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.medical_services_rounded,
                                        color: Colors.blue[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations?.doctor ?? 'Doctor',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCompactInfoRow(
                                    Icons.person_outline_rounded,
                                    appointment.doctor?.user?.name ?? '—',
                                  ),
                                  if (appointment.doctor?.user?.email !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    _buildCompactInfoRow(
                                      Icons.email_outlined,
                                      appointment.doctor!.user!.email!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Appointment Details with Time Remaining
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event_rounded,
                                      color: Colors.orange[700],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations?.appointmentDetails ??
                                          'Appointment',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildCompactInfoRow(
                                  Icons.local_hospital_outlined,
                                  appointment.service?.title ?? '—',
                                  label: localizations?.services ?? 'Service',
                                ),
                                const SizedBox(height: 8),
                                _buildCompactInfoRow(
                                  Icons.calendar_today_outlined,
                                  appointmentDate != null
                                      ? _getDateFormatter()
                                          .format(appointmentDate)
                                      : '—',
                                  label: localizations?.date ?? 'Date',
                                ),
                                const SizedBox(height: 8),
                                _buildCompactInfoRow(
                                  Icons.access_time_outlined,
                                  appointment.appointmentTime ?? '—',
                                  label: localizations?.time ?? 'Time',
                                ),
                                // Time remaining indicator
                                if (appointmentDate != null &&
                                    appointment.appointmentTime != null) ...[
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final timeRemaining =
                                          _calculateTimeRemaining(
                                              appointmentDate!,
                                              appointment.appointmentTime!);
                                      if (timeRemaining == null)
                                        return const SizedBox.shrink();
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: timeRemaining['isPast'] == true
                                              ? Colors.red.withOpacity(0.1)
                                              : timeRemaining['isToday'] == true
                                                  ? Colors.orange
                                                      .withOpacity(0.1)
                                                  : Colors.blue
                                                      .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              timeRemaining['isPast'] == true
                                                  ? Icons.schedule_rounded
                                                  : Icons.access_time_rounded,
                                              size: 16,
                                              color: timeRemaining['isPast'] ==
                                                      true
                                                  ? Colors.red[700]
                                                  : timeRemaining['isToday'] ==
                                                          true
                                                      ? Colors.orange[700]
                                                      : Colors.blue[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                timeRemaining['text'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: timeRemaining[
                                                              'isPast'] ==
                                                          true
                                                      ? Colors.red[700]
                                                      : timeRemaining[
                                                                  'isToday'] ==
                                                              true
                                                          ? Colors.orange[700]
                                                          : Colors.blue[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (appointment.notes != null &&
                              appointment.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildCompactInfoRow(
                              Icons.note_outlined,
                              appointment.notes!,
                              label: localizations?.notes ?? 'Notes',
                            ),
                          ],
                          if (appointment.createdAt != null ||
                              appointment.updatedAt != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  if (appointment.createdAt != null)
                                    _buildCompactInfoRow(
                                      Icons.add_circle_outline,
                                      DateFormat(
                                              'dd MMM yyyy HH:mm',
                                              ref
                                                  .watch(localeProvider)
                                                  .locale
                                                  .toString())
                                          .format(appointment.createdAt!),
                                      label:
                                          localizations?.createdAt ?? 'Created',
                                    ),
                                  if (appointment.updatedAt != null) ...[
                                    const SizedBox(height: 6),
                                    _buildCompactInfoRow(
                                      Icons.update_outlined,
                                      DateFormat(
                                              'dd MMM yyyy HH:mm',
                                              ref
                                                  .watch(localeProvider)
                                                  .locale
                                                  .toString())
                                          .format(appointment.updatedAt!),
                                      label:
                                          localizations?.updatedAt ?? 'Updated',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          // Scroll indicator hint
                          const SizedBox(height: 8),
                          Center(
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    // Fade gradient at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 20,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Enhanced Action Buttons for Doctors/Receptionists
              Consumer(
                builder: (context, ref, child) {
                  final authState = ref.read(authProvider);
                  final user = authState.user;
                  final userDoctorId =
                      user?.additionalData?['doctor']?['id'] as int?;
                  final canPerformActions = user != null &&
                      (user.isAdmin == 1 ||
                          user.isReceptionist == 1 ||
                          (user.isDoctor == 1 &&
                              (appointment.doctor?.id == userDoctorId ||
                                  appointment.doctor?.user?.id == user.id)));

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                          top: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.1))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (canPerformActions)
                          Text(
                            localizations?.actions ?? 'Actions',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        if (canPerformActions) const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.start,
                          children: [
                            // Quick Status Actions
                            if (canPerformActions) ...[
                              if (!isCompleted)
                                _buildCompactActionButton(
                                  context,
                                  icon: Icons.check_circle_rounded,
                                  label: 'Complete',
                                  color: Colors.green,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _handleSingleStatusUpdate(
                                        appointment, 'completed');
                                  },
                                ),
                              if (!isCancelled)
                                _buildCompactActionButton(
                                  context,
                                  icon: Icons.cancel_rounded,
                                  label: localizations?.cancel ?? 'Cancel',
                                  color: Colors.red,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _handleSingleStatusUpdate(
                                        appointment, 'cancelled');
                                  },
                                ),
                              if (isCancelled)
                                _buildCompactActionButton(
                                  context,
                                  icon: Icons.refresh_rounded,
                                  label:
                                      localizations?.reschedule ?? 'Reschedule',
                                  color: Colors.blue,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _handleSingleStatusUpdate(
                                        appointment, 'scheduled');
                                  },
                                ),
                              _buildCompactActionButton(
                                context,
                                icon: Icons.edit_rounded,
                                label: localizations?.edit ?? 'Edit',
                                color: Colors.blue,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleEditAppointment(appointment);
                                },
                              ),
                            ],
                            // Communication
                            if (!isCompleted &&
                                !isCancelled &&
                                appointment.id != null)
                              _buildCompactActionButton(
                                context,
                                icon: Icons.message_rounded,
                                label: localizations?.sendWhatsAppReminder ??
                                    'WhatsApp',
                                color: const Color(0xFF25D366),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleSendWhatsAppReminder(appointment);
                                },
                              ),
                            // Patient Profile
                            if (canPerformActions &&
                                appointment.patient?.id != null)
                              _buildCompactActionButton(
                                context,
                                icon: Icons.person_rounded,
                                label: localizations?.viewProfile ?? 'Profile',
                                color: Colors.purple,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleViewPatientProfile(appointment);
                                },
                              ),
                            // Add to Calendar
                            _buildCompactActionButton(
                              context,
                              icon: Icons.calendar_today_rounded,
                              label: 'Calendar',
                              color: Colors.blue,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _handleAddToGoogleCalendar(appointment);
                              },
                            ),
                          ],
                        ),
                      ],
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

  Future<void> _handleSendWhatsAppReminder(AppointmentModel appointment) async {
    if (appointment.id == null || !mounted) return;

    final patientName = appointment.patient?.user?.name ?? 'ce patient';

    // Wait a moment to ensure previous dialog is closed
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Show confirmation dialog using the root navigator to stay on current screen
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.message_rounded,
                  color: Color(0xFF25D366),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations?.sendWhatsAppReminder ??
                      'Send WhatsApp Reminder',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            localizations?.localeName == 'fr'
                ? 'Envoyer un rappel WhatsApp à $patientName ?'
                : localizations?.localeName == 'ar'
                    ? 'إرسال تذكير WhatsApp إلى $patientName؟'
                    : 'Send WhatsApp reminder to $patientName?',
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                localizations?.cancel ?? 'Cancel',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp green
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  // Use proper "Send" text based on locale
                  String sendText;
                  if (loc?.localeName == 'fr') {
                    sendText = 'Envoyer';
                  } else if (loc?.localeName == 'ar') {
                    sendText = 'إرسال';
                  } else {
                    sendText = 'Send';
                  }
                  return Text(
                    sendText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    final localizations = AppLocalizations.of(context);
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: localizations?.sending ?? 'Sending...',
      desc: localizations?.sendingWhatsAppReminder ??
          'Sending WhatsApp reminder...',
      dismissOnTouchOutside: false,
    ).show();

    final result = await ref.read(
      sendWhatsAppReminderProvider(appointment.id!).future,
    );

    // Close loading dialog - only pop if we can
    if (mounted) {
      final navigator = Navigator.of(context, rootNavigator: false);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    if (!mounted) return;

    result.when(
      success: (_) {
        if (!mounted) return;

        // Invalidate WhatsApp status provider to refresh status badge
        final statusParams = WhatsAppStatusParams(
          clientId: appointment.patient?.id,
          appointmentId: appointment.id,
        );

        // Wait a moment for message to be saved, then refresh
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ref.invalidate(whatsAppStatusProvider(statusParams));
          }
        });

        // Refresh the appointment list to show updated status
        _refreshAppointments();

        final localizations = AppLocalizations.of(context);
        if (mounted) {
          // Build success message with patient name
          String successMessage;
          if (localizations?.localeName == 'fr') {
            successMessage =
                'Rappel WhatsApp envoyé avec succès !\n\nÀ: $patientName';
          } else if (localizations?.localeName == 'ar') {
            successMessage =
                'تم إرسال تذكير WhatsApp بنجاح!\n\nإلى: $patientName';
          } else {
            successMessage =
                'WhatsApp reminder sent successfully!\n\nTo: $patientName';
          }

          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.scale,
            title: localizations?.success ?? 'Success',
            desc: successMessage,
            btnOkText: localizations?.ok ?? 'OK',
            btnOkColor: const Color(0xFF25D366), // WhatsApp green
            btnOkOnPress: () {},
            titleTextStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            descTextStyle: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
            padding: const EdgeInsets.all(20),
          ).show();
        }
      },
      failure: (error) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context);
        String errorMessage = localizations?.failedToSendWhatsAppReminder ??
            'Failed to send WhatsApp reminder. Please try again.';

        if (error.contains('Daily message limit') || error.contains('429')) {
          errorMessage = localizations?.dailyMessageLimitReached ??
              'Daily message limit reached. Please try again tomorrow.';
        } else if (error.isNotEmpty) {
          errorMessage = error;
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: localizations?.error ?? 'Error',
          desc: errorMessage,
          btnOkText: 'OK',
          btnOkColor: Colors.red,
          btnOkOnPress: () {},
        ).show();
      },
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Compact badge
  Widget _buildCompactBadge(Color color, IconData? icon, String text,
      {bool isIcon = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && isIcon) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Compact info row
  Widget _buildCompactInfoRow(IconData icon, String value, {String? label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (label != null) const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact phone row
  Widget _buildCompactPhoneRow(String phoneNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phoneNumber,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact phone row with quick actions
  Widget _buildCompactPhoneRowWithActions(String phoneNumber, [AppointmentModel? appointment]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phoneNumber,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Quick call button
          Material(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _handlePhoneCall(phoneNumber),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Quick WhatsApp button
          Material(
            color: const Color(0xFF25D366).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _handleWhatsAppMessage(phoneNumber, appointment),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.message_rounded,
                  color: Color(0xFF25D366),
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Copy button
          Material(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _handleCopyToClipboard(phoneNumber, 'Phone number'),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.copy_rounded,
                  color: Colors.grey[700],
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Calculate time remaining until appointment
  Map<String, dynamic>? _calculateTimeRemaining(
      DateTime appointmentDate, String time) {
    try {
      final timeParts = time.split(':');
      if (timeParts.length < 2) return null;

      final appointmentDateTime = DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final now = DateTime.now();
      final difference = appointmentDateTime.difference(now);

      final isPast = difference.isNegative;
      final isToday = appointmentDate.year == now.year &&
          appointmentDate.month == now.month &&
          appointmentDate.day == now.day;

      String text;
      if (isPast) {
        final hoursAgo = difference.inHours.abs();
        if (hoursAgo < 24) {
          text = '${hoursAgo}h ago';
        } else {
          final daysAgo = difference.inDays.abs();
          text = '$daysAgo days ago';
        }
      } else if (isToday) {
        if (difference.inHours < 1) {
          text = 'In ${difference.inMinutes} minutes';
        } else {
          text = 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
        }
      } else {
        final days = difference.inDays;
        text = 'In $days days';
      }

      return {
        'text': text,
        'isPast': isPast,
        'isToday': isToday,
        'difference': difference,
      };
    } catch (e) {
      return null;
    }
  }

  // Handle phone call
  Future<void> _handlePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot make call to $phoneNumber')),
        );
      }
    }
  }

  // Handle WhatsApp message — opens WhatsApp with a pre-filled suggested message
  Future<void> _handleWhatsAppMessage(String phoneNumber,
      [AppointmentModel? appointment]) async {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final waNumber = digitsOnly.startsWith('212')
        ? digitsOnly
        : (digitsOnly.startsWith('0') && digitsOnly.length >= 9)
            ? '212${digitsOnly.substring(1)}'
            : digitsOnly;

    final text = _buildWhatsAppSuggestedMessage(appointment);
    final encodedText = Uri.encodeComponent(text);

    // Try native whatsapp:// scheme first (works better on Android for pre-filled text)
    final nativeUri = Uri.parse('whatsapp://send?phone=$waNumber&text=$encodedText');
    final webUri = Uri.parse('https://wa.me/$waNumber?text=$encodedText');

    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open WhatsApp for $phoneNumber')),
        );
      }
    }
  }

  /// Build a suggested Arabic WhatsApp message.
  /// If an appointment is provided, includes date/time/doctor details.
  String _buildWhatsAppSuggestedMessage([AppointmentModel? appointment]) {
    if (appointment == null) {
      return 'السلام عليكم، نتمنى لكم دوام الصحة والعافية. 🙏';
    }

    final patientName = appointment.patient?.user?.name ?? '';
    final doctorName = appointment.doctor?.user?.name ?? '';
    final dateStr = appointment.appointmentDate;
    final timeStr = appointment.appointmentTime;

    // Format date in Arabic — e.g. يوم الأربعاء، 08 أبريل 2026 (2026-04-08)
    String formattedDate = dateStr ?? '';
    String formattedTime = timeStr ?? '';
    if (dateStr != null) {
      try {
        // weekday: 1=Mon,2=Tue,3=Wed,4=Thu,5=Fri,6=Sat,7=Sun → index by (weekday % 7)
        // 1%7=1,2%7=2,3%7=3,4%7=4,5%7=5,6%7=6,7%7=0
        const days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
        const months = {
          1: 'يناير', 2: 'فبراير', 3: 'مارس', 4: 'أبريل',
          5: 'مايو', 6: 'يونيو', 7: 'يوليو', 8: 'أغسطس',
          9: 'سبتمبر', 10: 'أكتوبر', 11: 'نوفمبر', 12: 'ديسمبر',
        };
        final d = DateTime.parse(dateStr);
        final dayName = days[d.weekday % 7];
        final dayNum = d.day.toString().padLeft(2, '0');
        final monthName = months[d.month]!;
        formattedDate = 'يوم $dayName، $dayNum $monthName ${d.year} ($dateStr)';
      } catch (_) {}
    }

    if (timeStr != null) {
      try {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1].substring(0, 2);
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        final String period;
        if (hour < 12) {
          period = 'صباحًا';
        } else if (hour < 17) {
          period = 'بعد الظهر';
        } else {
          period = 'مساءً';
        }
        final paddedHour = hour.toString().padLeft(2, '0');
        formattedTime = '$hour12:$minute $period ($paddedHour:$minute)';
      } catch (_) {}
    }

    final lines = <String>[
      'السلام عليكم${patientName.isNotEmpty ? ' $patientName' : ''}،',
      '',
      'هذا تذكير بموعدكم القادم:',
      '',
      '📅 $formattedDate',
      '⏰ على الساعة $formattedTime',
      if (doctorName.isNotEmpty) '👨‍⚕️ مع الدكتور: $doctorName',
      '',
      'نرجو الحضور قبل 10 دقائق من الموعد. ⌛',
      'نتمنى لكم دوام الصحة والعافية. 💚',
    ];

    return lines.join('\n');
  }

  /// Open WhatsApp with pre-filled thank-you message (location + review map + app link).
  Future<void> _openThankYouWhatsApp(AppointmentModel appointment) async {
    final phone = appointment.patient?.phoneNumber ??
        appointment.patient?.phone ??
        appointment.patient?.additionalData?['phone_number']?.toString();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يوجد رقم هاتف للمريض. لا يمكن فتح واتساب.',
            ),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
      return;
    }
    String address = 'عنوان العيادة';
    String? mapUrl;
    String tenantName = 'عيادتنا';
    try {
      final result = await ref.read(tenantWebsiteConfigProvider.future);
      result.when(
        success: (website) {
          tenantName = website.title?.trim().isNotEmpty == true
              ? website.title!
              : tenantName;
          address = website.contactAddress ?? address;
          mapUrl = website.googleMapsReviewUrl ?? website.googleMapsLocation;
        },
        failure: (_) {},
      );
    } catch (_) {
      try {
        final result = await ref.read(publicTenantWebsiteProvider.future);
        result.when(
          success: (website) {
            tenantName = website.title?.trim().isNotEmpty == true
                ? website.title!
                : tenantName;
            address = website.contactAddress ?? address;
            mapUrl = website.googleMapsReviewUrl ?? website.googleMapsLocation;
          },
          failure: (_) {},
        );
      } catch (_) {}
    }
    // Friendly message in Arabic, including cabinet/tenant name
    final lines = <String>[
      'شكراً لزيارتكم في $tenantName 🙏',
      '',
      'نتمنى لكم دوام الصحة والعافية.',
      '',
      'عنواننا: $address',
    ];
    // Use current tenant's map/review URL only (no app store link)
    final reviewUrl = mapUrl;
    if (reviewUrl != null && reviewUrl.isNotEmpty) {
      lines.add('');
      lines.add('نسعد بتقييمكم على خرائط Google:');
      lines.add(reviewUrl);
    }
    final text = lines.join('\n');
    // wa.me needs digits only, no + (e.g. 212612345678 for Morocco)
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    final waNumber = digitsOnly.startsWith('212')
        ? digitsOnly
        : (digitsOnly.startsWith('0') && digitsOnly.length >= 9)
            ? '212${digitsOnly.substring(1)}'
            : (digitsOnly.length >= 9 ? '212$digitsOnly' : '212$digitsOnly');
    final patientName =
        appointment.patient?.user?.name ?? 'Patient';
    final uri = Uri.parse(
      'https://wa.me/$waNumber?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم فتح واتساب لإرسال الرسالة إلى $patientName - $phone',
            ),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  // Copy to clipboard
  Future<void> _handleCopyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Handle view patient profile
  void _handleViewPatientProfile(AppointmentModel appointment) {
    if (appointment.patient?.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PatientDetailScreen(patientId: appointment.patient!.id!),
      ),
    );
  }

  // Handle add to Google Calendar
  Future<void> _handleAddToGoogleCalendar(AppointmentModel appointment) async {
    if (appointment.appointmentDate == null ||
        appointment.appointmentTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment date/time is missing')),
      );
      return;
    }

    try {
      final timeParts = appointment.appointmentTime!.split(':');
      final appointmentDateTime = DateTime.parse(appointment.appointmentDate!);
      final startDateTime = DateTime(
        appointmentDateTime.year,
        appointmentDateTime.month,
        appointmentDateTime.day,
        int.parse(timeParts[0]),
        int.parse(timeParts.length > 1 ? timeParts[1] : '0'),
      );
      final endDateTime = startDateTime.add(const Duration(hours: 1));

      final title =
          '${appointment.service?.title ?? 'Appointment'} - ${appointment.patient?.user?.name ?? 'Patient'}';
      final description =
          'Appointment with ${appointment.patient?.user?.name ?? 'Patient'}\n'
          'Service: ${appointment.service?.title ?? 'N/A'}\n'
          'Doctor: ${appointment.doctor?.user?.name ?? 'N/A'}';

      final uri = Uri.parse(
        'https://calendar.google.com/calendar/render?'
        'action=TEMPLATE&'
        'text=${Uri.encodeComponent(title)}&'
        'dates=${startDateTime.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').substring(0, 15)}/'
        '${endDateTime.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').substring(0, 15)}&'
        'details=${Uri.encodeComponent(description)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open Google Calendar')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Compact action button
  Widget _buildCompactActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsRowWithWhatsAppStatus(String label, String value,
      int? patientId, int? appointmentId, AppointmentModel? appointment) {
    debugPrint(
        '📱📱📱 [Details Row] Building - label: $label, patientId: $patientId, appointmentId: $appointmentId');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
          // WhatsApp Status Badge - Only show when status exists (like Next.js: whatsappStatus.status && ...)
          Consumer(
            builder: (context, ref, child) {
              if (patientId == null && appointmentId == null) {
                return const SizedBox.shrink();
              }

              final statusParams = WhatsAppStatusParams(
                clientId: patientId,
                appointmentId: appointmentId,
              );

              final statusStream =
                  ref.watch(whatsAppStatusProvider(statusParams));

              return statusStream.when(
                data: (result) {
                  return result.when(
                    success: (data) {
                      // Only show badge if status exists and is not 'not_found' (like Next.js)
                      final status = data['status'] as String?;
                      if (status == null || status == 'not_found') {
                        return const SizedBox.shrink();
                      }

                      // Show badge (matching Next.js: {whatsappStatus.status && ...})
                      return Padding(
                        padding: const EdgeInsets.only(left: 100, top: 4),
                        child: Row(
                          children: [
                            const Text(
                              'WhatsApp Status: ',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            WhatsAppStatusBadge(
                              status: status,
                              showLabel: true,
                            ),
                          ],
                        ),
                      );
                    },
                    failure: (_) => const SizedBox.shrink(),
                  );
                },
                loading: () => const SizedBox
                    .shrink(), // Don't show loading, wait for data
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppStatusBadge(int? patientId, int? appointmentId,
      [AppointmentModel? appointment]) {
    debugPrint(
        '🔵🔵🔵 [WhatsApp Status Badge] CALLED - patientId: $patientId, appointmentId: $appointmentId');

    if (patientId == null && appointmentId == null) {
      debugPrint('🔴 [WhatsApp Status Badge] No IDs - returning empty');
      return const SizedBox.shrink();
    }

    // Use Consumer to ensure we have proper Riverpod context
    return Consumer(
      builder: (context, ref, child) {
        final statusParams = WhatsAppStatusParams(
          clientId: patientId,
          appointmentId: appointmentId,
        );

        debugPrint(
            '🟢 [WhatsApp Status Badge] Watching provider - clientId=$patientId, appointmentId=$appointmentId');
        final statusStream = ref.watch(whatsAppStatusProvider(statusParams));
        debugPrint(
            '🟡 [WhatsApp Status Badge] Stream type: ${statusStream.runtimeType}');

        // Show notifications for status changes
        ref.listen(whatsAppStatusProvider(statusParams), (previous, next) {
          next.whenData((result) {
            result.when(
              success: (data) {
                final status = data['status'] as String?;
                final messageId = data['message_id'] as String?;

                if (status != null &&
                    status != 'not_found' &&
                    messageId != null) {
                  // Show notification for important status changes
                  final notificationService = NotificationService();
                  notificationService.showWhatsAppStatusNotification(
                    messageId: messageId,
                    status: status,
                    patientName: appointment?.patient?.user?.name,
                    appointmentId: appointment?.id?.toString(),
                  );
                }
              },
              failure: (_) {},
            );
          });
        });

        return statusStream.when(
          data: (result) {
            debugPrint('🟢 [WhatsApp Status Badge] Stream has data: $result');
            return result.when(
              success: (data) {
                debugPrint('✅ [WhatsApp Status Badge] Success! Data: $data');
                final status = data['status'] as String?;
                debugPrint('📊 [WhatsApp Status Badge] Status value: $status');

                // Show loading/pending state if not found (message might be sending)
                if (status == 'not_found') {
                  debugPrint(
                      '⏳ [WhatsApp Status Badge] Status is not_found, showing pending');
                  return Row(
                    children: [
                      const Text(
                        'WhatsApp Status: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pending...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                }

                final finalStatus = status ?? 'unknown';
                debugPrint(
                    '🎯 [WhatsApp Status Badge] Displaying status: $finalStatus');
                return Row(
                  children: [
                    const Text(
                      'WhatsApp Status: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    WhatsAppStatusBadge(
                      status: finalStatus,
                      showLabel: true,
                    ),
                  ],
                );
              },
              failure: (error) {
                debugPrint('❌ [WhatsApp Status Badge] Failure: $error');
                return Row(
                  children: [
                    const Text(
                      'WhatsApp Status: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      'Error: $error',
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ],
                );
              },
            );
          },
          loading: () {
            debugPrint('⏳ [WhatsApp Status Badge] Loading state');
            return Row(
              children: [
                const Text(
                  'WhatsApp Status: ',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            );
          },
          error: (error, stack) {
            debugPrint('❌ [WhatsApp Status Badge] Stream error: $error');
            return Row(
              children: [
                const Text(
                  'WhatsApp Status: ',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  'Error',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Compact version for appointment cards
  Widget _buildWhatsAppStatusBadgeCompact(int? patientId, int? appointmentId,
      [AppointmentModel? appointment]) {
    if (patientId == null && appointmentId == null) {
      return const SizedBox.shrink();
    }

    final statusParams = WhatsAppStatusParams(
      clientId: patientId,
      appointmentId: appointmentId,
    );

    final statusStream = ref.watch(whatsAppStatusProvider(statusParams));

    return statusStream.when(
      data: (result) {
        return result.when(
          success: (data) {
            // Show loading state if not found (message might be sending)
            if (data['status'] == 'not_found') {
              return const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              );
            }
            final status = data['status'] as String? ?? 'unknown';
            return WhatsAppStatusBadge(
              status: status,
              showLabel: true,
            );
          },
          failure: (_) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _statusLabel(String? status, [AppLocalizations? localizations]) {
    // Use provided localizations or get from context
    final loc = localizations ?? AppLocalizations.of(context);
    switch (status) {
      case 'completed':
        return loc?.completed ?? 'Completed';
      case 'cancelled':
        return loc?.cancelled ?? 'Cancelled';
      case 'no_show':
        return loc?.noShow ?? 'No Show';
      case 'scheduled':
      default:
        return loc?.scheduled ?? 'Scheduled';
    }
  }

  String _priorityLabel(String? priority) {
    final localizations = AppLocalizations.of(context);
    switch (priority) {
      case 'high':
        return localizations?.high ?? 'High';
      case 'low':
        return localizations?.low ?? 'Low';
      case 'medium':
      default:
        return localizations?.medium ?? 'Medium';
    }
  }

  void _handleEditAppointment(AppointmentModel appointment) {
    final localizations = AppLocalizations.of(context);
    if (appointment.id == null || appointment.doctor?.id == null) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.cannotEditAppointment ??
              'Cannot edit this appointment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime selectedDate = appointment.appointmentDate != null
        ? DateTime.parse(appointment.appointmentDate!)
        : DateTime.now();
    String selectedTime = _formatTime(appointment.appointmentTime);
    final doctorId = appointment.doctor!.id!;

    showDialog(
      context: context,
      builder: (context) => _EditAppointmentDialog(
        appointment: appointment,
        initialDate: selectedDate,
        initialTime: selectedTime,
        doctorId: doctorId,
        onUpdate: (date, time) async {
          final formattedDate = DateFormat('yyyy-MM-dd').format(date);
          String formattedTime = time;
          if (formattedTime.contains(':') &&
              formattedTime.split(':').length == 3) {
            final parts = formattedTime.split(':');
            formattedTime = '${parts[0]}:${parts[1]}';
          }
          if (!RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$')
              .hasMatch(formattedTime)) {
            formattedTime = _formatTime(time);
          }

          final appointmentData = <String, dynamic>{
            'doctor_id': doctorId.toString(),
            'appointment_date': formattedDate,
            'appointment_time': formattedTime,
            'priority': appointment.priority ?? 'medium',
            'status': appointment.status ?? 'scheduled',
            'notes': appointment.notes,
            'service_id': appointment.service?.id?.toString(),
            'patient_id': appointment.patient?.id,
          };

          final result = await ref.read(
            updateAppointmentProvider(
              UpdateAppointmentParams(
                appointmentId: appointment.id!,
                appointmentData: appointmentData,
              ),
            ).future,
          );

          result.when(
            success: (_) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizations?.appointmentUpdatedSuccessfully ??
                      'Appointment updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _refreshAppointments();
            },
            failure: (error) {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${localizations?.error ?? 'Error'}: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null) return '00:00';
    try {
      if (time.contains(':') && time.split(':').length == 3) {
        final parts = time.split(':');
        return '${parts[0]}:${parts[1]}';
      }
      return time;
    } catch (e) {
      return '00:00';
    }
  }
}

// Edit Appointment Dialog Widget
class _EditAppointmentDialog extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final DateTime initialDate;
  final String initialTime;
  final int doctorId;
  final Function(DateTime date, String time) onUpdate;

  const _EditAppointmentDialog({
    required this.appointment,
    required this.initialDate,
    required this.initialTime,
    required this.doctorId,
    required this.onUpdate,
  });

  @override
  ConsumerState<_EditAppointmentDialog> createState() =>
      _EditAppointmentDialogState();
}

class _EditAppointmentDialogState
    extends ConsumerState<_EditAppointmentDialog> {
  late DateTime _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedTime = widget.initialTime;
  }

  Future<void> _selectDate(BuildContext context) async {
    final locale = ref.watch(localeProvider).locale;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: locale,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }

  String _normalizeTime(String time) {
    if (time.contains(':') && time.split(':').length == 3) {
      final parts = time.split(':');
      return '${parts[0]}:${parts[1]}';
    }
    if (RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(time)) {
      return time;
    }
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
    } catch (e) {
      // If parsing fails, return default
    }
    return '09:00';
  }

  Future<void> _handleSave() async {
    if (_selectedTime == null || _selectedTime!.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(localizations?.pleaseSelectTime ?? 'Please select a time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final normalizedTime = _normalizeTime(_selectedTime!);
    await widget.onUpdate(_selectedDate, normalizedTime);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeSlotsAsync = ref.watch(
      timeSlotsProvider(
        TimeSlotsParams(
          doctorId: widget.doctorId,
          date: formattedDate,
        ),
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.editAppointment ?? 'Edit Appointment',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.appointment.patient?.user?.name ?? 'Inconnu',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                final locale = ref.watch(localeProvider).locale;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.date ?? 'Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat(
                                        'EEEE d MMMM yyyy', locale.toString())
                                    .format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.time ?? 'Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            timeSlotsAsync.when(
              data: (result) => result.when(
                success: (timeSlots) {
                  if (timeSlots.isEmpty) {
                    final localizations = AppLocalizations.of(context);
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        localizations?.noTimeSlotsAvailable ??
                            'No time slots available for this date',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    );
                  }

                  final availableSlots =
                      timeSlots.where((slot) => slot.available).toList();

                  if (_selectedTime != null &&
                      !availableSlots
                          .any((slot) => slot.time == _selectedTime)) {
                    availableSlots.add(TimeSlotModel(
                      time: _selectedTime!,
                      available: true,
                    ));
                    availableSlots.sort((a, b) => a.time.compareTo(b.time));
                  }

                  return Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: availableSlots.isEmpty
                        ? Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                    localizations?.noTimeSlotsAvailableShort ??
                                        'No time slots available'),
                              );
                            },
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableSlots.length,
                            itemBuilder: (context, index) {
                              final slot = availableSlots[index];
                              final isSelected = _selectedTime == slot.time;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTime = slot.time;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        slot.time,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
                failure: (error) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Erreur: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'Erreur: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(localizations?.cancel ?? 'Cancel'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(localizations?.save ?? 'Save'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
