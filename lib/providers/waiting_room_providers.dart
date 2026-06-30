// lib/providers/waiting_room_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/waiting_room_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

// Waiting room data provider
final waitingRoomProvider =
    FutureProvider.autoDispose<Result<WaitingRoomData>>((ref) async {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    return const Failure('Not authenticated');
  }

  final appointmentService = ref.watch(appointmentServiceProvider);
  return await appointmentService.fetchWaitingRoomData();
});

// Refresh provider for manual refresh
final waitingRoomRefreshProvider = NotifierProvider<WaitingRoomRefreshNotifier, int>(WaitingRoomRefreshNotifier.new);

class WaitingRoomRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

// Auto-refresh provider that refreshes every 2 minutes
final waitingRoomAutoRefreshProvider =
    StreamProvider.autoDispose<Result<WaitingRoomData>>((ref) async* {
  final authState = ref.watch(authProvider);

  if (authState.isAuth != true) {
    yield const Failure('Not authenticated');
    return;
  }

  final appointmentService = ref.watch(appointmentServiceProvider);

  // Initial fetch
  yield await appointmentService.fetchWaitingRoomData();

  // Refresh every 2 minutes
  await for (final _ in Stream.periodic(const Duration(minutes: 2))) {
    if (ref.watch(authProvider).isAuth == true) {
      yield await appointmentService.fetchWaitingRoomData();
    }
  }
});
