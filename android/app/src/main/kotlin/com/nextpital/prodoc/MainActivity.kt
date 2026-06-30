package com.nextpital.prodoc

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15+ (SDK 35) compatibility
        // This is required for apps targeting SDK 35 to ensure proper display on Android 15+
        // WindowCompat.setDecorFitsSystemWindows() is the recommended approach for Flutter apps
        // This ensures the app displays correctly without gaps at the edges
        // Call this before super.onCreate() to ensure it's applied early
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
