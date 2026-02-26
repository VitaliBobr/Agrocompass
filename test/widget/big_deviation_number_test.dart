import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/widgets/big_deviation_number.dart';

void main() {
  group('BigDeviationNumber', () {
    testWidgets('shows --- when no signal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: 0.0,
              hasSignal: false,
            ),
          ),
        ),
      );
      expect(find.text('---'), findsOneWidget);
    });

    testWidgets('shows --- when deviation is null with signal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: null,
              hasSignal: true,
            ),
          ),
        ),
      );
      expect(find.text('---'), findsOneWidget);
    });

    testWidgets('shows positive value with signal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: 1.5,
              hasSignal: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('1.50'), findsOneWidget);
      expect(find.textContaining('м'), findsOneWidget);
    });

    testWidgets('shows negative value with minus sign', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: -0.25,
              hasSignal: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('−'), findsOneWidget);
      expect(find.textContaining('0.25'), findsOneWidget);
    });

    testWidgets('shows green for small deviation (<0.1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: 0.05,
              hasSignal: true,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, const Color(0xFF4CAF50));
    });

    testWidgets('shows yellow for medium deviation (0.1–0.3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: 0.2,
              hasSignal: true,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, const Color(0xFFFFC107));
    });

    testWidgets('shows red for large deviation (>0.3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: 0.5,
              hasSignal: true,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, const Color(0xFFF44336));
    });

    testWidgets('shows grey when no signal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BigDeviationNumber(
              deviationMeters: 0.0,
              hasSignal: false,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, Colors.grey);
    });
  });
}
