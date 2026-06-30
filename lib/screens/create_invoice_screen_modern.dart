import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/models/patient_model.dart';
import '../data/models/appointment_model.dart';
import '../core/utils/result.dart';
import '../providers/patient_providers.dart';
import '../providers/api_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';

class CreateInvoiceScreenModern extends ConsumerStatefulWidget {
  const CreateInvoiceScreenModern({super.key});

  @override
  ConsumerState<CreateInvoiceScreenModern> createState() =>
      _CreateInvoiceScreenModernState();
}

class _CreateInvoiceScreenModernState
    extends ConsumerState<CreateInvoiceScreenModern>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _initialPaymentController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<PatientModel> _patients = [];
  List<AppointmentModel> _appointments = [];
  PatientModel? _selectedPatient;
  AppointmentModel? _selectedAppointment;
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  bool _isSearching = false;

  List<InvoiceItemForm> _items = [InvoiceItemForm()];

  late AnimationController _animationController;
  late AnimationController _stepAnimationController;
  late AnimationController _floatingAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatingAnimation;

  int _currentStep = 0;
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _predefinedServices = [
    {
      'value': 'consultation',
      'label': 'Consultation',
      'price': 200.0,
      'icon': '🩺',
      'color': Color(0xFF4F46E5)
    },
    {
      'value': 'follow_up',
      'label': 'Visite de suivi',
      'price': 150.0,
      'icon': '📋',
      'color': Color(0xFF059669)
    },
    {
      'value': 'medical_exam',
      'label': 'Examen médical',
      'price': 300.0,
      'icon': '🔬',
      'color': Color(0xFFDC2626)
    },
    {
      'value': 'diagnosis',
      'label': 'Diagnostic',
      'price': 250.0,
      'icon': '🏥',
      'color': Color(0xFFEA580C)
    },
    {
      'value': 'prescription_renewal',
      'label': 'Renouvellement d\'ordonnance',
      'price': 100.0,
      'icon': '💊',
      'color': Color(0xFF8B5CF6)
    },
    {
      'value': 'lab_test_request',
      'label': 'Demande d\'analyses',
      'price': 80.0,
      'icon': '🧪',
      'color': Color(0xFF0891B2)
    },
    {
      'value': 'health_certificate',
      'label': 'Certificat médical',
      'price': 120.0,
      'icon': '📄',
      'color': Color(0xFF65A30D)
    },
    {
      'value': 'teleconsultation',
      'label': 'Téléconsultation',
      'price': 180.0,
      'icon': '💻',
      'color': Color(0xFF7C3AED)
    },
    {
      'value': 'vaccination',
      'label': 'Vaccination',
      'price': 150.0,
      'icon': '💉',
      'color': Color(0xFFDB2777)
    },
    {
      'value': 'minor_surgery',
      'label': 'Petite chirurgie',
      'price': 500.0,
      'icon': '🔪',
      'color': Color(0xFF991B1B)
    },
  ];

  @override
  void initState() {
    super.initState();
    _dueDateController.text = DateFormat('yyyy-MM-dd').format(
      DateTime.now().add(const Duration(days: 7)),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _floatingAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
          parent: _floatingAnimationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stepAnimationController.dispose();
    _floatingAnimationController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _dueDateController.dispose();
    _initialPaymentController.dispose();
    _notesController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
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
        _showSnackBar(
          'Error searching: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadAppointments() async {
    if (_selectedPatient == null) return;

    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.searchAppointments(
        patientId: _selectedPatient!.id!,
      );
      if (result is Success<List<AppointmentModel>>) {
        setState(() {
          _appointments = result.data;
        });
      } else {
        if (mounted) {
          _showSnackBar(
            'Error: ${(result as Failure).message}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error loading appointments: $e',
          isError: true,
        );
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

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatient == null) {
      _showSnackBar(
        'Please select a patient',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items = _items
          .map((item) => {
                'description': item.description,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
              })
          .toList();

      final invoiceService = ref.read(invoiceServiceProvider);
      await invoiceService.createInvoice(
        patientId: _selectedPatient!.id!,
        appointmentId: _selectedAppointment?.id,
        items: items,
        dueDate:
            _dueDateController.text.isNotEmpty ? _dueDateController.text : null,
        initialPayment: _initialPayment > 0 ? _initialPayment : null,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        _showSnackBar(
          'Invoice created successfully!',
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Error: $e',
          isError: true,
        );
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.check,
                color: isError ? Colors.red : Colors.green,
                size: 20,
              ),
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

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      _stepAnimationController.forward(from: 0);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} MAD';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E27) : const Color(0xFFF5F7FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Animated Background Gradient
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Color(0xFF0A0E27),
                                Color(0xFF1E293B).withOpacity(0.8),
                              ]
                            : [
                                Color(0xFFF5F7FA),
                                Color(0xFFE0E7FF).withOpacity(0.5),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Floating Orbs Background
            ...List.generate(3, (index) {
              return Positioned(
                top: 100.0 * index,
                right: index.isEven ? -100 : null,
                left: index.isOdd ? -100 : null,
                child: AnimatedBuilder(
                  animation: _floatingAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatingAnimation.value * (index + 1)),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (isDark ? Colors.blue : Colors.purple)
                                  .withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // Main Content
            Column(
              children: [
                // Glass Morphism App Bar
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Color(0xFF1E3A8A).withOpacity(0.9),
                              Color(0xFF3B82F6).withOpacity(0.8),
                            ]
                          : [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.pop(context),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.arrow_back_ios_new,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final localizations =
                                            AppLocalizations.of(context);
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'New Invoice',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Create an invoice for a patient',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
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
                          const SizedBox(height: 28),

                          // Enhanced Progress Indicator
                          Row(
                            children: List.generate(3, (index) {
                              return Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    final stepTitles = [
                                      'Patient',
                                      'Items',
                                      'Payment',
                                    ];
                                    return _buildEnhancedStepIndicator(
                                      index,
                                      stepTitles[index],
                                      [
                                        Icons.person_outline,
                                        Icons.receipt_long_outlined,
                                        Icons.payment_outlined
                                      ][index],
                                    );
                                  },
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Summary Card with Glass Effect
                if (_subtotal > 0)
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(isDark ? 0.1 : 0.9),
                                Colors.white.withOpacity(isDark ? 0.05 : 0.7),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return _buildSummaryItem(
                                        'Subtotal',
                                        _formatCurrency(_subtotal),
                                        Colors.blue,
                                        Icons.receipt_long,
                                      );
                                    },
                                  ),
                                ),
                                if (_initialPayment > 0) ...[
                                  Container(
                                    width: 1,
                                    height: 50,
                                    color: Colors.grey.withOpacity(0.3),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final localizations =
                                            AppLocalizations.of(context);
                                        return _buildSummaryItem(
                                          'Paid',
                                          _formatCurrency(_initialPayment),
                                          Colors.green,
                                          Icons.check_circle_outline,
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 50,
                                    color: Colors.grey.withOpacity(0.3),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final localizations =
                                            AppLocalizations.of(context);
                                        return _buildSummaryItem(
                                          'Remaining',
                                          _formatCurrency(_remaining),
                                          _remaining > 0
                                              ? Colors.orange
                                              : Colors.green,
                                          Icons.pending_outlined,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Page View Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPatientStep(),
                      _buildItemsStep(),
                      _buildPaymentStep(),
                    ],
                  ),
                ),

                // Enhanced Bottom Navigation with Glass Effect
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        (isDark ? Colors.black : Colors.white).withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: (isDark ? Color(0xFF1E293B) : Colors.white)
                            .withOpacity(0.9),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _previousStep,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.arrow_back, size: 20),
                                            const SizedBox(width: 8),
                                            Builder(
                                              builder: (context) {
                                                final localizations =
                                                    AppLocalizations.of(
                                                        context);
                                                return Text(
                                                  'Previous',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
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
                            if (_currentStep > 0) const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary
                                          .withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoading
                                        ? null
                                        : _currentStep == 2
                                            ? _createInvoice
                                            : _nextStep,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      child: _isLoading
                                          ? const Center(
                                              child: SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Builder(
                                                  builder: (context) {
                                                    final localizations =
                                                        AppLocalizations.of(
                                                            context);
                                                    return Text(
                                                      _currentStep == 2
                                                          ? 'Create Invoice'
                                                          : 'Next',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  _currentStep == 2
                                                      ? Icons.check
                                                      : Icons.arrow_forward,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStepIndicator(int step, String title, IconData icon) {
    final isActive = step <= _currentStep;
    final isCurrent = step == _currentStep;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
      builder: (context, value, child) {
        return Column(
          children: [
            Row(
              children: [
                if (step > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(value * 0.8),
                            Colors.white.withOpacity(value * 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: isCurrent ? 1.0 + (value * 0.1) : 1.0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isActive ? Color(0xFF6366F1) : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                if (step < 2)
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white
                                .withOpacity(step < _currentStep ? 0.8 : 0.2),
                            Colors.white
                                .withOpacity(step < _currentStep ? 0.4 : 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Patient Selection',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      'Search and select the patient',
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF374151)
                          : Colors.white,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchPatients,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email or CNI...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        suffixIcon: _isSearching
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6366F1),
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
                  if (_patients.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        return Text(
                          'Patients Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_patients.length, (index) {
                      final patient = _patients[index];
                      final isSelected = _selectedPatient?.id == patient.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Color(0xFF6366F1)
                                : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected
                              ? Color(0xFF6366F1).withOpacity(0.1)
                              : Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF374151)
                                  : Colors.white,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPatient = patient;
                              });
                              _loadAppointments();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF8B5CF6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patient.user?.name ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (patient.user?.email != null)
                                          Text(
                                            patient.user!.email!,
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
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF6366F1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  // Selected Patient Info
                  if (_selectedPatient != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF10B981).withOpacity(0.1),
                            Color(0xFF059669).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF10B981).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Text(
                                    'Patient Selected',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final localizations =
                                            AppLocalizations.of(context);
                                        return Text(
                                          'Name',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      _selectedPatient!.user?.name ?? 'N/A',
                                      style: TextStyle(
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
                                      Builder(
                                        builder: (context) {
                                          final localizations =
                                              AppLocalizations.of(context);
                                          return Text(
                                            'Email',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        _selectedPatient!.user!.email!,
                                        style: TextStyle(
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

                  // Appointments Section
                  if (_appointments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Builder(
                      builder: (context) {
                        return Text(
                          'Available Appointments (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_appointments.length, (index) {
                      final appointment = _appointments[index];
                      final isSelected =
                          _selectedAppointment?.id == appointment.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Color(0xFF8B5CF6)
                                : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected
                              ? Color(0xFF8B5CF6).withOpacity(0.1)
                              : Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF374151)
                                  : Colors.white,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedAppointment =
                                    isSelected ? null : appointment;
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
                                      color: Color(0xFF8B5CF6).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF8B5CF6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${appointment.appointmentDate} à ${appointment.appointmentTime}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (appointment.notes != null)
                                          Text(
                                            appointment.notes!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF8B5CF6),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF059669),
                              Color(0xFF10B981),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Invoice Items',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      'Add services and products',
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
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _addItem,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Services
                  Builder(
                    builder: (context) {
                      return Text(
                        'Predefined Services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _predefinedServices.map((service) {
                      return Container(
                        decoration: BoxDecoration(
                          color: service['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: service['color'].withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Add service to items
                              setState(() {
                                _items.add(InvoiceItemForm(
                                  initialDescription: service['label'],
                                  initialPrice: service['price'],
                                ));
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    service['icon'],
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service['label'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: service['color'],
                                        ),
                                      ),
                                      Text(
                                        '${service['price']} MAD',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Items List
                  Builder(
                    builder: (context) {
                      return Text(
                        'Items (${_items.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  ...List.generate(_items.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF374151)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6366F1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return Text(
                                      'Item ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_items.length > 1)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _removeItem(index),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Description Field
                          TextFormField(
                            controller: _items[index].descriptionController,
                            onChanged: (value) {
                              setState(() {
                                // Trigger real-time calculation update
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Description *',
                              hintText: 'Ex: General consultation',
                              prefixIcon: Icon(Icons.description_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color(0xFF4B5563)
                                  : Color(0xFFF9FAFB),
                            ),
                            validator: (value) {
                              final localizations =
                                  AppLocalizations.of(context);
                              if (value == null || value.isEmpty) {
                                return 'Description is required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              // Quantity Field
                              Expanded(
                                child: TextFormField(
                                  controller: _items[index].quantityController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      // Trigger real-time calculation update
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    prefixIcon: Icon(Icons.numbers),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color(0xFF4B5563)
                                        : Color(0xFFF9FAFB),
                                  ),
                                  validator: (value) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final quantity = int.tryParse(value);
                                    if (quantity == null || quantity <= 0) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Unit Price Field
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _items[index].unitPriceController,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  onChanged: (value) {
                                    setState(() {
                                      // Trigger real-time calculation update
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Unit Price (MAD) *',
                                    prefixIcon: Icon(Icons.attach_money),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color(0xFF4B5563)
                                        : Color(0xFFF9FAFB),
                                  ),
                                  validator: (value) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    if (value == null || value.isEmpty) {
                                      return 'Price is required';
                                    }
                                    final price = double.tryParse(value);
                                    if (price == null || price <= 0) {
                                      return 'Invalid price';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Total Display
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF6366F1).withOpacity(0.1),
                                  Color(0xFF8B5CF6).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return Text(
                                      'Item Total:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                                Text(
                                  _formatCurrency(_items[index].total),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFEA580C),
                                Color(0xFFF59E0B),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.payment,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Information',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        'Configure payment details',
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Due Date Field
                    TextFormField(
                      controller: _dueDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Due Date',
                        hintText: 'Select a date',
                        prefixIcon: Icon(Icons.calendar_today),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF374151)
                                : Color(0xFFF9FAFB),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final locale = ref.read(localeProvider).locale;
                          _dueDateController.text =
                              DateFormat('yyyy-MM-dd', locale.toString())
                                  .format(date);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Initial Payment Field
                    TextFormField(
                      controller: _initialPaymentController,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          // Trigger real-time calculation update
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Initial Payment (Optional)',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'MAD',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF374151)
                                : Color(0xFFF9FAFB),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final payment = double.tryParse(value);
                          if (payment == null || payment < 0) {
                            return 'Invalid amount';
                          }
                          if (payment > _subtotal) {
                            return 'Cannot exceed subtotal';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Payment Method
                    Builder(
                      builder: (context) {
                        return Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    Builder(
                      builder: (context) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildPaymentMethodChip(
                                'cash', 'Cash', Icons.money),
                            _buildPaymentMethodChip(
                                'credit_card', 'Card', Icons.credit_card),
                            _buildPaymentMethodChip('bank_transfer',
                                'Bank Transfer', Icons.account_balance),
                            _buildPaymentMethodChip(
                                'insurance', 'Insurance', Icons.local_hospital),
                            _buildPaymentMethodChip('mobile_payment', 'Mobile',
                                Icons.phone_android),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Notes Field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add notes on this invoice...',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.note_outlined),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF374151)
                                : Color(0xFFF9FAFB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Color(0xFF6366F1)
            : Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF374151)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Color(0xFF6366F1) : Colors.grey.withOpacity(0.3),
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

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(isDark ? 0.1 : 0.9),
                Colors.white.withOpacity(isDark ? 0.05 : 0.7),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: child,
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
    double? initialPrice,
  })  : descriptionController =
            TextEditingController(text: initialDescription ?? ''),
        quantityController = TextEditingController(text: '1'),
        unitPriceController =
            TextEditingController(text: initialPrice?.toString() ?? '');

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
