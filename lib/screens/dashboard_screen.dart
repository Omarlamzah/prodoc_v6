import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui';
import 'package:glass_kit/glass_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../providers/dashboard_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/tenant_website_providers.dart';
import '../data/models/tenant_website_model.dart';
import '../data/models/dashboard_model.dart';
import '../core/utils/result.dart';
import '../utils/web_download_helper.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import 'login_screen.dart';
import 'create_appointment_screen.dart';
import 'create_prescription_screen.dart';
import 'attach_file_to_record_screen.dart';
import 'patients_screen.dart';
import 'public_appointment_booking_screen.dart';
import 'appointments_screen.dart';
import 'doctor_calendar_screen.dart';
import 'medical_records_screen.dart';
import 'prescriptions_screen.dart';
import 'invoices_screen_modern.dart';
import 'waiting_room_screen.dart';
import '../core/config/api_constants.dart';
import '../widgets/app_drawer.dart';
import '../providers/waiting_room_providers.dart';
import '../widgets/communication/medical_communication_hub.dart';
import '../services/review_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../providers/api_providers.dart';
import '../services/subscription_service.dart';
import '../data/models/subscription_model.dart';
import '../widgets/subscription_expiration_dialog.dart';
import 'subscription_management_screen.dart';
import 'cabinet_info_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/global_appointment_sync.dart';
import 'ai_assistant_screen_full.dart';
import 'referral_screen.dart';
import '../widgets/api_notification_bell.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/face_detection_camera.dart';
import '../data/models/patient_model.dart';
import 'patient_detail_screen.dart';

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterNotifier, String>(
        DashboardFilterNotifier.new);

class DashboardFilterNotifier extends Notifier<String> {
  @override
  String build() {
    return 'All Doctors';
  }

  void setFilter(String filter) {
    state = filter;
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isScanningId = false;
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasCheckedReview = false;
  bool _hasCheckedSubscription = false;
  bool _subscriptionExpired = false;
  GlobalAppointmentSync?
      _syncService; // Save reference to avoid using ref in dispose

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Save sync service reference before any async operations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Save the sync service reference while widget is still mounted
      _syncService = ref.read(globalAppointmentSyncProvider);
      _checkReviewPrompt();
      _checkSubscriptionExpiration();
      _startAppointmentSync();
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Stop appointment sync when leaving dashboard - use saved reference
    _syncService?.stopSync();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes to foreground, sync appointments
    if (state == AppLifecycleState.resumed) {
      final authState = ref.read(authProvider);
      if (authState.isAuth == true) {
        final syncService = ref.read(globalAppointmentSyncProvider);
        // Force immediate sync when app comes to foreground
        syncService.forceSync(ref);
        debugPrint('[Dashboard] App resumed, forcing appointment sync');
      }
    }
  }

  /// Start global appointment sync when user is authenticated
  void _startAppointmentSync() {
    final authState = ref.read(authProvider);
    if (authState.isAuth == true) {
      final syncService = ref.read(globalAppointmentSyncProvider);
      syncService.startSync(ref);
      debugPrint('[Dashboard] Started global appointment sync');
    }
  }

  List _safeList(dynamic value) {
    if (value is List) return value;
    return [];
  }

  Future<void> _checkReviewPrompt() async {
    if (_hasCheckedReview) return;
    _hasCheckedReview = true;

    // Wait a bit for the screen to load
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final shouldShow = await ReviewService.shouldShowReviewPrompt();
    if (shouldShow && mounted) {
      _showReviewDialog();
    }
  }

