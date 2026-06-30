// lib/widgets/ai_assistant_positioned_widget.dart
// AI Assistant with customizable position

import 'package:flutter/material.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

/// AI Assistant Widget with customizable position
/// Better placement options for different screen layouts
class AiAssistantPositionedWidget extends StatefulWidget {
  final AiChatService? aiChatService;
  final Color? buttonColor;
  final AiAssistantPosition position;
  final ValueChanged<bool>?
      onOpenStateChanged; // Callback when chatbox opens/closes

  const AiAssistantPositionedWidget({
    super.key,
    this.aiChatService,
    this.buttonColor,
    this.position = AiAssistantPosition.bottomRight,
    this.onOpenStateChanged,
  });

  @override
  State<AiAssistantPositionedWidget> createState() =>
      _AiAssistantPositionedWidgetState();
}

enum AiAssistantPosition {
  topRight, // Top-right corner (common for chat widgets)
  topLeft, // Top-left corner
  bottomRight, // Bottom-right (default)
  bottomLeft, // Bottom-left (good if FAB is on right)
  bottomCenter, // Bottom center
}

class _AiAssistantPositionedWidgetState
    extends State<AiAssistantPositionedWidget> {
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

  Positioned _buildPositionedButton() {
    final buttonColor = widget.buttonColor ?? Colors.indigo;
    final position = widget.position;

    if (!_isOpen) {
      // Button position based on enum
      double? top, bottom, left, right;

      switch (position) {
        case AiAssistantPosition.topRight:
          top = 80; // Below app bar
          right = 16;
          break;
        case AiAssistantPosition.topLeft:
          top = 80;
          left = 16;
          break;
        case AiAssistantPosition.bottomRight:
          bottom = 20;
          right = 20;
          break;
        case AiAssistantPosition.bottomLeft:
          bottom = 20;
          left = 20;
          break;
        case AiAssistantPosition.bottomCenter:
          bottom = 20;
          left = 0;
          right = 0;
          break;
      }

      return Positioned(
        top: top,
        bottom: bottom,
        left: position == AiAssistantPosition.bottomCenter ? null : left,
        right: position == AiAssistantPosition.bottomCenter ? null : right,
        child: position == AiAssistantPosition.bottomCenter
            ? Center(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: buttonColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.chat, color: Colors.white, size: 28),
                      onPressed: () {
                        widget.onOpenStateChanged?.call(true); // Call first
                        setState(() {
                          _isOpen = true;
                        });
                      },
                      tooltip: 'Ouvrir l\'assistant IA',
                    ),
                  ),
                ),
              )
            : Material(
                elevation: 10, // Higher than FAB (FAB is usually 6)
                borderRadius: BorderRadius.circular(30),
                shadowColor: Colors.black.withOpacity(0.3),
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

    // Chat window position
    double? top, bottom, left, right;

    switch (position) {
      case AiAssistantPosition.topRight:
        top = 80;
        right = 16;
        break;
      case AiAssistantPosition.topLeft:
        top = 80;
        left = 16;
        break;
      case AiAssistantPosition.bottomRight:
        bottom = 20;
        right = 20;
        break;
      case AiAssistantPosition.bottomLeft:
        bottom = 20;
        left = 20;
        break;
      case AiAssistantPosition.bottomCenter:
        bottom = 20;
        left = 0;
        right = 0;
        break;
    }

    // When chatbox is open, add a backdrop and ensure it's on top
    // Use IgnorePointer to ensure backdrop captures all touches
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            // Backdrop to dim background and ensure chatbox is on top
            // This will cover the FAB completely
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  // Close chatbox when tapping backdrop
                  FocusScope.of(context).unfocus();
                  widget.onOpenStateChanged?.call(false); // Call first
                  setState(() {
                    _isOpen = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.4), // Darker backdrop
                ),
              ),
            ),
            // Chat window
            Positioned(
              top: top,
              bottom: bottom,
              left: position == AiAssistantPosition.bottomCenter ? null : left,
              right:
                  position == AiAssistantPosition.bottomCenter ? null : right,
              child: GestureDetector(
                onTap:
                    () {}, // Prevent backdrop tap from closing when tapping chatbox
                child: position == AiAssistantPosition.bottomCenter
                    ? Center(
                        child: Material(
                          elevation:
                              30, // Very high elevation to appear above FAB
                          borderRadius: BorderRadius.circular(16),
                          shadowColor: Colors.black.withOpacity(0.4),
                          child: Container(
                            width: 380,
                            constraints: const BoxConstraints(
                              maxHeight: 600,
                              minHeight: 400,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _buildChatContent(buttonColor),
                          ),
                        ),
                      )
                    : Material(
                        elevation:
                            30, // Very high elevation to appear above FAB
                        borderRadius: BorderRadius.circular(16),
                        shadowColor: Colors.black.withOpacity(0.4),
                        child: Container(
                          width: 380,
                          // Height will be dynamic based on keyboard
                          constraints: const BoxConstraints(
                            maxHeight: 600,
                            minHeight: 400,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _buildChatContent(buttonColor),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatContent(Color buttonColor) {
    // Get keyboard height to adjust chat window
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate max height: if keyboard is open, make it smaller
    final maxHeight = keyboardHeight > 0
        ? (screenHeight - keyboardHeight - 100)
            .clamp(300.0, 600.0) // Adjust for keyboard
        : 600.0; // Fixed height when keyboard is closed

    return Container(
      // Adjust height based on keyboard
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        minHeight: 300.0,
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
                    // Dismiss keyboard first
                    FocusScope.of(context).unfocus();
                    widget.onOpenStateChanged?.call(false); // Call first
                    setState(() {
                      _isOpen = false;
                    });
                  },
                ),
              ],
            ),
          ),
          // Messages - Flexible to take available space
          Flexible(
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
          // Input - Always visible at bottom
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: keyboardHeight > 0
                  ? 8
                  : 16, // Less padding when keyboard is open
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
                      maxLines: null, // Allow multiple lines
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Tapez votre message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) {
                        // Auto-scroll when typing
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      },
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPositionedButton();
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
