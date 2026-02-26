import 'package:flutter/material.dart';

/// Горизонтальная шкала отклонения: зелёная зона 0±0.1 м, красные края, ползунок.
class DeviationBar extends StatelessWidget {
  final double deviationMeters;
  final double maxDeviation;

  const DeviationBar({
    super.key,
    required this.deviationMeters,
    this.maxDeviation = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final t = (deviationMeters / maxDeviation).clamp(-1.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final center = w / 2;
            final halfGreen = (0.1 / maxDeviation) * (w / 2);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Фон: красный слева, зелёный центр, красный справа
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        ),
                      ),
                    ),
                    Container(
                      width: halfGreen * 2,
                      height: 16,
                      color: const Color(0xFF4CAF50),
                    ),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                // Ползунок
                Positioned(
                  left: center + (t * (w / 2)) - 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ВЛЕВО', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('ВПРАВО', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
