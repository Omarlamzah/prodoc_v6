# Debug: Chatbox Button Not Visible

## Quick Checklist

### ✅ Step 1: Are you using Stack?

The widget MUST be inside a `Stack`:

```dart
Stack(
  children: [
    YourContent(),
    AiAssistantWidget(...),  // Must be here
  ],
)
```

### ✅ Step 2: Is it at the END of Stack children?

Put it LAST in the children array:

```dart
Stack(
  children: [
    YourContent(),           // First
    SomeOtherWidget(),       // Second
    AiAssistantWidget(...),  // LAST - This is important!
  ],
)
```

### ✅ Step 3: Are you using ConsumerWidget?

You need `ConsumerWidget` or `ConsumerStatefulWidget`:

```dart
class YourScreen extends ConsumerWidget {  // ✅ Correct
  // NOT: class YourScreen extends StatelessWidget {  // ❌ Wrong
```

### ✅ Step 4: Are you passing the service?

```dart
final aiChatService = ref.watch(aiChatServiceProvider);

AiAssistantWidget(
  aiChatService: aiChatService,  // ✅ Must pass this
)
```

## Test with Simple Widget

I created a simpler widget that's easier to see. Try this:

### 1. Use the Simple Widget

Replace `AiAssistantWidget` with `AiAssistantSimpleWidget`:

```dart
import '../widgets/ai_assistant_simple_widget.dart';  // Change import

// In your Stack:
AiAssistantSimpleWidget(  // Use this instead
  aiChatService: aiChatService,
  buttonColor: Colors.red,  // Make it RED so it's obvious
),
```

### 2. Test with the Test Screen

1. Open `lib/screens/ai_chatbox_visible_test.dart`
2. Add a route to it
3. Navigate to that screen
4. You should DEFINITELY see a button in bottom-right

## Common Issues

### Issue 1: Button is behind other content

**Solution:** Put the widget LAST in Stack children:

```dart
Stack(
  children: [
    Content1(),
    Content2(),
    AiAssistantWidget(...),  // LAST = On top
  ],
)
```

### Issue 2: Scaffold body is not a Stack

**Problem:**
```dart
Scaffold(
  body: YourContent(),  // ❌ Not a Stack
)
```

**Solution:**
```dart
Scaffold(
  body: Stack(  // ✅ Use Stack
    children: [
      YourContent(),
      AiAssistantWidget(...),
    ],
  ),
)
```

### Issue 3: Using Column or Row instead of Stack

**Problem:**
```dart
Column(  // ❌ Wrong
  children: [
    Content(),
    AiAssistantWidget(...),  // Won't work!
  ],
)
```

**Solution:**
```dart
Stack(  // ✅ Correct
  children: [
    Content(),
    AiAssistantWidget(...),
  ],
)
```

### Issue 4: Widget is outside visible area

Make sure your screen has enough space. The button is positioned at:
- `bottom: 16` or `bottom: 20`
- `right: 16` or `right: 20`

If your content covers the bottom-right, the button will be hidden.

## Visual Debugging

### Make the button OBVIOUS

Use a bright color to make sure it's visible:

```dart
AiAssistantSimpleWidget(
  aiChatService: aiChatService,
  buttonColor: Colors.red,  // RED = Very visible!
),
```

### Add a debug indicator

Add this to see if the widget is being built:

```dart
Stack(
  children: [
    YourContent(),
    // Debug: Always visible text
    Positioned(
      top: 50,
      right: 50,
      child: Container(
        padding: EdgeInsets.all(8),
        color: Colors.red,
        child: Text('DEBUG: Widget is here!'),
      ),
    ),
    AiAssistantWidget(aiChatService: aiChatService),
  ],
)
```

## Step-by-Step Debug Process

### Step 1: Verify Widget File Exists

Check that this file exists:
- `lib/widgets/ai_assistant_widget.dart` ✅
- OR `lib/widgets/ai_assistant_simple_widget.dart` ✅

### Step 2: Verify Provider Exists

Check `lib/providers/api_providers.dart` has:
```dart
final aiChatServiceProvider = Provider<AiChatService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiChatService(apiClient: apiClient);
});
```

### Step 3: Test with Minimal Code

Create a minimal test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ai_assistant_simple_widget.dart';
import '../providers/api_providers.dart';

class MinimalTest extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChatService = ref.watch(aiChatServiceProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          Center(child: Text('TEST')),
          AiAssistantSimpleWidget(
            aiChatService: aiChatService,
            buttonColor: Colors.red,  // RED = Visible!
          ),
        ],
      ),
    );
  }
}
```

If this doesn't show a button, there's a deeper issue.

### Step 4: Check Console for Errors

Look for errors in your console:
- Import errors?
- Provider errors?
- Build errors?

### Step 5: Hot Restart (Not Reload)

Press `R` in terminal for hot restart, or fully restart the app.

## Still Not Working?

### Try This Nuclear Option

Add a simple FloatingActionButton first to verify Stack works:

```dart
Stack(
  children: [
    YourContent(),
    // Test: Simple button
    Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.chat),
      ),
    ),
  ],
)
```

If this button shows, then the Stack works. Replace it with `AiAssistantWidget`.

If this button doesn't show, the problem is with your Stack setup.

## Need More Help?

1. Check `HOW_TO_ADD_CHATBOX.md` for detailed instructions
2. Use `lib/screens/ai_chatbox_visible_test.dart` to test
3. Try `AiAssistantSimpleWidget` instead of `AiAssistantWidget`
