import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class ExamsProvider with ChangeNotifier {
  List<ExamModel> _exams = [];
  Map<int, double> _examScores = {}; // studentId -> score
  bool _isLoading = false;

  List<ExamModel> get exams => _exams;
  Map<int, double> get examScores => _examScores;
  bool get isLoading => _isLoading;

  Future<void> fetchExams({int? classId}) async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final whereClause = classId != null ? 'WHERE e.class_id = $classId' : '';
    final res = await db.rawQuery('''
      SELECT e.*, c.name as class_name, c.subject as subject,
        COALESCE((SELECT AVG(score) FROM exam_scores es WHERE es.exam_id = e.id), 0.0) as average_score
      FROM exams e
      JOIN classes c ON c.id = e.class_id
      $whereClause
      ORDER BY e.exam_date ASC, e.id ASC
    ''');

    _exams = res.map((r) {
      final avg = (r['average_score'] as num?)?.toDouble() ?? 0.0;
      return ExamModel.fromMap(r, averageScore: avg);
    }).toList();

    _isLoading = false;
    notifyListeners();
  }

  /// Bir sınıfa ait tüm sınavların öğrenci notlarını topluca çeker (examId -> {studentId: score})
  Future<Map<int, Map<int, double>>> loadClassAllScores(int classId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT es.exam_id, es.student_id, es.score
      FROM exam_scores es
      JOIN exams e ON e.id = es.exam_id
      WHERE e.class_id = ?
    ''', [classId]);

    final Map<int, Map<int, double>> result = {};
    for (final r in res) {
      final eId = r['exam_id'] as int;
      final sId = r['student_id'] as int;
      final sc = (r['score'] as num?)?.toDouble() ?? 0.0;
      result.putIfAbsent(eId, () => {})[sId] = sc;
    }
    return result;
  }

  Future<ExamModel> createExam({
    required int classId,
    required String title,
    String type = 'written',
    required String examDate,
    double weight = 100.0,
    double maxScore = 100.0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('exams', {
      'class_id': classId,
      'title': title.trim(),
      'type': type,
      'exam_date': examDate,
      'weight': weight,
      'max_score': maxScore,
      'created_at': now,
    });

    await fetchExams();
    return _exams.firstWhere((e) => e.id == id);
  }

  Future<bool> deleteExam(int examId, {int? classId}) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('exams', where: 'id = ?', whereArgs: [examId]);
    await fetchExams();
    return true;
  }

  Future<void> loadExamScores(int examId) async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final res = await db.query('exam_scores', where: 'exam_id = ?', whereArgs: [examId]);

    _examScores = {};
    for (var r in res) {
      final sId = r['student_id'] as int;
      _examScores[sId] = (r['score'] as num?)?.toDouble() ?? 0.0;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setStudentScore(int studentId, double score) {
    _examScores[studentId] = score;
    notifyListeners();
  }

  Future<DateTime?> getExamLastSavedAt(int examId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT MAX(created_at) as last_saved FROM exam_scores WHERE exam_id = ?
    ''', [examId]);
    if (res.isNotEmpty && res.first['last_saved'] != null) {
      final str = res.first['last_saved'] as String;
      return DateTime.tryParse(str);
    }
    return null;
  }

  Future<bool> saveExamScores(int examId, [Map<int, double>? customScores]) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final scoresToSave = customScores ?? _examScores;

    await db.transaction((txn) async {
      for (var entry in scoresToSave.entries) {
        if (entry.value > 0) {
          await txn.rawInsert('''
            INSERT INTO exam_scores (exam_id, student_id, score, created_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(exam_id, student_id) DO UPDATE SET score = ?, created_at = ?
          ''', [examId, entry.key, entry.value, now, entry.value, now]);
        } else {
          await txn.delete('exam_scores', where: 'exam_id = ? AND student_id = ?', whereArgs: [examId, entry.key]);
        }
      }
    });

    await fetchExams();
    return true;
  }
}
