// lib/widgets/ai_chatbox_modern_example.dart
// Example usage of the modern AI chatbox widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_chatbox_modern.dart';
import '../providers/api_providers.dart';

/// Example screen showing how to use the modern AI chatbox
class AiChatboxModernExample extends ConsumerWidget {
  const AiChatboxModernExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chatbox Modern Example'),
      ),
      body: Stack(
        children: [
          // Your main content here
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap the floating button to open AI chat',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // AI Chatbox overlay
          AiChatboxModern(
            aiChatService: aiChatService,
            welcomeMessage:
                '👋 Bonjour! Je suis **Nextpital AI**, votre assistant intelligent.',
            suggestedQuestions: [
              QuestionCategory(
                category: "Réceptionniste / Secrétaire",
                icon: "👨‍💼",
                questions: [
                  "Comment enregistrer un nouveau patient?",
                  "Comment créer un rendez-vous?",
                  "Comment modifier un rendez-vous?",
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
                  "Comment rechercher un patient?",
                  "Comment voir les détails d'un patient?",
                  "Comment consulter l'historique médical?",
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
