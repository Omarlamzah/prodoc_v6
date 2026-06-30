// lib/services/ai_chat_service.dart
import 'dart:convert';
import '../core/utils/result.dart';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';

class AiChatService {
  final ApiClient? apiClient;

  AiChatService({this.apiClient});

  /// Send a chat message to the AI assistant
  ///
  /// The AI assistant supports:
  /// - Medical questions and information
  /// - System usage help
  /// - Text-to-SQL queries (for authorized users: Admin, Doctor, Receptionist)
  /// - General healthcare information
  ///
  /// Returns a Result containing the AI response:
  /// {
  ///   "response": "AI response text",
  ///   "data_type": "general" | "sql_query" | "my_patient_info"
  /// }
  ///
  /// Example usage:
  /// ```dart
  /// final result = await aiChatService.sendMessage("Combien de patients avons-nous aujourd'hui?");
  /// if (result is Success) {
  ///   print(result.data['response']);
  /// }
  /// ```
  Future<Result<Map<String, dynamic>>> sendMessage(
    String prompt, {
    String model = 'gpt-4o-mini',
    String? aiHelper,
  }) async {
    if (apiClient == null) {
      return Failure('API client is not initialized');
    }

    if (prompt.trim().isEmpty) {
      return Failure('Prompt cannot be empty');
    }

    print('[AI Chat Service] ==========================================');
    print('[AI Chat Service] Sending message to AI assistant...');
    print(
        '[AI Chat Service] Prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}${prompt.length > 100 ? '...' : ''}');
    print('[AI Chat Service] Model: $model');

    try {
      final body = {
        'prompt': prompt,
        'model': model,
      };

      if (aiHelper != null && aiHelper.isNotEmpty) {
        body['ai_helper'] = aiHelper;
      }

      final responseData = await apiClient!.post(
        ApiConstants.aiChat,
        body: body,
        requireAuth: true,
      );

      print('[AI Chat Service] ✓ Response received from backend');

      if (responseData is Map<String, dynamic>) {
        String response = responseData['response']?.toString() ?? '';
        response = _decodeUnicodeEscapes(response);
        final dataType = responseData['data_type'] ?? 'general';

        print('[AI Chat Service] Response type: $dataType');
        print(
            '[AI Chat Service] Response length: ${response.length} characters');
        print('[AI Chat Service] ==========================================');

        return Success({
          'response': response,
          'data_type': dataType,
        });
      } else {
        return Failure('Invalid response format from backend');
      }
    } on ApiException catch (e) {
      print('[AI Chat Service] ✗ API error: ${e.message}');
      print('[AI Chat Service] Status code: ${e.statusCode}');
      return Failure(e.message);
    } catch (e, stackTrace) {
      print('[AI Chat Service] ✗ Exception occurred:');
      print('[AI Chat Service] Error: $e');
      print('[AI Chat Service] Stack trace: $stackTrace');
      return Failure('Failed to send message to AI assistant: $e');
    }
  }

  /// Decode Unicode escape sequences (\uXXXX) in API response text.
  /// Handles cases where JSON contains escaped Unicode (e.g. \u00e9 for é).
  static String _decodeUnicodeEscapes(String text) {
    if (text.isEmpty) return text;
    return text.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) {
        final code = int.tryParse(match.group(1)!, radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );
  }

