import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../core/utils/result.dart';
import '../providers/api_providers.dart';
import '../screens/create_invoice_screen.dart';
import '../screens/invoice_detail_screen_modern.dart';

class InvoicesScreenModern extends ConsumerStatefulWidget {
  const InvoicesScreenModern({super.key});

  @override
  ConsumerState<InvoicesScreenModern> createState() =>
      _InvoicesScreenModernState();
}

class _InvoicesScreenModernState extends ConsumerState<InvoicesScreenModern>
    with TickerProviderStateMixin {
  List<Invoice> _invoices = [];
  InvoiceStatistics? _statistics;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _timeRange = 'all';
  int _currentPage = 1;

  late AnimationController _animationController;
  late AnimationController _floatingController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadInvoices();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _refreshController = AnimationController(
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
      curve: Curves.easeOutCubic,
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _floatingAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    _refreshController.dispose();
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
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
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
        _error = 'Erreur lors du chargement: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    _refreshController.forward(from: 0);
    await _loadInvoices();
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} MAD';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF10B981);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'unpaid':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'partial':
        return 'Partielle';
      case 'unpaid':
        return 'Non payée';
      default:
        return 'Inconnu';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'partial':
        return Icons.schedule;
      case 'unpaid':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Animated Background
            _buildAnimatedBackground(isDark),

            // Main Content
            CustomScrollView(
              slivers: [
                // Modern App Bar
                _buildModernAppBar(isDark),

                // Statistics Section
                if (_statistics != null) _buildStatisticsSection(isDark),

                // Search and Filters
                _buildSearchAndFilters(isDark),

                // Invoices List
                _buildInvoicesList(isDark),
              ],
            ),

            // Floating Action Button
            _buildFloatingActionButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark) {
    return Positioned.fill(
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
                        const Color(0xFF0A0E27),
                        const Color(0xFF1E293B).withOpacity(0.8),
                      ]
                    : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFE0E7FF).withOpacity(0.3),
                      ],
              ),
            ),
            child: Stack(
              children: List.generate(4, (index) {
                return Positioned(
                  top: 150.0 * index - 100,
                  right: index.isEven ? -150 + _floatingAnimation.value : null,
                  left: index.isOdd ? -150 - _floatingAnimation.value : null,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark ? Colors.blue : Colors.purple)
                              .withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark) {
    return SliverAppBar(
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
                      const Color(0xFF1E3A8A).withOpacity(0.9),
                      const Color(0xFF3B82F6).withOpacity(0.8),
                      const Color(0xFF8B5CF6).withOpacity(0.7),
                    ]
                  : [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                      const Color(0xFFEC4899),
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
              padding: const EdgeInsets.all(20),
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Factures',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'Gestion des factures et paiements',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _refreshData,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: RotationTransition(
                                turns: _refreshController,
                                child: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 24,
                                ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(bool isDark) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Main Statistics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total',
                      _formatCurrency(_statistics!.totalAmount),
                      Icons.account_balance_wallet,
                      const Color(0xFF3B82F6),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Payées',
                      _formatCurrency(_statistics!.totalPayments),
                      Icons.check_circle,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'En attente',
                      _formatCurrency(_statistics!.totalDue),
                      Icons.pending_outlined,
                      const Color(0xFFF59E0B),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Additional Statistics
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(isDark ? 0.1 : 0.9),
                      Colors.white.withOpacity(isDark ? 0.05 : 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        'Factures',
                        '${_statistics!.totalInvoices}',
                        Icons.receipt_outlined,
                        const Color(0xFF6366F1),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildMiniStat(
                        'Patients',
                        '${_statistics!.totalPatients}',
                        Icons.people_outline,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildMiniStat(
                        'Taux collecté',
                        '${_statistics!.paymentPercentage.toStringAsFixed(1)}%',
                        Icons.trending_up,
                        const Color(0xFF10B981),
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(isDark ? 0.1 : 0.9),
              Colors.white.withOpacity(isDark ? 0.05 : 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _loadInvoices();
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher par patient ou numéro...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips — time range first so "Toutes les dates" is visible without scrolling
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Toutes les dates', 'all', _timeRange,
                      (value) {
                    setState(() {
                      _timeRange = value;
                    });
                    _loadInvoices();
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Aujourd\'hui', 'day', _timeRange, (value) {
                    setState(() {
                      _timeRange = value;
                    });
                    _loadInvoices();
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ce mois', 'month', _timeRange, (value) {
                    setState(() {
                      _timeRange = value;
                    });
                    _loadInvoices();
                  }),
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(width: 16),
                  _buildFilterChip('Tous', 'all', _statusFilter, (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadInvoices();
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Payées', 'paid', _statusFilter, (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadInvoices();
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Partielles', 'partial', _statusFilter,
                      (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadInvoices();
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Non payées', 'unpaid', _statusFilter,
                      (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadInvoices();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String value, String currentValue, Function(String) onTap) {
    final isSelected = currentValue == value;
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              )
            : null,
        color: isSelected ? null : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(value),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoicesList(bool isDark) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(50),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Erreur',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInvoices,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoices.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(isDark ? 0.1 : 0.9),
                Colors.white.withOpacity(isDark ? 0.05 : 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune facture trouvée',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez votre première facture pour commencer',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final invoice = _invoices[index];
          return Container(
            margin: EdgeInsets.fromLTRB(
              20,
              index == 0 ? 20 : 8,
              20,
              index == _invoices.length - 1 ? 100 : 8,
            ),
            child: _buildInvoiceCard(invoice, isDark),
          );
        },
        childCount: _invoices.length,
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, bool isDark) {
    final statusColor = _getStatusColor(invoice.status);
    final progress = invoice.amount > 0 ? (invoice.paid / invoice.amount) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(isDark ? 0.1 : 0.95),
            Colors.white.withOpacity(isDark ? 0.05 : 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                    InvoiceDetailScreenModern(invoice: invoice),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(invoice.status),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Facture #${invoice.id}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            invoice.patient?.user?.name ?? 'Patient inconnu',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(invoice.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount Information
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Montant total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatCurrency(invoice.amount),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Montant payé',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatCurrency(invoice.paid),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Échéance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            invoice.dueDate ?? 'Non définie',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progression du paiement',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor,
                                statusColor.withOpacity(0.8)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
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
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateInvoiceScreen(),
                  ),
                );
                if (result == true) {
                  _loadInvoices();
                }
              },
              borderRadius: BorderRadius.circular(28),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Nouvelle facture',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
