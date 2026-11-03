import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/database_helper.dart';

class InstitutionImportResult {
  final bool success;
  final int classCount;
  final int studentCount;
  final int photoCount;
  final int bellPeriodCount;
  final String? errorMessage;

  InstitutionImportResult({
    required this.success,
    this.classCount = 0,
    this.studentCount = 0,
    this.photoCount = 0,
    this.bellPeriodCount = 0,
    this.errorMessage,
  });
}

class InstitutionShareService {
  /// Fotoğrafların yerel saklandığı dizin
  static Future<Directory> _getPhotosDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDocDir.path, 'student_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Kurum için tüm sınıfları, öğrencileri, fotoğrafları ve zil saatlerini
  /// paketleyip WhatsApp / diğer uygulamalarda paylaşır.
  static Future<File> exportAndShareInstitutionData({String? customSchoolName}) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Ayarları al
    final settingsList = await db.query('settings', limit: 1);
    final settings = settingsList.isNotEmpty ? settingsList.first : null;
    final schoolName = customSchoolName ?? (settings?['school_name']?.toString() ?? 'Okul');
    final academicYear = settings?['academic_year']?.toString() ?? DatabaseHelper.defaultAcademicYear;

    // 2. Sınıfları al
    final classes = await db.query(
      'classes',
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );

    // 3. Öğrencileri al
    final students = await db.query(
      'students',
      where: 'deleted_at IS NULL',
      orderBy: 'class_id ASC, CAST(student_no AS INTEGER) ASC',
    );

    // 4. Okul zil saatlerini al
    final bellPeriods = await db.query(
      'bell_periods',
      orderBy: 'period_no ASC',
    );

    // 5. Arşiv nesnesi oluştur
    final archive = Archive();

    // 6. Fotoğrafları arşive ekle
    final List<Map<String, dynamic>> studentsWithPhotoMeta = [];
    int photoCount = 0;

    for (var s in students) {
      final sMap = Map<String, dynamic>.from(s);
      final photoPath = s['photo_path']?.toString();
      String? archivePhotoName;

      if (photoPath != null && photoPath.isNotEmpty) {
        final photoFile = File(photoPath);
        if (await photoFile.exists()) {
          try {
            final photoBytes = await photoFile.readAsBytes();
            archivePhotoName = 'photos/photo_${s['id']}.jpg';
            archive.addFile(ArchiveFile(archivePhotoName, photoBytes.length, photoBytes));
            photoCount++;
          } catch (_) {}
        }
      }

      sMap['archive_photo_name'] = archivePhotoName;
      studentsWithPhotoMeta.add(sMap);
    }

    // 7. JSON veri paketi oluştur
    final now = DateTime.now();
    final exportData = {
      'app': 'ogretmencep',
      'package_type': 'institution_package',
      'version': '1.0',
      'created_at': now.toIso8601String(),
      'school_name': schoolName,
      'academic_year': academicYear,
      'classes_count': classes.length,
      'students_count': students.length,
      'photos_count': photoCount,
      'bell_periods_count': bellPeriods.length,
      'settings': {
        'school_name': schoolName,
        'academic_year': academicYear,
        'timetable_days': settings?['timetable_days'] ?? 5,
        'daily_periods_count': settings?['daily_periods_count'] ?? 8,
      },
      'bell_periods': bellPeriods,
      'classes': classes,
      'students': studentsWithPhotoMeta,
    };

    final jsonBytes = utf8.encode(jsonEncode(exportData));
    archive.addFile(ArchiveFile('institution_data.json', jsonBytes.length, jsonBytes));

