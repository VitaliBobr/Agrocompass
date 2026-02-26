import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/services/demo_gnss_simulation.dart';
import 'package:agrokilar_compass/services/location_service.dart';

void main() {
  group('GnssLogEntry', () {
    test('toNmeaStyle formats coordinates and time', () {
      final entry = GnssLogEntry(
        time: DateTime(2024, 1, 15, 9, 5, 30),
        lat: 55.75,
        lon: 37.62,
        accuracyMeters: 1.5,
        speedKmh: 18.5,
        heading: 45.0,
        isDemo: true,
      );
      final s = entry.toNmeaStyle();
      expect(s, contains('DEMO'));
      expect(s, contains('09:05:30'));
      expect(s, contains('55.750000'));
      expect(s, contains('37.620000'));
      expect(s, contains('1.5m'));
      expect(s, contains('18.5km/h'));
      expect(s, contains('45°'));
    });

    test('toNmeaStyle handles null heading', () {
      final entry = GnssLogEntry(
        time: DateTime(2024, 1, 1, 12, 0, 0),
        lat: 0,
        lon: 0,
        accuracyMeters: 2.0,
        speedKmh: 0,
        heading: null,
      );
      final s = entry.toNmeaStyle();
      expect(s, contains('—°'));
    });

    test('toNmeaStyle handles negative coordinates', () {
      final entry = GnssLogEntry(
        time: DateTime(2024, 1, 1, 0, 0, 0),
        lat: -33.5,
        lon: -70.5,
        accuracyMeters: 1.0,
        speedKmh: 5.0,
      );
      final s = entry.toNmeaStyle();
      expect(s, contains('S'));
      expect(s, contains('W'));
    });
  });

  group('DemoKeyState', () {
    test('default values are false', () {
      final keys = DemoKeyState();
      expect(keys.forward, isFalse);
      expect(keys.back, isFalse);
      expect(keys.left, isFalse);
      expect(keys.right, isFalse);
    });
  });

  group('DemoGnssSimulation', () {
    late DemoGnssSimulation sim;

    setUp(() {
      sim = DemoGnssSimulation();
    });

    tearDown(() {
      sim.dispose();
    });

    test('addToLog adds entry and emits to logStream', () async {
      final updates = <List<GnssLogEntry>>[];
      final sub = sim.logStream.listen(updates.add);

      sim.addToLog(
        PositionUpdate(
          latitude: 55.75,
          longitude: 37.62,
          accuracyMeters: 1.5,
          speedKmh: 10.0,
          heading: 90.0,
          timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        ),
        isDemo: true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sim.logEntries.length, 1);
      expect(sim.logEntries.first.lat, 55.75);
      expect(sim.logEntries.first.isDemo, isTrue);
      expect(updates.length, greaterThanOrEqualTo(1));

      await sub.cancel();
    });

    test('setDemoPath sets start position', () {
      sim.setDemoPath(55.8, 37.7, 55.9, 37.8);
      sim.addToLog(
        PositionUpdate(
          latitude: 55.75,
          longitude: 37.62,
          accuracyMeters: 1.0,
          speedKmh: 0,
          timestamp: DateTime(2024, 1, 1),
        ),
      );
      expect(sim.logEntries.isNotEmpty, isTrue);
    });

    test('setManualMode and updateKeyState', () {
      expect(sim.isManualMode, isFalse);
      sim.setManualMode(true);
      expect(sim.isManualMode, isTrue);
      sim.updateKeyState(DemoKeyState()..forward = true);
      sim.setManualMode(false);
      expect(sim.isManualMode, isFalse);
    });
  });
}
