# Flutter AI Assistant Integration Guide

## Overview

This guide explains how to integrate the AI Assistant (with Text-to-SQL support) into your Flutter app. The AI Assistant is the same backend service used in the Next.js web app, providing consistent functionality across platforms.

## Features

- ✅ **Medical Questions**: Ask about symptoms, medications, medical terminology
- ✅ **System Help**: Get guidance on using HMS features
- ✅ **Text-to-SQL**: Query database with natural language (Admin/Doctor/Receptionist only)
- ✅ **General Healthcare**: Best practices, communication tips
- ✅ **Floating Widget**: Always accessible chat interface
- ✅ **Conversation History**: Maintains chat during session

## Architecture

```
Flutter App
    ↓
AiChatService (lib/services/ai_chat_service.dart)
    ↓
ApiClient (lib/core/network/api_client.dart)
    ↓
Laravel Backend (/api/ai/chat)
    ↓
TextToSqlService (if SQL query detected)
    ↓
OpenAI GPT-4o-mini
    ↓
Response formatted and returned
```

## Installation Steps

### 1. Files Already Created

The following files have been created for you:

- ✅ `lib/services/ai_chat_service.dart` - Service for API calls
- ✅ `lib/widgets/ai_assistant_widget.dart` - UI widget
- ✅ `lib/core/config/api_constants.dart` - Updated with `/ai/chat` endpoint
- ✅ `lib/providers/api_providers.dart` - Updated with `aiChatServiceProvider`

### 2. Verify API Endpoint

The endpoint is already configured in `api_constants.dart`:

```dart
static const String aiChat = '/ai/chat';
```

### 3. Add Widget to Your App

#### Option A: Add to Main Dashboard Screen

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';

class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          // Your existing dashboard content
          YourDashboardContent(),
          
          // AI Assistant Widget (floating)
          AiAssistantWidget(
            aiChatService: aiChatService,
            primaryColor: Colors.indigo,
            secondaryColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}
```

#### Option B: Add to App-Wide Layout

If you have a main layout widget, add it there:

```dart
// In your main layout widget
class MainLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          // Your app content
          YourAppContent(),
          
          // AI Assistant (available on all screens)
          AiAssistantWidget(
            aiChatService: aiChatService,
          ),
        ],
      ),
    );
  }
}
```

### 4. Set Auth Token (Important!)

Make sure the API client has the authentication token set. This is typically done in your auth service:

```dart
// In your auth service or login handler
final apiClient = ref.read(apiClientProvider);
apiClient.setAuthToken(userToken); // Set token after login
```

The AI chat endpoint requires authentication (`auth:sanctum` middleware).

## Usage Examples

### Basic Usage (Using Widget)

The widget handles everything automatically:

```dart
AiAssistantWidget(
  aiChatService: aiChatService,
)
```

Users can:
1. Click the floating button to open chat
2. Type questions or select suggested questions
3. Get AI responses with Text-to-SQL support (if authorized)

### Programmatic Usage (Direct Service Call)

If you want to call the AI service directly:

```dart
import '../services/ai_chat_service.dart';
import '../core/utils/result.dart';

// Get service from provider
final aiChatService = ref.read(aiChatServiceProvider);

// Send message
final result = await aiChatService.sendMessage(
  "Combien de patients avons-nous aujourd'hui?",
);

