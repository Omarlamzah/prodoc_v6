import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_providers.dart';

class DashboardScreenFixed extends ConsumerStatefulWidget {
  const DashboardScreenFixed({super.key});

  @override
  ConsumerState<DashboardScreenFixed> createState() =>
      _DashboardScreenFixedState();
}

class _DashboardScreenFixedState extends ConsumerState<DashboardScreenFixed>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animationController.forward();

    // Debug user data after frame is built
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _debugUserData();
    // });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _debugUserData() {
    // Debug: Print user data structure
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null) {
      print('DEBUG: User data structure: $user');
      final userData = _getUserData(user);

      print('DEBUG: Processed user data: $userData');
      if (userData != null) {
        print('DEBUG: Image URL: ${userData['img_src']}');
        print('DEBUG: User name: ${userData['name']}');
        print('DEBUG: Doctor data: ${userData['doctor']}');
      }
    } else {
      print('DEBUG: No user data available');
    }
  }

  Map<String, dynamic>? _getUserData(dynamic user) {
    if (user == null) return null;

    if (user is Map<String, dynamic>) {
      return user;
    }

    try {
      return (user as dynamic).toJson() as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Could not convert user to Map: $e');
      return null;
    }
  }

  String _formatTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      // If parsing fails, return original string
    }
    return timeString;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Handle loading state
    if (authState.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle error state
    if (authState.error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                authState.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Reset error and try again
                  ref.read(authProvider.notifier).resetError();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(context, authState),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          // Refresh data here
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 80),
            ),
            SliverToBoxAdapter(
              child: _buildWelcomeSection(context, authState)
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms),
            ),
            SliverToBoxAdapter(
              child: _buildQuickStats(context)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 200.ms),
            ),
            SliverToBoxAdapter(
              child: _buildQuickActions(context)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 400.ms),
            ),
            SliverToBoxAdapter(
              child: _buildUpcomingAppointments(context)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 600.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 600.ms),
            ),
            SliverToBoxAdapter(
              child: _buildRecentActivity(context)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 800.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 800.ms),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showQuickActionsBottomSheet(context);
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick Action'),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
      BuildContext context, dynamic authState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 80 + MediaQuery.of(context).padding.top,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1F3A).withOpacity(0.9),
                        const Color(0xFF2D3748).withOpacity(0.8),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildAppLogo(context),
                    const Spacer(),
                    _buildNotificationButton(context),
                    const SizedBox(width: 12),
                    _buildUserAvatar(context, authState),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NextPital',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Healthcare Management',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            // Handle notifications
          },
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 22,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, dynamic authState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState?.user;

    // Handle both user object and direct user data
    final userData = _getUserData(user);

    return PopupMenuButton<String>(
      offset: const Offset(0, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildUserImage(userData),
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'profile':
            // Navigate to profile
            break;
          case 'settings':
            // Navigate to settings
            break;
          case 'logout':
            _showLogoutDialog(context);
            break;
        }
      },
    );
  }

  Widget _buildUserImage(Map<String, dynamic>? userData) {
    // Check for img_src (from your API) or profile_image (fallback)
    final imageUrl = userData?['img_src'] ?? userData?['profile_image'];

    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      return Image.network(
        imageUrl.toString(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultAvatar(context),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: Colors.white,
            ),
          );
        },
      );
    }

    return _buildDefaultAvatar(context);
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, dynamic authState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState?.user;

    // Handle both user object and direct user data
    final userData = _getUserData(user);
    final userName = userData?['name'] ?? 'Doctor';
    final doctorData = userData?['doctor'];
    final specialty = doctorData?['specialty'] ?? 'Healthcare Professional';
    final availableFrom = doctorData?['available_from'];
    final availableTo = doctorData?['available_to'];

    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    Color greetingColor;

    if (hour < 12) {
      greeting = 'Good morning';
      greetingIcon = Icons.wb_sunny_rounded;
      greetingColor = Colors.orange;
    } else if (hour < 17) {
      greeting = 'Good afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
      greetingColor = Colors.amber;
    } else {
      greeting = 'Good evening';
      greetingIcon = Icons.nights_stay_rounded;
      greetingColor = Colors.indigo;
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1F3A).withOpacity(0.9),
                  const Color(0xFF2D3748).withOpacity(0.8),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: greetingColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  greetingIcon,
                  color: greetingColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dr. $userName',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            specialty,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (availableFrom != null && availableTo != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.38),
                ),
                const SizedBox(width: 4),
                Text(
                  'Available: ${_formatTime(availableFrom)} - ${_formatTime(availableTo)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.38),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Ready to make a difference in your patients\' lives today?',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userData = _getUserData(user);
    final doctorData = userData?['doctor'];
    final consultationFee = doctorData?['consultation_fee'] ?? '0';

    final stats = [
      {
        'title': 'Today\'s Appointments',
        'value': '12',
        'icon': Icons.calendar_today_rounded,
        'color': Colors.blue,
        'trend': '+2',
      },
      {
        'title': 'Total Patients',
        'value': '248',
        'icon': Icons.people_rounded,
        'color': Colors.green,
        'trend': '+15',
      },
      {
        'title': 'Consultation Fee',
        'value': '\$${consultationFee}',
        'icon': Icons.monetization_on_rounded,
        'color': Colors.orange,
        'trend': 'per visit',
      },
      {
        'title': 'This Month',
        'value': '\$12.5K',
        'icon': Icons.trending_up_rounded,
        'color': Colors.purple,
        'trend': '+8.2%',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1F3A).withOpacity(0.9),
                        const Color(0xFF2D3748).withOpacity(0.8),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
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
                        color: (stat['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        stat['icon'] as IconData,
                        color: stat['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stat['trend'] as String,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      {
        'title': 'New Appointment',
        'icon': Icons.add_circle_outline_rounded,
        'color': Colors.blue,
        'onTap': () {
          // Navigate to appointments
        },
      },
      {
        'title': 'Patient Records',
        'icon': Icons.folder_shared_outlined,
        'color': Colors.green,
        'onTap': () {
          // Navigate to patients
        },
      },
      {
        'title': 'Prescriptions',
        'icon': Icons.receipt_long_outlined,
        'color': Colors.orange,
        'onTap': () {
          // Navigate to prescriptions
        },
      },
      {
        'title': 'Emergency',
        'icon': Icons.emergency_outlined,
        'color': Colors.red,
        'onTap': () {
          // Handle emergency
        },
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    (action['onTap'] as VoidCallback)();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (action['color'] as Color).withOpacity(0.1),
                          (action['color'] as Color).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (action['color'] as Color).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (action['color'] as Color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            color: action['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action['title'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mock data for demonstration
    final appointments = [
      {
        'patient': 'John Smith',
        'time': '10:30 AM',
        'type': 'Consultation',
        'status': 'confirmed',
      },
      {
        'patient': 'Sarah Johnson',
        'time': '2:15 PM',
        'type': 'Follow-up',
        'status': 'pending',
      },
      {
        'patient': 'Mike Wilson',
        'time': '4:00 PM',
        'type': 'Emergency',
        'status': 'urgent',
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Upcoming Appointments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Navigate to appointments
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              Color statusColor;
              switch (appointment['status']) {
                case 'confirmed':
                  statusColor = Colors.green;
                  break;
                case 'pending':
                  statusColor = Colors.orange;
                  break;
                case 'urgent':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1A1F3A).withOpacity(0.9),
                            const Color(0xFF2D3748).withOpacity(0.8),
                          ]
                        : [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.8),
                            statusColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
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
                            appointment['patient'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${appointment['time']} • ${appointment['type']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appointment['status'] as String,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activities = [
      {
        'title': 'New patient registered',
        'subtitle': 'Emma Davis joined your practice',
        'time': '2 hours ago',
        'icon': Icons.person_add_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Prescription updated',
        'subtitle': 'Updated medication for John Smith',
        'time': '4 hours ago',
        'icon': Icons.edit_note_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Appointment completed',
        'subtitle': 'Follow-up with Sarah Johnson',
        'time': '6 hours ago',
        'icon': Icons.check_circle_rounded,
        'color': Colors.orange,
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1F3A).withOpacity(0.9),
                        const Color(0xFF2D3748).withOpacity(0.8),
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (activity['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activity['icon'] as IconData,
                        color: activity['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['title'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      activity['time'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1A1F3A).withOpacity(0.95),
                    const Color(0xFF2D3748).withOpacity(0.9),
                  ]
                : [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.9),
                  ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickActionItem(
              context,
              Icons.person_add_rounded,
              'Add New Patient',
              Colors.green,
              () {
                Navigator.pop(context);
                // Navigate to add patient
              },
            ),
            _buildQuickActionItem(
              context,
              Icons.calendar_today_rounded,
              'Schedule Appointment',
              Colors.blue,
              () {
                Navigator.pop(context);
                // Navigate to schedule appointment
              },
            ),
            _buildQuickActionItem(
              context,
              Icons.receipt_long_rounded,
              'Create Prescription',
              Colors.orange,
              () {
                Navigator.pop(context);
                // Navigate to create prescription
              },
            ),
            _buildQuickActionItem(
              context,
              Icons.emergency_rounded,
              'Emergency Contact',
              Colors.red,
              () {
                Navigator.pop(context);
                // Handle emergency
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white60 : Colors.black45,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1F3A).withOpacity(0.95),
                        const Color(0xFF2D3748).withOpacity(0.9),
                      ]
                    : [
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.9),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout from your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              ref.read(authProvider.notifier).logout();
                            },
                            child: const Center(
                              child: Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
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
    );
  }
}
