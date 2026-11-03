import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_provider.dart';
import '../../providers/classes_provider.dart';
import '../../theme/app_theme.dart';

class BulkAllClassesImportDialog extends StatefulWidget {
  const BulkAllClassesImportDialog({Key? key}) : super(key: key);

  @override
  State<BulkAllClassesImportDialog> createState() => _BulkAllClassesImportDialogState();
}

class _BulkAllClassesImportDialogState extends State<BulkAllClassesImportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pasteCtrl = TextEditingController();

  bool _isParsed = false;
  bool _isLoadingFile = false;
  bool _isSaving = false;
  bool _updateIfExists = true;

  // Parsed classes: List of { 'class_name': '9-A', 'students': [ { 'student_no': ..., ... } ] }
  List<Map<String, dynamic>> _parsedClasses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  // Örnek Excel Şablonu Oluştur ve Paylaş
  Future<void> _exportSampleExcelTemplate() async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Tüm Sınıflar ve Öğrenciler';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Başlıklar
      sheet.appendRow([
        TextCellValue('Sınıf'),
        TextCellValue('Öğrenci No'),
        TextCellValue('Ad'),
        TextCellValue('Soyad'),
        TextCellValue('Cinsiyet (K/E)'),
        TextCellValue('Veli Adı'),
        TextCellValue('Veli Telefonu'),
        TextCellValue('Ders'),
      ]);

      // Örnek Satırlar
      final sampleRows = [
        ['9-A', '101', 'Ahmet', 'Yılmaz', 'E', 'Mehmet Yılmaz', '05551112233', 'Matematik'],
        ['9-A', '102', 'Ayşe', 'Kaya', 'K', 'Fatma Kaya', '05552223344', 'Matematik'],
        ['9-B', '103', 'Burak', 'Demir', 'E', 'Ahmet Demir', '05553334455', 'Matematik'],
        ['10-A', '201', 'Zeynep', 'Çelik', 'K', 'Emine Çelik', '05554445566', 'Geometri'],
        ['10-A', '202', 'Emre', 'Şahin', 'E', 'Murat Şahin', '05555556677', 'Geometri'],
        ['11-C', '301', 'Elif', 'Yıldız', 'K', 'Hasan Yıldız', '05556667788', 'Rehberlik'],
      ];

      for (var row in sampleRows) {
        sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/Ornek_Sinif_ve_Ogrenci_Sablonu.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'ÖğretmenCep - Tüm Sınıf ve Öğrenci Excel Şablonu',
        subject: 'Ornek_Sinif_ve_Ogrenci_Sablonu.xlsx',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şablon oluşturulurken hata: $e')),
        );
      }
    }
  }

  // Excel Dosyası Seç ve Ayrıştır
  Future<void> _pickAndParseExcelFile() async {
    setState(() => _isLoadingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoadingFile = false);
        return;
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Dosya içeriği okunamadı.');
      }

      final excel = Excel.decodeBytes(bytes);
      final Map<String, List<Map<String, dynamic>>> classMap = {};

      for (var tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        // Başlık satırını bul
        int headerRowIdx = -1;
        int colClass = -1;
        int colNo = -1;
        int colFirst = -1;
        int colLast = -1;
        int colGender = -1;
        int colGuardian = -1;
        int colPhone = -1;
        int colSubject = -1;

        for (int r = 0; r < sheet.rows.length && r < 5; r++) {
          final row = sheet.rows[r];
          for (int c = 0; c < row.length; c++) {
            final val = row[c]?.value?.toString().trim().toLowerCase() ?? '';
            if (val.isEmpty) continue;

            if (val.contains('sınıf') || val.contains('sinif') || val.contains('şube') || val.contains('sube')) {
              colClass = c;
            } else if (val.contains('no') || val.contains('numara')) {
              colNo = c;
            } else if (val.contains('ad') && !val.contains('soyad') && !val.contains('veli')) {
              colFirst = c;
            } else if (val.contains('soyad')) {
              colLast = c;
            } else if (val.contains('cinsiyet') || val == 'cins' || val == 'k/e') {
              colGender = c;
            } else if (val.contains('veli') && !val.contains('tel')) {
              colGuardian = c;
            } else if (val.contains('tel') || val.contains('telefon') || val.contains('gsm')) {
              colPhone = c;
            } else if (val.contains('ders') || val.contains('branş') || val.contains('brans')) {
              colSubject = c;
            }
          }

          // Eğer Ad veya No sütunları bulunduysa burası başlık satırıdır
          if (colFirst != -1 || colNo != -1) {
            headerRowIdx = r;
            break;
          }
        }

        // Eğer başlık satırı bulunamadıysa varsayılan sütun indeksleri (Sınıf: 0, No: 1, Ad: 2, Soyad: 3)
        final startIdx = (headerRowIdx != -1) ? headerRowIdx + 1 : 0;
        final isSheetNameAClass = (colClass == -1);

        for (int r = startIdx; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.isEmpty) continue;

          String className = isSheetNameAClass
              ? tableName.trim()
              : (colClass != -1 && colClass < row.length
                  ? (row[colClass]?.value?.toString().trim() ?? '')
                  : tableName.trim());

          if (className.toLowerCase().contains('sheet') && !isSheetNameAClass && colClass == -1) {
            continue;
          }

          final no = (colNo != -1 && colNo < row.length)
              ? (row[colNo]?.value?.toString().trim() ?? '')
              : (row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '');

          final first = (colFirst != -1 && colFirst < row.length)
              ? (row[colFirst]?.value?.toString().trim() ?? '')
              : (row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '');

          final last = (colLast != -1 && colLast < row.length)
              ? (row[colLast]?.value?.toString().trim() ?? '')
              : (row.length > 3 ? (row[3]?.value?.toString().trim() ?? '') : '');

          if (no.isEmpty || first.isEmpty) continue;

          // Başlık satırı kelimeleri ise atla
          if (no.toLowerCase().contains('no') || first.toLowerCase().contains('ad')) continue;

          String gender = 'M';
          if (colGender != -1 && colGender < row.length) {
            final g = row[colGender]?.value?.toString().trim().toUpperCase() ?? '';
            if (g == 'K' || g == 'F' || g.startsWith('KIZ')) gender = 'F';
          }

          String? guardian;
          if (colGuardian != -1 && colGuardian < row.length) {
            guardian = row[colGuardian]?.value?.toString().trim();
          }

          String? phone;
          if (colPhone != -1 && colPhone < row.length) {
            phone = row[colPhone]?.value?.toString().trim();
          }

          String? subject;
          if (colSubject != -1 && colSubject < row.length) {
            subject = row[colSubject]?.value?.toString().trim();
          }

          if (className.isEmpty) className = 'Genel Sınıf';

          classMap.putIfAbsent(className, () => []);
          classMap[className]!.add({
            'student_no': no,
            'first_name': first,
            'last_name': last,
            'gender': gender,
            'guardian_name': guardian,
            'guardian_phone': phone,
            'subject': subject,
          });
        }
      }

      _processClassMapToResult(classMap);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel okuma hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFile = false);
    }
  }

  // Yapıştırılan Metni Ayrıştır
  void _parsePastedText() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen içe aktarılacak metni yapıştırın.')),
      );
      return;
    }

    final lines = const LineSplitter().convert(text);
    final Map<String, List<Map<String, dynamic>>> classMap = {};

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      List<String> parts = [];
      if (trimmed.contains('\t')) {
        parts = trimmed.split('\t');
      } else if (trimmed.contains(';')) {
        parts = trimmed.split(';');
      } else if (trimmed.contains(',')) {
        parts = trimmed.split(',');
      } else {
        parts = trimmed.split(RegExp(r'\s{2,}')); // 2 veya daha fazla boşluk
        if (parts.length < 3) {
          parts = trimmed.split(' ');
        }
      }

      parts = parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length < 3) continue;

      // Başlık satırı kontrolü
      final p0 = parts[0].toLowerCase();
      final p1 = parts[1].toLowerCase();
      if (p0.contains('sınıf') || p0.contains('sinif') || p0.contains('şube') || p1.contains('no') || p1.contains('ad')) {
        continue;
      }

      // Format: Sınıf | No | Ad | [Soyad] | [Cinsiyet] | [Veli] | [Telefon]
      final className = parts[0];
      final no = parts[1];
      final first = parts[2];
      final last = parts.length > 3 ? parts[3] : '';

      String gender = 'M';
      String? guardian;
      String? phone;

      if (parts.length > 4) {
        final g = parts[4].toUpperCase();
        if (g == 'K' || g == 'F' || g == 'KIZ') {
          gender = 'F';
        } else if (g == 'E' || g == 'M' || g == 'ERKEK') {
          gender = 'M';
        } else {
          guardian = parts[4];
        }
      }

      if (parts.length > 5) {
        if (guardian == null) {
          guardian = parts[5];
        } else {
          phone = parts[5];
        }
      }

      if (parts.length > 6 && phone == null) {
        phone = parts[6];
      }

      classMap.putIfAbsent(className, () => []);
      classMap[className]!.add({
        'student_no': no,
        'first_name': first,
        'last_name': last,
        'gender': gender,
        'guardian_name': guardian,
        'guardian_phone': phone,
      });
    }

    _processClassMapToResult(classMap);
  }

  void _processClassMapToResult(Map<String, List<Map<String, dynamic>>> classMap) {
    if (classMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli sınıf veya öğrenci satırı bulunamadı.')),
      );
      return;
    }

    final List<Map<String, dynamic>> result = [];
    classMap.forEach((className, students) {
      if (students.isNotEmpty) {
        // Otomatik kademe tespiti (Örn: '10-A' -> '10')
        final gradeMatch = RegExp(r'\d+').firstMatch(className);
        final grade = gradeMatch != null ? gradeMatch.group(0)! : '9';
        final subject = students.first['subject'] as String?;

        result.add({
          'class_name': className,
          'grade_level': grade,
          'subject': subject,
          'students': students,
        });
      }
    });

    setState(() {
      _parsedClasses = result;
      _isParsed = true;
    });
  }

  Future<void> _handleSave() async {
    if (_parsedClasses.isEmpty) return;

    setState(() => _isSaving = true);
    final classesProv = context.read<ClassesProvider>();
    final appProv = context.read<AppProvider>();

    final res = await classesProv.bulkImportAllClassesAndStudents(
      classList: _parsedClasses,
      defaultAcademicYear: appProv.activeAcademicYear,
      updateIfExists: _updateIfExists,
    );

    setState(() => _isSaving = false);
    if (!mounted) return;

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.posLight,
        content: Text(
          'Toplu aktarım tamamlandı: ${res['classes_created']} yeni sınıf, ${res['students_created']} yeni öğrenci eklendi (${res['students_updated']} güncellendi).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalStudents = _parsedClasses.fold<int>(0, (sum, c) => sum + (c['students'] as List).length);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Başlığı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('📊', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplu Sınıf & Öğrenci Aktar',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Tek seferde tüm sınıflarınızı ve öğrencilerinizi sisteme aktarın',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
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
            const SizedBox(height: 12),

            if (!_isParsed) ...[
              // Sekmeler: Excel Dosyası / Panodan Yapıştır
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.brandLight,
                labelColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                unselectedLabelColor: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Excel Dosyası (.xlsx)'),
                  Tab(icon: Icon(Icons.paste_rounded, size: 18), text: 'Panodan Metin Yapıştır'),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Excel Dosyası Yükleme
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                              const Text(
                                '📁 Excel Dosyası Biçimi:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Excel tablonuzda "Sınıf", "Öğrenci No", "Ad", "Soyad" sütunlarının olması yeterlidir. Sistem sınıfları ve öğrencileri otomatik gruplar.',
                                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoadingFile) ...[
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  const Text('Excel dosyası inceleniyor...', style: TextStyle(fontSize: 12)),
                                ] else ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: _pickAndParseExcelFile,
                                    icon: const Icon(Icons.upload_file_rounded, size: 28),
                                    label: const Text(
                                      'Excel Dosyası Seç (.xlsx, .csv)',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextButton.icon(
                                    onPressed: _exportSampleExcelTemplate,
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: const Text(
                                      'Örnek Excel Şablonunu İndir / Paylaş',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: Metin Yapıştırma
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                          ),
                          child: const Text(
                            '💡 e-Okul veya tablonuzdan sütunları kopyalayıp buraya yapıştırın.\nFormat: Sınıf  No  Ad  Soyad  [Cinsiyet]  [Veli]',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _pasteCtrl,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: "9-A\t101\tAhmet\tYılmaz\tE\n9-A\t102\tAyşe\tKaya\tK\n10-B\t201\tBurak\tDemir\tE",
                              fillColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _parsePastedText,
                          icon: const Icon(Icons.table_view_rounded),
                          label: const Text('Metni Ayrıştır ve Önizle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Önizleme Ekranı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.posLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.posLight.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_parsedClasses.length} Sınıf, $totalStudents Öğrenci Bulundu',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        const Text(
                          'Aşağıdaki listeden sınıfları kontrol edip onaylayabilirsiniz.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _isParsed = false),
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Yeniden Seç', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView.separated(
                  itemCount: _parsedClasses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final cls = _parsedClasses[i];
                    final stList = (cls['students'] as List);

                    return Card(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        initiallyExpanded: i == 0,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.brandLight,
                          child: Text(
                            cls['grade_level'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          cls['class_name'],
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${stList.length} Öğrenci',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: stList.length,
                              itemBuilder: (context, sIdx) {
                                final st = stList[sIdx];
                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Text(
                                    '#${st['student_no']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  title: Text(
                                    '${st['first_name']} ${st['last_name']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(
                                    st['gender'] == 'F' ? 'Kız' : 'Erkek',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Seçenekler
              CheckboxListTile(
                value: _updateIfExists,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Aynı numaralı öğrenci varsa bilgilerini güncelle',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) => setState(() => _updateIfExists = val ?? true),
              ),
              const SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_isSaving ? 'Kaydediliyor...' : 'Tüm Sınıfları ve Öğrencileri Sisteme Ekle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