if (result is Success) {
  final response = result.data['response'];
  final dataType = result.data['data_type']; // 'general', 'sql_query', etc.
  print('AI Response: $response');
} else {
  print('Error: ${(result as Failure).error}');
}
```

## Text-to-SQL Feature

### How It Works

1. **Detection**: Backend detects if question needs SQL (keywords like "show me", "list all", "how many")
2. **Permission Check**: Only Admin, Doctor, Receptionist can use Text-to-SQL
3. **SQL Generation**: AI generates SQL from natural language
4. **Validation**: Multiple security layers validate SQL
5. **Execution**: Query executes safely
6. **Formatting**: Results formatted into natural language response

### Example Questions That Trigger Text-to-SQL

- ✅ "Combien de patients avons-nous aujourd'hui?"
- ✅ "Liste tous les rendez-vous de cette semaine"
- ✅ "Montre-moi les patients avec des factures impayées"
- ✅ "Quels sont les patients qui ont des rendez-vous en attente?"
- ✅ "Combien de rendez-vous par jour cette semaine?"

### Security

- ✅ Only SELECT queries allowed
- ✅ Whitelist of allowed tables
- ✅ Role-based filtering (doctors see only their data)
- ✅ LIMIT enforcement (max 100 rows)
- ✅ Full audit logging

## Customization

### Customize Colors

```dart
AiAssistantWidget(
  aiChatService: aiChatService,
  primaryColor: Colors.blue,
  secondaryColor: Colors.cyan,
)
```

### Customize Suggested Questions

Edit `_suggestedQuestions` in `ai_assistant_widget.dart`:

```dart
final List<String> _suggestedQuestions = [
  "Your custom question 1",
  "Your custom question 2",
  // ...
];
```

### Customize Welcome Message

Edit the welcome message in `_AiAssistantWidgetState.initState()`:

```dart
_messages.add(ChatMessage(
  role: 'assistant',
  content: 'Your custom welcome message',
  timestamp: DateTime.now(),
));
```

## API Response Format

The backend returns:

```json
{
  "response": "AI generated response text",
  "data_type": "general" | "sql_query" | "my_patient_info"
}
```

## Error Handling

The service handles errors gracefully:

```dart
final result = await aiChatService.sendMessage("Question");

if (result is Failure) {
  // Handle error
  showErrorDialog(result.error);
}
```

Common errors:
- **401 Unauthorized**: User not authenticated
- **403 Forbidden**: User doesn't have permission for Text-to-SQL
- **429 Too Many Requests**: Rate limit exceeded (20 requests/minute)
- **500 Server Error**: Backend error

## Testing

### Test Basic Chat

```dart
final result = await aiChatService.sendMessage(
  "Quels sont les symptômes courants de la grippe?",
);
```

### Test Text-to-SQL (Admin/Doctor/Receptionist)

```dart
final result = await aiChatService.sendMessage(
  "Combien de patients avons-nous aujourd'hui?",
);
```

### Check if Question is Likely SQL

```dart
final isSql = aiChatService.isLikelySqlQuery(
  "Liste tous les patients"
); // Returns true
```

## Troubleshooting

### Widget Not Showing

1. Check if `aiChatService` is provided:
   ```dart
   final aiChatService = ref.watch(aiChatServiceProvider);
   ```

2. Check if widget is in a Stack:
   ```dart
   Stack(
     children: [
       YourContent(),
       AiAssistantWidget(aiChatService: aiChatService),
     ],
   )
   ```

### "API client is not initialized" Error

Make sure you're passing the service:
```dart
AiAssistantWidget(
  aiChatService: aiChatService, // Don't forget this!
)
```

### "Not authenticated" Error

Set the auth token:
```dart
apiClient.setAuthToken(userToken);
```

### Text-to-SQL Not Working

1. Check user role (must be Admin, Doctor, or Receptionist)
2. Check if question contains SQL indicators
3. Check backend logs for errors

## Comparison with Next.js Implementation

| Feature | Next.js | Flutter |
|---------|---------|---------|
| API Endpoint | `/api/ai/chat` | `/api/ai/chat` ✅ |
| Text-to-SQL | ✅ | ✅ |
| Authentication | ✅ | ✅ |
| Floating Widget | ✅ | ✅ |
| Conversation History | ✅ | ✅ |
| Suggested Questions | ✅ | ✅ |
| Role-Based Access | ✅ | ✅ |

## Files Reference

- **Service**: `lib/services/ai_chat_service.dart`
- **Widget**: `lib/widgets/ai_assistant_widget.dart`
- **Provider**: `lib/providers/api_providers.dart` (line ~130)
- **Constants**: `lib/core/config/api_constants.dart` (line ~163)
- **Backend**: `api/app/Http/Controllers/AiChatController.php`
- **Text-to-SQL**: `api/app/Services/TextToSqlService.php`

## Next Steps

1. ✅ Add widget to your main screen
2. ✅ Test basic chat functionality
3. ✅ Test Text-to-SQL (if you're Admin/Doctor/Receptionist)
4. ✅ Customize colors and questions
5. ✅ Deploy and test on device

## Support

For more details on the backend implementation, see:
- `TEXT_TO_SQL_WORKFLOW_EXPLANATION.md` - Complete workflow explanation
- `TEXT_TO_SQL_DOCUMENTATION.md` - Backend documentation
- `AI_ASSISTANT_DOCUMENTATION.md` - Next.js implementation details

---

**Created**: 2024  
**Version**: 1.0
