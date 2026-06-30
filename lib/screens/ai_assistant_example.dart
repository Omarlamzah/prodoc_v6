// lib/screens/ai_assistant_example.dart
// Example: How to integrate AI Assistant in your screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';

/// Example screen showing how to integrate AI Assistant
class AiAssistantExampleScreen extends ConsumerWidget {
  const AiAssistantExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the AI chat service from provider
    final aiChatService = ref.watch(aiChatServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant Example'),
      ),
      body: Stack(
        children: [
          // Your main content here
          const Center(
            child: Text(
              'Your app content goes here.\n\n'
              'The AI Assistant floating button will appear in the bottom-right corner.',
              textAlign: TextAlign.center,
            ),
          ),

          // AI Assistant Widget (floating)
          AiAssistantWidget(
            aiChatService: aiChatService,
            // Optional: customize colors
            primaryColor: Colors.indigo,
            secondaryColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}

/// Alternative: Using StatefulWidget
class AiAssistantExampleStatefulScreen extends ConsumerStatefulWidget {
  const AiAssistantExampleStatefulScreen({super.key});

  @override
  ConsumerState<AiAssistantExampleStatefulScreen> createState() =>
      _AiAssistantExampleStatefulScreenState();
}

class _AiAssistantExampleStatefulScreenState
    extends ConsumerState<AiAssistantExampleStatefulScreen> {
  @override
  Widget build(BuildContext context) {
    final aiChatService = ref.watch(aiChatServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant Example'),
      ),
      body: Stack(
        children: [
          // Your content
          const Center(
            child: Text('Your content here'),
          ),

          // AI Assistant
          AiAssistantWidget(
            aiChatService: aiChatService,
          ),
        ],
      ),
    );
  }
}
