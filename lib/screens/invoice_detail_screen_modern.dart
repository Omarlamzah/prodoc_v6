import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invoice.dart';
import '../core/utils/result.dart';
import '../providers/api_providers.dart';
import '../l10n/app_localizations.dart';

class InvoiceDetailScreenModern extends ConsumerStatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreenModern({
    super.key,
    required this.invoice,
  });

  @override
  ConsumerState<InvoiceDetailScreenModern> createState() =>
      _InvoiceDetailScreenModernState();
}

class _InvoiceDetailScreenModernState
    extends ConsumerState<InvoiceDetailScreenModern>
    with TickerProviderStateMixin {
  late Invoice _invoice;
  List<Payment> _payments = [];
  bool _isLoading = false;
  bool _isLoadingPayments = false;

  late AnimationController _animationController;
  late AnimationController _floatingController;
  late AnimationController _heroController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _initAnimations();
    _loadPayments();
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
    _heroController = AnimationController(
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

    _animationController.forward();
    _heroController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoadingPayments = true;
    });

    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.getInvoicePayments(_invoice.id);

      if (result is Success<List<Payment>>) {
        setState(() {
          _payments = result.data;
          _isLoadingPayments = false;
        });
      } else {
        setState(() {
          _isLoadingPayments = false;
        });
        _showSnackBar('Error loading payments', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoadingPayments = false;
      });
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      final result = await invoiceService.downloadInvoicePdf(_invoice.id);

      if (result is Success<String>) {
        final filePath = result.data;
        final xFile = XFile(filePath, mimeType: 'application/pdf');
        await Share.shareXFiles(
          [xFile],
          text: 'Facture #${_invoice.id}',
          subject: 'Facture PDF',
        );
        if (mounted) {
          _showSnackBar(
            AppLocalizations.of(context)?.pdfDownloaded ?? 'PDF downloaded',
            isError: false,
          );
        }
      } else {
        if (mounted) {
          _showSnackBar((result as Failure).message, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error downloading: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendReminder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invoiceService = ref.read(invoiceServiceProvider);
      await invoiceService.sendDueReminder(_invoice.id);
      _showSnackBar('Reminder sent successfully', isError: false);
    } catch (e) {
      _showSnackBar('Error sending: $e', isError: true);
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

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => _PaymentDialog(
        invoice: _invoice,
        onPaymentAdded: () {
          _loadPayments();
          Navigator.pop(context);
        },
      ),
    );
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
    final localizations = AppLocalizations.of(context);
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      case 'unpaid':
        return 'Unpaid';
      default:
        return 'Unknown';
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
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(_invoice.status);
    final progress =
        _invoice.amount > 0 ? (_invoice.paid / _invoice.amount) : 0.0;

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
                // Hero Header
                _buildHeroHeader(isDark, statusColor),

                // Amount Cards
                _buildAmountCards(isDark, progress, statusColor),

                // Patient Information
                _buildPatientInfo(isDark),

                // Invoice Items
                _buildInvoiceItems(isDark),

                // Payment History
                _buildPaymentHistory(isDark),

                // Bottom Spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),

            // Floating Action Buttons
            _buildFloatingActions(theme, statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _floatingController,
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
              children: List.generate(3, (index) {
                return Positioned(
                  top: 200.0 * index,
                  right: index.isEven ? -200 : null,
                  left: index.isOdd ? -200 : null,
                  child: Transform.translate(
                    offset:
                        Offset(0, _floatingController.value * 20 * (index + 1)),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isDark ? Colors.blue : Colors.purple)
                                .withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
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

  Widget _buildHeroHeader(bool isDark, Color statusColor) {
    return SliverAppBar(
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
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor,
                statusColor.withOpacity(0.8),
                statusColor.withOpacity(0.6),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(_invoice.status),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Invoice #${_invoice.id}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(_invoice.status),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                                  'Total Amount',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                            Text(
                              _formatCurrency(_invoice.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_invoice.dueDate != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Text(
                                  'Due Date',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                            Text(
                              _invoice.dueDate!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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

  Widget _buildAmountCards(bool isDark, double progress, Color statusColor) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Progress Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(isDark ? 0.1 : 0.95),
                      Colors.white.withOpacity(isDark ? 0.05 : 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              'Payment Progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            );
                          },
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
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
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount Cards
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return _buildAmountCard(
                          'Paid',
                          _formatCurrency(_invoice.paid),
                          Icons.check_circle_outline,
                          const Color(0xFF10B981),
                          isDark,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return _buildAmountCard(
                          'Remaining',
                          _formatCurrency(_invoice.amount - _invoice.paid),
                          Icons.pending_outlined,
                          const Color(0xFFF59E0B),
                          isDark,
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
    );
  }

  Widget _buildAmountCard(
      String title, String amount, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(isDark ? 0.1 : 0.95),
            Colors.white.withOpacity(isDark ? 0.05 : 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfo(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(isDark ? 0.1 : 0.95),
              Colors.white.withOpacity(isDark ? 0.05 : 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invoice.patient?.user?.name ?? 'Unknown Patient',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      if (_invoice.patient?.user?.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _invoice.patient!.user!.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (_invoice.patient?.phoneNumber != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _invoice.patient!.phoneNumber!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_invoice.appointment != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: const Color(0xFF8B5CF6),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Text(
                                'Associated Appointment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                          Text(
                            '${_invoice.appointment!.appointmentDate} à ${_invoice.appointment!.appointmentTime}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
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
      ),
    );
  }

  Widget _buildInvoiceItems(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(isDark ? 0.1 : 0.95),
              Colors.white.withOpacity(isDark ? 0.05 : 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      'Invoice Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            ...List.generate(_invoice.items.length, (index) {
              final item = _invoice.items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF374151).withOpacity(0.5)
                      : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
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
                                    'Quantity',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '${item.quantity}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
                              Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Text(
                                    'Unit Price',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                _formatCurrency(item.unitPrice),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Builder(
                                builder: (context) {
                                  final localizations =
                                      AppLocalizations.of(context);
                                  return Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                _formatCurrency(item.total),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // Total Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return const Text(
                        'Invoice Total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  Text(
                    _formatCurrency(_invoice.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(isDark ? 0.1 : 0.95),
              Colors.white.withOpacity(isDark ? 0.05 : 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.payment_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoadingPayments)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.payment_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          children: [
                            Text(
                              'No payments recorded',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Payments will appear here once recorded',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_payments.length, (index) {
                final payment = _payments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF374151).withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatCurrency(payment.amount),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              payment.paymentDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          payment.paymentMethod,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActions(ThemeData theme, Color statusColor) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Record Payment Button
          if (_invoice.status != 'paid')
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showPaymentDialog,
                    borderRadius: BorderRadius.circular(28),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(
                        Icons.add_card,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Download PDF Button
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                  onTap: _isLoading ? null : _downloadPdf,
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ),

          // Send Reminder Button
          if (_invoice.status != 'paid')
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _sendReminder,
                    borderRadius: BorderRadius.circular(28),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(
                        Icons.send,
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
    );
  }
}

class _PaymentDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final VoidCallback onPaymentAdded;

  const _PaymentDialog({
    required this.invoice,
    required this.onPaymentAdded,
  });

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
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
      await invoiceService.recordPayment(
        invoiceId: widget.invoice.id,
        amount: double.parse(_amountController.text),
        paymentDate: _dateController.text,
        paymentMethod: _paymentMethod,
      );

      widget.onPaymentAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text('Payment recorded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingAmount = widget.invoice.amount - widget.invoice.paid;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.payment,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return const Text(
                          'Record Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          'Remaining Amount to Pay',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                    Text(
                      '${remainingAmount.toStringAsFixed(2)} MAD',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Payment Amount (MAD)',
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
                  if (amount > remainingAmount) {
                    return 'Amount too high';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Payment Date',
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
                    _dateController.text = date.toIso8601String().split('T')[0];
                  }
                },
              ),
              const SizedBox(height: 16),
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
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(
                      value: 'credit_card', child: Text('Credit Card')),
                  DropdownMenuItem(
                      value: 'bank_transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(
                      value: 'insurance', child: Text('Insurance')),
                  DropdownMenuItem(
                      value: 'mobile_payment', child: Text('Mobile Payment')),
                ],
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
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
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Text('Cancel');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _recordPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF10B981),
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
                          : Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
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
