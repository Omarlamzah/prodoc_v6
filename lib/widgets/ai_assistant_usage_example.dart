// lib/widgets/ai_assistant_usage_example.dart
// Example of how to use the comprehensive AI Assistant widget

import 'package:flutter/material.dart';
import 'ai_assistant_comprehensive.dart';
import '../services/ai_chat_service.dart';
import '../data/models/user_model.dart';
import '../core/network/api_client.dart';

/// Example screen showing how to integrate the AI Assistant
class AiAssistantExampleScreen extends StatelessWidget {
  final AiChatService aiChatService;
  final UserModel? user;

  const AiAssistantExampleScreen({
    super.key,
    required this.aiChatService,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant Example'),
      ),
      body: Stack(
        children: [
          // Your main content here
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'AI Assistant is available',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap the floating button in the bottom right',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // AI Assistant Widget - positioned in bottom right
          AiAssistantComprehensive(
            aiChatService: aiChatService,
            user: user,
          ),
        ],
      ),
    );
  }
}

/// Alternative: Using in a provider-based setup
/// 
/// ```dart
/// class MyApp extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final aiChatService = ref.watch(aiChatServiceProvider);
///     final user = ref.watch(authProvider)?.user;
///     
///     return Scaffold(
///       body: Stack(
///         children: [
///           // Your main content
///           YourMainContent(),
///           
///           // AI Assistant
///           AiAssistantComprehensive(
///             aiChatService: aiChatService,
///             user: user,
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
