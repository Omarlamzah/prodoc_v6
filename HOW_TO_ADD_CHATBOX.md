# How to Add AI Chatbox to Your App - Step by Step

## The Problem
You can't see the chatbox because it needs to be added to a screen. The widget exists but isn't displayed anywhere yet.

## Quick Solution (3 Steps)

### Step 1: Find Your Main Screen

Open one of these files:
- `lib/screens/dashboard_screen.dart` (most likely)
- Or any screen where you want the chatbox

### Step 2: Add These Imports at the Top

```dart
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';
```

### Step 3: Modify Your Build Method

Find your `Scaffold` and wrap the `body` in a `Stack`:

**BEFORE:**
```dart
return Scaffold(
  body: YourContent(),
);
```

**AFTER:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final aiChatService = ref.watch(aiChatServiceProvider);
  
  return Scaffold(
    body: Stack(
      children: [
        YourContent(),  // Your existing content
        AiAssistantWidget(aiChatService: aiChatService),  // Add this!
      ],
    ),
  );
}
```

## Visual Example

```
┌─────────────────────────────┐
│  Scaffold                   │
│  ┌───────────────────────┐  │
│  │  Stack                │  │
│  │  ┌─────────────────┐  │  │
│  │  │ Your Content    │  │  │
│  │  │ (Dashboard, etc)│  │  │
│  │  └─────────────────┘  │  │
│  │                        │  │
│  │  ┌─────────────────┐  │  │
│  │  │ AI Chatbox      │  │  │
│  │  │ (Floating)      │  │  │
│  │  └─────────────────┘  │  │
│  │                        │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

## Test It First

1. Open `lib/screens/ai_chatbox_test_screen.dart` (I created this for you)
2. Add a route to it in your app
3. Navigate to that screen
4. You should see a floating chat button in the bottom-right corner

## Full Example Code

Here's a complete example you can copy:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_widget.dart';
import '../providers/api_providers.dart';

class YourScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the AI chat service
    final aiChatService = ref.watch(aiChatServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Screen'),
      ),
      body: Stack(
        children: [
          // Your existing content goes here
          Center(
            child: Text('Your content'),
          ),
          
          // AI Chatbox - Add this at the end!
          AiAssistantWidget(
            aiChatService: aiChatService,
          ),
        ],
      ),
    );
  }
}
```

## Important Notes

1. ✅ **Must use `Stack`** - The widget uses `Positioned` and needs a Stack parent
2. ✅ **Must use `ConsumerWidget`** - To access the provider
3. ✅ **Must pass `aiChatService`** - From the provider
4. ✅ **Add at the END** - Put it last in the Stack children array

## Where to Add It

### Option 1: Dashboard (Recommended)
Add to `lib/screens/dashboard_screen.dart` so it's available on the main screen.

### Option 2: Main Layout
If you have a main layout widget, add it there so it's on all screens.

### Option 3: Specific Screen
Add to any screen where you want the chatbox.

## Troubleshooting

### Still can't see it?

1. **Check the Stack**: Make sure you're using `Stack`, not `Column` or `Row`
2. **Check imports**: Make sure both imports are added
3. **Check provider**: Make sure you're using `ref.watch(aiChatServiceProvider)`
4. **Hot restart**: Try hot restart (not just hot reload) - press `R` in terminal or restart the app
5. **Check console**: Look for any errors in the console

### Button appears but doesn't work?

- Make sure user is logged in (API requires authentication)
- Check that auth token is set: `apiClient.setAuthToken(token)`

## Quick Test

1. Open `lib/screens/ai_chatbox_test_screen.dart`
2. Add this route somewhere in your app:
```dart
routes: {
  '/ai-test': (context) => AiChatboxTestScreen(),
}
```
3. Navigate to `/ai-test`
4. You should see the chat button!

## Need More Help?

Check these files:
- `QUICK_FIX_ADD_AI_CHATBOX.md` - More detailed guide
- `FLUTTER_AI_ASSISTANT_INTEGRATION.md` - Full documentation
- `lib/screens/ai_assistant_example.dart` - Another example
