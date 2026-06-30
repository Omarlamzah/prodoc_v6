// lib/screens/ai_chatbox_visible_test.dart
// TEST SCREEN - Chatbox will DEFINITELY be visible here
// Use this to verify the chatbox works

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_simple_widget.dart';
import '../providers/api_providers.dart';

/// Test screen with ALWAYS VISIBLE chatbox
/// The button will be in the bottom-right corner
class AiChatboxVisibleTest extends ConsumerWidget {
  const AiChatboxVisibleTest({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chatbox Test - ALWAYS VISIBLE'),
        backgroundColor: Colors.red, // Red to make it obvious
      ),
      body: Stack(
        children: [
          // Background content
          Container(
            color: Colors.grey[100],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
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
                        const Text(
                          'Look at the BOTTOM-RIGHT corner!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'You should see a BLUE/INDIGO button',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text('in the bottom-right corner'),
                              SizedBox(height: 4),
                              Text('Click it to open the chat!'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Button should be visible in bottom-right!',
                                  style: TextStyle(fontSize: 16),
                                ),
                                duration: Duration(seconds: 3),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.info),
                          label: const Text('Click to verify'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // AI Chatbox - THIS IS THE BUTTON!
          // It MUST be at the end of the Stack children
          AiAssistantSimpleWidget(
            aiChatService: aiChatService,
            buttonColor: Colors.indigo,
          ),
        ],
      ),
    );
  }
}
