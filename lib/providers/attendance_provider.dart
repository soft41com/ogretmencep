import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class AttendanceProvider with ChangeNotifier {
  Map<int, String> _statuses = {}; // studentId -> status (present, absent, late, excused, sick)
  Map<int, String> _notes = {}; // studentId -> note
  bool _isLoading = false;
  DateTime? _lastSavedAt;

  Map<int, String> get statuses => _statuses;
  Map<int, String> get notes => _notes;
  bool get isLoading => _isLoading;
  DateTime? get lastSavedAt => _lastSavedAt;

  Future<void> loadAttendance({
    required int classId,
    required String date,
    int? periodId,
  }) async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'attendances',
      where: 'class_id = ? AND date = ?${periodId != null ? " AND period_id = ?" : ""}',
      whereArgs: periodId != null ? [classId, date, periodId] : [classId, date],
    );

    _statuses = {};
    _notes = {};
    _lastSavedAt = null;

    for (var r in res) {
      final sId = r['student_id'] as int;
      _statuses[sId] = r['status'] as String;
      if (r['note'] != null) {
        _notes[sId] = r['note'] as String;
      }
      if (r['created_at'] != null) {
        try {
          final dt = DateTime.parse(r['created_at'] as String);
          if (_lastSavedAt == null || dt.isAfter(_lastSavedAt!)) {
            _lastSavedAt = dt;
          }
        } catch (_) {}
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void setStudentStatus(int studentId, String status) {
    _statuses[studentId] = status;
    notifyListeners();
  }

  void markAllPresent(List<StudentModel> studentList) {
    for (var s in studentList) {
      _statuses[s.id] = 'present';
    }
    notifyListeners();
  }

  Future<bool> saveAttendance({
    required int classId,
    required String date,
    int? periodId,
    required List<StudentModel> studentList,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (var s in studentList) {
        final st = _statuses[s.id] ?? 'present';
        final nt = _notes[s.id];

        // Varsa güncelle, yoksa ekle
        final existing = await txn.query(
          'attendances',
          where: 'student_id = ? AND date = ?${periodId != null ? " AND period_id = ?" : ""}',
          whereArgs: periodId != null ? [s.id, date, periodId] : [s.id, date],
        );

        if (existing.isNotEmpty) {
          await txn.update('attendances', {
            'status': st,
            'note': nt,
            'created_at': now,
          }, where: 'id = ?', whereArgs: [existing.first['id']]);
        } else {
          await txn.insert('attendances', {
            'student_id': s.id,
            'class_id': classId,
            'date': date,
            'period_id': periodId,
            'status': st,
            'note': nt,
            'created_at': now,
          });
        }
      }
    });

    _lastSavedAt = DateTime.parse(now);
    notifyListeners();

    return true;
  }
}
