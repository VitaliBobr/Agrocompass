import 'package:flutter/material.dart';

/// Информация о спутниках и точности GPS.
class GpsStatus extends StatelessWidget {
  final bool hasSignal;
  final double? accuracyMeters;
  final int? satelliteCount;

  const GpsStatus({
    super.key,
    required this.hasSignal,
    this.accuracyMeters,
    this.satelliteCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSignal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'НЕТ СИГНАЛА GPS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (satelliteCount != null) ...[
          Icon(Icons.satellite_alt, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 4),
          Text(
            '$satelliteCount',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
        ],
        if (accuracyMeters != null)
          Text(
            'Точность: ${accuracyMeters!.toStringAsFixed(1)} м',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
      ],
    );
  }
}
