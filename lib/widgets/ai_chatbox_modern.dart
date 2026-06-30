// lib/widgets/ai_chatbox_modern.dart
// Modern AI Chatbox with beautiful UI/UX matching React component
// Features: Gradient design, glass morphism, animations, suggested questions

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

/// Modern AI Chatbox Widget with beautiful UI/UX
/// Matches the design of the React Next.js AI Assistant component
class AiChatboxModern extends StatefulWidget {
  final AiChatService? aiChatService;
  final String? welcomeMessage;
  final List<QuestionCategory>? suggestedQuestions;

  const AiChatboxModern({
    super.key,
    this.aiChatService,
    this.welcomeMessage,
    this.suggestedQuestions,
  });

  @override
  State<AiChatboxModern> createState() => _AiChatboxModernState();
}

class _AiChatboxModernState extends State<AiChatboxModern>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  bool _isMinimized = false;
  bool _isLoading = false;
  bool _showSuggestions = true;
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _floatController;
  late AnimationController _pulseController;

  // Gradient colors matching React component
  static const List<Color> _gradientColors = [
    Color(0xFF667eea), // Purple
    Color(0xFF764ba2), // Dark purple
    Color(0xFFf093fb), // Pink
  ];

  @override
  void initState() {
    super.initState();

    // Animation controllers
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Add welcome message
    _messages.add(ChatMessage(
      role: 'assistant',
      content: widget.welcomeMessage ??
          '👋 Bonjour! Je suis **Nextpital AI**, votre assistant intelligent pour la gestion de votre cabinet médical.\n\nJe peux vous aider avec:\n• **Informations sur les patients** et leurs rendez-vous\n• **Statistiques** de votre cabinet\n• **Questions médicales** générales\n• **Utilisation du système** et ses fonctionnalités\n\nComment puis-je vous aider aujourd\'hui? 😊',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _floatController.dispose();
    _pulseController.dispose();
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

  Future<void> _sendMessage(String? messageText) async {
    final textToSend = messageText ?? _textController.text.trim();
    if (textToSend.isEmpty || _isLoading || widget.aiChatService == null) {
      return;
    }

    setState(() {
      _showSuggestions = false;
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
    Future.delayed(const Duration(milliseconds: 100), () {
      _sendMessage(question);
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: widget.welcomeMessage ??
            '👋 Bonjour! Je suis **Nextpital AI**, votre assistant intelligent pour la gestion de votre cabinet médical.\n\nJe peux vous aider avec:\n• **Informations sur les patients** et leurs rendez-vous\n• **Statistiques** de votre cabinet\n• **Questions médicales** générales\n• **Utilisation du système** et ses fonctionnalités\n\nComment puis-je vous aider aujourd\'hui? 😊',
        timestamp: DateTime.now(),
      ));
      _showSuggestions = true;
    });
  }

  String _renderMarkdown(String text) {
    // Simple markdown to HTML conversion
    String html = text;

    // Bold: **text**
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );

    // Bullet points: - or *
    html = html.replaceAllMapped(
      RegExp(r'^[-*]\s+(.+)$', multiLine: true),
      (match) => '<li>${match.group(1)}</li>',
    );

    // Wrap consecutive <li> in <ul>
    html = html.replaceAllMapped(
      RegExp(r'(<li>.*?</li>(?:\n<li>.*?</li>)*)', dotAll: true),
      (match) => '<ul>${match.group(0)}</ul>',
    );

    // Line breaks
    html = html.replaceAll('\n', '<br />');

    return html;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return _buildFloatingButton();
    }

    return _buildChatWindow();
  }

  Widget _buildFloatingButton() {
    return Positioned(
      bottom: 32,
      right: 32,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isOpen = true;
            _isMinimized = false;
          });
        },
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatController.value * -10),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _gradientColors[0].withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: _gradientColors[0].withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Shimmer effect
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment(-1.0, 0),
                            end: Alignment(1.0, 0),
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Icon
                    Center(
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    // Active indicator
                    Positioned(
                      top: -2,
                      right: -2,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.shade500,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade500.withOpacity(
                                    0.5 + _pulseController.value * 0.3,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatWindow() {
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = screenSize.height * 0.85;
    final maxWidth = 680.0;

    return Positioned(
      bottom: 32,
      right: 32,
      child: Container(
        width: maxWidth.clamp(300.0, screenSize.width - 64),
        height: _isMinimized
            ? 80
            : (maxHeight - keyboardHeight).clamp(400.0, maxHeight),
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(300.0, screenSize.width - 64),
          maxHeight: maxHeight,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: _isMinimized ? _buildMinimizedHeader() : _buildFullChat(),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Nextpital AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full, color: Colors.white),
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
    );
  }

  Widget _buildFullChat() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade50,
                  Colors.white,
                  Colors.purple.shade50.withOpacity(0.3),
                ],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _buildMessagesList(),
                ),
                if (_showSuggestions && _messages.length <= 1)
                  _buildSuggestedQuestions(),
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Nextpital AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your intelligent medical assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clearChat,
            tooltip: 'Nouvelle conversation',
          ),
          IconButton(
            icon: Icon(
              _isMinimized ? Icons.open_in_full : Icons.minimize,
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
              setState(() {
                _isOpen = false;
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
      padding: const EdgeInsets.all(24),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildLoadingIndicator();
        }

        final message = _messages[index];
        return _buildMessageBubble(message)
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.1, end: 0, duration: 300.ms);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade100,
                    Colors.pink.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.purple.shade200.withOpacity(0.5),
                ),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.shade600,
                          Colors.pink.shade600,
                        ],
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isUser
                    ? null
                    : Border.all(
                        color: Colors.grey.shade100,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  else
                    Html(
                      data: _renderMarkdown(message.content),
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(14),
                          color: Colors.grey.shade700,
                          lineHeight: LineHeight(1.5),
                        ),
                        "strong": Style(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                        "ul": Style(
                          margin: Margins.only(left: 16),
                          padding: HtmlPaddings.zero,
                        ),
                        "li": Style(
                          margin: Margins.only(bottom: 4),
                          color: Colors.grey.shade700,
                        ),
                      },
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey.shade400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade600,
                    Colors.pink.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade100,
                  Colors.pink.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.purple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.shade100,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.purple.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingDot(delay: 0),
                    _LoadingDot(delay: 100),
                    _LoadingDot(delay: 200),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final questions = widget.suggestedQuestions ?? _defaultSuggestedQuestions;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50.withOpacity(0.5),
            Colors.white,
            Colors.pink.shade50.withOpacity(0.5),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.orange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Questions Suggérées',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = LinearGradient(
                      colors: [
                        Colors.purple.shade600,
                        Colors.pink.shade600,
                      ],
                    ).createShader(
                      const Rect.fromLTWH(0, 0, 200, 20),
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...questions.take(3).map((category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: category.questions.take(3).map((question) {
                      return InkWell(
                        onTap: () => _handleSuggestedQuestion(question),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            question,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
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
              maxLength: 500,
              textInputAction: TextInputAction.send,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Posez votre question... ✨',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.purple.shade400,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                counterText: '',
              ),
              onSubmitted: (_) => _sendMessage(null),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: _textController.text.trim().isNotEmpty && !_isLoading
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.shade600,
                        Colors.purple.shade800,
                      ],
                    )
                  : null,
              color: _textController.text.trim().isEmpty || _isLoading
                  ? Colors.grey.shade300
                  : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_textController.text.trim().isNotEmpty && !_isLoading)
                      ? Colors.purple.withOpacity(0.3)
                      : Colors.transparent,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _isLoading || _textController.text.trim().isEmpty
                    ? null
                    : () => _sendMessage(null),
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
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

class _LoadingDot extends StatefulWidget {
  final int delay;

  const _LoadingDot({required this.delay});

  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.purple.shade400,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
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

class QuestionCategory {
  final String category;
  final String icon;
  final List<String> questions;

  QuestionCategory({
    required this.category,
    required this.icon,
    required this.questions,
  });
}

final List<QuestionCategory> _defaultSuggestedQuestions = [
  QuestionCategory(
    category: "Réceptionniste / Secrétaire",
    icon: "👨‍💼",
    questions: [
      "Comment enregistrer un nouveau patient dans le système?",
      "Comment créer un rendez-vous pour un patient?",
      "Comment modifier ou annuler un rendez-vous?",
    ],
  ),
  QuestionCategory(
    category: "Gestion des Rendez-vous",
    icon: "📅",
    questions: [
      "Comment prendre un rendez-vous?",
      "Comment voir mes rendez-vous?",
      "Comment annuler un rendez-vous?",
    ],
  ),
  QuestionCategory(
    category: "Gestion des Patients",
    icon: "🏥",
    questions: [
      "Comment rechercher un patient rapidement?",
      "Comment voir les détails d'un patient?",
      "Comment consulter l'historique médical d'un patient?",
    ],
  ),
];
