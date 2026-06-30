// lib/widgets/ai_scribe_soap_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_chat_service.dart';
import '../services/speech_to_text_service.dart';

/// Callback when SOAP note was generated and parsed. Keys: symptoms, diagnosis, treatment, notes.
typedef OnSoapGenerated = void Function(Map<String, dynamic> soap);

/// AI Medical Scribe widget (Pr. Prodoc): voice or text input + "Generate SOAP" to fill symptoms, diagnosis, treatment, notes.
class AiScribeSoapWidget extends StatefulWidget {
  final AiChatService aiChatService;
  final OnSoapGenerated onSoapGenerated;
  /// Optional locale for speech recognition (e.g. 'fr_FR', 'en_US'). Defaults to 'fr_FR'.
  final String? speechLocaleId;

  const AiScribeSoapWidget({
    super.key,
    required this.aiChatService,
    required this.onSoapGenerated,
    this.speechLocaleId,
  });

  @override
  State<AiScribeSoapWidget> createState() => _AiScribeSoapWidgetState();
}

class _AiScribeSoapWidgetState extends State<AiScribeSoapWidget> {
  final _inputController = TextEditingController();
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isLoading = false;
  bool _isListening = false;
  String? _error;
  String? _voiceBaseText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speechService.initialize(context);
    });
  }

  @override
  void dispose() {
    if (_isListening) {
      _speechService.stopListening();
    }
    _inputController.dispose();
    super.dispose();
  }

  void _toggleVoiceInput() async {
    if (_isListening) {
      await _speechService.stopListening(onDone: () {
        if (mounted) setState(() {
          _isListening = false;
          _voiceBaseText = null;
        });
      });
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnaissance vocale indisponible. Vérifiez les permissions du microphone.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _voiceBaseText = _inputController.text.trim();
    HapticFeedback.mediumImpact();

    setState(() => _isListening = true);

    await _speechService.startListening(
      context: context,
      localeId: widget.speechLocaleId ?? 'fr_FR',
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          final base = _voiceBaseText ?? '';
          _inputController.text = base.isEmpty ? text.trim() : '$base ${text.trim()}';
        });
      },
      onError: () {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur de reconnaissance vocale. Vérifiez le micro.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onDone: () {
        if (mounted) setState(() {
          _isListening = false;
          _voiceBaseText = null;
        });
      },
      onListeningStateChanged: (listening) {
        if (!mounted) return;
        // Only setState when value actually changes to avoid rebuild storm and keep Stop button visible.
        if (_isListening != listening && listening) {
          setState(() => _isListening = true);
        }
      },
    );
  }

  Future<void> _generateSoap() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = 'Veuillez saisir ou dicter des informations cliniques.';
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    final result = await widget.aiChatService.extractSoapNote(text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.when(
      success: (data) {
        widget.onSoapGenerated(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Champs remplis par le Pr. Prodoc (SOAP)'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      failure: (message) {
        setState(() => _error = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF18181B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Pr. Prodoc + title
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Icon(Icons.medical_services_rounded, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Medical Scribe',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vous dialoguez avec le Pr. Prodoc pour structurer vos notes en format SOAP.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Label (changes when listening)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _inputController,
              builder: (_, value, __) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isListening ? 'Le Pr. Prodoc vous écoute…' : 'Parlez ou écrivez au Pr. Prodoc',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isListening ? Colors.red : (isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                    if (value.text.isNotEmpty && !_isListening)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Modifiable',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: primaryColor),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              maxLines: 5,
              minLines: 3,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Décrivez les symptômes ou la consultation… Le Pr. Prodoc structurera en SOAP (Subjective, Objectif, Assessment, Plan).',
                hintMaxLines: 3,
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isListening ? Colors.red.withOpacity(0.5) : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _isListening ? Colors.red : primaryColor, width: 2),
                ),
                errorText: _error,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    tooltip: _isListening ? 'Arrêter l\'écoute' : 'Parler (reconnaissance vocale)',
                    icon: _isListening
                        ? const Icon(Icons.stop_rounded, color: Colors.red, size: 28)
                        : Icon(Icons.mic_rounded, color: isDark ? Colors.white70 : Colors.grey.shade600, size: 26),
                    onPressed: _isLoading ? null : _toggleVoiceInput,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateSoap,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'Génération…' : 'Générer la note SOAP'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
