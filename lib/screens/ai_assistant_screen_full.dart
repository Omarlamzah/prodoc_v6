// lib/screens/ai_assistant_screen_full.dart
// Full-screen AI Assistant: helper selection (2x2 grid) then chat

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/ai_assistant_modern.dart';
import '../services/speech_to_text_service.dart';
import '../core/utils/result.dart';
import '../providers/api_providers.dart';

class AiAssistantScreenFull extends ConsumerStatefulWidget {
  const AiAssistantScreenFull({super.key});

  @override
  ConsumerState<AiAssistantScreenFull> createState() =>
      _AiAssistantScreenFullState();
}

class _AiAssistantScreenFullState extends ConsumerState<AiAssistantScreenFull> {
  bool _showHelperSelection = true;
  late AIHelper _selectedAIHelper;

  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isTextToSpeechEnabled = false;
  bool _isSpeaking = false;
  int? _speakingMessageIndex;

  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isListening = false;
  String _inputBaseText = '';

  @override
  void initState() {
    super.initState();
    _selectedAIHelper = getRandomAIHelper();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speechService.initialize(context);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _flutterTts.stop();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.9);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _speakingMessageIndex = null;
      });
    });
    _flutterTts.setErrorHandler((_) {
      setState(() {
        _isSpeaking = false;
        _speakingMessageIndex = null;
      });
    });
  }

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'[-*]\s+(.+)'), r'$1')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _speakText(String text, {int? messageIndex, bool forcePlay = false}) async {
    if (text.isEmpty || (!_isTextToSpeechEnabled && !forcePlay)) return;
    await _flutterTts.stop();
    final cleanText = _stripMarkdown(text);
    if (cleanText.isEmpty) return;
    setState(() {
      _isSpeaking = true;
      _speakingMessageIndex = messageIndex;
    });
    await _flutterTts.speak(cleanText);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _speakingMessageIndex = null;
    });
  }

  void _onHelperSelected(AIHelper helper) {
    setState(() {
      _selectedAIHelper = helper;
      _showHelperSelection = false;
      _messages.clear();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: getWelcomeMessage(helper),
        timestamp: DateTime.now(),
      ));
    });
    _initTTS();
  }

  void _onUseDefault() {
    setState(() {
      _showHelperSelection = false;
      _messages.clear();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: getWelcomeMessage(_selectedAIHelper),
        timestamp: DateTime.now(),
      ));
    });
    _initTTS();
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

  Future<void> _sendMessage([String? messageText]) async {
    final textToSend = messageText ?? _textController.text.trim();
    if (textToSend.isEmpty || _isLoading) return;

    final aiChatService = ref.read(aiChatServiceProvider);

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

    try {
      final result = await aiChatService.sendMessage(
        textToSend,
        model: _selectedAIHelper.model,
        aiHelper: _selectedAIHelper.name,
      );

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
          if (_isTextToSpeechEnabled) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _speakText(response, messageIndex: _messages.length - 1);
            });
          }
        } else {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Désolé, une erreur s\'est produite. Veuillez réessayer.',
            timestamp: DateTime.now(),
          ));
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Désolé, une erreur s\'est produite. Veuillez réessayer.',
          timestamp: DateTime.now(),
        ));
      });
    }
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: getWelcomeMessage(_selectedAIHelper),
        timestamp: DateTime.now(),
      ));
    });
  }

  void _handleStartSpeech() {
    if (!_speechService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconnaissance vocale indisponible')),
      );
      return;
    }
    setState(() {
      _inputBaseText = _textController.text;
      _isListening = true;
    });
    _speechService.startListening(
      context: context,
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            final newValue = (_inputBaseText.isEmpty ? "" : "$_inputBaseText ") + text;
            _textController.text = newValue.trim();
          });
        }
      },
      onError: () {
        if (mounted) setState(() => _isListening = false);
      },
      onListeningStateChanged: (isListening) {
        if (mounted) setState(() => _isListening = isListening);
      },
    );
  }

  void _handleStopSpeech({bool autoSend = false}) {
    _speechService.stopListening(onDone: () {
      if (mounted) {
        setState(() => _isListening = false);
        if (autoSend && _textController.text.trim().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () => _sendMessage());
        }
      }
    });
    _inputBaseText = '';
  }

  @override
  Widget build(BuildContext context) {
    if (_showHelperSelection) {
      return _buildHelperSelectionScreen();
    }
    return _buildChatScreen();
  }

  Widget _buildHelperSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Choisissez votre assistant'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sélectionnez un assistant pour commencer la conversation. Chaque assistant a sa propre spécialité.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = 2;
                    final spacing = 16.0;
                    final width = (constraints.maxWidth - spacing) / crossAxisCount;
                    final itemHeight = width * 1.15;
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: width / itemHeight,
                      ),
                      itemCount: aiHelpers.length,
                      itemBuilder: (context, index) {
                        final helper = aiHelpers[index];
                        final isSelected = _selectedAIHelper.name == helper.name;
                        return _buildHelperCard(
                          helper: helper,
                          isSelected: isSelected,
                          onTap: () => _onHelperSelected(helper),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: _onUseDefault,
                  child: const Text('Utiliser celui par défaut'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelperCard({
    required AIHelper helper,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? Colors.purple.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: helper.image,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => SizedBox(
                        width: 72,
                        height: 72,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 36),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      helper.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (helper.specialty == 'medical')
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('🏥', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                helper.description,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: _selectedAIHelper.image,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Assistant IA',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _selectedAIHelper.name,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isTextToSpeechEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              if (_isSpeaking) _stopSpeaking();
              setState(() => _isTextToSpeechEnabled = !_isTextToSpeechEnabled);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _buildMessageBubble(_messages[index], index);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: _selectedAIHelper.image,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[200],
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[300],
                  child: const Icon(Icons.smart_toy, color: Colors.purple),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF667eea) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isUser ? null : Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                    MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, height: 1.5),
                        strong: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      if (!isUser)
                        IconButton(
                          icon: Icon(
                            _isSpeaking && _speakingMessageIndex == index
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            if (_isSpeaking && _speakingMessageIndex == index) {
                              _stopSpeaking();
                            } else {
                              _speakText(message.content, messageIndex: index, forcePlay: true);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFFf093fb)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                  hintText: _isListening ? '🎤 En écoute...' : 'Posez votre question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _isListening ? Colors.red.shade400 : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _isListening ? Colors.red.shade400 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _isListening ? Colors.red.shade500 : Colors.purple.shade400,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: _isListening
                      ? Colors.red.shade50.withOpacity(0.5)
                      : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            if (_speechService.isAvailable)
              GestureDetector(
                onTap: () {
                  if (_isListening) {
                    _handleStopSpeech();
                  } else {
                    _handleStartSpeech();
                  }
                },
                onDoubleTap: () {
                  if (_isListening) _handleStopSpeech(autoSend: true);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red.shade50 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening ? Colors.red.shade200 : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: _isListening ? Colors.red.shade600 : Colors.grey.shade600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: (_textController.text.trim().isNotEmpty &&
                        !_isLoading &&
                        !_isListening)
                    ? const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                      ),
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
                onPressed: (_textController.text.trim().isNotEmpty &&
                        !_isLoading &&
                        !_isListening)
                    ? () => _sendMessage()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