  Future<void> _showReviewDialog() async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);

    AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: localizations?.reviewDialogTitle ?? 'Hello! 👋',
      desc: localizations?.reviewDialogMessage ??
          'You\'ve been using ProDoc for a while now. Would you be ready to leave us a review on the Play Store? It would help us a lot!',
      btnOkText: localizations?.rateNow ?? 'Rate now ⭐',
      btnCancelText: localizations?.maybeLater ?? 'Maybe later',
      btnOkOnPress: () async {
        await ReviewService.completeReview();
        await _openPlayStoreReview();
      },
      btnCancelOnPress: () async {
        await ReviewService.dismissReviewPrompt();
      },
      btnOkColor: Colors.amber,
      btnCancelColor: Colors.grey,
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      descTextStyle: const TextStyle(
        fontSize: 16,
      ),
      padding: const EdgeInsets.all(20),
    ).show();
  }

  Future<void> _openPlayStoreReview() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.nextpital.prodoc';
    final uri = Uri.parse(playStoreUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Error opening Play Store: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.cannotOpenPlayStore ??
                'Unable to open Play Store. Please try again later.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _checkSubscriptionExpiration() async {
    if (_hasCheckedSubscription) return;
    _hasCheckedSubscription = true;

    // Wait a bit for the screen to load and auth to be ready
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Save ref state before async operations to avoid using ref when unmounted
    final authState = ref.read(authProvider);
    if (authState.isAuth != true) {
      debugPrint('[Subscription Check] User not authenticated, skipping check');
      return;
    }

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);

      // Try with auth first, fallback to public if needed
      Result<Map<String, dynamic>> result;
      try {
        result = await subscriptionService.getSubscriptions();
      } catch (e) {
        debugPrint(
            '[Subscription Check] Auth failed, trying public endpoint: $e');
        result = await subscriptionService.getSubscriptionsPublic();
      }

      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final subscriptions = (data['subscriptions'] is List)
            ? (data['subscriptions'] as List).cast<SubscriptionModel>()
            : <SubscriptionModel>[];

        // Check if subscription is already expired (no active subscription)
        final hasActive = subscriptions.any((s) {
          if (!s.isActive) return false;
          if (s.status != 'active' && s.status != 'trialing') return false;
          final endDate = s.status == 'trialing' && s.trialEndsAt != null
              ? s.trialEndsAt!
              : s.endsAt;
          return endDate != null && endDate.isAfter(DateTime.now());
        });
        if (mounted) {
          setState(() => _subscriptionExpired = !hasActive);
        }

        // Check if any subscription expires in less than 3 days (but still active)
        final daysUntilExpiration = SubscriptionService.checkExpirationWarning(
          subscriptions,
          3, // threshold: 3 days
        );

        if (daysUntilExpiration != null && mounted) {
          debugPrint(
            '[Subscription Check] Subscription expires in $daysUntilExpiration days, showing warning',
          );
          await SubscriptionExpirationDialog.show(
            context,
            daysUntilExpiration,
          );
        } else {
          debugPrint('[Subscription Check] No expiration warning needed');
        }
      } else if (result is Failure<Map<String, dynamic>>) {
        debugPrint(
            '[Subscription Check] Failed to fetch subscriptions: ${result.message}');
      }
    } catch (e) {
      debugPrint('[Subscription Check] Error checking subscription: $e');
      // Silently fail - don't interrupt user experience
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale provider to rebuild when language changes
    final localeState = ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context);

    debugPrint('[Dashboard] build() called');
    debugPrint(
        '[Dashboard] localeState.locale: ${localeState.locale.languageCode}_${localeState.locale.countryCode}');
    debugPrint(
        '[Dashboard] AppLocalizations.of(context) is null: ${localizations == null}');
    if (localizations != null) {
      debugPrint(
          '[Dashboard] Current localization language: ${localizations.dashboard}');
    }

    final authState = ref.watch(authProvider);
    final timeRange = ref.watch(timeRangeProvider);
    // Use public provider first (works with selected tenant), fallback to authenticated provider
    final tenantWebsiteAsync = ref.watch(publicTenantWebsiteProvider);

    final dashboardAsync = authState.isAuth == true
        ? ref.watch(dashboardDataProvider(timeRange))
        : const AsyncValue<Result<DashboardModel>>.loading();

    final refresh = ref.watch(dashboardRefreshProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      final syncService = ref.read(globalAppointmentSyncProvider);

      if (next.isAuth == false && previous?.isAuth == true) {
        // User logged out - stop sync
        syncService.stopSync();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else if (next.isAuth == true && previous?.isAuth != true) {
        // User logged in - start sync
        syncService.startSync(ref);
        debugPrint('[Dashboard] User logged in, started appointment sync');
      }
    });

    if (authState.isAuth == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.isAuth == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F0F23)
          : const Color(0xFFF0F2F5),
      drawer: const AppDrawer(),
      appBar: _buildModernAppBar(
          context, authState, timeRange, ref, tenantWebsiteAsync),
      body: Stack(
        children: [
          Positioned.fill(
            child: dashboardAsync.when(
              data: (result) {
                if (result is Success<DashboardModel>) {
                  final dashboardData = result.data;
                  return RefreshIndicator(
                    onRefresh: () async {
                      refresh(timeRange);
                      await ref.read(dashboardDataProvider(timeRange).future);
                    },
                    child: _buildResponsiveLayout(
                      context,
                      authState,
                      dashboardData,
                      ref,
                      timeRange,
                      refresh,
                      tenantWebsiteAsync,
                      subscriptionExpired: _subscriptionExpired,
                    ),
                  );
                } else if (result is Failure<DashboardModel>) {
                  final isSubscriptionError = result.message
                      .toLowerCase()
                      .contains('expiré') ||
                      result.message.toLowerCase().contains('expired') ||
                      result.message.toLowerCase().contains('abonnement');
                  return CustomErrorWidget(
                    message: result.message,
                    onRetry: () => refresh(timeRange),
                    subscriptionButtonLabel: isSubscriptionError
                        ? 'Abonnements'
                        : null,
                    onSubscriptionTap: isSubscriptionError
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SubscriptionManagementScreen(),
                              ),
                            );
                          }
                        : null,
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) {
                final msg = error.toString();
                final isSubscriptionError = msg.toLowerCase().contains('expiré') ||
                    msg.toLowerCase().contains('expired') ||
                    msg.toLowerCase().contains('abonnement');
                return CustomErrorWidget(
                  message: msg,
                  onRetry: () => refresh(timeRange),
                  subscriptionButtonLabel:
                      isSubscriptionError ? 'Abonnements' : null,
                  onSubscriptionTap: isSubscriptionError
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SubscriptionManagementScreen(),
                            ),
                          );
                        }
                      : null,
                );
              },
            ),
          ),
          if (authState.user?.isPatient != 1) const MedicalCommunicationHub(),
          // AI Assistant - Navigate to full screen (bottom left)
          Positioned(
            bottom: 20,
            left: 20,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xFF667eea),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AiAssistantScreenFull(),
                    ),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: const Icon(Icons.chat, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
      // Quick Actions Button - Bottom Right (default position)
      floatingActionButton: _buildModernFAB(context, authState.user, ref),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context,
    AuthState authState,
    String timeRange,
    WidgetRef ref,
    AsyncValue<Result<TenantWebsiteModel>> tenantWebsiteAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF0F0F23).withOpacity(0.8)
          : Colors.white.withOpacity(0.8),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0F0F23).withOpacity(0.9),
                        const Color(0xFF1A1A2E).withOpacity(0.8),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      title: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return tenantWebsiteAsync.when(
            data: (result) {
              if (result is Success<TenantWebsiteModel>) {
                return Text(
                  result.data.title ??
                      (localizations?.dashboard ?? 'Dashboard'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 18),
                );
              }
              return Text(
                localizations?.dashboard ?? 'Dashboard',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              );
            },
            loading: () => Text(
              localizations?.dashboard ?? 'Dashboard',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            error: (_, __) => Text(
              localizations?.dashboard ?? 'Dashboard',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          );
        },
      ),
      actions: [
        // Referral / Win (admin only) – trophy icon + “win” label, animated
        if (authState.user?.isAdmin == 1)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: () => _showReferralDialog(context, ref),
              icon: Icon(Icons.emoji_events_rounded, size: 20, color: Theme.of(context).colorScheme.primary)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: 1200.ms, curve: Curves.easeInOut),
              label: Text(
                AppLocalizations.of(context)?.referralShort ?? 'Win',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        // Quick scan patient
        _isScanningId
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.document_scanner_rounded),
                tooltip: 'Quick Find Patient',
                onPressed: () => _showQuickFindSheet(context),
              ),
        // Notification Bell
        const ApiNotificationBell(),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Quick Find Patient ──────────────────────────────────────────────────────

  void _showQuickFindSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Find Patient',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan a Moroccan CNI card or go to patient search.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Scan CNI Card'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _scanCniQuick();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.people_rounded),
                    label: const Text('Search by Name / CNI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanCniQuick() async {
    try {
      File? capturedImage;

      if (kIsWeb) {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (image == null) return;
        capturedImage = File(image.path);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FaceDetectionCamera(
              onImageCaptured: (File image) {
                capturedImage = image;
              },
              onCancel: () {},
            ),
          ),
        );
        if (capturedImage == null) return;
      }

      setState(() => _isScanningId = true);

      final ocrService = ref.read(ocrServiceProvider);
      final dynamic imageFile =
          kIsWeb ? await capturedImage!.readAsBytes() : capturedImage!;

      final result =
          await ocrService.extractMoroccanId(imageFile, extractFace: true);

      setState(() => _isScanningId = false);

      result.when(
        success: (data) {
          final parsed = data is Map ? data['parsed'] as Map? : null;
          final faceRecognition =
              data is Map ? data['face_recognition'] as Map? : null;

          // Validated face match → navigate directly to patient
          if (faceRecognition != null &&
              faceRecognition['matched_patient'] != null &&
              faceRecognition['match_validation_failed'] != true) {
            try {
              final matchedPatient = PatientModel.fromJson(
                  Map<String, dynamic>.from(
                      faceRecognition['matched_patient'] as Map));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Patient matched: ${matchedPatient.user?.name ?? ''}'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PatientDetailScreen(patientId: matchedPatient.id!),
                ),
              );
              return;
            } catch (_) {}
          }

          // No direct match → go to patients screen with search term
          final cni = parsed?['cni_number']?.toString().trim() ?? '';
          final name = parsed?['name']?.toString().trim() ?? '';
          final searchTerm = cni.isNotEmpty ? cni : name;

          if (searchTerm.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Searching for: $searchTerm'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PatientsScreen(),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not extract information from CNI card'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        failure: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scan failed: $message'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      setState(() => _isScanningId = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────

  void _showReferralDialog(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final referralService = ref.read(referralServiceProvider);
    final futureData = referralService.getMyReferralCode();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.card_giftcard_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc?.referralProgram ?? 'Referral Program',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc?.referralDialogInvite ?? 'Invite friends & colleagues — everyone wins!',
                style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                loc?.referralDialogYouEarn ?? 'Share your code. You win free days. They win free days. Simple!',
                style: const TextStyle(fontSize: 13, height: 1.35),
              )
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 350.ms)
                  .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 14),
              FutureBuilder<Result<Map<String, dynamic>>>(
                future: futureData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms);
                  }
                  final result = snapshot.data;
                  if (result == null) return const SizedBox.shrink();
                  return result.when(
                    success: (data) {
                      final code = data['referral_code']?.toString() ?? '—';
                      final rewards = data['rewards'] as Map<String, dynamic>?;
                      final daysYou = rewards?['days_referrer'] ?? 120;
                      final daysThem = rewards?['days_referred'] ?? 90;
                      final youWin = (loc?.referralDialogYouWinDays ?? 'You win %s days free!').replaceAll('%s', '$daysYou');
                      final theyGet = (loc?.referralDialogTheyGetDays ?? 'They win %s days free!').replaceAll('%s', '$daysThem');
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc?.referralDialogYourCode ?? 'Your referral code',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                          )
                              .animate()
                              .fadeIn(delay: 120.ms, duration: 300.ms)
                              .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc?.referralCodeCopied ?? 'Copied!'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(code, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
                                  const SizedBox(width: 8),
                                  Icon(Icons.copy_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                ],
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 180.ms, duration: 320.ms)
                              .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), curve: Curves.easeOutCubic)
                              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.emoji_events_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(youWin, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.card_giftcard_rounded, size: 16, color: Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 6),
                                    Text(theyGet, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                                  ],
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 260.ms, duration: 350.ms)
                              .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), curve: Curves.easeOutCubic)
                              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                        ],
                      );
                    },
                    failure: (_) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc?.referralDialogShareLink ?? 'Share your personal link from the Referral Program page.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 320.ms, duration: 300.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Text(loc?.cancel ?? 'Cancel', style: const TextStyle(fontSize: 14)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReferralScreen()),
              );
            },
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            icon: const Icon(Icons.card_giftcard_rounded, size: 18),
            label: Text(loc?.referralDialogOpen ?? 'Open Referral Program', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeChips(
      BuildContext context, String timeRange, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;
    final localizations = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeRangeChip(
            context: context,
            label: localizations?.day ?? 'Day',
            value: 'day',
            isSelected: timeRange == 'day',
            icon: Icons.today_rounded,
            onTap: () => ref.read(timeRangeProvider.notifier).update('day'),
            isSmall: isSmall,
            primaryColor: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildTimeRangeChip(
            context: context,
            label: localizations?.week ?? 'Week',
            value: 'week',
            isSelected: timeRange == 'week',
            icon: Icons.date_range_rounded,
            onTap: () => ref.read(timeRangeProvider.notifier).update('week'),
            isSmall: isSmall,
            primaryColor: primaryColor,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildTimeRangeChip(
            context: context,
            label: localizations?.month ?? 'Month',
            value: 'month',
            isSelected: timeRange == 'month',
            icon: Icons.calendar_month_rounded,
            onTap: () => ref.read(timeRangeProvider.notifier).update('month'),
            isSmall: isSmall,
            primaryColor: primaryColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeChip({
    required BuildContext context,
    required String label,
    required String value,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmall,
    required Color primaryColor,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 16 : 20,
            vertical: isSmall ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300]!,
                    width: 1,
                  ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSmall ? 18 : 20,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey[700]),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.grey[800]),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    AuthState authState,
    DashboardModel dashboardData,
    WidgetRef ref,
    String timeRange,
    Function(String) refresh,
    AsyncValue<Result<TenantWebsiteModel>> tenantWebsiteAsync, {
    bool subscriptionExpired = false,
  }) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600 && size.width < 1024;
    final isDesktop = size.width >= 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subscription expired banner – go to subscription screen
          if (subscriptionExpired && authState.user?.isAdmin == 1)
            _buildSubscriptionExpiredBanner(context),

          // Modern Welcome Banner
          if (authState.user != null)
            _buildModernWelcomeBanner(
                context, authState.user!, tenantWebsiteAsync, ref),

          const SizedBox(height: 28),

          // Create Appointment Card
          if (authState.user != null &&
              (authState.user!.isAdmin == 1 ||
                  authState.user!.isReceptionist == 1 ||
                  authState.user!.isPatient == 1))
            _buildCreateAppointmentCard(context),

          // Create Prescription Card
          if (authState.user != null &&
              (authState.user!.isDoctor == 1 || authState.user!.isAdmin == 1))
            _buildCreatePrescriptionCard(context),

          // Attach File to Record Card
          if (authState.user != null &&
              (authState.user!.isDoctor == 1 || authState.user!.isAdmin == 1))
            _buildAttachFileCard(context),

          const SizedBox(height: 16),

          // Main Content based on role
          if (authState.user != null) ...[
            if (authState.user!.isAdmin == 1 && dashboardData.admin != null)
              _buildAdminDashboard(context, dashboardData.admin!, ref,
                  timeRange, isDesktop, isTablet, tenantWebsiteAsync),
            if (authState.user!.isDoctor == 1 && dashboardData.doctor != null)
              _buildDoctorDashboard(
                  context, dashboardData.doctor!, isDesktop, isTablet),
            if (authState.user!.isPatient == 1 && dashboardData.patient != null)
              _buildPatientDashboard(
                  context, dashboardData.patient!, isDesktop, isTablet),
            if (authState.user!.isReceptionist == 1 &&
                dashboardData.receptionist != null)
              _buildReceptionistDashboard(
                  context, dashboardData.receptionist!, isDesktop, isTablet),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionExpiredBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SubscriptionManagementScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Abonnement expiré',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Renouvelez pour continuer à utiliser toutes les fonctionnalités.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.credit_card, size: 18),
                  label: const Text('Abonnements'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernWelcomeBanner(
      BuildContext context,
      dynamic user,
      AsyncValue<Result<TenantWebsiteModel>> tenantWebsiteAsync,
      WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentHour = DateTime.now().hour;
    final localizations = AppLocalizations.of(context);
    String greeting = localizations?.goodMorning ?? 'Good morning';
    IconData greetingIcon = Icons.wb_sunny_rounded;

    if (currentHour >= 12 && currentHour < 17) {
      greeting = localizations?.goodAfternoon ?? 'Good afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (currentHour >= 17) {
      greeting = localizations?.goodEvening ?? 'Good evening';
      greetingIcon = Icons.nights_stay_rounded;
    }

    // Get tenant website data
    TenantWebsiteModel? tenantWebsite;
    Color? tenantPrimaryColor;

    tenantWebsiteAsync.whenData((result) {
      if (result is Success<TenantWebsiteModel>) {
        tenantWebsite = result.data;
        // Parse theme colors
        final themeColors = tenantWebsite?.parsedThemeColors;
        if (themeColors != null && themeColors['primary'] != null) {
          try {
            final colorString = themeColors['primary'] as String;
            tenantPrimaryColor =
                Color(int.parse(colorString.replaceAll('#', '0xFF')));
          } catch (e) {
            // Use default color if parsing fails
          }
        }
      }
    });

    final effectivePrimaryColor = tenantPrimaryColor ?? primaryColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: effectivePrimaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.2 : 0.3),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E).withOpacity(0.9),
                        const Color(0xFF16213E).withOpacity(0.7),
                        effectivePrimaryColor.withOpacity(0.3),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        effectivePrimaryColor.withOpacity(0.1),
                        effectivePrimaryColor.withOpacity(0.2),
                      ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              greetingIcon,
                              size: 16,
                              color:
                                  isDark ? Colors.amber : effectivePrimaryColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                greeting,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            tenantWebsite?.title ??
                                user.name ??
                                (AppLocalizations.of(context)?.user ?? 'User'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[800],
                              height: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        if (tenantWebsite?.description != null) ...[
                          const SizedBox(height: 3),
                          Flexible(
                            child: Text(
                              tenantWebsite?.description ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark ? Colors.white60 : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ] else if (user.email != null) ...[
                          const SizedBox(height: 3),
                          Flexible(
                            child: Text(
                              user.email!,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark ? Colors.white60 : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (tenantWebsite != null)
                          _buildMiniSocialLinks(context, tenantWebsite!, isDark,
                              effectivePrimaryColor),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CabinetInfoScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: effectivePrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      effectivePrimaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)?.seeClinicInfo ??
                                      'See Clinic Info',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: effectivePrimaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: effectivePrimaryColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CabinetInfoScreen(),
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.all(8), // Reduced from 16 to 8
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: tenantWebsite?.logoPath != null &&
                                  tenantWebsite!.logoPath!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Builder(
                                    builder: (context) {
                                      // Clean the logo path - aggressively remove all whitespace including newlines
                                      final logoPath = tenantWebsite!.logoPath!;

                                      // Aggressively clean the path - remove ALL whitespace and control characters
                                      // This handles cases where the API returns paths with embedded newlines
                                      String cleanPath = logoPath
                                          .replaceAll(RegExp(r'\s+'),
                                              '') // Remove ALL whitespace first
                                          .replaceAll('\n',
                                              '') // Explicitly remove newlines
                                          .replaceAll('\r',
                                              '') // Explicitly remove carriage returns
                                          .replaceAll('\t',
                                              '') // Explicitly remove tabs
                                          .replaceAll(' ',
                                              '') // Explicitly remove spaces
                                          .trim(); // Final trim

                                      // Debug: Check for any remaining problematic characters
                                      debugPrint(
                                          'Original logo path: "${logoPath.replaceAll('\n', '\\n').replaceAll('\r', '\\r')}"');
                                      debugPrint(
                                          'Cleaned logo path: "$cleanPath"');
                                      debugPrint(
                                          'Clean path has newlines: ${cleanPath.contains('\n')}');
                                      debugPrint(
                                          'Clean path has carriage returns: ${cleanPath.contains('\r')}');

                                      // Remove leading slash if present
                                      if (cleanPath.startsWith('/')) {
                                        cleanPath = cleanPath.substring(1);
                                      }

                                      // Construct the full URL - ensure no double slashes
                                      final storageBase = ApiConstants
                                              .storageBaseUrl
                                              .endsWith('/')
                                          ? ApiConstants.storageBaseUrl
                                              .substring(
                                                  0,
                                                  ApiConstants.storageBaseUrl
                                                          .length -
                                                      1)
                                          : ApiConstants.storageBaseUrl;
                                      final logoUrl =
                                          '$storageBase/storage/$cleanPath'
                                              .trim();

                                      // Debug: Print the cleaned URL (shows the actual URL that will be used)
                                      debugPrint(
                                          'Loading logo from URL: $logoUrl');
                                      debugPrint(
                                          'URL length: ${logoUrl.length}');

                                      // Use Image.network with error handling since NetworkImage in DecorationImage
                                      // doesn't handle CORS errors well. Image.network has better error handling.
                                      // Increased size from 60x60 to 80x80 for better visibility
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          logoUrl,
                                          width: 80, // Increased from 60
                                          height: 80, // Increased from 60
                                          fit: BoxFit
                                              .contain, // Changed from cover to contain for better logo display
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              width:
                                                  80, // Updated to match image size
                                              height:
                                                  80, // Updated to match image size
                                              decoration: BoxDecoration(
                                                color: effectivePrimaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null,
                                                  strokeWidth: 2,
                                                  color: effectivePrimaryColor,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            debugPrint(
                                                'Failed to load logo from: $logoUrl');
                                            debugPrint('Error: $error');
                                            // Show fallback icon
                                            return Container(
                                              width:
                                                  80, // Updated to match image size
                                              height:
                                                  80, // Updated to match image size
                                              decoration: BoxDecoration(
                                                color: effectivePrimaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.business_rounded,
                                                color: effectivePrimaryColor,
                                                size:
                                                    40, // Slightly larger icon
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 80, // Updated to match logo size
                                  height: 80, // Updated to match logo size
                                  decoration: BoxDecoration(
                                    color:
                                        effectivePrimaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.business_rounded,
                                    color: effectivePrimaryColor,
                                    size: 40, // Slightly larger icon
                                  ),
                                ),
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: effectivePrimaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark ? Colors.black : Colors.white,
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 14,
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
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(
        begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Future<void> _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $uri');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildMiniSocialLinks(BuildContext context, TenantWebsiteModel website,
      bool isDark, Color color) {
    final links = website.parsedSocialLinks ?? {};

    final validLinks = links.entries
        .where((e) =>
            e.value != null && e.value != '#' && e.value.toString().isNotEmpty)
        .toList();

    // Prepare list of widgets to display
    List<Widget> iconWidgets = [];

    // 1. Phone
    if (website.contactPhone != null && website.contactPhone!.isNotEmpty) {
      iconWidgets.add(_buildMiniIcon(
        icon: Icons.phone_rounded,
        color: Colors.blue,
        onTap: () => _launchURL('tel:${website.contactPhone}'),
        isDark: isDark,
      ));
    }

    // 2. WhatsApp
    if (website.contactPhone != null && website.contactPhone!.isNotEmpty) {
      final phone = website.contactPhone!.replaceAll(RegExp(r'[^0-9]'), '');
      iconWidgets.add(_buildMiniIcon(
        icon: FontAwesomeIcons.whatsapp,
        color: const Color(0xFF25D366),
        onTap: () => _launchURL('https://wa.me/$phone'),
        isDark: isDark,
        isFa: true,
      ));
    }

    // 3. Google Maps
    if (website.googleMapsLocation != null &&
        website.googleMapsLocation!.isNotEmpty) {
      iconWidgets.add(_buildMiniIcon(
        icon: Icons.map_rounded,
        color: Colors.orange,
        onTap: () => _launchURL(website.googleMapsLocation!),
        isDark: isDark,
      ));
    }

    // 4. Social Links
    for (final entry in validLinks) {
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

      iconWidgets.add(_buildMiniIcon(
        icon: icon,
        color: iconColor,
        onTap: () => _launchURL(url),
        isDark: isDark,
        isFa: true,
      ));
    }

    if (iconWidgets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: iconWidgets.take(6).toList(), // Show up to 6 icons
      ),
    );
  }

  Widget _buildMiniIcon({
    required Object icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isFa = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: isFa
              ? FaIcon(icon as FaIconData, color: color, size: 16)
              : Icon(icon as IconData, color: color, size: 16),
        ),
      ),
    );
  }

  Widget _buildAdminDashboard(
    BuildContext context,
    Map<String, dynamic> data,
    WidgetRef ref,
    String timeRange,
    bool isDesktop,
    bool isTablet,
    AsyncValue<Result<TenantWebsiteModel>> tenantWebsiteAsync,
  ) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = size.width < 600 ? 1.4 : (isTablet ? 1.7 : 1.9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Range Filter
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildTimeRangeChips(context, timeRange, ref),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Modern Stats Grid
        Builder(
          builder: (context) {
            final authState = ref.watch(authProvider);
            final localizations = AppLocalizations.of(context);
            final statsCards = <_ModernStatCard>[
              _ModernStatCard(
                title: localizations?.totalPatients ?? 'Total Patients',
                value: (data['total_patients'] ?? 0).toString(),
                color: _getTenantPrimaryColor(tenantWebsiteAsync) ??
                    const Color(0xFF3B82F6),
                subtitle:
                    '${data['total_patients'] ?? 0} ${localizations?.patients ?? 'Patients'}',
                icon: Icons.people_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.totalAppointments ?? 'Total Appointments',
                value: (data['total_appointments'] ?? 0).toString(),
                color: const Color(0xFF10B981),
                subtitle:
                    '${data['total_appointments'] ?? 0} ${localizations?.appointments ?? 'appointments'}',
                icon: Icons.calendar_month_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.pendingInvoices ?? 'Pending Invoices',
                value: (data['pending_invoices'] ?? 0).toString(),
                color: const Color(0xFFF59E0B),
                subtitle: localizations?.requiresAction ?? 'Requires action',
                icon: Icons.receipt_long_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoicesScreenModern(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.urgentCases ?? 'Urgent Cases',
                value: (data['urgent_case_count'] ?? 0).toString(),
                color: const Color(0xFFEF4444),
                subtitle:
                    localizations?.highPriorityCases ?? 'High priority cases',
                icon: Icons.warning_amber_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title:
                    localizations?.totalPrescriptions ?? 'Total Prescriptions',
                value: (data['total_prescriptions'] ?? 0).toString(),
                color: const Color(0xFF8B5CF6),
                subtitle:
                    '${data['active_prescriptions'] ?? 0} ${localizations?.active ?? 'Active'} / ${data['expired_prescriptions'] ?? 0} ${localizations?.expired ?? 'Expired'}',
                icon: Icons.medication_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrescriptionsScreen(),
                    ),
                  );
                },
              ),
            ];

            // Add Waiting Room Card - only for admin, doctor, and receptionist
            if (authState.user?.isAdmin == 1 ||
                authState.user?.isDoctor == 1 ||
                authState.user?.isReceptionist == 1) {
              // Get waiting room data to show accurate count
              final waitingRoomAsync = ref.watch(waitingRoomProvider);
              final waitingCount = waitingRoomAsync.when(
                data: (result) {
                  return result.when(
                    success: (waitingRoomData) =>
                        waitingRoomData.waitingAppointments.length,
                    failure: (_) => 0,
                  );
                },
                loading: () => 0,
                error: (_, __) => 0,
              );

              statsCards.add(
                _ModernStatCard(
                  title: localizations?.waitingRoom ?? 'Waiting Room',
                  value: waitingCount.toString(),
                  color: const Color(0xFF06B6D4),
                  subtitle:
                      localizations?.patientsWaiting ?? 'Patients waiting',
                  icon: Icons.meeting_room_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WaitingRoomScreen(),
                      ),
                    );
                  },
                ),
              );
            }

            return _buildResponsiveStatsGrid(
              context,
              statsCards,
              crossAxisCount,
              childAspectRatio,
            );
          },
        ),

        const SizedBox(height: 32),

        // Charts Section
        if (data['chart_data'] != null) ...[
          _buildSectionTitle(
              context,
              AppLocalizations.of(context)?.analysisOverview ??
                  'Analysis Overview'),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1024) {
                // Desktop: 2 columns
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildModernPieChart(
                              context,
                              AppLocalizations.of(context)?.appointmentStatus ??
                                  'Appointment Status',
                              data['chart_data']['appointments_by_status']),
                          const SizedBox(height: 16),
                          _buildModernLineChart(
                              context,
                              AppLocalizations.of(context)?.totalAppointments ??
                                  'Monthly Appointments',
                              data['chart_data']['monthly_appointments'],
                              const Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildModernPieChart(
                              context,
                              AppLocalizations.of(context)?.prescriptions ??
                                  'Prescriptions',
                              data['chart_data']['prescriptions_by_status']),
                          const SizedBox(height: 16),
                          _buildModernLineChart(
                              context,
                              AppLocalizations.of(context)
                                      ?.monthlyPrescriptions ??
                                  'Monthly Prescriptions',
                              data['chart_data']['monthly_prescriptions'],
                              const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile/Tablet: Single column
                return Column(
                  children: [
                    _buildModernPieChart(
                        context,
                        AppLocalizations.of(context)?.appointmentStatus ??
                            'Appointment Status',
                        data['chart_data']['appointments_by_status']),
                    const SizedBox(height: 16),
                    _buildModernPieChart(
                        context,
                        AppLocalizations.of(context)?.prescriptions ??
                            'Prescriptions',
                        data['chart_data']['prescriptions_by_status']),
                    const SizedBox(height: 16),
                    _buildModernLineChart(
                        context,
                        AppLocalizations.of(context)?.monthlyAppointments ??
                            'Monthly Appointments',
                        data['chart_data']['monthly_appointments'],
                        const Color(0xFF3B82F6)),
                    const SizedBox(height: 16),
                    _buildModernLineChart(
                        context,
                        AppLocalizations.of(context)?.monthlyPrescriptions ??
                            'Monthly Prescriptions',
                        data['chart_data']['monthly_prescriptions'],
                        const Color(0xFF8B5CF6)),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 16),

          // Revenue Chart
          _buildModernRevenueChart(
              context, data['chart_data']['revenue_by_service']),

          const SizedBox(height: 32),
        ],

        // Upcoming Appointments
        if (data['upcoming_appointments'] != null &&
            _safeList(data['upcoming_appointments']).isNotEmpty) ...[
          _buildSectionTitle(
              context,
              AppLocalizations.of(context)?.upcomingAppointments ??
                  'Upcoming Appointments'),
          const SizedBox(height: 16),
          ..._safeList(data['upcoming_appointments'])
              .take(5)
              .map((apt) => _buildModernAppointmentCard(context, apt)),
        ],

        // Recent Appointments
        if (data['recent_appointments'] != null &&
            _safeList(data['recent_appointments']).isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSectionTitle(
              context,
              AppLocalizations.of(context)?.recentAppointments ??
                  'Recent Appointments'),
          const SizedBox(height: 16),
          ..._safeList(data['recent_appointments'])
              .take(5)
              .map((apt) => _buildModernAppointmentCard(context, apt)),
        ],

        // Recent Prescriptions
        if (data['recent_prescriptions'] != null &&
            _safeList(data['recent_prescriptions']).isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSectionTitle(
              context,
              AppLocalizations.of(context)?.recentPrescriptions ??
                  'Recent Prescriptions'),
          const SizedBox(height: 16),
          ..._safeList(data['recent_prescriptions'])
              .take(5)
              .map((presc) => _buildModernPrescriptionCard(context, presc)),
        ],
      ],
    );
  }

  Widget _buildDoctorDashboard(BuildContext context, Map<String, dynamic> data,
      bool isDesktop, bool isTablet) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = size.width < 600 ? 1.4 : (isTablet ? 1.7 : 1.9);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            context, localizations?.doctorOverview ?? 'Doctor Overview'),
        const SizedBox(height: 16),
        _buildResponsiveStatsGrid(
            context,
            [
              _ModernStatCard(
                title: localizations?.todaysSchedule ?? "Today's Schedule",
                value:
                    _safeList(data['upcoming_appointments']).length.toString(),
                color: const Color(0xFF3B82F6),
                subtitle: localizations?.appointments ?? 'Appointments',
                icon: Icons.event_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.totalPatients ?? 'Total Patients',
                value: (data['total_patients'] ?? 0).toString(),
                color: const Color(0xFF10B981),
                subtitle:
                    '${data['total_patients'] ?? 0} ${localizations?.patients ?? 'Patients'}',
                icon: Icons.people_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.prescriptions ?? 'Prescriptions',
                value: (data['total_prescriptions'] ?? 0).toString(),
                color: const Color(0xFF8B5CF6),
                subtitle:
                    '${data['active_prescriptions'] ?? 0} ${localizations?.active ?? 'Active'}',
                icon: Icons.medication_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicalRecordsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.urgentCases ?? 'Urgent Cases',
                value: (data['urgent_case_count'] ?? 0).toString(),
                color: const Color(0xFFEF4444),
                subtitle:
                    localizations?.highPriorityCases ?? 'High priority cases',
                icon: Icons.warning_amber_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
            ],
            crossAxisCount,
            childAspectRatio),
        const SizedBox(height: 24),
        if (data['upcoming_appointments'] != null)
          ...(_safeList(data['upcoming_appointments']).map((apt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildModernAppointmentCard(context, apt),
              ))),
      ],
    );
  }

  Widget _buildPatientDashboard(BuildContext context, Map<String, dynamic> data,
      bool isDesktop, bool isTablet) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = size.width < 600 ? 1.4 : (isTablet ? 1.7 : 1.9);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            context, localizations?.healthOverview ?? 'Health Overview'),
        const SizedBox(height: 16),
        _buildResponsiveStatsGrid(
            context,
            [
              _ModernStatCard(
                title: localizations?.upcomingVisitsStat ?? 'Upcoming Visits',
                value:
                    _safeList(data['upcoming_appointments']).length.toString(),
                color: const Color(0xFF3B82F6),
                subtitle: localizations?.scheduledAppointmentsStat ??
                    'Scheduled Appointments',
                icon: Icons.calendar_today_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.unpaidInvoicesStat ?? 'Unpaid Invoices',
                value: (data['unpaid_invoices'] ?? 0).toString(),
                color: const Color(0xFFF59E0B),
                subtitle: localizations?.requiresAction ?? 'Requires action',
                icon: Icons.payment_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoicesScreenModern(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.activePrescriptionsStat ??
                    'Active Prescriptions',
                value:
                    _safeList(data['recent_prescriptions']).length.toString(),
                color: const Color(0xFF8B5CF6),
                subtitle: localizations?.inProgressStat ?? 'In progress',
                icon: Icons.medication_liquid_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrescriptionsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.myCalendarStat ?? 'My Calendar',
                value:
                    _safeList(data['upcoming_appointments']).length.toString(),
                color: const Color(0xFF10B981),
                subtitle: localizations?.manageMyDatesStat ?? 'Manage my dates',
                icon: Icons.calendar_month_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalendarScreen(),
                    ),
                  );
                },
              ),
            ],
            crossAxisCount,
            childAspectRatio),
        const SizedBox(height: 24),
        if (data['upcoming_appointments'] != null)
          ...(_safeList(data['upcoming_appointments']).map((apt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildModernAppointmentCard(context, apt),
              ))),
        if (data['recent_prescriptions'] != null &&
            _safeList(data['recent_prescriptions']).isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle(context,
              localizations?.yourPrescriptionsSection ?? 'Your Prescriptions'),
          const SizedBox(height: 16),
          ..._safeList(data['recent_prescriptions']).map((presc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildModernPrescriptionCard(context, presc),
              )),
        ],
      ],
    );
  }

  Widget _buildReceptionistDashboard(BuildContext context,
      Map<String, dynamic> data, bool isDesktop, bool isTablet) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = size.width < 600 ? 1.4 : (isTablet ? 1.7 : 1.9);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context,
            localizations?.receptionistOverview ?? 'Receptionist Overview'),
        const SizedBox(height: 16),
        _buildResponsiveStatsGrid(
            context,
            [
              _ModernStatCard(
                title: localizations?.todaysSchedule ?? "Today's Schedule",
                value:
                    _safeList(data['upcoming_appointments']).length.toString(),
                color: const Color(0xFF3B82F6),
                subtitle:
                    localizations?.activeAppointments ?? 'Active Appointments',
                icon: Icons.today_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.patientsToday ?? 'Patients today',
                value: (data['total_patients_today'] ?? 0).toString(),
                color: const Color(0xFF10B981),
                subtitle:
                    '${data['total_patients_today'] ?? 0} ${localizations?.patients ?? 'Patients'}',
                icon: Icons.person_add_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.pendingRequests ?? 'Pending Requests',
                value: _safeList(data['pending_appointment_requests'])
                    .length
                    .toString(),
                color: const Color(0xFFF59E0B),
                subtitle: localizations?.pending ?? 'Pending',
                icon: Icons.pending_actions_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
              _ModernStatCard(
                title: localizations?.urgentCases ?? 'Urgent Cases',
                value: (data['urgent_case_count'] ?? 0).toString(),
                color: const Color(0xFFEF4444),
                subtitle:
                    localizations?.highPriorityCases ?? 'High priority cases',
                icon: Icons.emergency_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(),
                    ),
                  );
                },
              ),
            ],
            crossAxisCount,
            childAspectRatio),
        const SizedBox(height: 24),
        if (data['upcoming_appointments'] != null)
          ...(_safeList(data['upcoming_appointments']).map((apt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildModernAppointmentCard(context, apt),
              ))),
      ],
    );
  }

  Widget _buildResponsiveStatsGrid(
      BuildContext context,
      List<_ModernStatCard> stats,
      int crossAxisCount,
      double childAspectRatio) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isSmallScreen ? 14 : 20,
        mainAxisSpacing: isSmallScreen ? 14 : 20,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => stats[index],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
    );
  }

  Widget _buildModernPieChart(
      BuildContext context, String title, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    final labels = _safeList(data['labels']);
    final datasets = _safeList(data['datasets']);
    if (datasets.isEmpty) return const SizedBox.shrink();

    final dataValues = _safeList(datasets[0]['data']);
    final colors = _safeList(datasets[0]['backgroundColor']);

    List<PieChartSectionData> sections = [];
    double total = dataValues.fold(
        0.0,
        (sum, val) =>
            sum +
            ((val is int)
                ? val.toDouble()
                : double.tryParse(val.toString()) ?? 0));

    for (int i = 0; i < dataValues.length; i++) {
      final value = (dataValues[i] is int)
          ? dataValues[i].toDouble()
          : double.tryParse(dataValues[i].toString()) ?? 0;
      if (value > 0) {
        sections.add(PieChartSectionData(
          value: value,
          title: '${((value / total) * 100).toStringAsFixed(0)}%',
          color: _parseColor(colors[i]),
          radius: 70,
          titleStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
                sections: sections, centerSpaceRadius: 50, sectionsSpace: 2)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(
                labels.length,
                (i) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: _parseColor(colors[i]),
                                borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${labels[i]}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    )),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLineChart(BuildContext context, String title,
      Map<String, dynamic>? data, Color color) {
    if (data == null) return const SizedBox.shrink();

    final datasets = _safeList(data['datasets']);
    if (datasets.isEmpty) return const SizedBox.shrink();

    final dataValues = _safeList(datasets[0]['data']);
    List<FlSpot> spots = [];
    for (int i = 0; i < dataValues.length; i++) {
      final value = (dataValues[i] is int)
          ? dataValues[i].toDouble()
          : double.tryParse(dataValues[i].toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData:
                        BarAreaData(show: true, color: color.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRevenueChart(
      BuildContext context, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    final labels = _safeList(data['labels']);
    final datasets = _safeList(data['datasets']);

    if (datasets.isEmpty) return const SizedBox.shrink();

    final dataValues = _safeList(datasets[0]['data']);

    // Get top 10 services by revenue
    List<MapEntry<String, double>> serviceRevenue = [];
    for (int i = 0; i < labels.length; i++) {
      final value = double.tryParse(dataValues[i].toString()) ?? 0;
      if (value > 0) {
        serviceRevenue.add(MapEntry(labels[i], value));
      }
    }

    serviceRevenue.sort((a, b) => b.value.compareTo(a.value));
    final top10 = serviceRevenue.take(10).toList();

    if (top10.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Services by Revenue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...top10.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(2)} MAD',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4BC0C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value / top10.first.value,
                      backgroundColor:
                          isDark ? Colors.grey[700] : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4BC0C0)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildModernAppointmentCard(
      BuildContext context, dynamic appointment) {
    final status = appointment['status'] ?? '';
    final statusColor = _getStatusColor(status);
    // For patients, show doctor name; for doctors/admins, show patient name
    final localizations = AppLocalizations.of(context);
    final displayName = appointment['doctor_name'] ??
        appointment['patient_name'] ??
        localizations?.unknown ??
        'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showAppointmentDetailsDialog(context, appointment);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6),
                        const Color(0xFF3B82F6).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appointment['time']?.substring(0, 5) ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appointment['date'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getLocalizedStatus(status, localizations).toLowerCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetailsDialog(
      BuildContext context, dynamic appointment) {
    final localizations = AppLocalizations.of(context);
    final appointmentId = appointment['id'] ?? '—';
    final patientName = appointment['patient_name'] ?? 'Unknown';
    final date = appointment['date'] ?? '—';
    final time = appointment['time'] ?? '—';
    final status = appointment['status'] ?? '—';
    final doctorName =
        appointment['doctor_name'] ?? appointment['doctor'] ?? '—';
    final service =
        appointment['service'] ?? appointment['service_name'] ?? '—';
    final notes = appointment['notes'] ?? '';
    final priority = appointment['priority'] ?? '—';

    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: localizations?.appointmentDetails ?? 'Appointment Details',
      desc: '',
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF1976D2), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${localizations?.appointmentNumber ?? 'Appointment'} #$appointmentId',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Patient Information
              _buildDetailsRow(
                  localizations?.patient ?? 'Patient', patientName),
              const Divider(height: 24),
              // Doctor Information
              if (doctorName != '—')
                _buildDetailsRow(localizations?.doctor ?? 'Doctor', doctorName),
              // Service Information
              if (service != '—')
                _buildDetailsRow(localizations?.services ?? 'Service', service),
              const Divider(height: 24),
              // Appointment Date/Time
              _buildDetailsRow(localizations?.date ?? 'Date', date),
              _buildDetailsRow(localizations?.time ?? 'Time', time),
              // Status and Priority
              _buildDetailsRow(localizations?.status ?? 'Status', status),
              if (priority != '—')
                _buildDetailsRow(
                    localizations?.priority ?? 'Priority', priority),
              // Notes
              if (notes.isNotEmpty) ...[
                const Divider(height: 24),
                _buildDetailsRow(localizations?.notes ?? 'Notes', notes),
              ],
            ],
          ),
        ),
      ),
      btnOkText: localizations?.viewAllAppointments ?? 'View All Appointments',
      btnOkOnPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AppointmentsScreen(),
          ),
        );
      },
      btnCancelText: localizations?.close ?? 'Close',
      btnCancelOnPress: () {},
    ).show();
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPrescriptionCard(
      BuildContext context, dynamic prescription) {
    final localizations = AppLocalizations.of(context);
    final status = prescription['status'] ?? 'active';
    final isActive = status.toLowerCase() == 'active';
    final pdfPath = prescription['pdf_path'];
    final pdfUrl = prescription['pdf_url'];
    // For patients, show doctor name; for doctors, show patient name
    final personName = prescription['doctor_name'] ??
        prescription['patient_name'] ??
        localizations?.unknown ??
        'Unknown';

    // Handle new medications array structure
    final medications = _safeList(prescription['medications']);
    String medicationTitle;
    String medicationDetails = '';

    if (medications.isNotEmpty) {
      final count = medications.length;
      medicationTitle = count == 1
          ? '1 ${localizations?.medication ?? 'Medication'}'
          : '$count ${localizations?.medications ?? 'Medications'}';

      // Build details from first medication
      final firstMed = medications[0];
      final parts = <String>[];
      if (firstMed['medication_name'] != null &&
          firstMed['medication_name'].toString().isNotEmpty) {
        parts.add(firstMed['medication_name']);
      }
      if (firstMed['dosage'] != null &&
          firstMed['dosage'].toString().isNotEmpty) {
        parts.add(firstMed['dosage']);
      }
      if (firstMed['frequency'] != null &&
          firstMed['frequency'].toString().isNotEmpty) {
        parts.add(
            '${firstMed['frequency']} ${localizations?.timesPerDay ?? 'x/day'}');
      }
      if (firstMed['duration'] != null &&
          firstMed['duration'].toString().isNotEmpty) {
        parts.add('${firstMed['duration']} ${localizations?.days ?? 'days'}');
      }
      medicationDetails = parts.isNotEmpty ? parts.join(' • ') : '';

      if (count > 1) {
        medicationDetails +=
            ' (+${count - 1} ${localizations?.more ?? 'more'})';
      }
    } else {
      // Fallback to old structure
      final medication = prescription['medication'] ??
          prescription['medication_name'] ??
          localizations?.prescriptionLabel ??
          'Prescription';
      medicationTitle = medication;

      final dosage = prescription['dosage'];
      final frequency = prescription['frequency'];
      final notes = prescription['notes'];

      if (dosage != null || frequency != null || notes != null) {
        medicationDetails = [dosage, frequency, notes]
            .where((e) => e != null && e.toString().isNotEmpty)
            .join(' • ');
      }
    }

    final date = prescription['created_at'] ?? prescription['date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final prescriptionId = prescription['id'];
            if (prescriptionId != null) {
              // Use API endpoint instead of storage URL
              final url =
                  '${ApiConstants.baseUrl}${ApiConstants.prescriptionPdf(prescriptionId)}';
              final uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch PDF URL')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error opening PDF: $e')),
                  );
                }
              }
            } else {
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      '${localizations?.openingPrescription ?? 'Opening prescription'} ${prescription['id']}')));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicationTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (medicationDetails.isNotEmpty)
                        Text(
                          medicationDetails,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (personName != null)
                        Text(
                          personName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  '${localizations?.issued ?? 'Issued'}: $date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Status icon
                Icon(
                  isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 24,
                ),
                // PDF download button if available
                if (pdfPath != null || pdfUrl != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.red),
                    onPressed: () => _downloadPrescriptionPdf(
                        context, pdfPath, pdfUrl, prescription['id']),
                    tooltip: AppLocalizations.of(context)?.downloadPdf ??
                        'Download PDF',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFAB(BuildContext context, dynamic user, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    return FloatingActionButton.extended(
      onPressed: () => _showQuickActionsSheet(context, user, ref),
      label: Text(localizations?.quickActions ?? 'Quick Actions'),
      icon: const Icon(Icons.add_rounded),
      elevation: 4,
    );
  }

  void _showQuickActionsSheet(
      BuildContext context, dynamic user, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final localizations = AppLocalizations.of(ctx);
        return Container(
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
                      style: TextStyle(
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
                      // Appointments
                      if (user.isAdmin == 1 || user.isReceptionist == 1)
                        _buildQuickActionCard(
                          context: ctx,
                          icon: Icons.calendar_today_rounded,
                          title: localizations?.newAppointment ??
                              'New Appointment',
                          subtitle: localizations?.createAppointment ??
                              'Create an appointment',
                          color: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const CreateAppointmentScreen(),
                              ),
                            );
                          },
                        ),
                      // Prescriptions
                      if (user.isDoctor == 1 || user.isAdmin == 1)
                        _buildQuickActionCard(
                          context: ctx,
                          icon: Icons.medication_rounded,
                          title: localizations?.newPrescription ??
                              'New Prescription',
                          subtitle: localizations?.createPrescription ??
                              'Create a prescription',
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CreatePrescriptionScreen(),
                              ),
                            );
                          },
                        ),
                      // Medical Records
                      if (user.isDoctor == 1 || user.isAdmin == 1)
                        _buildQuickActionCard(
                          context: ctx,
                          icon: Icons.medical_services_rounded,
                          title: localizations?.medicalRecords ??
                              'Medical Records',
                          subtitle: localizations?.createMedicalRecord ??
                              'Create Medical Record',
                          color: const Color(0xFFEF4444),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const MedicalRecordsScreen(),
                              ),
                            );
                          },
                        ),
                      // Calendar
                      _buildQuickActionCard(
                        context: ctx,
                        icon: Icons.calendar_month_rounded,
                        title: localizations?.calendar ?? 'Calendar',
                        subtitle:
                            localizations?.calendarView ?? 'Calendar view',
                        color: const Color(0xFFF59E0B),
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
                      // Appointments List
                      _buildQuickActionCard(
                        context: ctx,
                        icon: Icons.event_available_rounded,
                        title: localizations?.appointmentsList ??
                            'Appointments List',
                        subtitle: localizations?.viewAllAppointments ??
                            'View all appointments',
                        color: const Color(0xFF06B6D4),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => const AppointmentsScreen(),
                            ),
                          );
                        },
                      ),
                      // Waiting Room - only for admin, doctor, and receptionist
                      if (user.isAdmin == 1 ||
                          user.isDoctor == 1 ||
                          user.isReceptionist == 1)
                        _buildQuickActionCard(
                          context: ctx,
                          icon: Icons.meeting_room_rounded,
                          title: localizations?.waitingRoom ?? 'Waiting Room',
                          subtitle: localizations?.waitingRoomDisplay ??
                              'Waiting room display',
                          color: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const WaitingRoomScreen(),
                              ),
                            );
                          },
                        ),
                      // Patients List
                      if (user.isAdmin == 1 ||
                          user.isReceptionist == 1 ||
                          user.isDoctor == 1)
                        _buildQuickActionCard(
                          context: ctx,
                          icon: Icons.people_rounded,
                          title: localizations?.patients ?? 'Patients',
                          subtitle:
                              localizations?.patientList ?? 'Patient list',
                          color: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const PatientsScreen(),
                              ),
                            );
                          },
                        ),
                      // Invoices
                      if (user.isAdmin == 1 || user.isReceptionist == 1)
                        _buildQuickActionCard(
                          context: ctx,
                          icon: Icons.receipt_long_rounded,
                          title: localizations?.invoices ?? 'Invoices',
                          subtitle: localizations?.invoiceManagement ??
                              'Invoice management',
                          color: const Color(0xFF14B8A6),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => const InvoicesScreenModern(),
                              ),
                            );
                          },
                        ),
                      // Refresh Dashboard
                      _buildQuickActionCard(
                        context: ctx,
                        icon: Icons.refresh_rounded,
                        title: localizations?.refresh ?? 'Refresh',
                        subtitle: localizations?.refreshList ?? 'Refresh list',
                        color: Colors.grey[600]!,
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(dashboardRefreshProvider)(
                              ref.read(timeRangeProvider));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(localizations?.listRefreshed ??
                                  'List refreshed'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      // Rate App on Play Store
                      _buildQuickActionCard(
                        context: ctx,
                        icon: Icons.star_rounded,
                        title: localizations?.rateApp ?? 'Rate the app',
                        subtitle: localizations?.rateOnPlayStore ??
                            'Rate on Play Store',
                        color: const Color(0xFFFFB800),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openPlayStoreReview();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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

  Color? _getTenantPrimaryColor(
      AsyncValue<Result<TenantWebsiteModel>> tenantWebsiteAsync) {
    Color? tenantPrimaryColor;
    tenantWebsiteAsync.whenData((result) {
      if (result is Success<TenantWebsiteModel>) {
        final themeColors = result.data.parsedThemeColors;
        if (themeColors != null && themeColors['primary'] != null) {
          try {
            final colorString = themeColors['primary'] as String;
            tenantPrimaryColor =
                Color(int.parse(colorString.replaceAll('#', '0xFF')));
          } catch (e) {
            // Use default color if parsing fails
          }
        }
      }
    });
    return tenantPrimaryColor;
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child:
                const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAppointmentCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isPatient = user?.isPatient == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer.clearGlass(
        height: 80,
        width: double.infinity,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primaryColor.withOpacity(0.25),
                  primaryColor.withOpacity(0.08),
                  const Color(0xFF1A1A2E).withOpacity(0.85),
                ]
              : [
                  primaryColor.withOpacity(0.15),
                  primaryColor.withOpacity(0.06),
                  Colors.white.withOpacity(0.95),
                ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.25 : 0.4),
            primaryColor.withOpacity(0.35),
          ],
        ),
        borderColor: Colors.white.withOpacity(isDark ? 0.25 : 0.35),
        blur: 20,
        borderWidth: 1.2,
        elevation: 10,
        shadowColor: primaryColor.withOpacity(0.25),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (isPatient) {
                _showBookingTypeSelection(context);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateAppointmentScreen(),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor,
                          primaryColor.withOpacity(0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isPatient
                              ? (AppLocalizations.of(context)
                                      ?.bookAppointment ??
                                  'Book Appointment')
                              : (AppLocalizations.of(context)?.newAppointment ??
                                  'New Appointment'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey[900],
                            letterSpacing: 0.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPatient
                              ? (AppLocalizations.of(context)?.onlineBooking ??
                                  'Online booking')
                              : 'Existing or new patient',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            letterSpacing: 0.1,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.white60 : Colors.grey[500],
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBookingTypeSelection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final localizations = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who is this appointment for?', // Fallback if key missing
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
              _buildBookingOption(
                context,
                title: localizations?.bookForMe ?? 'Book for me',
                subtitle:
                    localizations?.onlineBooking ?? 'Use my profile details',
                icon: Icons.person_rounded,
                color: primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PublicAppointmentBookingScreen(
                        isBookingForSelf: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildBookingOption(
                context,
                title: localizations?.someoneElse ?? 'Someone else',
                subtitle:
                    localizations?.onlineBooking ?? 'Family member or friend',
                icon: Icons.people_outline_rounded,
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PublicAppointmentBookingScreen(
                        isBookingForSelf: false,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePrescriptionCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleGradient = [Colors.purple.shade600, Colors.indigo.shade600];

    return Container(
      child: GlassContainer.clearGlass(
        height: 80,
        width: double.infinity,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  purpleGradient.first.withOpacity(0.25),
                  purpleGradient.last.withOpacity(0.08),
                  const Color(0xFF1A1A2E).withOpacity(0.85),
                ]
              : [
                  purpleGradient.first.withOpacity(0.15),
                  purpleGradient.last.withOpacity(0.06),
                  Colors.white.withOpacity(0.95),
                ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.25 : 0.4),
            purpleGradient.first.withOpacity(0.35),
          ],
        ),
        borderColor: Colors.white.withOpacity(isDark ? 0.25 : 0.35),
        blur: 20,
        borderWidth: 1.2,
        elevation: 10,
        shadowColor: purpleGradient.first.withOpacity(0.25),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreatePrescriptionScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: purpleGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: purpleGradient.first.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.newPrescription ??
                              'New Prescription',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey[900],
                            letterSpacing: 0.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prescribe medications',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            letterSpacing: 0.1,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.white60 : Colors.grey[500],
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideX(
          begin: 0.3,
          end: 0,
          duration: 600.ms,
          delay: 400.ms,
          curve: Curves.easeOutCubic),
    );
  }

  Widget _buildAttachFileCard(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenGradient = [Colors.green.shade600, Colors.green.shade700];

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      child: GlassContainer.clearGlass(
        height: 80,
        width: double.infinity,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  greenGradient.first.withOpacity(0.25),
                  greenGradient.last.withOpacity(0.08),
                  const Color(0xFF1A1A2E).withOpacity(0.85),
                ]
              : [
                  greenGradient.first.withOpacity(0.15),
                  greenGradient.last.withOpacity(0.06),
                  Colors.white.withOpacity(0.95),
                ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.25 : 0.4),
            greenGradient.first.withOpacity(0.35),
          ],
        ),
        borderColor: Colors.white.withOpacity(isDark ? 0.25 : 0.35),
        blur: 20,
        borderWidth: 1.2,
        elevation: 10,
        shadowColor: greenGradient.first.withOpacity(0.25),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttachFileToRecordScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: greenGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: greenGradient.first.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.upload_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localizations?.attachFiles ?? 'Attach Files',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.grey[900],
                            letterSpacing: 0.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations?.attachFilesToMedicalRecord ??
                              'Attach Files to Medical Record',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            letterSpacing: 0.1,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.white60 : Colors.grey[500],
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 500.ms).slideX(
          begin: -0.3,
          end: 0,
          duration: 600.ms,
          delay: 500.ms,
          curve: Curves.easeOutCubic),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  // Helper function for status colors
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
      case 'scheduled':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _downloadPrescriptionPdf(BuildContext context, String? pdfPath,
      String? pdfUrl, dynamic prescriptionId) async {
    String? url;

    // Priority 1: Use pdf_url from API (secure download endpoint)
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      url = pdfUrl;
    }
    // Priority 2: Check if pdfPath is already a full URL (Backblaze direct URL)
    else if (pdfPath != null &&
        (pdfPath.startsWith('http://') || pdfPath.startsWith('https://'))) {
      url = pdfPath;
    }
    // Priority 3: Use secure API endpoint if we have prescriptionId
    else if (prescriptionId != null) {
      url =
          '${ApiConstants.baseUrl}${ApiConstants.prescriptionPdf(prescriptionId)}';
    }
    // Priority 4: Fallback to storage URL (may not work with Backblaze)
    else if (pdfPath != null && pdfPath.isNotEmpty) {
      final cleanPath =
          pdfPath.startsWith('/') ? pdfPath.substring(1) : pdfPath;
      url = '${ApiConstants.storageBaseUrl}/storage/$cleanPath';
    }

    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL du PDF non disponible')),
        );
      }
      return;
    }

    final finalUrl = url; // Non-nullable after check

    try {
      // Show loading dialog
      if (context.mounted) {
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

      final uri = Uri.parse(finalUrl);

      // Get auth token if available
      final authState = ref.read(authProvider);
      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the file
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // Get file name from URL or use prescription ID
        String fileName =
            'ordonnance_${prescriptionId ?? DateTime.now().millisecondsSinceEpoch}.pdf';
        final urlPath = uri.path;
        if (urlPath.isNotEmpty) {
          final urlFileName = urlPath.split('/').last;
          if (urlFileName.isNotEmpty && urlFileName.endsWith('.pdf')) {
            fileName = urlFileName;
          }
        }

        if (kIsWeb) {
          // For web, use the response bytes to trigger download
          try {
            final bytes = response.bodyBytes;
            downloadFileWeb(bytes, fileName);

            if (context.mounted) {
              Navigator.of(context).pop(); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF téléchargé: $fileName'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.of(context).pop(); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur de téléchargement: ${e.toString()}'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          // For mobile, save to temporary directory first, then share
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading dialog

            // Use share_plus to share the PDF
            final xFile = XFile(filePath, mimeType: 'application/pdf');

            try {
              await Share.shareXFiles(
                [xFile],
                text: 'Ordonnance #${prescriptionId ?? "PDF"}',
                subject: 'Prescription PDF',
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'PDF sauvegardé: $fileName\nEmplacement: ${tempDir.path}'),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Partager à nouveau',
                    onPressed: () async {
                      await Share.shareXFiles(
                        [xFile],
                        text: 'Ordonnance #${prescriptionId ?? "PDF"}',
                        subject: 'Prescription PDF',
                      );
                    },
                  ),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'PDF téléchargé: $fileName\nEmplacement: ${tempDir.path}'),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      } else {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Erreur lors du téléchargement: ${response.statusCode}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getLocalizedStatus(String? status, AppLocalizations? localizations) {
    if (status == null) return '';
    switch (status.toLowerCase()) {
      case 'confirmed':
        return localizations?.scheduled ?? 'Confirmed';
      case 'scheduled':
        return localizations?.scheduled ?? 'Scheduled';
      case 'pending':
        return localizations?.pending ?? 'Pending';
      case 'cancelled':
        return localizations?.cancelled ?? 'Cancelled';
      case 'completed':
        return localizations?.completed ?? 'Completed';
      case 'no_show':
        return localizations?.noShow ?? 'No Show';
      default:
        return status;
    }
  }
}

// Modern Stat Card with Gradient and Animation

class _ModernStatCard extends StatefulWidget {
  final String title;
  final String value;
  final Color color;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
    this.icon,
    this.onTap,
  });

  @override
  State<_ModernStatCard> createState() => _ModernStatCardState();
}

class _ModernStatCardState extends State<_ModernStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(0.15),
                  widget.color.withOpacity(0.05),
                  isDark ? const Color(0xFF1A1A2E) : Colors.white,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.color.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(_isHovered ? 0.3 : 0.15),
                  blurRadius: _isHovered ? 20 : 12,
                  offset: Offset(0, _isHovered ? 8 : 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.5)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative circle
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.color.withOpacity(0.2),
                          widget.color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16), // Equal vertical padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // Distribute space evenly
                    children: [
                      // Top row: Title and Icon (top right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title on left
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.grey[800],
                                fontSize: 14, // Optimal size for cards
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2, // Better letter spacing
                                height:
                                    1.3, // Better line height for readability
                                fontFeatures: const [
                                  FontFeature.enable(
                                      'liga'), // Enable ligatures for better text rendering
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8), // Reduced from 12
                          // Icon in top right
                          Container(
                            padding: const EdgeInsets.all(8), // Reduced from 10
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.color,
                                  widget.color.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.icon ?? Icons.info_rounded,
                              color: Colors.white,
                              size: 20, // Reduced from 22
                            ),
                          ),
                        ],
                      ),
                      // Add more space between row 1 and row 2
                      const SizedBox(
                          height: 12), // Reduced spacing to prevent overflow
                      // Bottom row: Subtitle and Value (bottom right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Subtitle on left
                          if (widget.subtitle != null)
                            Expanded(
                              child: Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey[600],
                                  fontSize:
                                      11, // Reduced to 11 to prevent overflow
                                  fontWeight: FontWeight
                                      .w500, // Changed to medium weight
                                  height:
                                      1.2, // Reduced line height for compact display
                                  letterSpacing:
                                      0.1, // Add letter spacing for clarity
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (widget.subtitle != null)
                            const SizedBox(width: 8), // Reduced from 12
                          // Value in bottom right
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomRight,
                              child: Text(
                                widget.value,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white : Colors.grey[900],
                                  fontSize: 32, // Reduced from 36
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                  letterSpacing: -1.5, // Reduced from -2
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(
        begin: 0.15,
        end: 0,
        duration: 500.ms,
        delay: 100.ms,
        curve: Curves.easeOutCubic);
  }
}
