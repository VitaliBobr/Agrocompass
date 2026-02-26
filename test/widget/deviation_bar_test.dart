import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/widgets/deviation_bar.dart';

void main() {
  group('DeviationBar', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: DeviationBar(
                deviationMeters: 0,
                maxDeviation: 1.0,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(DeviationBar), findsOneWidget);
    });

    testWidgets('shows ВЛЕВО and ВПРАВО labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: DeviationBar(
                deviationMeters: 0,
                maxDeviation: 1.0,
              ),
            ),
          ),
        ),
      );
      expect(find.text('ВЛЕВО'), findsOneWidget);
      expect(find.text('ВПРАВО'), findsOneWidget);
    });

    testWidgets('contains Stack with LayoutBuilder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: DeviationBar(
                deviationMeters: 0.5,
                maxDeviation: 1.0,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Stack), findsWidgets);
      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('accepts custom maxDeviation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: DeviationBar(
                deviationMeters: 0.5,
                maxDeviation: 2.0,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(DeviationBar), findsOneWidget);
    });
  });
}
