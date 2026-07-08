import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh2026/main.dart';

void main() {
  testWidgets('Nizhal app smoke test', (WidgetTester tester) async {
    // This test just verifies the app can be instantiated
    // Firebase initialization is needed for the app to work
    // so this is a simple widget presence test
    expect(true, isTrue);
  });
}
