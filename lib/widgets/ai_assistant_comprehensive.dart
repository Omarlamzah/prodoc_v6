// lib/widgets/ai_assistant_comprehensive.dart
// Comprehensive AI Assistant Widget similar to Next.js version
// Features: Multiple AI helpers, Speech-to-text, Text-to-speech, Markdown rendering, Suggested questions

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
  final String specialty; // 'general' or 'medical'
  final String description;

  AIHelper({
    required this.image,
    required this.name,
    required this.model,
    required this.specialty,
    required this.description,
  });
}

// AI Helpers list (matching Next.js version)
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

// Suggested Questions Categories
class QuestionCategory {
  final String category;
  final String icon;
  final List<String> questions;
  final Color color;

  QuestionCategory({
    required this.category,
    required this.icon,
    required this.questions,
    required this.color,
  });
}

final List<QuestionCategory> suggestedQuestions = [
  QuestionCategory(
    category: "Réceptionniste / Secrétaire",
    icon: "👨‍💼",
    color: Colors.purple,
    questions: [
      "Comment enregistrer un nouveau patient dans le système?",
      "Comment créer un rendez-vous pour un patient?",
      "Comment modifier ou annuler un rendez-vous?",
      "Comment rechercher un patient par nom ou CNI?",
      "Comment imprimer une facture pour un patient?",
    ],
  ),
  QuestionCategory(
    category: "Gestion des Rendez-vous",
    icon: "📅",
    color: Colors.blue,
    questions: [
      "Comment prendre un rendez-vous?",
      "Comment voir mes rendez-vous?",
      "Comment annuler un rendez-vous?",
      "Quand est mon prochain rendez-vous?",
    ],
  ),
  QuestionCategory(
    category: "Gestion des Patients",
    icon: "🏥",
    color: Colors.teal,
    questions: [
      "Comment rechercher un patient rapidement?",
      "Comment voir les détails d'un patient?",
      "Comment consulter l'historique médical d'un patient?",
      "Comment mettre à jour les informations d'un patient?",
    ],
  ),
  QuestionCategory(
    category: "Facturation & Paiements",
    icon: "💰",
    color: Colors.orange,
    questions: [
      "Comment créer une facture?",
      "Comment enregistrer un paiement?",
      "Comment générer un reçu?",
      "Comment voir les factures impayées?",
    ],
  ),
  QuestionCategory(
    category: "Medical",
    icon: "⚕️",
    color: Colors.pink,
    questions: [
      "Quels sont les symptômes courants de la grippe?",
      "Comment calculer la posologie d'un médicament pour un enfant?",
      "Quelle est la différence entre une infection virale et bactérienne?",
      "Comment interpréter les résultats d'une analyse sanguine?",
    ],
  ),
  QuestionCategory(
    category: "Statistiques & Données",
    icon: "📊",
    color: Colors.indigo,
    questions: [
      "Combien de patients avons-nous aujourd'hui?",
      "Combien de rendez-vous avons-nous aujourd'hui?",
      "Combien de nouveaux patients ce mois?",
      "Quel est le revenu d'aujourd'hui?",
    ],
  ),
  QuestionCategory(
    category: "Pour les Patients",
    icon: "👤",
    color: Colors.blue,
    questions: [
      "Quelles sont mes informations?",
      "Comment prendre un rendez-vous?",
      "Comment voir mes rendez-vous?",
      "Quand est mon prochain rendez-vous?",
    ],
  ),
];

// Chat Message model
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

