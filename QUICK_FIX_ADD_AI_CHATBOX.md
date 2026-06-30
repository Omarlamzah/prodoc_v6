# Quick Fix: Add AI Chatbox to Your App

## Problem: Chatbox Not Showing

The AI Assistant widget needs to be added to your screen. Follow these steps:

## Solution 1: Add to Dashboard Screen

### Step 1: Open `lib/screens/dashboard_screen.dart`

### Step 2: Add imports at the top:

```dart
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';
```

### Step 3: Find the main `build` method or `Scaffold`

Look for something like:
```dart
return Scaffold(
  body: YourContent(),
);
```

### Step 4: Wrap it in a Stack and add the widget:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Get AI chat service
  final aiChatService = ref.watch(aiChatServiceProvider);
  
  return Scaffold(
    body: Stack(
      children: [
        // Your existing content
        YourExistingContent(),
        
        // Add AI Assistant here (floating button)
        AiAssistantWidget(
          aiChatService: aiChatService,
        ),
      ],
    ),
  );
}
```

## Solution 2: Add to Main Layout (Recommended)

If you have a main layout file, add it there so it's available on all screens.

### Find your main layout file (might be in `lib/main.dart` or a layout widget)

Add the same Stack structure as above.

## Solution 3: Quick Test - Add to Any Screen

### Create a test screen or add to an existing screen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';

class TestScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Test Screen')),
      body: Stack(
        children: [
          Center(
            child: Text('Look for the chat button in bottom-right!'),
          ),
          // AI Assistant Widget
          AiAssistantWidget(
            aiChatService: aiChatService,
          ),
        ],
      ),
    );
  }
}
```

## Important Notes:

1. **Must use Stack**: The widget uses `Positioned` and needs to be in a `Stack`
2. **Must provide service**: Pass `aiChatService` from the provider
3. **Must be ConsumerWidget**: Use `ConsumerWidget` or `ConsumerStatefulWidget` to access providers
4. **Check authentication**: Make sure user is logged in (API requires auth token)

## Visual Guide:

```
Your Screen Structure:
┌─────────────────────────┐
│   Scaffold              │
│   ┌─────────────────┐   │
│   │  Stack          │   │
│   │  ├─ Your Content│   │
│   │  └─ AI Widget   │ ← Add here!
│   │                  │   │
│   └─────────────────┘   │
└─────────────────────────┘
```

## Troubleshooting:

### Widget not showing?
1. ✅ Check you're using `Stack`
2. ✅ Check you're passing `aiChatService`
3. ✅ Check imports are correct
4. ✅ Check user is authenticated
5. ✅ Try hot restart (not just hot reload)

### Button not clickable?
- Make sure nothing is covering it (check z-index/order in Stack)
- The button should be in bottom-right corner

### Error: "API client is not initialized"?
- Make sure you're passing `aiChatService` from provider
- Make sure auth token is set: `apiClient.setAuthToken(token)`

## Quick Copy-Paste Template:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';

class YourScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          // YOUR EXISTING CONTENT HERE
          
          // AI Assistant (add at the end)
          AiAssistantWidget(
            aiChatService: aiChatService,
          ),
        ],
      ),
    );
  }
}
```

## Still Not Working?

1. Check console for errors
2. Verify `aiChatServiceProvider` exists in `api_providers.dart`
3. Make sure widget file exists: `lib/widgets/ai_assistant_widget.dart`
4. Try the example screen: `lib/screens/ai_assistant_example.dart`
