import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../core/utils/result.dart';
import '../providers/api_providers.dart';
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen>
    with TickerProviderStateMixin {
  Invoice? _invoice;
  List<Payment> _payments = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoiceDetails();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final invoiceService = ref.read(invoiceServiceProvider);
      final invoiceResult = await invoiceService.getInvoice(widget.invoiceId);
      final paymentsResult =
          await invoiceService.getInvoicePayments(widget.invoiceId);

      if (invoiceResult is Success<Invoice> &&
          paymentsResult is Success<List<Payment>>) {
        setState(() {
          _invoice = invoiceResult.data;
          _payments = paymentsResult.data;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _error = 'Failed to load invoice details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.downloadInvoicePdf(widget.invoiceId);

      if (mounted) {
        if (result is Success<String>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF downloaded: ${result.data}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  final uri = Uri.file(result.data);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${(result as Failure).message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendReminder() async {
    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.sendDueReminder(widget.invoiceId);

      if (mounted) {
        if (result is Success<String>) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Rappel envoyé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${(result as Failure).message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sending: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} MAD';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.access_time;
      case 'overdue':
        return Icons.warning;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  String _getStatusText(String status) {
    final localizations = AppLocalizations.of(context);
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'overdue':
        return 'Overdue';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final canManageInvoices = user?.isAdmin == 1 || user?.isAccountant == 1;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInvoiceDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
        body: const Center(
          child: const Text('Invoice not found'),
        ),
      );
    }

    final statusColor = _getStatusColor(_invoice!.status);
    final statusIcon = _getStatusIcon(_invoice!.status);
    final statusText = _getStatusText(_invoice!.status);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 280,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                actions: [
                  if (canManageInvoices) ...[
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf,
                            color: Colors.white),
                      ),
                    ),
                    if (_invoice!.status != 'paid')
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _sendReminder,
                          icon: const Icon(Icons.notifications_active,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF1E3A8A),
                                const Color(0xFF3B82F6),
                                statusColor.withOpacity(0.8),
                              ]
                            : [
                                const Color(0xFF3B82F6),
                                statusColor,
                                statusColor.withOpacity(0.8),
                              ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 60), // Space for app bar
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    statusIcon,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final localizations =
                                              AppLocalizations.of(context);
                                          final locale =
                                              ref.watch(localeProvider).locale;
                                          return Text(
                                            'Invoice #${_invoice!.id}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final localizations =
                                              AppLocalizations.of(context);
                                          final locale =
                                              ref.watch(localeProvider).locale;
                                          return Text(
                                            'Created on ${DateFormat('dd/MM/yyyy', locale.toString()).format(DateTime.parse(_invoice!.createdAt))}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Amount Cards
                            Row(
                              children: [
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return _buildAmountCard(
                                        'Total Amount',
                                        _formatCurrency(_invoice!.amount),
                                        Icons.account_balance_wallet,
                                        Colors.white.withOpacity(0.9),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return _buildAmountCard(
                                        'Paid',
                                        _formatCurrency(_invoice!.paid),
                                        Icons.check_circle,
                                        Colors.green.withOpacity(0.9),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return _buildAmountCard(
                                        'Remaining',
                                        _formatCurrency(
                                            _invoice!.amount - _invoice!.paid),
                                        Icons.pending,
                                        Colors.orange.withOpacity(0.9),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Patient Info Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return const Text(
                                      '👤 Patient Information',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              final locale = ref.watch(localeProvider).locale;
                              return Column(
                                children: [
                                  _buildInfoRow(
                                    '👤 Name',
                                    _invoice!.patient?.user?.name ?? 'N/A',
                                    Icons.person,
                                  ),
                                  _buildInfoRow(
                                    '📧 Email',
                                    _invoice!.patient?.user?.email ?? 'N/A',
                                    Icons.email,
                                  ),
                                  if (_invoice!.appointment != null)
                                    _buildInfoRow(
                                      '📅 Appointment',
                                      'Appointment: ${DateFormat('dd/MM/yyyy', locale.toString()).format(DateTime.parse(_invoice!.appointment!.appointmentDate!))} at ${_invoice!.appointment!.appointmentTime!}',
                                      Icons.calendar_today,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Tab Bar
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Tab(
                            icon: Icon(Icons.list_alt),
                            text: 'Items',
                          );
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Tab(
                            icon: Icon(Icons.payment),
                            text: 'Payments',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Content
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildItemsTab(),
                      _buildPaymentsTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Floating Action Button for Payment
      floatingActionButton: canManageInvoices && _invoice!.status != 'paid'
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _PaymentDialog(
                      invoice: _invoice!,
                      onPaymentRecorded: _loadInvoiceDetails,
                    ),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return const Text(
                      'Record Payment',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAmountCard(
      String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text(
              '📋 Invoiced Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _invoice!.items.length,
            itemBuilder: (context, index) {
              final item = _invoice!.items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF374151)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${item.quantity} × ${_formatCurrency(item.unitPrice)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency(item.total),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return const Text(
              '💳 Payment History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.payment,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Column(
                            children: [
                              const Text(
                                'No payments recorded',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Payments will appear here',
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
                )
              : ListView.builder(
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final payment = _payments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF374151)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
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
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatCurrency(payment.amount ?? 0),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return Text(
                                        payment.paymentMethod ??
                                            'Unknown method',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final localizations =
                                          AppLocalizations.of(context);
                                      return Text(
                                        payment.paymentDate != null
                                            ? 'On ${payment.paymentDate}'
                                            : 'Unknown date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PaymentDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final VoidCallback onPaymentRecorded;

  const _PaymentDialog({
    required this.invoice,
    required this.onPaymentRecorded,
  });

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final remaining = widget.invoice.amount - widget.invoice.paid;
    _amountController.text = remaining.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.recordPayment(
        invoiceId: widget.invoice.id,
        amount: double.parse(_amountController.text),
        paymentDate: _dateController.text,
        paymentMethod: _paymentMethod,
      );

      if (mounted) {
        if (result is Success<Payment>) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Paiement enregistré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onPaymentRecorded();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${(result as Failure).message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.invoice.amount - widget.invoice.paid;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.05),
              Colors.green.withOpacity(0.05),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payment,
                      color: Colors.green,
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
                            final localizations = AppLocalizations.of(context);
                            return const Text(
                              '💳 Record Payment',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        Text(
                          'Facture #${widget.invoice.id}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Remaining Amount Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return const Text(
                                'Remaining Amount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              );
                            },
                          ),
                          Text(
                            '${remaining.toStringAsFixed(2)} MAD',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (MAD) *',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount required';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Invalid amount';
                  }
                  if (amount > remaining) {
                    return 'Amount exceeds remaining balance';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date Field
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Payment Date *',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    _dateController.text =
                        DateFormat('yyyy-MM-dd').format(date);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Payment Method
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: const Icon(Icons.payment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('💵 Cash')),
                  DropdownMenuItem(
                      value: 'credit_card', child: Text('💳 Credit Card')),
                  DropdownMenuItem(
                      value: 'bank_transfer', child: Text('🏦 Bank Transfer')),
                  DropdownMenuItem(
                      value: 'insurance', child: Text('🏥 Insurance')),
                  DropdownMenuItem(
                      value: 'mobile_payment',
                      child: Text('📱 Mobile Payment')),
                ],
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
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
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _recordPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
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
                          : const Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
