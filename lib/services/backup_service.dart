import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database_helper.dart';

class BackupItemInfo {
  final File file;
  final String fileName;
  final String academicYear;
  final DateTime createdAt;
  final int fileSize;
  final int classCount;
  final int studentCount;
  final int photoCount;

  BackupItemInfo({
    required this.file,
    required this.fileName,
    required this.academicYear,
    required this.createdAt,
    required this.fileSize,
    required this.classCount,
    required this.studentCount,
    required this.photoCount,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BackupService {
  /// Telefonun yerel belgeler klasöründe 'backups' dizinini döndürür
  static Future<Directory> getBackupsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(appDocDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Öğrenci fotoğraflarının tutulduğu dizini döndürür
  static Future<Directory> getPhotosDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDocDir.path, 'student_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// Aktif eğitim öğretim yılına göre yerel telefon hafızasına tam yedek (DB + Fotoğraflar) alır
  static Future<File> createAcademicYearBackup({required String academicYear}) async {
    final db = await DatabaseHelper.instance.database;

    // WAL modundaki tüm verileri ana veritabanı dosyasına yaz
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {}

    // İstatistikleri topla
    int classCount = 0;
    int studentCount = 0;
    try {
      final classRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM classes WHERE deleted_at IS NULL');
      classCount = Sqflite.firstIntValue(classRes) ?? 0;

      final studentRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM students WHERE deleted_at IS NULL');
      studentCount = Sqflite.firstIntValue(studentRes) ?? 0;
    } catch (_) {}

    // DB dosyasını oku
    final dbDir = await getDatabasesPath();
    var dbPath = p.join(dbDir, 'ogretmencep.db');
    var dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      final legacyPath = p.join(dbDir, 'ogretmen_yardimcisi.db');
      final legacyFile = File(legacyPath);
      if (await legacyFile.exists()) {
        dbPath = legacyPath;
        dbFile = legacyFile;
      } else {
        throw Exception('Veritabanı dosyası bulunamadı: $dbPath');
      }
    }
    final dbBytes = await dbFile.readAsBytes();

    // Fotoğrafları topla
    final photosDir = await getPhotosDirectory();
    final photoFiles = <File>[];
    if (await photosDir.exists()) {
      final entities = photosDir.listSync(recursive: true);
      for (var e in entities) {
        if (e is File && !p.basename(e.path).startsWith('.')) {
          photoFiles.add(e);
        }
      }
    }

    final now = DateTime.now();
    final metadata = {
      'academic_year': academicYear,
      'created_at': now.toIso8601String(),
      'class_count': classCount,
      'student_count': studentCount,
      'photo_count': photoFiles.length,
      'app_version': '1.0.0',
    };

    // Archive nesnesi oluştur
    final archive = Archive();

    // 1. Veritabanı dosyası
    archive.addFile(ArchiveFile('database.db', dbBytes.length, dbBytes));

    // 2. Üstveri (Metadata)
    final metaBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    // 3. Fotoğraflar
    for (var file in photoFiles) {
      final bytes = await file.readAsBytes();
      final relName = p.basename(file.path);
      archive.addFile(ArchiveFile('photos/$relName', bytes.length, bytes));
    }

    // Zip olarak paketle
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) {
      throw Exception('Yedek arşivi oluşturulamadı.');
    }

    // Dosya adı eğitim öğretim yılına özel ve benzersizdir: yedek_2024-2025.zip
    final safeYear = academicYear.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_');
    final fileName = 'yedek_$safeYear.zip';

    final backupsDir = await getBackupsDirectory();
    final backupFile = File(p.join(backupsDir.path, fileName));

    // Aynı eğitim öğretim yılına ait eski zaman damgalı veya mevcut dosyaları temizle (üzerine yaz)
    if (await backupsDir.exists()) {
      final entities = backupsDir.listSync();
      for (var entity in entities) {
        if (entity is File && entity.path.endsWith('.zip')) {
          final bName = p.basename(entity.path);
          if (bName == fileName || bName.startsWith('yedek_${safeYear}_')) {
            try {
              if (await entity.exists()) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      }
    }

    await backupFile.writeAsBytes(zipData);

    return backupFile;
  }

  /// Telefonda kayıtlı tüm yerel yedekleri listeler (Eğitim öğretim yılına göre benzersiz)
  static Future<List<BackupItemInfo>> listLocalBackups() async {
    final backupsDir = await getBackupsDirectory();
    if (!await backupsDir.exists()) return [];

    final list = <BackupItemInfo>[];
    final entities = backupsDir.listSync();

    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.zip')) {
        try {
          final bytes = await entity.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);

          String academicYear = 'Bilinmeyen Yıl';
          DateTime createdAt = entity.lastModifiedSync();
          int classCount = 0;
          int studentCount = 0;
          int photoCount = 0;

          final metaFile = archive.findFile('metadata.json');
          if (metaFile != null) {
            final jsonStr = utf8.decode(metaFile.content as List<int>);
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            academicYear = map['academic_year']?.toString() ?? academicYear;
            if (map['created_at'] != null) {
              createdAt = DateTime.tryParse(map['created_at'].toString()) ?? createdAt;
            }
            classCount = (map['class_count'] as num?)?.toInt() ?? 0;
            studentCount = (map['student_count'] as num?)?.toInt() ?? 0;
            photoCount = (map['photo_count'] as num?)?.toInt() ?? 0;
          } else {
            // Dosya adından tahmin et: yedek_2024-2025.zip veya yedek_2024-2025_...
            final base = p.basenameWithoutExtension(entity.path);
            final parts = base.split('_');
            if (parts.length >= 2) {
              academicYear = parts[1];
            }
          }

          list.add(BackupItemInfo(
            file: entity,
            fileName: p.basename(entity.path),
            academicYear: academicYear,
            createdAt: createdAt,
            fileSize: bytes.length,
            classCount: classCount,
            studentCount: studentCount,
            photoCount: photoCount,
          ));
        } catch (_) {
          // Bozuk veya uyumsuz zip dosyalarını geç
        }
      }
    }

    // En yeni tarihli en üstte
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Eğitim öğretim yılına göre benzersiz kayıtları tut (aynı yıl varsa en yenisini koru, mükerrerleri sil)
    final uniqueMap = <String, BackupItemInfo>{};
    for (var item in list) {
      final key = item.academicYear.trim().toLowerCase();
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = item;
      } else {
        // Eski mükerrer dosyayı temizle
        try {
          if (item.file.existsSync()) {
            item.file.deleteSync();
          }
        } catch (_) {}
      }
    }

    final uniqueList = uniqueMap.values.toList();
    uniqueList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return uniqueList;
  }

  /// Seçili yedekten geri yükleme yapar (DB + Fotoğraflar)
  static Future<bool> restoreFromBackup(File backupZipFile) async {
    if (!await backupZipFile.exists()) {
      throw Exception('Yedek dosyası bulunamadı.');
    }

    final bytes = await backupZipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbArchiveFile = archive.findFile('database.db');
    if (dbArchiveFile == null) {
      throw Exception('Yedek arşivinde veritabanı (database.db) bulunamadı.');
    }

    // 1. Veritabanını kapat
    await DatabaseHelper.instance.closeDatabase();

    // 2. Mevcut veritabanı dosyasını ve wal/shm dosyalarını temizle/üzerine yaz
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'ogretmencep.db');
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
    if (await shmFile.exists()) {
      try {
        await shmFile.delete();
      } catch (_) {}
    }

    final targetDbFile = File(dbPath);
    await targetDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

    // 3. Fotoğrafları geri yükle
    final photosDir = await getPhotosDirectory();
    if (await photosDir.exists()) {
      try {
        await photosDir.delete(recursive: true);
      } catch (_) {}
    }
    await photosDir.create(recursive: true);

    for (var file in archive) {
      if (file.name.startsWith('photos/') && !file.name.endsWith('/')) {
        final relName = p.basename(file.name);
        if (relName.isNotEmpty) {
          final outFile = File(p.join(photosDir.path, relName));
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }
    }

    // 4. Veritabanını tekrar aç
    await DatabaseHelper.instance.database;
    return true;
  }

  /// Yeni eğitim öğretim yılı için tüm sınıf, öğrenci ve ders verilerini sıfırlar
  static Future<void> clearAcademicYearData() async {
    await DatabaseHelper.instance.clearAcademicYearData();

    // Fotoğrafları temizle
    final photosDir = await getPhotosDirectory();
    if (await photosDir.exists()) {
      final files = photosDir.listSync(recursive: true);
      for (var f in files) {
        if (f is File) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
  }

  /// Belirtilen yedeği telefon hafızasından siler
  static Future<void> deleteBackup(File backupZipFile) async {
    if (await backupZipFile.exists()) {
      await backupZipFile.delete();
    }
  }
}
