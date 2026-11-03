import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class ClassesProvider with ChangeNotifier {
  List<ClassModel> _classes = [];
  bool _isLoading = false;

  List<ClassModel> get classes => _classes;
  bool get isLoading => _isLoading;

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT c.*, 
        (SELECT COUNT(*) FROM students s WHERE s.class_id = c.id AND s.deleted_at IS NULL) as student_count
      FROM classes c
      WHERE c.deleted_at IS NULL
      ORDER BY c.name ASC
    ''');

    _classes = res.map((row) {
      final count = (row['student_count'] as int?) ?? 0;
      return ClassModel.fromMap(row, studentCount: count);
    }).toList();

    _classes.sort((a, b) => compareClassNames(a.name, b.name));

    _isLoading = false;
    notifyListeners();
  }

  /// Sınıf adlarını doğal sayısal sıralamaya göre sıralar (Örn: 9-A, 10-A dan önce gelir)
  static int compareClassNames(String a, String b) {
    final regex = RegExp(r'(\d+)|(\D+)');
    final matchesA = regex.allMatches(a.trim()).map((m) => m.group(0)!).toList();
    final matchesB = regex.allMatches(b.trim()).map((m) => m.group(0)!).toList();

    final minLen = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
    for (int i = 0; i < minLen; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];

      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      if (numA != null && numB != null) {
        if (numA != numB) return numA.compareTo(numB);
      } else if (numA != null && numB == null) {
        return -1;
      } else if (numA == null && numB != null) {
        return 1;
      } else {
        final strCompare = partA.toLowerCase().compareTo(partB.toLowerCase());
        if (strCompare != 0) return strCompare;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  Future<ClassModel?> createClass({
    required String name,
    required String gradeLevel,
    String? subject,
    required String academicYear,
    String color = '#17433B',
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('classes', {
      'name': name.trim(),
      'grade_level': gradeLevel.trim(),
      'subject': subject?.trim().isNotEmpty == true ? subject!.trim() : null,
      'academic_year': academicYear,
      'color': color,
      'created_at': now,
    });

    await fetchClasses();
    return _classes.firstWhere((c) => c.id == id, orElse: () => ClassModel(
      id: id,
      name: name,
      gradeLevel: gradeLevel,
      subject: subject,
      academicYear: academicYear,
      color: color,
    ));
  }

  Future<bool> updateClass({
    required int id,
    required String name,
    required String gradeLevel,
    String? subject,
    String? color,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('classes', {
      'name': name.trim(),
      'grade_level': gradeLevel.trim(),
      'subject': subject?.trim().isNotEmpty == true ? subject!.trim() : null,
      if (color != null) 'color': color,
    }, where: 'id = ?', whereArgs: [id]);

    await fetchClasses();
    return true;
  }

  Future<bool> deleteClass(int id) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('classes', {'deleted_at': now}, where: 'id = ?', whereArgs: [id]);

    await fetchClasses();
    return true;
  }

  // Toplu Tüm Sınıfları ve Öğrencileri İçe Aktar (Excel / Matris)
  Future<Map<String, int>> bulkImportAllClassesAndStudents({
    required List<Map<String, dynamic>> classList,
    required String defaultAcademicYear,
    bool updateIfExists = true,
  }) async {
    final res = await DatabaseHelper.instance.bulkImportClassesWithStudents(
      classList: classList,
      defaultAcademicYear: defaultAcademicYear,
      updateIfExists: updateIfExists,
    );

    await fetchClasses();
    return res;
  }
}