// Get welcome message based on AI helper
String getWelcomeMessage(AIHelper helper) {
  if (helper.specialty == 'medical') {
    return '''👋 Bonjour! Je suis **${helper.name}**, votre assistant IA spécialisé en questions médicales.

🏥 **Spécialisé en médecine**, je peux vous aider avec:
• **Questions médicales approfondies** et diagnostics
• **Symptômes et conditions médicales**
• **Médicaments et posologies**
• **Interprétation de résultats médicaux**
• **Conseils médicaux professionnels**
• **Terminologie médicale** et procédures cliniques

💡 J'utilise le modèle **${helper.model}** pour une précision maximale dans les réponses médicales.

Comment puis-je vous aider aujourd'hui? 😊''';
  }
  return '''👋 Bonjour! Je suis **${helper.name}**, votre assistant Secrétaire Médical IA pour la gestion de votre cabinet médical.

Je peux vous aider avec:
• **Informations sur les patients** et leurs rendez-vous
• **Statistiques** de votre cabinet
• **Questions médicales** générales
• **Utilisation du système** et ses fonctionnalités

Comment puis-je vous aider aujourd'hui? 😊''';
}

// Get random AI helper
AIHelper getRandomAIHelper() {
  return aiHelpers[Random().nextInt(aiHelpers.length)];
}

// Filter questions based on user role
List<QuestionCategory> getFilteredQuestions(UserModel? user) {
  if (user == null) return suggestedQuestions;

  final isPatient = user.isPatient == 1 &&
      user.isAdmin != 1 &&
      user.isDoctor != 1 &&
      user.isReceptionist != 1;

  if (isPatient) {
    return suggestedQuestions
        .where((cat) =>
            cat.category == "Pour les Patients" ||
            cat.category == "Medical" ||
            cat.category == "System Help" ||
            cat.category == "Gestion des Rendez-vous")
        .toList();
  }

  return suggestedQuestions
      .where((cat) => cat.category != "Pour les Patients")
      .toList();
}

/// Comprehensive AI Assistant Widget
class AiAssistantComprehensive extends StatefulWidget {
  final AiChatService aiChatService;
  final UserModel? user;

  const AiAssistantComprehensive({
    super.key,
    required this.aiChatService,
    this.user,
  });

  @override
  State<AiAssistantComprehensive> createState() =>
      _AiAssistantComprehensiveState();
}

