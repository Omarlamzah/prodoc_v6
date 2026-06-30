// lib/screens/ai_chatbox_test_screen.dart
// COPY THIS FILE TO TEST THE AI CHATBOX
// Then navigate to this screen to see the chatbox

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';

/// Test screen to verify AI chatbox is working
/// Add this route to your app and navigate to it
class AiChatboxTestScreen extends ConsumerWidget {
  const AiChatboxTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get AI chat service from provider
    final aiChatService = ref.watch(aiChatServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chatbox Test'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        children: [
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat,
                  size: 64,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 16),
                const Text(
                  'AI Chatbox Test',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Look for the floating chat button in the bottom-right corner!\n\n'
                    'Click it to open the AI Assistant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // You can test by clicking this button
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Chatbox should be visible in bottom-right!'),
                      ),
                    );
                  },
                  child: const Text('Test Button'),
                ),
              ],
            ),
          ),

          // AI Assistant Widget - THIS IS THE CHATBOX!
          // It will appear as a floating button in bottom-right
          AiAssistantWidget(
            aiChatService: aiChatService,
            primaryColor: Colors.indigo,
            secondaryColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}
