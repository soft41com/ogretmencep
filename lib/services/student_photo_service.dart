import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class BulkPhotoResult {
  final int matchedCount;
  final int totalFilesInZip;
  final List<String> matchedStudentNames;
  final List<String> unmatchedFiles;
  final Map<int, String> studentIdToPhotoPath;

  BulkPhotoResult({
    required this.matchedCount,
    required this.totalFilesInZip,
    required this.matchedStudentNames,
    required this.unmatchedFiles,
    required this.studentIdToPhotoPath,
  });
}

class StudentPhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Fotoğrafı 260px genişliğe küçültüp optimize eder ve minimum yer kaplamasını sağlar
  static Future<Uint8List> _minimizeImageBytes(Uint8List rawBytes, {int targetWidth = 260}) async {
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetWidth,
      );
      final frameInfo = await codec.getNextFrame();
      final byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return rawBytes;
      return byteData.buffer.asUint8List();
    } catch (_) {
      // Eğer küçültme sırasında hata olursa ham veriyi döndür
      return rawBytes;
    }
  }

  /// Fotoğrafların kaydedileceği yerel klasör yolunu döndürür
  static Future<Directory> _getPhotoDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${appDocDir.path}/student_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    return photoDir;
  }

  /// Tek bir öğrenci için kamera veya galeriden fotoğraf seçer, küçültür ve kaydeder
  static Future<String?> pickAndSaveStudentPhoto({
    required ImageSource source,
    required int classId,
    required int studentId,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 360,
        maxHeight: 360,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final rawBytes = await pickedFile.readAsBytes();
      final minimizedBytes = await _minimizeImageBytes(rawBytes, targetWidth: 260);

      final photoDir = await _getPhotoDirectory();
      final targetPath = '${photoDir.path}/photo_${classId}_$studentId.jpg';
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(minimizedBytes);

      return targetPath;
    } catch (e) {
      return null;
    }
  }

  /// ZIP dosyasını açar, okul numaralarıyla eşleştirir, fotoğrafları küçülterek kaydeder
  static Future<BulkPhotoResult> processZipBytes({
    required Uint8List zipBytes,
    required int classId,
    required List<StudentModel> students,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final photoDir = await _getPhotoDirectory();

    final Map<int, String> studentIdToPath = {};
    final List<String> matchedNames = [];
    final List<String> unmatchedFiles = [];
    int totalFiles = 0;

    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.bmp'];

    for (final file in archive) {
      if (!file.isFile) continue;

      // macOS veya gizli sistem dosyalarını yoksay
      if (file.name.contains('__MACOSX') || file.name.contains('.DS_Store')) {
        continue;
      }

      // Dosya adını ayıkla (Örn: "photos/101.jpg" -> "101.jpg")
      final fileName = file.name.split('/').last.split('\\').last;
      if (fileName.startsWith('.') || fileName.isEmpty) continue;

      final dotIdx = fileName.lastIndexOf('.');
      if (dotIdx == -1) continue;

      final ext = fileName.substring(dotIdx).toLowerCase();
      if (!validExtensions.contains(ext)) continue;

      totalFiles++;
      final nameOnly = fileName.substring(0, dotIdx).trim();

      // Öğrenci numarası ile eşleştirme
      StudentModel? matchedStudent = _findMatchingStudent(nameOnly, students);

      if (matchedStudent != null) {
        try {
          final contentData = file.content;
          final Uint8List rawBytes = contentData is Uint8List
              ? contentData
              : Uint8List.fromList(contentData as List<int>);
          final minimizedBytes = await _minimizeImageBytes(rawBytes, targetWidth: 260);

          final targetPath = '${photoDir.path}/photo_${classId}_${matchedStudent.id}.jpg';
          final targetFile = File(targetPath);
          await targetFile.writeAsBytes(minimizedBytes);

          studentIdToPath[matchedStudent.id] = targetPath;
          matchedNames.add('${matchedStudent.studentNo} - ${matchedStudent.fullName}');
        } catch (_) {
          unmatchedFiles.add('$fileName (işleme hatası)');
        }
      } else {
        unmatchedFiles.add(fileName);
      }
    }

    return BulkPhotoResult(
      matchedCount: studentIdToPath.length,
      totalFilesInZip: totalFiles,
      matchedStudentNames: matchedNames,
      unmatchedFiles: unmatchedFiles,
      studentIdToPhotoPath: studentIdToPath,
    );
  }

  /// Esnek öğrenci numarası eşleştirme
  /// Örnekler: "101.jpg" -> "101", "0101.jpg" -> "101", "101_Ahmet.jpg" -> "101"
  static StudentModel? _findMatchingStudent(String nameOnly, List<StudentModel> students) {
    // 1. Birebir eşleşme
    for (final s in students) {
      if (s.studentNo.trim().toLowerCase() == nameOnly.toLowerCase()) {
        return s;
      }
    }

    // 2. Baştaki sıfırları atarak tam sayı eşleşmesi (Örn: "0101" -> "101")
    final parsedInt = int.tryParse(nameOnly);
    if (parsedInt != null) {
      for (final s in students) {
        if (int.tryParse(s.studentNo.trim()) == parsedInt) {
          return s;
        }
      }
    }

    // 3. Dosya adı numara ile başlıyorsa (Örn: "101_Ali.jpg" veya "101-Demir.jpg")
    final matchLeading = RegExp(r'^\d+').firstMatch(nameOnly);
    if (matchLeading != null) {
      final leadingStr = matchLeading.group(0)!;
      final leadingInt = int.tryParse(leadingStr);
      for (final s in students) {
        if (s.studentNo.trim() == leadingStr || (leadingInt != null && int.tryParse(s.studentNo.trim()) == leadingInt)) {
          return s;
        }
      }
    }

    return null;
  }

  /// Fotoğraf dosyasını siler
  static Future<void> deletePhotoFile(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) return;
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Öğrencinin fotoğrafını ekranda büyük ve yakınlaştırılabilir şekilde gösterir
  static void showPhotoPreview(BuildContext context, StudentModel student) {
    final photoPath = student.photoPath;
    if (photoPath == null || photoPath.isEmpty || !File(photoPath).existsSync()) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Kısım: Öğrenci Bilgisi ve Kapat Butonu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Okul No: #${student.studentNo} • ${student.gender == "F" ? "Kız Öğrenci" : "Erkek Öğrenci"}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Büyütülmüş Fotoğraf Gövdesi (InteractiveViewer ile zumlanabilir)
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.file(
                        File(photoPath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pinch_rounded, color: Colors.white60, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Fotoğrafı yakınlaştırmak için iki parmakla kıstırabilirsiniz',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
