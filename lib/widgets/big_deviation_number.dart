import 'package:flutter/material.dart';

/// Огромная цифра отклонения (80–120 sp), цвет по величине: зелёный <0.1, жёлтый 0.1–0.3, красный >0.3.
class BigDeviationNumber extends StatelessWidget {
  final double? deviationMeters;
  final bool hasSignal;

  const BigDeviationNumber({
    super.key,
    required this.deviationMeters,
    required this.hasSignal,
  });

  Color _color() {
    if (!hasSignal || deviationMeters == null) return Colors.grey;
    final d = deviationMeters!.abs();
    if (d < 0.1) return const Color(0xFF4CAF50);
    if (d <= 0.3) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final text = !hasSignal || deviationMeters == null
        ? '---'
        : '${deviationMeters! >= 0 ? '' : '−'}${deviationMeters!.abs().toStringAsFixed(2)} м';
    return Text(
      text,
      style: TextStyle(
        fontSize: 96,
        fontWeight: FontWeight.bold,
        color: _color(),
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(1, 2), blurRadius: 2),
        ],
      ),
    );
  }
}
