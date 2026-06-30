// lib/screens/medical_record_detail_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../core/utils/result.dart';
import '../data/models/medical_record_model.dart';
import '../providers/medical_record_providers.dart';
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../utils/web_download_helper.dart';
import '../widgets/error_widget.dart' as custom;
import '../widgets/loading_widget.dart';
import 'create_medical_record_screen.dart';
import 'create_prescription_screen.dart';
import '../core/config/api_constants.dart';

class MedicalRecordDetailScreen extends ConsumerStatefulWidget {
  final int recordId;

  const MedicalRecordDetailScreen({super.key, required this.recordId});

  @override
  ConsumerState<MedicalRecordDetailScreen> createState() =>
      _MedicalRecordDetailScreenState();
}

class _MedicalRecordDetailScreenState
    extends ConsumerState<MedicalRecordDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  String _attachmentVisibility = 'public';
  int? _updatingAttachmentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final recordAsync = ref.watch(medicalRecordProvider(widget.recordId));
    final isAuthorized =
        authState.user?.isAdmin == 1 || authState.user?.isDoctor == 1;
    final currentUserId = authState.user?.id;

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.medicalRecordDetails ?? 'Medical Record Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            );
          },
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        actions: [
          if (_currentTabIndex == 2)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: localizations?.addAttachment ?? 'Add Attachment',
                    onPressed: () => _uploadAttachment(widget.recordId),
                  );
                },
              ),
            ),
          if (isAuthorized && _currentTabIndex != 2)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateMedicalRecordScreen(
                        recordId: widget.recordId,
                      ),
                    ),
                  ).then((_) {
                    ref.invalidate(medicalRecordProvider(widget.recordId));
                  });
                },
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Tab(
                        icon: const Icon(Icons.description_rounded),
                        text: localizations?.details ?? 'Details');
                  },
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Tab(
                        icon: const Icon(Icons.medication_rounded),
                        text: localizations?.prescriptions ?? 'Prescriptions');
                  },
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Tab(
                        icon: const Icon(Icons.attach_file_rounded),
                        text: localizations?.attachments ?? 'Attachments');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: recordAsync.when(
        data: (result) {
          if (result is Success<MedicalRecordModel>) {
            return _buildDetailContent(
                result.data, isAuthorized, currentUserId);
          } else if (result is Failure<MedicalRecordModel>) {
            return custom.CustomErrorWidget(message: result.message);
          }
          return const SizedBox.shrink();
        },
        loading: () => const LoadingWidget(),
        error: (error, stack) =>
            custom.CustomErrorWidget(message: error.toString()),
      ),
    );
  }

  Widget _buildDetailContent(
      MedicalRecordModel record, bool isAuthorized, int? currentUserId) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Check if user can update visibility
    // Admin: can update any record
    // Doctor: can update if they are the assigned doctor (check if record's doctor's user id matches current user id)
    // Patient: can update their own records (check if record's patient's user id matches current user id)
    bool canUpdateVisibility = false;
    if (user?.isAdmin == 1) {
      canUpdateVisibility = true;
    } else if (user?.isDoctor == 1) {
      // Check if the record's doctor's user id matches the current user id
      // This matches backend logic: $medicalRecord->doctor_id === $user->doctor->id
      // In Flutter, we check if the doctor's user id matches (simplified check)
      canUpdateVisibility = record.doctor?.user?.id == user?.id;
    } else if (user?.isPatient == 1) {
      // Check if the record's patient's user id matches the current user id
      // This matches backend logic: $medicalRecord->patient->user_id === $user->id
      canUpdateVisibility = record.patient?.user?.id == user?.id;
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildDetailsTab(record, canUpdateVisibility),
        _buildPrescriptionsTab(record, isAuthorized),
        _buildAttachmentsTab(record, isAuthorized, currentUserId),
      ],
    );
  }

  Widget _buildDetailsTab(MedicalRecordModel record, bool canUpdateVisibility) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                ]
              : [
                  Colors.grey.shade50,
                  Colors.white,
                ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildModernHeaderCard(
                    record, isDark, primaryColor, canUpdateVisibility)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            // General Information
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                final locale = ref.watch(localeProvider).locale;
                return _buildModernSection(
                  localizations?.generalInformation ?? 'General Information',
                  Icons.info_rounded,
                  Colors.blue,
                  [
                    _buildModernInfoRow(
                        'ID', record.id?.toString(), Icons.tag_rounded, isDark),
                    _buildModernInfoRow(
                        localizations?.patients ?? 'Patient',
                        record.patient?.user?.name,
                        Icons.person_rounded,
                        isDark),
                    _buildModernInfoRow(
                        localizations?.doctor ?? 'Doctor',
                        record.doctor?.user?.name,
                        Icons.medical_services_rounded,
                        isDark),
                    _buildModernInfoRow(
                        localizations?.specialty ?? 'Specialty',
                        record.specialty?.name,
                        Icons.local_hospital_rounded,
                        isDark),
                    if (record.appointment != null)
                      _buildModernInfoRow(
                        localizations?.appointment ?? 'Appointment',
                        '${record.appointment!.appointmentDate} ${record.appointment!.appointmentTime ?? ''}',
                        Icons.calendar_today_rounded,
                        isDark,
                      ),
                    if (record.createdAt != null)
                      _buildModernInfoRow(
                        localizations?.createdOn ?? 'Created on',
                        DateFormat(
                                'dd MMMM yyyy \'at\' HH:mm', locale.toString())
                            .format(record.createdAt!),
                        Icons.access_time_rounded,
                        isDark,
                      ),
                    const SizedBox(height: 12),
                    _buildVisibilityRow(record, canUpdateVisibility, isDark),
                  ],
                  isDark,
                );
              },
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 300.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            // Vital Signs
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return _buildModernSection(
                  localizations?.vitalSigns ?? 'Vital Signs',
                  Icons.favorite_rounded,
                  Colors.red,
                  [
                    _buildVitalSignCard(
                        localizations?.bloodPressure ?? 'Blood Pressure',
                        record.bloodPressure,
                        Icons.monitor_heart_rounded,
                        Colors.red,
                        isDark),
                    _buildVitalSignCard(
                        localizations?.weight ?? 'Weight',
                        record.weight != null ? '${record.weight} kg' : null,
                        Icons.scale_rounded,
                        Colors.orange,
                        isDark),
                    _buildVitalSignCard(
                        localizations?.height ?? 'Height',
                        record.height != null ? '${record.height} cm' : null,
                        Icons.height_rounded,
                        Colors.blue,
                        isDark),
                    _buildVitalSignCard(
                        localizations?.temperature ?? 'Temperature',
                        record.temperature != null
                            ? '${record.temperature} °C'
                            : null,
                        Icons.thermostat_rounded,
                        Colors.deepOrange,
                        isDark),
                    _buildVitalSignCard(
                        localizations?.heartRate ?? 'Heart Rate',
                        record.heartRate != null
                            ? '${record.heartRate} bpm'
                            : null,
                        Icons.favorite_rounded,
                        Colors.pink,
                        isDark),
                    _buildVitalSignCard(
                        localizations?.respiratoryRate ?? 'Respiratory Rate',
                        record.respiratoryRate != null
                            ? '${record.respiratoryRate} /min'
                            : null,
                        Icons.air_rounded,
                        Colors.teal,
                        isDark),
                    _buildVitalSignCard('BMI', record.bmi,
                        Icons.calculate_rounded, Colors.purple, isDark),
                  ],
                  isDark,
                );
              },
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 300.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            // Allergies
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return _buildModernSection(
                  localizations?.allergies ?? 'Allergies',
                  Icons.warning_rounded,
                  Colors.amber,
                  [
                    _buildAllergyCard(record, isDark),
                  ],
                  isDark,
                );
              },
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 300.ms)
                .slideY(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            // Medical Information
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return _buildModernSection(
                  localizations?.medicalInformation ?? 'Medical Information',
                  Icons.medical_information_rounded,
                  Colors.green,
                  [
                    _buildMedicalInfoCard(localizations?.symptoms ?? 'Symptoms',
                        record.symptoms, Icons.sick_rounded, isDark),
                    _buildMedicalInfoCard(
                        localizations?.diagnosis ?? 'Diagnosis',
                        record.diagnosis,
                        Icons.medical_information_rounded,
                        isDark),
                    _buildMedicalInfoCard(
                        localizations?.treatment ?? 'Treatment',
                        record.treatment,
                        Icons.healing_rounded,
                        isDark),
                    _buildMedicalInfoCard(localizations?.notes ?? 'Notes',
                        record.notes, Icons.note_rounded, isDark),
                  ],
                  isDark,
                );
              },
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 300.ms)
                .slideY(begin: -0.1, end: 0),
            if (record.specialtyData != null &&
                record.specialtyData!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildModernSection(
                    localizations?.specialtyData ?? 'Specialty Data',
                    Icons.science_rounded,
                    Colors.purple,
                    record.specialtyData!.entries
                        .map((e) => _buildModernInfoRow(
                            e.key,
                            e.value?.toString(),
                            Icons.data_object_rounded,
                            isDark))
                        .toList(),
                    isDark,
                  );
                },
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 300.ms)
                  .slideY(begin: -0.1, end: 0),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionsTab(MedicalRecordModel record, bool isAuthorized) {
    final prescriptions = record.prescriptions ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                ]
              : [
                  Colors.grey.shade50,
                  Colors.white,
                ],
        ),
      ),
      child: Column(
        children: [
          // Add button at top when there are prescriptions
          if (isAuthorized && prescriptions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildModernCreatePrescriptionButton(
                  record, isDark, primaryColor),
            ),
          // List or empty state
          Expanded(
            child: prescriptions.isEmpty
                ? _buildEmptyPrescriptionsState(isDark, isAuthorized, record)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: prescriptions.length,
                    itemBuilder: (context, index) {
                      final prescription = prescriptions[index];
                      return _buildModernPrescriptionCard(
                              prescription, isDark, primaryColor, index)
                          .animate()
                          .fadeIn(delay: (index * 100).ms, duration: 300.ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrescriptionsState(
      bool isDark, bool isAuthorized, MedicalRecordModel record) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.medication_rounded,
                size: 60,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  children: [
                    Text(
                      'No Prescriptions',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations?.noPrescriptionsRecorded ??
                          'No prescriptions have been recorded for this medical record',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            _buildModernCreatePrescriptionButton(record, isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPrescriptionCard(
      dynamic prescription, bool isDark, Color primaryColor, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.all(20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: primaryColor,
              size: 24,
            ),
          ),
          title: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              final locale = ref.watch(localeProvider).locale;
              return Text(
                localizations?.prescriptionNumber(prescription.id) ??
                    'Prescription #${prescription.id}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              );
            },
          ),
          subtitle: prescription.createdAt != null
              ? Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    final locale = ref.watch(localeProvider).locale;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color:
                                isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMMM yyyy', locale.toString())
                                .format(prescription.createdAt!),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : null,
          children: [
            if (prescription.medications != null &&
                prescription.medications!.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations?.medications ?? 'Medications',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade800,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ...prescription.medications!.map(
                  (med) => _buildMedicationItem(med, isDark, primaryColor)),
            ],
            if (prescription.notes != null &&
                prescription.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_rounded,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              localizations?.notes ?? 'Notes',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prescription.notes!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (prescription.pdfPath != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openPrescriptionPdf(
                              prescription.pdfPath,
                              prescription.pdfUrl,
                              prescription.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.visibility_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return Text(
                                      'View PDF',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded),
                      label: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            'Download',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      onPressed: () => _downloadPrescriptionPdf(
                          prescription.pdfPath,
                          prescription.pdfUrl,
                          prescription.id),
                      style: OutlinedButton.styleFrom(
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
          ],
        ),
      ),
    );
  }

  Widget _buildModernCreatePrescriptionButton(
      MedicalRecordModel record, bool isDark, Color primaryColor) {
    final authState = ref.watch(authProvider);
    final isAuthorized =
        authState.user?.isAdmin == 1 || authState.user?.isDoctor == 1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          onTap: isAuthorized
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePrescriptionScreen(
                        currentPatient: record.patient,
                      ),
                    ),
                  ).then((_) {
                    ref.invalidate(medicalRecordProvider(widget.recordId));
                  });
                }
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You do not have permission to create a prescription',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_circle_rounded,
                    color: Colors.white,
                    size: 28,
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
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Prescription',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add a new prescription',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationItem(dynamic med, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.medication_liquid_rounded,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      med.medication?.nom ?? med.medicationName ?? 'Medication',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (med.dosage != null) ...[
                      Icon(
                        Icons.science_rounded,
                        size: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            'Dosage: ${med.dosage}',
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
                    if (med.dosage != null && med.frequency != null)
                      Text(
                        ' • ',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    if (med.frequency != null) ...[
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            'Frequency: ${med.frequency}',
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsTab(
      MedicalRecordModel record, bool isAuthorized, int? currentUserId) {
    final attachments = record.attachments ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Column(
          children: [
            // Upload button at top
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _uploadAttachment(record.id!),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Text(
                                localizations?.addAttachment ??
                                    'Add Attachment',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (attachments.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_file,
                          size: 50,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Column(
                            children: [
                              Text(
                                'No Attachments',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add documents, images or files',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _uploadAttachment(record.id!),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_circle_outline,
                                      color: Colors.white, size: 22),
                                  const SizedBox(width: 8),
                                  Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return Text(
                                        localizations?.addAttachment ??
                                            'Add Attachment',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
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
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return _buildModernAttachmentCard(attachment, isDark,
                        primaryColor, isAuthorized, currentUserId);
                  },
                ),
              ),
          ],
        ),
        // Floating action button
        if (attachments.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withOpacity(0.8),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => _uploadAttachment(record.id!),
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModernAttachmentCard(MedicalRecordAttachment attachment,
      bool isDark, Color primaryColor, bool isAuthorized, int? currentUserId) {
    final fileType = attachment.fileType ?? '';
    final isImage = fileType.contains('image');
    final isPdf = fileType.contains('pdf');

    Color getFileColor() {
      if (isImage) return Colors.blue;
      if (isPdf) return Colors.red;
      return Colors.orange;
    }

    IconData getFileIcon() {
      if (isImage) return Icons.image_rounded;
      if (isPdf) return Icons.picture_as_pdf_rounded;
      return Icons.insert_drive_file_rounded;
    }

    final fileColor = getFileColor();
    final fileIcon = getFileIcon();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          width: 1,
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
          onTap: () {
            if (attachment.fileUrl != null || attachment.filePath != null) {
              _openAttachment(attachment);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // File Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    fileIcon,
                    color: fileColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // File Info - Expanded to take available space
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            attachment.fileName ?? 'File',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.white : Colors.grey.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      if (attachment.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  final locale =
                                      ref.watch(localeProvider).locale;
                                  return Text(
                                    DateFormat('dd MMM yyyy \'at\' HH:mm',
                                            locale.toString())
                                        .format(attachment.createdAt!),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Actions - Fixed width to prevent overflow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Visibility badge and selector - Compact layout
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (attachment.visibility == 'private'
                                      ? Colors.orange
                                      : Colors.green)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  attachment.visibility == 'private'
                                      ? Icons.lock
                                      : Icons.lock_open,
                                  size: 14,
                                  color: attachment.visibility == 'private'
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    attachment.visibility == 'private'
                                        ? 'Private'
                                        : 'Public',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: attachment.visibility == 'private'
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if ((isAuthorized ||
                                (currentUserId != null &&
                                    currentUserId ==
                                        attachment.uploadedByUserId)) &&
                            attachment.id != null) ...[
                          const SizedBox(width: 4),
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return DropdownButton<String>(
                                value: attachment.visibility ?? 'public',
                                underline: const SizedBox(),
                                iconSize: 18,
                                items: [
                                  DropdownMenuItem(
                                      value: 'public',
                                      child: Text(
                                          localizations?.public ?? 'Public',
                                          style:
                                              const TextStyle(fontSize: 12))),
                                  DropdownMenuItem(
                                      value: 'private',
                                      child: Text(
                                          localizations?.private ?? 'Private',
                                          style:
                                              const TextStyle(fontSize: 12))),
                                ],
                                onChanged: _updatingAttachmentId != null
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _changeAttachmentVisibility(
                                              attachment.id!, value);
                                        }
                                      },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Action buttons - Compact
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (attachment.fileUrl != null ||
                            attachment.filePath != null)
                          Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.visibility_rounded,
                                  color: primaryColor, size: 20),
                              tooltip: 'View File',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () => _openAttachment(attachment),
                            ),
                          ),
                        if (isAuthorized) ...[
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_rounded,
                                  color: Colors.red, size: 20),
                              tooltip: 'Delete',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () =>
                                  _deleteAttachment(attachment.id!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern UI Components
  Widget _buildModernHeaderCard(MedicalRecordModel record, bool isDark,
      Color primaryColor, bool canUpdateVisibility) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: Colors.white,
                    size: 28,
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
                          final locale = ref.watch(localeProvider).locale;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record #${record.id}',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (record.createdAt != null)
                                Text(
                                  DateFormat('dd MMMM yyyy', locale.toString())
                                      .format(record.createdAt!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (record.patient != null || record.doctor != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              if (record.patient != null)
                _buildHeaderInfoRow(Icons.person_rounded, 'Patient',
                    record.patient!.user?.name ?? 'N/A', Colors.white),
              if (record.doctor != null) ...[
                const SizedBox(height: 8),
                _buildHeaderInfoRow(Icons.medical_services_rounded, 'Doctor',
                    record.doctor!.user?.name ?? 'N/A', Colors.white),
              ],
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Row(
                    children: [
                      Icon(
                        record.visibility == 'public'
                            ? Icons.public
                            : Icons.lock,
                        size: 18,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${localizations?.visibility ?? 'Visibility'}: ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (record.visibility == 'public'
                                  ? Colors.green
                                  : Colors.orange)
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.visibility == 'public'
                              ? (localizations?.public ?? 'Public')
                              : (localizations?.private ?? 'Private'),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (canUpdateVisibility) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            _updateVisibility(record.visibility == 'public'
                                ? 'private'
                                : 'public');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  record.visibility == 'public'
                                      ? Icons.lock_outline
                                      : Icons.public,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  record.visibility == 'public'
                                      ? (localizations?.changeToPrivate ??
                                          'Change to Private')
                                      : (localizations?.changeToPublic ??
                                          'Change to Public'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfoRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withOpacity(0.9)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: color.withOpacity(0.8),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildModernSection(String title, IconData icon, Color color,
      List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(
      String label, String? value, IconData icon, bool isDark) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityRow(
      MedicalRecordModel record, bool canUpdate, bool isDark) {
    final isPublic = record.visibility == 'public';
    final localizations = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPublic
              ? Colors.green.withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPublic ? Colors.green : Colors.orange).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  (isPublic ? Colors.green : Colors.orange).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPublic ? Icons.public : Icons.lock,
              size: 24,
              color: isPublic ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      localizations?.visibility ?? 'Visibility',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPublic
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPublic
                            ? (localizations?.public ?? 'Public')
                            : (localizations?.private ?? 'Private'),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPublic ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isPublic
                      ? (localizations?.visibleToAllAuthorized ??
                          'Visible to all authorized users')
                      : (localizations?.onlyVisibleToDoctorAndAdmin ??
                          'Only visible to assigned doctor and admin'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (canUpdate)
            Switch(
              value: isPublic,
              onChanged: (value) {
                _updateVisibility(value ? 'public' : 'private');
              },
              activeColor: Colors.green,
              activeTrackColor: Colors.green.withOpacity(0.5),
              inactiveThumbColor: Colors.orange,
              inactiveTrackColor: Colors.orange.withOpacity(0.5),
            )
          else
            Icon(
              Icons.lock_outline,
              size: 20,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
        ],
      ),
    );
  }

  Future<void> _updateVisibility(String newVisibility) async {
    final service = ref.read(medicalRecordServiceProvider);
    final result = await service.updateMedicalRecordVisibility(
      recordId: widget.recordId,
      visibility: newVisibility,
    );

    if (mounted) {
      final localizations = AppLocalizations.of(context);
      result.when(
        success: (_) {
          // Refresh the record
          ref.invalidate(medicalRecordProvider(widget.recordId));
          final visibilityText = newVisibility == 'public'
              ? (localizations?.public ?? 'Public')
              : (localizations?.private ?? 'Private');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.visibilityUpdated(visibilityText) ??
                    'Visibility updated to $visibilityText',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
        failure: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $message'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    }
  }

  Widget _buildVitalSignCard(
      String label, String? value, IconData icon, Color color, bool isDark) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
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
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyCard(MedicalRecordModel record, bool isDark) {
    final hasAllergies = record.hasAllergies == true;
    final color = hasAllergies ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasAllergies
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    hasAllergies ? 'Has Allergies' : 'No Allergies',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  );
                },
              ),
            ],
          ),
          if (record.allergyDetails != null &&
              record.allergyDetails!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                record.allergyDetails!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalInfoCard(
      String label, String? value, IconData icon, bool isDark) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrescriptionPdf(
      String? pdfPath, String? pdfUrl, int? prescriptionId) async {
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

    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription ID not available')),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(url);

      // Try to launch the URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // If canLaunchUrl returns false, try anyway
        try {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open PDF: ${e.toString()}'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _downloadPrescriptionPdf(
      String? pdfPath, String? pdfUrl, int? prescriptionId) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF URL not available')),
        );
      }
      return;
    }

    final finalUrl = url; // Non-nullable after check

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Téléchargement en cours...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
          // For web, use the response bytes we already have to trigger download
          // Since we fetched with auth, we have the file content
          try {
            // Use the bytes from response to create download
            final bytes = response.bodyBytes;
            downloadFileWeb(bytes, fileName);

            if (mounted) {
              Navigator.of(context).pop(); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF téléchargé: $fileName'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
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

          if (mounted) {
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
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download error: ${response.statusCode}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _openAttachment(MedicalRecordAttachment attachment) async {
    if (attachment.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment ID not available')),
        );
      }
      return;
    }

    // Use API endpoint with authentication
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.medicalRecordAttachmentDownload(attachment.id!)}';

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Téléchargement en cours...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final uri = Uri.parse(url);

      // Get auth token
      final authState = ref.read(authProvider);
      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the file with authentication
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // Get file name from attachment or generate one
        String fileName = attachment.fileName ??
            'attachment_${attachment.id ?? DateTime.now().millisecondsSinceEpoch}';

        // Add extension if missing
        final fileType = attachment.fileType ?? '';
        if (!fileName.contains('.')) {
          if (fileType.contains('pdf')) {
            fileName += '.pdf';
          } else if (fileType.contains('image/jpeg') ||
              fileType.contains('image/jpg')) {
            fileName += '.jpg';
          } else if (fileType.contains('image/png')) {
            fileName += '.png';
          } else if (fileType.contains('word')) {
            fileName += '.docx';
          } else if (fileType.contains('excel') ||
              fileType.contains('spreadsheet')) {
            fileName += '.xlsx';
          }
        }

        final isImage = fileType.contains('image');
        final isPdf = fileType.contains('pdf');

        if (kIsWeb) {
          // For web, download the file
          final bytes = response.bodyBytes;
          downloadFileWeb(bytes, fileName);

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fichier téléchargé: $fileName'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // For mobile, save to temporary directory and open
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog

            try {
              // Use share_plus to open the file with default app
              final xFile = XFile(
                filePath,
                mimeType: fileType.isNotEmpty ? fileType : null,
              );

              await Share.shareXFiles(
                [xFile],
                text: isImage
                    ? 'Image du dossier médical'
                    : isPdf
                        ? 'Document PDF'
                        : 'Pièce jointe',
                subject: attachment.fileName ?? 'Attachment',
              );
            } catch (e) {
              // If share fails, show message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Fichier téléchargé: $fileName\nEmplacement: ${tempDir.path}'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de téléchargement: ${response.statusCode}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<String?> _promptAttachmentVisibility(
      {String initial = 'public'}) async {
    String selected = initial;
    return showDialog<String>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(localizations?.chooseVisibility ?? 'Choose visibility'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text(localizations?.publicDescription ??
                        'Public (visible to authorized staff)'),
                    value: 'public',
                    groupValue: selected,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selected = value);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(localizations?.privateDescription ??
                        'Private (only you)'),
                    value: 'private',
                    groupValue: selected,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selected = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(localizations?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: Text(localizations?.confirm ?? 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeAttachmentVisibility(
      int attachmentId, String visibility) async {
    setState(() {
      _updatingAttachmentId = attachmentId;
    });

    final service = ref.read(medicalRecordServiceProvider);
    final result = await service.updateAttachmentVisibility(
        attachmentId: attachmentId, visibility: visibility);

    if (mounted) {
      setState(() {
        _updatingAttachmentId = null;
      });
      result.when(
        success: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Visibility updated to "$visibility"'),
            ),
          );
          ref.invalidate(medicalRecordProvider(widget.recordId));
        },
        failure: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
    }
  }

  Future<void> _uploadAttachment(int recordId) async {
    // Show modern bottom sheet with options
    final source = await _showUploadOptionsBottomSheet();
    if (source == null) return;

    try {
      File? pickedFile;
      Uint8List? fileBytes;
      String fileName = '';

      if (source == 'camera') {
        // Take photo with camera
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (photo == null) return;

        // Generate filename with timestamp if name is empty or invalid
        if (photo.name.isEmpty || !photo.name.contains('.')) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          fileName = 'camera_$timestamp.jpg';
        } else {
          fileName = photo.name;
        }

        if (kIsWeb) {
          fileBytes = await photo.readAsBytes();
        } else {
          pickedFile = File(photo.path);
          // Ensure filename has proper extension
          if (!fileName.toLowerCase().endsWith('.jpg') &&
              !fileName.toLowerCase().endsWith('.jpeg')) {
            fileName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '') + '.jpg';
          }
        }
      } else if (source == 'gallery') {
        // Use FilePicker instead of ImagePicker to avoid READ_MEDIA permissions
        // FilePicker uses system photo picker on Android 13+ without requiring permissions
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return;

        final file = result.files.single;
        fileName = file.name;

        if (kIsWeb) {
          if (file.bytes == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Erreur lors du chargement de l\'image')),
            );
            return;
          }
          fileBytes = file.bytes;
        } else {
          if (file.path == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Erreur lors du chargement de l\'image')),
            );
            return;
          }
          pickedFile = File(file.path!);

          // Generate filename if empty
          if (fileName.isEmpty || !fileName.contains('.')) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final pathExtension = file.path!.split('.').last.toLowerCase();
            if (pathExtension == 'jpg' ||
                pathExtension == 'jpeg' ||
                pathExtension == 'png') {
              fileName = 'image_$timestamp.$pathExtension';
            } else {
              fileName = 'image_$timestamp.jpg';
            }
          }
        }
      } else if (source == 'file') {
        // Choose file
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) {
          return;
        }

        final file = result.files.single;
        fileName = file.name;

        if (kIsWeb) {
          if (file.bytes == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to read file. Please try again.'),
                ),
              );
            }
            return;
          }
          fileBytes = file.bytes;
        } else {
          if (file.path == null || file.path!.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File path not available. Please try again.'),
                ),
              );
            }
            return;
          }

          // Use the cached file path from FilePicker
          pickedFile = File(file.path!);

          // Verify file exists and is readable
          if (!await pickedFile.exists()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File does not exist: ${file.path}'),
                ),
              );
            }
            return;
          }

          // Ensure we have a valid filename
          if (fileName.isEmpty) {
            fileName = file.path!.split('/').last;
            if (fileName.isEmpty) {
              fileName = 'file_${DateTime.now().millisecondsSinceEpoch}';
            }
          }
        }
      }

      // Ask visibility before upload
      final selectedVisibility =
          await _promptAttachmentVisibility(initial: _attachmentVisibility);
      if (selectedVisibility == null) return;
      _attachmentVisibility = selectedVisibility;

      if (mounted) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Téléchargement en cours...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final service = ref.read(medicalRecordServiceProvider);
      Result<MedicalRecordAttachment> uploadResult;

      if (kIsWeb) {
        // On web, use bytes
        uploadResult = await service.uploadAttachment(
          medicalRecordId: recordId,
          fileBytes: fileBytes,
          fileName: fileName,
          visibility: _attachmentVisibility,
        );
      } else {
        // On mobile/desktop, use File
        // Pass fileName for proper file naming on server
        uploadResult = await service.uploadAttachment(
          medicalRecordId: recordId,
          file: pickedFile,
          fileName: fileName.isNotEmpty ? fileName : null,
          visibility: _attachmentVisibility,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        uploadResult.when(
          success: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File "$fileName" uploaded successfully'),
              ),
            );
            ref.invalidate(medicalRecordProvider(widget.recordId));
          },
          failure: (message) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $message')),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
          ),
        );
      }
    }
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.deleteAttachment ?? 'Delete Attachment');
          },
        ),
        content: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text(
                'Are you sure you want to delete this attachment?');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(medicalRecordServiceProvider);
      final result = await service.deleteAttachment(attachmentId);

      if (mounted) {
        result.when(
          success: (_) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(localizations?.attachmentDeleted ??
                      'Attachment deleted')),
            );
            ref.invalidate(medicalRecordProvider(widget.recordId));
          },
          failure: (message) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          },
        );
      }
    }
  }

  Future<String?> _showUploadOptionsBottomSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          localizations?.addAttachment ?? 'Add Attachment',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose an option to add a file',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color:
                                isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Options
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.camera_alt_rounded,
                            title: 'Camera',
                            subtitle: 'Take a photo',
                            color: Colors.blue,
                            onTap: () => Navigator.pop(context, 'camera'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.photo_library_rounded,
                            title: 'Gallery',
                            subtitle: 'Choose an image',
                            color: Colors.green,
                            onTap: () => Navigator.pop(context, 'gallery'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildUploadOption(
                            icon: Icons.insert_drive_file_rounded,
                            title: 'File',
                            subtitle: 'Choose a file',
                            color: Colors.orange,
                            onTap: () => Navigator.pop(context, 'file'),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
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

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
