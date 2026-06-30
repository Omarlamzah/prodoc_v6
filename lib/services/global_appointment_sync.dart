// lib/services/global_appointment_sync.dart
// Global appointment sync service that runs in background

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/appointment_providers.dart';
import 'appointment_sync_service.dart';

/// Global appointment sync service
/// Syncs appointments in the background when user is authenticated
class GlobalAppointmentSync {
  static final GlobalAppointmentSync _instance = GlobalAppointmentSync._internal();
  factory GlobalAppointmentSync() => _instance;
  GlobalAppointmentSync._internal();

  final AppointmentSyncService _syncService = AppointmentSyncService();
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Start global appointment sync
  /// Call this when user logs in or app comes to foreground
  void startSync(WidgetRef ref) {
    // Stop any existing timer
    stopSync();

    // Sync immediately
    _syncAppointments(ref);

    // Set up periodic sync every 5 minutes
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _syncAppointments(ref),
    );

    debugPrint('[GlobalAppointmentSync] Started global appointment sync');
  }

  /// Stop global appointment sync
  /// Call this when user logs out
  void stopSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    debugPrint('[GlobalAppointmentSync] Stopped global appointment sync');
  }

  /// Sync appointments from API
  Future<void> _syncAppointments(WidgetRef ref) async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      debugPrint('[GlobalAppointmentSync] Sync already in progress, skipping');
      return;
    }

    // Check if user is authenticated
    final authState = ref.read(authProvider);
    if (authState.isAuth != true) {
      debugPrint('[GlobalAppointmentSync] User not authenticated, skipping sync');
      return;
    }

    // Don't sync too frequently (minimum 1 minute between syncs)
    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync.inMinutes < 1) {
        debugPrint('[GlobalAppointmentSync] Sync too recent, skipping');
        return;
      }
    }

    _isSyncing = true;
    _lastSyncTime = DateTime.now();

    try {
      debugPrint('[GlobalAppointmentSync] Starting appointment sync...');

      // Fetch appointments from API
      final params = AppointmentsParams(
        page: 1,
        status: null, // Get all statuses
      );

      final result = await ref.read(appointmentsProvider(params).future);

      result.when(
        success: (appointments) {
          // Sync appointments and schedule reminders
          _syncService.syncAppointments(appointments).then((_) {
            debugPrint(
              '[GlobalAppointmentSync] Successfully synced ${appointments.length} appointments',
            );
          }).catchError((e) {
            debugPrint('[GlobalAppointmentSync] Error syncing appointments: $e');
          });
        },
        failure: (error) {
          debugPrint('[GlobalAppointmentSync] Failed to fetch appointments: $error');
        },
      );
    } catch (e) {
      debugPrint('[GlobalAppointmentSync] Error in sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Force immediate sync (useful for manual refresh)
  Future<void> forceSync(WidgetRef ref) async {
    _lastSyncTime = null; // Reset last sync time to force immediate sync
    await _syncAppointments(ref);
  }

  /// Check if sync is currently running
  bool get isSyncing => _isSyncing;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;
}

/// Provider for global appointment sync
final globalAppointmentSyncProvider = Provider<GlobalAppointmentSync>((ref) {
  return GlobalAppointmentSync();
});
