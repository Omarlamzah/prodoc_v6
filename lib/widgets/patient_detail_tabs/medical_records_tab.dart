import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/patient_model.dart';
import '../../data/models/medical_record_model.dart';
import '../../providers/medical_record_providers.dart';
import '../../core/utils/result.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as custom;
import '../../screens/medical_record_detail_screen.dart';
import '../../screens/create_medical_record_screen.dart';
import '../../providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';

class MedicalRecordsTab extends ConsumerWidget {
  final PatientModel patient;

  const MedicalRecordsTab({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isAuthorized = authState.user?.isAdmin == 1 ||
        authState.user?.isDoctor == 1 ||
        authState.user?.isReceptionist == 1;
    final recordsAsync = ref.watch(patientMedicalRecordsProvider(patient.id!));

    return recordsAsync.when(
      data: (result) {
        if (result is Success<List<MedicalRecordModel>>) {
          final records = result.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF15151C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Dossiers Médicaux',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white : Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                          if (isAuthorized)
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreateMedicalRecordScreen(
                                      patientId: patient.id,
                                    ),
                                  ),
                                ).then((_) {
                                  ref.invalidate(patientMedicalRecordsProvider(
                                      patient.id!));
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (records.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 40, bottom: 40),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon with gradient background
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDark
                                          ? [
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.2),
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                            ]
                                          : [
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.05),
                                            ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.folder_open_rounded,
                                    size: 72,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return Column(
                                      children: [
                                        Text(
                                          localizations
                                                  ?.noMedicalRecordsFoundForPatient ??
                                              'No medical records found',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.grey[900],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          localizations
                                                  ?.startByCreatingFirstMedicalRecord ??
                                              'Start by creating the first medical record for this patient',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 40),
                                if (isAuthorized)
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CreateMedicalRecordScreen(
                                              patientId: patient.id,
                                            ),
                                          ),
                                        ).then((_) {
                                          ref.invalidate(
                                              patientMedicalRecordsProvider(
                                                  patient.id!));
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.8),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.4),
                                              blurRadius: 15,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.add_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Flexible(
                                              child: Text(
                                                'Créer un Dossier',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...records.map((record) => _buildRecordCard(
                              context,
                              ref,
                              record,
                              isDark,
                            )),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (result is Failure<List<MedicalRecordModel>>) {
          return custom.CustomErrorWidget(message: result.message);
        }
        return const SizedBox.shrink();
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) =>
          custom.CustomErrorWidget(message: error.toString()),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    WidgetRef ref,
    MedicalRecordModel record,
    bool isDark,
  ) {
    final recordDate = record.additionalData?['record_date'] != null
        ? DateTime.tryParse(record.additionalData!['record_date'] as String)
        : null;
    final dateLabel = recordDate != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(recordDate)
        : record.createdAt != null
            ? DateFormat('dd MMM yyyy', 'fr_FR').format(record.createdAt!)
            : 'Date inconnue';

    return InkWell(
      onTap: () {
        if (record.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MedicalRecordDetailScreen(recordId: record.id!),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F25) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.diagnosis ?? 'Dossier médical',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          if (record.doctor != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.local_hospital_rounded,
                              size: 14,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              record.doctor!.user?.name ?? 'Médecin',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (record.additionalData?['record_type'] != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRecordTypeColor(
                              record.additionalData!['record_type'] as String)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getRecordTypeColor(
                                record.additionalData!['record_type'] as String)
                            .withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      (record.additionalData!['record_type'] as String)
                          .toUpperCase(),
                      style: TextStyle(
                        color: _getRecordTypeColor(
                            record.additionalData!['record_type'] as String),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (record.symptoms != null && record.symptoms!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoSection(
                context,
                'Symptômes',
                Icons.sick_rounded,
                record.symptoms!,
                isDark,
              ),
            ],
            if (record.treatment != null && record.treatment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoSection(
                context,
                'Traitement',
                Icons.medication_rounded,
                record.treatment!,
                isDark,
              ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoSection(
                context,
                'Notes',
                Icons.note_rounded,
                record.notes!,
                isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String label,
    IconData icon,
    String content,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16, color: isDark ? Colors.grey[400] : Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRecordTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'consultation':
        return Colors.blue;
      case 'emergency':
        return Colors.red;
      case 'follow_up':
        return Colors.green;
      case 'lab_result':
        return Colors.purple;
      case 'surgery':
        return Colors.orange;
      case 'vaccination':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
