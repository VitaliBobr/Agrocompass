import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/widgets/gps_status.dart';

void main() {
  group('GpsStatus', () {
    testWidgets('shows НЕТ СИГНАЛА GPS when no signal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: GpsStatus(
              hasSignal: false,
            ),
          ),
        ),
      );
      expect(find.text('НЕТ СИГНАЛА GPS'), findsOneWidget);
    });

    testWidgets('shows accuracy when has signal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: GpsStatus(
              hasSignal: true,
              accuracyMeters: 1.5,
            ),
          ),
        ),
      );
      expect(find.textContaining('1.5'), findsOneWidget);
      expect(find.textContaining('Точность'), findsOneWidget);
    });

    testWidgets('shows satellite count when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: GpsStatus(
              hasSignal: true,
              accuracyMeters: 2.0,
              satelliteCount: 12,
            ),
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.satellite_alt), findsOneWidget);
    });

    testWidgets('hides accuracy when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: GpsStatus(
              hasSignal: true,
              satelliteCount: 8,
            ),
          ),
        ),
      );
      expect(find.textContaining('Точность'), findsNothing);
    });

    testWidgets('has signal without optional params', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: GpsStatus(hasSignal: true),
          ),
        ),
      );
      expect(find.byType(GpsStatus), findsOneWidget);
    });
  });
}
