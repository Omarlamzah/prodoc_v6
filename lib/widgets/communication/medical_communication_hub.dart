// lib/widgets/communication/medical_communication_hub.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/config/api_constants.dart';
import '../../core/config/realtime_config.dart';
import '../../data/models/tenant_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/tenant_providers.dart';

class MedicalCommunicationHub extends ConsumerStatefulWidget {
  const MedicalCommunicationHub({super.key});

  @override
  ConsumerState<MedicalCommunicationHub> createState() =>
      _MedicalCommunicationHubState();
}

class _MedicalCommunicationHubState
    extends ConsumerState<MedicalCommunicationHub> {
  final List<_MedicalMessage> _messages = [];
  final List<_EmergencyAlert> _alerts = [];

  bool _hubVisible = false;
  bool _isMuted = false;
  bool _isSendingMessage = false;
  bool _isSendingEmergency = false;

  _CommunicationTab _activeTab = _CommunicationTab.messages;
  _MessageFilter _messageFilter = _MessageFilter.all;
  String _messageType = _MessageType.normal;
  String _searchQuery = '';
  String? _emergencyTitle;
  String? _emergencyMessage;
  String? _emergencyLocation;

  late final TextEditingController _messageController;
  late final TextEditingController _searchController;

  PusherChannelsFlutter? _pusher;
  String? _messageChannelName;
  String? _emergencyChannelName;

  AudioPlayer? _messagePlayer;
  AudioPlayer? _emergencyPlayer;
  StreamSubscription<void>? _emergencyLoopSub;
  int _emergencyLoopCount = 0;

  ProviderSubscription<AuthState>? _authSubscription;
  ProviderSubscription<TenantModel?>? _tenantSubscription;
  Timer? _realtimeSetupTimer;
  bool _isRealtimeSettingUp = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _searchController = TextEditingController();

    // Reset notification counts when hub is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.resetMessageCounts();
    });

    _authSubscription = ref.listenManual<AuthState>(
      authProvider,
      (previous, next) {
        final prevId = previous?.user?.id;
        final nextId = next.user?.id;
        if (prevId != nextId) {
          _teardownRealtime();
          _resetState();
          if (next.user != null) {
            _scheduleRealtimeSetup();
          }
        }
      },
    );

    _tenantSubscription =
        ref.listenManual<TenantModel?>(selectedTenantProvider, (prev, next) {
      final auth = ref.read(authProvider);
      if (auth.user != null) {
        _scheduleRealtimeSetup();
      }
    });

    final authState = ref.read(authProvider);
    if (authState.user != null) {
      _scheduleRealtimeSetup();
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _tenantSubscription?.close();
    _messageController.dispose();
    _searchController.dispose();
    _messagePlayer?.dispose();
    _emergencyLoopSub?.cancel();
    _emergencyPlayer?.dispose();
    _realtimeSetupTimer?.cancel();
    _teardownRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (authState.isAuth != true || user == null) {
      return const SizedBox.shrink();
    }

    final unreadMessages = _messages
        .where((m) => !m.isRead && m.isForMe && m.fromId != user.id)
        .length;
    final activeEmergencies = _alerts.where((alert) => alert.isActive).length;
    final totalUnread = unreadMessages + activeEmergencies;

    return Stack(
      children: [
        if (_hubVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _hubVisible = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 96,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_hubVisible)
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate available height accounting for button and spacing
                        final mediaQuery = MediaQuery.of(context);
                        final screenHeight = mediaQuery.size.height;
                        final bottomPadding = mediaQuery.padding.bottom;
                        // Button height (~62px with padding), spacing (12px), bottom padding (96px)
                        // Account for header (~120px), composer (~100px when visible), and extra spacing
                        final buttonHeight = 62.0;
                        final spacing = 12.0;
                        final bottomPaddingValue = 96.0;
                        final reservedSpace = buttonHeight +
                            spacing +
                            bottomPaddingValue +
                            bottomPadding;
                        final maxCardHeight = screenHeight - reservedSpace - 16;
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                math.max(380.0, math.min(maxCardHeight, 650.0)),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _buildHubCard(context, user, unreadMessages,
                                activeEmergencies, totalUnread),
                          ),
                        );
                      },
                    ),
                  ),
                if (_hubVisible) const SizedBox(height: 12),
                _buildLauncherButton(
                    context, totalUnread, unreadMessages, activeEmergencies),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLauncherButton(BuildContext context, int totalUnread,
      int unreadMessages, int activeEmergencies) {
    final isOpen = _hubVisible;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 6,
        backgroundColor:
            isOpen ? Theme.of(context).colorScheme.primary : Colors.white,
        foregroundColor:
            isOpen ? Colors.white : Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(18),
      ),
      onPressed: () {
        setState(() {
          _hubVisible = !_hubVisible;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_rounded, size: 26),
          if (totalUnread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (unreadMessages > 0)
                    _buildBadge(
                      context,
                      unreadMessages > 9 ? '9+' : '$unreadMessages',
                      Colors.blue,
                    ),
                  if (activeEmergencies > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildBadge(
                        context,
                        activeEmergencies > 9 ? '9+' : '$activeEmergencies',
                        Colors.red,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context,
    UserModel user,
    int unreadMessages,
    int activeEmergencies,
    int totalUnread,
  ) {
    final theme = Theme.of(context);
    final filteredMessages = _filteredMessages();
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final cardWidth = screenSize.width < 460 ? screenSize.width - 32 : 420.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 2.0 // Safety margin to prevent overflow
            : 600.0;
        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            color: theme.colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildHeader(context, user, unreadMessages, activeEmergencies,
                    totalUnread),
                if (_activeTab == _CommunicationTab.messages)
                  _buildMessageComposer(context),
                Expanded(
                  child: _activeTab == _CommunicationTab.messages
                      ? _buildMessagePanel(context, user, filteredMessages)
                      : _buildEmergencyPanel(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UserModel user,
    int unreadMessages,
    int activeEmergencies,
    int totalUnread,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.03),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.monitor_heart_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Centre de communication',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.name ?? 'Utilisateur',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isMuted ? 'Activer les sons' : 'Couper les sons',
                onPressed: () => setState(() => _isMuted = !_isMuted),
                icon: Icon(
                  _isMuted ? Icons.notifications_off : Icons.notifications,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => setState(() => _hubVisible = false),
                icon: const Icon(Icons.close_rounded, size: 22),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  context,
                  isSelected: _activeTab == _CommunicationTab.messages,
                  label: 'Messages',
                  icon: Icons.message_rounded,
                  badgeValue: unreadMessages,
                  onTap: () =>
                      setState(() => _activeTab = _CommunicationTab.messages),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTabButton(
                  context,
                  isSelected: _activeTab == _CommunicationTab.emergency,
                  label: 'Urgences',
                  icon: Icons.warning_rounded,
                  badgeValue: activeEmergencies,
                  activeColor: Colors.red,
                  onTap: () =>
                      setState(() => _activeTab = _CommunicationTab.emergency),
                ),
              ),
            ],
          ),
          if (totalUnread > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.circle_notifications_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$totalUnread notification(s) non lue(s)',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required bool isSelected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    int badgeValue = 0,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final color = activeColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.35),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeValue > 0) ...[
              const SizedBox(width: 6),
              _buildBadge(
                context,
                badgeValue > 9 ? '9+' : '$badgeValue',
                isSelected ? Colors.white : color,
                textColor: isSelected ? color : Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isSendingMessage,
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tapez votre message...',
                            hintStyle: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.attach_file_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        onPressed: null,
                        tooltip: 'Pièce jointe',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSendingMessage ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: _isSendingMessage
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMessageTypeChip(theme),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'À: Tous',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
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
  }

  Widget _buildMessageTypeChip(ThemeData theme) {
    final messageTypeLabels = {
      _MessageType.normal: '💬 Normal',
      _MessageType.info: 'ℹ️ Info',
      _MessageType.important: '⚠️ Important',
      _MessageType.urgent: '🚨 Urgent',
    };

    return GestureDetector(
      onTap: () => _showMessageTypePicker(theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _messageTypeColor(_messageType, theme).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                _messageTypeColor(_messageType, theme).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              messageTypeLabels[_messageType] ?? '💬 Normal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _messageTypeColor(_messageType, theme),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _messageTypeColor(_messageType, theme),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageTypePicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _MessageType.options.map((type) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _messageTypeColor(type, theme).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == _MessageType.urgent
                      ? Icons.error_rounded
                      : type == _MessageType.important
                          ? Icons.warning_rounded
                          : type == _MessageType.info
                              ? Icons.info_rounded
                              : Icons.message_rounded,
                  color: _messageTypeColor(type, theme),
                  size: 20,
                ),
              ),
              title: Text(_messageTypeLabel(type)),
              onTap: () {
                setState(() => _messageType = type);
                Navigator.pop(context);
              },
              selected: _messageType == type,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessagePanel(
    BuildContext context,
    UserModel user,
    List<_MedicalMessage> filteredMessages,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          hintText: 'Rechercher...',
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.toLowerCase()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButton<_MessageFilter>(
                      value: _messageFilter,
                      onChanged: (value) => setState(
                          () => _messageFilter = value ?? _messageFilter),
                      items: _MessageFilter.values
                          .map(
                            (filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(
                                filter.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      underline: const SizedBox(),
                      icon: Icon(
                        Icons.filter_list_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      tooltip: 'Tout marquer comme lu',
                      onPressed: filteredMessages.isEmpty
                          ? null
                          : () {
                              setState(() {
                                for (final message in _messages) {
                                  message.isRead = true;
                                }
                              });
                              final notificationService =
                                  ref.read(notificationServiceProvider);
                              notificationService.resetMessageCounts();
                            },
                      icon: Icon(
                        Icons.done_all_rounded,
                        color: filteredMessages.isEmpty
                            ? Colors.grey
                            : theme.colorScheme.primary,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (filteredMessages.isEmpty)
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                              theme.colorScheme.primary.withValues(alpha: 0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _searchQuery.isEmpty
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.search_off_rounded,
                          size: 56,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ).animate().scale(delay: 100.ms, duration: 400.ms),
                      const SizedBox(height: 20),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aucun message pour le moment'
                            : 'Aucun résultat',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 200)),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Envoyez votre premier message pour commencer la conversation'
                            : 'Aucun message ne correspond à votre recherche',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.disabledColor,
                          fontSize: 13,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 300)),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final message = filteredMessages[index];
                final isSender = message.fromId == user.id;
                final isSameSender = index < filteredMessages.length - 1 &&
                    filteredMessages[index + 1].fromId == message.fromId;
                final showDateSeparator = index == 0 ||
                    !_isSameDay(message.timestamp,
                        filteredMessages[index - 1].timestamp);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDateSeparator)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _buildDateSeparator(message.timestamp),
                      ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: isSameSender ? 2 : 6,
                        bottom: 2,
                      ),
                      child: _buildModernMessageBubble(
                        context,
                        message,
                        user,
                        isSender,
                        theme,
                        isSameSender,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmergencyPanel(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildDropdownField(
                label: 'Type d\'urgence',
                value: _emergencyTitle,
                hint: 'Sélectionner le type',
                enabled: !_isSendingEmergency,
                items: _emergencyTitleOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.label,
                        child: Text(option.label,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _emergencyTitle = value),
              ),
              const SizedBox(height: 10),
              _buildDropdownField(
                label: 'Message',
                value: _emergencyMessage,
                hint: 'Sélectionner le message',
                enabled: !_isSendingEmergency,
                items: _emergencyMessages
                    .map(
                      (label) => DropdownMenuItem(
                        value: label,
                        child:
                            Text(label, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _emergencyMessage = value),
              ),
              const SizedBox(height: 10),
              _buildDropdownField(
                label: 'Lieu',
                value: _emergencyLocation,
                hint: 'Sélectionner le lieu',
                enabled: !_isSendingEmergency,
                items: _emergencyLocations
                    .map(
                      (label) => DropdownMenuItem(
                        value: label,
                        child:
                            Text(label, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _emergencyLocation = value),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red,
                      Colors.red.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSendingEmergency ? null : _sendEmergencyAlert,
                  icon: _isSendingEmergency
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.warning_rounded, size: 22),
                  label: Text(
                    _isSendingEmergency
                        ? 'Envoi en cours...'
                        : 'Déclencher une alerte',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _alerts.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.health_and_safety_rounded,
                              size: 48,
                              color: Colors.red.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune alerte active',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toutes les alertes sont résolues',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.disabledColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: alert.isActive
                            ? Colors.red.withValues(alpha: 0.08)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: alert.isActive
                              ? Colors.red.withValues(alpha: 0.3)
                              : theme.dividerColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: alert.isActive
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: alert.isActive
                                        ? Colors.red.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: alert.isActive
                                        ? Colors.red
                                        : Colors.grey,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    alert.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatTime(alert.timestamp),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              alert.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            if (alert.location != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      alert.location!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Par: ${alert.requester}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
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

  Future<void> _sendMessage() async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user == null) {
      debugPrint('[CommunicationHub] Cannot send message: user is null');
      _showSnack('Utilisateur non connecté');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      _showSnack('Le message ne peut pas être vide');
      return;
    }

    debugPrint(
        '[CommunicationHub] Sending message: "$text" (type: $_messageType) from user ${user.id}');
    setState(() => _isSendingMessage = true);
    final service = ref.read(communicationServiceProvider);
    final result = await service.sendMessage(
      message: text,
      messageType: _messageType,
      senderId: user.id ?? 0,
      senderName: user.name ?? 'Utilisateur',
      profileImage: user.additionalData?['profile_photo_path'] as String?,
    );

    result.when(
      success: (_) {
        debugPrint('[CommunicationHub] Message sent successfully via API');
        _messageController.clear();
        _showSnack('Message envoyé');
      },
      failure: (message) {
        debugPrint('[CommunicationHub] Failed to send message: $message');
        _showSnack(message);
      },
    );

    if (mounted) {
      setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _sendEmergencyAlert() async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user == null) {
      _showSnack('Utilisateur non connecté');
      return;
    }

    if (_emergencyTitle == null ||
        _emergencyMessage == null ||
        _emergencyLocation == null) {
      _showSnack('Tous les champs sont requis');
      return;
    }

    setState(() => _isSendingEmergency = true);

    final service = ref.read(communicationServiceProvider);
    final result = await service.sendEmergency(
      title: _emergencyTitle!,
      body: _emergencyMessage!,
      location: _emergencyLocation!,
      requesterId: user.id ?? 0,
      requesterName: user.name ?? 'Utilisateur',
    );

    result.when(
      success: (_) {
        _showSnack('Alerte envoyée');
        setState(() {
          _emergencyTitle = null;
          _emergencyMessage = null;
          _emergencyLocation = null;
        });
      },
      failure: (message) => _showSnack(message),
    );

    if (mounted) {
      setState(() => _isSendingEmergency = false);
    }
  }

  List<_MedicalMessage> _filteredMessages() {
    final filtered = _messages.where((message) {
      final matchesSearch = _searchQuery.isEmpty ||
          message.message.toLowerCase().contains(_searchQuery) ||
          (message.from ?? '').toLowerCase().contains(_searchQuery);

      final matchesFilter = switch (_messageFilter) {
        _MessageFilter.all => true,
        _MessageFilter.unread => !message.isRead,
        _MessageFilter.toMe => message.isForMe,
      };

      return matchesSearch && matchesFilter;
    }).toList();

    debugPrint(
        '[CommunicationHub] Filtered messages: ${filtered.length} of ${_messages.length} (filter: ${_messageFilter.label}, search: "$_searchQuery")');
    return filtered;
  }

  void _scheduleRealtimeSetup() {
    _realtimeSetupTimer?.cancel();
    _realtimeSetupTimer = Timer(const Duration(milliseconds: 150), () async {
      final auth = ref.read(authProvider);
      final tenant = ref.read(selectedTenantProvider);
      final currentUser = auth.user;
      if (currentUser == null || currentUser.id == null) {
        debugPrint(
            '[CommunicationHub] No authenticated user for realtime setup');
        return;
      }
      await _setupRealtime(currentUser, tenant);
    });
  }

  Future<void> _setupRealtime(UserModel user, TenantModel? tenant) async {
    if (_isRealtimeSettingUp) {
      debugPrint(
          '[CommunicationHub] Realtime setup already running, skipping duplicate request');
      return;
    }
    _isRealtimeSettingUp = true;
    try {
      await _teardownRealtime();
      if (user.id == null) {
        debugPrint(
            '[CommunicationHub] User ID is null, skipping realtime setup');
        return;
      }

      final tenantDomain = _resolveTenantDomain(tenant);
      debugPrint(
          '[CommunicationHub] Setting up realtime for user ${user.id}, tenant: $tenantDomain');

      // For mobile/online apps, always use Pusher (not Socket.IO)
      debugPrint(
          '[CommunicationHub] Using Pusher mode for online communication');
      final pusherSetup = await _setupPusher(user, tenantDomain);
      if (!pusherSetup) {
        debugPrint(
            '[CommunicationHub] ⚠️ Pusher configuration required! Add PUSHER_KEY and PUSHER_CLUSTER via dart-define flags.');
        debugPrint(
            '[CommunicationHub] Example: flutter run --dart-define=PUSHER_KEY=your_key --dart-define=PUSHER_CLUSTER=your_cluster');
        if (mounted) {
          _showSnack(
              'Communication non configurée. Veuillez configurer Pusher.');
        }
      }
    } finally {
      _isRealtimeSettingUp = false;
    }
  }

  Future<bool> _setupPusher(UserModel user, String tenantDomain) async {
    if (!RealtimeConfig.hasPusherConfig) {
      debugPrint(
          '[CommunicationHub] Pusher non configuré. Ajoutez PUSHER_KEY et PUSHER_CLUSTER via dart-define.');
      return false;
    }

    final messageChannelName = RealtimeConfig.messageChannel(tenantDomain);
    final emergencyChannelName = RealtimeConfig.emergencyChannel(tenantDomain);

    // Check if we're already set up with the same channels
    if (_pusher != null &&
        _messageChannelName == messageChannelName &&
        _emergencyChannelName == emergencyChannelName) {
      debugPrint(
          '[CommunicationHub] Already subscribed to channels: $messageChannelName, $emergencyChannelName');
      return true;
    }

    // Ensure any previous connection is fully torn down
    await _teardownRealtime();
    // Small delay to ensure teardown completes
    await Future.delayed(const Duration(milliseconds: 100));

    final pusher = PusherChannelsFlutter.getInstance();
    await pusher.init(
      apiKey: RealtimeConfig.pusherKey,
      cluster: RealtimeConfig.pusherCluster,
      logToConsole: kDebugMode,
      onConnectionStateChange: (current, previous) {
        debugPrint('[CommunicationHub] Pusher state: $previous -> $current');
      },
      onError: (message, code, exception) {
        debugPrint(
            '[CommunicationHub] Pusher error: $message ($code) $exception');
      },
      onEvent: (event) {
        // Global event handler for debugging
        debugPrint(
            '[CommunicationHub] Global Pusher event: ${event.channelName} / ${event.eventName}');
      },
    );

    await pusher.connect();
    debugPrint('[CommunicationHub] Pusher connected');

    _messageChannelName = messageChannelName;
    _emergencyChannelName = emergencyChannelName;

    debugPrint(
        '[CommunicationHub] Subscribing to channels: $messageChannelName, $emergencyChannelName');

    // Subscribe to message channel with error handling for duplicate subscriptions
    try {
      await pusher.subscribe(
        channelName: messageChannelName,
        onSubscriptionSucceeded: (data) {
          debugPrint(
              '[CommunicationHub] Successfully subscribed to message channel: $messageChannelName');
        },
        onSubscriptionError: (message, error) {
          debugPrint(
              '[CommunicationHub] Message channel subscription error: $message - $error');
        },
        onEvent: (event) {
          debugPrint(
              '[CommunicationHub] Pusher event on message channel: ${event.eventName}');
          debugPrint(
              '[CommunicationHub] Event data type: ${event.data.runtimeType}');
          debugPrint('[CommunicationHub] Event data: ${event.data}');

          if (event.eventName == 'message.sent' ||
              event.eventName == 'App\\Events\\MessageSent') {
            final data = _decodeEvent(event.data);
            debugPrint('[CommunicationHub] Decoded message data: $data');
            _handleIncomingMessage(data, user);
          }
        },
      );
    } on PlatformException catch (e) {
      if (e.message?.contains('Already subscribed') == true ||
          e.code == 'error') {
        debugPrint(
            '[CommunicationHub] Already subscribed to message channel, continuing...');
      } else {
        debugPrint(
            '[CommunicationHub] Error subscribing to message channel: ${e.message}');
        rethrow;
      }
    } catch (e) {
      if (e.toString().contains('Already subscribed')) {
        debugPrint(
            '[CommunicationHub] Already subscribed to message channel, continuing...');
      } else {
        debugPrint(
            '[CommunicationHub] Error subscribing to message channel: $e');
        rethrow;
      }
    }

    // Subscribe to emergency channel with error handling for duplicate subscriptions
    try {
      await pusher.subscribe(
        channelName: emergencyChannelName,
        onSubscriptionSucceeded: (data) {
          debugPrint(
              '[CommunicationHub] Successfully subscribed to emergency channel: $emergencyChannelName');
        },
        onSubscriptionError: (message, error) {
          debugPrint(
              '[CommunicationHub] Emergency channel subscription error: $message - $error');
        },
        onEvent: (event) {
          debugPrint(
              '[CommunicationHub] Pusher event on emergency channel: ${event.eventName}');
          debugPrint(
              '[CommunicationHub] Event data type: ${event.data.runtimeType}');
          debugPrint('[CommunicationHub] Event data: ${event.data}');

          if (event.eventName == 'emergency.alert' ||
              event.eventName == 'App\\Events\\EmergencyAlert') {
            final data = _decodeEvent(event.data);
            debugPrint('[CommunicationHub] Decoded emergency data: $data');
            _handleEmergencyAlert(data);
          }
        },
      );
    } on PlatformException catch (e) {
      if (e.message?.contains('Already subscribed') == true ||
          e.code == 'error') {
        debugPrint(
            '[CommunicationHub] Already subscribed to emergency channel, continuing...');
      } else {
        debugPrint(
            '[CommunicationHub] Error subscribing to emergency channel: ${e.message}');
        rethrow;
      }
    } catch (e) {
      if (e.toString().contains('Already subscribed')) {
        debugPrint(
            '[CommunicationHub] Already subscribed to emergency channel, continuing...');
      } else {
        debugPrint(
            '[CommunicationHub] Error subscribing to emergency channel: $e');
        rethrow;
      }
    }

    _pusher = pusher;
    debugPrint('[CommunicationHub] Pusher setup complete');
    return true;
  }

  Future<void> _teardownRealtime() async {
    if (_pusher != null) {
      try {
        if (_messageChannelName != null) {
          try {
            await _pusher!.unsubscribe(channelName: _messageChannelName!);
          } catch (e) {
            debugPrint(
                '[CommunicationHub] Error unsubscribing from message channel: $e');
          }
        }
        if (_emergencyChannelName != null) {
          try {
            await _pusher!.unsubscribe(channelName: _emergencyChannelName!);
          } catch (e) {
            debugPrint(
                '[CommunicationHub] Error unsubscribing from emergency channel: $e');
          }
        }
        try {
          await _pusher!.disconnect();
        } catch (e) {
          debugPrint('[CommunicationHub] Error disconnecting Pusher: $e');
        }
      } catch (e) {
        debugPrint('[CommunicationHub] Error during teardown: $e');
      }
    }
    _pusher = null;
    _messageChannelName = null;
    _emergencyChannelName = null;
  }

  void _handleIncomingMessage(dynamic rawData, UserModel user) {
    debugPrint(
        '[CommunicationHub] _handleIncomingMessage called with: $rawData');
    final data = _normalizeMap(rawData);
    if (data.isEmpty) {
      debugPrint('[CommunicationHub] Normalized data is empty');
      return;
    }

    final senderId = _intOrNull(data['sender_id']);
    final recipientId = _intOrNull(data['recipient_id']);
    final messageText = data['message']?.toString() ?? '';
    debugPrint(
        '[CommunicationHub] Parsed message - senderId: $senderId, recipientId: $recipientId, text: $messageText');

    if (messageText.isEmpty) {
      debugPrint('[CommunicationHub] Message text is empty, ignoring');
      return;
    }

    final isSender = senderId == user.id;
    final isForMe = recipientId == null || recipientId == user.id;

    final message = _MedicalMessage(
      id: 'message-${DateTime.now().millisecondsSinceEpoch}',
      from: data['sender_name']?.toString(),
      fromId: senderId,
      to: data['recipient_name']?.toString(),
      message: messageText,
      messageType: data['message_type']?.toString() ?? _MessageType.normal,
      timestamp: DateTime.now(),
      isForMe: isForMe,
      isRead: isSender,
    );

    if (!mounted) {
      debugPrint(
          '[CommunicationHub] Widget not mounted, skipping message display');
      return;
    }

    debugPrint(
        '[CommunicationHub] Adding message to list. Current count: ${_messages.length}');
    setState(() {
      _messages.insert(0, message);
      if (_messages.length > 50) {
        _messages.removeLast();
      }
      debugPrint(
          '[CommunicationHub] Message added. New count: ${_messages.length}, Message: ${message.message}');
    });

    if (!isSender && isForMe) {
      _playMessageSound();

      // Show in-app notification banner (if app is in foreground)
      if (mounted) {
        _showNotificationBanner(
          title: 'Message de ${message.from ?? 'Inconnu'}',
          body: message.message,
          color: _messageTypeColor(message.messageType, Theme.of(context)),
        );
      }

      // Show system notification (works even when app is in background)
      final notificationService = ref.read(notificationServiceProvider);
      final senderIdInt = senderId ?? 0;
      notificationService.showMessageNotification(
        senderName: message.from ?? 'Inconnu',
        message: message.message,
        senderId: senderIdInt,
        messageType: message.messageType,
        senderAvatar: data['sender_avatar']?.toString() ??
            data['profile_image']?.toString(),
        payload: {
          'type': 'message',
          'sender_id': senderIdInt,
          'message_id': message.id,
        },
      );
    } else if (isSender) {
      debugPrint(
          '[CommunicationHub] Message from self, not showing notification');
    }
  }

  void _handleEmergencyAlert(dynamic rawData) {
    debugPrint(
        '[CommunicationHub] _handleEmergencyAlert called with: $rawData');
    final data = _normalizeMap(rawData);
    if (data.isEmpty) {
      debugPrint('[CommunicationHub] Emergency alert data is empty');
      return;
    }

    final alert = _EmergencyAlert(
      id: 'emergency-${DateTime.now().millisecondsSinceEpoch}',
      title: data['title']?.toString() ?? 'Alerte',
      message: data['message']?.toString() ?? '',
      severity: data['severity']?.toString() ?? 'high',
      location: data['location']?.toString(),
      requester: data['requester_name']?.toString() ?? 'Inconnu',
      timestamp: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _alerts.insert(0, alert);
      if (_alerts.length > 10) {
        _alerts.removeLast();
      }
    });

    _playEmergencySound();

    // Show in-app notification banner (if app is in foreground)
    if (mounted) {
      _showNotificationBanner(
        title: '🚨 ${alert.title}',
        body: alert.message,
        color: Colors.red,
        persistent: true,
      );
    }

    // Show system notification for emergency (works even when app is in background)
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.showEmergencyNotification(
      title: alert.title,
      message: alert.message,
      location: alert.location ?? '',
      requesterName: alert.requester,
      payload: {
        'type': 'emergency',
        'alert_id': alert.id,
      },
    );
  }

  void _resetState() {
    setState(() {
      _messages.clear();
      _alerts.clear();
      _hubVisible = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNotificationBanner({
    required String title,
    required String body,
    required Color color,
    bool persistent = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        backgroundColor: color,
        duration: persistent
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _playMessageSound() async {
    if (_isMuted) return;
    _messagePlayer ??= AudioPlayer();
    await _messagePlayer!.stop();
    await _messagePlayer!.play(AssetSource('notification/message.mp3'));
  }

  Future<void> _playEmergencySound() async {
    if (_isMuted) return;
    _emergencyPlayer ??= AudioPlayer();
    await _emergencyPlayer!.stop();
    await _emergencyPlayer!.play(AssetSource('notification/emergency.mp3'));
    _emergencyLoopCount = 0;
    await _emergencyLoopSub?.cancel();
    _emergencyLoopSub = _emergencyPlayer!.onPlayerComplete.listen((_) async {
      if (_emergencyLoopCount < 2 && !_isMuted) {
        _emergencyLoopCount += 1;
        await _emergencyPlayer!.seek(Duration.zero);
        await _emergencyPlayer!.resume();
      }
    });
  }

  Map<String, dynamic> _decodeEvent(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Map<String, dynamic> _normalizeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return (jsonDecode(data) as Map).cast<String, dynamic>();
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _resolveTenantDomain(TenantModel? tenant) {
    if (tenant?.domain != null && tenant!.domain!.isNotEmpty) {
      return tenant.domain!;
    }

    final baseUrl = tenant?.baseUrl ?? ApiConstants.baseUrl;
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (_) {
      return 'global';
    }
  }

  String _messageTypeLabel(String type) {
    switch (type) {
      case _MessageType.urgent:
        return '🚨 Urgent';
      case _MessageType.important:
        return '⚠️ Important';
      case _MessageType.info:
        return 'ℹ️ Info';
      default:
        return '💬 Normal';
    }
  }

  Color _messageTypeColor(String type, ThemeData theme) {
    switch (type) {
      case _MessageType.urgent:
        return Colors.red;
      case _MessageType.important:
        return Colors.orange;
      case _MessageType.info:
        return theme.colorScheme.primary;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDate == today) {
      return "Aujourd'hui";
    } else if (messageDate == yesterday) {
      return "Hier";
    } else {
      final months = [
        'Janvier',
        'Février',
        'Mars',
        'Avril',
        'Mai',
        'Juin',
        'Juillet',
        'Août',
        'Septembre',
        'Octobre',
        'Novembre',
        'Décembre'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMessageBubble(
    BuildContext context,
    _MedicalMessage message,
    UserModel user,
    bool isSender,
    ThemeData theme,
    bool isSameSender,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final messageColor = isSender
        ? const Color(0xFF25D366) // WhatsApp green
        : (isDark ? Colors.grey[800]! : Colors.white);
    final textColor =
        isSender ? Colors.white : theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: () {
        if (!message.isRead) {
          setState(() {
            message.isRead = true;
          });
          if (message.fromId != null) {
            final notificationService = ref.read(notificationServiceProvider);
            notificationService.clearSenderNotifications(message.fromId!);
          }
        }
      },
      child: Row(
        mainAxisAlignment:
            isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSender && !isSameSender)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                child: Text(
                  (message.from ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            )
          else if (!isSender)
            const SizedBox(width: 38),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: messageColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isSender ? 12 : 2),
                  bottomRight: Radius.circular(isSender ? 2 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSender && !isSameSender)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.from ?? 'Inconnu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSender
                              ? Colors.white70
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (message.messageType != _MessageType.normal) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _messageTypeColor(message.messageType, theme)
                            .withValues(alpha: isSender ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.messageType == _MessageType.urgent
                                ? Icons.error_rounded
                                : message.messageType == _MessageType.important
                                    ? Icons.warning_rounded
                                    : Icons.info_rounded,
                            size: 12,
                            color: _messageTypeColor(message.messageType, theme)
                                .withValues(alpha: isSender ? 1.0 : 1.0),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _messageTypeLabel(message.messageType),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  _messageTypeColor(message.messageType, theme)
                                      .withValues(alpha: isSender ? 1.0 : 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SelectableText(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSender ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      if (isSender) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: message.isRead
                              ? Colors.blue[300]
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 300))
                .slideY(
                  begin: 0.1,
                  end: 0,
                  curve: Curves.easeOut,
                ),
          ),
          if (isSender) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
    String? hint,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: hint != null
                ? Text(
                    hint,
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  )
                : null,
            onChanged: enabled ? onChanged : null,
            items: items,
            style: const TextStyle(fontSize: 13),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.primary,
            ),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String label,
    Color color, {
    Color textColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MedicalMessage {
  _MedicalMessage({
    required this.id,
    required this.message,
    required this.messageType,
    required this.timestamp,
    required this.isForMe,
    required this.isRead,
    this.from,
    this.fromId,
    this.to,
  });

  final String id;
  final String? from;
  final int? fromId;
  final String? to;
  final String message;
  final String messageType;
  final DateTime timestamp;
  final bool isForMe;
  bool isRead;
}

class _EmergencyAlert {
  _EmergencyAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.requester,
    this.location,
  }) : isActive = true;

  final String id;
  final String title;
  final String message;
  final String severity;
  final String requester;
  final String? location;
  final DateTime timestamp;
  bool isActive;
}

enum _CommunicationTab { messages, emergency }

enum _MessageFilter { all, unread, toMe }

extension on _MessageFilter {
  String get label {
    switch (this) {
      case _MessageFilter.unread:
        return 'Non lus';
      case _MessageFilter.toMe:
        return 'Pour moi';
      default:
        return 'Tous';
    }
  }
}

class _MessageType {
  static const normal = 'normal';
  static const important = 'important';
  static const urgent = 'urgent';
  static const info = 'info';

  static const options = [normal, important, urgent, info];
}

class _EmergencyTitleOption {
  final String label;
  const _EmergencyTitleOption(this.label);
}

const _emergencyTitleOptions = [
  _EmergencyTitleOption('🩺 Assistance médicale'),
  _EmergencyTitleOption('❤️ Urgence cardiaque'),
  _EmergencyTitleOption('🚑 Chute de patient'),
  _EmergencyTitleOption('🫁 Crise respiratoire'),
  _EmergencyTitleOption('🔵 Alerte code bleu'),
];

const _emergencyMessages = [
  'Assistance immédiate requise',
  'Patient en détresse',
  'Intervention médicale urgente',
  'Équipe de réanimation nécessaire',
  'Situation critique',
];

const _emergencyLocations = [
  'Salle de Consultation 1',
  'Salle de Soins',
  'Salle d\'Échographie',
  'Salle de Radiologie',
  'Salle d\'Observation',
  'Salle d\'Urgence',
  'Salle de Pansement',
  'Salle d\'Infirmiers',
  'Bureau du Médecin Généraliste',
  'Bureau du Gynécologue',
  'Bureau du Pédiatre',
  'Bloc de Petite Chirurgie',
  'Salle de Réveil',
  'Accueil / Réception',
  'Pharmacie Interne',
  'Salle d\'Attente',
  'Laboratoire',
  'Couloir Principal',
  'Couloir Consultation',
];
