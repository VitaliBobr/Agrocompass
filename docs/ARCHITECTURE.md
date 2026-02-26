# Архитектура приложения Agrokilar

## Обзор

Agrokilar — Flutter-приложение по слоям:

```
┌─────────────────────────────────────────────────────────────────┐
│  UI (screens, widgets)                                           │
├─────────────────────────────────────────────────────────────────┤
│  Services (location, track_recorder, guidance, export)           │
├─────────────────────────────────────────────────────────────────┤
│  Repository (app_repository)                                     │
├─────────────────────────────────────────────────────────────────┤
│  Database (SQLite / in-memory)  │  Models (AbLine, WorkSession…)  │
└─────────────────────────────────────────────────────────────────┘
```

## Слои

### 1. UI — Screens и Widgets

| Компонент | Назначение |
|-----------|------------|
| `MainScreen` | Главный экран: карта, шкала отклонения, кнопки, запись трека, демо |
| `CreateAbLineScreen` | Создание AB-линии (точки А, Б, название, ширина) |
| `AbLinesListScreen` | Список линий, выбор, редактирование, удаление |
| `WorkHistoryScreen` | История сессий, экспорт |
| `MapLibreMapWidget` | Карта: AB-линия, трек-полоса, позиция, 2D/3D, follow |
| `DeviationBar` | Шкала отклонения (влево/вправо) |
| `BigDeviationNumber` | Большое число отклонения в метрах |
| `GpsStatus` | Точность GPS, индикатор сигнала |

### 2. Services — Бизнес-логика

| Сервис | Назначение |
|--------|------------|
| `LocationService` | GPS-поток, демо-режим, GNSS-лог, права доступа |
| `TrackRecorderService` | Запись трека, путь (км), площадь (га), сохранение в БД |
| `GuidanceCalculator` | Расчёт отклонения от AB-линии (метры, знак) |
| `GapOverlapDetector` | Детекция пропусков и перекрытий между проходами |
| `ExportService` | Экспорт GPX, CSV, KML (поделиться) |
| `DemoGnssSimulation` | Симуляция движения A→B→A, управление клавиатурой |

### 3. Repository

`AppRepository` — обёртка над БД. Методы: `getAllAbLines`, `getAbLineById`, `insertAbLine`, `updateAbLine`, `deleteAbLine`, `getAllWorkSessions`, `getTrackPointsBySessionId`, `insertTrackPoints` и т.д.

### 4. Database и Models

- **Database**: условный импорт — `database_helper_io.dart` (SQLite) на VM, `database_helper_web.dart` (in-memory) на web.
- **Export**: `export_service_io.dart` на VM, `export_service_web.dart` на web (для обхода ограничений `path_provider` на web).

**Модели:**

| Модель | Поля |
|--------|------|
| `AbLine` | id, name, createdAt, latA, lonA, latB, lonB, widthMeters, totalAreaHa |
| `WorkSession` | id, abLineId, startTime, endTime, distanceKm, areaHa, abLineName |
| `TrackPoint` | id, sessionId, latitude, longitude, timestamp, speedKmh, heading, deviationMeters |

## Потоки данных

### Главный экран

```
LocationService.positionStream
    → MainScreen._onPositionUpdate
    → отклонение (GuidanceCalculator.deviationMeters)
    → BigDeviationNumber, DeviationBar

LocationService.positionStream
    → TrackRecorderService._onPosition
    → путь, площадь, сохранение TrackPoint
    → MainScreen._onTrackState (distanceKm, areaHa)

SharedPreferences
    → _loadSelectedLine
    → AppRepository.getAbLineById
    → _selectedLine, _tracker.setAbLine
```

### Создание AB-линии

```
CreateAbLineScreen
    → LocationService.lastPositionUpdate / Geolocator.getCurrentPosition
    → точки А, Б
    → AppRepository.insertAbLine
    → Navigator.pop(line)
```

### Экспорт

```
WorkHistoryScreen / MainScreen._showShareMenu
    → AppRepository.getTrackPointsBySessionId
    → ExportService.exportGpx / exportCsv / exportKml
    → share_plus
```

### Демо-режим

```
MainScreen: _demoMode == true
    → LocationService.setDemoMode(true)
    → LocationService.setDemoPath(latA, lonA, latB, lonB)
    → DemoGnssSimulation.startDemo
    → positionStream (симуляция 10 Гц)

Клавиатура (WASD / стрелки):
    → _handleKeyEvent
    → DemoKeyState (forward, back, left, right)
    → LocationService.updateDemoKeyState
    → DemoGnssSimulation (ручное движение)
```

## Условная компиляция

| Файл | VM (mobile, desktop) | Web |
|------|----------------------|-----|
| `database_helper.dart` | `database_helper_io.dart` (SQLite) | `database_helper_web.dart` (in-memory) |
| `export_service.dart` | `export_service_web.dart` (XFile.fromData) | `export_service_io.dart` (File + path_provider) |

*Примечание: в `export_service.dart` при `dart.library.io` используется web-реализация; при её отсутствии — io. При сбоях «Поделиться» на web проверить порядок экспорта.*

## Схема экранов

```
MainScreen (home)
├── CreateAbLineScreen (при нажатии «Новая линия»)
├── AbLinesListScreen (при нажатии «Выбрать»)
├── WorkHistoryScreen (нижняя навигация «История»)
├── GnssLogSheet (модальное окно «GNSS лог»)
└── Export bottom sheet (поделиться)
```
