// lib/screens/prescriptions_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config/api_constants.dart';
import '../data/models/prescription_model.dart';
import '../providers/prescription_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/locale_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';
import '../l10n/app_localizations.dart';
import '../utils/web_download_helper.dart';
import 'create_prescription_screen.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _activeTab = 'all';
  String _sortOrder = 'asc';
  PrescriptionModel? _selectedPrescription;
  PrescriptionModel? _prescriptionToDelete;

  late TabController _tabController;

  DateFormat _getDateFormatter(BuildContext context) {
    final locale = ref.watch(localeProvider).locale;
    return DateFormat('dd MMM yyyy', locale.toString());
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = ['all', 'upcoming', 'past'][_tabController.index];
        });
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(prescriptionListFiltersProvider.notifier).setSearch(
              _searchController.text.isEmpty ? null : _searchController.text,
            );
      }
    });
  }

  String _formatDate(String? dateString, {bool isBirthdate = false}) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      if (date.year < 1900) return 'Invalid date';

      final formattedDate = _getDateFormatter(context).format(date);

      if (isBirthdate) {
        final today = DateTime.now();
        int age = today.year - date.year;
        final monthDiff = today.month - date.month;
        if (monthDiff < 0 || (monthDiff == 0 && today.day < date.day)) {
          age--;
        }
        return '$formattedDate (${age} years)';
      }

      final today = DateTime.now();
      final diffTime = date.difference(today);
      final diffDays = diffTime.inDays;
      final diffMonths = (diffDays / 30.42).round();

      final localizations = AppLocalizations.of(context);
      String relativeTime = '';
      if (diffDays == 0) {
        relativeTime = localizations?.today ?? 'today';
      } else if (diffDays > 0) {
        if (diffDays < 30) {
          relativeTime =
              diffDays == 1 ? 'in $diffDays day' : 'in $diffDays days';
        } else {
          relativeTime = diffMonths == 1
              ? 'in $diffMonths month'
              : 'in $diffMonths months';
        }
      } else {
        final absDiffDays = diffDays.abs();
        if (absDiffDays < 30) {
          relativeTime = absDiffDays == 1
              ? '$absDiffDays day ago'
              : '$absDiffDays days ago';
        } else {
          relativeTime = diffMonths.abs() == 1
              ? '${diffMonths.abs()} month ago'
              : '${diffMonths.abs()} months ago';
        }
      }

      return '$formattedDate ($relativeTime)';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _handleSortByDate() {
    setState(() {
      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
    });
  }

  List<PrescriptionModel> _filterPrescriptions(
      List<PrescriptionModel> prescriptions) {
    final today = DateTime.now();
    return prescriptions.where((prescription) {
      if (_activeTab == 'all') return true;
      final followUpDate = prescription.followUpDate != null
          ? DateTime.tryParse(prescription.followUpDate!)
          : null;
      if (followUpDate == null) return false;
      return _activeTab == 'upcoming'
          ? followUpDate.isAfter(today)
          : followUpDate.isBefore(today);
    }).toList()
      ..sort((a, b) {
        final dateA = a.followUpDate != null
            ? DateTime.tryParse(a.followUpDate!) ?? DateTime(1900)
            : DateTime(1900);
        final dateB = b.followUpDate != null
            ? DateTime.tryParse(b.followUpDate!) ?? DateTime(1900)
            : DateTime(1900);
        return _sortOrder == 'asc'
            ? dateA.compareTo(dateB)
            : dateB.compareTo(dateA);
      });
  }

  void _handleViewPrescription(PrescriptionModel prescription) {
    setState(() {
      _selectedPrescription = prescription;
    });
    _showViewDialog();
  }

  void _showViewDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildViewDialog(),
    );
  }

  Future<void> _downloadPrescriptionPDF(PrescriptionModel prescription) async {
    String? url;

    // Priority 1: Use pdf_url from API (secure download endpoint)
    if (prescription.pdfUrl != null && prescription.pdfUrl!.isNotEmpty) {
      url = prescription.pdfUrl;
    }
    // Priority 2: Check if pdfPath is already a full URL (Backblaze direct URL)
    else if (prescription.pdfPath != null &&
        (prescription.pdfPath!.startsWith('http://') ||
            prescription.pdfPath!.startsWith('https://'))) {
      url = prescription.pdfPath;
    }
    // Priority 3: Use secure API endpoint if we have prescription ID
    else if (prescription.id != null) {
      url =
          '${ApiConstants.baseUrl}${ApiConstants.prescriptionPdf(prescription.id!)}';
    }
    // Priority 4: Fallback to storage URL (may not work with Backblaze)
    else if (prescription.pdfPath != null && prescription.pdfPath!.isNotEmpty) {
      final cleanPath = prescription.pdfPath!.startsWith('/')
          ? prescription.pdfPath!.substring(1)
          : prescription.pdfPath!;
      url = '${ApiConstants.storageBaseUrl}/storage/$cleanPath';
    }

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available')),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          backgroundColor: Colors.transparent,
          child: Center(child: CircularProgressIndicator()),
        ),
      );

      // Get auth token
      final authState = ref.read(authProvider);
      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the file
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        String fileName =
            'ordonnance_${prescription.id ?? DateTime.now().millisecondsSinceEpoch}.pdf';

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
                  content: Text('PDF downloaded: $fileName'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Download error: ${e.toString()}')),
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
                text: 'Ordonnance #${prescription.id ?? "PDF"}',
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
                        text: 'Ordonnance #${prescription.id ?? "PDF"}',
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
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _openDeleteDialog(PrescriptionModel prescription) {
    setState(() {
      _prescriptionToDelete = prescription;
    });
    _showDeleteDialog();
  }

  void _showDeleteDialog() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content:
            const Text('Are you sure you want to delete this prescription?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _prescriptionToDelete = null;
              });
            },
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_prescriptionToDelete == null) return;

              Navigator.pop(context);
              final deleteResult = await ref.read(
                deletePrescriptionProvider(_prescriptionToDelete!.id!).future,
              );

              if (!mounted) return;

              deleteResult.when(
                success: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            const Text('Prescription deleted successfully')),
                  );
                  setState(() {
                    _prescriptionToDelete = null;
                  });
                  ref.invalidate(prescriptionListProvider);
                },
                failure: (message) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                },
              );
            },
            child: Text(localizations?.delete ?? 'Delete',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale provider to rebuild when language changes
    ref.watch(localeProvider);
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final filters = ref.watch(prescriptionListFiltersProvider);
    final prescriptionsAsync = ref.watch(prescriptionListProvider(filters));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width > 600 && size.width < 1024;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context, authState, isDesktop),
          ];
        },
        body: Column(
          children: [
            // Time Range Filter
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: ['day', 'month', 'all'].map((range) {
                  final labels = {
                    'day': localizations?.day ?? 'Day',
                    'month': localizations?.month ?? 'Month',
                    'all': localizations?.all ?? 'All'
                  };
                  final isSelected = filters.timeRange == range;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(labels[range]!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(prescriptionListFiltersProvider.notifier)
                              .setTimeRange(range);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            // Search and Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: localizations?.search ?? 'Search',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (authState.user != null &&
                      (authState.user!.isAdmin == 1 ||
                          authState.user!.isDoctor == 1))
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreatePrescriptionScreen(),
                            ),
                          ).then((_) {
                            ref.invalidate(prescriptionListProvider);
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: Text(localizations?.newPrescription ?? 'New'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: localizations?.all ?? 'All'),
                Tab(text: localizations?.upcoming ?? 'Upcoming'),
                Tab(text: localizations?.past ?? 'Past'),
              ],
            ),
            // Content
            Expanded(
              child: prescriptionsAsync.when(
                data: (result) {
                  return result.when(
                    failure: (message) => Center(
                      child: CustomErrorWidget(
                        message: message,
                        onRetry: () =>
                            ref.refresh(prescriptionListProvider(filters)),
                      ),
                    ),
                    success: (response) {
                      final filtered =
                          _filterPrescriptions(response.prescriptions);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_liquid_rounded,
                                size: 64,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localizations?.noData ?? 'No data available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              if (authState.user != null &&
                                  (authState.user!.isAdmin == 1 ||
                                      authState.user!.isDoctor == 1))
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CreatePrescriptionScreen(),
                                        ),
                                      ).then((_) {
                                        ref.invalidate(
                                            prescriptionListProvider);
                                      });
                                    },
                                    child: Text(
                                        localizations?.createPrescription ??
                                            'Create Prescription'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: isDesktop || isTablet
                                ? _buildDesktopTable(filtered, isDark)
                                : _buildMobileList(filtered, isDark),
                          ),
                          if (response.hasPagination)
                            _buildPagination(response, filters),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: LoadingWidget()),
                error: (error, stack) => Center(
                  child: CustomErrorWidget(
                    message: error.toString(),
                    onRetry: () =>
                        ref.refresh(prescriptionListProvider(filters)),
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
  ) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        localizations?.prescriptions ?? 'Prescriptions',
        style: TextStyle(
          fontSize: isDesktop ? 28 : 24,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.grey[800],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.refresh(prescriptionListProvider(
            ref.read(prescriptionListFiltersProvider),
          )),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(
      List<PrescriptionModel> prescriptions, bool isDark) {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(2),
          5: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            children: [
              _buildTableHeader(localizations?.patients ?? 'Patient', isDark),
              _buildTableHeader('Phone', isDark),
              _buildTableHeader(
                  localizations?.diagnosis ?? 'Diagnosis', isDark),
              _buildTableHeader(
                'Follow-up',
                isDark,
                onTap: _handleSortByDate,
                showSort: true,
              ),
              _buildTableHeader(
                  localizations?.medications ?? 'Medications', isDark),
              _buildTableHeader('Actions', isDark, alignRight: true),
            ],
          ),
          ...prescriptions.map((prescription) =>
              _buildTableRow(prescription, isDark, localizations)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, bool isDark,
      {VoidCallback? onTap, bool showSort = false, bool alignRight = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            if (showSort)
              Icon(
                Icons.swap_vert,
                size: 16,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(PrescriptionModel prescription, bool isDark,
      AppLocalizations? localizations) {
    final patient = prescription.medicalRecord?.patient;
    final patientName = patient?.user?.name ?? 'N/A';
    final phone = patient?.phoneNumber ?? 'N/A';
    final diagnosis = prescription.medicalRecord?.diagnosis ?? 'N/A';
    final followUpDate = prescription.followUpDate;
    final medications = prescription.medications ?? [];

    final followUpDateTime =
        followUpDate != null ? DateTime.tryParse(followUpDate) : null;
    final isUpcoming =
        followUpDateTime != null && followUpDateTime.isAfter(DateTime.now());
    final isUrgent = followUpDate != null &&
        (() {
          final date = DateTime.tryParse(followUpDate);
          if (date == null) return false;
          final diff = date.difference(DateTime.now()).inDays;
          return diff >= 0 && diff <= 3;
        })();

    return TableRow(
      children: [
        _buildTableCell(patientName, isDark),
        _buildTableCell(phone, isDark),
        _buildTableCell(diagnosis, isDark),
        _buildTableCell(
          followUpDate != null ? _formatDate(followUpDate) : 'N/A',
          isDark,
          color: isUpcoming ? Colors.green : Colors.orange,
          badge: isUrgent ? 'Urgent' : null,
        ),
        _buildTableCell(
          medications.length > 2
              ? '${medications.take(2).map((m) => m.medication?.nom ?? 'N/A').join(', ')} +${medications.length - 2}'
              : medications.map((m) => m.medication?.nom ?? 'N/A').join(', '),
          isDark,
        ),
        _buildTableCell(
          '',
          isDark,
          widget: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _handleViewPrescription(prescription),
                tooltip: 'View',
              ),
              if (prescription.pdfPath != null &&
                  prescription.pdfPath!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  onPressed: () => _downloadPrescriptionPDF(prescription),
                  tooltip: localizations?.downloadPdf ?? 'Download PDF',
                ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _openDeleteDialog(prescription),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String text, bool isDark,
      {Color? color, String? badge, Widget? widget}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: widget ??
          Row(
            children: [
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color:
                        color ?? (isDark ? Colors.white70 : Colors.grey[800]),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Chip(
                    label: Text(badge, style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.red[100],
                    labelStyle: const TextStyle(color: Colors.red),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildMobileList(List<PrescriptionModel> prescriptions, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = prescriptions[index];
        return _buildPrescriptionCard(prescription, isDark);
      },
    );
  }

  Widget _buildPrescriptionCard(PrescriptionModel prescription, bool isDark) {
    final patient = prescription.medicalRecord?.patient;
    final patientName = patient?.user?.name ?? 'N/A';
    final phone = patient?.phoneNumber ?? 'N/A';
    final diagnosis = prescription.medicalRecord?.diagnosis ?? 'N/A';
    final followUpDate = prescription.followUpDate;
    final medications = prescription.medications ?? [];

    final followUpDateTime =
        followUpDate != null ? DateTime.tryParse(followUpDate) : null;
    final isUpcoming =
        followUpDateTime != null && followUpDateTime.isAfter(DateTime.now());
    final isUrgent = followUpDate != null &&
        (() {
          final date = DateTime.tryParse(followUpDate);
          if (date == null) return false;
          final diff = date.difference(DateTime.now()).inDays;
          return diff >= 0 && diff <= 3;
        })();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        phone,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => _handleViewPrescription(prescription),
                    ),
                    if (prescription.pdfPath != null &&
                        prescription.pdfPath!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        onPressed: () => _downloadPrescriptionPDF(prescription),
                      ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _openDeleteDialog(prescription),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Text(
                '${AppLocalizations.of(context)?.diagnosis ?? 'Diagnosis'}: $diagnosis'),
            if (followUpDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isUpcoming ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(followUpDate),
                    style: TextStyle(
                      color: isUpcoming ? Colors.green : Colors.orange,
                    ),
                  ),
                  if (isUrgent)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Chip(
                        label: const Text('Urgent',
                            style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.red[100],
                        labelStyle: const TextStyle(color: Colors.red),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
            if (medications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: medications.take(3).map((med) {
                  return Chip(
                    label: Text(
                      med.medication?.nom ?? 'N/A',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue[100],
                    labelStyle: TextStyle(color: Colors.blue[800]),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList()
                  ..addIf(
                    medications.length > 3,
                    Chip(
                      label: Text(
                        '+${medications.length - 3}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(dynamic response, PrescriptionListFilters filters) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: response.currentPage > 1
                ? () => ref
                    .read(prescriptionListFiltersProvider.notifier)
                    .goToPreviousPage()
                : null,
            child: const Text('Previous'),
          ),
          Text(
            'Page ${response.currentPage} of ${response.lastPage}',
            style: const TextStyle(fontSize: 16),
          ),
          ElevatedButton(
            onPressed: response.currentPage < response.lastPage
                ? () => ref
                    .read(prescriptionListFiltersProvider.notifier)
                    .goToNextPage(response.lastPage)
                : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewDialog() {
    if (_selectedPrescription == null) return const SizedBox.shrink();

    final localizations = AppLocalizations.of(context);
    final prescription = _selectedPrescription!;
    final patient = prescription.medicalRecord?.patient;
    final medicalRecord = prescription.medicalRecord;
    final medications = prescription.medications ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_liquid,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localizations?.prescriptions ?? 'Prescription'} Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: #${prescription.id ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedPrescription = null;
                      });
                    },
                    tooltip: localizations?.close ?? 'Close',
                  ),
                ],
              ),
            ),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Info Card
                    _buildInfoCard(
                      context: context,
                      title: localizations?.patientInformation ??
                          'Patient Information',
                      icon: Icons.person,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: localizations?.name ?? 'Name',
                          value: patient?.user?.name ?? 'N/A',
                          isDark: isDark,
                        ),
                        _buildInfoRow(
                          icon: Icons.wc,
                          label: localizations?.gender ?? 'Gender',
                          value: patient?.gender ?? 'N/A',
                          isDark: isDark,
                        ),
                        _buildInfoRow(
                          icon: Icons.cake,
                          label: localizations?.birthDate ?? 'Birthdate',
                          value: _formatDate(patient?.birthdate,
                              isBirthdate: true),
                          isDark: isDark,
                        ),
                        _buildInfoRow(
                          icon: Icons.badge,
                          label: localizations?.cniNumber ?? 'CNI Number',
                          value: patient?.cniNumber ?? 'N/A',
                          isDark: isDark,
                        ),
                        _buildInfoRow(
                          icon: Icons.phone,
                          label: localizations?.phone ?? 'Phone',
                          value: patient?.phoneNumber ?? 'N/A',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Prescription Details Card
                    _buildInfoCard(
                      context: context,
                      title:
                          '${localizations?.prescriptions ?? 'Prescription'} Details',
                      icon: Icons.description,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: localizations?.createdOn ?? 'Created On',
                          value: _formatDate(
                              prescription.createdAt?.toIso8601String()),
                          isDark: isDark,
                        ),
                        _buildInfoRow(
                          icon: Icons.event_available,
                          label:
                              localizations?.followUpDate ?? 'Follow-up Date',
                          value: prescription.followUpDate != null
                              ? _formatDate(prescription.followUpDate)
                              : 'N/A',
                          isDark: isDark,
                        ),
                        if (prescription.pdfPath != null &&
                                prescription.pdfPath!.isNotEmpty ||
                            prescription.pdfUrl != null &&
                                prescription.pdfUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _downloadPrescriptionPDF(prescription),
                              icon:
                                  const Icon(Icons.download_rounded, size: 20),
                              label: Text(
                                  localizations?.downloadPdf ?? 'Download PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Medical Record Card
                    _buildInfoCard(
                      context: context,
                      title: localizations?.medicalRecords ?? 'Medical Record',
                      icon: Icons.medical_services,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      children: [
                        _buildInfoRow(
                          icon: Icons.sick,
                          label: 'Symptoms',
                          value: medicalRecord?.symptoms ?? 'N/A',
                          isDark: isDark,
                          isMultiline: true,
                        ),
                        _buildInfoRow(
                          icon: Icons.assignment,
                          label: localizations?.diagnosis ?? 'Diagnosis',
                          value: medicalRecord?.diagnosis ?? 'N/A',
                          isDark: isDark,
                          isMultiline: true,
                        ),
                        _buildInfoRow(
                          icon: Icons.healing,
                          label: 'Treatment',
                          value: medicalRecord?.treatment ?? 'N/A',
                          isDark: isDark,
                          isMultiline: true,
                        ),
                        if (prescription.notes != null &&
                            prescription.notes!.isNotEmpty)
                          _buildInfoRow(
                            icon: Icons.note,
                            label:
                                localizations?.notesAndObservations ?? 'Notes',
                            value: prescription.notes ?? 'N/A',
                            isDark: isDark,
                            isMultiline: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Medications Card
                    _buildInfoCard(
                      context: context,
                      title: localizations?.medications ?? 'Medications',
                      icon: Icons.medication,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      children: [
                        if (medications.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No medications',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[200]!,
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  isDark ? Colors.grey[700] : Colors.grey[100],
                                ),
                                dataRowMinHeight: 50,
                                dataRowMaxHeight: 100,
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Medication',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Dosage',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Frequency',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Duration',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Refills',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Notes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                ],
                                rows: medications.map((med) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              med.medication?.nom ?? 'N/A',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.grey[900],
                                              ),
                                            ),
                                            if (med.medication?.dci1 != null)
                                              Text(
                                                med.medication!.dci1!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(
                                        med.dosage ?? 'N/A',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      )),
                                      DataCell(Text(
                                        med.frequency ?? 'N/A',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      )),
                                      DataCell(Text(
                                        med.duration ?? 'N/A',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      )),
                                      DataCell(Text(
                                        '${med.refills ?? 0}',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      )),
                                      DataCell(Text(
                                        med.notes ?? 'N/A',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50]!,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedPrescription = null;
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(localizations?.close ?? 'Close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 22),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon,
              size: 18, color: isDark ? Colors.white70 : Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension ListExtension<T> on List<T> {
  void addIf(bool condition, T item) {
    if (condition) add(item);
  }
}
