import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/result.dart';
import '../data/models/medication_model.dart';
import '../data/models/medication_list_response.dart';
import '../providers/auth_providers.dart';
import '../providers/medication_providers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isEditing = false;
  MedicationModel? _editingMedication;
  MedicationModel? _deletingMedication;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _dci1Controller = TextEditingController();
  final _dosage1Controller = TextEditingController();
  final _uniteDosage1Controller = TextEditingController();
  final _formeController = TextEditingController();
  final _presentationController = TextEditingController();
  final _ppvController = TextEditingController();
  final _phController = TextEditingController();
  final _prixBrController = TextEditingController();
  final _tauxRemboursementController = TextEditingController();
  String? _princepsGenerique;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nomController.dispose();
    _dci1Controller.dispose();
    _dosage1Controller.dispose();
    _uniteDosage1Controller.dispose();
    _formeController.dispose();
    _presentationController.dispose();
    _ppvController.dispose();
    _phController.dispose();
    _prixBrController.dispose();
    _tauxRemboursementController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final searchTerm = _searchController.text.trim();
      final notifier = ref.read(medicationListFiltersProvider.notifier);
      if (searchTerm.isEmpty) {
        notifier.clearSearch();
      } else {
        notifier.setSearch(searchTerm);
      }
    });
  }

  void _resetForm() {
    _nomController.clear();
    _dci1Controller.clear();
    _dosage1Controller.clear();
    _uniteDosage1Controller.clear();
    _formeController.clear();
    _presentationController.clear();
    _ppvController.clear();
    _phController.clear();
    _prixBrController.clear();
    _tauxRemboursementController.clear();
    _princepsGenerique = null;
    _isEditing = false;
    _editingMedication = null;
  }

  void _openCreateDialog() {
    _resetForm();
    showDialog(
      context: context,
      builder: (_) => _buildCreateEditDialog(),
    );
  }

  void _openEditDialog(MedicationModel medication) {
    _nomController.text = medication.nom ?? '';
    _dci1Controller.text = medication.dci1 ?? '';
    _dosage1Controller.text = medication.dosage1 ?? '';
    _uniteDosage1Controller.text = medication.uniteDosage1 ?? '';
    _formeController.text = medication.forme ?? '';
    _presentationController.text = medication.presentation ?? '';
    _ppvController.text = medication.ppv ?? '';
    _phController.text = medication.ph ?? '';
    _prixBrController.text = medication.prixBr ?? '';
    _tauxRemboursementController.text = medication.tauxRemboursement ?? '';
    _princepsGenerique = medication.princepsGenerique;
    setState(() {
      _isEditing = true;
      _editingMedication = medication;
    });
    showDialog(
      context: context,
      builder: (_) => _buildCreateEditDialog(),
    );
  }

  void _openDeleteDialog(MedicationModel medication) {
    setState(() {
      _deletingMedication = medication;
    });
    showDialog(
      context: context,
      builder: (_) => _buildDeleteDialog(),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final medicationService = ref.read(medicationServiceProvider);

    // Helper function to convert empty strings to null
    String? _toNullableString(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final medicationData = <String, dynamic>{
      'NOM': _nomController.text.trim(),
      'DCI1': _toNullableString(_dci1Controller.text),
      'DOSAGE1': _toNullableString(_dosage1Controller.text),
      'UNITE_DOSAGE1': _toNullableString(_uniteDosage1Controller.text),
      'FORME': _toNullableString(_formeController.text),
      'PRESENTATION': _toNullableString(_presentationController.text),
      'PPV': _toNullableString(_ppvController.text),
      'PH': _toNullableString(_phController.text),
      'PRIX_BR': _toNullableString(_prixBrController.text),
      'PRINCEPS_GENERIQUE': _princepsGenerique,
      'TAUX_REMBOURSEMENT':
          _toNullableString(_tauxRemboursementController.text),
    };

    // Remove null values to match API expectations
    medicationData.removeWhere((key, value) => value == null);

    try {
      if (_isEditing && _editingMedication?.code != null) {
        final result = await medicationService.updateMedication(
          code: _editingMedication!.code!,
          medicationData: medicationData,
        );
        result.when(
          success: (_) {
            Navigator.of(context).pop(); // Close dialog
            _showSuccessSnackBar('Medication updated successfully');
            _resetForm();
            ref.refresh(medicationListProvider(
              ref.read(medicationListFiltersProvider),
            ));
          },
          failure: (message) {
            _showErrorSnackBar(message);
          },
        );
      } else {
        final result = await medicationService.createMedication(medicationData);
        result.when(
          success: (_) {
            Navigator.of(context).pop(); // Close dialog
            _showSuccessSnackBar('Medication created successfully');
            _resetForm();
            ref.refresh(medicationListProvider(
              ref.read(medicationListFiltersProvider),
            ));
          },
          failure: (message) {
            _showErrorSnackBar(message);
          },
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _handleDelete() async {
    if (_deletingMedication?.code == null) return;

    final medicationService = ref.read(medicationServiceProvider);
    try {
      final result = await medicationService.deleteMedication(
        _deletingMedication!.code!,
      );
      result.when(
        success: (_) {
          Navigator.of(context).pop(); // Close dialog
          _showSuccessSnackBar('Medication deleted successfully');
          setState(() {
            _deletingMedication = null;
          });
          ref.refresh(medicationListProvider(
            ref.read(medicationListFiltersProvider),
          ));
        },
        failure: (message) {
          _showErrorSnackBar(message);
        },
      );
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final filters = ref.watch(medicationListFiltersProvider);
    final medicationListAsync = ref.watch(medicationListProvider(filters));
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, authState, isDesktop),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: 16,
                ),
                child: _buildSearchSection(context, isDesktop, isTablet),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
              ),
              sliver: medicationListAsync.when(
                data: (result) {
                  if (result is Failure<MedicationListResponse>) {
                    return SliverToBoxAdapter(
                      child: CustomErrorWidget(
                        message: result.message,
                        onRetry: () => ref.refresh(
                          medicationListProvider(filters),
                        ),
                      ),
                    );
                  }
                  final response =
                      (result as Success<MedicationListResponse>).data;
                  if (response.medications.isEmpty) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(),
                    );
                  }
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildSummaryHeader(response, isDesktop),
                      ),
                      _buildMedicationsTable(response.medications, isDesktop),
                      if (response.hasPagination)
                        SliverToBoxAdapter(
                          child: _buildPagination(response, isDesktop),
                        ),
                    ],
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: LoadingWidget()),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: CustomErrorWidget(
                    message: error.toString(),
                    onRetry: () => ref.refresh(medicationListProvider(filters)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text('Add Medication');
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    AuthState authState,
    bool isDesktop,
  ) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medication Management',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: () {
            final currentFilters = ref.read(medicationListFiltersProvider);
            ref.refresh(medicationListProvider(currentFilters));
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchSection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(medicationListFiltersProvider.notifier)
                        .clearSearch();
                  },
                )
              : null,
          hintText: 'Search medications...',
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[850]
              : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(
    MedicationListResponse response,
    bool isDesktop,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${response.total} medication${response.total > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Page ${response.currentPage} / ${response.lastPage}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
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

  Widget _buildMedicationsTable(
    List<MedicationModel> medications,
    bool isDesktop,
  ) {
    if (isDesktop) {
      return SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
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
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text('Code',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Name',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('DCI',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Dosage',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Form',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Presentation',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('PPV',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Actions',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  rows: medications.map((medication) {
                    return DataRow(
                      cells: [
                        DataCell(Text(medication.code ?? '—')),
                        DataCell(Text(medication.nom ?? '—',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(medication.dci1 ?? '—')),
                        DataCell(Text(
                          '${medication.dosage1 ?? ''} ${medication.uniteDosage1 ?? ''}'
                              .trim(),
                        )),
                        DataCell(Text(medication.forme ?? '—')),
                        DataCell(Text(medication.presentation ?? '—')),
                        DataCell(Text(medication.ppv ?? '—')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                color: Theme.of(context).primaryColor,
                                onPressed: () => _openEditDialog(medication),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded),
                                color: Colors.red,
                                onPressed: () => _openDeleteDialog(medication),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final medication = medications[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMedicationCard(medication),
            );
          },
          childCount: medications.length,
        ),
      );
    }
  }

  Widget _buildMedicationCard(MedicationModel medication) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        medication.nom ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${medication.code ?? '—'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          );
                        },
                      ),
                      onTap: () => _openEditDialog(medication),
                    ),
                    PopupMenuItem(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Row(
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          );
                        },
                      ),
                      onTap: () => _openDeleteDialog(medication),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  children: [
                    _buildInfoRow(
                        Icons.medication_rounded, 'DCI', medication.dci1),
                    _buildInfoRow(
                      Icons.science_rounded,
                      'Dosage',
                      '${medication.dosage1 ?? ''} ${medication.uniteDosage1 ?? ''}'
                          .trim(),
                    ),
                    _buildInfoRow(
                        Icons.shape_line_rounded, 'Form', medication.forme),
                    _buildInfoRow(
                      Icons.inventory_2_rounded,
                      'Presentation',
                      medication.presentation,
                    ),
                    _buildInfoRow(
                        Icons.attach_money_rounded, 'PPV', medication.ppv),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(
    MedicationListResponse response,
    bool isDesktop,
  ) {
    final notifier = ref.read(medicationListFiltersProvider.notifier);
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
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
          Expanded(
            child: ElevatedButton.icon(
              onPressed: response.currentPage > 1
                  ? () => notifier.setPage(response.currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(isDesktop ? 'Previous' : 'Prev.');
                },
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${response.currentPage} / ${response.lastPage}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: response.currentPage < response.lastPage
                  ? () => notifier.setPage(response.currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(isDesktop ? 'Next' : 'Next');
                },
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                children: [
                  const Text(
                    'No Medications Available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by adding medications',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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

  Widget _buildCreateEditDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            _isEditing
                                ? 'Edit Medication'
                                : 'Add New Medication',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetForm();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isEditing && _editingMedication?.code != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      initialValue: _editingMedication!.code,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                      enabled: false,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _dci1Controller,
                        decoration: const InputDecoration(
                          labelText: 'DCI',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dosage1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Dosage',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _uniteDosage1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _formeController,
                        decoration: const InputDecoration(
                          labelText: 'Form',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _presentationController,
                        decoration: const InputDecoration(
                          labelText: 'Presentation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _ppvController,
                        decoration: const InputDecoration(
                          labelText: 'PPV',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phController,
                        decoration: const InputDecoration(
                          labelText: 'PH',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _prixBrController,
                        decoration: const InputDecoration(
                          labelText: 'BR Price',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _princepsGenerique,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PRINCEPS',
                            child: Text('Brand Name'),
                          ),
                          DropdownMenuItem(
                            value: 'GENERIQUE',
                            child: Text('Generic'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _princepsGenerique = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tauxRemboursementController,
                  decoration: const InputDecoration(
                    labelText: 'Reimbursement Rate',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetForm();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      child: const Text('Save'),
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

  Widget _buildDeleteDialog() {
    return AlertDialog(
      title: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return const Text('Confirm Deletion');
        },
      ),
      content: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Text(
            'Are you sure you want to delete the medication '
            '${_deletingMedication?.nom ?? ''} '
            '(Code: ${_deletingMedication?.code ?? ''})?',
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            setState(() {
              _deletingMedication = null;
            });
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
