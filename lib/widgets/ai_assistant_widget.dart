// lib/widgets/ai_assistant_widget.dart
import 'package:flutter/material.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

/// A floating AI assistant widget that provides chat interface
/// Similar to the Next.js AI Assistant component
class AiAssistantWidget extends StatefulWidget {
  final AiChatService? aiChatService;
  final Color? primaryColor;
  final Color? secondaryColor;

  const AiAssistantWidget({
    super.key,
    this.aiChatService,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends State<AiAssistantWidget> {
  bool _isOpen = false;
  bool _isMinimized = false;
  bool _isLoading = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Suggested questions (similar to Next.js version)
  final List<String> _suggestedQuestions = [
    "Quels sont les symptômes courants de la grippe?",
    "Comment créer un nouveau dossier médical?",
    "Combien de patients avons-nous aujourd'hui?",
    "Liste tous les rendez-vous de cette semaine",
    "Quelles sont les meilleures pratiques pour la documentation médicale?",
  ];

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      role: 'assistant',
      content:
          'Bonjour! Je suis votre assistant IA médical. Comment puis-je vous aider aujourd\'hui?',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String? messageText) async {
    final textToSend = messageText ?? _textController.text.trim();
    if (textToSend.isEmpty || _isLoading || widget.aiChatService == null) {
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

  void _handleSuggestedQuestion(String question) {
    _textController.text = question;
    _sendMessage(question);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final secondaryColor = widget.secondaryColor ?? Colors.purple;

    if (!_isOpen) {
      // Floating button (closed state)
      return Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton(
          onPressed: () {
            setState(() {
              _isOpen = true;
              _isMinimized = false;
            });
          },
          backgroundColor: primaryColor,
          child: Stack(
            children: [
              const Icon(Icons.chat, color: Colors.white),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Chat window (open state)
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        width: _isMinimized ? 300 : 400,
        height: _isMinimized ? 60 : 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isMinimized
            ? _buildMinimizedHeader(primaryColor, secondaryColor)
            : Column(
                children: [
                  _buildHeader(primaryColor, secondaryColor),
                  Expanded(
                    child: _buildMessagesList(),
                  ),
                  if (_messages.length == 1) _buildSuggestedQuestions(),
                  _buildInputArea(primaryColor),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, Color secondaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              setState(() {
                _isOpen = false;
              });
            },
            tooltip: 'Effacer la conversation',
          ),
          IconButton(
            icon: Icon(
              _isMinimized ? Icons.expand_more : Icons.expand_less,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isMinimized = !_isMinimized;
              });
            },
            tooltip: _isMinimized ? 'Agrandir' : 'Réduire',
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedHeader(Color primaryColor, Color secondaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
                fontSize: 16,
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
          IconButton(
            icon: const Icon(Icons.expand_less, color: Colors.white),
            onPressed: () {
              setState(() {
                _isMinimized = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          // Loading indicator
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
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
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.smart_toy, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isUser ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.person, size: 20, color: Colors.blue),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions suggérées:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions.take(3).map((question) {
              return InkWell(
                onTap: () => _handleSuggestedQuestion(question),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(Color primaryColor) {
    return Container(
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
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(null),
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
                : Icon(Icons.send, color: primaryColor),
            onPressed: _isLoading ? null : () => _sendMessage(null),
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
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}