class _AiAssistantComprehensiveState extends State<AiAssistantComprehensive>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  bool _isMinimized = false;
  bool _isLoading = false;
  bool _showSuggestions = true;
  bool _showHelperSelector = false;
  bool _showInitialHelperSelection = false;
  bool _hasSelectedHelper = false;
  bool _isTextToSpeechEnabled = false;
  bool _isSpeaking = false;
  int? _speakingMessageIndex;

  late AIHelper _selectedAIHelper;
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Speech services
  final SpeechToTextService _speechService = SpeechToTextService();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _inputBaseText = '';

  // Animations
  late AnimationController _buttonAnimationController;
  late AnimationController _entranceAnimationController;
  late Animation<double> _buttonScaleAnimation;

  // Image animation state
  bool _showImageAnimation = false;
  bool _showNameText = false;

  @override
  void initState() {
    super.initState();
    _selectedAIHelper = getRandomAIHelper();

    // Initialize welcome message
    _messages.add(ChatMessage(
      role: 'assistant',
      content: getWelcomeMessage(_selectedAIHelper),
      timestamp: DateTime.now(),
    ));

    // Initialize animations
    _buttonAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _entranceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize TTS
    _initTTS();

    // Initialize speech service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _speechService.initialize(context);
      }
    });
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.9);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
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
    _entranceAnimationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _flutterTts.stop();
    _speechService.dispose();
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

  // Strip markdown for TTS
  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'[-*]\s+(.+)'), r'$1') // Bullet points
        .replaceAll('\n', ' ') // New lines to spaces
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .trim();
  }

  // Speak text
  Future<void> _speakText(String text,
      {int? messageIndex, bool forcePlay = false}) async {
    if (!text.isNotEmpty) return;

    if (!_isTextToSpeechEnabled && !forcePlay) return;

    await _flutterTts.stop();

    final cleanText = _stripMarkdown(text);
    if (cleanText.isEmpty) return;

    setState(() {
      _isSpeaking = true;
      _speakingMessageIndex = messageIndex;
    });

    await _flutterTts.speak(cleanText);
  }

  // Stop speaking
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _speakingMessageIndex = null;
    });
  }

  // Toggle text-to-speech
  void _toggleTextToSpeech() {
    if (_isSpeaking) {
      _stopSpeaking();
    }
    setState(() {
      _isTextToSpeechEnabled = !_isTextToSpeechEnabled;
    });
  }

  Future<void> _sendMessage([String? messageText]) async {
    final textToSend = messageText ?? _textController.text.trim();
    if (textToSend.isEmpty || _isLoading) return;

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

    try {
      final result = await widget.aiChatService.sendMessage(
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

          // Auto-speak if enabled
          if (_isTextToSpeechEnabled) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _speakText(response, messageIndex: _messages.length - 1);
            });
          }
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
        content: getWelcomeMessage(_selectedAIHelper),
        timestamp: DateTime.now(),
      ));
      _showSuggestions = true;
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
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur de reconnaissance vocale')),
          );
        }
      },
      onListeningStateChanged: (isListening) {
        if (mounted) {
          setState(() {
            _isListening = isListening;
          });
        }
      },
    );
  }

  void _handleStopSpeech({bool autoSend = false}) {
    _speechService.stopListening(onDone: () {
      if (mounted) {
        setState(() {
          _isListening = false;
        });

        if (autoSend && _textController.text.trim().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _sendMessage();
          });
        }
      }
    });
    _inputBaseText = '';
  }

  void _openChat() {
    setState(() {
      _isOpen = true;
      _isMinimized = false;
      // Only show initial selection if user hasn't selected a helper yet
      if (!_hasSelectedHelper) {
        _showInitialHelperSelection = true;
      }
    });

    _entranceAnimationController.forward();

    // Trigger image animation
    _triggerImageAnimation();
  }

  void _triggerImageAnimation() {
    // Simplified animation - can be enhanced with position tracking
    setState(() {
      _showImageAnimation = true;
    });

    // Stage 2: Grow large
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showNameText = true;
        });
      }
    });

    // Stage 3: Hide text
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() {
          _showNameText = false;
        });
      }
    });

    // Hide animation
    Future.delayed(const Duration(milliseconds: 7500), () {
      if (mounted) {
        setState(() {
          _showImageAnimation = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return Positioned(
        bottom: 32,
        left: 32,
        child: AnimatedBuilder(
          animation: _buttonScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _buttonScaleAnimation.value,
              child: FloatingActionButton(
                onPressed: _openChat,
                backgroundColor: Colors.transparent,
                elevation: 8,
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
                        color: Colors.purple.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _selectedAIHelper.image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.chat, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Stack(
      children: [
        // Image animation overlay
        if (_showImageAnimation)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showNameText ? 0.4 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          ),

        // Main chat widget
        Positioned(
          bottom: 32,
          left: 32,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 680,
            height:
                _isMinimized ? 80 : MediaQuery.of(context).size.height * 0.85,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 64,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _isMinimized
                ? _buildMinimizedHeader()
                : Stack(
                    children: [
                      Column(
                        children: [
                          _buildHeader(),
                          Expanded(
                            child: _buildContent(),
                          ),
                        ],
                      ),
                      // Initial AI Helper Selection Modal
                      if (_showInitialHelperSelection && !_isMinimized)
                        _buildInitialHelperSelectionModal(),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // AI Helper Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _selectedAIHelper.image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Secrétaire Médical IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Pro',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_selectedAIHelper.name} - Votre assistant médical intelligent',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                icon: const Icon(Icons.people, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showHelperSelector = !_showHelperSelector;
                  });
                },
                tooltip: 'Choisir un assistant',
              ),
              IconButton(
                icon: Icon(
                  _isTextToSpeechEnabled ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                ),
                onPressed: _toggleTextToSpeech,
                tooltip: _isTextToSpeechEnabled
                    ? "Désactiver la lecture vocale"
                    : "Activer la lecture vocale",
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _clearChat,
                tooltip: 'Nouvelle conversation',
              ),
              IconButton(
                icon: Icon(
                  _isMinimized ? Icons.expand_less : Icons.expand_more,
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
                  _stopSpeaking();
                  if (_isListening) {
                    _handleStopSpeech();
                  }
                  setState(() {
                    _isOpen = false;
                  });
                },
              ),
            ],
          ),
          // Helper selector dropdown
          if (_showHelperSelector)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Choisir votre assistant',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _showHelperSelector = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: aiHelpers.map((helper) {
                      final isSelected = _selectedAIHelper.name == helper.name;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAIHelper = helper;
                            _showHelperSelector = false;
                            _messages.clear();
                            _messages.add(ChatMessage(
                              role: 'assistant',
                              content: getWelcomeMessage(helper),
                              timestamp: DateTime.now(),
                            ));
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Assistant changé pour ${helper.name}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: helper.image,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
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
                              const SizedBox(height: 4),
                              Text(
                                helper.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                helper.description,
                                style: const TextStyle(
                                  fontSize: 10,
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMinimizedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: _selectedAIHelper.image,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.chat, color: Colors.white),
            ),
          ),
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

  Widget _buildInitialHelperSelectionModal() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Choisissez votre assistant IA',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _showInitialHelperSelection = false;
                              _hasSelectedHelper = true;
                              // Use the already selected helper (random by default)
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sélectionnez un assistant pour commencer la conversation. Chaque assistant a sa propre spécialité.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // AI Helpers Grid
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: aiHelpers.map((helper) {
                        final isSelected =
                            _selectedAIHelper.name == helper.name;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAIHelper = helper;
                              _showInitialHelperSelection = false;
                              _hasSelectedHelper = true;
                              // Update welcome message
                              _messages.clear();
                              _messages.add(ChatMessage(
                                role: 'assistant',
                                content: getWelcomeMessage(helper),
                                timestamp: DateTime.now(),
                              ));
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${helper.name} sélectionnée - ${helper.description}'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.purple,
                              ),
                            );
                          },
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.purple.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.purple
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: helper.image,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
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
                                          child: const Icon(Icons.person,
                                              size: 40),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.purple.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.purple,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      helper.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (helper.specialty == 'medical')
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Text(
                                          '🏥',
                                          style: TextStyle(fontSize: 14),
                                        ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Messages area
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
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final message = _messages[index];
                return _buildMessageBubble(message, index);
              },
            ),
          ),
        ),

        // Suggested questions
        if (_showSuggestions && _messages.length <= 1)
          _buildSuggestedQuestions(),

        // Input area
        _buildInputArea(),
      ],
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade100, Colors.pink.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _selectedAIHelper.image,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.smart_toy, color: Colors.purple),
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
                        listBullet: const TextStyle(color: Colors.purple),
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
                              _speakText(message.content,
                                  messageIndex: index, forcePlay: true);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: _isSpeaking && _speakingMessageIndex == index
                              ? "Arrêter la lecture"
                              : "Lire ce message",
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFFf093fb)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final filteredCategories = getFilteredQuestions(widget.user);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade50.withOpacity(0.5),
            Colors.white,
            Colors.pink.shade50.withOpacity(0.5),
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
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
                    colors: [Colors.amber.shade400, Colors.orange.shade500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.lightbulb, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Questions Suggérées',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...filteredCategories.take(3).map((category) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      category.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          question,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          Row(
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
                        : "Posez votre question... ✨",
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
                    suffixIcon: _isListening
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Enregistrement',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              // Speech button
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
                    width: 60,
                    height: 60,
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
              // Send button
              Container(
                width: 60,
                height: 60,
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt, color: Colors.purple.shade500, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Propulsé par Secrétaire Médical IA',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple.shade500,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.trending_up,
                      color: Colors.grey.shade400, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "S'améliore constamment",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
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
