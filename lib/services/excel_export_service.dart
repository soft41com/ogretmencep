import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class ExcelExportService {
  /// Excel sayfa adı (Sheet) için güvenli ve benzersiz isim üretir
  static String _sanitizeSheetName(String rawName, Set<String> existingNames) {
    var sanitized = rawName.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_').trim();
    if (sanitized.isEmpty) sanitized = 'Sinif';
    if (sanitized.length > 28) sanitized = sanitized.substring(0, 28);

    var uniqueName = sanitized;
    int counter = 1;
    while (existingNames.contains(uniqueName.toLowerCase())) {
      uniqueName = '$sanitized ($counter)';
      counter++;
    }
    existingNames.add(uniqueName.toLowerCase());
    return uniqueName;
  }

  /// 1. TÜM SINIFLARIN ÖĞRENCİ LİSTESİNİ EXCEL'E AKTAR
  /// Her bir sekmede (Sheet) bir sınıf listesi bulunur.
  static Future<bool> exportAllStudentsToExcel() async {
    final db = await DatabaseHelper.instance.database;

    final classes = await db.query(
      'classes',
      where: 'deleted_at IS NULL',
      orderBy: 'grade_level ASC, name ASC',
    );

    if (classes.isEmpty) {
      throw Exception('Aktarılacak sınıf bulunamadı. Lütfen önce sınıf ekleyin.');
    }

    final excel = Excel.createExcel();
    final createdSheets = <String>{};
    final existingNames = <String>{};

    for (var cls in classes) {
      final classId = cls['id'] as int;
      final rawClassName = cls['name'] as String;
      final sheetName = _sanitizeSheetName(rawClassName, existingNames);
      createdSheets.add(sheetName);

      final sheet = excel[sheetName];

      // Başlık Satırı
      sheet.appendRow([
        TextCellValue('Sıra'),
        TextCellValue('Öğrenci No'),
        TextCellValue('Adı'),
        TextCellValue('Soyadı'),
        TextCellValue('Cinsiyet'),
        TextCellValue('Veli Adı'),
        TextCellValue('Veli Telefonu'),
        TextCellValue('Sağlık Notu'),
        TextCellValue('Sosyal Kulüp'),
        TextCellValue('Kan Grubu'),
        TextCellValue('Adres'),
      ]);

      // Sınıfa Ait Öğrenciler
      final students = await db.rawQuery('''
        SELECT * FROM students 
        WHERE class_id = ? AND deleted_at IS NULL 
        ORDER BY CAST(student_no AS INTEGER) ASC, student_no ASC
      ''', [classId]);

      int index = 1;
      for (var st in students) {
        final gender = (st['gender'] == 'F') ? 'Kız' : 'Erkek';
        sheet.appendRow([
          IntCellValue(index),
          TextCellValue(st['student_no']?.toString() ?? ''),
          TextCellValue(st['first_name']?.toString() ?? ''),
          TextCellValue(st['last_name']?.toString() ?? ''),
          TextCellValue(gender),
          TextCellValue(st['guardian_name']?.toString() ?? ''),
          TextCellValue(st['guardian_phone']?.toString() ?? ''),
          TextCellValue(st['health_note']?.toString() ?? ''),
          TextCellValue(st['club']?.toString() ?? ''),
          TextCellValue(st['blood_type']?.toString() ?? ''),
          TextCellValue(st['address']?.toString() ?? ''),
        ]);
        index++;
      }
    }

    // Varsayılan Sheet1'i kaldır ve ilk sınıfı varsayılan yap
    if (createdSheets.isNotEmpty) {
      excel.setDefaultSheet(createdSheets.first);
      if (excel.sheets.containsKey('Sheet1') && !createdSheets.contains('Sheet1')) {
        excel.delete('Sheet1');
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${tempDir.path}/Tum_Siniflar_Ogrenci_Listesi_$dateStr.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'ÖğretmenCep - Tüm Sınıfların Öğrenci Listesi ($dateStr)',
      subject: 'Tum_Siniflar_Ogrenci_Listesi.xlsx',
    );

    return true;
  }

  /// 2. DEVAMSIZLIK RAPORU EXCEL'E AKTAR
  /// Her bir sekmede (Sheet) bir sınıf listesi bulunur.
  /// Öğrenciler toplam devamsızlık sayısına göre AZALAN SIRA ile listelenir.
  static Future<bool> exportAttendanceReportToExcel() async {
    final db = await DatabaseHelper.instance.database;

    final classes = await db.query(
      'classes',
      where: 'deleted_at IS NULL',
      orderBy: 'grade_level ASC, name ASC',
    );

    if (classes.isEmpty) {
      throw Exception('Raporlanacak sınıf bulunamadı.');
    }

    final excel = Excel.createExcel();
    final createdSheets = <String>{};
    final existingNames = <String>{};

    for (var cls in classes) {
      final classId = cls['id'] as int;
      final rawClassName = cls['name'] as String;
      final sheetName = _sanitizeSheetName(rawClassName, existingNames);
      createdSheets.add(sheetName);

      final sheet = excel[sheetName];

      // Başlık Satırı
      sheet.appendRow([
        TextCellValue('Sıra'),
        TextCellValue('Öğrenci No'),
        TextCellValue('Adı'),
        TextCellValue('Soyadı'),
        TextCellValue('Toplam Devamsızlık'),
        TextCellValue('Gelmedi (Özürsüz)'),
        TextCellValue('İzinli'),
        TextCellValue('Geç Kaldı'),
        TextCellValue('Raporlu'),
      ]);

      // Öğrenci devamsızlık sayılarını azalan sıra ile çek
      final rows = await db.rawQuery('''
        SELECT s.id, s.student_no, s.first_name, s.last_name,
          COALESCE(COUNT(CASE WHEN a.status = 'absent' THEN 1 END), 0) as absent_count,
          COALESCE(COUNT(CASE WHEN a.status = 'late' THEN 1 END), 0) as late_count,
          COALESCE(COUNT(CASE WHEN a.status = 'excused' THEN 1 END), 0) as excused_count,
          COALESCE(COUNT(CASE WHEN a.status = 'report' OR a.status = 'sick' THEN 1 END), 0) as report_count,
          COALESCE(COUNT(CASE WHEN a.status != 'present' AND a.status IS NOT NULL THEN 1 END), 0) as total_absence
        FROM students s
        LEFT JOIN attendances a ON a.student_id = s.id
        WHERE s.class_id = ? AND s.deleted_at IS NULL
        GROUP BY s.id
        ORDER BY total_absence DESC, absent_count DESC, CAST(s.student_no AS INTEGER) ASC
      ''', [classId]);

      int index = 1;
      for (var r in rows) {
        final totalAbsence = (r['total_absence'] as num?)?.toInt() ?? 0;
        final absentCount = (r['absent_count'] as num?)?.toInt() ?? 0;
        final excusedCount = (r['excused_count'] as num?)?.toInt() ?? 0;
        final lateCount = (r['late_count'] as num?)?.toInt() ?? 0;
        final reportCount = (r['report_count'] as num?)?.toInt() ?? 0;

        sheet.appendRow([
          IntCellValue(index),
          TextCellValue(r['student_no']?.toString() ?? ''),
          TextCellValue(r['first_name']?.toString() ?? ''),
          TextCellValue(r['last_name']?.toString() ?? ''),
          IntCellValue(totalAbsence),
          IntCellValue(absentCount),
          IntCellValue(excusedCount),
          IntCellValue(lateCount),
          IntCellValue(reportCount),
        ]);
        index++;
      }
    }

    if (createdSheets.isNotEmpty) {
      excel.setDefaultSheet(createdSheets.first);
      if (excel.sheets.containsKey('Sheet1') && !createdSheets.contains('Sheet1')) {
        excel.delete('Sheet1');
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${tempDir.path}/Devamsizlik_Raporu_$dateStr.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'ÖğretmenCep - Devamsızlık Raporu ($dateStr)',
      subject: 'Devamsizlik_Raporu.xlsx',
    );

    return true;
  }

  /// 3. SINAVLAR & ÖĞRENCİ NOTLARI EXCEL'E AKTAR
  /// Her bir sekmede (Sheet) bir sınıf listesi bulunur.
  /// Öğrenci no sırasına göre tüm sınav/değerlendirme notları ve ortalaması yer alır.
  static Future<bool> exportExamGradesToExcel() async {
    final db = await DatabaseHelper.instance.database;

    final classes = await db.query(
      'classes',
      where: 'deleted_at IS NULL',
      orderBy: 'grade_level ASC, name ASC',
    );

    if (classes.isEmpty) {
      throw Exception('Raporlanacak sınıf bulunamadı.');
    }

    final excel = Excel.createExcel();
    final createdSheets = <String>{};
    final existingNames = <String>{};

    for (var cls in classes) {
      final classId = cls['id'] as int;
      final rawClassName = cls['name'] as String;
      final sheetName = _sanitizeSheetName(rawClassName, existingNames);
      createdSheets.add(sheetName);

      final sheet = excel[sheetName];

      // Sınıfa ait sınavlar
      final exams = await db.query(
        'exams',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'exam_date ASC, id ASC',
      );

      // Başlık satırı oluştur
      final header = <CellValue>[
        TextCellValue('Sıra'),
        TextCellValue('Öğrenci No'),
        TextCellValue('Adı'),
        TextCellValue('Soyadı'),
      ];

      for (var ex in exams) {
        header.add(TextCellValue(ex['title'] as String));
      }
      header.add(TextCellValue('Dönem Ortalaması'));
      sheet.appendRow(header);

      // Sınıfa ait öğrenciler
      final students = await db.rawQuery('''
        SELECT id, student_no, first_name, last_name 
        FROM students 
        WHERE class_id = ? AND deleted_at IS NULL 
        ORDER BY CAST(student_no AS INTEGER) ASC, student_no ASC
      ''', [classId]);

      // Sınav notlarını topla: studentId -> {examId: score}
      final scoresRes = await db.rawQuery('''
        SELECT es.exam_id, es.student_id, es.score 
        FROM exam_scores es 
        JOIN exams e ON e.id = es.exam_id 
        WHERE e.class_id = ?
      ''', [classId]);

      final Map<int, Map<int, double>> studentScores = {};
      for (var sc in scoresRes) {
        final sId = sc['student_id'] as int;
        final eId = sc['exam_id'] as int;
        final val = (sc['score'] as num?)?.toDouble() ?? 0.0;
        studentScores.putIfAbsent(sId, () => {})[eId] = val;
      }

      int index = 1;
      for (var st in students) {
        final sId = st['id'] as int;
        final row = <CellValue>[
          IntCellValue(index),
          TextCellValue(st['student_no']?.toString() ?? ''),
          TextCellValue(st['first_name']?.toString() ?? ''),
          TextCellValue(st['last_name']?.toString() ?? ''),
        ];

        final scores = studentScores[sId] ?? {};
        double sum = 0;
        int count = 0;

        for (var ex in exams) {
          final eId = ex['id'] as int;
          if (scores.containsKey(eId)) {
            final sc = scores[eId]!;
            row.add(DoubleCellValue(sc));
            sum += sc;
            count++;
          } else {
            row.add(TextCellValue('-'));
          }
        }

        if (count > 0) {
          final avg = double.parse((sum / count).toStringAsFixed(2));
          row.add(DoubleCellValue(avg));
        } else {
          row.add(TextCellValue('-'));
        }

        sheet.appendRow(row);
        index++;
      }
    }

    if (createdSheets.isNotEmpty) {
      excel.setDefaultSheet(createdSheets.first);
      if (excel.sheets.containsKey('Sheet1') && !createdSheets.contains('Sheet1')) {
        excel.delete('Sheet1');
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${tempDir.path}/Sinav_ve_Not_Cizelgesi_$dateStr.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'ÖğretmenCep - Sınav ve Not Çizelgesi ($dateStr)',
      subject: 'Sinav_ve_Not_Cizelgesi.xlsx',
    );

    return true;
  }

  /// 4. TEK BİR SINIFIN NOT ÇİZELGESİNİ EXCEL'E AKTAR
  static Future<bool> exportSingleClassExamGradesToExcel(ClassModel classModel) async {
    final db = await DatabaseHelper.instance.database;

    final excel = Excel.createExcel();
    final sheetName = _sanitizeSheetName(classModel.name, {});
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Sınıfa ait sınavlar
    final exams = await db.query(
      'exams',
      where: 'class_id = ?',
      whereArgs: [classModel.id],
      orderBy: 'exam_date ASC, id ASC',
    );

    // Başlık satırı
    final header = <CellValue>[
      TextCellValue('Sıra'),
      TextCellValue('Öğrenci No'),
      TextCellValue('Adı'),
      TextCellValue('Soyadı'),
    ];

    for (var ex in exams) {
      header.add(TextCellValue(ex['title'] as String));
    }
    header.add(TextCellValue('Dönem Ortalaması'));
    sheet.appendRow(header);

    // Sınıfa ait öğrenciler
    final students = await db.rawQuery('''
      SELECT id, student_no, first_name, last_name 
      FROM students 
      WHERE class_id = ? AND deleted_at IS NULL 
      ORDER BY CAST(student_no AS INTEGER) ASC, student_no ASC
    ''', [classModel.id]);

    // Sınav notları
    final scoresRes = await db.rawQuery('''
      SELECT es.exam_id, es.student_id, es.score 
      FROM exam_scores es 
      JOIN exams e ON e.id = es.exam_id 
      WHERE e.class_id = ?
    ''', [classModel.id]);

    final Map<int, Map<int, double>> studentScores = {};
    for (var sc in scoresRes) {
      final sId = sc['student_id'] as int;
      final eId = sc['exam_id'] as int;
      final val = (sc['score'] as num?)?.toDouble() ?? 0.0;
      studentScores.putIfAbsent(sId, () => {})[eId] = val;
    }

    int index = 1;
    for (var st in students) {
      final sId = st['id'] as int;
      final row = <CellValue>[
        IntCellValue(index),
        TextCellValue(st['student_no']?.toString() ?? ''),
        TextCellValue(st['first_name']?.toString() ?? ''),
        TextCellValue(st['last_name']?.toString() ?? ''),
      ];

      final scores = studentScores[sId] ?? {};
      double sum = 0;
      int count = 0;

      for (var ex in exams) {
        final eId = ex['id'] as int;
        if (scores.containsKey(eId)) {
          final sc = scores[eId]!;
          row.add(DoubleCellValue(sc));
          sum += sc;
          count++;
        } else {
          row.add(TextCellValue('-'));
        }
      }

      if (count > 0) {
        final avg = double.parse((sum / count).toStringAsFixed(2));
        row.add(DoubleCellValue(avg));
      } else {
        row.add(TextCellValue('-'));
      }

      sheet.appendRow(row);
      index++;
    }

    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final sanitizedFileBase = classModel.name.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final filePath = '${tempDir.path}/${sanitizedFileBase}_Not_Cizelgesi_$dateStr.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'ÖğretmenCep - ${classModel.name} Not Çizelgesi ($dateStr)',
      subject: '${sanitizedFileBase}_Not_Cizelgesi.xlsx',
    );

    return true;
  }

  /// 5. EXCEL'DEN SINAV NOTLARINI YÜKLE VE GÜNCELLE
  /// [targetClassId] belirtilirse o sınıfa ait sheet veya öğrenci notları güncellenir.
  /// Belirtilmezse tüm sınıfların sheet'leri taranır.
  static Future<ExamImportResult> importExamGradesFromExcel({int? targetClassId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ExamImportResult(success: false, message: 'Dosya seçilmedi.');
    }

    final file = result.files.first;
    List<int>? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null || bytes.isEmpty) {
      return ExamImportResult(success: false, message: 'Seçilen dosya okunamadı.');
    }

    final excel = Excel.decodeBytes(bytes);
    final db = await DatabaseHelper.instance.database;

    // Tüm sınıfları al
    final allClasses = await db.query('classes', where: 'deleted_at IS NULL');
    if (allClasses.isEmpty) {
      return ExamImportResult(success: false, message: 'Kayıtlı sınıf bulunamadı.');
    }

    int totalUpdatedScores = 0;
    final Set<int> updatedStudentIds = {};
    final now = DateTime.now().toIso8601String();

    final nonExamHeaders = {
      'sıra', 'sira', 'öğrenci no', 'ogrenci no', 'no', 'numara', 'okul no', 'okul_no',
      'adı', 'adi', 'ad', 'soyadı', 'soyadi', 'soyad', 'cinsiyet',
      'dönem ortalaması', 'donem ortalamasi', 'ortalama', 'genel ortalama',
      'sınıf', 'sinif', 'veli adı', 'veli telefonu', 'sağlık notu', 'sosyal kulüp', 'kan grubu', 'adres',
    };

    for (var tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      // Hangi sınıfla eşleşiyor?
      Map<String, dynamic>? currentClass;
      if (targetClassId != null) {
        currentClass = allClasses.firstWhere(
          (c) => c['id'] == targetClassId,
          orElse: () => allClasses.first,
        );
      } else {
        final cleanSheet = tableName.toLowerCase().trim();
        for (var c in allClasses) {
          final cName = (c['name'] as String).toLowerCase().trim();
          if (cleanSheet.contains(cName) || cName.contains(cleanSheet)) {
            currentClass = c;
            break;
          }
        }
        if (currentClass == null && allClasses.length == 1) {
          currentClass = allClasses.first;
        }
      }

      if (currentClass == null) continue;
      final classId = currentClass['id'] as int;

      // Sınıfın öğrencilerini al: student_no -> student_id
      final studentsRes = await db.query(
        'students',
        columns: ['id', 'student_no'],
        where: 'class_id = ? AND deleted_at IS NULL',
        whereArgs: [classId],
      );
      final Map<String, int> studentMap = {};
      for (var s in studentsRes) {
        final no = (s['student_no'] ?? '').toString().trim();
        if (no.isNotEmpty) studentMap[no] = s['id'] as int;
      }

      if (studentMap.isEmpty) continue;

      // Sınıfın mevcut sınavlarını al: title -> exam_id
      final examsRes = await db.query(
        'exams',
        where: 'class_id = ?',
        whereArgs: [classId],
      );
      final Map<String, int> examMap = {};
      for (var ex in examsRes) {
        final title = (ex['title'] as String).trim().toLowerCase();
        examMap[title] = ex['id'] as int;
      }

      // Başlık satırını bul
      int headerRowIdx = -1;
      int colStudentNo = -1;
      final Map<int, int> examColumnIndexToExamId = {}; // colIndex -> examId

      for (int r = 0; r < sheet.rows.length && r < 5; r++) {
        final row = sheet.rows[r];
        int foundNoCol = -1;
        for (int c = 0; c < row.length; c++) {
          final cellText = _extractCellValue(row[c]?.value).toLowerCase();
          if (cellText.contains('no') || cellText.contains('numara')) {
            foundNoCol = c;
            break;
          }
        }

        if (foundNoCol != -1) {
          headerRowIdx = r;
          colStudentNo = foundNoCol;

          // Şimdi sınav sütunlarını tespit et
          for (int c = 0; c < row.length; c++) {
            if (c == colStudentNo) continue;
            final rawTitle = _extractCellValue(row[c]?.value);
            final cleanTitleLower = rawTitle.toLowerCase();
            if (rawTitle.isEmpty || nonExamHeaders.contains(cleanTitleLower)) continue;

            // Bu bir sınav sütunudur
            int? examId = examMap[cleanTitleLower];
            if (examId == null) {
              // Mevcut değilse otomatik oluştur
              final newId = await db.insert('exams', {
                'class_id': classId,
                'title': rawTitle,
                'type': _guessExamType(rawTitle),
                'exam_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'weight': 100.0,
                'max_score': 100.0,
                'created_at': now,
              });
              examMap[cleanTitleLower] = newId;
              examId = newId;
            }
            examColumnIndexToExamId[c] = examId;
          }
          break;
        }
      }

      if (headerRowIdx == -1 || colStudentNo == -1 || examColumnIndexToExamId.isEmpty) {
        continue;
      }

      // Veri satırlarını oku ve notları güncelle
      await db.transaction((txn) async {
        for (int r = headerRowIdx + 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.isEmpty || colStudentNo >= row.length) continue;

          final rawNo = _extractCellValue(row[colStudentNo]?.value);
          final studentId = studentMap[rawNo] ??
              studentMap[rawNo.replaceFirst(RegExp(r'^0+'), '')];

          if (studentId == null) continue;

          for (var entry in examColumnIndexToExamId.entries) {
            final colIdx = entry.key;
            final examId = entry.value;

            if (colIdx < row.length) {
              final rawVal = _extractCellValue(row[colIdx]?.value);
              final score = _parseScoreValue(rawVal);

              if (score != null) {
                await txn.rawInsert('''
                  INSERT INTO exam_scores (exam_id, student_id, score, created_at)
                  VALUES (?, ?, ?, ?)
                  ON CONFLICT(exam_id, student_id) DO UPDATE SET score = ?, created_at = ?
                ''', [examId, studentId, score, now, score, now]);

                totalUpdatedScores++;
                updatedStudentIds.add(studentId);
              }
            }
          }
        }
      });
    }

    if (totalUpdatedScores == 0) {
      return ExamImportResult(
        success: false,
        message: 'Excel dosyasında güncellenecek öğrenci notu bulunamadı. Lütfen öğrenci numaralarını ve sütunları kontrol edin.',
      );
    }

    return ExamImportResult(
      success: true,
      updatedCount: totalUpdatedScores,
      totalStudents: updatedStudentIds.length,
      message: '${updatedStudentIds.length} öğrencinin toplam $totalUpdatedScores adet notu başarıyla güncellendi.',
    );
  }

  static String _extractCellValue(CellValue? cellValue) {
    if (cellValue == null) return '';
    if (cellValue is TextCellValue) {
      return (cellValue.value.text ?? '').trim();
    }
    if (cellValue is IntCellValue) return cellValue.value.toString();
    if (cellValue is DoubleCellValue) return cellValue.value.toString();
    if (cellValue is BoolCellValue) return cellValue.value ? 'true' : 'false';
    return cellValue.toString().trim();
  }

  static double? _parseScoreValue(String raw) {
    final clean = raw.trim().replaceAll(',', '.');
    if (clean.isEmpty || clean == '-' || clean == '–' || clean.toLowerCase() == 'g' || clean.toLowerCase() == 'girmedi') {
      return null;
    }
    final d = double.tryParse(clean);
    if (d != null && d >= 0 && d <= 100) {
      return d;
    }
    return null;
  }

  static String _guessExamType(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('sözlü') || lower.contains('sozlu') || lower.contains('katılım') || lower.contains('katilim')) {
      return 'oral';
    }
    if (lower.contains('performans')) {
      return 'performance';
    }
    if (lower.contains('proje')) {
      return 'project';
    }
    return 'written';
  }

  /// 7. SINIF ÖĞRENCİLERİNİN ARTI / EKSİ PUAN RAPORU
  /// Sekme adı: Sınıf adı
  /// Sütunlar: Sıra, Öğrenci No, Öğrenci Adı Soyadı, Artı, Eksi, Toplam
  static Future<bool> exportClassEvaluationsToExcel(ClassModel classModel) async {
    final db = await DatabaseHelper.instance.database;

    final excel = Excel.createExcel();
    final sheetName = _sanitizeSheetName(classModel.name, {});
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Başlık satırı
    sheet.appendRow([
      TextCellValue('Sıra'),
      TextCellValue('Öğrenci No'),
      TextCellValue('Öğrenci Adı Soyadı'),
      TextCellValue('Artı'),
      TextCellValue('Eksi'),
      TextCellValue('Toplam'),
    ]);

    // Öğrencileri ve sınıf içi artı/eksi puanlarını çek
    final rows = await db.rawQuery('''
      SELECT s.id, s.student_no, s.first_name, s.last_name,
        COALESCE(SUM(CASE WHEN e.value > 0 THEN e.value ELSE 0 END), 0) as plus_points,
        COALESCE(SUM(CASE WHEN e.value < 0 THEN ABS(e.value) ELSE 0 END), 0) as minus_points,
        COALESCE(SUM(e.value), 0) as total_points
      FROM students s
      LEFT JOIN student_evaluations e ON e.student_id = s.id AND e.class_id = ?
      WHERE s.class_id = ? AND s.deleted_at IS NULL
      GROUP BY s.id
      ORDER BY CAST(s.student_no AS INTEGER) ASC, s.student_no ASC
    ''', [classModel.id, classModel.id]);

    if (rows.isEmpty) {
      throw Exception('Bu sınıfta kayıtlı öğrenci bulunamadı.');
    }

    int index = 1;
    for (var r in rows) {
      final studentNo = r['student_no']?.toString() ?? '';
      final fullName = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
      final plus = (r['plus_points'] as num?)?.toInt() ?? 0;
      final minus = (r['minus_points'] as num?)?.toInt() ?? 0;
      final total = (r['total_points'] as num?)?.toInt() ?? 0;

      sheet.appendRow([
        IntCellValue(index),
        TextCellValue(studentNo),
        TextCellValue(fullName),
        IntCellValue(plus),
        IntCellValue(minus),
        IntCellValue(total),
      ]);
      index++;
    }

    // Sheet1 varsayılanını temizle
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final sanitizedFileName = classModel.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${tempDir.path}/${sanitizedFileName}_Puan_Raporu_$dateStr.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'ÖğretmenCep - ${classModel.name} Artı/Eksi Puan Raporu ($dateStr)',
      subject: '${sanitizedFileName}_Puan_Raporu.xlsx',
    );

    return true;
  }
}

class ExamImportResult {
  final bool success;
  final int updatedCount;
  final int totalStudents;
  final String message;

  ExamImportResult({
    required this.success,
    this.updatedCount = 0,
    this.totalStudents = 0,
    required this.message,
  });
}
