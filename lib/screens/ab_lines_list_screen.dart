import 'package:flutter/material.dart';
import '../models/ab_line.dart';
import '../repository/app_repository.dart';
import '../utils/geo_utils.dart';

class AbLinesListScreen extends StatefulWidget {
  final AbLine? selectedLine;
  final ValueChanged<AbLine>? onSelect;

  const AbLinesListScreen({super.key, this.selectedLine, this.onSelect});

  @override
  State<AbLinesListScreen> createState() => _AbLinesListScreenState();
}

class _AbLinesListScreenState extends State<AbLinesListScreen> {
  final _repo = AppRepository();
  List<AbLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAllAbLines();
    if (mounted) setState(() => _lines = list);
  }

  Future<void> _delete(AbLine line) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить линию?'),
        content: Text('Точно удалить «${line.name}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    if (confirm != true || line.id == null) return;
    await _repo.deleteAbLine(line.id!);
    _load();
  }

  void _edit(AbLine line) async {
    final nameController = TextEditingController(text: line.name);
    final widthController = TextEditingController(text: line.widthMeters.toString());
    final totalAreaController = TextEditingController(
      text: line.totalAreaHa != null ? line.totalAreaHa.toString() : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: widthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Ширина (м)'),
              ),
              TextField(
                controller: totalAreaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Площадь поля (га)',
                  hintText: 'Необязательно',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameController.text.trim();
    final width = double.tryParse(widthController.text.replaceAll(',', '.'));
    final totalArea = totalAreaController.text.trim().isEmpty
        ? null
        : double.tryParse(totalAreaController.text.replaceAll(',', '.'));
    if (name.isEmpty || width == null || width <= 0) return;
    if (totalArea != null && totalArea <= 0) return;
    await _repo.updateAbLine(line.copyWith(name: name, widthMeters: width, totalAreaHa: totalArea));
    _load();
  }

  double _lengthMeters(AbLine line) {
    return haversineDistanceMeters(line.latA, line.lonA, line.latB, line.lonB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Список линий', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black26,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _lines.isEmpty
          ? const Center(child: Text('Нет сохранённых линий', style: TextStyle(color: Colors.white70, fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lines.length,
              itemBuilder: (context, i) {
                final line = _lines[i];
                final len = _lengthMeters(line);
                final isSelected = widget.selectedLine?.id == line.id;
                return Card(
                  color: isSelected ? const Color(0xFF1B5E20).withValues(alpha: 0.3) : Colors.white12,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(line.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${line.widthMeters} м · ${len.toStringAsFixed(0)} м · ${_formatDate(line.createdAt)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      if (widget.onSelect != null) {
                        widget.onSelect!(line);
                        Navigator.pop(context);
                      }
                    },
                    onLongPress: () => _delete(line),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _edit(line),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
