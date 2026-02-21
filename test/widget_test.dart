import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gitty/app.dart';

void main() {
  testWidgets('GittyApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GittyApp(),
      ),
    );
    // App renders a loading/splash state initially
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