    // 8. ZIP kodla
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw Exception('Kurum veri paketi oluşturulamadı.');
    }

    // 9. Geçici dosyayı oluştur
    final tempDir = await getTemporaryDirectory();
    final safeSchool = schoolName.replaceAll(RegExp(r'[^a-zA-Z0-9çÇğĞıİöÖşŞüÜ_-]'), '_');
    final timeStr = DateFormat('yyyyMMdd_HHmm').format(now);
    final fileName = 'Kurum_Verisi_${safeSchool}_$timeStr.ogretmencep';
    final targetFile = File(p.join(tempDir.path, fileName));
    await targetFile.writeAsBytes(zipBytes);

    // 10. WhatsApp / Diğer uygulamalar ile Paylaş
    await Share.shareXFiles(
      [XFile(targetFile.path, mimeType: 'application/octet-stream', name: fileName)],
      subject: '$schoolName - Kurum Veri Paketi',
      text: 'ÖğretmenCep Kurum Veri Paketi:\n'
          'Okul: $schoolName\n'
          'Sınıf Sayısı: ${classes.length}\n'
          'Öğrenci Sayısı: ${students.length}\n'
          'Fotoğraf Sayısı: $photoCount\n'
          'Zil Saatleri: ${bellPeriods.length} Periyot\n\n'
          'Bu dosyayı ÖğretmenCep uygulamasında açarak veya Ayarlar menüsünden "Kurum Verisini İçe Aktar" seçeneği ile tek tıkla yükleyebilirsiniz.',
    );

    return targetFile;
  }

  /// WhatsApp'tan veya dosya yöneticisinden seçilen kurum veri paketini içe aktarır
  static Future<InstitutionImportResult> importInstitutionData(File file) async {
    try {
      if (!await file.exists()) {
        return InstitutionImportResult(
          success: false,
          errorMessage: 'Dosya bulunamadı.',
        );
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // institution_data.json ara
      final jsonFile = archive.findFile('institution_data.json');
      if (jsonFile == null) {
        return InstitutionImportResult(
          success: false,
          errorMessage: 'Geçersiz dosya formatı. Bu dosya ÖğretmenCep Kurum Veri Paketi içermiyor.',
        );
      }

      final jsonContent = utf8.decode(jsonFile.content as List<int>);
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      final rawClasses = (data['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final rawStudents = (data['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final rawBellPeriods = (data['bell_periods'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final rawSettings = data['settings'] as Map<String, dynamic>?;

      final db = await DatabaseHelper.instance.database;
      final photosDir = await _getPhotosDirectory();

      int importedClasses = 0;
      int importedStudents = 0;
      int importedPhotos = 0;
      int importedBellPeriods = 0;

      await db.transaction((txn) async {
        // 1. Okul Ayarları (Okul adı vs.)
        if (rawSettings != null) {
          final schoolName = rawSettings['school_name']?.toString();
          if (schoolName != null && schoolName.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE settings SET school_name = ?, updated_at = ? WHERE id = (SELECT id FROM settings LIMIT 1)',
              [schoolName, DateTime.now().toIso8601String()],
            );
          }
        }

        // 2. Okul Zil Saatleri (bell_periods)
        if (rawBellPeriods.isNotEmpty) {
          await txn.delete('bell_periods');
          for (var bp in rawBellPeriods) {
            await txn.insert('bell_periods', {
              'period_no': bp['period_no'],
              'start_time': bp['start_time'],
              'end_time': bp['end_time'],
              'label': bp['label'] ?? '${bp['period_no']}. Ders',
            });
            importedBellPeriods++;
          }
        }

        // 3. Sınıfları Eşleştir veya Ekle
        // Eski Sınıf ID -> Yeni Sınıf ID
        final Map<int, int> oldToNewClassIds = {};

        // Mevcut sınıfları al
        final existingClasses = await txn.query('classes', where: 'deleted_at IS NULL');
        final Map<String, int> existingClassByName = {};
        for (var c in existingClasses) {
          existingClassByName[c['name'].toString().trim().toUpperCase()] = c['id'] as int;
        }

        for (var c in rawClasses) {
          final oldId = c['id'] as int;
          final name = c['name'].toString().trim();
          final upperName = name.toUpperCase();

          if (existingClassByName.containsKey(upperName)) {
            // Zaten var olan sınıfın id'sini kullan
            oldToNewClassIds[oldId] = existingClassByName[upperName]!;
          } else {
            // Yeni sınıf oluştur
            final newId = await txn.insert('classes', {
              'name': name,
              'grade_level': c['grade_level'] ?? '',
              'subject': c['subject'],
              'academic_year': c['academic_year'] ?? DatabaseHelper.defaultAcademicYear,
              'color': c['color'] ?? '#17433B',
              'created_at': DateTime.now().toIso8601String(),
            });
            oldToNewClassIds[oldId] = newId;
            existingClassByName[upperName] = newId;
            importedClasses++;
          }
        }

        // 4. Öğrencileri Eşleştir veya Ekle, Fotoğrafları Kaydet
        for (var s in rawStudents) {
          final oldClassId = (s['class_id'] as num?)?.toInt();
          if (oldClassId == null || !oldToNewClassIds.containsKey(oldClassId)) {
            continue;
          }

          final newClassId = oldToNewClassIds[oldClassId]!;
          final studentNo = s['student_no'].toString().trim();
          final firstName = s['first_name']?.toString() ?? '';
          final lastName = s['last_name']?.toString() ?? '';
          final archivePhotoName = s['archive_photo_name']?.toString();

          // Fotoğrafı yerel diske çıkart
          String? localPhotoPath;
          if (archivePhotoName != null) {
            final archiveFile = archive.findFile(archivePhotoName);
            if (archiveFile != null) {
              try {
                final targetPath = p.join(
                  photosDir.path,
                  'photo_${newClassId}_${studentNo}_${DateTime.now().millisecondsSinceEpoch % 10000}.jpg',
                );
                final outFile = File(targetPath);
                await outFile.writeAsBytes(archiveFile.content as List<int>);
                localPhotoPath = targetPath;
                importedPhotos++;
              } catch (_) {}
            }
          }

          // Bu sınıfta aynı numaralı öğrenci var mı?
          final existingStudents = await txn.query(
            'students',
            where: 'class_id = ? AND student_no = ? AND deleted_at IS NULL',
            whereArgs: [newClassId, studentNo],
            limit: 1,
          );

          if (existingStudents.isNotEmpty) {
            // Öğrenciyi güncelle
            final existingId = existingStudents.first['id'] as int;
            final existingPhoto = existingStudents.first['photo_path']?.toString();

            final updateData = <String, dynamic>{
              'first_name': firstName,
              'last_name': lastName,
              'gender': s['gender'] ?? 'M',
              'birth_date': s['birth_date'],
              'guardian_name': s['guardian_name'],
              'guardian_phone': s['guardian_phone'],
              'health_note': s['health_note'],
              'club': s['club'],
              'blood_type': s['blood_type'],
              'address': s['address'],
              'special_notes': s['special_notes'],
            };

            // Eğer yeni fotoğraf geldiyse veya eskisi yoksa güncelle
            if (localPhotoPath != null) {
              updateData['photo_path'] = localPhotoPath;
            } else if (existingPhoto != null && existingPhoto.isNotEmpty) {
              updateData['photo_path'] = existingPhoto;
            }

            await txn.update(
              'students',
              updateData,
              where: 'id = ?',
              whereArgs: [existingId],
            );
            importedStudents++;
          } else {
            // Yeni öğrenci ekle
            await txn.insert('students', {
              'class_id': newClassId,
              'student_no': studentNo,
              'first_name': firstName,
              'last_name': lastName,
              'gender': s['gender'] ?? 'M',
              'photo_path': localPhotoPath,
              'birth_date': s['birth_date'],
              'guardian_name': s['guardian_name'],
              'guardian_phone': s['guardian_phone'],
              'health_note': s['health_note'],
              'club': s['club'],
              'blood_type': s['blood_type'],
              'address': s['address'],
              'special_notes': s['special_notes'],
              'created_at': DateTime.now().toIso8601String(),
            });
            importedStudents++;
          }
        }
      });

      return InstitutionImportResult(
        success: true,
        classCount: importedClasses,
        studentCount: importedStudents,
        photoCount: importedPhotos,
        bellPeriodCount: importedBellPeriods,
      );
    } catch (e) {
      return InstitutionImportResult(
        success: false,
        errorMessage: 'İçe aktarma sırasında bir hata oluştu: $e',
      );
    }
  }
}
