// lib/widgets/ai_assistant_simple_widget.dart
// SIMPLER VERSION - Always visible, easier to debug

import 'package:flutter/material.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

/// Simplified AI Assistant Widget - Always visible button
/// Use this if the regular widget isn't showing
class AiAssistantSimpleWidget extends StatefulWidget {
  final AiChatService? aiChatService;
  final Color? buttonColor;

  const AiAssistantSimpleWidget({
    super.key,
    this.aiChatService,
    this.buttonColor,
  });

  @override
  State<AiAssistantSimpleWidget> createState() =>
      _AiAssistantSimpleWidgetState();
}

class _AiAssistantSimpleWidgetState extends State<AiAssistantSimpleWidget> {
  bool _isOpen = false;
  bool _isLoading = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      role: 'assistant',
      content:
          'Bonjour! Je suis votre assistant IA médical. Comment puis-je vous aider?',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final textToSend = _textController.text.trim();
    if (textToSend.isEmpty || _isLoading || widget.aiChatService == null) {
      return;
    }

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: textToSend,
        timestamp: DateTime.now(),
      ));
      _textController.clear();
      _isLoading = true;
    });

    final result = await widget.aiChatService!.sendMessage(textToSend);

    setState(() {
      _isLoading = false;
      if (result is Success<Map<String, dynamic>>) {
        final response = result.data['response'] ??
            'Désolé, je n\'ai pas pu générer de réponse.';
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response,
          timestamp: DateTime.now(),
        ));
      } else {
        final errorMessage = result is Failure
            ? (result as Failure).message
            : 'Désolé, une erreur s\'est produite.';
        _messages.add(ChatMessage(
          role: 'assistant',
          content: errorMessage,
          timestamp: DateTime.now(),
        ));
      }
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.buttonColor ?? Colors.indigo;

    if (!_isOpen) {
      // Simple floating button - ALWAYS VISIBLE
      return Positioned(
        bottom: 20,
        right: 20,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.chat, color: Colors.white, size: 28),
              onPressed: () {
                setState(() {
                  _isOpen = true;
                });
              },
              tooltip: 'Ouvrir l\'assistant IA',
            ),
          ),
        ),
      );
    }

    // Chat window
    return Positioned(
      bottom: 20,
      right: 20,
      child: Material(
        elevation: 16,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 380,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Assistant IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isOpen = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final message = _messages[index];
                    final isUser = message.role == 'user';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            const CircleAvatar(
                              radius: 16,
                              child: Icon(Icons.smart_toy, size: 20),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isUser ? buttonColor : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          if (isUser) ...[
                            const SizedBox(width: 8),
                            const CircleAvatar(
                              radius: 16,
                              child: Icon(Icons.person, size: 20),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Tapez votre message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send, color: buttonColor),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}
