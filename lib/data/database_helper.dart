import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_data_seeder.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ogretmencep.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final legacyFile = File(join(dbPath, 'ogretmen_yardimcisi.db'));
    final targetFile = File(join(dbPath, filePath));
    if (await legacyFile.exists() && !await targetFile.exists()) {
      try {
        await legacyFile.copy(targetFile.path);
      } catch (_) {}
    }

    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureTeacherSubjectsTable(db);
        await _ensureStudentColumns(db);
        await _ensureSettingsColumns(db);
        await _ensureCleanOnboardingData(db);
      },
      onConfigure: _onConfigure,
    );
  }

  Future<void> _ensureCleanOnboardingData(Database db) async {
    try {
      final settingsRes = await db.query('settings', limit: 1);
      if (settingsRes.isNotEmpty) {
        final isOnboardingCompleted = settingsRes.first['is_onboarding_completed'] == 1;
        if (!isOnboardingCompleted) {
          final schoolName = settingsRes.first['school_name']?.toString() ?? '';
          // Eğer kurulum tamamlanmamış ve varsayılan test verisi duruyorsa temizle
          if (schoolName == 'Atatürk Anadolu Lisesi' || schoolName.isEmpty) {
            final classCountRes = await db.rawQuery("SELECT COUNT(*) as cnt FROM classes WHERE name IN ('9-A', '10-B')");
            final cnt = (classCountRes.first['cnt'] as int?) ?? 0;
            if (cnt > 0) {
              await db.transaction((txn) async {
                await txn.delete('student_evaluations');
                await txn.delete('student_notes');
                await txn.delete('attendances');
                await txn.delete('exam_scores');
                await txn.delete('exams');
                await txn.delete('students');
                await txn.delete('lesson_plans');
                await txn.delete('timetable_entries');
                await txn.delete('classes');
                await txn.delete('teacher_subjects');
                await txn.update('settings', {
                  'teacher_name': '',
                  'school_name': '',
                  'branch': '',
                  'updated_at': DateTime.now().toIso8601String(),
                });
              });
            }
          }
          final currentAy = settingsRes.first['academic_year']?.toString();
          if (currentAy == null || currentAy.isEmpty || currentAy == '2024-2025') {
            await db.update('settings', {
              'academic_year': defaultAcademicYear,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureSettingsColumns(Database db) async {
    final columnsInfo = await db.rawQuery('PRAGMA table_info(settings)');
    final existingColumns = columnsInfo.map((c) => c['name'] as String).toSet();

    if (!existingColumns.contains('timetable_days')) {
      await db.execute('ALTER TABLE settings ADD COLUMN timetable_days INTEGER NOT NULL DEFAULT 5');
    }
    if (!existingColumns.contains('daily_periods_count')) {
      await db.execute('ALTER TABLE settings ADD COLUMN daily_periods_count INTEGER NOT NULL DEFAULT 8');
    }
    if (!existingColumns.contains('is_onboarding_completed')) {
      await db.execute('ALTER TABLE settings ADD COLUMN is_onboarding_completed INTEGER NOT NULL DEFAULT 0');
    }
    if (!existingColumns.contains('lesson_notify_enabled')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lesson_notify_enabled INTEGER NOT NULL DEFAULT 1');
    }
    if (!existingColumns.contains('lesson_start_notify_enabled')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lesson_start_notify_enabled INTEGER NOT NULL DEFAULT 1');
    }
    if (!existingColumns.contains('lesson_start_minutes')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lesson_start_minutes INTEGER NOT NULL DEFAULT 5');
    }
    if (!existingColumns.contains('lesson_end_notify_enabled')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lesson_end_notify_enabled INTEGER NOT NULL DEFAULT 1');
    }
    if (!existingColumns.contains('lesson_end_minutes')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lesson_end_minutes INTEGER NOT NULL DEFAULT 5');
    }
    if (!existingColumns.contains('lesson_notify_type')) {
      await db.execute("ALTER TABLE settings ADD COLUMN lesson_notify_type TEXT NOT NULL DEFAULT 'both'");
    }
  }

  Future<void> _ensureStudentColumns(Database db) async {
    final columnsInfo = await db.rawQuery('PRAGMA table_info(students)');
    final existingColumns = columnsInfo.map((c) => c['name'] as String).toSet();

    if (!existingColumns.contains('club')) {
      await db.execute('ALTER TABLE students ADD COLUMN club TEXT');
    }
    if (!existingColumns.contains('blood_type')) {
      await db.execute('ALTER TABLE students ADD COLUMN blood_type TEXT');
    }
    if (!existingColumns.contains('address')) {
      await db.execute('ALTER TABLE students ADD COLUMN address TEXT');
    }
    if (!existingColumns.contains('special_notes')) {
      await db.execute('ALTER TABLE students ADD COLUMN special_notes TEXT');
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _ensureTeacherSubjectsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    // Otomatik varsayılan ders ekleme kaldırıldı. Kullanıcı sihirbaz veya ayarlardan ekleyecektir.
  }

  /// Dinamik varsayılan eğitim öğretim yılı (içinde bulunulan yıl ve sonraki yıl, örn: 2026-2027)
  static String get defaultAcademicYear {
    final year = DateTime.now().year;
    return '$year-${year + 1}';
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Ayarlar & Öğretmen Profili
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_name TEXT NOT NULL DEFAULT 'Öğretmen',
        school_name TEXT NOT NULL DEFAULT '',
        branch TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL,
        theme_mode TEXT NOT NULL DEFAULT 'system',
        timetable_days INTEGER NOT NULL DEFAULT 5,
        daily_periods_count INTEGER NOT NULL DEFAULT 8,
        is_onboarding_completed INTEGER NOT NULL DEFAULT 0,
        lesson_notify_enabled INTEGER NOT NULL DEFAULT 1,
        lesson_start_notify_enabled INTEGER NOT NULL DEFAULT 1,
        lesson_start_minutes INTEGER NOT NULL DEFAULT 5,
        lesson_end_notify_enabled INTEGER NOT NULL DEFAULT 1,
        lesson_end_minutes INTEGER NOT NULL DEFAULT 5,
        lesson_notify_type TEXT NOT NULL DEFAULT 'both',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Zil Saatleri (Ders Periyotları)
    await db.execute('''
      CREATE TABLE bell_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_no INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        label TEXT NOT NULL
      )
    ''');

    // 3. Sınıflar
    await db.execute('''
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        grade_level TEXT NOT NULL,
        subject TEXT,
        academic_year TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#17433B',
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // 4. Öğrenciler
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        student_no TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        gender TEXT NOT NULL DEFAULT 'M',
        photo_path TEXT,
        birth_date TEXT,
        guardian_name TEXT,
        guardian_phone TEXT,
        health_note TEXT,
        club TEXT,
        blood_type TEXT,
        address TEXT,
        special_notes TEXT,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // 5. Değerlendirmeler (+ / - Puanlar)
    await db.execute('''
      CREATE TABLE student_evaluations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        value INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'participation',
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // 6. Öğrenci Notları (Gözlem, Veli, Davranış vb.)
    await db.execute('''
      CREATE TABLE student_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'observation',
        body TEXT NOT NULL,
        tags TEXT,
        is_private INTEGER NOT NULL DEFAULT 1,
        follow_up_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // 7. Yoklama Kayıtları
    await db.execute('''
      CREATE TABLE attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        period_id INTEGER,
        status TEXT NOT NULL DEFAULT 'present',
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        FOREIGN KEY (period_id) REFERENCES bell_periods (id) ON DELETE SET NULL
      )
    ''');

    // 8. Haftalık Ders Programı (Timetable)
    await db.execute('''
      CREATE TABLE timetable_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        period_id INTEGER NOT NULL,
        weekday INTEGER NOT NULL,
        subject TEXT NOT NULL,
        classroom TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        FOREIGN KEY (period_id) REFERENCES bell_periods (id) ON DELETE CASCADE
      )
    ''');

    // 9. Sınavlar
    await db.execute('''
      CREATE TABLE exams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'written',
        exam_date TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 100.0,
        max_score REAL NOT NULL DEFAULT 100.0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // 10. Sınav Notları
    await db.execute('''
      CREATE TABLE exam_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exam_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        score REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        UNIQUE(exam_id, student_id),
        FOREIGN KEY (exam_id) REFERENCES exams (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // 11. Yıllık Ders Planları
    await db.execute('''
      CREATE TABLE lesson_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER,
        week_no INTEGER NOT NULL,
        term INTEGER NOT NULL DEFAULT 1,
        subject TEXT NOT NULL,
        topic TEXT NOT NULL,
        learning_outcomes TEXT,
        activities TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE SET NULL
      )
    ''');

    // Varsayılan verileri yükle
    await _seedDefaults(db);
  }

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Boş Başlangıç Ayarları
    await db.insert('settings', {
      'teacher_name': '',
      'school_name': '',
      'branch': '',
      'academic_year': defaultAcademicYear,
      'theme_mode': 'system',
      'timetable_days': 5,
      'daily_periods_count': 8,
      'is_onboarding_completed': 0,
      'created_at': now,
      'updated_at': now,
    });

    // 2. Varsayılan 8 Ders Zil Saatleri Şablonu
    final defaultPeriods = [
      {'period_no': 1, 'start_time': '08:40', 'end_time': '09:20', 'label': '1. Ders'},
      {'period_no': 2, 'start_time': '09:30', 'end_time': '10:10', 'label': '2. Ders'},
      {'period_no': 3, 'start_time': '10:20', 'end_time': '11:00', 'label': '3. Ders'},
      {'period_no': 4, 'start_time': '11:10', 'end_time': '11:50', 'label': '4. Ders'},
      {'period_no': 5, 'start_time': '12:40', 'end_time': '13:20', 'label': '5. Ders'},
      {'period_no': 6, 'start_time': '13:30', 'end_time': '14:10', 'label': '6. Ders'},
      {'period_no': 7, 'start_time': '14:20', 'end_time': '15:00', 'label': '7. Ders'},
      {'period_no': 8, 'start_time': '15:10', 'end_time': '15:50', 'label': '8. Ders'},
    ];
    for (var p in defaultPeriods) {
      await db.insert('bell_periods', p);
    }
    // Sınıf veya ders tanımı ilk kurulum esnasında yapılmaz. Kullanıcı kurulum sihirbazında kendisi oluşturur.
  }

  // Öğretmenin Girdiği Dersler Yönetimi
  Future<List<String>> getTeacherSubjects() async {
    final db = await database;
    await _ensureTeacherSubjectsTable(db);
    final res = await db.query('teacher_subjects', orderBy: 'id ASC');
    return res.map((r) => r['name'] as String).toList();
  }

  Future<bool> addTeacherSubject(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;
    final db = await database;
    await _ensureTeacherSubjectsTable(db);
    await db.insert(
      'teacher_subjects',
      {'name': clean, 'created_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return true;
  }

  Future<bool> deleteTeacherSubject(String name) async {
    final db = await database;
    await db.delete('teacher_subjects', where: 'name = ?', whereArgs: [name.trim()]);
    return true;
  }

  // Toplu Sınıf ve Öğrenci İçe Aktarma (Excel Matrisi)
  Future<Map<String, int>> bulkImportClassesWithStudents({
    required List<Map<String, dynamic>> classList,
    required String defaultAcademicYear,
    bool updateIfExists = true,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    int classesCreated = 0;
    int studentsCreated = 0;
    int studentsUpdated = 0;

    await db.transaction((txn) async {
      final palette = [
        '#17433B',
        '#1F8A5B',
        '#2563EB',
        '#7C3AED',
        '#E11D48',
        '#D97706',
        '#064E3B',
        '#475569'
      ];
      int colorIdx = 0;

      for (var clsData in classList) {
        final className = clsData['class_name']?.toString().trim();
        if (className == null || className.isEmpty) continue;

        final gradeLevel = clsData['grade_level']?.toString().trim() ??
            (RegExp(r'\d+').firstMatch(className)?.group(0) ?? '9');
        final subject = clsData['subject']?.toString().trim();
        final academicYear = (clsData['academic_year']?.toString().trim().isNotEmpty == true)
            ? clsData['academic_year'].toString().trim()
            : defaultAcademicYear;

        // Sınıf var mı kontrolü
        final existingClasses = await txn.query(
          'classes',
          where: 'LOWER(name) = ? AND deleted_at IS NULL',
          whereArgs: [className.toLowerCase()],
          limit: 1,
        );

        int classId;
        if (existingClasses.isNotEmpty) {
          classId = existingClasses.first['id'] as int;
        } else {
          final color = palette[colorIdx % palette.length];
          colorIdx++;
          classId = await txn.insert('classes', {
            'name': className,
            'grade_level': gradeLevel,
            'subject': (subject != null && subject.isNotEmpty) ? subject : null,
            'academic_year': academicYear,
            'color': color,
            'created_at': now,
          });
          classesCreated++;
        }

        final students = (clsData['students'] as List<dynamic>?) ?? [];
        for (var st in students) {
          final stMap = Map<String, dynamic>.from(st);
          final no = stMap['student_no']?.toString().trim();
          final first = stMap['first_name']?.toString().trim();
          final last = stMap['last_name']?.toString().trim() ?? '';
          if (no == null || no.isEmpty || first == null || first.isEmpty) continue;

          final existingStudent = await txn.query(
            'students',
            where: 'class_id = ? AND student_no = ? AND deleted_at IS NULL',
            whereArgs: [classId, no],
            limit: 1,
          );

          final studentData = {
            'class_id': classId,
            'student_no': no,
            'first_name': first,
            'last_name': last,
            'gender': (stMap['gender']?.toString().toUpperCase() == 'K' ||
                    stMap['gender']?.toString().toUpperCase() == 'F')
                ? 'F'
                : 'M',
            'guardian_name': stMap['guardian_name']?.toString().trim(),
            'guardian_phone': stMap['guardian_phone']?.toString().trim(),
            'health_note': stMap['health_note']?.toString().trim(),
          };

          if (existingStudent.isNotEmpty) {
            if (updateIfExists) {
              await txn.update('students', studentData,
                  where: 'id = ?', whereArgs: [existingStudent.first['id']]);
              studentsUpdated++;
            }
          } else {
            studentData['created_at'] = now;
            await txn.insert('students', studentData);
            studentsCreated++;
          }
        }
      }
    });

    return {
      'classes_created': classesCreated,
      'students_created': studentsCreated,
      'students_updated': studentsUpdated,
    };
  }

  Future<Map<String, int>> seedTestData() async {
    return await TestDataSeeder.seedAllData();
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> clearAcademicYearData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('student_evaluations');
      await txn.delete('student_notes');
      await txn.delete('attendances');
      await txn.delete('exam_scores');
      await txn.delete('exams');
      await txn.delete('students');
      await txn.delete('lesson_plans');
      await txn.delete('timetable_entries');
      await txn.delete('classes');
    });
  }

  /// Temiz verilerle başlamak için tüm örnek ders, sınıf, öğrenci ve plan verilerini sıfırlar.
  Future<void> clearAllDataForFreshStart() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('student_evaluations');
      await txn.delete('student_notes');
      await txn.delete('attendances');
      await txn.delete('exam_scores');
      await txn.delete('exams');
      await txn.delete('students');
      await txn.delete('lesson_plans');
      await txn.delete('timetable_entries');
      await txn.delete('classes');
      await txn.update('settings', {
        'is_onboarding_completed': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final db = await database;
    await db.update('settings', {
      'is_onboarding_completed': completed ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
