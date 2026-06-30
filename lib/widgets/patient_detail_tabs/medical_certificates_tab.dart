import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/api_constants.dart';
import '../../core/utils/result.dart';
import '../../data/models/certificate_template_model.dart';
import '../../data/models/medical_certificate_model.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/patient_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/certificate_providers.dart';
import '../../providers/doctor_providers.dart';
import '../../providers/api_providers.dart';

class MedicalCertificatesTab extends ConsumerWidget {
  final PatientModel patient;

  const MedicalCertificatesTab({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isAuthorized = authState.user?.isAdmin == 1 ||
        authState.user?.isDoctor == 1 ||
        authState.user?.isReceptionist == 1;

    final certificatesAsync =
        ref.watch(certificatesByPatientProvider(patient.id!));
    final templatesAsync = ref.watch(certificateTemplatesProvider);
    final doctorsAsync = ref.watch(doctorsProvider);

    return certificatesAsync.when(
      data: (result) {
        if (result is Success<List<MedicalCertificateModel>>) {
          final certs = result.data;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(certificatesByPatientProvider(patient.id!));
              await ref.read(certificatesByPatientProvider(patient.id!).future);
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
                                  Icons.description_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Certificats Médicaux',
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
                              ElevatedButton.icon(
                                onPressed: () => _showCreateDialog(
                                  context,
                                  ref,
                                  isDark,
                                  templatesAsync,
                                  doctorsAsync,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Nouveau certificat'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (certs.isEmpty)
                          _emptyState(
                            isDark,
                            context,
                            ref,
                            isAuthorized,
                            templatesAsync,
                            doctorsAsync,
                          )
                        else
                          ...certs.map(
                            (c) => _buildCertificateCard(
                              context,
                              ref,
                              c,
                              isDark,
                              isAuthorized,
                              templatesAsync,
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
        } else if (result is Failure<List<MedicalCertificateModel>>) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(result.message),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString()),
        ),
      ),
    );
  }

  Widget _emptyState(
    bool isDark,
    BuildContext context,
    WidgetRef ref,
    bool isAuthorized,
    AsyncValue<Result<List<CertificateTemplateModel>>> templatesAsync,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun certificat médical trouvé',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            if (isAuthorized)
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(
                  context,
                  ref,
                  isDark,
                  templatesAsync,
                  doctorsAsync,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Créer le premier certificat'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(
    BuildContext context,
    WidgetRef ref,
    MedicalCertificateModel cert,
    bool isDark,
    bool isAuthorized,
    AsyncValue<Result<List<CertificateTemplateModel>>> templatesAsync,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) {
    final title = cert.template?.title ?? 'Certificat médical';
    final dateLabel = cert.createdAt != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(cert.createdAt!)
        : 'Date inconnue';
    final isFinalized = cert.isFinalized == true;
    final doctorName =
        cert.doctor?.user?.name ?? cert.medicalRecord?.doctor?.user?.name;
    final contentPreview = _plainText(cert.content).trim();

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
                      title,
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
                  color: (isFinalized ? Colors.green : Colors.orange)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isFinalized ? Colors.green : Colors.orange)
                        .withOpacity(0.5),
                  ),
                ),
                child: Text(
                  isFinalized ? 'Finalisé' : 'Brouillon',
                  style: TextStyle(
                    color: isFinalized ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _showViewDialog(context, cert),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Voir'),
                  ),
                  if (!isFinalized && isAuthorized)
                    TextButton.icon(
                      onPressed: () => _showEditDialog(
                        context,
                        ref,
                        isDark,
                        cert,
                        templatesAsync,
                        doctorsAsync,
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                    ),
                  if (contentPreview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        contentPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ),
                  if (cert.id != null)
                    TextButton.icon(
                      onPressed: () => _downloadPdfById(ref, cert.id!),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('PDF'),
                    )
                  else if (isAuthorized)
                    TextButton.icon(
                      onPressed: () async {
                        final service = ref.read(certificateServiceProvider);
                        final res = await service.generatePdf(cert.id!);
                        if (context.mounted) {
                          if (res is Success<MedicalCertificateModel>) {
                            ref.invalidate(
                                certificatesByPatientProvider(patient.id!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('PDF généré avec succès')),
                            );
                          } else if (res is Failure<MedicalCertificateModel>) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Générer PDF'),
                    ),
                  if (isAuthorized)
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final service = ref.read(certificateServiceProvider);
                        final res = await service.deleteCertificate(cert.id!);
                        if (context.mounted) {
                          if (res is Success<String>) {
                            ref.invalidate(
                                certificatesByPatientProvider(patient.id!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Certificat supprimé')),
                            );
                          } else if (res is Failure<String>) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdfById(WidgetRef ref, int id) async {
    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      }
    }

    // Ask backend to (re)generate to ensure file exists
    try {
      final service = ref.read(certificateServiceProvider);
      await service.generatePdf(id);
    } catch (_) {
      // ignore; still attempt download
    }

    // Always hit download endpoint so Laravel streams the binary
    final downloadUrl =
        '${ApiConstants.baseUrl}${ApiConstants.certificateDownload(id)}';
    await openUrl(downloadUrl);
  }

  void _showViewDialog(BuildContext context, MedicalCertificateModel cert) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(cert.template?.title ?? 'Certificat médical'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créé le: ${cert.createdAt != null ? DateFormat('dd/MM/yyyy').format(cert.createdAt!) : '—'}',
                ),
                const SizedBox(height: 8),
                Text('Médecin: ${cert.doctor?.user?.name ?? '—'}'),
                const SizedBox(height: 12),
                if (cert.content != null && cert.content!.isNotEmpty)
                  Html(data: cert.content)
                else
                  const Text('Pas de contenu'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _plainText(String? html) {
    if (html == null) return '';
    final stripped = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _extractVariables(String html) {
    final regex = RegExp(r'\{\{([^}]+)\}\}');
    final matches = regex.allMatches(html);
    final vars = <String>{};
    for (final m in matches) {
      final name = m.group(1)?.trim();
      if (name != null && name.isNotEmpty) vars.add(name);
    }
    return vars.toList();
  }

  Map<String, String> _prefillVariables(
    String html,
    PatientModel patient,
    int? doctorId,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) {
    final keys = _extractVariables(html);
    final result = <String, String>{};

    String? doctorName;
    final doctorsVal = doctorsAsync.value;
    if (doctorId != null && doctorsVal is Success<List<DoctorModel>>) {
      final doc = doctorsVal.data
          .firstWhere((d) => d.id == doctorId, orElse: () => DoctorModel());
      doctorName = doc.user?.name;
    }

    for (final k in keys) {
      switch (k) {
        case 'nom_medecin':
          result[k] = doctorName ?? '';
          break;
        case 'nom_patient':
          result[k] = patient.user?.name ?? '';
          break;
        case 'date_naissance_patient':
          result[k] = patient.birthdate ?? '';
          break;
        case 'cni_patient':
          result[k] = patient.cniNumber ?? '';
          break;
        case 'ville':
          result[k] = '';
          break;
        default:
          result[k] = '';
      }
    }
    return result;
  }

  String _applyVariables(String html, Map<String, String> values) {
    var out = html;
    values.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }

  int? _firstDoctorId(AsyncValue<Result<List<DoctorModel>>> doctorsAsync) {
    final value = doctorsAsync.value;
    if (value is Success<List<DoctorModel>>) {
      if (value.data.isNotEmpty) return value.data.first.id;
    }
    return null;
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AsyncValue<Result<List<CertificateTemplateModel>>> templatesAsync,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) async {
    final service = ref.read(certificateServiceProvider);
    final templateCtrl = ValueNotifier<int?>(null);
    final doctorCtrl = ValueNotifier<int?>(null);
    final contentCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final varsCtrl = ValueNotifier<Map<String, String>>({});
    String priority = 'normal';
    bool saving = false;
    bool showHtmlEditor = false;
    bool doctorInitialized = false;
    bool varsInitialized = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Initialize default doctor once when data is available
            if (!doctorInitialized) {
              final defaultDocId = _firstDoctorId(doctorsAsync);
              if (defaultDocId != null) {
                doctorCtrl.value = defaultDocId;
                doctorInitialized = true;
              }
            }

            void applyTemplate(int? id) {
              if (id == null) return;
              final value = templatesAsync.value;
              if (value is Success<List<CertificateTemplateModel>>) {
                final tpl = value.data.firstWhere(
                  (t) => t.id == id,
                  orElse: () =>
                      CertificateTemplateModel(id: id, title: '', content: ''),
                );
                contentCtrl.text = tpl.content ?? '';
                varsCtrl.value = _prefillVariables(
                    tpl.content ?? '', patient, doctorCtrl.value, doctorsAsync);
                setState(() {});
                varsInitialized = true;
              }
            }

            // If a template is already selected and variables not yet initialized, prefill
            if (!varsInitialized && templateCtrl.value != null) {
              applyTemplate(templateCtrl.value);
              setState(() {});
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F1F25) : Colors.white,
              title: const Text('Nouveau certificat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _templateDropdown(
                      templatesAsync,
                      templateCtrl,
                      onChanged: (v) {
                        templateCtrl.value = v;
                        applyTemplate(v);
                      },
                    ),
                    const SizedBox(height: 12),
                    _doctorDropdown(
                      doctorsAsync,
                      doctorCtrl,
                      onChanged: (v) {
                        doctorCtrl.value = v;
                        if (templateCtrl.value != null) {
                          varsCtrl.value = _prefillVariables(
                            contentCtrl.text,
                            patient,
                            doctorCtrl.value,
                            doctorsAsync,
                          );
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priorité'),
                      items: const [
                        DropdownMenuItem(value: 'high', child: Text('Haute')),
                        DropdownMenuItem(
                            value: 'normal', child: Text('Normale')),
                        DropdownMenuItem(value: 'low', child: Text('Basse')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => priority = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Render HTML preview + optional raw editor toggle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contentCtrl.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isDark ? Colors.white24 : Colors.grey[300]!,
                              ),
                            ),
                            child: Html(
                              data: contentCtrl.text,
                              style: {
                                "body": Style(
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                  fontSize: FontSize.medium,
                                  color: isDark
                                      ? Colors.grey[200]
                                      : Colors.grey[800],
                                ),
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(
                                () => showHtmlEditor = !showHtmlEditor),
                            icon: Icon(
                              showHtmlEditor
                                  ? Icons.visibility_off
                                  : Icons.edit_note,
                              size: 18,
                            ),
                            label: Text(
                              showHtmlEditor
                                  ? 'Masquer le code HTML'
                                  : 'Modifier le contenu (HTML)',
                            ),
                          ),
                        ),
                        if (showHtmlEditor)
                          TextField(
                            controller: contentCtrl,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Contenu (HTML)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<Map<String, String>>(
                      valueListenable: varsCtrl,
                      builder: (_, vars, __) {
                        final keys = _extractVariables(contentCtrl.text);
                        if (keys.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune, size: 16),
                                const SizedBox(width: 6),
                                Text('Variables du modèle (${keys.length})',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[800])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...keys.map(
                              (k) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: TextEditingController(
                                      text: vars[k] ?? ''),
                                  onChanged: (val) {
                                    final updated =
                                        Map<String, String>.from(vars);
                                    updated[k] = val;
                                    varsCtrl.value = updated;
                                  },
                                  decoration: InputDecoration(
                                    labelText: k,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (templateCtrl.value == null ||
                              doctorCtrl.value == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Sélectionnez un modèle et un médecin')),
                            );
                            return;
                          }
                          setState(() => saving = true);
                          final body = {
                            'patient_id': patient.id,
                            'template_id': templateCtrl.value,
                            'doctor_id': doctorCtrl.value,
                            'content': _applyVariables(
                              contentCtrl.text.trim(),
                              varsCtrl.value,
                            ),
                            'priority': priority,
                            'notes': notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                          };
                          final res = await service.createCertificate(body);
                          setState(() => saving = false);
                          if (res is Success<MedicalCertificateModel>) {
                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ref.invalidate(
                                  certificatesByPatientProvider(patient.id!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Certificat créé')),
                              );
                            }
                          } else if (res is Failure<MedicalCertificateModel>) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    MedicalCertificateModel cert,
    AsyncValue<Result<List<CertificateTemplateModel>>> templatesAsync,
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
  ) async {
    final service = ref.read(certificateServiceProvider);
    final templateCtrl = ValueNotifier<int?>(cert.templateId);
    final doctorCtrl = ValueNotifier<int?>(cert.doctorId);
    final contentCtrl = TextEditingController(text: cert.content ?? '');
    final notesCtrl = TextEditingController(text: cert.notes ?? '');
    final varsCtrl = ValueNotifier<Map<String, String>>(_prefillVariables(
        cert.content ?? '', patient, cert.doctorId, doctorsAsync));
    String priority = cert.priority ?? 'normal';
    bool saving = false;
    bool showHtmlEditor = false;
    bool doctorInitialized = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Initialize doctor if missing
            if (!doctorInitialized && doctorCtrl.value == null) {
              final defaultDocId = _firstDoctorId(doctorsAsync);
              if (defaultDocId != null) {
                doctorCtrl.value = defaultDocId;
              }
              doctorInitialized = true;
            }

            void applyTemplate(int? id) {
              if (id == null) return;
              final value = templatesAsync.value;
              if (value is Success<List<CertificateTemplateModel>>) {
                final tpl = value.data.firstWhere(
                  (t) => t.id == id,
                  orElse: () =>
                      CertificateTemplateModel(id: id, title: '', content: ''),
                );
                contentCtrl.text = tpl.content ?? '';
                varsCtrl.value = _prefillVariables(
                    tpl.content ?? '', patient, doctorCtrl.value, doctorsAsync);
                setState(() {});
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F1F25) : Colors.white,
              title: const Text('Modifier le certificat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _templateDropdown(
                      templatesAsync,
                      templateCtrl,
                      onChanged: (v) {
                        templateCtrl.value = v;
                        applyTemplate(v);
                      },
                      initial: cert.templateId,
                    ),
                    const SizedBox(height: 12),
                    _doctorDropdown(
                      doctorsAsync,
                      doctorCtrl,
                      initial: cert.doctorId,
                      onChanged: (v) {
                        doctorCtrl.value = v;
                        if (templateCtrl.value != null) {
                          varsCtrl.value = _prefillVariables(
                            contentCtrl.text,
                            patient,
                            doctorCtrl.value,
                            doctorsAsync,
                          );
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priorité'),
                      items: const [
                        DropdownMenuItem(value: 'high', child: Text('Haute')),
                        DropdownMenuItem(
                            value: 'normal', child: Text('Normale')),
                        DropdownMenuItem(value: 'low', child: Text('Basse')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => priority = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contentCtrl.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isDark ? Colors.white24 : Colors.grey[300]!,
                              ),
                            ),
                            child: Html(
                              data: contentCtrl.text,
                              style: {
                                "body": Style(
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                  fontSize: FontSize.medium,
                                  color: isDark
                                      ? Colors.grey[200]
                                      : Colors.grey[800],
                                ),
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(
                                () => showHtmlEditor = !showHtmlEditor),
                            icon: Icon(
                              showHtmlEditor
                                  ? Icons.visibility_off
                                  : Icons.edit_note,
                              size: 18,
                            ),
                            label: Text(
                              showHtmlEditor
                                  ? 'Masquer le code HTML'
                                  : 'Modifier le contenu (HTML)',
                            ),
                          ),
                        ),
                        if (showHtmlEditor)
                          TextField(
                            controller: contentCtrl,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Contenu (HTML)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<Map<String, String>>(
                      valueListenable: varsCtrl,
                      builder: (_, vars, __) {
                        final keys = _extractVariables(contentCtrl.text);
                        if (keys.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune, size: 16),
                                const SizedBox(width: 6),
                                Text('Variables du modèle (${keys.length})',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[800])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...keys.map(
                              (k) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: TextEditingController(
                                      text: vars[k] ?? ''),
                                  onChanged: (val) {
                                    final updated =
                                        Map<String, String>.from(vars);
                                    updated[k] = val;
                                    varsCtrl.value = updated;
                                  },
                                  decoration: InputDecoration(
                                    labelText: k,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (templateCtrl.value == null ||
                              doctorCtrl.value == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Sélectionnez un modèle et un médecin')),
                            );
                            return;
                          }
                          setState(() => saving = true);
                          final body = {
                            'template_id': templateCtrl.value,
                            'doctor_id': doctorCtrl.value,
                            'content': _applyVariables(
                              contentCtrl.text.trim(),
                              varsCtrl.value,
                            ),
                            'priority': priority,
                            'notes': notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                          };
                          final res =
                              await service.updateCertificate(cert.id!, body);
                          setState(() => saving = false);
                          if (res is Success<MedicalCertificateModel>) {
                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ref.invalidate(
                                  certificatesByPatientProvider(patient.id!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Certificat mis à jour')),
                              );
                            }
                          } else if (res is Failure<MedicalCertificateModel>) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Mettre à jour'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _templateDropdown(
    AsyncValue<Result<List<CertificateTemplateModel>>> templatesAsync,
    ValueNotifier<int?> controller, {
    void Function(int?)? onChanged,
    int? initial,
  }) {
    return templatesAsync.when(
      data: (result) {
        if (result is Success<List<CertificateTemplateModel>>) {
          final items = result.data;
          return DropdownButtonFormField<int>(
            value: initial ?? controller.value,
            decoration: const InputDecoration(labelText: 'Modèle'),
            items: items
                .map((t) => DropdownMenuItem<int>(
                      value: t.id,
                      child: Text(t.title ?? 'Modèle ${t.id}'),
                    ))
                .toList(),
            onChanged: onChanged,
          );
        } else if (result is Failure<List<CertificateTemplateModel>>) {
          return Text('Erreur: ${result.message}');
        }
        return const SizedBox.shrink();
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(e.toString()),
    );
  }

  Widget _doctorDropdown(
    AsyncValue<Result<List<DoctorModel>>> doctorsAsync,
    ValueNotifier<int?> controller, {
    int? initial,
    void Function(int?)? onChanged,
  }) {
    return doctorsAsync.when(
      data: (result) {
        if (result is Success<List<DoctorModel>>) {
          final items = result.data;
          return DropdownButtonFormField<int>(
            value: initial ?? controller.value,
            decoration: const InputDecoration(labelText: 'Médecin'),
            items: items
                .map(
                  (d) => DropdownMenuItem<int>(
                    value: d.id,
                    child: Text(d.user?.name ?? 'Dr. ${d.id ?? ''}'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              controller.value = v;
              if (onChanged != null) onChanged(v);
            },
          );
        } else if (result is Failure<List<DoctorModel>>) {
          return Text('Erreur médecins: ${result.message}');
        }
        return const SizedBox.shrink();
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(e.toString()),
    );
  }
}
