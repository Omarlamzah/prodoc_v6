// lib/screens/ai_chat_screen.dart
// Dedicated AI Chat Screen - Full screen, no positioning issues

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/result.dart';
import '../providers/api_providers.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
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
    
    // Auto-focus input when screen opens
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

    final aiChatService = ref.read(aiChatServiceProvider);

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
    final result = await aiChatService.sendMessage(textToSend);

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Assistant IA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
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
                          radius: 20,
                          backgroundColor: Colors.indigo[100],
                          child: const Icon(Icons.smart_toy, color: Colors.indigo, size: 24),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.indigo : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                  height: 1.5,
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
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, color: Colors.blue, size: 24),
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
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
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
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tapez votre message...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: Colors.indigo, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) {
                        _scrollToBottom();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _isLoading ? null : _sendMessage,
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 24),
                        ),
                      ),
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
