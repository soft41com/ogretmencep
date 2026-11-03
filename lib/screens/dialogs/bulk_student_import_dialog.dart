import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/students_provider.dart';
import '../../theme/app_theme.dart';

class BulkStudentImportDialog extends StatefulWidget {
  final ClassModel targetClass;

  const BulkStudentImportDialog({Key? key, required this.targetClass}) : super(key: key);

  @override
  State<BulkStudentImportDialog> createState() => _BulkStudentImportDialogState();
}

class _BulkStudentImportDialogState extends State<BulkStudentImportDialog> {
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> _parsedStudents = [];
  bool _updateIfExists = false;
  bool _isParsed = false;
  bool _isSaving = false;

  void _parseText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen yapıştırılan öğrenci listesini girin.')),
      );
      return;
    }

    final lines = const LineSplitter().convert(text);
    final List<Map<String, dynamic>> result = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Sekme (\t), noktalı virgül (;) veya virgül (,) ile ayır
      List<String> parts = [];
      if (trimmed.contains('\t')) {
        parts = trimmed.split('\t');
      } else if (trimmed.contains(';')) {
        parts = trimmed.split(';');
      } else if (trimmed.contains(',')) {
        parts = trimmed.split(',');
      } else {
        parts = trimmed.split(RegExp(r'\s+'));
      }

      parts = parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) continue;

      // Başlık satırını atla (No, Ad, Soyad vb.)
      final first = parts.first.toLowerCase();
      if (first.contains('no') || first.contains('numara') || first.contains('öğrenci')) {
        continue;
      }

      String no = parts.isNotEmpty ? parts[0] : '';
      String firstName = parts.length > 1 ? parts[1] : '';
      String lastName = parts.length > 2 ? parts[2] : '';
      String gender = 'M';
      String? guardianName;
      String? guardianPhone;

      // Cinsiyet veya Veli tespiti
      if (parts.length > 3) {
        final g = parts[3].toUpperCase();
        if (g == 'K' || g == 'F' || g == 'KIZ') {
          gender = 'F';
        } else if (g == 'E' || g == 'M' || g == 'ERKEK') {
          gender = 'M';
        } else {
          guardianName = parts[3];
        }
      }

      if (parts.length > 4) {
        guardianPhone = parts[4];
      }

      if (no.isNotEmpty && firstName.isNotEmpty) {
        result.add({
          'student_no': no,
          'first_name': firstName,
          'last_name': lastName,
          'gender': gender,
          'guardian_name': guardianName,
          'guardian_phone': guardianPhone,
        });
      }
    }

    setState(() {
      _parsedStudents = result;
      _isParsed = true;
    });

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli öğrenci satırı tespit edilemedi.')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (_parsedStudents.isEmpty) return;

    setState(() => _isSaving = true);
    final provider = context.read<StudentsProvider>();

    final res = await provider.bulkImportStudents(
      classId: widget.targetClass.id,
      studentList: _parsedStudents,
      updateIfExists: _updateIfExists,
    );

    setState(() => _isSaving = false);
    if (!mounted) return;

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.posLight,
        content: Text(
          'Toplu aktarım tamamlandı: ${res['created']} yeni eklendi, ${res['updated']} güncellendi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.posLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('📊', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplu Öğrenci Aktar',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        '${widget.targetClass.name} sınıfına Excel / e-Okul listesi aktarımı',
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isParsed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                ),
                child: const Text(
                  '💡 İpucu: e-Okul veya Excel tablonuzdan öğrenci listesini (Öğrenci No, Ad, Soyad...) kopyalayıp aşağıdaki kutucuğa doğrudan yapıştırın.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: "Örnek:\n101\tAli\tYılmaz\tE\n102\tAyşe\tKaya\tK\n103\tBurak\tDemir\tE",
                    fillColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _parseText,
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('Listeyi Ayrıştır ve Önizle'),
              ),
            ] else ...[
              // Önizleme Ekranı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_parsedStudents.length} Öğrenci Bulundu',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _isParsed = false),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Metni Düzenle', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.separated(
                    itemCount: _parsedStudents.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                    ),
                    itemBuilder: (context, i) {
                      final s = _parsedStudents[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: s['gender'] == 'F' ? Colors.pink.shade100 : Colors.blue.shade100,
                          child: Text(
                            s['gender'] == 'F' ? 'K' : 'E',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: s['gender'] == 'F' ? Colors.pink.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                        title: Text(
                          '${s['first_name']} ${s['last_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        trailing: Text(
                          '#${s['student_no']}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _updateIfExists,
                onChanged: (val) => setState(() => _updateIfExists = val ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Aynı numaralı öğrenci varsa bilgilerini güncelle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isSaving ? 'Kaydediliyor...' : 'Öğrencileri Kaydet (${_parsedStudents.length})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
