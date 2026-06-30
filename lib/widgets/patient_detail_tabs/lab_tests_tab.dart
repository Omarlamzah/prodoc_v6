import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/result.dart';
import '../../data/models/lab_test_model.dart';
import '../../data/models/patient_model.dart';
import '../../data/models/doctor_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/doctor_providers.dart';
import '../../providers/lab_test_providers.dart';
import '../loading_widget.dart';
import '../error_widget.dart' as custom;

class LabTestsTab extends ConsumerWidget {
  final PatientModel patient;

  const LabTestsTab({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final doctorsAsync = ref.watch(doctorsProvider);
    final isAuthorized = authState.user?.isAdmin == 1 ||
        authState.user?.isDoctor == 1 ||
        authState.user?.isReceptionist == 1 ||
        authState.user?.isLabTechnician == 1;
    final labTestsAsync = ref.watch(patientLabTestsProvider(patient.id!));

    return labTestsAsync.when(
      data: (result) {
        if (result is Success<List<LabTestModel>>) {
          final tests = result.data;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(patientLabTestsProvider(patient.id!));
              await ref.read(patientLabTestsProvider(patient.id!).future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.science_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Analyses de Laboratoire',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                  ),
                                ),
                              ],
                            ),
                            if (isAuthorized)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 210,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showCreateLabTestDialog(
                                      context,
                                      ref,
                                      isDark,
                                      doctorsAsync,
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Nouvelle analyse'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      minimumSize: const Size(0, 40),
                                      foregroundColor:
                                          isDark ? Colors.white : Colors.white,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (tests.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.science_outlined,
                                    size: 48,
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucune analyse trouvée',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Les analyses seront affichées dès qu’elles seront disponibles pour ce patient.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...tests.map(
                            (test) => _buildLabTestCard(
                              context,
                              ref,
                              test,
                              isDark,
                              isAuthorized,
                              doctorsAsync,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (result is Failure<List<LabTestModel>>) {
          return custom.CustomErrorWidget(
            message: result.message,
            onRetry: () => ref.invalidate(patientLabTestsProvider(patient.id!)),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const LoadingWidget(),
      error: (error, _) => custom.CustomErrorWidget(
        message: error.toString(),
        onRetry: () => ref.invalidate(patientLabTestsProvider(patient.id!)),
      ),
    );
  }

  Widget _buildLabTestCard(
    BuildContext context,
    WidgetRef ref,
    LabTestModel test,
    bool isDark,
    bool isAuthorized,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) {
    final testName = test.testName ?? 'Analyse';
    final doctorName = test.doctor?.user?.name;
    final testDate = test.testDate ?? test.createdAt;
    final dateLabel = testDate != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(testDate)
        : 'Date inconnue';

    Color statusColor;
    String statusLabel;
    switch (test.status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Terminé';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'En attente';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = test.status ?? 'Inconnu';
    }

    return Container(
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (doctorName != null && doctorName.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_hospital_rounded,
                                size: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  doctorName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAuthorized && test.id != null)
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditLabTestDialog(
                    context,
                    ref,
                    isDark,
                    doctorsAsync,
                    test,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          if (test.result != null && test.result!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? Colors.black.withOpacity(0.3) : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      test.result ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.green[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (test.attachments != null && test.attachments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Fichiers joints',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: test.attachments!
                  .map((attachment) => _buildAttachmentChip(
                        context,
                        ref,
                        attachment,
                        isDark,
                      ))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.attach_file_rounded,
                  size: 16,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  'Aucun fichier joint',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          if (isAuthorized && test.id != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Ajouter des fichiers'),
                onPressed: () => _pickAndUploadAttachments(
                  context,
                  ref,
                  test.id!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAttachments(
    BuildContext context,
    WidgetRef ref,
    int labTestId,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Téléversement en cours...')),
    );

    final service = ref.read(labTestServiceProvider);
    try {
      for (final file in result.files) {
        if (kIsWeb) {
          if (file.bytes == null) continue;
          await service.uploadAttachment(
            labTestId: labTestId,
            fileBytes: file.bytes!,
            fileName: file.name,
            fileType: file.extension,
          );
        } else {
          if (file.path == null) continue;
          await service.uploadAttachment(
            labTestId: labTestId,
            file: File(file.path!),
            fileName: file.name,
            fileType: file.extension,
          );
        }
      }

      if (context.mounted) {
        ref.invalidate(patientLabTestsProvider(patient.id!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichiers ajoutés avec succès')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléversement: $e')),
        );
      }
    }
  }

  Widget _buildAttachmentChip(
    BuildContext context,
    WidgetRef ref,
    LabTestAttachmentModel attachment,
    bool isDark,
  ) {
    final fileName = attachment.fileName ?? 'Fichier';

    return GestureDetector(
      onTap: () => _openAttachment(context, ref, attachment),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF26262F) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_rounded,
              size: 16,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    LabTestAttachmentModel attachment,
  ) async {
    if (attachment.id == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le fichier'),
          ),
        );
      }
      return;
    }

    final service = ref.read(labTestServiceProvider);
    final result = await service.downloadAttachment(attachment.id!);

    result.when(
      success: (bytes) async {
        if (!context.mounted) return;
        final fileName =
            attachment.fileName ?? 'attachment_${attachment.id}';
        final mimeType = _mimeFromFileName(fileName);

        if (kIsWeb) {
          final uri = Uri.dataFromBytes(bytes, mimeType: mimeType);
          final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (!launched && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Échec de l\'ouverture du fichier'),
              ),
            );
          }
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          final uri = Uri.file(file.path);
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Échec de l\'ouverture du fichier'),
              ),
            );
          }
        }
      },
      failure: (message) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
    );
  }

  static String _mimeFromFileName(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _showCreateLabTestDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) async {
    final testNameController = TextEditingController();
    final resultController = TextEditingController();
    final attachments = <PlatformFile>[];
    DateTime? selectedDate;
    int? selectedDoctorId;
    String status = 'pending';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F1F25) : Colors.white,
              title: const Text('Nouvelle analyse'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: testNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du test *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: resultController,
                      decoration: const InputDecoration(
                        labelText: 'Résultats (optionnel)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    if (doctorsAsync is AsyncData<Result<List<DoctorModel>>>)
                      doctorsAsync.value.when(
                        success: (docs) => DropdownButtonFormField<int>(
                          value: selectedDoctorId,
                          decoration: const InputDecoration(
                            labelText: 'Médecin (optionnel)',
                          ),
                          items: docs
                              .map(
                                (d) => DropdownMenuItem<int>(
                                  value: d.id,
                                  child:
                                      Text(d.user?.name ?? 'Dr. ${d.id ?? ''}'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedDoctorId = val;
                            });
                          },
                        ),
                        failure: (msg) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Médecins non chargés: $msg',
                            style: TextStyle(
                              color: isDark ? Colors.red[200] : Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      selectedDate = pickedDate;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  selectedDate != null
                                      ? DateFormat('dd/MM/yyyy')
                                          .format(selectedDate!)
                                      : 'Date du test',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                            labelText: 'Statut',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('En attente'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Terminé'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                status = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          attachments.isEmpty
                              ? 'Ajouter des fichiers'
                              : 'Ajouter d’autres fichiers',
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            withData: kIsWeb,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setState(() {
                              attachments.addAll(result.files);
                            });
                          }
                        },
                      ),
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attachments
                              .asMap()
                              .entries
                              .map(
                                (entry) => Chip(
                                  label: Text(
                                    entry.value.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      attachments.removeAt(entry.key);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (testNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Le nom du test est requis'),
                              ),
                            );
                            return;
                          }

                          setState(() => isSaving = true);

                          final service = ref.read(labTestServiceProvider);
                          final payload = {
                            'patient_id': patient.id,
                            if (selectedDoctorId != null)
                              'doctor_id': selectedDoctorId,
                            'test_name': testNameController.text.trim(),
                            'result': resultController.text.trim().isEmpty
                                ? null
                                : resultController.text.trim(),
                            'status': status,
                            'test_date': selectedDate != null
                                ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                                : null,
                          };

                          final result = await service.createLabTest(payload);
                          if (result is Success<LabTestModel>) {
                            // Upload attachments if any
                            if (attachments.isNotEmpty) {
                              for (final file in attachments) {
                                if (kIsWeb) {
                                  if (file.bytes == null) continue;
                                  await service.uploadAttachment(
                                    labTestId: result.data.id!,
                                    fileBytes: file.bytes!,
                                    fileName: file.name,
                                    fileType: file.extension,
                                  );
                                } else {
                                  if (file.path == null) continue;
                                  await service.uploadAttachment(
                                    labTestId: result.data.id!,
                                    file: File(file.path!),
                                    fileName: file.name,
                                    fileType: file.extension,
                                  );
                                }
                              }
                            }

                            setState(() => isSaving = false);
                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ref.invalidate(
                                  patientLabTestsProvider(patient.id!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Analyse créée avec succès'),
                                ),
                              );
                            }
                          } else if (result is Failure<LabTestModel>) {
                            setState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditLabTestDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
    LabTestModel test,
  ) async {
    final testNameController = TextEditingController(text: test.testName ?? '');
    final resultController = TextEditingController(text: test.result ?? '');
    final attachments = <PlatformFile>[];
    DateTime? selectedDate = test.testDate;
    int? selectedDoctorId = test.doctorId;
    String status = test.status ?? 'pending';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F1F25) : Colors.white,
              title: const Text('Modifier l\'analyse'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: testNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du test *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: resultController,
                      decoration: const InputDecoration(
                        labelText: 'Résultats (optionnel)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    if (doctorsAsync is AsyncData<Result<List<DoctorModel>>>)
                      doctorsAsync.value.when(
                        success: (docs) => DropdownButtonFormField<int>(
                          value: selectedDoctorId,
                          decoration: const InputDecoration(
                            labelText: 'Médecin (optionnel)',
                          ),
                          items: docs
                              .map(
                                (d) => DropdownMenuItem<int>(
                                  value: d.id,
                                  child:
                                      Text(d.user?.name ?? 'Dr. ${d.id ?? ''}'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedDoctorId = val;
                            });
                          },
                        ),
                        failure: (msg) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Médecins non chargés: $msg',
                            style: TextStyle(
                              color: isDark ? Colors.red[200] : Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      selectedDate = pickedDate;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  selectedDate != null
                                      ? DateFormat('dd/MM/yyyy')
                                          .format(selectedDate!)
                                      : 'Date du test',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                            labelText: 'Statut',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('En attente'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Terminé'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                status = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          attachments.isEmpty
                              ? 'Ajouter des fichiers'
                              : 'Ajouter d’autres fichiers',
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            withData: kIsWeb,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setState(() {
                              attachments.addAll(result.files);
                            });
                          }
                        },
                      ),
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attachments
                              .asMap()
                              .entries
                              .map(
                                (entry) => Chip(
                                  label: Text(
                                    entry.value.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      attachments.removeAt(entry.key);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (testNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Le nom du test est requis'),
                              ),
                            );
                            return;
                          }

                          setState(() => isSaving = true);

                          final service = ref.read(labTestServiceProvider);
                          final payload = {
                            'patient_id': patient.id,
                            if (selectedDoctorId != null)
                              'doctor_id': selectedDoctorId,
                            'test_name': testNameController.text.trim(),
                            'result': resultController.text.trim().isEmpty
                                ? null
                                : resultController.text.trim(),
                            'status': status,
                            'test_date': selectedDate != null
                                ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                                : null,
                          };

                          final result = await service.updateLabTest(
                            test.id!,
                            payload,
                          );

                          if (result is Success<LabTestModel>) {
                            // Upload new attachments if any
                            if (attachments.isNotEmpty) {
                              for (final file in attachments) {
                                if (kIsWeb) {
                                  if (file.bytes == null) continue;
                                  await service.uploadAttachment(
                                    labTestId: result.data.id!,
                                    fileBytes: file.bytes!,
                                    fileName: file.name,
                                    fileType: file.extension,
                                  );
                                } else {
                                  if (file.path == null) continue;
                                  await service.uploadAttachment(
                                    labTestId: result.data.id!,
                                    file: File(file.path!),
                                    fileName: file.name,
                                    fileType: file.extension,
                                  );
                                }
                              }
                            }

                            setState(() => isSaving = false);
                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ref.invalidate(
                                  patientLabTestsProvider(patient.id!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Analyse mise à jour'),
                                ),
                              );
                            }
                          } else if (result is Failure<LabTestModel>) {
                            setState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Mettre à jour'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
