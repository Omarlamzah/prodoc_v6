// lib/screens/waiting_room_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/waiting_room_providers.dart';
import '../providers/appointment_providers.dart';
import '../providers/auth_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../data/models/waiting_room_model.dart';
import '../core/utils/result.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  DateTime _currentTime = DateTime.now();
  Timer? _timeTimer;
  Timer? _dataRefreshTimer;
  bool _showLeftSidebar = false;
  bool _showRightSidebar = false;
  bool _showCancelledSidebar = false;
  bool _showNoShowSidebar = false;

  @override
  void initState() {
    super.initState();
    _startTimeUpdates();
    _setupDataRefresh();
  }

  void _startTimeUpdates() {
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  void _setupDataRefresh() {
    _dataRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        ref.invalidate(waitingRoomProvider);
      }
    });
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '';
    final parts = timeString.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeString;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade50;
      case 'medium':
        return Colors.orange.shade50;
      case 'low':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MEDIUM';
      case 'low':
        return 'LOW';
      default:
        return 'NORMAL';
    }
  }

  // Check if user can change status (admin or doctor)
  bool _canChangeStatus() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    return user?.isAdmin == 1 || user?.isDoctor == 1;
  }

  // Show status change dialog
  void _showStatusChangeDialog(WaitingRoomAppointment appointment) {
    if (appointment.appointmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentStatus = appointment.status?.toLowerCase() ?? 'scheduled';
    final isCompleted = currentStatus == 'completed';
    final isCancelled = currentStatus == 'cancelled';
    final isNoShow = currentStatus == 'no_show' || currentStatus == 'no-show';
    final isWaiting = currentStatus == 'scheduled' ||
        currentStatus == 'pending' ||
        currentStatus == 'waiting';

    // Mobile: Bottom Sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              appointment.patientName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Dr. ${appointment.doctorName} - ${appointment.service}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'Change Status',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Status options
            if (isCompleted || isCancelled || isNoShow)
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildStatusButton(
                    context,
                    icon: Icons.refresh_rounded,
                    label: 'Reschedule',
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.pop(context);
                      _handleStatusUpdate(appointment, 'scheduled');
                    },
                  );
                },
              ),
            if (isWaiting) ...[
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildStatusButton(
                    context,
                    icon: Icons.check_circle_rounded,
                    label: 'Mark as Completed',
                    color: Colors.green,
                    onPressed: () {
                      Navigator.pop(context);
                      _handleStatusUpdate(appointment, 'completed');
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildStatusButton(
                    context,
                    icon: Icons.cancel_rounded,
                    label: 'Cancel',
                    color: Colors.red,
                    onPressed: () {
                      Navigator.pop(context);
                      _handleStatusUpdate(appointment, 'cancelled');
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildStatusButton(
                    context,
                    icon: Icons.play_circle_rounded,
                    label: 'Mark in Progress',
                    color: Colors.orange,
                    onPressed: () {
                      Navigator.pop(context);
                      _handleStatusUpdate(appointment, 'in_progress');
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildStatusButton(
                    context,
                    icon: Icons.person_off_outlined,
                    label: localizations?.noShow ?? 'Mark as No Show',
                    color: Colors.grey,
                    onPressed: () {
                      Navigator.pop(context);
                      _handleStatusUpdate(appointment, 'no_show');
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // Handle status update
  Future<void> _handleStatusUpdate(
      WaitingRoomAppointment appointment, String status) async {
    if (appointment.appointmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmMessage = status == 'completed'
        ? 'Mark this appointment as completed?'
        : status == 'cancelled'
            ? 'Cancel this appointment?'
            : status == 'no_show'
                ? 'Mark this appointment as no show?'
                : status == 'in_progress'
                    ? 'Mark this appointment as in progress?'
                    : status == 'scheduled'
                        ? 'Reschedule this appointment?'
                        : 'Change the status of this appointment?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return AlertDialog(
            title: const Text('Confirmation'),
            content: Text(confirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      status == 'cancelled' ? Colors.red : Colors.blue,
                ),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              const Text('Updating status...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final result = await ref.read(
      updateAppointmentStatusProvider(
        UpdateStatusParams(
          appointmentId: appointment.appointmentId!,
          status: status,
        ),
      ).future,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'completed'
                  ? 'Appointment marked as completed'
                  : status == 'cancelled'
                      ? 'Appointment cancelled'
                      : status == 'no_show'
                          ? 'Appointment marked as no show'
                          : status == 'scheduled'
                              ? 'Appointment rescheduled'
                              : status == 'in_progress'
                                  ? 'Appointment marked as in progress'
                                  : 'Status updated',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh waiting room data
        ref.invalidate(waitingRoomProvider);
      },
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $message'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _dataRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitingRoomAsync = ref.watch(waitingRoomProvider);
    return _buildMobileLayout(waitingRoomAsync);
  }

  // ========== MOBILE LAYOUT WITH SIDEBARS (OVERLAY LIKE DRAWER) ==========
  Widget _buildMobileLayout(
      AsyncValue<Result<WaitingRoomData>> waitingRoomAsync) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildMobileAppBar(),
      body: Stack(
        children: [
          // Main Content (Always full width)
          _buildMobileMainContent(waitingRoomAsync),
          // Backdrop overlay when sidebar is open
          if (_showLeftSidebar ||
              _showRightSidebar ||
              _showCancelledSidebar ||
              _showNoShowSidebar)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showLeftSidebar = false;
                  _showRightSidebar = false;
                  _showCancelledSidebar = false;
                  _showNoShowSidebar = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          // Left Sidebar (Overlay from left)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _showLeftSidebar ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child: _buildMobileLeftSidebar(waitingRoomAsync),
          ),
          // Right Sidebar (Overlay from right) - Completed
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _showRightSidebar ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child:
                _buildMobileRightSidebar(waitingRoomAsync, isCancelled: false),
          ),
          // Cancelled Sidebar (Overlay from right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _showCancelledSidebar ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child:
                _buildMobileRightSidebar(waitingRoomAsync, isCancelled: true),
          ),
          // No Show Sidebar (Overlay from right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _showNoShowSidebar ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child: _buildMobileRightSidebar(waitingRoomAsync,
                isCancelled: false, isNoShow: true),
          ),
          // Sidebar toggle buttons (only show when sidebars are closed)
          if (!_showLeftSidebar &&
              !_showRightSidebar &&
              !_showCancelledSidebar &&
              !_showNoShowSidebar) ...[
            Positioned(
              left: 8,
              top: MediaQuery.of(context).size.height / 2 - 100,
              child: _buildSidebarToggleButton(
                icon: Icons.people,
                isActive: false,
                onTap: () => setState(() => _showLeftSidebar = true),
                color: Colors.blue,
              ),
            ),
            Positioned(
              right: 8,
              top: MediaQuery.of(context).size.height / 2 - 100,
              child: _buildSidebarToggleButton(
                icon: Icons.check_circle,
                isActive: false,
                onTap: () => setState(() => _showRightSidebar = true),
                color: Colors.green,
              ),
            ),
            Positioned(
              right: 8,
              top: MediaQuery.of(context).size.height / 2 - 20,
              child: _buildSidebarToggleButton(
                icon: Icons.cancel,
                isActive: false,
                onTap: () => setState(() => _showCancelledSidebar = true),
                color: Colors.red,
              ),
            ),
            Positioned(
              right: 8,
              top: MediaQuery.of(context).size.height / 2 + 60,
              child: _buildSidebarToggleButton(
                icon: Icons.person_off,
                isActive: false,
                onTap: () => setState(() => _showNoShowSidebar = true),
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMobileSettings(),
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.settings, color: Colors.white),
      ),
    );
  }

  Widget _buildSidebarToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : color,
            size: 20,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              final locale = ref.watch(localeProvider).locale;
              return Text(
                localizations?.waitingRoom ?? 'Waiting Room',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          Builder(
            builder: (context) {
              final locale = ref.watch(localeProvider).locale;
              return Text(
                DateFormat('dd MMM yyyy | HH:mm', locale.toString())
                    .format(_currentTime),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(waitingRoomProvider),
        ),
      ],
    );
  }

  Widget _buildMobileMainContent(
      AsyncValue<Result<WaitingRoomData>> waitingRoomAsync) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(waitingRoomProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: waitingRoomAsync.when(
        data: (result) {
          return result.when(
            success: (data) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Now Serving Card
                    _buildMobileNowServing(data.stats.nextAppointment),
                    const SizedBox(height: 16),
                    // Stats Cards - Horizontal Scroll
                    SizedBox(
                      height: 140,
                      child: _buildMobileStats(data.stats.today),
                    ),
                    const SizedBox(height: 16),
                    // Quick Stats
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return _buildMobileQuickStat(
                                'Waiting',
                                data.waitingAppointments.length.toString(),
                                Colors.blue,
                                Icons.people,
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
                              return _buildMobileQuickStat(
                                'Completed',
                                data.completedAppointments.length.toString(),
                                Colors.green,
                                Icons.check_circle,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Cancelled Stats
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return _buildMobileQuickStat(
                          'Cancelled',
                          data.cancelledAppointments.length.toString(),
                          Colors.red,
                          Icons.cancel,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // No Show Stats
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return _buildMobileQuickStat(
                          localizations?.noShow ?? 'No Show',
                          data.noShowAppointments.length.toString(),
                          Colors.grey,
                          Icons.person_off,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            failure: (message) => _buildErrorView(message),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorView(error.toString()),
      ),
    );
  }

  Widget _buildMobileLeftSidebar(
      AsyncValue<Result<WaitingRoomData>> waitingRoomAsync) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        'Waiting',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _showLeftSidebar = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildMobileSidebarList(waitingRoomAsync, isWaiting: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRightSidebar(
      AsyncValue<Result<WaitingRoomData>> waitingRoomAsync,
      {required bool isCancelled,
      bool isNoShow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isNoShow
                    ? [Colors.grey.shade600, Colors.grey.shade700]
                    : isCancelled
                        ? [Colors.red.shade600, Colors.red.shade700]
                        : [Colors.green.shade600, Colors.green.shade700],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isNoShow
                      ? Icons.person_off
                      : isCancelled
                          ? Icons.cancel
                          : Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        isNoShow
                            ? (localizations?.noShow ?? 'No Show')
                            : isCancelled
                                ? 'Cancelled'
                                : 'Completed',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() {
                    if (isNoShow) {
                      _showNoShowSidebar = false;
                    } else if (isCancelled) {
                      _showCancelledSidebar = false;
                    } else {
                      _showRightSidebar = false;
                    }
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildMobileSidebarList(
              waitingRoomAsync,
              isWaiting: false,
              isCancelled: isCancelled,
              isNoShow: isNoShow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSidebarList(
      AsyncValue<Result<WaitingRoomData>> waitingRoomAsync,
      {required bool isWaiting,
      bool isCancelled = false,
      bool isNoShow = false}) {
    return waitingRoomAsync.when(
      data: (result) {
        return result.when(
          success: (data) {
            final appointments = isWaiting
                ? data.waitingAppointments
                : isNoShow
                    ? data.noShowAppointments
                    : isCancelled
                        ? data.cancelledAppointments
                        : data.completedAppointments;
            if (appointments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isWaiting
                          ? Icons.person_outline
                          : isNoShow
                              ? Icons.person_off_outlined
                              : isCancelled
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          isWaiting
                              ? 'No patients waiting'
                              : isNoShow
                                  ? 'No no-show appointments'
                                  : isCancelled
                                      ? 'No appointments cancelled'
                                      : 'No appointments completed',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appointment = appointments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMobileSidebarCard(
                    appointment,
                    isFirst: isWaiting && index == 0,
                    isCompleted: !isWaiting && !isCancelled && !isNoShow,
                    isCancelled: isCancelled,
                    isNoShow: isNoShow,
                  ),
                );
              },
            );
          },
          failure: (message) => _buildErrorView(message),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorView(error.toString()),
    );
  }

  Widget _buildMobileSidebarCard(WaitingRoomAppointment appointment,
      {bool isFirst = false,
      bool isCompleted = false,
      bool isCancelled = false,
      bool isNoShow = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!_canChangeStatus()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to change status'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (appointment.appointmentId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ID de rendez-vous introuvable'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          _showStatusChangeDialog(appointment);
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: (_canChangeStatus() && appointment.appointmentId != null)
            ? Colors.blue.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        highlightColor:
            (_canChangeStatus() && appointment.appointmentId != null)
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFirst
                ? Colors.blue.shade50
                : isNoShow
                    ? Colors.grey.shade100
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: isFirst
                ? Border.all(color: Colors.blue.shade500, width: 2)
                : isNoShow
                    ? Border.all(color: Colors.grey.shade400, width: 1.5)
                    : Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isNoShow
                          ? Colors.grey.shade400
                          : isCancelled
                              ? Colors.red.shade200
                              : isCompleted
                                  ? Colors.green.shade200
                                  : isFirst
                                      ? Colors.blue.shade500
                                      : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        appointment.orderNumber.toString(),
                        style: GoogleFonts.poppins(
                          color: isNoShow
                              ? Colors.white
                              : isCancelled
                                  ? Colors.red.shade800
                                  : isCompleted
                                      ? Colors.green.shade800
                                      : isFirst
                                          ? Colors.white
                                          : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.patientName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.medical_services,
                      size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appointment.doctorName,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.local_activity,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appointment.service,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(appointment.appointmentTime),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              // Click hint (only for admin/doctor)
              if (_canChangeStatus() && appointment.appointmentId != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          'Tap to change status',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNowServing(NextAppointment? nextAppointment) {
    if (nextAppointment == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.local_hospital, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  'No patient in progress',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.notifications_active,
              size: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'IN PROGRESS',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextAppointment.patientName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMobileInfoRow(
                        Icons.medical_services,
                        'Dr. ${nextAppointment.doctorName}',
                      ),
                      const SizedBox(height: 8),
                      _buildMobileInfoRow(
                        Icons.local_activity,
                        nextAppointment.service,
                      ),
                      const SizedBox(height: 8),
                      _buildMobileInfoRow(
                        Icons.access_time,
                        _formatTime(nextAppointment.time),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              'Please go to the room',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Status change button for "Now Serving" (only for admin/doctor)
                if (_canChangeStatus() &&
                    nextAppointment.appointmentId != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final appointment = WaitingRoomAppointment(
                        appointmentId: nextAppointment.appointmentId,
                        orderNumber: 0,
                        patientName: nextAppointment.patientName,
                        doctorName: nextAppointment.doctorName,
                        service: nextAppointment.service,
                        appointmentTime: nextAppointment.time,
                        priority: 'medium',
                        status: 'in_progress',
                      );
                      _showStatusChangeDialog(appointment);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return const Text('Change Status',
                            style: TextStyle(fontSize: 12));
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
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

  Widget _buildMobileInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStats(TodayStats stats) {
    final progress =
        stats.total > 0 ? (stats.completed / stats.total * 100).round() : 0;

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return _buildMobileStatCard('Waiting', stats.waiting.toString(),
                Colors.blue, Icons.people_outline);
          },
        ),
        const SizedBox(width: 12),
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return _buildMobileStatCard('Completed', stats.completed.toString(),
                Colors.green, Icons.check_circle_outline);
          },
        ),
        const SizedBox(width: 12),
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return _buildMobileStatCard('Total', stats.total.toString(),
                Colors.purple, Icons.calendar_today_outlined);
          },
        ),
        const SizedBox(width: 12),
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return _buildMobileProgressCard(
                'Progress', '$progress%', progress, Colors.orange);
          },
        ),
      ],
    );
  }

  Widget _buildMobileStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProgressCard(
      String title, String value, int progress, Color color) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.trending_up, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQuickStat(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ElevatedButton(
                  onPressed: () => ref.invalidate(waitingRoomProvider),
                  child: const Text('Retry'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.settings ?? 'Settings',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
