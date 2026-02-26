import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double _heading = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenCompass();
  }

  void _listenCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Датчик компаса недоступен на этом устройстве';
        });
      }
      return;
    }
    events.listen((CompassEvent event) {
      if (mounted) {
        setState(() {
          _heading = event.heading ?? 0.0;
          _hasError = false;
          _errorMessage = null;
        });
      }
    }, onError: (dynamic e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e?.toString() ?? 'Нет доступа к датчику';
        });
      }
    });
  }

  String _cardinalDirection(double degrees) {
    const directions = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];
    final index = ((degrees + 22.5) % 360 / 45).floor().clamp(0, 7);
    return directions[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                'Курсоуказатель',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Card(
                    color: Colors.orange.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _errorMessage ?? 'Ошибка датчика',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.85;
                    return Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Внешнее кольцо (шкала градусов)
                            _buildDegreeRing(size),
                            // Роза компаса (вращается по курсу)
                            Transform.rotate(
                              angle: -_heading * math.pi / 180,
                              child: _buildCompassRose(size),
                            ),
                            // Неподвижная стрелка "направление устройства"
                            _buildHeadingArrow(size),
                            // Центральный круг
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Блок курса в градусах и румбах
              _buildCourseCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDegreeRing(double size) {
    const step = 15;
    return CustomPaint(
      size: Size(size, size),
      painter: _DegreeRingPainter(step: step),
    );
  }

  Widget _buildCompassRose(double size) {
    const labels = ['С', 'В', 'Ю', 'З'];
    const angles = [0.0, 90.0, 180.0, 270.0];
    return CustomPaint(
      size: Size(size, size),
      painter: _CompassRosePainter(
        labels: labels,
        angles: angles,
      ),
    );
  }

  Widget _buildHeadingArrow(double size) {
    return CustomPaint(
      size: Size(size * 0.5, size * 0.5),
      painter: _HeadingArrowPainter(),
    );
  }

  Widget _buildCourseCard() {
    final degrees = _heading.toStringAsFixed(1);
    final cardinal = _cardinalDirection(_heading);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Курс',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              Text(
                '${degrees}°',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          Container(
            width: 2,
            height: 50,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Румб',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              Text(
                cardinal,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DegreeRingPainter extends CustomPainter {
  final int step;

  _DegreeRingPainter({this.step = 15});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, tickPaint);

    for (int i = 0; i < 360; i += step) {
      final rad = i * math.pi / 180;
      final isMajor = i % 90 == 0;
      final tickLength = isMajor ? 16.0 : 10.0;
      final innerR = radius - tickLength;
      final outerR = radius;
      canvas.drawLine(
        Offset(center.dx + innerR * math.sin(rad), center.dy - innerR * math.cos(rad)),
        Offset(center.dx + outerR * math.sin(rad), center.dy - outerR * math.cos(rad)),
        tickPaint,
      );
      if (i % 30 == 0 && i % 90 != 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$i',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final x = center.dx + (radius - 22) * math.sin(rad) - textPainter.width / 2;
        final y = center.dy - (radius - 22) * math.cos(rad) - textPainter.height / 2;
        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompassRosePainter extends CustomPainter {
  final List<String> labels;
  final List<double> angles;

  _CompassRosePainter({required this.labels, required this.angles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;

    for (int i = 0; i < labels.length; i++) {
      final angle = angles[i] * math.pi / 180;
      final x = center.dx + radius * math.sin(angle);
      final y = center.dy - radius * math.cos(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Деления между С-В-Ю-З (по 45°)
    const subLabels = ['СВ', 'ЮВ', 'ЮЗ', 'СЗ'];
    const subAngles = [45.0, 135.0, 225.0, 315.0];
    for (int i = 0; i < subLabels.length; i++) {
      final angle = subAngles[i] * math.pi / 180;
      final x = center.dx + radius * math.sin(angle);
      final y = center.dy - radius * math.cos(angle);
      final textPainter = TextPainter(
        text: TextSpan(
          text: subLabels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black38, offset: Offset(1, 1), blurRadius: 1),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeadingArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    // Стрелка вверх (куда "смотрит" устройство)
    const h = 18.0;
    const w = 24.0;
    path.moveTo(center.dx, center.dy - h);
    path.lineTo(center.dx - w / 2, center.dy + h);
    path.lineTo(center.dx, center.dy + h - 8);
    path.lineTo(center.dx + w / 2, center.dy + h);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.red.shade700
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
