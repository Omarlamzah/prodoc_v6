// lib/core/config/realtime_config.dart
enum RealtimeMode { socket, pusher }

class RealtimeConfig {
  static const String _mode =
      String.fromEnvironment('REALTIME_MODE', defaultValue: 'pusher');

  static RealtimeMode get mode => _mode.toLowerCase() == 'socket'
      ? RealtimeMode.socket
      : RealtimeMode.pusher;

  static const String pusherKey = String.fromEnvironment('PUSHER_KEY',
      defaultValue: '7d9d287008e8241767e9');
  static const String pusherCluster =
      String.fromEnvironment('PUSHER_CLUSTER', defaultValue: 'eu');

  static const String socketHost =
      String.fromEnvironment('SOCKET_HOST', defaultValue: '10.0.2.2');
  static const int socketPort =
      int.fromEnvironment('SOCKET_PORT', defaultValue: 6001);

  static bool get hasPusherConfig =>
      pusherKey.isNotEmpty && pusherCluster.isNotEmpty;

  static String messageChannel(String tenantDomain) =>
      'tenant.$tenantDomain.messages';

  static String emergencyChannel(String tenantDomain) =>
      'tenant.$tenantDomain.emergency';
}
