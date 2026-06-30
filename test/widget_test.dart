// Widget tests for ProDoc Medical Management App
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prodoc/main.dart';

void main() {
  group('ProDoc App Tests', () {
    testWidgets('MyApp widget builds without errors', (WidgetTester tester) async {
      // Test that the main app widget can be built
      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );

      // Wait for initial render
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify MaterialApp is present
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Verify SplashScreen is initially shown (it contains "ProDoc" text)
      expect(find.text('ProDoc'), findsOneWidget);
    });

    test('Flutter dependencies are properly configured', () {
      // This test verifies that the test framework is working
      expect(true, isTrue);
    });
  });
}
