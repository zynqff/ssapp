// Файл: test/unit_test.dart
// Запуск: flutter test
//
// Покрывает:
//  1. _shouldForceUpdate  — логика принудительного обновления
//  2. AppConfig.fromMap   — парсинг remote config
//  3. AppConfig.isUnderMaintenance — расчёт тех. перерыва
//  4. DatabaseService.migrateUsername — миграция SQLite при смене никнейма

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ssapp/models/app_config.dart';
import 'package:ssapp/services/database_service.dart';

// ─── Вспомогательная копия _shouldForceUpdate из main.dart ───────────────────
// Вынесена сюда, чтобы тестировать без запуска всего приложения.
// Если изменишь логику в main.dart — обнови и здесь.
bool shouldForceUpdate(String minVersion, {String currentVersion = '1.0.4'}) {
  if (minVersion == '0.0.0') return false;
  try {
    final min = minVersion.split('.').map(int.parse).toList();
    final cur = currentVersion.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final m = i < min.length ? min[i] : 0;
      final c = i < cur.length ? cur[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  } catch (_) {
    return false;
  }
}

void main() {
  // ── 1. shouldForceUpdate ────────────────────────────────────────────────────
  group('shouldForceUpdate', () {
    test('возвращает false если minVersion = 0.0.0 (отключено)', () {
      expect(shouldForceUpdate('0.0.0'), isFalse);
    });

    test('возвращает false если текущая версия выше минимальной', () {
      expect(shouldForceUpdate('1.0.3'), isFalse); // 1.0.4 > 1.0.3
    });

    test('возвращает false если версии одинаковые', () {
      expect(shouldForceUpdate('1.0.4'), isFalse);
    });

    test('возвращает true если текущая версия ниже минимальной (patch)', () {
      expect(shouldForceUpdate('1.0.5'), isTrue); // 1.0.4 < 1.0.5
    });

    test('возвращает true если текущая версия ниже минимальной (minor)', () {
      expect(shouldForceUpdate('1.1.0'), isTrue); // 1.0.4 < 1.1.0
    });

    test('возвращает true если текущая версия ниже минимальной (major)', () {
      expect(shouldForceUpdate('2.0.0'), isTrue); // 1.0.4 < 2.0.0
    });

    test('не падает на кривой строке версии', () {
      expect(() => shouldForceUpdate('not.a.version'), returnsNormally);
      expect(shouldForceUpdate('not.a.version'), isFalse);
    });
  });

  // ── 2. AppConfig.fromMap ────────────────────────────────────────────────────
  group('AppConfig.fromMap', () {
    test('дефолтные значения при пустой map', () {
      final config = AppConfig.fromMap({});
      expect(config.forceUpdateVersion, equals('0.0.0'));
      expect(config.registrationEnabled, isTrue);
      expect(config.aiEnabled, isTrue);
      expect(config.googleSigninEnabled, isTrue);
      expect(config.aiDailyLimit, equals(0));
      expect(config.bannerText, equals(''));
      expect(config.bannerColor, equals('info'));
      expect(config.maintenanceUntil, isNull);
    });

    test('парсит force_update_version', () {
      final config = AppConfig.fromMap({'force_update_version': '2.0.0'});
      expect(config.forceUpdateVersion, equals('2.0.0'));
    });

    test('регистрация выключена если registration_enabled = false', () {
      final config = AppConfig.fromMap({'registration_enabled': 'false'});
      expect(config.registrationEnabled, isFalse);
    });

    test('регистрация включена при любом другом значении', () {
      final config = AppConfig.fromMap({'registration_enabled': 'true'});
      expect(config.registrationEnabled, isTrue);
    });

    test('парсит ai_daily_limit как int', () {
      final config = AppConfig.fromMap({'ai_daily_limit': '10'});
      expect(config.aiDailyLimit, equals(10));
    });

    test('ai_daily_limit = 0 при некорректном значении', () {
      final config = AppConfig.fromMap({'ai_daily_limit': 'abc'});
      expect(config.aiDailyLimit, equals(0));
    });

    test('парсит maintenance_until как DateTime', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      final config = AppConfig.fromMap({
        'maintenance_until': future.toUtc().toIso8601String(),
      });
      expect(config.maintenanceUntil, isNotNull);
    });

    test('maintenance_until = null при пустой строке', () {
      final config = AppConfig.fromMap({'maintenance_until': ''});
      expect(config.maintenanceUntil, isNull);
    });
  });

  // ── 3. AppConfig.isUnderMaintenance ────────────────────────────────────────
  group('AppConfig.isUnderMaintenance', () {
    test('false если maintenanceUntil = null', () {
      expect(AppConfig.defaults().isUnderMaintenance, isFalse);
    });

    test('true если maintenanceUntil в будущем', () {
      final config = AppConfig(
        maintenanceUntil: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(config.isUnderMaintenance, isTrue);
    });

    test('false если maintenanceUntil в прошлом', () {
      final config = AppConfig(
        maintenanceUntil: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(config.isUnderMaintenance, isFalse);
    });

    test('maintenanceRemaining > 0 если тех. перерыв активен', () {
      final config = AppConfig(
        maintenanceUntil: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(config.maintenanceRemaining.inSeconds, greaterThan(0));
    });

    test('maintenanceRemaining = 0 если тех. перерыв прошёл', () {
      final config = AppConfig(
        maintenanceUntil: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(config.maintenanceRemaining, equals(Duration.zero));
    });
  });

  // ── 4. DatabaseService.migrateUsername ─────────────────────────────────────
  group('DatabaseService.migrateUsername', () {
    setUpAll(() {
      // Инициализируем sqflite для работы в тестовой среде (без Android)
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('переносит read_poems на новый username', () async {
      final db = DatabaseService();

      await db.setReadPoems('old_user', [1, 2, 3]);
      await db.migrateUsername('old_user', 'new_user');

      final newReads = await db.getReadPoems('new_user');
      expect(newReads, containsAll([1, 2, 3]));

      final oldReads = await db.getReadPoems('old_user');
      expect(oldReads, isEmpty);
    });

    test('переносит pinned_poem на новый username', () async {
      final db = DatabaseService();

      await db.togglePinnedPoem('old_user2', 42);
      await db.migrateUsername('old_user2', 'new_user2');

      final pinned = await db.getPinnedPoem('new_user2');
      expect(pinned, equals(42));

      final oldPinned = await db.getPinnedPoem('old_user2');
      expect(oldPinned, isNull);
    });

    test('не падает если у старого username нет данных', () async {
      final db = DatabaseService();
      expect(
        () => db.migrateUsername('ghost_user', 'new_user3'),
        returnsNormally,
      );
    });

    test('не дублирует данные при повторном вызове', () async {
      final db = DatabaseService();

      // Используем уникальные имена, не пересекающиеся с предыдущими тестами
      await db.setReadPoems('user_a2', [10, 20]);
      await db.migrateUsername('user_a2', 'user_b2');
      // Второй вызов не должен упасть и не должен задублировать
      await db.migrateUsername('user_a2', 'user_b2');

      final reads = await db.getReadPoems('user_b2');
      expect(reads.where((id) => id == 10).length, equals(1)); // без дублей
    });
  });
}
