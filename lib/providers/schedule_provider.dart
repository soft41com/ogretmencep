import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../services/notification_service.dart';

class ScheduleProvider with ChangeNotifier {
  List<BellPeriodModel> _bellPeriods = [];
  List<TimetableEntryModel> _timetable = [];
  bool _isLoading = false;

  List<BellPeriodModel> get bellPeriods => _bellPeriods;
  List<TimetableEntryModel> get timetable => _timetable;
  bool get isLoading => _isLoading;

  Future<int> rescheduleNotifications() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings', limit: 1);
      if (res.isNotEmpty) {
        final settings = SettingsModel.fromMap(res.first);
        return await NotificationService.instance.scheduleLessonNotifications(
          timetable: _timetable,
          settings: settings,
        );
      }
    } catch (e) {
      debugPrint('Bildirimler yeniden planlanırken hata: $e');
    }
    return 0;
  }

  Future<void> fetchBellPeriods() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('bell_periods', orderBy: 'period_no ASC');
    _bellPeriods = res.map((r) => BellPeriodModel.fromMap(r)).toList();
    notifyListeners();
  }

  Future<void> updateBellPeriods(List<BellPeriodModel> periods) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (var p in periods) {
        await txn.update(
          'bell_periods',
          p.toMap(),
          where: 'id = ?',
          whereArgs: [p.id],
        );
      }
    });
    await fetchBellPeriods();
  }

  static const Map<int, List<String>> _defaultPeriodTimes = {
    1: ['08:40', '09:20'],
    2: ['09:30', '10:10'],
    3: ['10:20', '11:00'],
    4: ['11:10', '11:50'],
    5: ['12:40', '13:20'],
    6: ['13:30', '14:10'],
    7: ['14:20', '15:00'],
    8: ['15:10', '15:50'],
    9: ['16:00', '16:40'],
    10: ['16:50', '17:30'],
    11: ['17:40', '18:20'],
    12: ['18:30', '19:10'],
    13: ['19:20', '20:00'],
    14: ['20:10', '20:50'],
    15: ['21:00', '21:40'],
  };

  Future<void> syncBellPeriodsCount(int targetCount) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('bell_periods', orderBy: 'period_no ASC');
    final currentPeriods = res.map((r) => BellPeriodModel.fromMap(r)).toList();
    final existingPeriodNos = currentPeriods.map((p) => p.periodNo).toSet();

    await db.transaction((txn) async {
      // 1. targetCount'tan büyük periyotları ve bunlara ait dersleri sil
      await txn.delete(
        'timetable_entries',
        where: 'period_id IN (SELECT id FROM bell_periods WHERE period_no > ?)',
        whereArgs: [targetCount],
      );
      await txn.delete(
        'bell_periods',
        where: 'period_no > ?',
        whereArgs: [targetCount],
      );

      // 2. Eksik periyotları ekle (1..targetCount)
      for (int i = 1; i <= targetCount; i++) {
        if (!existingPeriodNos.contains(i)) {
          String start;
          String end;
          if (_defaultPeriodTimes.containsKey(i)) {
            start = _defaultPeriodTimes[i]![0];
            end = _defaultPeriodTimes[i]![1];
          } else {
            final prevEnd = _defaultPeriodTimes[12]![1];
            final parts = prevEnd.split(':').map(int.parse).toList();
            final baseMinutes = parts[0] * 60 + parts[1] + (i - 12) * 50;
            final sH = (baseMinutes ~/ 60) % 24;
            final sM = baseMinutes % 60;
            final eH = ((baseMinutes + 40) ~/ 60) % 24;
            final eM = (baseMinutes + 40) % 60;
            start = '${sH.toString().padLeft(2, '0')}:${sM.toString().padLeft(2, '0')}';
            end = '${eH.toString().padLeft(2, '0')}:${eM.toString().padLeft(2, '0')}';
          }

          await txn.insert('bell_periods', {
            'period_no': i,
            'start_time': start,
            'end_time': end,
            'label': '$i. Ders',
          });
        }
      }
    });

    await fetchBellPeriods();
    await fetchTimetable();
  }

  Future<void> fetchTimetable() async {
    _isLoading = true;
    notifyListeners();

    await fetchBellPeriods();
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT t.*, 
        c.name as class_name, 
        c.color as class_color,
        bp.label as period_label,
        bp.start_time,
        bp.end_time
      FROM timetable_entries t
      JOIN classes c ON c.id = t.class_id
      JOIN bell_periods bp ON bp.id = t.period_id
      WHERE c.deleted_at IS NULL
      ORDER BY t.weekday ASC, bp.period_no ASC
    ''');

    _timetable = res.map((r) => TimetableEntryModel.fromMap(r)).toList();
    _isLoading = false;
    notifyListeners();
    // Arka planda bildirimleri senkronize et
    rescheduleNotifications();
  }

  // Belirli bir günün dersleri (1: Pazartesi ... 5: Cuma)
  List<TimetableEntryModel> getDayEntries(int weekday) {
    return _timetable.where((t) => t.weekday == weekday).toList();
  }

  // Şu anki aktif ders veya sıradaki ders
  TimetableEntryModel? getCurrentOrNextClass({int maxDays = 5}) {
    final now = DateTime.now();
    final weekday = now.weekday; // 1: Mon ... 7: Sun
    if (weekday > maxDays) return null; // Belirlenen gün sayısı dışı

    final currentMinutes = now.hour * 60 + now.minute;
    final dayClasses = getDayEntries(weekday);

    for (var entry in dayClasses) {
      if (entry.startTime != null && entry.endTime != null) {
        final startParts = entry.startTime!.split(':').map(int.parse).toList();
        final endParts = entry.endTime!.split(':').map(int.parse).toList();

        final startMinutes = startParts[0] * 60 + startParts[1];
        final endMinutes = endParts[0] * 60 + endParts[1];

        // Şu anda bu dersteyiz
        if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
          return entry;
        }
        // Henüz başlamamış ilk ders
        if (currentMinutes < startMinutes) {
          return entry;
        }
      }
    }
    return null;
  }

  Future<bool> setTimetableCell({
    required int classId,
    required int periodId,
    required int weekday,
    required String subject,
    String? classroom,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    // Varsa sil, sonra ekle (upsert)
    await db.delete(
      'timetable_entries',
      where: 'period_id = ? AND weekday = ?',
      whereArgs: [periodId, weekday],
    );

    await db.insert('timetable_entries', {
      'class_id': classId,
      'period_id': periodId,
      'weekday': weekday,
      'subject': subject.trim(),
      'classroom': classroom?.trim(),
      'created_at': now,
    });

    await fetchTimetable();
    return true;
  }

  Future<bool> removeTimetableCell(int periodId, int weekday) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'timetable_entries',
      where: 'period_id = ? AND weekday = ?',
      whereArgs: [periodId, weekday],
    );

    await fetchTimetable();
    return true;
  }

  Future<bool> deleteTimetableCell(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'timetable_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    await fetchTimetable();
    return true;
  }

  Future<int> bulkSaveTimetable(List<Map<String, dynamic>> entries, {bool clearExisting = false}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    int count = 0;

    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete('timetable_entries');
      }

      for (var row in entries) {
        final classId = row['class_id'] as int?;
        final periodId = row['period_id'] as int?;
        final weekday = row['weekday'] as int?;
        final subject = row['subject'] as String?;

        if (classId != null && periodId != null && weekday != null && subject != null) {
          await txn.delete(
            'timetable_entries',
            where: 'period_id = ? AND weekday = ?',
            whereArgs: [periodId, weekday],
          );

          await txn.insert('timetable_entries', {
            'class_id': classId,
            'period_id': periodId,
            'weekday': weekday,
            'subject': subject.trim(),
            'classroom': row['classroom']?.toString().trim(),
            'created_at': now,
          });
          count++;
        }
      }
    });

    await fetchTimetable();
    return count;
  }
}
