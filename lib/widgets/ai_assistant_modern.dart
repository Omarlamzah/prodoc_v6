// lib/widgets/ai_assistant_modern.dart
// Modern AI Assistant Widget - Redesigned from scratch with better UI/UX
// Uses modal bottom sheet approach for better mobile experience

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/ai_chat_service.dart';
import '../services/speech_to_text_service.dart';
import '../core/utils/result.dart';
import '../data/models/user_model.dart';

// AI Helper model
class AIHelper {
  final String image;
  final String name;
  final String model;
  final String specialty;
  final String description;

  AIHelper({
    required this.image,
    required this.name,
    required this.model,
    required this.specialty,
    required this.description,
  });
}

// AI Helpers list
final List<AIHelper> aiHelpers = [
  AIHelper(
    image: 'https://prodoc.ma/aihelp/1.jpg',
    name: 'Fatima',
    model: 'gpt-4o-mini',
    specialty: 'general',
    description: 'Votre secrétaire médicale',
  ),
  AIHelper(
    image: 'https://prodoc.ma/aihelp/2.jpg',
    name: 'Aisha',
    model: 'gpt-4',
    specialty: 'general',
    description: 'Assistante administrative',
  ),
  AIHelper(
    image: 'https://prodoc.ma/aihelp/3.jpg',
    name: 'Khadija',
    model: 'gpt-4o-mini',
    specialty: 'general',
    description: 'Gestionnaire de rendez-vous',
  ),
  AIHelper(
    image: 'https://prodoc.ma/aihelp/4.jpg',
    name: 'Zaynab',
    model: 'gpt-3.5-turbo',
    specialty: 'general',
    description: 'Assistante réceptionniste',
  ),
  AIHelper(
    image: 'https://prodoc.ma/aihelp/5.jpg',
    name: 'Amina',
    model: 'gpt-4',
    specialty: 'general',
    description: 'Conseillère médicale',
  ),
  AIHelper(
    image: 'https://prodoc.ma/aihelp/profisseurai.png',
    name: 'Pr. Laurent',
    model: 'gpt-4o',
    specialty: 'medical',
    description: 'Spécialiste médical',
  ),
];

// Chat Message model
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

// Get welcome message
String getWelcomeMessage(AIHelper helper) {
  if (helper.specialty == 'medical') {
    return '''👋 Bonjour! Je suis **${helper.name}**, votre assistant IA spécialisé en questions médicales.

🏥 **Spécialisé en médecine**, je peux vous aider avec:
• **Questions médicales approfondies** et diagnostics
• **Symptômes et conditions médicales**
• **Médicaments et posologies**
• **Interprétation de résultats médicaux**
• **Conseils médicaux professionnels**

💡 J'utilise le modèle **${helper.model}** pour une précision maximale.

Comment puis-je vous aider aujourd'hui? 😊''';
  }
  return '''👋 Bonjour! Je suis **${helper.name}**, votre assistant Secrétaire Médical IA.

Je peux vous aider avec:
• **Informations sur les patients** et leurs rendez-vous
• **Statistiques** de votre cabinet
• **Questions médicales** générales
• **Utilisation du système** et ses fonctionnalités

Comment puis-je vous aider aujourd'hui? 😊''';
}

AIHelper getRandomAIHelper() {
  return aiHelpers[Random().nextInt(aiHelpers.length)];
}

/// Modern AI Assistant Widget - Floating Button + Modal
class AiAssistantModern extends StatefulWidget {
  final AiChatService aiChatService;
  final UserModel? user;

  const AiAssistantModern({
    super.key,
    required this.aiChatService,
    this.user,
  });

  @override
  State<AiAssistantModern> createState() => _AiAssistantModernState();
}

