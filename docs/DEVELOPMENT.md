# Процесс разработки Agrokilar

## Локальная разработка

### Окружение

1. Установите [Flutter](https://flutter.dev/docs/get-started/install)
2. Проверьте: `flutter doctor`
3. В корне проекта: `flutter pub get`

### Запуск

```bash
# По умолчанию (первое доступное устройство)
flutter run

# Конкретная платформа
flutter run -d chrome      # Web
flutter run -d windows     # Windows
flutter run -d android     # Android
```

### Демо без GPS

На главном экране включите переключатель «Демо» — симуляция движения по AB-линии. На web/десктопе можно включить «Клавиатура» и управлять стрелками или WASD (удержание = движение).

## Проверки перед PR

Перед отправкой изменений выполните:

```bash
flutter pub get
flutter analyze
flutter test
```

- **flutter analyze** — должен завершаться без ошибок
- **flutter test** — все тесты должны проходить

## Стиль кода

- Проект использует `flutter_lints` (см. `analysis_options.yaml`)
- Рекомендуется: комментарии на русском для публичных API и сложных участков
- Имена классов/файлов — на английском

## Структура при добавлении фич

| Что добавляете | Куда класть |
|---------------|-------------|
| Новый экран | `lib/screens/` |
| Переиспользуемый виджет | `lib/widgets/` |
| Сервис / бизнес-логика | `lib/services/` |
| Модель данных | `lib/models/` |
| Работа с БД | `lib/repository/`, `lib/database/` |
| Утилиты | `lib/utils/` |

## Тестирование

- Тесты в `test/`
- Сейчас: `widget_test.dart` — проверка запуска приложения и наличия кнопки «Новая линия»
- Для новых фич добавляйте unit- и widget-тесты

## Условная компиляция

При коде, зависящем от платформы:

- **БД**: `database_helper.dart` — `dart.library.io` → `database_helper_io.dart`, иначе `database_helper_web.dart`
- **Экспорт**: `export_service.dart` — выбор между `export_service_io.dart` и `export_service_web.dart` по платформе

Используйте `import '...' if (dart.library.io) '...';` для условных импортов.

## Типичные задачи

- **Новый экран**: создать в `screens/`, добавить маршрут в `MainScreen` или навигацию
- **Новая модель**: добавить в `models/`, таблицу в `database_helper_io.dart` и `database_helper_web.dart`
- **Изменение расчёта отклонения**: `lib/services/guidance_calculator.dart` и `lib/utils/ab_parallel_utils.dart`
