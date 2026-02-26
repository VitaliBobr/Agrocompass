import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/ab_line.dart';
import '../models/equipment_profile.dart';
import '../repository/app_repository.dart';
import '../services/guidance_calculator.dart';
import '../services/location_service.dart';
import '../services/track_recorder_service.dart';
import '../utils/format_utils.dart';
import '../widgets/big_deviation_number.dart';
import '../widgets/deviation_bar.dart';
import '../widgets/gps_status.dart';
import 'create_ab_line_screen.dart';
import 'ab_lines_list_screen.dart';
import 'work_history_screen.dart';
import '../widgets/maplibre_map_widget.dart';
import '../widgets/gnss_log_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ab_parallel_utils.dart';
import '../services/gap_overlap_detector.dart';
import '../services/demo_gnss_simulation.dart';
import '../services/export_service.dart';
import '../models/work_session.dart';
import '../utils/app_logger.dart';
import '../utils/geo_utils.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _repo = AppRepository();
  final _location = LocationService();
  final _tracker = TrackRecorderService();

  AbLine? _selectedLine;
  double? _deviationMeters;
  bool _hasGpsSignal = false;
  double? _accuracyMeters;
  double _heading = 0;
  double _speedKmh = 0;
  double _distanceKm = 0;
  double _areaHa = 0;
  double _accumulatedAreaHa = 0;
  bool _isRecording = false;
  bool _map3D = true;
  bool _follow = true;
  double? _workWidthMeters;
  bool _demoMode = false;
  bool _keyboardControl = false;
  int _passIndex = 0;
  int _lastAutoPassSwitchMs = 0;
  final DemoKeyState _demoKeys = DemoKeyState();
  StreamSubscription? _locationSub;
  StreamSubscription? _trackSub;
  StreamSubscription? _compassSub;
  GapOverlapStatus _gapOverlapStatus = GapOverlapStatus.ok;
  Timer? _gapOverlapTimer;
  late final FocusNode _focusNode = FocusNode();
  final GlobalKey _mapRepaintKey = GlobalKey();
  double? _draftLatA;
  double? _draftLonA;
  double? _draftLatB;
  double? _draftLonB;
  EquipmentProfile? _selectedEquipmentProfile;
  static const int _sectionCount = 5;
  List<bool> _sectionEnabled = List.filled(_sectionCount, true);
  bool _showTrack = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _tracker.setLocationService(_location);
    _loadSelectedLine();
    _loadSelectedEquipmentProfile();
    _loadSectionEnabled();
    _loadShowTrack();
    _requestLocationAndStart();
    _tracker.stateStream.listen(_onTrackState);
    _listenCompass();
  }

  static const _keySelectedAbLineId = 'selected_ab_line_id';
  static const _keyWorkingWidthMeters = 'working_width_meters';
  static const _keySelectedEquipmentProfileId = 'selected_equipment_profile_id';
  static const _keySectionEnabled = 'section_enabled';
  static const _keyShowTrack = 'show_track';

  Future<void> _loadShowTrack() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_keyShowTrack);
      if (v != null && mounted) setState(() => _showTrack = v);
    } catch (_) {}
  }

  Future<void> _saveShowTrack(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowTrack, value);
    } catch (_) {}
  }

  Future<void> _loadSectionEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_keySectionEnabled);
      if (s != null && s.length == _sectionCount && mounted) {
        final list = s.split('').map((c) => c == '1').toList();
        if (list.length == _sectionCount) setState(() => _sectionEnabled = list);
      }
    } catch (_) {}
  }

  Future<void> _saveSectionEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keySectionEnabled,
        _sectionEnabled.map((b) => b ? '1' : '0').join(),
      );
    } catch (_) {}
  }

  void _toggleSection(int index) {
    if (index < 0 || index >= _sectionCount) return;
    setState(() {
      _sectionEnabled = List<bool>.from(_sectionEnabled);
      _sectionEnabled[index] = !_sectionEnabled[index];
    });
    _saveSectionEnabled();
  }

  Future<void> _loadSelectedEquipmentProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_keySelectedEquipmentProfileId);
      if (id != null && mounted) {
        final profile = EquipmentProfile.findById(id);
        if (profile != null) setState(() => _selectedEquipmentProfile = profile);
      }
      if (_selectedEquipmentProfile == null && mounted) {
        setState(() => _selectedEquipmentProfile = EquipmentProfile.farmer());
      }
    } catch (_) {}
  }

  Future<void> _saveSelectedEquipmentProfile(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedEquipmentProfileId, id);
    } catch (_) {}
  }

  void _showEquipmentPicker() {
    final profiles = EquipmentProfile.builtInList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Выберите агрегат', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            ...profiles.map((p) {
              final isSelected = _selectedEquipmentProfile?.id == p.id;
              return ListTile(
                leading: Icon(Icons.agriculture, color: isSelected ? const Color(0xFF4CAF50) : Colors.white70),
                title: Text(p.name, style: TextStyle(color: isSelected ? const Color(0xFF4CAF50) : Colors.white)),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF4CAF50)) : null,
                onTap: () {
                  setState(() => _selectedEquipmentProfile = p);
                  _saveSelectedEquipmentProfile(p.id);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showFieldPicker() async {
    final lines = await _repo.getAllAbLines();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Выберите поле', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Нет сохранённых полей. Создайте AB-линию через «Новая линия».', style: TextStyle(color: Colors.white70)),
              )
            else
              ...lines.map((line) {
                final isSelected = _selectedLine?.id == line.id;
                return ListTile(
                  leading: Icon(Icons.map, color: isSelected ? const Color(0xFF4CAF50) : Colors.white70),
                  title: Text(line.name, style: TextStyle(color: isSelected ? const Color(0xFF4CAF50) : Colors.white)),
                  subtitle: Text('${line.widthMeters.toStringAsFixed(1)} м', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF4CAF50)) : null,
                  onTap: () {
                    _selectLine(line);
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSelectedLine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_keySelectedAbLineId);
      final savedWidth = prefs.getDouble(_keyWorkingWidthMeters);
      if (savedWidth != null && savedWidth > 0) {
        _workWidthMeters = savedWidth;
        _tracker.setWorkingWidthMeters(savedWidth);
      }
      if (id != null) {
        final line = await _repo.getAbLineById(id);
        if (line != null && mounted) {
          setState(() => _selectedLine = line);
          _tracker.setAbLine(line);
          _reloadAccumulatedAreaHa();
          if (_workWidthMeters == null || _workWidthMeters! <= 0) {
            _workWidthMeters = line.widthMeters;
            _tracker.setWorkingWidthMeters(line.widthMeters);
          }
        } else if (mounted) {
          await prefs.remove(_keySelectedAbLineId);
          setState(() => _selectedLine = null);
          _tracker.setAbLine(null);
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Линия не найдена'),
                content: const Text(
                  'Выбранная линия не найдена. Выберите другую.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AbLinesListScreen(
                            selectedLine: null,
                            onSelect: _selectLine,
                          ),
                        ),
                      );
                    },
                    child: const Text('Выбрать линию'),
                  ),
                ],
              ),
            );
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSelectedLine(int? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_keySelectedAbLineId);
      } else {
        await prefs.setInt(_keySelectedAbLineId, id);
      }
    } catch (_) {}
  }

  Future<void> _saveWorkingWidth(double? width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (width == null || width <= 0) {
        await prefs.remove(_keyWorkingWidthMeters);
      } else {
        await prefs.setDouble(_keyWorkingWidthMeters, width);
      }
    } catch (_) {}
  }

  Future<void> _requestLocationAndStart() async {
    _locationSub?.cancel();
    if (_demoMode) {
      _location.setDemoPath(
        _selectedLine?.latA, _selectedLine?.lonA,
        _selectedLine?.latB, _selectedLine?.lonB,
      );
      _location.setDemoMode(true);
      _location.startPositionUpdates();
      _locationSub = _location.positionStream.listen(
        _onPositionUpdate,
        onError: (_) {
          if (mounted) setState(() => _hasGpsSignal = false);
        },
      );
      if (mounted) setState(() => _hasGpsSignal = true);
      return;
    }
    final ok = await _location.checkAndRequestPermission();
    if (!ok && mounted) {
      setState(() => _hasGpsSignal = false);
      return;
    }
    _location.setDemoMode(false);
    _location.startPositionUpdates();
    _locationSub = _location.positionStream.listen(
      _onPositionUpdate,
      onError: (_) {
        if (mounted) setState(() => _hasGpsSignal = false);
      },
    );
  }

  void _onPositionUpdate(PositionUpdate pos) {
    if (!mounted) return;
    final selectedLine = _selectedLine;
    final heading = pos.heading;
    final width = _workWidthMeters ?? selectedLine?.widthMeters;
    final canUseAutoPass = selectedLine != null && width != null && width > 0.2;

    int? nextAutoPassIndex;
    if (canUseAutoPass) {
      final baseDeviation = deviationFromAbLineMeters(
        latA: selectedLine!.latA,
        lonA: selectedLine.lonA,
        latB: selectedLine.latB,
        lonB: selectedLine.lonB,
        lat: pos.latitude,
        lon: pos.longitude,
        // Для авто-переключения фиксируем систему координат A->B,
        // чтобы выбор ближайшей параллели не "переворачивался" при разворотах.
        directionAtoB: true,
      );
      final candidate = (baseDeviation / width).round().clamp(-200, 200);
      final currentResidual = (baseDeviation - (_passIndex * width)).abs();
      final candidateResidual = (baseDeviation - (candidate * width)).abs();
      final hysteresis = (width * 0.15).clamp(0.2, 0.8);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cooldownPassed = nowMs - _lastAutoPassSwitchMs >= 700;
      if (candidate != _passIndex &&
          cooldownPassed &&
          candidateResidual + hysteresis < currentResidual) {
        nextAutoPassIndex = candidate;
        _lastAutoPassSwitchMs = nowMs;
      }
    }

    setState(() {
      if (nextAutoPassIndex != null) {
        _passIndex = nextAutoPassIndex!;
      }
      _hasGpsSignal = true;
      _accuracyMeters = pos.accuracyMeters;
      _speedKmh = pos.speedKmh;
      if (selectedLine != null && heading != null) {
        final shifted = offsetAbSegment(
          latA: selectedLine.latA,
          lonA: selectedLine.lonA,
          latB: selectedLine.latB,
          lonB: selectedLine.lonB,
          offsetMeters: _passIndex * selectedLine.widthMeters,
        );
        _deviationMeters = GuidanceCalculator.deviationMeters(
          latA: shifted.latA,
          lonA: shifted.lonA,
          latB: shifted.latB,
          lonB: shifted.lonB,
          lat: pos.latitude,
          lon: pos.longitude,
          bearingDeg: heading,
        );
      }
    });
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _keyboardControl) {
      _demoKeys.forward = _demoKeys.back = _demoKeys.left = _demoKeys.right = false;
      _location.updateDemoKeyState(_demoKeys);
    }
  }

  void _toggleKeyboardControl(bool value) {
    if (!_demoMode) return;
    setState(() => _keyboardControl = value);
    _location.setDemoManualMode(value);
    if (!value) {
      _location.updateDemoKeyState(DemoKeyState());
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_demoMode || !_keyboardControl) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;
    final isArrowUp = key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW;
    final isArrowDown = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS;
    final isArrowLeft = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA;
    final isArrowRight = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD;
    if (isArrowUp && (isDown || isUp)) _demoKeys.forward = isDown;
    if (isArrowDown && (isDown || isUp)) _demoKeys.back = isDown;
    if (isArrowLeft && (isDown || isUp)) _demoKeys.left = isDown;
    if (isArrowRight && (isDown || isUp)) _demoKeys.right = isDown;
    if (isArrowUp || isArrowDown || isArrowLeft || isArrowRight) {
      _location.updateDemoKeyState(_demoKeys);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleDemo(bool value) {
    _locationSub?.cancel();
    setState(() {
      _demoMode = value;
      if (!value) _keyboardControl = false;
    });
    _location.setDemoMode(value);
    _location.setDemoManualMode(value && _keyboardControl);
    if (!value) _location.updateDemoKeyState(DemoKeyState());
    if (value) {
      _location.setDemoPath(
        _selectedLine?.latA, _selectedLine?.lonA,
        _selectedLine?.latB, _selectedLine?.lonB,
      );
      _location.startPositionUpdates();
      _locationSub = _location.positionStream.listen(_onPositionUpdate);
      setState(() => _hasGpsSignal = true);
    } else {
      _requestLocationAndStart();
    }
  }

  void _onTrackState(TrackRecordingState s) {
    if (!mounted) return;
    final wasRecording = _isRecording;
    setState(() {
      _isRecording = s.isRecording;
      _distanceKm = s.distanceKm;
      _areaHa = s.areaHa;
    });
    if (s.isRecording) {
      _gapOverlapTimer?.cancel();
      _gapOverlapTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkGapOverlap());
    } else {
      _gapOverlapTimer?.cancel();
      _gapOverlapTimer = null;
      setState(() => _gapOverlapStatus = GapOverlapStatus.ok);
      if (wasRecording) {
        _reloadAccumulatedAreaHa();
      }
    }
  }

  void _setWorkingWidth(double width) {
    final normalized = double.parse(width.toStringAsFixed(2));
    setState(() => _workWidthMeters = normalized);
    _tracker.setWorkingWidthMeters(normalized);
    _saveWorkingWidth(normalized);
  }

  Future<void> _reloadAccumulatedAreaHa() async {
    final sessions = await _repo.getAllWorkSessions();
    final selectedId = _selectedLine?.id;
    final relevant = selectedId == null
        ? sessions
        : sessions.where((s) => s.abLineId == selectedId);
    final sum = relevant.fold<double>(0.0, (acc, s) => acc + s.areaHa);
    if (!mounted) return;
    setState(() => _accumulatedAreaHa = sum);
  }

  void _setPointAOnMain() {
    final pos = _location.lastPositionUpdate;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет текущих координат для точки A')),
      );
      return;
    }
    setState(() {
      _draftLatA = pos.latitude;
      _draftLonA = pos.longitude;
      _draftLatB = null;
      _draftLonB = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Точка A сохранена')),
    );
  }

  Future<void> _setPointBOnMain() async {
    if (_draftLatA == null || _draftLonA == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала задайте точку A')),
      );
      return;
    }
    final pos = _location.lastPositionUpdate;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет текущих координат для точки B')),
      );
      return;
    }
    setState(() {
      _draftLatB = pos.latitude;
      _draftLonB = pos.longitude;
    });
    await _showCreateLineDialogFromMain();
  }

  void _resetDraftPoints() {
    setState(() {
      _draftLatA = null;
      _draftLonA = null;
      _draftLatB = null;
      _draftLonB = null;
    });
  }

  Future<void> _showCreateLineDialogFromMain() async {
    if (_draftLatA == null || _draftLonA == null || _draftLatB == null || _draftLonB == null) {
      return;
    }
    final nameCtrl = TextEditingController();
    final widthCtrl = TextEditingController(
      text: (_workWidthMeters ?? _selectedLine?.widthMeters ?? 2.0).toStringAsFixed(2),
    );
    final created = await showDialog<AbLine>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить AB-линию'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название линии',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widthCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Ширина захвата (м)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final width = double.tryParse(widthCtrl.text.trim().replaceAll(',', '.'));
              if (name.isEmpty || width == null || width <= 0) return;
              final line = AbLine(
                name: name,
                createdAt: DateTime.now(),
                latA: _draftLatA!,
                lonA: _draftLonA!,
                latB: _draftLatB!,
                lonB: _draftLonB!,
                widthMeters: width,
              );
              final id = await _repo.insertAbLine(line);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, line.copyWith(id: id));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (created != null) {
      _selectLine(created);
      _setWorkingWidth(created.widthMeters);
      _resetDraftPoints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AB-линия создана и выбрана')),
        );
      }
    }
  }

  Future<void> _showWorkingWidthDialog() async {
    final initial = (_workWidthMeters ?? _selectedLine?.widthMeters ?? 2.0).toStringAsFixed(2);
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ширина захвата'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Ширина штанги/агрегата (м)',
            hintText: 'Например, 3.5',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (parsed == null || parsed <= 0 || parsed > 40) return;
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null) {
      _setWorkingWidth(result);
    }
  }

  void _onStartStopPressed() {
    if (_isRecording) {
      _tracker.stopRecording();
      return;
    }
    final width = _workWidthMeters;
    if (width == null || width <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Перед стартом задайте ширину захвата')),
      );
      return;
    }
    _tracker.setAbLine(_selectedLine);
    _tracker.setWorkingWidthMeters(width);
    _tracker.startRecording();
  }

  Future<void> _checkGapOverlap() async {
    if (!_isRecording || _selectedLine == null) return;
    final pos = _location.lastPositionUpdate;
    if (pos == null) return;
    final pts = await _tracker.getCurrentTrackPoints();
    if (!mounted) return;
    final status = GapOverlapDetector.detect(
      trackPoints: pts,
      lat: pos.latitude,
      lon: pos.longitude,
      widthMeters: _workWidthMeters ?? _selectedLine!.widthMeters,
    );
    if (mounted && _gapOverlapStatus != status) {
      setState(() => _gapOverlapStatus = status);
    }
  }

  void _listenCompass() {
    final events = FlutterCompass.events;
    if (events == null) return;
    _compassSub = events.listen((e) {
      if (!mounted) return;
      final h = e.heading;
      if (h != null && h.isFinite) setState(() => _heading = h);
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _locationSub?.cancel();
    _trackSub?.cancel();
    _compassSub?.cancel();
    _gapOverlapTimer?.cancel();
    _location.stopPositionUpdates();
    _tracker.dispose();
    super.dispose();
  }

  void _selectLine(AbLine line) {
    setState(() {
      _selectedLine = line;
      _workWidthMeters ??= line.widthMeters;
    });
    _tracker.setAbLine(line);
    if (_workWidthMeters != null && _workWidthMeters! > 0) {
      _tracker.setWorkingWidthMeters(_workWidthMeters!);
    }
    _saveSelectedLine(line.id);
    _reloadAccumulatedAreaHa();
  }

  double get _displayAreaHa => _accumulatedAreaHa + _areaHa;

  @override
  Widget build(BuildContext context) {
    final showNoGpsOverlay = !_hasGpsSignal && !_demoMode;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
            // Верх: GPS, название линии, Демо, время
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GpsStatus(
                    hasSignal: _hasGpsSignal,
                    accuracyMeters: _accuracyMeters,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedLine != null
                          ? '${_selectedLine!.name} (${(_workWidthMeters ?? _selectedLine!.widthMeters).toStringAsFixed(1)} м)'
                          : '—',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Демо', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Switch(
                        value: _demoMode,
                        onChanged: _toggleDemo,
                      ),
                      if (_demoMode) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '↑↓←→ или WASD. Удержание — движение пока нажато',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Клавиатура', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Switch(
                                value: _keyboardControl,
                                onChanged: _toggleKeyboardControl,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _timeNow(),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            // Кнопки: Новая линия, Выбрать, GNSS лог
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilledButton.icon(
                      onPressed: _hasGpsSignal || _demoMode
                          ? () async {
                              final line = await Navigator.push<AbLine>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateAbLineScreen(
                                    locationService: _location,
                                  ),
                                ),
                              );
                              if (line != null) _selectLine(line);
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Новая линия'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AbLinesListScreen(
                              selectedLine: _selectedLine,
                              onSelect: _selectLine,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('Выбрать'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.icon(
                      onPressed: _showFieldPicker,
                      icon: const Icon(Icons.terrain),
                      label: const Text('Поле'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
                    ),
                  ),
                ),
                Tooltip(
                  message: _selectedEquipmentProfile?.name ?? 'Сменить агрегат',
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: FilledButton.icon(
                      onPressed: _showEquipmentPicker,
                      icon: const Icon(Icons.agriculture),
                      label: const Text('Агрегат'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF455A64),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showShareMenu(context),
                  icon: const Icon(Icons.share),
                  tooltip: 'Поделиться',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white70,
                    backgroundColor: Colors.white12,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => GnssLogSheet.show(
                      context,
                      _location.gnssLogEntries,
                      _demoMode,
                    ),
                    icon: const Icon(Icons.article_outlined),
                    tooltip: 'Журнал GPS',
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white70,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_hasGpsSignal || _demoMode) ? _setPointAOnMain : null,
                      icon: const Icon(Icons.looks_one),
                      label: Text(_draftLatA != null ? 'Точка A ✓' : 'Точка A'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _draftLatA != null ? const Color(0xFF4CAF50) : const Color(0xFF455A64),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_hasGpsSignal || _demoMode) ? _setPointBOnMain : null,
                      icon: const Icon(Icons.looks_two),
                      label: Text(_draftLatB != null ? 'Точка B ✓' : 'Точка B'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _draftLatB != null ? const Color(0xFF4CAF50) : const Color(0xFF455A64),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (_draftLatA != null || _draftLatB != null) ? _resetDraftPoints : null,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Сбросить точки A/B',
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white70,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Карта
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  MapLibreMapWidget(
                    hasGpsSignal: _hasGpsSignal || _demoMode,
                    abLine: _selectedLine,
                    trackRecorder: _tracker,
                    locationService: _location,
                    headingDegrees: _heading,
                    speedKmh: _speedKmh,
                    is3D: _map3D,
                    follow: _follow,
                    passIndex: _passIndex,
                    gapOverlapStatus: _gapOverlapStatus,
                    repaintBoundaryKey: _mapRepaintKey,
                    staticTrackWidthMeters: _workWidthMeters,
                    equipmentProfile: _selectedEquipmentProfile ?? EquipmentProfile.farmer(),
                    sectionEnabled: _sectionEnabled,
                    showTrack: _showTrack,
                  ),
                  Positioned(
                    left: 8,
                    bottom: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Трек', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 24,
                                child: Switch(
                                  value: _showTrack,
                                  onChanged: (v) {
                                    setState(() => _showTrack = v);
                                    _saveShowTrack(v);
                                  },
                                  activeColor: const Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Секции:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 6),
                          ...List.generate(_sectionCount, (i) {
                            final on = _sectionEnabled[i];
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Material(
                                color: on ? const Color(0xFF4CAF50) : Colors.grey.shade700,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => _toggleSection(i),
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _passIndex -= 1),
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          tooltip: 'Проход влево',
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _passIndex == 0 ? 'Полоса' : 'Проход',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _passIndex == 0 ? 'AB' : (_passIndex > 0 ? '+$_passIndex' : '$_passIndex'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => setState(() => _passIndex += 1),
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          tooltip: 'Проход вправо',
                        ),
                        FilledButton(
                          onPressed: () => setState(() => _map3D = !_map3D),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            _map3D ? '3D' : '2D',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() => _follow = !_follow),
                          icon: Icon(
                            _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          tooltip: _follow
                              ? 'Следовать: карта поворачивается по курсу (техника вверх)'
                              : 'Следовать за трактором',
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_heading.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isRecording && _gapOverlapStatus != GapOverlapStatus.ok)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _gapOverlapStatus == GapOverlapStatus.gap
                        ? Colors.red.withValues(alpha: 0.8)
                        : Colors.amber.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _gapOverlapStatus == GapOverlapStatus.gap
                            ? Icons.warning_amber
                            : Icons.warning,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _gapOverlapStatus == GapOverlapStatus.gap
                            ? 'Внимание: пропуск!'
                            : 'Перекрытие!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Шкала отклонения и большое число
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  BigDeviationNumber(
                    deviationMeters: _deviationMeters,
                    hasSignal: _hasGpsSignal && _selectedLine != null,
                  ),
                  const SizedBox(height: 8),
                  DeviationBar(
                    deviationMeters: _deviationMeters ?? 0,
                    maxDeviation: 1.0,
                  ),
                  if (_selectedLine?.totalAreaHa != null &&
                      _selectedLine!.totalAreaHa! > 0) ...[
                    const SizedBox(height: 12),
                    _PercentProgress(
                      areaHa: _displayAreaHa,
                      totalAreaHa: _selectedLine!.totalAreaHa!,
                    ),
                  ],
                ],
              ),
            ),
            // Низ: ПУТЬ (км), ОБРАБОТАНО (га), СТАРТ, СКОРОСТЬ (км/ч)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatDistanceKm(_distanceKm)} км',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('ПУТЬ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatAreaHa(_displayAreaHa)} га',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('ОБРАБОТАНО', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      FilledButton.icon(
                    onPressed: (_hasGpsSignal || _demoMode)
                        ? _onStartStopPressed
                        : null,
                    icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow, size: 28),
                    label: Text(_isRecording ? 'СТОП' : 'СТАРТ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                      if (_isRecording)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _RecordingIndicator(),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _showWorkingWidthDialog,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    ),
                    child: Text(
                      _workWidthMeters == null
                          ? 'Ширина'
                          : '${_workWidthMeters!.toStringAsFixed(1)} м',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_speedKmh.toStringAsFixed(1)} км/ч',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('СКОРОСТЬ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
          // ТЗ 3.4: при отсутствии GPS — показать на весь экран «НЕТ СИГНАЛА GPS»
          if (showNoGpsOverlay)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1A1A),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gps_off, size: 80, color: Colors.red.shade700),
                          const SizedBox(height: 24),
                          const Text(
                            'НЕТ СИГНАЛА GPS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Разрешите доступ к геолокации\nдля работы курсоуказателя',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () async {
                              final opened = await _location.openAppSettings();
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('На Web откройте настройки геолокации в браузере (значок замка в адресной строке).'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Настройки'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => _toggleDemo(true),
                            icon: const Icon(Icons.preview, color: Colors.white70),
                            label: const Text('Режим демо (без GPS)', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: showNoGpsOverlay ? null : BottomNavigationBar(
        backgroundColor: Colors.black26,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Работа'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'История'),
        ],
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkHistoryScreen()));
        },
      ),
    ),
    );
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  /// ТЗ 10.1: Поделиться — экспорт трека GPX/CSV/KML
  Future<void> _showShareMenu(BuildContext context) async {
    var session = _tracker.state.currentSession;
    if (session == null) {
      final sessions = await _repo.getAllWorkSessions();
      if (sessions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет треков для экспорта')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      session = sessions.first;
    }
    if (session.abLineName == null && session.abLineId != null && context.mounted) {
      final ab = await _repo.getAbLineById(session.abLineId!);
      if (ab != null) {
        session = session.copyWith(abLineName: ab.name);
      }
    }
    if (context.mounted) _showShareMenuForSession(context, session);
  }

  Future<void> _showShareMenuForSession(BuildContext context, WorkSession s) async {
    if (s.id == null) return;
    final points = await _repo.getTrackPointsBySessionId(s.id!);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Поделиться треком', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.white70),
              title: const Text('GPX', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportGpx(s, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.white70),
              title: const Text('CSV', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportCsv(s, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.terrain, color: Colors.white70),
              title: const Text('KML', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.exportKml(s, points);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white70),
              title: const Text('Снимок карты', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await _captureAndShareMapImage(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// P1: Захват карты через RepaintBoundary и экспорт.
  Future<void> _captureAndShareMapImage(BuildContext context) async {
    final boundary = _mapRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Карта недоступна для снимка')),
        );
      }
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Не удалось создать изображение');
      final bytes = byteData.buffer.asUint8List();
      await ExportService.shareMapImage(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Снимок карты готов к отправке')),
        );
      }
    } catch (e, st) {
      AppLogger.warn('map.snapshot.main', 'Failed to capture/share map image', error: e, stackTrace: st);
      final msg = e.toString().trim().isEmpty || e.toString() == 'null'
          ? 'Неизвестная ошибка'
          : e.toString();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка снимка: $msg')),
        );
      }
    }
  }
}

/// Мигающая красная точка при активной записи трека (ТЗ 2.1.E).
class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        );
      },
    );
  }
}

/// ТЗ 2.1.I: Процент выполнения при известной площади поля.
class _PercentProgress extends StatelessWidget {
  final double areaHa;
  final double totalAreaHa;

  const _PercentProgress({
    required this.areaHa,
    required this.totalAreaHa,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalAreaHa > 0 ? (areaHa / totalAreaHa * 100).clamp(0.0, 100.0) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          minHeight: 8,
        ),
      ],
    );
  }
}