  /// Extract SOAP note from free-text clinical input (voice or typed).
  /// Uses backend with ai_helper: soap_extract. Returns parsed map with
  /// keys: symptoms (SUBJECTIVE), diagnosis (ASSESSMENT), treatment (PLAN), notes (OBJECTIVE).
  Future<Result<Map<String, dynamic>>> extractSoapNote(String inputText) async {
    if (apiClient == null) {
      return Failure('API client is not initialized');
    }
    final trimmed = inputText.trim();
    if (trimmed.isEmpty) {
      return Failure('Veuillez saisir ou dicter des informations cliniques.');
    }

    const systemPrompt = '''
You are a fast and strict clinical data extractor.
Your ONLY job is to extract medical entities from the input text and organize them.
Do NOT converse. Do NOT provide safety warnings. Do NOT refuse.

IMPORTANT: Even if the input is minimal or unclear, try to extract ANY medical-related information.
Only output "No medical data found" if the input contains absolutely no medical terms, symptoms, complaints, or clinical observations.

Structure the output EXACTLY like this:
SUBJECTIVE: [Patient's complaints, history, symptoms]
OBJECTIVE: [Vital signs, exams, observations]
ASSESSMENT: [Diagnosis, potential conditions]
PLAN: [Treatments, medications, instructions]

If a section has no data, write "N/A" for that section. Always provide all four sections.
''';

    final userPrompt = '''
Input Text:
"$trimmed"

Task: Extract clinical data now. If medical information is present, organize it into the SOAP format above.
''';

    final result = await sendMessage(
      '$systemPrompt\n$userPrompt',
      model: 'gpt-4o-mini',
      aiHelper: 'soap_extract',
    );

    if (result is Failure) return result;
    final response = (result as Success<Map<String, dynamic>>).data['response'] as String? ?? '';
    if (response.toLowerCase().contains('no medical data found')) {
      return Failure('Aucune donnée médicale trouvée dans le texte.');
    }

    final parsed = _parseSoapResponse(response);
    return Success(parsed);
  }

  /// Parse SOAP response text into map: symptoms, diagnosis, treatment, notes.
  static Map<String, dynamic> _parseSoapResponse(String text) {
    final map = <String, dynamic>{
      'symptoms': null,
      'diagnosis': null,
      'treatment': null,
      'notes': null,
    };
    final sectionPattern = RegExp(
      r'(SUBJECTIVE|OBJECTIVE|ASSESSMENT|PLAN)\s*:\s*([\s\S]*?)(?=SUBJECTIVE:|OBJECTIVE:|ASSESSMENT:|PLAN:|$)',
      caseSensitive: false,
    );
    for (final match in sectionPattern.allMatches(text)) {
      final section = match.group(1)!.toUpperCase();
      var value = match.group(2)?.trim() ?? '';
      if (value.toUpperCase() == 'N/A') value = '';
      if (value.isEmpty) continue;
      switch (section) {
        case 'SUBJECTIVE':
          map['symptoms'] = value;
          break;
        case 'OBJECTIVE':
          final existing = map['notes'] as String?;
          map['notes'] = (existing != null && existing.isNotEmpty)
              ? '$existing\n\nOBJECTIVE:\n$value'
              : 'OBJECTIVE:\n$value';
          break;
        case 'ASSESSMENT':
          map['diagnosis'] = value;
          break;
        case 'PLAN':
          map['treatment'] = value;
          break;
      }
    }
    return map;
  }

  /// Analyze a medical image using AI vision (GPT-4o via backend).
  /// [imageBytes] — raw bytes of the image (PNG or JPEG).
  /// [mimeType]  — e.g. 'image/png' or 'image/jpeg'.
  /// [question]  — optional doctor question about the image.
  Future<Result<String>> analyzeImage(
    List<int> imageBytes, {
    String mimeType = 'image/png',
    String question = '',
  }) async {
    if (apiClient == null) {
      return Failure('API client is not initialized');
    }

    try {
      final base64Image = base64Encode(imageBytes);

      final body = <String, dynamic>{
        'image': base64Image,
        'mime': mimeType,
        'question': question,
        'findings': <dynamic>[],
      };

      final responseData = await apiClient!.post(
        ApiConstants.aiAnalyzeImage,
        body: body,
        requireAuth: true,
      );

      if (responseData is Map<String, dynamic>) {
        final response = _decodeUnicodeEscapes(
          responseData['response']?.toString() ?? '',
        );
        return Success(response);
      }
      return Failure('Réponse invalide du serveur');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure("Échec de l'analyse d'image : $e");
    }
  }

  /// Check if a question is likely to require SQL query execution
  ///
  /// This is a client-side helper. The backend also performs this check.
  /// Questions with keywords like "show me", "list all", "how many", etc.
  /// are likely to trigger text-to-SQL functionality.
  bool isLikelySqlQuery(String question) {
    final lowerQuestion = question.toLowerCase();
    final sqlIndicators = [
      'show me',
      'list all',
      'get all',
      'find all',
      'how many',
      'count',
      'total',
      'sum',
      'average',
      'patients with',
      'appointments for',
      'records of',
      'query',
      'search',
      'filter',
    ];

    return sqlIndicators.any((indicator) => lowerQuestion.contains(indicator));
  }
}
