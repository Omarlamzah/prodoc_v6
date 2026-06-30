import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import '../data/models/patient_model.dart';
import '../data/models/service_model.dart';
import '../providers/patient_providers.dart';
import '../providers/api_providers.dart';
import '../providers/service_providers.dart';
import '../providers/locale_providers.dart';
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../models/invoice.dart';
import '../core/config/api_constants.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
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
  int _currentStep = 0; // 0: Patient, 1: Items, 2: Payment, 3: Review
  Set<String> _expandedItems = {}; // Track which items are expanded

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchController.addListener(_onSearchChanged);
    _initialPaymentController.addListener(() => setState(() {}));
    // Set default due date (7 days from today)
    final defaultDueDate = DateTime.now().add(const Duration(days: 7));
    _dueDateController.text = DateFormat('yyyy-MM-dd').format(defaultDueDate);
    // Expand the first item by default
    if (_items.isNotEmpty) {
      _expandedItems.add(_items.first.id);
    }
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
      final newItem = InvoiceItemForm();
      _items.add(newItem);
      // Auto-expand newly added items
      _expandedItems.add(newItem.id);
    });
  }

  void _toggleItemExpansion(String itemId) {
    setState(() {
      if (_expandedItems.contains(itemId)) {
        _expandedItems.remove(itemId);
      } else {
        _expandedItems.add(itemId);
      }
    });
  }

  void _duplicateItem(int index) {
    final itemToCopy = _items[index];
    setState(() {
      final newItem = InvoiceItemForm(
        initialDescription: itemToCopy.descriptionController.text,
        initialPrice: itemToCopy.unitPriceController.text,
      );
      _items.insert(index + 1, newItem);
      // Auto-expand duplicated items
      _expandedItems.add(newItem.id);
    });
    _showSnackBar('Item duplicated', isError: false);
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        final itemToRemove = _items[index];
        _expandedItems.remove(itemToRemove.id);
        itemToRemove.dispose();
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

  void _setQuickPayment(double percentage) {
    if (_subtotal > 0) {
      final amount = (_subtotal * percentage / 100).toStringAsFixed(2);
      setState(() {
        _initialPaymentController.text = amount;
      });
      if (percentage >= 100) {
        _checkAutoSetDueDate();
      }
    }
  }

  int get _formCompletionPercentage {
    int completed = 0;
    int total = 4; // patient, items, payment info, due date

    if (_selectedPatient != null) completed++;
    if (_items.isNotEmpty &&
        _items.every((item) =>
            item.descriptionController.text.isNotEmpty &&
            item.unitPriceController.text.isNotEmpty)) completed++;
    if (_dueDateController.text.isNotEmpty) completed++;
    if (_initialPaymentController.text.isNotEmpty || _subtotal == 0)
      completed++;

    return ((completed / total) * 100).round();
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
      _currentStep = 0;
    });
    _showSnackBar('Form reset', isError: false);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate patient selection
      if (_selectedPatient == null) {
        _showSnackBar('Please select a patient', isError: true);
        return;
      }
    } else if (_currentStep == 1) {
      // Validate items
      if (_items.isEmpty ||
          _items.any((item) =>
              item.descriptionController.text.isEmpty ||
              item.unitPriceController.text.isEmpty)) {
        _showSnackBar('Please fill all invoice items', isError: true);
        return;
      }
    } else if (_currentStep == 2) {
      // Validate payment info
      if (_initialPayment > _subtotal) {
        _showSnackBar('Initial payment cannot exceed total amount',
            isError: true);
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
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
      final result = await invoiceService.createInvoice(
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
        result.when(
          success: (invoice) {
            _showSuccessDialog(context, invoice);
          },
          failure: (message) {
            _showSnackBar('Error creating invoice: $message', isError: true);
          },
        );
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

  void _showSuccessDialog(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Facture créée avec succès!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'La facture a été créée et le PDF a été généré.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close success dialog
                      Navigator.of(context)
                          .pop(); // Close create invoice screen
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Invoice Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green[200]!,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInvoiceDetailRow(
                      'Numéro de facture:',
                      '#${invoice.id}',
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    _buildInvoiceDetailRow(
                      'Patient:',
                      invoice.patient?.user?.name ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildInvoiceDetailRow(
                      'Montant total:',
                      _formatCurrency(invoice.amount),
                      valueColor: Colors.green[700],
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Statut:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        _buildStatusBadge(invoice.status),
                      ],
                    ),
                    if (invoice.paid > 0) ...[
                      const SizedBox(height: 12),
                      _buildInvoiceDetailRow(
                        'Payé:',
                        _formatCurrency(invoice.paid),
                        valueColor: Colors.blue[700],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _viewInvoicePdf(invoice.id),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Voir le PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadInvoicePdf(invoice.id),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Télécharger'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Encrypted file download (if available)
              if (invoice.pdfPath != null && invoice.pdfPath!.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _downloadEncryptedFile(invoice.pdfPath!),
                  icon: const Icon(Icons.lock, size: 16),
                  label: const Text(
                    'Télécharger fichier chiffré (vérification)',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'paid':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        label = 'Payée';
        icon = Icons.check_circle;
        break;
      case 'partial':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        label = 'Partielle';
        icon = Icons.access_time;
        break;
      default:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        label = 'Non payée';
        icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewInvoicePdf(int invoiceId) async {
    await _downloadAndOpenPdf(invoiceId, openAfterDownload: true);
  }

  Future<void> _downloadInvoicePdf(int invoiceId) async {
    await _downloadAndOpenPdf(invoiceId, openAfterDownload: false);
  }

  Future<void> _downloadAndOpenPdf(int invoiceId,
      {required bool openAfterDownload}) async {
    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      // Get auth token
      final authState = ref.read(authProvider);
      final apiUrl =
          '${ApiConstants.baseUrl}${ApiConstants.invoicePdf(invoiceId)}';
      final uri = Uri.parse(apiUrl);

      final headers = <String, String>{};
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the PDF
      final response = await http.get(uri, headers: headers);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (response.statusCode == 200) {
        final fileName = 'facture_$invoiceId.pdf';

        if (kIsWeb) {
          // For web, trigger browser download
          final blobUrl = Uri.dataFromBytes(
            response.bodyBytes,
            mimeType: 'application/pdf',
          );
          await launchUrl(blobUrl, mode: LaunchMode.platformDefault);

          if (mounted) {
            _showSnackBar(
              openAfterDownload
                  ? 'PDF ouvert dans le navigateur'
                  : 'PDF téléchargé avec succès',
              isError: false,
            );
          }
        } else {
          // For mobile, save to temporary directory first, then share/open
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            // Use share_plus to share/open the file
            // This allows users to open with PDF viewer or save to Downloads
            final xFile = XFile(filePath, mimeType: 'application/pdf');

            if (openAfterDownload) {
              // Share with option to open
              await Share.shareXFiles(
                [xFile],
                text: 'Facture #$invoiceId',
                subject: 'Facture PDF',
              );
              _showSnackBar(
                'Ouvrez le PDF depuis le menu de partage',
                isError: false,
              );
            } else {
              // Share for saving
              await Share.shareXFiles(
                [xFile],
                text: 'Facture #$invoiceId',
                subject: 'Facture PDF',
              );
              _showSnackBar(
                'Sauvegardez le PDF depuis le menu de partage',
                isError: false,
              );
            }
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'Erreur lors du téléchargement: ${response.statusCode}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close loading dialog if still open
        }
        _showSnackBar('Erreur: $e', isError: true);
      }
    }
  }

  Future<void> _downloadEncryptedFile(String pdfPath) async {
    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      // Get auth token
      final authState = ref.read(authProvider);
      final apiUrl = '${ApiConstants.baseUrl}/api/b2/download-raw-encrypted';
      final uri = Uri.parse(apiUrl);

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (authState.token != null) {
        headers['Authorization'] = 'Bearer ${authState.token}';
      }

      // Download the encrypted file
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'file_name': pdfPath}),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (response.statusCode == 200) {
        final fileName =
            'encrypted_facture_${DateTime.now().millisecondsSinceEpoch}.bin';

        if (kIsWeb) {
          // For web, trigger browser download
          final blobUrl = Uri.dataFromBytes(
            response.bodyBytes,
            mimeType: 'application/octet-stream',
          );
          await launchUrl(blobUrl, mode: LaunchMode.platformDefault);

          if (mounted) {
            _showSnackBar(
              'Fichier chiffré téléchargé (non lisible - format chiffré)',
              isError: false,
            );
          }
        } else {
          // For mobile, save to Downloads directory
          Directory? directory;
          try {
            if (Platform.isAndroid) {
              directory = Directory('/storage/emulated/0/Download');
              if (!await directory.exists()) {
                directory = await getApplicationDocumentsDirectory();
              }
            } else if (Platform.isIOS) {
              directory = await getApplicationDocumentsDirectory();
            } else {
              directory = await getApplicationDocumentsDirectory();
            }
          } catch (e) {
            directory = await getApplicationDocumentsDirectory();
          }

          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            _showSnackBar(
              'Fichier chiffré téléchargé (non lisible - format chiffré)',
              isError: false,
            );
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'Erreur lors du téléchargement: ${response.statusCode}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close loading dialog if still open
        }
        _showSnackBar('Erreur: $e', isError: true);
      }
    }
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
      floatingActionButton: _currentStep == 1
          ? Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return FloatingActionButton.extended(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(localizations?.addItem ?? 'Add Item'),
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                );
              },
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // Fixed Calculation Summary at Top (Sticky)
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 600;
              return SliverPersistentHeader(
                pinned: true,
                delegate: _CalculationSummaryDelegate(
                  isMobile: isMobile,
                  builder: (context) => Container(
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
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 20,
                            vertical: isMobile ? 10 : 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: isMobile ? 20 : 24,
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calculate,
                                        color: Colors.white,
                                        size: isMobile ? 16 : 20,
                                      ),
                                      SizedBox(width: isMobile ? 6 : 8),
                                      Flexible(
                                        child: Text(
                                          'Calculation Summary',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isMobile ? 14 : 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isFullyPaid)
                                  Flexible(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 6 : 12,
                                        vertical: isMobile ? 3 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: isMobile ? 12 : 16,
                                          ),
                                          SizedBox(width: isMobile ? 3 : 4),
                                          Flexible(
                                            child: Text(
                                              'Fully Paid',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isMobile ? 9 : 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // Use 2x2 grid on mobile, 4 columns on larger screens
                                if (isMobile) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                          SizedBox(width: isMobile ? 4 : 6),
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
                                      SizedBox(height: isMobile ? 4 : 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildSummaryCard(
                                              'Payment',
                                              _formatCurrency(_initialPayment),
                                              Icons.wallet,
                                              Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: isMobile ? 4 : 6),
                                          Expanded(
                                            child: _buildSummaryCard(
                                              'Remaining',
                                              _formatCurrency(_remaining > 0
                                                  ? _remaining
                                                  : 0),
                                              Icons.trending_up,
                                              _remaining > 0
                                                  ? Colors.amber
                                                  : Colors.greenAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _buildSummaryCard(
                                          'Subtotal',
                                          _formatCurrency(_subtotal),
                                          Icons.receipt,
                                          Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildSummaryCard(
                                          'Payment',
                                          _formatCurrency(_initialPayment),
                                          Icons.wallet,
                                          Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildSummaryCard(
                                          'Remaining',
                                          _formatCurrency(
                                              _remaining > 0 ? _remaining : 0),
                                          Icons.trending_up,
                                          _remaining > 0
                                              ? Colors.amber
                                              : Colors.greenAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildSummaryCard(
                                          'Paid',
                                          '${_percentagePaid.toStringAsFixed(0)}%',
                                          Icons.percent,
                                          Colors.white,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width < 600 ? 12 : 20,
                  right: MediaQuery.of(context).size.width < 600 ? 12 : 20,
                  top: 16,
                  bottom: 100, // Extra padding at bottom for navigation buttons
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Indicator Header
                    _buildStepIndicator(isDark),
                    const SizedBox(height: 24),

                    // Step Content
                    _buildStepContent(isDark),

                    const SizedBox(height: 24),

                    // Navigation Buttons
                    _buildNavigationButtons(isDark),

                    const SizedBox(
                        height: 24), // Extra space at the very bottom
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Patient(isDark);
      case 1:
        return _buildStep2Items(isDark);
      case 2:
        return _buildStep3Payment(isDark);
      case 3:
        return _buildStep4Review(isDark);
      default:
        return _buildStep1Patient(isDark);
    }
  }

  Widget _buildStep1Patient(bool isDark) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Patient Information',
            Icons.person,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search patient by name, email or CNI...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Patient Results
          if (_patients.isNotEmpty && _selectedPatient == null)
            ..._patients.asMap().entries.map((entry) {
              final patient = entry.value;
              final index = entry.key;
              return Container(
                key: ValueKey('patient_result_${patient.id}_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : Colors.grey[50],
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
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _selectedPatient!.user?.name ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedPatient!.user?.email != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        _selectedPatient!.user!.email!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2Items(bool isDark) {
    return Column(
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Invoice Items',
                Icons.receipt,
                const Color(0xFF4F46E5),
              ),
              // Service Selector
              if (_services.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedServiceId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select a service to add',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF374151) : Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: _services.map((service) {
                      return DropdownMenuItem<String>(
                        value: service.id.toString(),
                        child: Text(
                          '${service.title} - ${(service.price ?? 0).toStringAsFixed(2)} MAD',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: _handleServiceSelect,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item Manually'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items List
              ...List.generate(_items.length, (index) {
                return _buildItemCard(index);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Payment(bool isDark) {
    return Column(
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Payment Information',
                Icons.payment,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 16),

              // Due Date and Initial Payment Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  if (isMobile) {
                    // Mobile: Stack vertically
                    return Column(
                      children: [
                        Column(
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
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF374151)
                                    : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
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
                                    _dueDateController.text = DateFormat(
                                            'yyyy-MM-dd', locale.toString())
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
                                    Flexible(
                                      child: Text(
                                        'Auto-set to today (fully paid)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.wallet, size: 16),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Initial Payment (MAD)',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_subtotal > 0) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildQuickPaymentButton('25%', 25),
                                  _buildQuickPaymentButton('50%', 50),
                                  _buildQuickPaymentButton('75%', 75),
                                  _buildQuickPaymentButton('100%', 100,
                                      isFull: true),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _initialPaymentController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixIcon: const Icon(Icons.attach_money),
                                suffixText: 'MAD',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF374151)
                                    : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
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
                      ],
                    );
                  } else {
                    // Desktop: Horizontal layout
                    return Row(
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
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
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
                                      _dueDateController.text = DateFormat(
                                              'yyyy-MM-dd', locale.toString())
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
                                      Flexible(
                                        child: Text(
                                          'Auto-set to today (fully paid)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                                  Flexible(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.wallet, size: 16),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Initial Payment (MAD)',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_subtotal > 0) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildQuickPaymentButton('25%', 25),
                                    _buildQuickPaymentButton('50%', 50),
                                    _buildQuickPaymentButton('75%', 75),
                                    _buildQuickPaymentButton('100%', 100,
                                        isFull: true),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _initialPaymentController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixIcon: const Icon(Icons.attach_money),
                                  suffixText: 'MAD',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
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
                    );
                  }
                },
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
                  _buildPaymentMethodChip('cash', 'Cash', Icons.money),
                  _buildPaymentMethodChip(
                      'credit_card', 'Credit Card', Icons.credit_card),
                  _buildPaymentMethodChip(
                      'bank_transfer', 'Bank Transfer', Icons.account_balance),
                  _buildPaymentMethodChip(
                      'insurance', 'Insurance', Icons.local_hospital),
                  _buildPaymentMethodChip(
                      'mobile_payment', 'Mobile', Icons.phone_android),
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
                  fillColor: isDark ? const Color(0xFF374151) : Colors.grey[50],
                ),
              ),
            ],
          ),
        ),
        // Payment Status Alert
        if (_remaining > 0 && _initialPayment > 0)
          Container(
            margin: const EdgeInsets.only(top: 16),
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
      ],
    );
  }

  Widget _buildStep4Review(bool isDark) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Review Invoice Details',
            Icons.check_circle,
            Colors.green,
          ),
          const SizedBox(height: 20),
          // Patient Info
          _buildReviewSection(
            'Patient',
            Icons.person,
            [
              _selectedPatient?.user?.name ?? 'N/A',
              _selectedPatient?.user?.email ?? 'N/A',
            ],
          ),
          const Divider(height: 32),
          // Items
          _buildReviewSection(
            'Invoice Items (${_items.length})',
            Icons.receipt,
            _items.map((item) {
              final qty = item.quantity;
              final price = item.unitPrice;
              final total = qty * price;
              return '${item.description} - ${qty}x ${_formatCurrency(price)} = ${_formatCurrency(total)}';
            }).toList(),
          ),
          const Divider(height: 32),
          // Payment Info
          _buildReviewSection(
            'Payment Information',
            Icons.payment,
            [
              'Due Date: ${_dueDateController.text.isEmpty ? "Not set" : _dueDateController.text}',
              'Initial Payment: ${_formatCurrency(_initialPayment)}',
              'Payment Method: ${_paymentMethod.replaceAll('_', ' ').toUpperCase()}',
              if (_notesController.text.isNotEmpty)
                'Notes: ${_notesController.text}',
            ],
          ),
          const Divider(height: 32),
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildReviewRow('Subtotal', _formatCurrency(_subtotal)),
                const SizedBox(height: 8),
                _buildReviewRow('Paid', _formatCurrency(_initialPayment)),
                const SizedBox(height: 8),
                _buildReviewRow('Remaining', _formatCurrency(_remaining),
                    isBold: true,
                    color: _remaining > 0 ? Colors.orange : Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, IconData icon, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 8),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: _currentStep == 0 ? 1 : 2,
          child: ElevatedButton.icon(
            onPressed: _currentStep == 3
                ? (_isLoading ||
                        _selectedPatient == null ||
                        _items.any((item) =>
                            item.descriptionController.text.isEmpty ||
                            item.unitPriceController.text.isEmpty) ||
                        (_initialPaymentController.text.isNotEmpty &&
                            _initialPayment > _subtotal))
                    ? null
                    : _createInvoice
                : _nextStep,
            icon: Icon(
              _currentStep == 3 ? Icons.check_circle : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(_currentStep == 3 ? 'Create Invoice' : 'Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color textColor) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 2 : 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 13 : 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.grey.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    final steps = [
      {'title': 'Patient', 'icon': Icons.person},
      {'title': 'Items', 'icon': Icons.receipt},
      {'title': 'Payment', 'icon': Icons.payment},
      {'title': 'Review', 'icon': Icons.check_circle},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.grey.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          final step = steps[index];

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green
                              : isActive
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : step['icon'] as IconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive || isCompleted
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green
                            : index < _currentStep
                                ? Colors.grey[300]
                                : Colors.grey[200],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: isMobile ? 18 : 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isExpanded = _expandedItems.contains(item.id);
    final hasContent = item.descriptionController.text.isNotEmpty ||
        item.unitPriceController.text.isNotEmpty;

    return Container(
      key: ValueKey('invoice_item_${item.id}'),
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed Header (always visible)
          InkWell(
            onTap: () => _toggleItemExpansion(item.id),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 14 : 16),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Item ${index + 1}',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            if (hasContent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Filled',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (!isExpanded && hasContent) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.descriptionController.text.isNotEmpty
                                ? item.descriptionController.text
                                : 'No description',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity}x ${_formatCurrency(item.unitPrice)} = ${_formatCurrency(item.total)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isExpanded) ...[
                        IconButton(
                          onPressed: () => _duplicateItem(index),
                          icon: Icon(Icons.copy,
                              color: Colors.blue[700], size: 18),
                          tooltip: 'Duplicate',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (_items.length > 1)
                          IconButton(
                            onPressed: () => _removeItem(index),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            tooltip: 'Remove',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Selector for this item
                  if (_services.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select a service (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        items: _services.map((service) {
                          return DropdownMenuItem<String>(
                            value: service.id.toString(),
                            child: Text(
                              '${service.title} - ${(service.price ?? 0).toStringAsFixed(2)} MAD',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            _handleItemServiceSelect(index, value),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Description
                  TextFormField(
                    controller: item.descriptionController,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      hintText: 'e.g., Consultation, Treatment, Medication...',
                      helperText: 'Describe the service or item',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Quantity and Unit Price Row
                  Row(
                    children: [
                      Expanded(
                        flex: isMobile ? 1 : 2,
                        child: TextFormField(
                          controller: item.quantityController,
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            hintText: '1',
                            helperText: 'Number of units',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
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
                      const SizedBox(width: 12),
                      Expanded(
                        flex: isMobile ? 2 : 3,
                        child: TextFormField(
                          controller: item.unitPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Price (MAD) *',
                            hintText: '0.00',
                            helperText: 'Unit price per item',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price < 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Item Total
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatCurrency(item.total),
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildQuickPaymentButton(String label, double percentage,
      {bool isFull = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final currentAmount = _initialPayment;
    final targetAmount = _subtotal * percentage / 100;
    final isSelected =
        (currentAmount - targetAmount).abs() < 0.01 && _subtotal > 0;

    return GestureDetector(
      onTap: () => _setQuickPayment(percentage),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isFull ? Colors.green : const Color(0xFF3B82F6))
              : (isDark ? const Color(0xFF374151) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isFull ? Colors.green : const Color(0xFF3B82F6))
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}

// Delegate for sticky calculation summary header
class _CalculationSummaryDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(BuildContext) builder;
  final bool isMobile;

  _CalculationSummaryDelegate({required this.builder, required this.isMobile});

  @override
  double get minExtent => isMobile ? 260 : 170;

  @override
  double get maxExtent => isMobile ? 260 : 170;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: minExtent,
      child: builder(context),
    );
  }

  @override
  bool shouldRebuild(_CalculationSummaryDelegate oldDelegate) {
    return isMobile != oldDelegate.isMobile;
  }
}

// Invoice Item Form Class
class InvoiceItemForm {
  final String id;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  InvoiceItemForm({
    String? initialDescription,
    String? initialPrice,
  })  : id = DateTime.now().millisecondsSinceEpoch.toString(),
        descriptionController =
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
