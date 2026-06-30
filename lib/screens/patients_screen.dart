import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/utils/result.dart';
import '../data/models/patient_model.dart';
import '../data/models/patient_list_response.dart';
import '../providers/api_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/patient_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/face_detection_camera.dart';
import '../widgets/loading_widget.dart';
import 'patient_detail_screen.dart';
import '../widgets/improved_patient_form_example.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  Timer? _debounce;
  String _searchTerm = '';
  String _searchType = 'name';
  bool _isGridView = false;
  bool _isScanningId = false;
  final ImagePicker _imagePicker = ImagePicker();

  static const _filterOptions = ['all', 'today', 'week', 'month'];
  static const _sortColumns = {
    'id': 'ID',
    'name': 'Name',
    'birthdate': 'Birth Date',
  };
  static const _searchTypeLabels = {
    'name': 'Name',
    'email': 'Email',
    'cni': 'CNI Number',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _searchTerm = value.trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final filters = ref.watch(patientListFiltersProvider);
    final patientListAsync = ref.watch(patientListProvider(filters));
    final searchAsync = ref.watch(findPatientsProvider(_searchTerm));
    final bool isSearching = _searchTerm.length >= 2;
    List<PatientModel> searchResults = <PatientModel>[];
    bool searchLoading = false;
    String? searchError;
    searchAsync.when(
      data: (result) {
        if (result is Success<List<PatientModel>>) {
          searchResults = result.data;
        } else if (result is Failure<List<PatientModel>>) {
          searchError = result.message;
        }
      },
      loading: () {
        if (isSearching) {
          searchLoading = true;
        }
      },
      error: (error, _) {
        searchError = error.toString();
      },
    );
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600 && size.width < 900;
    final isDesktop = size.width >= 900;
    final isMobile = size.width < 600;
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, authState, isDesktop, isMobile),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    _buildSearchSection(context, isDesktop, isTablet),
                    if (searchLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(minHeight: 3),
                        ),
                      ),
                    if (isSearching && searchError != null)
                      _buildErrorBanner(searchError!),
                    const SizedBox(height: 20),
                    _buildFiltersSection(context, filters, isDesktop, isTablet),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
              ),
              sliver: patientListAsync.when(
                data: (result) {
                  if (result is Failure<PatientListResponse>) {
                    return SliverToBoxAdapter(
                      child: CustomErrorWidget(
                        message: result.message,
                        onRetry: () =>
                            ref.refresh(patientListProvider(filters)),
                      ),
                    );
                  }
                  final response =
                      (result as Success<PatientListResponse>).data;
                  final patients = _resolveDisplayedPatients(
                    response.patients,
                    searchResults,
                    isSearching,
                  );
                  if (patients.isEmpty) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(isSearching),
                    );
                  }
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildSummaryHeader(
                          response,
                          isDesktop,
                          isTablet,
                        ),
                      ),
                      _buildPatientsList(
                        patients,
                        isDesktop,
                        isTablet,
                        isMobile,
                      ),
                      if (response.hasPagination && !isSearching)
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
                    onRetry: () => ref.refresh(patientListProvider(filters)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImprovedPatientFormExample(),
            ),
          );
        },
        icon: const Icon(Icons.person_add_rounded),
        label: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.newPatient ?? 'New Patient (Test)');
          },
        ),
        tooltip: 'Test Improved Patient Form',
      ),
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
                  'Scan a Moroccan CNI card or search by name / CNI number.',
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
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search by Name / CNI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                      });
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
          final parsed =
              data is Map ? data['parsed'] as Map? : null;
          final faceRecognition =
              data is Map ? data['face_recognition'] as Map? : null;

          // Validated face match → navigate directly to patient detail
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
                  builder: (_) => PatientDetailScreen(patientId: matchedPatient.id!),
                ),
              );
              return;
            } catch (_) {}
          }

          // No direct match → fill search bar with CNI or name
          final cni = parsed?['cni_number']?.toString().trim() ?? '';
          final name = parsed?['name']?.toString().trim() ?? '';
          final searchTerm = cni.isNotEmpty ? cni : name;

          if (searchTerm.isNotEmpty) {
            _searchController.text = searchTerm;
            setState(() {
              _searchType = cni.isNotEmpty ? 'cni' : 'name';
              _searchTerm = searchTerm;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Searching for: $searchTerm'),
                behavior: SnackBarBehavior.floating,
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

  Widget _buildSliverAppBar(
    BuildContext context,
    AuthState authState,
    bool isDesktop,
    bool isMobile,
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
              Icons.people_rounded,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations?.patients ?? 'Patients',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  );
                },
              ),
              if (authState.user != null && !isMobile)
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      authState.user!.name ?? authState.user!.email ?? 'User',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
      actions: [
        // Quick patient search / scan icon
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
        if (isDesktop)
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return IconButton(
                icon: Icon(_isGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded),
                tooltip: _isGridView
                    ? (localizations?.listView ?? 'List view')
                    : (localizations?.gridView ?? 'Grid view'),
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              );
            },
          ),
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: localizations?.refresh ?? 'Refresh',
              onPressed: () {
                final filters = ref.read(patientListFiltersProvider);
                ref.refresh(patientListProvider(filters));
                if (_searchTerm.length >= 2) {
                  ref.refresh(findPatientsProvider(_searchTerm));
                }
              },
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchSection(
      BuildContext context, bool isDesktop, bool isTablet) {
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
      child: isDesktop || isTablet
          ? Row(
              children: [
                Expanded(flex: 3, child: _buildSearchField(context)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildSearchTypeDropdown(context)),
              ],
            )
          : Column(
              children: [
                _buildSearchField(context),
                const SizedBox(height: 12),
                _buildSearchTypeDropdown(context),
              ],
            ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
        suffixIcon: _searchTerm.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchTerm = '';
                  });
                },
              ),
        hintText: () {
          final localizations = AppLocalizations.of(context);
          final searchTypeLabel =
              _searchTypeLabels[_searchType] ?? localizations?.name ?? 'name';
          return 'Search by ${searchTypeLabel.toLowerCase()}...';
        }(),
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
      onChanged: _handleSearchChanged,
    );
  }

  Widget _buildSearchTypeDropdown(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _searchType,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.filter_list_rounded),
          labelText: localizations?.searchType ?? 'Search Type',
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
        items: _searchTypeLabels.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _searchType = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(
    BuildContext context,
    PatientListFilters filters,
    bool isDesktop,
    bool isTablet,
  ) {
    final localizations = AppLocalizations.of(context);
    final notifier = ref.read(patientListFiltersProvider.notifier);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                localizations?.filtersAndSort ?? 'Filters and Sort',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.grey[800],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.showsOnlyPatientsWithAppointments ??
                            'Shows only patients with appointments in the selected period.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.grey[700],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filterOptions.map((option) {
              final localizations = AppLocalizations.of(context);
              final label = switch (option) {
                'today' => localizations?.today ?? 'Today',
                'week' => localizations?.thisWeek ?? 'This Week',
                'month' => localizations?.thisMonth ?? 'This Month',
                'all' => localizations?.all ?? 'All',
                _ => option,
              };
              final isSelected = filters.filter == option;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => notifier.setFilter(option),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]
                          : Colors.grey[100],
                  selectedColor:
                      Theme.of(context).primaryColor.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          isDesktop || isTablet
              ? Row(
                  children: [
                    Expanded(
                        child: _buildSortColumnDropdown(
                            context, filters, notifier)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildSortDirectionDropdown(
                            context, filters, notifier)),
                  ],
                )
              : Column(
                  children: [
                    _buildSortColumnDropdown(context, filters, notifier),
                    const SizedBox(height: 12),
                    _buildSortDirectionDropdown(context, filters, notifier),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSortColumnDropdown(
    BuildContext context,
    PatientListFilters filters,
    dynamic notifier,
  ) {
    final localizations = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: filters.sortColumn,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.sort_rounded),
          labelText: localizations?.sortBy ?? 'Sort By',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: _sortColumns.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) notifier.setSortColumn(value);
        },
      ),
    );
  }

  Widget _buildSortDirectionDropdown(
    BuildContext context,
    PatientListFilters filters,
    dynamic notifier,
  ) {
    final localizations = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: filters.sortDirection,
        decoration: InputDecoration(
          prefixIcon: Icon(
            filters.sortDirection == 'asc'
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
          ),
          labelText: localizations?.order ?? 'Order',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          DropdownMenuItem(
            value: 'asc',
            child: Text(localizations?.ascending ?? 'Ascending'),
          ),
          DropdownMenuItem(
            value: 'desc',
            child: Text(localizations?.descending ?? 'Descending'),
          ),
        ],
        onChanged: (value) {
          if (value != null) notifier.setSortDirection(value);
        },
      ),
    );
  }

  Widget _buildSummaryHeader(
    PatientListResponse response,
    bool isDesktop,
    bool isTablet,
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
                  Icons.people_rounded,
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
                            '${response.total} patient${response.total > 1 ? 's' : ''}',
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

  Widget _buildPatientsList(
    List<PatientModel> patients,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    if (isDesktop) {
      return _isGridView
          ? _buildPatientGrid(patients, 3)
          : _buildPatientsTable(patients);
    }
    if (isTablet) {
      return _buildPatientGrid(patients, 2);
    }
    return _buildPatientCards(patients);
  }

  Widget _buildPatientGrid(List<PatientModel> patients, int crossAxisCount) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final patient = patients[index];
            return _buildEnhancedPatientCard(patient, index);
          },
          childCount: patients.length,
        ),
      ),
    );
  }

  Widget _buildPatientsTable(List<PatientModel> patients) {
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
                columns: [
                  DataColumn(
                      label: Text('ID',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.name ?? 'Name',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.gender ?? 'Gender',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.birthDate ?? 'Birth Date',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.bloodType ?? 'Blood Type',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.insurance ?? 'Insurance',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.email ?? 'Email',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(localizations?.phone ?? 'Phone',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: patients.map((patient) {
                  return DataRow(
                    cells: [
                      DataCell(Text(patient.id?.toString() ?? '—')),
                      DataCell(Text(patient.user?.name ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(_buildBadge(_formatGender(patient.gender),
                          _getGenderColor(patient.gender))),
                      DataCell(Text(_formatDate(patient.birthdate))),
                      DataCell(
                          _buildBadge(patient.bloodType ?? 'N/A', Colors.red)),
                      DataCell(Text(patient.insuranceType ?? 'N/A')),
                      DataCell(Text(patient.user?.email ?? 'N/A')),
                      DataCell(
                          Text(patient.phoneNumber ?? patient.phone ?? 'N/A')),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCards(List<PatientModel> patients) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final patient = patients[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEnhancedPatientCard(patient, index),
          );
        },
        childCount: patients.length,
      ),
    );
  }

  Widget _buildEnhancedPatientCard(PatientModel patient, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
        ),
        child: InkWell(
          onTap: () {
            if (patient.id != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientDetailScreen(patientId: patient.id!),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        (patient.user?.name ?? 'N')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.user?.name ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${patient.id ?? '—'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(_formatGender(patient.gender),
                            _getGenderColor(patient.gender)),
                        _buildBadge(
                            patient.bloodType ?? 'Unknown Group', Colors.red),
                        _buildBadge(patient.insuranceType ?? 'Insurance N/A',
                            Colors.blue),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                    Icons.cake_outlined, _formatDate(patient.birthdate)),
                _buildInfoRow(Icons.mail_outline, patient.user?.email ?? '—'),
                _buildInfoRow(
                  Icons.phone_outlined,
                  patient.phoneNumber ?? patient.phone ?? '—',
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildInfoRow(Icons.badge_outlined,
                        'CNI: ${patient.cniNumber ?? '—'}');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPagination(PatientListResponse response, bool isDesktop) {
    final localizations = AppLocalizations.of(context);
    final notifier = ref.read(patientListFiltersProvider.notifier);
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
              label: Text(localizations?.previous ??
                  (isDesktop ? 'Previous' : 'Prev.')),
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
              label: Text(localizations?.next ?? 'Next'),
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

  Widget _buildEmptyState(bool isSearching) {
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
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.person_add_alt_1_rounded,
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
                  Text(
                    isSearching
                        ? (localizations?.noPatientFound ?? 'No Patient Found')
                        : (localizations?.noPatientsAvailable ??
                            'No Patients Available'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSearching
                        ? (localizations?.tryAnotherSearch ??
                            'Try another search or modify the filters')
                        : (localizations?.startByAddingPatients ??
                            'Start by adding patients'),
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

  List<PatientModel> _resolveDisplayedPatients(
    List<PatientModel> basePatients,
    List<PatientModel> searchResults,
    bool isSearching,
  ) {
    if (!isSearching) return basePatients;
    final source = searchResults.isNotEmpty ? searchResults : basePatients;
    final term = _searchTerm.toLowerCase();
    return source.where((patient) {
      final value = switch (_searchType) {
        'email' => patient.user?.email ?? '',
        'cni' => patient.cniNumber ?? '',
        _ => patient.user?.name ?? '',
      };
      return value.toLowerCase().contains(term);
    }).toList();
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(date);
      final locale = ref.watch(localeProvider).locale;
      return DateFormat.yMMMMd(locale.toString()).format(parsed);
    } catch (_) {
      return date;
    }
  }

  String _formatGender(String? gender) {
    return switch (gender?.toLowerCase()) {
      'male' => 'Male',
      'female' => 'Female',
      'other' => 'Other',
      _ => 'Unknown',
    };
  }

  Color _getGenderColor(String? gender) {
    return switch (gender?.toLowerCase()) {
      'male' => Colors.blue,
      'female' => Colors.pink,
      'other' => Colors.purple,
      _ => Colors.grey,
    };
  }
}
