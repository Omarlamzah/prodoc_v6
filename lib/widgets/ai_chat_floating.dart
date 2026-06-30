// lib/widgets/ai_chat_floating.dart
// Flexible, draggable AI chat widget
// Can be positioned anywhere, resized, and customized

import 'package:flutter/material.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

/// Flexible floating AI chat widget
/// Draggable, resizable, and customizable
class AiChatFloating extends StatefulWidget {
  final AiChatService? aiChatService;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Offset initialPosition;
  final Size initialSize;
  final bool isDraggable;
  final bool isResizable;

  const AiChatFloating({
    super.key,
    this.aiChatService,
    this.primaryColor,
    this.secondaryColor,
    this.initialPosition = const Offset(20, 100),
    this.initialSize = const Size(360, 500),
    this.isDraggable = true,
    this.isResizable = true,
  });

  @override
  State<AiChatFloating> createState() => _AiChatFloatingState();
}

class _AiChatFloatingState extends State<AiChatFloating> {
  bool _isOpen = false;
  bool _isMinimized = false;
  bool _isLoading = false;
  Offset _position = const Offset(20, 100);
  Size _size = const Size(360, 500);
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _size = widget.initialSize;
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

    _scrollToBottom();

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

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Colors.indigo;
    final secondaryColor = widget.secondaryColor ?? Colors.purple;

    if (!_isOpen) {
      // Floating button
      return Positioned(
        left: _position.dx,
        top: _position.dy,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isOpen = true;
              _isMinimized = false;
            });
          },
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(30),
            color: primaryColor,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.chat, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
    }

    // Chat window
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    // When keyboard is open, adjust position and size to keep input visible
    double adjustedY = _position.dy;
    double adjustedHeight = _size.height;

    if (keyboardHeight > 0) {
      // Calculate available space above keyboard
      final availableHeight = screenSize.height -
          keyboardHeight -
          safeAreaTop -
          safeAreaBottom -
          20;

      // Move chatbox up if it would be covered by keyboard
      final maxY = availableHeight - _size.height;
      if (_position.dy > maxY) {
        adjustedY = maxY.clamp(safeAreaTop, screenSize.height - _size.height);
      }

      // Adjust height to fit above keyboard, but keep it reasonable
      adjustedHeight = _size.height.clamp(350.0, availableHeight);
    }

    // Constrain position to screen bounds
    final constrainedX =
        _position.dx.clamp(0.0, screenSize.width - _size.width);
    final constrainedY = adjustedY.clamp(
        safeAreaTop, screenSize.height - adjustedHeight - keyboardHeight);

    return Positioned(
      left: constrainedX,
      top: constrainedY,
      child: Material(
        elevation: 24,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withOpacity(0.3),
        child: Container(
          width: _size.width,
          height: _isMinimized ? 60 : adjustedHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _isMinimized
              ? _buildMinimizedHeader(primaryColor, secondaryColor)
              : Column(
                  children: [
                    _buildHeader(primaryColor, secondaryColor),
                    Expanded(
                      child: _buildMessagesList(),
                    ),
                    _buildInputArea(primaryColor, keyboardHeight),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, Color secondaryColor) {
    return GestureDetector(
      onPanUpdate: widget.isDraggable
          ? (details) {
              setState(() {
                _position += details.delta;
              });
            }
          : null,
      child: Container(
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
            if (widget.isResizable)
              IconButton(
                icon:
                    const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    if (_size.width < 400) {
                      _size = const Size(500, 600);
                    } else {
                      _size = const Size(360, 500);
                    }
                  });
                },
                tooltip: 'Resize',
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
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _isOpen = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedHeader(Color primaryColor, Color secondaryColor) {
    return GestureDetector(
      onPanUpdate: widget.isDraggable
          ? (details) {
              setState(() {
                _position += details.delta;
              });
            }
          : null,
      child: Container(
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
              icon: const Icon(Icons.expand_less, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isMinimized = false;
                });
              },
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
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
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
                  radius: 16,
                  backgroundColor: Colors.indigo[100],
                  child: const Icon(Icons.smart_toy,
                      color: Colors.indigo, size: 18),
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
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.person, color: Colors.blue, size: 18),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea(Color primaryColor, double keyboardHeight) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: keyboardHeight > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
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
                color: Colors.black87, // Ensure text is visible
              ),
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                hintStyle: TextStyle(color: Colors.grey[600]),
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
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) {
                _scrollToBottom();
                // Ensure input stays visible when typing
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_focusNode.hasFocus && _scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: primaryColor,
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
