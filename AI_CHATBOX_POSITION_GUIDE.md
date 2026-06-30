# AI Chatbox Position Guide

## Current Position Options

The AI chatbox can be placed in 5 different positions. Choose the one that works best for your app layout.

## Position Options

### 1. Top-Right (Recommended) ✅
**Best for:** Most apps, doesn't interfere with FAB buttons
```dart
AiAssistantPositionedWidget(
  aiChatService: aiChatService,
  position: AiAssistantPosition.topRight, // ← Change this
)
```
**Location:** Below app bar, right side
**Good because:** 
- Doesn't conflict with bottom FAB buttons
- Easy to reach
- Common pattern for chat widgets

### 2. Top-Left
**Best for:** If you have important content on the right
```dart
position: AiAssistantPosition.topLeft,
```
**Location:** Below app bar, left side

### 3. Bottom-Right (Default)
**Best for:** If no FAB button on right
```dart
position: AiAssistantPosition.bottomRight,
```
**Location:** Bottom-right corner
**Note:** May conflict with FloatingActionButton

### 4. Bottom-Left
**Best for:** If FAB is on the right side
```dart
position: AiAssistantPosition.bottomLeft,
```
**Location:** Bottom-left corner
**Good because:** Doesn't conflict with right-side FAB

### 5. Bottom-Center
**Best for:** Centered layout preference
```dart
position: AiAssistantPosition.bottomCenter,
```
**Location:** Bottom center
**Good because:** Centered, balanced look

## How to Change Position

### In Dashboard Screen

Open `lib/screens/dashboard_screen.dart` and find:

```dart
AiAssistantPositionedWidget(
  aiChatService: ref.watch(aiChatServiceProvider),
  buttonColor: Colors.indigo,
  position: AiAssistantPosition.topRight, // ← Change this line
),
```

### Change to Different Position

**Example 1: Move to Top-Left**
```dart
position: AiAssistantPosition.topLeft,
```

**Example 2: Move to Bottom-Left**
```dart
position: AiAssistantPosition.bottomLeft,
```

**Example 3: Move to Bottom-Center**
```dart
position: AiAssistantPosition.bottomCenter,
```

## Visual Guide

```
┌─────────────────────────────┐
│ [App Bar]              [💬] │ ← topRight
│ [💬]                        │ ← topLeft
│                             │
│                             │
│                             │
│                             │
│ [💬]                  [💬]  │ ← bottomLeft  bottomRight
│         [💬]                │ ← bottomCenter
└─────────────────────────────┘
```

## Recommended Positions by Screen Type

### Dashboard Screen
- ✅ **Top-Right** (Recommended) - Doesn't interfere with FAB
- ✅ **Top-Left** - Alternative if right side is busy

### Forms/Screens with Bottom Buttons
- ✅ **Top-Right** - Best choice
- ✅ **Top-Left** - If right side has important content

### Screens with Right FAB
- ✅ **Top-Right** - Best choice
- ✅ **Bottom-Left** - Alternative

### Screens with Left FAB
- ✅ **Top-Right** - Best choice
- ✅ **Bottom-Right** - Alternative

## Current Setup in Dashboard

The dashboard currently uses **topRight** position:

```dart
AiAssistantPositionedWidget(
  aiChatService: ref.watch(aiChatServiceProvider),
  buttonColor: Colors.indigo,
  position: AiAssistantPosition.topRight, // Currently here
),
```

## Quick Change Examples

### Move to Top-Left
```dart
position: AiAssistantPosition.topLeft,
```

### Move to Bottom-Left
```dart
position: AiAssistantPosition.bottomLeft,
```

### Move to Bottom-Center
```dart
position: AiAssistantPosition.bottomCenter,
```

## Customization

You can also change the button color:

```dart
AiAssistantPositionedWidget(
  aiChatService: aiChatService,
  buttonColor: Colors.blue,      // Change color
  position: AiAssistantPosition.topRight,
),
```

## Testing Different Positions

1. Change the `position` value
2. Hot restart your app
3. Check the new location
4. Try different positions to find the best one

## Best Practice

**Recommended:** Use `topRight` for most screens because:
- ✅ Doesn't conflict with FAB buttons
- ✅ Easy to reach
- ✅ Standard pattern for chat widgets
- ✅ Visible but not intrusive

---

**Current Position:** `topRight` (Top-right, below app bar)
**File:** `lib/screens/dashboard_screen.dart` (line ~377)
