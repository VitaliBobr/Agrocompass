import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ab_line.dart';
import '../repository/app_repository.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';

class CreateAbLineScreen extends StatefulWidget {
  final LocationService locationService;

  const CreateAbLineScreen({
    super.key,
    required this.locationService,
  });

  @override
  State<CreateAbLineScreen> createState() => _CreateAbLineScreenState();
}

class _CreateAbLineScreenState extends State<CreateAbLineScreen> {
  final _repo = AppRepository();
  double? _latA, _lonA, _latB, _lonB;
  bool _loading = false;
  String? _error;
  final _nameController = TextEditingController();
  final _widthController = TextEditingController(text: '2.1');
  final _totalAreaController = TextEditingController();
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final ok = await widget.locationService.checkAndRequestPermission();
    if (mounted) setState(() => _hasPermission = ok);
  }

  Future<Position?> _getCurrentPositionFallback() async {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _setPointA() async {
    if (!_hasPermission) {
      setState(() => _error = 'Нет разрешения на геолокацию');
      return;
    }
    setState(() { _error = null; _loading = true; });
    try {
      final demoPos = widget.locationService.lastPositionUpdate;
      final pos = demoPos == null ? await _getCurrentPositionFallback() : null;
      final lat = demoPos?.latitude ?? pos!.latitude;
      final lon = demoPos?.longitude ?? pos!.longitude;
      final acc = demoPos?.accuracyMeters ?? pos!.accuracy;
      if (acc > 5.0 && mounted && demoPos == null) {
        setState(() {
          _error = 'Точность GPS хуже 5 м. Подождите улучшения сигнала.';
          _loading = false;
        });
        return;
      }
      if (mounted) {
        setState(() {
          _latA = lat;
          _lonA = lon;
          _latB = _lonB = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _setPointB() async {
    if (!_hasPermission || _latA == null) return;
    setState(() { _error = null; _loading = true; });
    try {
      final demoPos = widget.locationService.lastPositionUpdate;
      final pos = demoPos == null ? await _getCurrentPositionFallback() : null;
      final lat = demoPos?.latitude ?? pos!.latitude;
      final lon = demoPos?.longitude ?? pos!.longitude;
      final acc = demoPos?.accuracyMeters ?? pos!.accuracy;
      if (acc > 5.0 && mounted && demoPos == null) {
        setState(() {
          _error = 'Точность GPS хуже 5 м.';
          _loading = false;
        });
        return;
      }
      if (mounted) {
        setState(() {
          _latB = lat;
          _lonB = lon;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _reset() {
    setState(() {
      _latA = _lonA = _latB = _lonB = null;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_latA == null || _latB == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название линии');
      return;
    }
    final width = double.tryParse(_widthController.text.replaceAll(',', '.'));
    if (width == null || width <= 0) {
      setState(() => _error = 'Введите ширину междурядья (м)');
      return;
    }
    final totalArea = _totalAreaController.text.trim().isEmpty
        ? null
        : double.tryParse(_totalAreaController.text.replaceAll(',', '.'));
    if (totalArea != null && totalArea <= 0) {
      setState(() => _error = 'Площадь поля должна быть > 0');
      return;
    }
    setState(() => _loading = true);
    try {
      final line = AbLine(
        name: name,
        createdAt: DateTime.now(),
        latA: _latA!,
        lonA: _lonA!,
        latB: _latB!,
        lonB: _lonB!,
        widthMeters: width,
        totalAreaHa: totalArea,
      );
      final id = await _repo.insertAbLine(line);
      if (mounted && id > 0) Navigator.of(context).pop(line.copyWith(id: id));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _totalAreaController.dispose();
    super.dispose();
  }

  double? get _lengthMeters {
    if (_latA == null || _latB == null) return null;
    return haversineDistanceMeters(_latA!, _lonA!, _latB!, _lonB!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Создание AB-линии', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black26,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_hasPermission)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: _checkPermission,
                    child: const Text('Разрешить геолокацию'),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _setPointA,
                      icon: const Icon(Icons.place),
                      label: Text(_latA != null ? 'Точка А ✓' : 'Точка А'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: _latA != null ? const Color(0xFF4CAF50) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading || _latA == null ? null : _setPointB,
                      icon: const Icon(Icons.place),
                      label: Text(_latB != null ? 'Точка Б ✓' : 'Точка Б'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: _latB != null ? const Color(0xFF4CAF50) : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (_latA != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _latB == null ? _reset : null,
                  child: const Text('Сбросить'),
                ),
              ],
              if (_latB != null) ...[
                if (_lengthMeters != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Длина линии: ${_lengthMeters!.toStringAsFixed(0)} м',
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название линии',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white12,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _widthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ширина междурядья (м)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white12,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _totalAreaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Площадь поля (га) — для % выполнения',
                    hintText: 'Необязательно',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white12,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: _loading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('СОХРАНИТЬ', style: TextStyle(fontSize: 18)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
