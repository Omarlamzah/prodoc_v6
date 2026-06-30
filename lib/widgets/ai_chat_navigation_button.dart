// lib/widgets/ai_chat_navigation_button.dart
// Simple button that navigates to AI Chat screen

import 'package:flutter/material.dart';
import '../screens/ai_chat_screen.dart';

/// Simple button that navigates to AI Chat screen
/// Can be used as FloatingActionButton or positioned button
class AiChatNavigationButton extends StatelessWidget {
  final Color? buttonColor;
  final IconData icon;
  final String tooltip;
  final bool useMaterialButton; // If false, uses custom Material button

  const AiChatNavigationButton({
    super.key,
    this.buttonColor,
    this.icon = Icons.chat,
    this.tooltip = 'Assistant IA',
    this.useMaterialButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = buttonColor ?? Colors.indigo;

    if (useMaterialButton) {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AiChatScreen(),
            ),
          );
        },
        backgroundColor: color,
        tooltip: tooltip,
        child: Icon(icon, color: Colors.white),
      );
    }

    // Custom positioned button (for bottom-left placement)
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(30),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AiChatScreen(),
            ),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
