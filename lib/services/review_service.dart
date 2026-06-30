// lib/services/review_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const String _firstLaunchKey = 'review_first_launch';
  static const String _launchCountKey = 'review_launch_count';
  static const String _lastReviewPromptKey = 'review_last_prompt';
  static const String _reviewDismissedKey = 'review_dismissed';
  static const String _reviewCompletedKey = 'review_completed';

  // Show review prompt after 3 days and 5 app launches
  static const int _minDaysSinceFirstLaunch = 3;
  static const int _minLaunchCount = 5;
  static const int _daysBetweenPrompts = 7; // Don't show again for 7 days if dismissed

  /// Check if review prompt should be shown
  static Future<bool> shouldShowReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't show if user already completed review
    if (prefs.getBool(_reviewCompletedKey) == true) {
      return false;
    }

    // Get first launch date
    final firstLaunchMillis = prefs.getInt(_firstLaunchKey);
    if (firstLaunchMillis == null) {
      // First time opening app - record it
      await prefs.setInt(_firstLaunchKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_launchCountKey, 1);
      return false;
    }

    // Increment launch count
    final currentCount = prefs.getInt(_launchCountKey) ?? 0;
    await prefs.setInt(_launchCountKey, currentCount + 1);

    // Check if dismissed recently
    final lastPromptMillis = prefs.getInt(_lastReviewPromptKey);
    if (lastPromptMillis != null) {
      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
      final daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
      
      if (daysSinceLastPrompt < _daysBetweenPrompts) {
        return false; // Too soon to show again
      }
    }

    // Check conditions
    final firstLaunchDate = DateTime.fromMillisecondsSinceEpoch(firstLaunchMillis);
    final daysSinceFirstLaunch = DateTime.now().difference(firstLaunchDate).inDays;
    final launchCount = prefs.getInt(_launchCountKey) ?? 0;

    // Show if conditions are met
    return daysSinceFirstLaunch >= _minDaysSinceFirstLaunch && 
           launchCount >= _minLaunchCount;
  }

  /// Mark review as dismissed (user clicked "Maybe later" or similar)
  static Future<void> dismissReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReviewPromptKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_reviewDismissedKey, true);
  }

  /// Mark review as completed (user clicked "Rate now" and went to Play Store)
  static Future<void> completeReview() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewCompletedKey, true);
    await prefs.setInt(_lastReviewPromptKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Reset review data (for testing purposes)
  static Future<void> resetReviewData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstLaunchKey);
    await prefs.remove(_launchCountKey);
    await prefs.remove(_lastReviewPromptKey);
    await prefs.remove(_reviewDismissedKey);
    await prefs.remove(_reviewCompletedKey);
  }
}

