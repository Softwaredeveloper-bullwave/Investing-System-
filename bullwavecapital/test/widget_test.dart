import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bullwave_invest/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BullWaveApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
