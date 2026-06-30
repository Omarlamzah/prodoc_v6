// lib/services/communication_service.dart
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';

class CommunicationService {
  final ApiClient apiClient;

  CommunicationService({required this.apiClient});

  Future<Result<void>> sendMessage({
    required String message,
    required String messageType,
    required int senderId,
    required String senderName,
    String? recipientId,
    String? profileImage,
  }) async {
    try {
      await apiClient.post(
        ApiConstants.sendMessage,
        body: {
          'message': message,
          'message_type': messageType,
          'sender_id': senderId,
          'sender_name': senderName,
          'recipient_id': recipientId,
          'profile_image': profileImage,
        },
        requireAuth: true,
      );
      return const Success(null);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Impossible d\'envoyer le message : $e');
    }
  }

  Future<Result<void>> sendEmergency({
    required String title,
    required String body,
    required String location,
    required int requesterId,
    required String requesterName,
    String severity = 'high',
  }) async {
    try {
      await apiClient.post(
        ApiConstants.sendEmergency,
        body: {
          'title': title,
          'message': body,
          'location': location,
          'severity': severity,
          'requester_id': requesterId,
          'requester_name': requesterName,
        },
        requireAuth: true,
      );
      return const Success(null);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Impossible d\'envoyer l\'alerte : $e');
    }
  }
}