class _AiAssistantModernState extends State<AiAssistantModern>
    with SingleTickerProviderStateMixin {
  late AIHelper _selectedAIHelper;
  bool _hasSelectedHelper = false;
  bool _isTextToSpeechEnabled = false;
  bool _isSpeaking = false;
  int? _speakingMessageIndex;

  final FlutterTts _flutterTts = FlutterTts();

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedAIHelper = getRandomAIHelper();

    _buttonAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _initTTS();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.9);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _speakingMessageIndex = null;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
        _speakingMessageIndex = null;
      });
    });
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    _flutterTts.stop();
    super.dispose();
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

  Future<void> _speakText(String text,
      {int? messageIndex, bool forcePlay = false}) async {
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

  void _openChat() {
    if (!_hasSelectedHelper) {
      _showHelperSelectionDialog();
    } else {
      _showChatModal();
    }
  }

  void _showHelperSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _HelperSelectionDialog(
        selectedHelper: _selectedAIHelper,
        onHelperSelected: (helper) {
          setState(() {
            _selectedAIHelper = helper;
            _hasSelectedHelper = true;
          });
          Navigator.of(context).pop();
          _showChatModal();
        },
        onSkip: () {
          setState(() {
            _hasSelectedHelper = true;
          });
          Navigator.of(context).pop();
          _showChatModal();
        },
      ),
    );
  }

  void _showChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => _ChatModalContent(
        aiChatService: widget.aiChatService,
        user: widget.user,
        selectedHelper: _selectedAIHelper,
        isTextToSpeechEnabled: _isTextToSpeechEnabled,
        isSpeaking: _isSpeaking,
        speakingMessageIndex: _speakingMessageIndex,
        onToggleTextToSpeech: () {
          setState(() {
            if (_isSpeaking) {
              _stopSpeaking();
            }
            _isTextToSpeechEnabled = !_isTextToSpeechEnabled;
          });
        },
        onSpeakMessage: (text, index) =>
            _speakText(text, messageIndex: index, forcePlay: true),
        onStopSpeaking: _stopSpeaking,
        onHelperChanged: (helper) {
          setState(() {
            _selectedAIHelper = helper;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      child: AnimatedBuilder(
        animation: _buttonScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonScaleAnimation.value,
            child: Material(
              elevation: 8,
              shape: const CircleBorder(),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF667eea),
                      Color(0xFF764ba2),
                      Color(0xFFf093fb)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _openChat,
                  borderRadius: BorderRadius.circular(32),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _selectedAIHelper.image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.chat,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Helper Selection Dialog
class _HelperSelectionDialog extends StatelessWidget {
  final AIHelper selectedHelper;
  final Function(AIHelper) onHelperSelected;
  final VoidCallback onSkip;

  const _HelperSelectionDialog({
    required this.selectedHelper,
    required this.onHelperSelected,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Choisissez votre assistant',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sélectionnez un assistant pour commencer la conversation. Chaque assistant a sa propre spécialité.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: aiHelpers.map((helper) {
                    final isSelected = selectedHelper.name == helper.name;
                    return GestureDetector(
                      onTap: () => onHelperSelected(helper),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.purple.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected ? Colors.purple : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: helper.image,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.person, size: 40),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.purple,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
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
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (helper.specialty == 'medical')
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Text('🏥',
                                        style: TextStyle(fontSize: 14)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              helper.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Utiliser celui par défaut'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Chat Modal Content
class _ChatModalContent extends StatefulWidget {
  final AiChatService aiChatService;
  final UserModel? user;
  final AIHelper selectedHelper;
  final bool isTextToSpeechEnabled;
  final bool isSpeaking;
  final int? speakingMessageIndex;
  final VoidCallback onToggleTextToSpeech;
  final Function(String, int) onSpeakMessage;
  final VoidCallback onStopSpeaking;
  final Function(AIHelper) onHelperChanged;

  const _ChatModalContent({
    required this.aiChatService,
    required this.user,
    required this.selectedHelper,
    required this.isTextToSpeechEnabled,
    required this.isSpeaking,
    required this.speakingMessageIndex,
    required this.onToggleTextToSpeech,
    required this.onSpeakMessage,
    required this.onStopSpeaking,
    required this.onHelperChanged,
  });

  @override
  State<_ChatModalContent> createState() => _ChatModalContentState();
}

class _ChatModalContentState extends State<_ChatModalContent> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _showHelperSelector = false;

  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isListening = false;
  String _inputBaseText = '';

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      role: 'assistant',
      content: getWelcomeMessage(widget.selectedHelper),
      timestamp: DateTime.now(),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _speechService.initialize(context);
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

  Future<void> _sendMessage([String? messageText]) async {
    final textToSend = messageText ?? _textController.text.trim();
    if (textToSend.isEmpty || _isLoading) return;

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
      final result = await widget.aiChatService.sendMessage(
        textToSend,
        model: widget.selectedHelper.model,
        aiHelper: widget.selectedHelper.name,
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

          if (widget.isTextToSpeechEnabled) {
            Future.delayed(const Duration(milliseconds: 500), () {
              widget.onSpeakMessage(response, _messages.length - 1);
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
        content: getWelcomeMessage(widget.selectedHelper),
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
            final newValue =
                (_inputBaseText.isEmpty ? "" : "$_inputBaseText ") + text;
            _textController.text = newValue.trim();
          });
        }
      },
      onError: () {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
      onListeningStateChanged: (isListening) {
        if (mounted) {
          setState(() => _isListening = isListening);
        }
      },
    );
  }

  void _handleStopSpeech({bool autoSend = false}) {
    _speechService.stopListening(onDone: () {
      if (mounted) {
        setState(() => _isListening = false);
        if (autoSend && _textController.text.trim().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _sendMessage();
          });
        }
      }
    });
    _inputBaseText = '';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight - MediaQuery.of(context).padding.top - 50;

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
          // Handle bar
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
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                  Color(0xFFf093fb)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.selectedHelper.image,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.white.withOpacity(0.2),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assistant IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.selectedHelper.name,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.people, color: Colors.white),
                  onPressed: () {
                    setState(() => _showHelperSelector = !_showHelperSelector);
                  },
                ),
                IconButton(
                  icon: Icon(
                    widget.isTextToSpeechEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    color: Colors.white,
                  ),
                  onPressed: widget.onToggleTextToSpeech,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: _clearChat,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Helper selector dropdown
          if (_showHelperSelector)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choisir un assistant',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: aiHelpers.length,
                      itemBuilder: (context, index) {
                        final helper = aiHelpers[index];
                        final isSelected =
                            widget.selectedHelper.name == helper.name;
                        return GestureDetector(
                          onTap: () {
                            widget.onHelperChanged(helper);
                            setState(() {
                              _showHelperSelector = false;
                              _messages.clear();
                              _messages.add(ChatMessage(
                                role: 'assistant',
                                content: getWelcomeMessage(helper),
                                timestamp: DateTime.now(),
                              ));
                            });
                          },
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: helper.image,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.person),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: Colors.purple,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  helper.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Messages area
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final message = _messages[index];
                  return _buildMessageBubble(message, index);
                },
              ),
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: keyboardHeight > 0
                  ? 8
                  : MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
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
                        hintText: _isListening
                            ? "🎤 En écoute..."
                            : "Posez votre question...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: _isListening
                                ? Colors.red.shade400
                                : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: _isListening
                                ? Colors.red.shade400
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: _isListening
                                ? Colors.red.shade500
                                : Colors.purple.shade400,
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
                        if (_isListening) {
                          _handleStopSpeech(autoSend: true);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.red.shade50
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isListening
                                ? Colors.red.shade200
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: _isListening
                              ? Colors.red.shade600
                              : Colors.grey.shade600,
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
                              colors: [
                                Colors.grey.shade300,
                                Colors.grey.shade400
                              ],
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.selectedHelper.image,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                            widget.isSpeaking &&
                                    widget.speakingMessageIndex == index
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            if (widget.isSpeaking &&
                                widget.speakingMessageIndex == index) {
                              widget.onStopSpeaking();
                            } else {
                              widget.onSpeakMessage(message.content, index);
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
