import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../data/models/patient_model.dart';
import '../data/models/service_model.dart';
import '../providers/patient_providers.dart';
import '../providers/api_providers.dart';
import '../providers/service_providers.dart';
import '../providers/locale_providers.dart';

class CreateInvoiceScreenNextJS extends ConsumerStatefulWidget {
  const CreateInvoiceScreenNextJS({super.key});

  @override
  ConsumerState<CreateInvoiceScreenNextJS> createState() =>
      _CreateInvoiceScreenNextJSState();
}

class _CreateInvoiceScreenNextJSState
    extends ConsumerState<CreateInvoiceScreenNextJS> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _initialPaymentController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<PatientModel> _patients = [];
  PatientModel? _selectedPatient;
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounceTimer;
  String? _selectedServiceId; // For the main service selector

  List<InvoiceItemForm> _items = [InvoiceItemForm()];
  List<ServiceModel> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchController.addListener(_onSearchChanged);
    _initialPaymentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _dueDateController.dispose();
    _initialPaymentController.dispose();
    _notesController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchPatients(_searchController.text);
    });
  }

  Future<void> _loadServices() async {
    final servicesResult = await ref.read(servicesProvider.future);
    servicesResult.when(
      success: (services) {
        setState(() {
          _services = services;
        });
      },
      failure: (error) {
        // Silently fail, services are optional
      },
    );
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() {
        _patients = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final result = await ref.read(findPatientsProvider(query).future);

      result.when(
        success: (patients) {
          setState(() {
            _patients = patients;
            _isSearching = false;
          });
        },
        failure: (message) {
          setState(() {
            _patients = [];
            _isSearching = false;
          });
          _showSnackBar('Error searching patients: $message', isError: true);
        },
      );
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        _showSnackBar('Error searching: $e', isError: true);
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItemForm());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    } else {
      _showSnackBar('At least one item is required', isError: true);
    }
  }

  // Handle service selection from main dropdown
  void _handleServiceSelect(String? serviceId) {
    if (serviceId == null) {
      setState(() {
        _selectedServiceId = null;
      });
      return;
    }

    final service = _services.firstWhere(
      (s) => s.id.toString() == serviceId,
      orElse: () => ServiceModel(),
    );

    if (service.id != null && service.title != null) {
      final priceValue = service.price ?? 0;
      final servicePrice = priceValue > 0 ? priceValue.toString() : '0';

      final newItem = InvoiceItemForm(
        initialDescription: service.title!,
        initialPrice: servicePrice,
      );

      setState(() {
        // If first item is empty, replace it, otherwise add new
        if (_items.length == 1 &&
            _items[0].descriptionController.text.isEmpty &&
            (_items[0].unitPriceController.text.isEmpty ||
                _items[0].unitPriceController.text == '0')) {
          _items[0].dispose();
          _items[0] = newItem;
        } else {
          _items.add(newItem);
        }
        _selectedServiceId = null; // Reset selection
      });

      _showSnackBar('Service "${service.title}" added to invoice',
          isError: false);
    }
  }

  // Handle service selection for a specific item row
  void _handleItemServiceSelect(int index, String? serviceId) {
    if (serviceId == null) return;

    final service = _services.firstWhere(
      (s) => s.id.toString() == serviceId,
      orElse: () => ServiceModel(),
    );

    if (service.id != null && service.title != null) {
      final priceValue = service.price ?? 0;
      final servicePrice = priceValue > 0 ? priceValue.toString() : '0';

      setState(() {
        _items[index].descriptionController.text = service.title!;
        _items[index].unitPriceController.text = servicePrice;
      });

      _showSnackBar('Service "${service.title}" added to item ${index + 1}',
          isError: false);
    }
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _initialPayment {
    return double.tryParse(_initialPaymentController.text) ?? 0.0;
  }

  double get _remaining {
    return _subtotal - _initialPayment;
  }

  double get _percentagePaid {
    return _subtotal > 0 ? (_initialPayment / _subtotal) * 100 : 0;
  }

  bool get _isFullyPaid {
    return _remaining <= 0 && _subtotal > 0;
  }

  // Auto-set due date to today if fully paid
  void _checkAutoSetDueDate() {
    if (_isFullyPaid && _dueDateController.text.isEmpty) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      setState(() {
        _dueDateController.text = today;
      });
    }
  }

  void _handleQuickFillInitialPayment() {
    setState(() {
      _initialPaymentController.text = _subtotal.toStringAsFixed(2);
    });
    _checkAutoSetDueDate();
    _showSnackBar('Initial payment set to total amount', isError: false);
  }

  void _handleReset() {
    setState(() {
      _selectedPatient = null;
      _items = [InvoiceItemForm()];
      _searchController.clear();
      _dueDateController.clear();
      _initialPaymentController.clear();
      _notesController.clear();
      _paymentMethod = 'cash';
      _patients = [];
      _selectedServiceId = null;
    });
    _showSnackBar('Form reset', isError: false);
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatient == null) {
      _showSnackBar('Please select a patient', isError: true);
      return;
    }

    if (_items.any((item) =>
        item.descriptionController.text.isEmpty ||
        item.unitPriceController.text.isEmpty)) {
      _showSnackBar('Please fill all invoice items', isError: true);
      return;
    }

    if (_initialPayment > _subtotal) {
      _showSnackBar('Initial payment cannot exceed total amount',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items = _items
          .map((item) => {
                'description': item.descriptionController.text,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
              })
          .toList();

      final invoiceService = ref.read(invoiceServiceProvider);
      await invoiceService.createInvoice(
        patientId: _selectedPatient!.id!,
        appointmentId: null,
        items: items,
        dueDate:
            _dueDateController.text.isNotEmpty ? _dueDateController.text : null,
        initialPayment: _initialPayment > 0 ? _initialPayment : null,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        _showSnackBar('Invoice created successfully!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error creating invoice: $e', isError: true);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} MAD';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Update calculations when items change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoSetDueDate();
    });

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC), // slate-50
      body: Column(
        children: [
          // Fixed Calculation Summary at Top
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF3B82F6), // blue-500
                  const Color(0xFF4F46E5), // indigo-600
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.calculate,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Calculation Summary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isFullyPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Fully Paid',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Subtotal',
                            _formatCurrency(_subtotal),
                            Icons.receipt,
                            Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Initial Payment',
                            _formatCurrency(_initialPayment),
                            Icons.wallet,
                            Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Remaining',
                            _formatCurrency(_remaining > 0 ? _remaining : 0),
                            Icons.trending_up,
                            _remaining > 0 ? Colors.amber : Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Paid',
                            '${_percentagePaid.toStringAsFixed(0)}%',
                            Icons.percent,
                            Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Invoice',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF4F46E5),
                                    ],
                                  ).createShader(
                                    const Rect.fromLTWH(0, 0, 200, 70),
                                  ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create an invoice for a patient',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _handleReset,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reset',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Patient Selection Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            'Patient Information',
                            Icons.person,
                            const Color(0xFF3B82F6),
                          ),
                          const SizedBox(height: 16),
                          // Search Field
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Name, email or CNI...',
                                prefixIcon:
                                    Icon(Icons.search, color: Colors.grey[500]),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Patient Results
                          if (_patients.isNotEmpty && _selectedPatient == null)
                            ..._patients.map((patient) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedPatient = patient;
                                        _patients = [];
                                        _searchController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              color: Color(0xFF3B82F6),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  patient.user?.name ?? 'N/A',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  patient.user?.email ?? 'N/A',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                if (patient.cniNumber != null)
                                                  Text(
                                                    'CNI: ${patient.cniNumber}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                          // Selected Patient Display
                          if (_selectedPatient != null)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.withOpacity(0.1),
                                    Colors.green.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.green, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Patient Selected',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Name',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _selectedPatient!.user?.name ??
                                                  'N/A',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_selectedPatient!.user?.email != null)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Email',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                _selectedPatient!.user!.email!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Invoice Items Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader(
                                'Invoice Items',
                                Icons.receipt,
                                const Color(0xFF4F46E5),
                              ),
                              Row(
                                children: [
                                  // Service Selector
                                  if (_services.isNotEmpty)
                                    Container(
                                      width: 180,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedServiceId,
                                          hint: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Text('Add Service'),
                                          ),
                                          isExpanded: true,
                                          items: _services.map((service) {
                                            return DropdownMenuItem<String>(
                                              value: service.id.toString(),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                child: Text(
                                                  '${service.title} - ${(service.price ?? 0).toStringAsFixed(2)} MAD',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _handleServiceSelect,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _addItem,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Manually'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Items List
                          ...List.generate(_items.length, (index) {
                            return _buildItemCard(index);
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Payment Information Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            'Payment Information',
                            Icons.payment,
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 24),

                          // Due Date and Initial Payment Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Due Date',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _dueDateController,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        hintText: 'Select date',
                                        prefixIcon:
                                            const Icon(Icons.calendar_today),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF374151)
                                            : Colors.grey[50],
                                      ),
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now()
                                              .add(const Duration(days: 7)),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 365)),
                                        );
                                        if (date != null) {
                                          final locale =
                                              ref.read(localeProvider).locale;
                                          setState(() {
                                            _dueDateController.text =
                                                DateFormat('yyyy-MM-dd',
                                                        locale.toString())
                                                    .format(date);
                                          });
                                        }
                                      },
                                    ),
                                    if (_isFullyPaid)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline,
                                                size: 14, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Auto-set to today (fully paid)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.wallet, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'Initial Payment (MAD)',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_subtotal > 0)
                                          TextButton(
                                            onPressed:
                                                _handleQuickFillInitialPayment,
                                            child: const Text(
                                              'Pay All',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _initialPaymentController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        prefixIcon:
                                            const Icon(Icons.attach_money),
                                        suffixText: 'MAD',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF374151)
                                            : Colors.grey[50],
                                      ),
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          final amount = double.tryParse(value);
                                          if (amount == null || amount < 0) {
                                            return 'Invalid amount';
                                          }
                                          if (amount > _subtotal) {
                                            return 'Cannot exceed total';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Payment Method
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildPaymentMethodChip(
                                  'cash', 'Cash', Icons.money),
                              _buildPaymentMethodChip('credit_card',
                                  'Credit Card', Icons.credit_card),
                              _buildPaymentMethodChip('bank_transfer',
                                  'Bank Transfer', Icons.account_balance),
                              _buildPaymentMethodChip('insurance', 'Insurance',
                                  Icons.local_hospital),
                              _buildPaymentMethodChip('mobile_payment',
                                  'Mobile', Icons.phone_android),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Notes
                          const Row(
                            children: [
                              Icon(Icons.note, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Notes (Optional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Additional notes on the invoice...',
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 60),
                                child: Icon(Icons.note_outlined),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF374151)
                                  : Colors.grey[50],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Payment Status Alert
                    if (_remaining > 0 && _initialPayment > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.1),
                              Colors.orange.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.amber, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Partial Payment Detected',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Patient must pay ${_formatCurrency(_remaining)} before ${_dueDateController.text.isEmpty ? 'due date' : _dueDateController.text}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleReset,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: 18),
                                SizedBox(width: 8),
                                Text('Reset'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_isLoading ||
                                    _selectedPatient == null ||
                                    _items.any((item) =>
                                        item.descriptionController.text
                                            .isEmpty ||
                                        item.unitPriceController.text
                                            .isEmpty) ||
                                    (_initialPaymentController
                                            .text.isNotEmpty &&
                                        _initialPayment > _subtotal))
                                ? null
                                : _createInvoice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Create Invoice',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(0.75)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? const Color(0xFF374151) : Colors.grey[50]!)
                .withOpacity(0.5),
            (isDark ? const Color(0xFF1E293B) : Colors.white),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Item #${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Service Selector for this item
          if (_services.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: null,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Select a service'),
                  ),
                  isExpanded: true,
                  items: _services.map((service) {
                    return DropdownMenuItem<String>(
                      value: service.id.toString(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${service.title} - ${(service.price ?? 0).toStringAsFixed(2)} MAD',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => _handleItemServiceSelect(index, value),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Description
          TextFormField(
            controller: item.descriptionController,
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText: 'Ex: Consultation...',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Quantity and Unit Price Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF374151) : Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty < 1) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: item.unitPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Unit Price (MAD) *',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF374151) : Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Price is required';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Invalid price';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Item Total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4F46E5).withOpacity(0.1),
                  const Color(0xFF4F46E5).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Item Total:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatCurrency(item.total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF3B82F6)
            : (isDark ? const Color(0xFF374151) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : Colors.grey.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _paymentMethod = value;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Invoice Item Form Class
class InvoiceItemForm {
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  InvoiceItemForm({
    String? initialDescription,
    String? initialPrice,
  })  : descriptionController =
            TextEditingController(text: initialDescription ?? ''),
        quantityController = TextEditingController(text: '1'),
        unitPriceController = TextEditingController(text: initialPrice ?? '');

  String get description => descriptionController.text;
  int get quantity => int.tryParse(quantityController.text) ?? 1;
  double get unitPrice => double.tryParse(unitPriceController.text) ?? 0.0;
  double get total => quantity * unitPrice;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
