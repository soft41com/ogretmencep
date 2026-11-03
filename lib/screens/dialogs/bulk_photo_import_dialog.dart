import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/students_provider.dart';
import '../../services/student_photo_service.dart';
import '../../theme/app_theme.dart';

class BulkPhotoImportDialog extends StatefulWidget {
  final ClassModel targetClass;

  const BulkPhotoImportDialog({Key? key, required this.targetClass}) : super(key: key);

  @override
  State<BulkPhotoImportDialog> createState() => _BulkPhotoImportDialogState();
}

class _BulkPhotoImportDialogState extends State<BulkPhotoImportDialog> {
  bool _isProcessing = false;
  bool _isSaving = false;
  BulkPhotoResult? _result;
  String? _selectedFileName;

  Future<void> _pickAndProcessZipFile() async {
    final students = context.read<StudentsProvider>().students;
    setState(() => _isProcessing = true);

    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final file = pickerResult.files.first;
      _selectedFileName = file.name;

      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('ZIP dosyası okunamadı.');
      }

      final result = await StudentPhotoService.processZipBytes(
        zipBytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        classId: widget.targetClass.id,
        students: students,
      );

      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _applyPhotos() async {
    if (_result == null || _result!.studentIdToPhotoPath.isEmpty) return;

    setState(() => _isSaving = true);
    final studentsProv = context.read<StudentsProvider>();

    try {
      final updatedCount = await studentsProv.bulkUpdatePhotos(
        widget.targetClass.id,
        _result!.studentIdToPhotoPath,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text(
              '$updatedCount öğrencinin fotoğrafı optimize edilerek başarıyla yüklendi.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Kaydetme hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 540,
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.folder_zip_rounded, color: isDark ? AppTheme.accent : AppTheme.brandLight, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplu Fotoğraf Yükle (ZIP)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        '${widget.targetClass.name} • ${widget.targetClass.subject ?? "Ders"}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),

            // Bilgilendirme Kartı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accent),
                      SizedBox(width: 6),
                      Text('Nasıl Hazırlanmalı?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• ZIP dosyasındaki fotoğrafların adı öğrenci numarası olmalıdır (Örn: 101.jpg, 102.png).\n'
                    '• Fotoğraflar otomatik olarak 260px vesikalık boyuta küçültülür ve bellekte minimum yer kaplayacak şekilde optimize edilir.',
                    style: TextStyle(fontSize: 11, height: 1.45, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // İçerik Alanı
            Expanded(
              child: _isProcessing
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('ZIP dosyası açılıyor ve fotoğraflar optimize ediliyor...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )
                  : _result == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.archive_outlined, size: 56, color: AppTheme.brandLight.withOpacity(0.5)),
                              const SizedBox(height: 14),
                              const Text('Fotoğraf ZIP Dosyasını Seçin', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(
                                'e-Okul veya okul arşivinden indirdiğiniz vesikalık fotoğrafları içeren .zip arşivini seçin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _pickAndProcessZipFile,
                                icon: const Icon(Icons.file_open_rounded),
                                label: const Text('ZIP Dosyası Seç (.zip)'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Eşleşme Özet Başlığı
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.posLight.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_result!.matchedCount} Öğrenci Eşleşti',
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.posLight, fontSize: 12),
                                      ),
                                    ),
                                    if (_result!.unmatchedFiles.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.negLight.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_result!.unmatchedFiles.length} Eşleşmeyen',
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.negLight, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _pickAndProcessZipFile,
                                  icon: const Icon(Icons.refresh_rounded, size: 14),
                                  label: Text(_selectedFileName != null ? 'Değiştir ($_selectedFileName)' : 'Başka ZIP Seç', style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Eşleşen Öğrenciler Önizleme Listesi
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                                ),
                                child: ListView(
                                  padding: const EdgeInsets.all(8),
                                  children: [
                                    if (_result!.matchedStudentNames.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Text(
                                          'Eşleşen Öğrenciler:',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.posLight),
                                        ),
                                      ),
                                      ..._result!.matchedStudentNames.map((name) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.posLight),
                                                const SizedBox(width: 6),
                                                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          )),
                                    ],
                                    if (_result!.unmatchedFiles.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Text(
                                          'Sınıfta Eşleşmeyen Dosyalar (Yüklenmeyecek):',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.negLight),
                                        ),
                                      ),
                                      ..._result!.unmatchedFiles.map((file) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.negLight),
                                                const SizedBox(width: 6),
                                                Text(file, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Onay Butonu
                            ElevatedButton.icon(
                              onPressed: _isSaving || _result!.matchedCount == 0 ? null : _applyPhotos,
                              icon: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _isSaving
                                    ? 'Kaydediliyor...'
                                    : '${_result!.matchedCount} Öğrenci Fotoğrafını Kaydet',
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
