// lib/widgets/ai_chat_modal.dart
// Brand new AI Chat implementation using Modal Bottom Sheet
// This approach ensures it appears above everything including FABs

import 'package:flutter/material.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

/// AI Chat Modal - Opens as a bottom sheet that appears above everything
class AiChatModal {
  /// Show the AI chat modal
  static void show(BuildContext context, {required AiChatService aiChatService}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full screen
      backgroundColor: Colors.transparent, // Transparent background
      enableDrag: true, // Allow dragging to dismiss
      isDismissible: true, // Allow tapping outside to dismiss
      builder: (context) => _AiChatModalContent(aiChatService: aiChatService),
    );
  }
}

class _AiChatModalContent extends StatefulWidget {
  final AiChatService aiChatService;

  const _AiChatModalContent({required this.aiChatService});

  @override
  State<_AiChatModalContent> createState() => _AiChatModalContentState();
}

class _AiChatModalContentState extends State<_AiChatModalContent> {
  bool _isLoading = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      role: 'assistant',
      content: 'Bonjour! Je suis votre assistant IA médical. Comment puis-je vous aider aujourd\'hui?',
      timestamp: DateTime.now(),
    ));
    
    // Auto-focus input when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final textToSend = _textController.text.trim();
    if (textToSend.isEmpty || _isLoading) {
      return;
    }

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: textToSend,
        timestamp: DateTime.now(),
      ));
      _textController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    // Send to AI
    final result = await widget.aiChatService.sendMessage(textToSend);

    setState(() {
      _isLoading = false;
      if (result is Success<Map<String, dynamic>>) {
        final response = result.data['response'] ?? 'Désolé, je n\'ai pas pu générer de réponse.';
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response,
          timestamp: DateTime.now(),
        ));
      } else {
        final errorMessage = result is Failure
            ? (result as Failure).message
            : 'Désolé, une erreur s\'est produite. Veuillez réessayer.';
        _messages.add(ChatMessage(
          role: 'assistant',
          content: errorMessage,
          timestamp: DateTime.now(),
        ));
      }
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate height: full screen minus safe area, adjust for keyboard
    final maxHeight = screenHeight - MediaQuery.of(context).padding.top - (keyboardHeight > 0 ? 0 : 50);

    return Container(
      height: maxHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar (for dragging)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Assistant IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Messages list
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
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.indigo[100],
                          child: const Icon(Icons.smart_toy, color: Colors.indigo, size: 22),
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
                            color: isUser ? Colors.indigo : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(message.timestamp),
                                style: TextStyle(
                                  color: isUser ? Colors.white70 : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, color: Colors.blue, size: 22),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: keyboardHeight > 0 ? 8 : MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Tapez votre message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.indigo, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) => _scrollToBottom(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours} h';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
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
