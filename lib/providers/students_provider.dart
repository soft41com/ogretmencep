import 'dart:math';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../services/turkish_search_helper.dart';

class StudentsProvider with ChangeNotifier {
  List<StudentModel> _students = [];
  bool _isLoading = false;

  List<StudentModel> get students => _students;
  bool get isLoading => _isLoading;

  Future<void> fetchStudents(int classId) async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT s.*, 
        COALESCE((SELECT SUM(value) FROM student_evaluations e WHERE e.student_id = s.id), 0) as total_score,
        COALESCE((SELECT COUNT(*) FROM student_notes n WHERE n.student_id = s.id), 0) as note_count
      FROM students s
      WHERE s.class_id = ? AND s.deleted_at IS NULL
      ORDER BY CAST(s.student_no AS INTEGER) ASC, s.first_name ASC
    ''', [classId]);

    _students = res.map((row) {
      final score = (row['total_score'] as num?)?.toInt() ?? 0;
      final notes = (row['note_count'] as num?)?.toInt() ?? 0;
      return StudentModel.fromMap(row, totalScore: score, noteCount: notes);
    }).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createStudent({
    required int classId,
    required String studentNo,
    required String firstName,
    required String lastName,
    String gender = 'M',
    String? photoPath,
    String? birthDate,
    String? guardianName,
    String? guardianPhone,
    String? healthNote,
    String? club,
    String? bloodType,
    String? address,
    String? specialNotes,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('students', {
      'class_id': classId,
      'student_no': studentNo.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'gender': gender,
      'photo_path': photoPath,
      'birth_date': birthDate,
      'guardian_name': guardianName?.trim(),
      'guardian_phone': guardianPhone?.trim(),
      'health_note': healthNote?.trim(),
      'club': club?.trim(),
      'blood_type': bloodType?.trim(),
      'address': address?.trim(),
      'special_notes': specialNotes?.trim(),
      'created_at': now,
    });

    await fetchStudents(classId);
    return true;
  }

  Future<bool> updateStudent({
    required int id,
    required int classId,
    required String studentNo,
    required String firstName,
    required String lastName,
    required String gender,
    String? photoPath,
    String? birthDate,
    String? guardianName,
    String? guardianPhone,
    String? healthNote,
    String? club,
    String? bloodType,
    String? address,
    String? specialNotes,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('students', {
      'student_no': studentNo.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'gender': gender,
      if (photoPath != null) 'photo_path': photoPath,
      if (birthDate != null) 'birth_date': birthDate,
      'guardian_name': guardianName?.trim(),
      'guardian_phone': guardianPhone?.trim(),
      'health_note': healthNote?.trim(),
      'club': club?.trim(),
      'blood_type': bloodType?.trim(),
      'address': address?.trim(),
      'special_notes': specialNotes?.trim(),
    }, where: 'id = ?', whereArgs: [id]);

    await fetchStudents(classId);
    return true;
  }

  static const List<String> defaultClubs = [
    'Kızılay Kulübü',
    'Yeşilay Kulübü',
    'Beyazay Kulübü',
    'Siberay Kulübü',
    'Tarih ve Kültürel Miras Kulübü',
    'Tabiat ve Yaşanabilir Çevre Kulübü',
    'Sağlıklı Yaşam ve Fiziksel Aktivite Kulübü',
    'Yaşam Becerileri Kulübü',
  ];

  /// Sistemde herhangi bir öğrenciye tanımlanmış tüm benzersiz kulüpler
  Future<List<String>> fetchDistinctClubs() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT DISTINCT club FROM students 
      WHERE club IS NOT NULL AND TRIM(club) != '' AND deleted_at IS NULL
      ORDER BY club ASC
    ''');
    return res
        .map((r) => (r['club'] as String).trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  /// Varsayılan kulüpler + şu an aktif olarak en az bir öğrencinin kaydında bulunan kulüpler
  Future<List<String>> getAvailableClubs() async {
    final usedClubs = await fetchDistinctClubs();
    final Set<String> clubSet = {...defaultClubs};
    for (final c in usedClubs) {
      if (!clubSet.contains(c)) {
        clubSet.add(c);
      }
    }
    return clubSet.toList();
  }

  Future<bool> updatePhoto(int studentId, int classId, String photoPath) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('students', {'photo_path': photoPath}, where: 'id = ?', whereArgs: [studentId]);
    await fetchStudents(classId);
    return true;
  }

  Future<bool> removePhoto(int studentId, int classId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('students', {'photo_path': null}, where: 'id = ?', whereArgs: [studentId]);
    await fetchStudents(classId);
    return true;
  }

  Future<int> bulkUpdatePhotos(int classId, Map<int, String> studentIdToPhotoPath) async {
    if (studentIdToPhotoPath.isEmpty) return 0;
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final entry in studentIdToPhotoPath.entries) {
      batch.update(
        'students',
        {'photo_path': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
    await fetchStudents(classId);
    return studentIdToPhotoPath.length;
  }

  Future<bool> deleteStudent(int id, int classId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('students', {'deleted_at': now}, where: 'id = ?', whereArgs: [id]);

    await fetchStudents(classId);
    return true;
  }

  // Değerlendirme (+1 / -1)
  Future<bool> giveEvaluation({
    required int studentId,
    required int classId,
    required int value,
    String category = 'participation',
    String? note,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('student_evaluations', {
      'student_id': studentId,
      'class_id': classId,
      'value': value,
      'category': category,
      'note': note?.trim(),
      'created_at': now,
    });

    // Optimistic / update memory list
    final idx = _students.indexWhere((s) => s.id == studentId);
    if (idx != -1) {
      final cur = _students[idx];
      _students[idx] = cur.copyWith(totalScore: cur.totalScore + value);
      notifyListeners();
    }

    return true;
  }

  // Kim Kalksın? (Rastgele Öğrenci Seçimi)
  StudentModel? getRandomStudent() {
    if (_students.isEmpty) return null;
    final rand = Random();
    return _students[rand.nextInt(_students.length)];
  }

  // Öğrenci Akışı (Timeline)
  Future<List<EvaluationModel>> fetchStudentEvaluations(int studentId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'student_evaluations',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
    return res.map((r) => EvaluationModel.fromMap(r)).toList();
  }

  Future<bool> deleteEvaluation({
    required int evaluationId,
    required int studentId,
    required int value,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('student_evaluations', where: 'id = ?', whereArgs: [evaluationId]);

    final idx = _students.indexWhere((s) => s.id == studentId);
    if (idx != -1) {
      final cur = _students[idx];
      _students[idx] = cur.copyWith(totalScore: cur.totalScore - value);
      notifyListeners();
    }
    return true;
  }

  Future<List<StudentNoteModel>> fetchStudentNotes(int studentId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'student_notes',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
    );
    return res.map((r) => StudentNoteModel.fromMap(r)).toList();
  }

  Future<bool> addStudentNote({
    required int studentId,
    required String type,
    required String body,
    String? tags,
    bool isPrivate = true,
    String? followUpAt,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('student_notes', {
      'student_id': studentId,
      'type': type,
      'body': body.trim(),
      'tags': tags,
      'is_private': isPrivate ? 1 : 0,
      'follow_up_at': followUpAt,
      'created_at': now,
    });
    return true;
  }

  Future<bool> deleteStudentNote(int noteId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('student_notes', where: 'id = ?', whereArgs: [noteId]);
    return true;
  }

  // Toplu Öğrenci İçe Aktarma (Excel / e-Okul / Panodan Yapıştırma)
  Future<Map<String, int>> bulkImportStudents({
    required int classId,
    required List<Map<String, dynamic>> studentList,
    bool updateIfExists = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    int createdCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;

    await db.transaction((txn) async {
      for (var row in studentList) {
        final no = row['student_no']?.toString().trim();
        final first = row['first_name']?.toString().trim();
        final last = row['last_name']?.toString().trim();

        if (no == null || no.isEmpty || first == null || first.isEmpty) {
          skippedCount++;
          continue;
        }

        // Mevcut öğrenci kontrolü
        final existing = await txn.query(
          'students',
          where: 'class_id = ? AND student_no = ? AND deleted_at IS NULL',
          whereArgs: [classId, no],
          limit: 1,
        );

        final data = {
          'class_id': classId,
          'student_no': no,
          'first_name': first,
          'last_name': last ?? '',
          'gender': (row['gender']?.toString().toUpperCase() == 'K' || row['gender']?.toString().toUpperCase() == 'F') ? 'F' : 'M',
          'guardian_name': row['guardian_name']?.toString().trim(),
          'guardian_phone': row['guardian_phone']?.toString().trim(),
          'health_note': row['health_note']?.toString().trim(),
        };

        if (existing.isNotEmpty) {
          if (updateIfExists) {
            await txn.update('students', data, where: 'id = ?', whereArgs: [existing.first['id']]);
            updatedCount++;
          } else {
            skippedCount++;
          }
        } else {
          data['created_at'] = now;
          await txn.insert('students', data);
          createdCount++;
        }
      }
    });

    await fetchStudents(classId);
    return {
      'created': createdCount,
      'updated': updatedCount,
      'skipped': skippedCount,
    };
  }

  /// Tüm sınıflarda ad, soyad, okul no, veli veya kulübe göre öğrenci arar (Türkçe karakter duyarlı)
  Future<List<StudentModel>> searchAllStudents(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final db = await DatabaseHelper.instance.database;

    final res = await db.rawQuery('''
      SELECT s.*, c.name as class_name, c.subject as class_subject,
        COALESCE((SELECT SUM(value) FROM student_evaluations e WHERE e.student_id = s.id), 0) as total_score
      FROM students s
      JOIN classes c ON c.id = s.class_id
      WHERE s.deleted_at IS NULL AND c.deleted_at IS NULL
      ORDER BY c.name ASC, CAST(s.student_no AS INTEGER) ASC
    ''');

    final q = TurkishSearchHelper.toLower(clean);

    final allStudents = res.map((row) {
      final score = (row['total_score'] as int?) ?? 0;
      return StudentModel.fromMap(row, totalScore: score);
    });

    return allStudents.where((s) {
      final fullName = TurkishSearchHelper.toLower('${s.firstName} ${s.lastName}');
      final firstName = TurkishSearchHelper.toLower(s.firstName);
      final lastName = TurkishSearchHelper.toLower(s.lastName);
      final studentNo = s.studentNo;
      final guardianName = TurkishSearchHelper.toLower(s.guardianName ?? '');
      final guardianPhone = s.guardianPhone ?? '';
      final club = TurkishSearchHelper.toLower(s.club ?? '');
      final healthNote = TurkishSearchHelper.toLower(s.healthNote ?? '');

      return fullName.contains(q) ||
          firstName.contains(q) ||
          lastName.contains(q) ||
          studentNo.contains(q) ||
          guardianName.contains(q) ||
          guardianPhone.contains(q) ||
          club.contains(q) ||
          healthNote.contains(q);
    }).take(30).toList();
  }

  /// Öğrencinin sınıfına ait tüm sınav ve değerlendirme notlarını çeker
  Future<List<Map<String, dynamic>>> fetchStudentExamDetails(int studentId, int classId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT e.id as exam_id, e.title, e.type, e.exam_date, e.weight, e.max_score,
             es.score,
             COALESCE((SELECT AVG(score) FROM exam_scores WHERE exam_id = e.id AND score > 0), 0.0) as class_average
      FROM exams e
      LEFT JOIN exam_scores es ON es.exam_id = e.id AND es.student_id = ?
      WHERE e.class_id = ?
      ORDER BY e.exam_date ASC, e.id ASC
    ''', [studentId, classId]);
    return res;
  }

  /// Öğrencinin devamsızlık özetini çeker
  Future<Map<String, int>> fetchStudentAttendanceSummary(int studentId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM attendances
      WHERE student_id = ?
      GROUP BY status
    ''', [studentId]);

    final Map<String, int> summary = {
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
    };
    for (var r in res) {
      final st = r['status'] as String?;
      final count = (r['count'] as int?) ?? 0;
      if (st != null && summary.containsKey(st)) {
        summary[st] = count;
      }
    }
    return summary;
  }
}
