import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../core/utils/result.dart';
import '../providers/api_providers.dart';
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import 'create_invoice_screen.dart';
import 'create_invoice_screen_nextjs.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  List<Invoice> _invoices = [];
  InvoiceStatistics? _statistics;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  String _statusFilter = 'all';
  String _timeRange = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.getInvoices(
        page: _currentPage,
        search:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        status: _statusFilter != 'all' ? _statusFilter : null,
        timeRange: _timeRange != 'all' ? _timeRange : null,
      );

      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        setState(() {
          _invoices = data['invoices'] as List<Invoice>;
          _statistics = data['statistics'] as InvoiceStatistics?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = (result as Failure).message;
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

  String _formatCurrency(double? amount) {
    if (amount == null) return '0.00 MAD';
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
    final canCreateInvoice = user?.isAdmin == 1 || user?.isAccountant == 1;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
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
                            const Color(0xFF8B5CF6),
                          ]
                        : [
                            const Color(0xFF3B82F6),
                            const Color(0xFF8B5CF6),
                            const Color(0xFFEC4899),
                          ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.receipt_long,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Invoices',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'Invoice Management',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            if (canCreateInvoice)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            const CreateInvoiceScreen(),
                                        transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) {
                                          return SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(1.0, 0.0),
                                              end: Offset.zero,
                                            ).animate(CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeInOut,
                                            )),
                                            child: child,
                                          );
                                        },
                                      ),
                                    ).then((_) => _loadInvoices());
                                  },
                                  icon: const Icon(
                                    Icons.add,
                                    color: Color(0xFF3B82F6),
                                    size: 28,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Statistics Cards
                        if (_statistics != null)
                          Row(
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return _buildStatCard(
                                      'Total',
                                      _formatCurrency(_statistics!.totalAmount),
                                      Icons.account_balance_wallet,
                                      const Color(0xFF3B82F6),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return _buildStatCard(
                                      'Paid',
                                      _formatCurrency(
                                          _statistics!.totalPayments),
                                      Icons.check_circle,
                                      const Color(0xFF10B981),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final localizations =
                                        AppLocalizations.of(context);
                                    return _buildStatCard(
                                      'Pending',
                                      _formatCurrency(_statistics!.totalDue),
                                      Icons.access_time,
                                      const Color(0xFFF59E0B),
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

          // Search and Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search Bar
                  Container(
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
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // Debounce search
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value) {
                            _loadInvoices();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search invoice...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.colorScheme.primary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return _buildFilterChip(
                                'All', 'all', _statusFilter);
                          },
                        ),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return _buildFilterChip(
                                'Paid', 'paid', _statusFilter);
                          },
                        ),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return _buildFilterChip(
                                'Pending', 'pending', _statusFilter);
                          },
                        ),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return _buildFilterChip(
                                'Overdue', 'overdue', _statusFilter);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Invoices List
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
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
                      onPressed: _loadInvoices,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_invoices.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return const Text(
                          'No invoices found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          'Start by creating your first invoice',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                    if (canCreateInvoice) ...[
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateInvoiceScreenNextJS(),
                                ),
                              ).then((_) => _loadInvoices());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Invoice'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final invoice = _invoices[index];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      child: _buildInvoiceCard(invoice, isDark),
                    );
                  },
                  childCount: _invoices.length,
                ),
              ),
            ),

          // Bottom Padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue) {
    final isSelected = currentValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _statusFilter = value;
          });
          _loadInvoices();
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        checkmarkColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, bool isDark) {
    final statusColor = _getStatusColor(invoice.status);
    final statusIcon = _getStatusIcon(invoice.status);
    final statusText = _getStatusText(invoice.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    InvoiceDetailScreen(invoiceId: invoice.id),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    )),
                    child: child,
                  );
                },
              ),
            ).then((_) => _loadInvoices());
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
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
                              return Text(
                                'Invoice #${invoice.id}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          Text(
                            invoice.patient?.user?.name ?? 'Unknown Patient',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                            Text(
                              _formatCurrency(invoice.amount),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                            Text(
                              _formatCurrency(invoice.paid),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Due Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                            Text(
                              invoice.dueDate ?? 'Not set',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
  }
}
