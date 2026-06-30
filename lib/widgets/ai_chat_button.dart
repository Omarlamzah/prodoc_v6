// lib/widgets/ai_chat_button.dart
// Simple floating button that opens the AI chat modal

import 'package:flutter/material.dart';
import 'ai_chat_modal.dart';
import '../services/ai_chat_service.dart';

/// Simple floating button for AI chat
/// Opens a modal bottom sheet when tapped
class AiChatButton extends StatelessWidget {
  final AiChatService? aiChatService;
  final Color? buttonColor;
  final IconData icon;
  final String tooltip;

  const AiChatButton({
    super.key,
    this.aiChatService,
    this.buttonColor,
    this.icon = Icons.chat,
    this.tooltip = 'Assistant IA',
  });

  @override
  Widget build(BuildContext context) {
    if (aiChatService == null) {
      return const SizedBox.shrink();
    }

    final color = buttonColor ?? Colors.indigo;

    return FloatingActionButton(
      onPressed: () {
        AiChatModal.show(context, aiChatService: aiChatService!);
      },
      backgroundColor: color,
      tooltip: tooltip,
      child: Icon(icon, color: Colors.white),
    );
  }
}
