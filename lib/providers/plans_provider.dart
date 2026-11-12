import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class PlansProvider with ChangeNotifier {
  List<LessonPlanModel> _plans = [];
  Map<int, LessonPlanModel> _nextPlansByClassId = {};
  bool _isLoading = false;
  int? _activeClassId;

  List<LessonPlanModel> get plans => _plans;
  Map<int, LessonPlanModel> get nextPlansByClassId => _nextPlansByClassId;
  bool get isLoading => _isLoading;
  int? get activeClassId => _activeClassId;

  /// Her sınıf için sıradaki (pending durumundaki veya ilk sıradaki) planı çeker
  Future<void> loadNextPlans() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.rawQuery('''
        SELECT * FROM lesson_plans
        ORDER BY 
          CASE WHEN status = 'pending' THEN 0 ELSE 1 END ASC,
          week_no ASC,
          id ASC
      ''');

      final Map<int, LessonPlanModel> map = {};
      for (final r in res) {
        final cid = r['class_id'] as int?;
        if (cid != null && !map.containsKey(cid)) {
          map[cid] = LessonPlanModel.fromMap(r);
        }
      }
      _nextPlansByClassId = map;
      notifyListeners();
    } catch (e) {
      debugPrint('PlansProvider loadNextPlans error: $e');
    }
  }

  Future<void> fetchPlans({int? classId}) async {
    _isLoading = true;
    _activeClassId = classId;
    notifyListeners();

    if (classId == null) {
      _plans = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'lesson_plans',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'week_no ASC',
    );

    _plans = res.map((r) => LessonPlanModel.fromMap(r)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> togglePlanStatus(int planId) async {
    final idx = _plans.indexWhere((p) => p.id == planId);
    if (idx == -1) return;

    final cur = _plans[idx];
    final nextStatus = cur.status == 'completed' ? 'pending' : 'completed';

    final db = await DatabaseHelper.instance.database;
    await db.update('lesson_plans', {'status': nextStatus}, where: 'id = ?', whereArgs: [planId]);

    _plans[idx] = LessonPlanModel(
      id: cur.id,
      classId: cur.classId,
      weekNo: cur.weekNo,
      term: cur.term,
      subject: cur.subject,
      topic: cur.topic,
      learningOutcomes: cur.learningOutcomes,
      activities: cur.activities,
      status: nextStatus,
    );
    notifyListeners();
    await loadNextPlans();
  }

  Future<void> addPlan({
    required int classId,
    required int weekNo,
    required int term,
    required String subject,
    required String topic,
    String? learningOutcomes,
    String? activities,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('lesson_plans', {
      'class_id': classId,
      'week_no': weekNo,
      'term': term,
      'subject': subject.trim().isEmpty ? 'Ders' : subject.trim(),
      'topic': topic.trim(),
      'learning_outcomes': learningOutcomes?.trim(),
      'activities': activities?.trim(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    await fetchPlans(classId: classId);
    await loadNextPlans();
  }

  Future<void> updatePlan({
    required int id,
    required int weekNo,
    required int term,
    required String subject,
    required String topic,
    String? learningOutcomes,
    String? activities,
    String? status,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final Map<String, dynamic> data = {
      'week_no': weekNo,
      'term': term,
      'subject': subject.trim().isEmpty ? 'Ders' : subject.trim(),
      'topic': topic.trim(),
      'learning_outcomes': learningOutcomes?.trim(),
      'activities': activities?.trim(),
    };
    if (status != null) {
      data['status'] = status;
    }

    await db.update('lesson_plans', data, where: 'id = ?', whereArgs: [id]);
    await fetchPlans(classId: _activeClassId);
    await loadNextPlans();
  }

  Future<void> deletePlan(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('lesson_plans', where: 'id = ?', whereArgs: [id]);
    await fetchPlans(classId: _activeClassId);
    await loadNextPlans();
  }

  Future<void> clearPlansForClass(int classId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('lesson_plans', where: 'class_id = ?', whereArgs: [classId]);
    await fetchPlans(classId: classId);
    await loadNextPlans();
  }

  Future<int> bulkImportPlans({
    required int classId,
    required String subject,
    required List<Map<String, dynamic>> items,
    bool replaceExisting = true,
  }) async {
    if (items.isEmpty) return 0;

    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();

    if (replaceExisting) {
      batch.delete('lesson_plans', where: 'class_id = ?', whereArgs: [classId]);
    }

    final now = DateTime.now().toIso8601String();
    for (var item in items) {
      final weekNo = item['week_no'] is int
          ? item['week_no'] as int
          : (int.tryParse(item['week_no']?.toString() ?? '') ?? 1);

      final term = item['term'] is int
          ? item['term'] as int
          : (int.tryParse(item['term']?.toString() ?? '') ?? (weekNo > 18 ? 2 : 1));

      batch.insert('lesson_plans', {
        'class_id': classId,
        'week_no': weekNo,
        'term': term,
        'subject': subject.trim().isNotEmpty ? subject.trim() : (item['subject'] ?? 'Ders'),
        'topic': (item['topic']?.toString() ?? '').trim(),
        'learning_outcomes': item['learning_outcomes']?.toString().trim(),
        'activities': item['activities']?.toString().trim(),
        'status': item['status']?.toString() ?? 'pending',
        'created_at': now,
      });
    }

    await batch.commit(noResult: true);
    await fetchPlans(classId: classId);
    await loadNextPlans();
    return items.length;
  }

  Future<void> copyPlansFrom({
    required int sourceClassId,
    required int targetClassId,
    required String subject,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final sourcePlans = await db.query(
      'lesson_plans',
      where: 'class_id = ?',
      whereArgs: [sourceClassId],
      orderBy: 'week_no ASC',
    );

    if (sourcePlans.isEmpty) return;

    final batch = db.batch();
    batch.delete('lesson_plans', where: 'class_id = ?', whereArgs: [targetClassId]);

    final now = DateTime.now().toIso8601String();
    for (var p in sourcePlans) {
      batch.insert('lesson_plans', {
        'class_id': targetClassId,
        'week_no': p['week_no'],
        'term': p['term'],
        'subject': subject.trim().isNotEmpty ? subject.trim() : p['subject'],
        'topic': p['topic'],
        'learning_outcomes': p['learning_outcomes'],
        'activities': p['activities'],
        'status': 'pending',
        'created_at': now,
      });
    }

    await batch.commit(noResult: true);
    await fetchPlans(classId: targetClassId);
    await loadNextPlans();
  }
}
