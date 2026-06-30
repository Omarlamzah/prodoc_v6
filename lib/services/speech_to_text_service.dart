// lib/services/speech_to_text_service.dart
import 'package:flutter/material.dart';
import 'package:manual_speech_to_text/manual_speech_to_text.dart';

/// Service class to handle speech-to-text functionality with continuous listening
/// Uses manual_speech_to_text package for better control and continuous listening
class SpeechToTextService {
  static final SpeechToTextService _instance = SpeechToTextService._internal();
  factory SpeechToTextService() => _instance;
  SpeechToTextService._internal();

  ManualSttController? _controller;
  BuildContext? _context;
  bool _isListening = false;
  bool _shouldContinueListening =
      false; // Flag to track if we should auto-resume
  Function()? _currentOnDone;
  Function(String text, bool isFinal)? _currentOnResult;
  Function(bool isListening)? _currentOnListeningStateChanged;

  /// Initialize the service with context (required for ManualSttController)
  void initialize(BuildContext context) {
    // Don't recreate controller if it already exists and context is valid
    if (_controller != null) {
      return;
    }

    _context = context;
    try {
      _controller = ManualSttController(context);
      _setupController();
      debugPrint('Manual STT controller initialized');
    } catch (e) {
      debugPrint('Error initializing Manual STT controller: $e');
      _controller = null;
    }
  }

  /// Set up the controller with listeners
  void _setupController() {
    if (_controller == null) return;

    _controller!.listen(
      onListeningStateChanged: (ManualSttState state) {
        bool wasListening = _isListening;
        _isListening = state == ManualSttState.listening;
        // Only log when state actually changes to avoid terminal spam (plugin may fire repeatedly)
        if (wasListening != _isListening) {
          debugPrint('Manual STT state changed: ${state.name}');
        }

        // Auto-resume if paused but we should continue listening
        if (state == ManualSttState.paused &&
            _shouldContinueListening &&
            _controller != null) {
          debugPrint('Auto-resuming after pause...');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_shouldContinueListening && _controller != null && mounted) {
              try {
                _controller!.resumeStt();
              } catch (e) {
                debugPrint('Error auto-resuming: $e');
              }
            }
          });
        }

        // Notify UI of state change only when it actually changed
        if (wasListening != _isListening) {
          _currentOnListeningStateChanged?.call(_isListening);
        }

        // If stopped, clear the continue flag
        if (state == ManualSttState.stopped) {
          _shouldContinueListening = false; // Clear flag when stopped
        }
      },
      onListeningTextChanged: (String text) {
        // Log only when we have meaningful text to avoid spam
        if (text.trim().isNotEmpty) {
          debugPrint('Manual STT text changed: ${text.length} chars');
        }
        if (_currentOnResult != null) {
          // Manual STT provides accumulated text, so use it directly
          _currentOnResult!(
              text, false); // Always treat as partial for real-time updates
        }
      },
      onSoundLevelChanged: (double level) {
        // Optional: can be used for visual feedback
      },
    );

    // Configure for continuous listening
    // Set to true to clear text when starting new session (prevents mixing text from different fields)
    _controller!.clearTextOnStart = true; // Clear text on restart to prevent mixing sessions
    // Remove auto-pause - allow continuous listening without pausing on silence
    // Note: Setting to null disables auto-pause, but package may still pause
    // We'll handle resuming automatically when paused
  }

  /// Check if speech recognition is available
  bool get isAvailable => _controller != null && _context != null;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Start listening for speech input with continuous listening
  Future<void> startListening({
    required BuildContext context,
    required Function(String text, bool isFinal) onResult,
    Function()? onError,
    Function()? onDone,
    Function(bool isListening)? onListeningStateChanged,
    String? localeId,
  }) async {
    // IMPORTANT: Stop any existing listening first
    if (_isListening || _shouldContinueListening) {
      debugPrint(
          'Stopping existing speech recognition before starting new one...');
      _shouldContinueListening = false;
      if (_controller != null) {
        try {
          _controller!.stopStt();
          // Wait a bit for it to fully stop
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('Error stopping existing recognition: $e');
        }
      }
    }

    // Always reinitialize with current context to ensure it's valid
    initialize(context);

    if (_controller == null) {
      debugPrint('Manual STT controller is null, cannot start');
      onError?.call();
      return;
    }

    // Store callbacks
    _currentOnResult = onResult;
    _currentOnDone = onDone;
    _currentOnListeningStateChanged = onListeningStateChanged;
    _shouldContinueListening = true; // Enable continuous listening mode

    // Set locale if provided
    if (localeId != null) {
      _controller!.localId = localeId;
    }

    try {
      _controller!.startStt();
      debugPrint('Manual STT started successfully');
    } catch (e) {
      debugPrint('Error starting manual STT: $e');
      _shouldContinueListening = false;
      _isListening = false;
      onError?.call();
    }
  }

  /// Stop listening (user-initiated stop)
  Future<void> stopListening({Function()? onDone}) async {
    debugPrint('Stopping speech recognition...');
    _shouldContinueListening = false; // Disable continuous listening FIRST

    // Store callback before clearing it
    final onStateChanged = _currentOnListeningStateChanged;
    final onDoneCallback = _currentOnDone;

    if (_controller != null) {
      try {
        _controller!.stopStt();
        debugPrint('Manual STT stopped successfully');
        // Ensure state is updated
        _isListening = false;
      } catch (e) {
        debugPrint('Error stopping manual STT: $e');
      }
    }

    // Notify UI that listening has stopped BEFORE clearing callbacks
    onStateChanged?.call(false);

    // Clear callbacks AFTER stopping and notifying
    _currentOnDone = null;
    _currentOnResult = null;
    _currentOnListeningStateChanged = null;

    // Call the onDone callback if provided
    onDoneCallback?.call();
    onDone?.call();
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    _shouldContinueListening = false; // Disable continuous listening

    if (_controller != null) {
      try {
        _controller!.stopStt();
      } catch (e) {
        debugPrint('Error canceling manual STT: $e');
      }
    }

    _currentOnDone = null;
    _currentOnResult = null;
    _currentOnListeningStateChanged = null;
  }

  /// Pause listening (for manual control)
  Future<void> pauseListening() async {
    if (_controller != null && _isListening) {
      try {
        _controller!.pauseStt();
      } catch (e) {
        debugPrint('Error pausing manual STT: $e');
      }
    }
  }

  /// Resume listening (for manual control)
  Future<void> resumeListening() async {
    if (_controller != null && !_isListening) {
      try {
        _controller!.resumeStt();
      } catch (e) {
        debugPrint('Error resuming manual STT: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _shouldContinueListening = false;

    if (_controller != null) {
      try {
        _controller!.stopStt();
        _controller!.dispose();
      } catch (e) {
        debugPrint('Error disposing manual STT: $e');
      }
      _controller = null;
    }
    _context = null;
    _isListening = false;
    _currentOnDone = null;
    _currentOnResult = null;
    _currentOnListeningStateChanged = null;
  }

  /// Helper to check if context is still mounted (for auto-resume)
  bool get mounted => _context != null;
}
