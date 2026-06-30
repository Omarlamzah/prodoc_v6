// lib/screens/medical_records_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/utils/result.dart';
import '../data/models/medical_record_model.dart';
import '../data/models/patient_model.dart';
import '../providers/medical_record_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/patient_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/loading_widget.dart';
import 'medical_record_detail_screen.dart';
import 'create_medical_record_screen.dart';

class MedicalRecordsScreen extends ConsumerStatefulWidget {
  final int? patientId;

  const MedicalRecordsScreen({super.key, this.patientId});

  @override
  ConsumerState<MedicalRecordsScreen> createState() =>
      _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController _cniController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  bool _showFilters = false;
  bool _isSearchingPatients = false;
  List<dynamic> _foundPatients = [];

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(medicalRecordListStateProvider.notifier).updateFilter(
              patientId: widget.patientId,
            );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _patientSearchController.dispose();
    _cniController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _foundPatients = [];
        _isSearchingPatients = false;
      });
      return;
    }

    setState(() => _isSearchingPatients = true);

    try {
      final result = await ref.read(findPatientsProvider(query).future);
      if (mounted) {
        setState(() {
          if (result is Success<List<PatientModel>>) {
            _foundPatients = result.data
                .map((p) => {
                      'id': p.id,
                      'user': {
                        'name': p.user?.name,
                        'email': p.user?.email,
                      }
                    })
                .toList();
          } else {
            _foundPatients = [];
          }
          _isSearchingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foundPatients = [];
          _isSearchingPatients = false;
        });
      }
    }
  }

  void _applyFilters() {
    ref.read(medicalRecordListStateProvider.notifier).updateFilter(
          globalSearch: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          cniNumber: _cniController.text.trim().isEmpty
              ? null
              : _cniController.text.trim(),
          date: _dateController.text.trim().isEmpty
              ? null
              : _dateController.text.trim(),
        );
  }

  void _clearFilters() {
    _searchController.clear();
    _patientSearchController.clear();
    _cniController.clear();
    _dateController.clear();
    setState(() {
      _foundPatients = [];
    });
    ref.read(medicalRecordListStateProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final listState = ref.watch(medicalRecordListStateProvider);
    final recordsAsync = ref.watch(medicalRecordListProvider(listState));
    final isAuthorized = authState.user?.isAdmin == 1 ||
        authState.user?.isDoctor == 1 ||
        authState.user?.isReceptionist == 1;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            final isPatient = authState.user?.isPatient == 1;
            return Text(
              widget.patientId != null
                  ? 'Patient Medical Records'
                  : (isPatient
                      ? (localizations?.medicalRecords ?? 'My Medical Records')
                      : (localizations?.medicalRecords ?? 'Medical Records')),
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
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          if (isAuthorized)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateMedicalRecordScreen(
                      patientId: widget.patientId,
                    ),
                  ),
                ).then((_) {
                  ref.invalidate(medicalRecordListProvider(listState));
                });
              },
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Container(
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
            // Search Bar (Always visible)
            _buildSearchBar(isDark, primaryColor),
            if (_showFilters) _buildFiltersSection(isDark),
            Expanded(
              child: recordsAsync.when(
                data: (result) {
                  if (result is Success<List<MedicalRecordModel>>) {
                    final records = result.data;
                    if (records.isEmpty) {
                      return _buildEmptyState(isDark);
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(medicalRecordListProvider(listState));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          return _buildModernRecordCard(
                              records[index], isDark, primaryColor);
                        },
                      ),
                    );
                  } else if (result is Failure<List<MedicalRecordModel>>) {
                    return _buildErrorState(result.message, isDark);
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const LoadingWidget(),
                error: (error, stack) =>
                    _buildErrorState(error.toString(), isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color primaryColor) {
    final localizations = AppLocalizations.of(context);
    return Container(
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: localizations?.searchByPatient ??
              'Search by patient, diagnosis, symptoms...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.poppins(),
        onChanged: (value) {
          setState(() {});
          if (value.length > 2) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _applyFilters();
              }
            });
          } else if (value.isEmpty) {
            _applyFilters();
          }
        },
        onSubmitted: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildFiltersSection(bool isDark) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final isAuthorized = authState.user?.isAdmin == 1 ||
        authState.user?.isDoctor == 1 ||
        authState.user?.isReceptionist == 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                localizations?.searchFilters ?? 'Search Filters',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Patient Search (only for non-patients)
          if (isAuthorized)
            TextField(
              controller: _patientSearchController,
              decoration: InputDecoration(
                labelText: localizations?.searchPatient ?? 'Search Patient',
                hintText: localizations?.nameEmailOrPhone ??
                    'Name, email or phone...',
                prefixIcon: const Icon(Icons.person_search),
                suffixIcon: _isSearchingPatients
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
              ),
              style: GoogleFonts.poppins(),
              onChanged: (value) {
                _searchPatients(value);
              },
            ),
          if (isAuthorized && _foundPatients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _foundPatients.length,
                itemBuilder: (context, index) {
                  final patient = _foundPatients[index];
                  final name =
                      patient['user']?['name'] ?? 'Patient #${patient['id']}';
                  final email = patient['user']?['email'] ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(name[0].toUpperCase()),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.poppins(),
                    ),
                    subtitle: email.isNotEmpty
                        ? Text(
                            email,
                            style: GoogleFonts.poppins(fontSize: 12),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _patientSearchController.text = name;
                        _foundPatients = [];
                      });
                      ref
                          .read(medicalRecordListStateProvider.notifier)
                          .updateFilter(patientId: patient['id'] as int);
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cniController,
                  decoration: InputDecoration(
                    labelText: localizations?.cniNumber ?? 'CNI Number',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade700 : Colors.grey.shade50,
                  ),
                  style: GoogleFonts.poppins(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: localizations?.date ?? 'Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade700 : Colors.grey.shade50,
                  ),
                  style: GoogleFonts.poppins(),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _dateController.text =
                          DateFormat('yyyy-MM-dd').format(date);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.clear),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.reset ?? 'Reset',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  onPressed: _clearFilters,
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
                  icon: const Icon(Icons.search),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.search ?? 'Search',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
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
    );
  }

  Widget _buildModernRecordCard(
      MedicalRecordModel record, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MedicalRecordDetailScreen(recordId: record.id!),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            'Record #${record.id}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    if (record.createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                final locale = ref.watch(localeProvider).locale;
                                return Text(
                                  DateFormat('dd MMM yyyy', locale.toString())
                                      .format(record.createdAt!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (record.patient != null)
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildInfoRow(
                        Icons.person,
                        localizations?.patients ?? 'Patient',
                        record.patient!.user?.name ??
                            (localizations?.unknownPatient ??
                                'Unknown Patient'),
                        Colors.blue,
                        isDark,
                      );
                    },
                  ),
                if (record.doctor != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildInfoRow(
                        Icons.medical_services,
                        localizations?.doctor ?? 'Doctor',
                        record.doctor!.user?.name ??
                            (localizations?.unknownDoctor ?? 'Unknown Doctor'),
                        Colors.green,
                        isDark,
                      );
                    },
                  ),
                ],
                if (record.specialty != null &&
                    record.specialty!.name != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildInfoRow(
                        Icons.local_hospital,
                        localizations?.specialty ?? 'Specialty',
                        record.specialty!.name!,
                        Colors.purple,
                        isDark,
                      );
                    },
                  ),
                ],
                if (record.diagnosis != null &&
                    record.diagnosis!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.medical_information,
                          size: 20,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Text(
                                    localizations?.diagnosis ?? 'Diagnosis',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.diagnosis!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (record.attachments != null &&
                    record.attachments!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${record.attachments!.length} attachment(s)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange,
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
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                children: [
                  Text(
                    localizations?.noMedicalRecordsFound ??
                        'No Medical Records Found',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations?.tryModifyingSearch ??
                        'Try modifying your search criteria',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
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

  Widget _buildErrorState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Error',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
