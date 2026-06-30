import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../core/utils/result.dart';

import '../data/models/patient_model.dart';
import '../providers/patient_providers.dart';
import '../providers/api_providers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/patient_detail_tabs/patient_info_tab.dart';
import '../widgets/patient_detail_tabs/appointments_tab.dart';
import '../widgets/patient_detail_tabs/prescriptions_tab.dart';
import '../widgets/patient_detail_tabs/medical_records_tab.dart';
import '../widgets/patient_detail_tabs/lab_tests_tab.dart';
import '../widgets/patient_detail_tabs/medical_certificates_tab.dart';
import '../utils/web_download_helper.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final int patientId;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
  });

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patientAsync = ref.watch(patientProvider(widget.patientId));

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.patientDetails ?? 'Patient Details',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'export') _exportPatientData(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_rounded),
                  title: Text('Exporter les données du patient'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: patientAsync.when(
        data: (result) {
          if (result is Failure<PatientModel>) {
            return CustomErrorWidget(
              message: result.message,
              onRetry: () => ref.refresh(patientProvider(widget.patientId)),
            );
          }
          if (result is Success<PatientModel>) {
            final patient = result.data;
            return _buildPatientDetailContent(context, patient, isDark);
          }
          return const SizedBox.shrink();
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (error, stackTrace) => CustomErrorWidget(
          message: error.toString(),
          onRetry: () => ref.refresh(patientProvider(widget.patientId)),
        ),
      ),
    );
  }

  Widget _buildPatientDetailContent(
    BuildContext context,
    PatientModel patient,
    bool isDark,
  ) {
    return Column(
      children: [
        // Patient Header Card
        _buildPatientHeader(context, patient, isDark),

        // Tab Bar
        Container(
          color: isDark ? const Color(0xFF15151C) : Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Tab(
                    icon: const Icon(Icons.person_rounded, size: 20),
                    text: localizations?.information ?? 'Information',
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Tab(
                    icon: const Icon(Icons.folder_rounded, size: 20),
                    text: localizations?.records ?? 'Records',
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Tab(
                    icon: const Icon(Icons.calendar_today_rounded, size: 20),
                    text: localizations?.appointments ?? 'Appointments',
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Tab(
                    icon: const Icon(Icons.medication_rounded, size: 20),
                    text: localizations?.prescriptions ?? 'Prescriptions',
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Tab(
                    icon: const Icon(Icons.science_rounded, size: 20),
                    text: localizations?.labTests ?? 'Lab Tests',
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Tab(
                    icon: const Icon(Icons.description_rounded, size: 20),
                    text: localizations?.certificates ?? 'Certificates',
                  );
                },
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              PatientInfoTab(patient: patient),
              MedicalRecordsTab(patient: patient),
              AppointmentsTab(patient: patient),
              PrescriptionsTab(patient: patient),
              LabTestsTab(patient: patient),
              MedicalCertificatesTab(patient: patient),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientHeader(
    BuildContext context,
    PatientModel patient,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A1A), const Color(0xFF0F0F0F)]
              : [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Avatar - Clickable
          Tooltip(
            message: patient.photoUrl != null || patient.photoPath != null
                ? 'Tap to view full photo'
                : 'No photo available',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showPatientPhoto(context, patient, isDark),
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipOval(
                        child: _buildPatientAvatar(patient, theme),
                      ),
                      // Overlay icon if photo exists
                      if (patient.photoUrl != null || patient.photoPath != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Patient Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      patient.user?.name ??
                          (localizations?.patients ?? 'Patient'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID: ${patient.id ?? '—'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (patient.user?.email != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.email_rounded,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          patient.user!.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (patient.phoneNumber != null || patient.phone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        patient.phoneNumber ?? patient.phone ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    );
  }

  Widget _buildPatientAvatar(PatientModel patient, ThemeData theme) {
    final String? photoUrl = patient.photoUrl;

    final fallback = Container(
      color: theme.colorScheme.primary,
      child: Center(
        child: Text(
          (patient.user?.name ?? 'P')[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return AuthenticatedImage(
        photoUrl: photoUrl,
        fit: BoxFit.cover,
        fallback: fallback,
        errorFallback: fallback,
      );
    }

    // No photo - show initials
    return Container(
      color: theme.colorScheme.primary,
      child: Center(
        child: Text(
          (patient.user?.name ?? 'P')[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showPatientPhoto(
    BuildContext context,
    PatientModel patient,
    bool isDark,
  ) {
    // Get photo URL
    String? photoUrl = patient.photoUrl ?? patient.photoPath;

    // If no photo, show message
    if (photoUrl == null || photoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            patient.user?.name != null
                ? '${patient.user!.name} has no photo'
                : 'Patient has no photo',
          ),
        ),
      );
      return;
    }

    // Show full-screen photo viewer
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full-screen image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: AuthenticatedImage(
                  photoUrl: photoUrl,
                  fit: BoxFit.contain,
                  errorFallback: Container(
                    padding: const EdgeInsets.all(20),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.white, size: 48),
                        SizedBox(height: 16),
                        Text('Failed to load image', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Patient name at bottom
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        patient.user?.name ?? 'Patient',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPatientData(BuildContext context) async {
    final patientService = ref.read(patientServiceProvider);
    final patientAsync = ref.read(patientProvider(widget.patientId));
    final resultValue = patientAsync.value;
    final patientName = (resultValue is Success<PatientModel>)
        ? resultValue.data.user?.name ?? 'patient'
        : 'patient';
    final fileName = 'patient_data_${patientName.replaceAll(' ', '_')}_${DateTime.now().toIso8601String().split('T').first}.zip';

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Export en cours...'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final result = await patientService.exportPatientData(widget.patientId);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading
      String? failureMsg;
      Uint8List? bytes;
      result.when(
        success: (b) => bytes = b,
        failure: (msg) => failureMsg = msg,
      );
      if (failureMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMsg!), backgroundColor: Colors.red),
        );
        return;
      }
      if (bytes == null) return;
      if (kIsWeb) {
        downloadFileWeb(bytes!, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export téléchargé.')),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes!);
        final xFile = XFile(filePath, mimeType: 'application/zip');
        await Share.shareXFiles([xFile], text: 'Données patient');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export prêt à partager.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
