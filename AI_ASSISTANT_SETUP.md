# AI Assistant Setup Guide

This guide explains how to set up and use the comprehensive AI Assistant widget in your Flutter app, similar to the Next.js version.

## Features

✅ Multiple AI Helpers with different models and specialties  
✅ Speech-to-Text (voice input)  
✅ Text-to-Speech (voice output)  
✅ Markdown rendering for messages  
✅ Suggested questions with categories  
✅ Helper selection UI  
✅ Beautiful animations and entrance effects  
✅ Minimize/maximize functionality  
✅ Role-based question filtering  

## Installation

1. **Add dependencies** (already added to `pubspec.yaml`):
   ```yaml
   flutter_tts: ^4.1.0
   flutter_markdown: ^0.6.18
   ```

2. **Run**:
   ```bash
   flutter pub get
   ```

## Usage

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'widgets/ai_assistant_comprehensive.dart';
import 'services/ai_chat_service.dart';
import 'data/models/user_model.dart';

class MyScreen extends StatelessWidget {
  final AiChatService aiChatService;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your main content
          YourMainContent(),
          
          // AI Assistant (positioned in bottom right)
          AiAssistantComprehensive(
            aiChatService: aiChatService,
            user: user,
          ),
        ],
      ),
    );
  }
}
```

### With Riverpod Provider

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/ai_assistant_comprehensive.dart';
import 'providers/api_providers.dart';
import 'providers/auth_providers.dart';

class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);
    final user = ref.watch(authProvider)?.user;
    
    return Scaffold(
      body: Stack(
        children: [
          YourMainContent(),
          
          AiAssistantComprehensive(
            aiChatService: aiChatService,
            user: user,
          ),
        ],
      ),
    );
  }
}
```

## AI Helpers

The widget includes 6 AI helpers (matching Next.js version):

1. **Fatima** - `gpt-4o-mini` - Votre secrétaire médicale
2. **Aisha** - `gpt-4` - Assistante administrative
3. **Khadija** - `gpt-4o-mini` - Gestionnaire de rendez-vous
4. **Zaynab** - `gpt-3.5-turbo` - Assistante réceptionniste
5. **Amina** - `gpt-4` - Conseillère médicale
6. **Pr. Laurent** - `gpt-4o` - Spécialiste médical (medical specialty)

## Features Explained

### Speech-to-Text
- Tap the microphone button to start voice input
- Tap again to stop
- Double-tap to stop and auto-send

### Text-to-Speech
- Toggle the volume button in the header to enable/disable auto-reading
- Tap the speaker icon on any message to read it manually

### Helper Selection
- Click the people icon in the header to select a different AI helper
- Each helper has different capabilities and models

### Suggested Questions
- Questions are filtered based on user role (patient vs staff)
- Categories include:
  - Réceptionniste / Secrétaire
  - Gestion des Rendez-vous
  - Gestion des Patients
  - Facturation & Paiements
  - Medical
  - Statistiques & Données
  - Pour les Patients

## Customization

### AI Helper Images

Update the image paths in `ai_assistant_comprehensive.dart`:

```dart
final List<AIHelper> aiHelpers = [
  AIHelper(
    image: 'assets/aihelp/1.jpg', // Your image path
    name: 'Fatima',
    // ...
  ),
  // ...
];
```

Make sure to add the images to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/aihelp/
```

### Styling

The widget uses Material Design 3 with gradient colors. You can customize:

- Colors: Modify gradient colors in `_buildHeader()` and button
- Size: Adjust `width` and `height` in `build()` method
- Position: Change `bottom` and `right` values in `Positioned` widget

## API Integration

The widget uses the existing `AiChatService` which calls:
- Endpoint: `/api/ai/chat`
- Method: POST
- Body: `{ prompt, model, ai_helper }`

The service has been updated to support the `ai_helper` parameter.

## Permissions

### Android
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS
Add to `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice input</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>We need speech recognition for voice input</string>
```

## Troubleshooting

### Speech-to-Text not working
- Check microphone permissions
- Ensure `manual_speech_to_text` package is properly configured
- Verify device has microphone access

### Text-to-Speech not working
- Check device language settings
- Ensure `flutter_tts` package is installed
- Some devices may not support all languages

### Images not showing
- Verify image paths in `aiHelpers` list
- Check `pubspec.yaml` includes the asset paths
- Run `flutter pub get` and rebuild

## Next Steps

1. Add your AI helper images to `assets/aihelp/` directory
2. Update image paths in the widget
3. Customize colors and styling to match your app theme
4. Test speech-to-text and text-to-speech on physical devices
5. Adjust suggested questions based on your app's features

## Notes

- The widget is positioned as a `Stack` child, so it appears above other content
- The widget handles its own state and doesn't require external state management
- All animations and transitions are built-in
- The widget is responsive and adapts to screen size
