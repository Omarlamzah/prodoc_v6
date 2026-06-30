import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../core/utils/result.dart';
import '../providers/auth_providers.dart';
import '../providers/report_providers.dart';
import '../providers/api_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showFilters = false;

  final List<String> _reportTypes = [
    'appointments',
    'financial',
    'patients',
    'doctor-performance',
    'lab-tests',
    'prescriptions',
    'inventory',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _reportTypes.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final notifier = ref.read(reportFiltersProvider.notifier);
      notifier.setReportType(_reportTypes[_tabController.index]);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final notifier = ref.read(reportFiltersProvider.notifier);
      notifier.updateFilter('search', _searchController.text.trim());
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final locale = ref.watch(localeProvider).locale;
      return DateFormat('dd MMM yyyy', locale.toString()).format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _selectDate(BuildContext context, String filterKey) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: ref.watch(localeProvider).locale,
    );
    if (picked != null) {
      final notifier = ref.read(reportFiltersProvider.notifier);
      notifier.updateFilter(filterKey, DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final filters = ref.watch(reportFiltersProvider);
    final reportAsync = ref.watch(reportDataProvider(filters));
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, authState, isDesktop),
            _buildTabs(context),
            Expanded(
              child: reportAsync.when(
                data: (result) {
                  if (result is Failure<Map<String, dynamic>>) {
                    return CustomErrorWidget(
                      message: result.message,
                      onRetry: () => ref.refresh(reportDataProvider(filters)),
                    );
                  }
                  final response =
                      (result as Success<Map<String, dynamic>>).data;
                  return _buildReportContent(
                      context, response, filters, isDesktop);
                },
                loading: () => const Center(child: LoadingWidget()),
                error: (error, _) => CustomErrorWidget(
                  message: error.toString(),
                  onRetry: () => ref.refresh(reportDataProvider(filters)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
      BuildContext context, AuthState authState, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A0A0A)
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.assessment_rounded,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return const Text(
                  'Hospital Reports',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              final currentFilters = ref.read(reportFiltersProvider);
              ref.refresh(reportDataProvider(currentFilters));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.grey[100],
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        tabs: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Appointments');
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Financial');
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Patients');
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Doctors');
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Lab Tests');
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Prescriptions');
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return const Tab(text: 'Inventory');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(
    BuildContext context,
    Map<String, dynamic> response,
    ReportFilters filters,
    bool isDesktop,
  ) {
    final data = response['data'] as List<dynamic>? ?? [];
    final stats = response['stats'] as Map<String, dynamic>? ?? {};
    final pagination = response['pagination'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFiltersSection(context, filters, isDesktop),
          if (stats.isNotEmpty) _buildStatsSection(stats, isDesktop),
          const SizedBox(height: 16),
          _buildTableSection(context, data, filters, isDesktop),
          if (pagination.isNotEmpty)
            _buildPagination(pagination, filters, isDesktop),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(
    BuildContext context,
    ReportFilters filters,
    bool isDesktop,
  ) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).primaryColor,
                    ),
                    hintText: 'Search...',
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
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_showFilters
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: 'Filters',
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () => _showExportMenu(context, filters),
                tooltip: 'Export',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.read(reportFiltersProvider.notifier).resetFilters();
                },
                tooltip: 'Reset',
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 16),
            _buildFiltersForTab(context, filters, isDesktop),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersForTab(
    BuildContext context,
    ReportFilters filters,
    bool isDesktop,
  ) {
    switch (filters.reportType) {
      case 'appointments':
        return _buildAppointmentsFilters(context, filters);
      case 'financial':
        return _buildFinancialFilters(context, filters);
      case 'patients':
        return _buildPatientsFilters(context, filters);
      case 'doctor-performance':
        return _buildDoctorPerformanceFilters(context, filters);
      case 'lab-tests':
        return _buildLabTestsFilters(context, filters);
      case 'prescriptions':
        return _buildPrescriptionsFilters(context, filters);
      case 'inventory':
        return _buildInventoryFilters(context, filters);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAppointmentsFilters(
      BuildContext context, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'start_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.startDate ?? 'Start Date'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'end_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.endDate ?? 'End Date'),
          ),
        ),
        SizedBox(
          width: 150,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Doctor ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => notifier.updateFilter('doctor_id', value),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: filters.status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              DropdownMenuItem(value: 'no_show', child: Text('No Show')),
            ],
            onChanged: (value) => notifier.updateFilter('status', value),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialFilters(BuildContext context, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'start_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.startDate ?? 'Start Date'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'end_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.endDate ?? 'End Date'),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: filters.status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              DropdownMenuItem(value: 'partial', child: Text('Partial')),
            ],
            onChanged: (value) => notifier.updateFilter('status', value),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientsFilters(BuildContext context, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: filters.gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => notifier.updateFilter('gender', value),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Blood Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => notifier.updateFilter('blood_type', value),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: filters.insuranceType,
            decoration: const InputDecoration(
              labelText: 'Insurance',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'amo', child: Text('AMO')),
              DropdownMenuItem(value: 'cnss', child: Text('CNSS')),
              DropdownMenuItem(value: 'private', child: Text('Private')),
              DropdownMenuItem(value: 'none', child: Text('None')),
            ],
            onChanged: (value) =>
                notifier.updateFilter('insurance_type', value),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorPerformanceFilters(
      BuildContext context, ReportFilters filters) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'start_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.startDate ?? 'Start Date'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'end_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.endDate ?? 'End Date'),
          ),
        ),
      ],
    );
  }

  Widget _buildLabTestsFilters(BuildContext context, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'start_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.startDate ?? 'Start Date'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'end_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.endDate ?? 'End Date'),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: filters.status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
            ],
            onChanged: (value) => notifier.updateFilter('status', value),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionsFilters(
      BuildContext context, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'start_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.startDate ?? 'Start Date'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, 'end_date'),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(filters.endDate ?? 'End Date'),
          ),
        ),
        SizedBox(
          width: 200,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Medication Code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) =>
                notifier.updateFilter('medication_code', value),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryFilters(BuildContext context, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Row(
          children: [
            Checkbox(
              value: filters.lowStock,
              onChanged: (value) =>
                  notifier.updateFilter('low_stock', value ?? false),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return const Text('Low Stock');
              },
            ),
            const SizedBox(width: 16),
            Checkbox(
              value: filters.expiringSoon,
              onChanged: (value) =>
                  notifier.updateFilter('expiring_soon', value ?? false),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return const Text('Expiring Soon');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> stats, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats.entries.map((entry) {
          final value = entry.value;
          String displayValue = value.toString();
          if (value is num) {
            if (entry.key.contains('percentage')) {
              displayValue = '${value.toStringAsFixed(1)}%';
            } else if (entry.key.contains('amount') ||
                entry.key.contains('earnings') ||
                entry.key.contains('value')) {
              displayValue = '\$${value.toStringAsFixed(2)}';
            }
          }
          return Container(
            width: isDesktop ? 200 : 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableSection(
    BuildContext context,
    List<dynamic> data,
    ReportFilters filters,
    bool isDesktop,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    'No data available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

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
      child: isDesktop
          ? _buildDesktopTable(data, filters)
          : _buildMobileTable(data, filters),
    );
  }

  Widget _buildDesktopTable(List<dynamic> data, ReportFilters filters) {
    final notifier = ref.read(reportFiltersProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Theme.of(context).primaryColor.withOpacity(0.1),
        ),
        columns: _getTableColumns(filters.reportType, notifier, filters),
        rows: data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;
          return DataRow(
            color: WidgetStateProperty.all(
              index % 2 == 0
                  ? Colors.transparent
                  : Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.grey[50],
            ),
            cells: _getTableCells(item, filters.reportType),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileTable(List<dynamic> data, ReportFilters filters) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index] as Map<String, dynamic>;
        return _buildMobileCard(item, filters.reportType, index);
      },
    );
  }

  List<DataColumn> _getTableColumns(
    String reportType,
    ReportFiltersNotifier notifier,
    ReportFilters filters,
  ) {
    switch (reportType) {
      case 'appointments':
        return [
          _buildSortableColumn('Date', 'appointment_date', notifier, filters),
          const DataColumn(label: Text('Time')),
          _buildSortableColumn('Patient', 'patient_name', notifier, filters),
          _buildSortableColumn('Doctor', 'doctor_name', notifier, filters),
          const DataColumn(label: Text('Service')),
          const DataColumn(label: Text('Status')),
        ];
      case 'financial':
        return [
          const DataColumn(label: Text('Invoice ID')),
          _buildSortableColumn('Patient', 'patient_name', notifier, filters),
          _buildSortableColumn('Amount', 'amount', notifier, filters),
          const DataColumn(label: Text('Paid')),
          const DataColumn(label: Text('Due')),
          const DataColumn(label: Text('Status')),
          _buildSortableColumn('Date', 'created_at', notifier, filters),
        ];
      case 'patients':
        return [
          _buildSortableColumn('Nom', 'name', notifier, filters),
          const DataColumn(label: Text('Gender')),
          const DataColumn(label: Text('Blood Type')),
          const DataColumn(label: Text('Insurance')),
          const DataColumn(label: Text('Appointments')),
          const DataColumn(label: Text('Medical Records')),
        ];
      case 'doctor-performance':
        return [
          _buildSortableColumn('Doctor', 'name', notifier, filters),
          const DataColumn(label: Text('Specialty')),
          const DataColumn(label: Text('Total Appointments')),
          const DataColumn(label: Text('Completed')),
          const DataColumn(label: Text('Cancelled')),
          const DataColumn(label: Text('Patients')),
          const DataColumn(label: Text('Earnings')),
        ];
      case 'lab-tests':
        return [
          const DataColumn(label: Text('Test Name')),
          _buildSortableColumn('Patient', 'patient_name', notifier, filters),
          _buildSortableColumn('Doctor', 'doctor_name', notifier, filters),
          const DataColumn(label: Text('Status')),
          _buildSortableColumn('Date', 'created_at', notifier, filters),
          const DataColumn(label: Text('Result')),
        ];
      case 'prescriptions':
        return [
          _buildSortableColumn(
              'Medication', 'medication_name', notifier, filters),
          const DataColumn(label: Text('Dosage')),
          const DataColumn(label: Text('Frequency')),
          const DataColumn(label: Text('Duration')),
          _buildSortableColumn('Patient', 'patient_name', notifier, filters),
          _buildSortableColumn('Date', 'created_at', notifier, filters),
        ];
      case 'inventory':
        return [
          _buildSortableColumn(
              'Medication', 'medicine_name', notifier, filters),
          _buildSortableColumn('Quantity', 'quantity', notifier, filters),
          const DataColumn(label: Text('Threshold')),
          const DataColumn(label: Text('Price')),
          _buildSortableColumn('Expiry Date', 'expiry_date', notifier, filters),
          const DataColumn(label: Text('Status')),
        ];
      default:
        return [];
    }
  }

  DataColumn _buildSortableColumn(
    String label,
    String sortKey,
    ReportFiltersNotifier notifier,
    ReportFilters filters,
  ) {
    return DataColumn(
      label: InkWell(
        onTap: () => notifier.setSort(sortKey),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (filters.sortBy == sortKey)
              Icon(
                filters.sortDirection == 'asc'
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  List<DataCell> _getTableCells(Map<String, dynamic> item, String reportType) {
    switch (reportType) {
      case 'appointments':
        return [
          DataCell(Text(_formatDate(item['appointment_date']?.toString()))),
          DataCell(Text(item['appointment_time']?.toString() ?? 'N/A')),
          DataCell(
              Text(item['patient']?['user']?['name']?.toString() ?? 'N/A')),
          DataCell(Text(item['doctor']?['user']?['name']?.toString() ?? 'N/A')),
          DataCell(Text(item['service']?['title']?.toString() ?? 'N/A')),
          DataCell(_buildStatusBadge(item['status']?.toString() ?? 'N/A')),
        ];
      case 'financial':
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (item['paid'] as num?)?.toDouble() ?? 0.0;
        return [
          DataCell(Text(item['id']?.toString() ?? 'N/A')),
          DataCell(
              Text(item['patient']?['user']?['name']?.toString() ?? 'N/A')),
          DataCell(Text('\$${amount.toStringAsFixed(2)}')),
          DataCell(Text('\$${paid.toStringAsFixed(2)}')),
          DataCell(Text('\$${(amount - paid).toStringAsFixed(2)}')),
          DataCell(_buildStatusBadge(item['status']?.toString() ?? 'N/A')),
          DataCell(Text(_formatDate(item['created_at']?.toString()))),
        ];
      case 'patients':
        return [
          DataCell(Text(item['user']?['name']?.toString() ?? 'N/A')),
          DataCell(Text(_formatGender(item['gender']?.toString()))),
          DataCell(Text(item['blood_type']?.toString() ?? 'N/A')),
          DataCell(_buildInsuranceBadge(item['insurance_type']?.toString())),
          DataCell(
              Text((item['appointments'] as List?)?.length.toString() ?? '0')),
          DataCell(Text(
              (item['medicalRecords'] as List?)?.length.toString() ?? '0')),
        ];
      case 'doctor-performance':
        final stats = item['stats'] as Map<String, dynamic>? ?? {};
        return [
          DataCell(Text(item['doctor']?['user']?['name']?.toString() ?? 'N/A')),
          DataCell(Text(item['doctor']?['specialty']?.toString() ?? 'N/A')),
          DataCell(Text(stats['total_appointments']?.toString() ?? '0')),
          DataCell(Text(stats['completed_appointments']?.toString() ?? '0')),
          DataCell(Text(stats['cancelled_appointments']?.toString() ?? '0')),
          DataCell(Text(stats['total_patients']?.toString() ?? '0')),
          DataCell(Text(
              '\$${(stats['total_earnings'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
        ];
      case 'lab-tests':
        return [
          DataCell(Text(item['test_name']?.toString() ?? 'N/A')),
          DataCell(
              Text(item['patient']?['user']?['name']?.toString() ?? 'N/A')),
          DataCell(Text(item['doctor']?['user']?['name']?.toString() ?? 'N/A')),
          DataCell(_buildStatusBadge(item['status']?.toString() ?? 'N/A')),
          DataCell(Text(_formatDate(item['created_at']?.toString()))),
          DataCell(item['result'] != null
              ? TextButton(
                  onPressed: () {},
                  child: const Text('View Result'),
                )
              : const Text('N/A')),
        ];
      case 'prescriptions':
        // Handle prescriptions which might have nested medications array
        final medications = item['medications'] as List?;
        if (medications != null && medications.isNotEmpty) {
          final med = medications[0] as Map<String, dynamic>;
          return [
            DataCell(Text(med['medication']?['NOM']?.toString() ?? 'N/A')),
            DataCell(Text(med['dosage']?.toString() ?? 'N/A')),
            DataCell(Text(med['frequency']?.toString() ?? 'N/A')),
            DataCell(Text(med['duration']?.toString() ?? 'N/A')),
            DataCell(Text(item['medical_record']?['patient']?['user']?['name']
                    ?.toString() ??
                'N/A')),
            DataCell(Text(_formatDate(item['created_at']?.toString()))),
          ];
        }
        return [
          const DataCell(Text('N/A')),
          const DataCell(Text('N/A')),
          const DataCell(Text('N/A')),
          const DataCell(Text('N/A')),
          const DataCell(Text('N/A')),
          const DataCell(Text('N/A')),
        ];
      case 'inventory':
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final threshold = (item['threshold'] as num?)?.toInt() ?? 0;
        final expiryDate = item['expiry_date']?.toString();
        return [
          DataCell(Text(item['medicine_name']?.toString() ?? 'N/A')),
          DataCell(Text(quantity.toString())),
          DataCell(Text(threshold.toString())),
          DataCell(Text(
              '\$${(item['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
          DataCell(Text(_formatDate(expiryDate))),
          DataCell(_buildInventoryStatusBadge(quantity, threshold, expiryDate)),
        ];
      default:
        return [];
    }
  }

  Widget _buildMobileCard(
      Map<String, dynamic> item, String reportType, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _getMobileCardContent(item, reportType),
        ),
      ),
    );
  }

  List<Widget> _getMobileCardContent(
      Map<String, dynamic> item, String reportType) {
    switch (reportType) {
      case 'appointments':
        return [
          Text(
            item['patient']?['user']?['name']?.toString() ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
              'Date', _formatDate(item['appointment_date']?.toString())),
          _buildInfoRow('Time', item['appointment_time']?.toString() ?? 'N/A'),
          _buildInfoRow(
              'Doctor', item['doctor']?['user']?['name']?.toString() ?? 'N/A'),
          _buildInfoRow(
              'Service', item['service']?['title']?.toString() ?? 'N/A'),
          const SizedBox(height: 8),
          _buildStatusBadge(item['status']?.toString() ?? 'N/A'),
        ];
      case 'financial':
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (item['paid'] as num?)?.toDouble() ?? 0.0;
        return [
          Text(
            'Invoice #${item['id']?.toString() ?? 'N/A'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Patient',
              item['patient']?['user']?['name']?.toString() ?? 'N/A'),
          _buildInfoRow('Amount', '\$${amount.toStringAsFixed(2)}'),
          _buildInfoRow('Paid', '\$${paid.toStringAsFixed(2)}'),
          _buildInfoRow('Due', '\$${(amount - paid).toStringAsFixed(2)}'),
          _buildInfoRow('Date', _formatDate(item['created_at']?.toString())),
          const SizedBox(height: 8),
          _buildStatusBadge(item['status']?.toString() ?? 'N/A'),
        ];
      case 'patients':
        return [
          Text(
            item['user']?['name']?.toString() ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Gender', _formatGender(item['gender']?.toString())),
          _buildInfoRow('Blood Type', item['blood_type']?.toString() ?? 'N/A'),
          _buildInfoRow(
              'Insurance', item['insurance_type']?.toString() ?? 'None'),
          _buildInfoRow('Appointments',
              (item['appointments'] as List?)?.length.toString() ?? '0'),
          _buildInfoRow('Medical Records',
              (item['medicalRecords'] as List?)?.length.toString() ?? '0'),
        ];
      default:
        return [const Text('N/A')];
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        color = Colors.green;
        label = status == 'completed' ? 'Completed' : 'Paid';
        break;
      case 'cancelled':
      case 'unpaid':
        color = Colors.red;
        label = status == 'cancelled' ? 'Cancelled' : 'Unpaid';
        break;
      case 'scheduled':
      case 'pending':
        color = Colors.blue;
        label = status == 'scheduled' ? 'Scheduled' : 'Pending';
        break;
      case 'no_show':
        color = Colors.grey;
        label = 'No Show';
        break;
      case 'partial':
        color = Colors.orange;
        label = 'Partial';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInsuranceBadge(String? insuranceType) {
    if (insuranceType == null || insuranceType.isEmpty) {
      return _buildStatusBadge('none');
    }
    return _buildStatusBadge(insuranceType);
  }

  Widget _buildInventoryStatusBadge(
      int quantity, int threshold, String? expiryDate) {
    if (quantity <= 0) {
      return _buildStatusBadge('Out of Stock');
    } else if (quantity <= threshold) {
      return _buildStatusBadge('Low Stock');
    } else if (expiryDate != null) {
      try {
        final expiry = DateTime.parse(expiryDate);
        final daysUntilExpiry = expiry.difference(DateTime.now()).inDays;
        if (daysUntilExpiry <= 30) {
          return _buildStatusBadge('Expiring Soon');
        }
      } catch (_) {}
    }
    return _buildStatusBadge('In Stock');
  }

  String _formatGender(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      default:
        return 'N/A';
    }
  }

  Widget _buildPagination(
    Map<String, dynamic> pagination,
    ReportFilters filters,
    bool isDesktop,
  ) {
    final currentPage = (pagination['current_page'] as num?)?.toInt() ?? 1;
    final lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
    final notifier = ref.read(reportFiltersProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Row(
                children: [
                  const Text('Show'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      value: filters.perPage,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: (value) {
                        if (value != null) notifier.setPerPage(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('per page'),
                ],
              );
            },
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: currentPage > 1
                    ? () => notifier.setPage(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(isDesktop ? 'Previous' : 'Prev.');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      'Page $currentPage of $lastPage',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: currentPage < lastPage
                    ? () => notifier.setPage(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(isDesktop ? 'Next' : 'Next');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExportMenu(BuildContext context, ReportFilters filters) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.table_chart_rounded),
                      title: const Text('Export to CSV'),
                      onTap: () {
                        Navigator.pop(context);
                        _exportToCSV(filters);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf_rounded),
                      title: const Text('Export to PDF'),
                      onTap: () {
                        Navigator.pop(context);
                        _exportToPDF(filters);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.grid_on_rounded),
                      title: const Text('Export to Excel'),
                      onTap: () {
                        Navigator.pop(context);
                        _exportToExcel(filters);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV(ReportFilters filters) async {
    try {
      final reportService = ref.read(reportServiceProvider);
      final result = await reportService.fetchReport(
        reportType: filters.reportType,
        filters: filters.toQueryParams(),
      );

      await result.when(
        success: (response) async {
          final data = response['data'] as List<dynamic>? ?? [];

          if (data.isEmpty) {
            _showErrorSnackBar('No data available for export');
            return;
          }

          final csv = _generateCSV(data, filters.reportType);
          await _saveAndShareFile(
              csv,
              '${filters.reportType}_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
              'text/csv');
          _showSuccessSnackBar('CSV exported successfully');
        },
        failure: (message) {
          _showErrorSnackBar('Error: $message');
        },
      );
    } catch (e) {
      _showErrorSnackBar('CSV export error: $e');
    }
  }

  Future<void> _exportToPDF(ReportFilters filters) async {
    try {
      _showErrorSnackBar('PDF Export - Feature coming soon');
    } catch (e) {
      _showErrorSnackBar('PDF export error: $e');
    }
  }

  Future<void> _exportToExcel(ReportFilters filters) async {
    try {
      _showErrorSnackBar('Excel Export - Feature coming soon');
    } catch (e) {
      _showErrorSnackBar('Excel export error: $e');
    }
  }

  String _generateCSV(List<dynamic> data, String reportType) {
    final buffer = StringBuffer();

    // Add headers
    final headers = _getCSVHeaders(reportType);
    buffer.writeln(headers.join(','));

    // Add data rows
    for (final item in data) {
      final row = _getCSVRow(item as Map<String, dynamic>, reportType);
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  List<String> _getCSVHeaders(String reportType) {
    switch (reportType) {
      case 'appointments':
        return ['Date', 'Time', 'Patient', 'Doctor', 'Service', 'Status'];
      case 'financial':
        return [
          'Invoice ID',
          'Patient',
          'Amount',
          'Paid',
          'Due',
          'Status',
          'Date'
        ];
      case 'patients':
        return [
          'Name',
          'Gender',
          'Blood Type',
          'Insurance',
          'Appointments',
          'Medical Records'
        ];
      case 'doctor-performance':
        return [
          'Doctor',
          'Specialty',
          'Total Appointments',
          'Completed',
          'Cancelled',
          'Patients',
          'Earnings'
        ];
      case 'lab-tests':
        return ['Test Name', 'Patient', 'Doctor', 'Status', 'Date', 'Result'];
      case 'prescriptions':
        return [
          'Medication',
          'Dosage',
          'Frequency',
          'Duration',
          'Patient',
          'Date'
        ];
      case 'inventory':
        return [
          'Medication',
          'Quantity',
          'Threshold',
          'Price',
          'Expiry Date',
          'Status'
        ];
      default:
        return [];
    }
  }

  List<String> _getCSVRow(Map<String, dynamic> item, String reportType) {
    switch (reportType) {
      case 'appointments':
        return [
          _formatDate(item['appointment_date']?.toString()),
          item['appointment_time']?.toString() ?? 'N/A',
          item['patient']?['user']?['name']?.toString() ?? 'N/A',
          item['doctor']?['user']?['name']?.toString() ?? 'N/A',
          item['service']?['title']?.toString() ?? 'N/A',
          item['status']?.toString() ?? 'N/A',
        ];
      case 'financial':
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (item['paid'] as num?)?.toDouble() ?? 0.0;
        return [
          item['id']?.toString() ?? 'N/A',
          item['patient']?['user']?['name']?.toString() ?? 'N/A',
          amount.toStringAsFixed(2),
          paid.toStringAsFixed(2),
          (amount - paid).toStringAsFixed(2),
          item['status']?.toString() ?? 'N/A',
          _formatDate(item['created_at']?.toString()),
        ];
      case 'patients':
        return [
          item['user']?['name']?.toString() ?? 'N/A',
          _formatGender(item['gender']?.toString()),
          item['blood_type']?.toString() ?? 'N/A',
          item['insurance_type']?.toString() ?? 'None',
          (item['appointments'] as List?)?.length.toString() ?? '0',
          (item['medicalRecords'] as List?)?.length.toString() ?? '0',
        ];
      case 'doctor-performance':
        final stats = item['stats'] as Map<String, dynamic>? ?? {};
        return [
          item['doctor']?['user']?['name']?.toString() ?? 'N/A',
          item['doctor']?['specialty']?.toString() ?? 'N/A',
          stats['total_appointments']?.toString() ?? '0',
          stats['completed_appointments']?.toString() ?? '0',
          stats['cancelled_appointments']?.toString() ?? '0',
          stats['total_patients']?.toString() ?? '0',
          (stats['total_earnings'] as num?)?.toStringAsFixed(2) ?? '0.00',
        ];
      default:
        return [];
    }
  }

  Future<void> _saveAndShareFile(
      String content, String fileName, String mimeType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      final xFile = XFile(file.path, mimeType: mimeType);
      await Share.shareXFiles([xFile], text: 'Exported report');
    } catch (e) {
      throw Exception('Error saving file: $e');
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
}
