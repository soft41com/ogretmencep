import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/exams_provider.dart';
import '../providers/students_provider.dart';
import '../services/excel_export_service.dart';
import '../services/turkish_search_helper.dart';
import '../theme/app_theme.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({Key? key}) : super(key: key);

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassesProvider>().fetchClasses();
      context.read<ExamsProvider>().fetchExams();
    });
  }

  void _showAddExamSheet(BuildContext context, {ClassModel? preselectedClass}) {
    final classes = context.read<ClassesProvider>().classes;
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerlendirme eklemek için önce bir sınıf oluşturmalısınız.')),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: '1. Yazılı Sınav');
    ClassModel selectedClass = preselectedClass ?? classes.first;
    String examType = 'written';
    DateTime examDate = DateTime.now();

    final presets = [
      {'title': '1. Yazılı Sınav', 'type': 'written', 'label': '1. Yazılı', 'icon': '📝'},
      {'title': '2. Yazılı Sınav', 'type': 'written', 'label': '2. Yazılı', 'icon': '📝'},
      {'title': '1. Sözlü / Katılım', 'type': 'oral', 'label': '1. Sözlü', 'icon': '🗣️'},
      {'title': '2. Sözlü / Katılım', 'type': 'oral', 'label': '2. Sözlü', 'icon': '🗣️'},
      {'title': '1. Performans Görevi', 'type': 'performance', 'label': 'Performans 1', 'icon': '⭐'},
      {'title': '2. Performans Görevi', 'type': 'performance', 'label': 'Performans 2', 'icon': '⭐'},
      {'title': 'Proje Ödevi', 'type': 'project', 'label': 'Proje', 'icon': '🎨'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Yeni Değerlendirme / Sınav',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Sınıf & Ders Seçimi
                      DropdownButtonFormField<int>(
                        value: selectedClass.id,
                        decoration: const InputDecoration(labelText: 'Hedef Sınıf & Ders'),
                        items: classes.map((c) {
                          final subjectInfo = c.subject != null && c.subject!.isNotEmpty ? ' (${c.subject})' : '';
                          return DropdownMenuItem(value: c.id, child: Text('${c.name}$subjectInfo'));
                        }).toList(),
                        onChanged: preselectedClass != null
                            ? null
                            : (val) {
                                if (val != null) {
                                  setSheetState(() {
                                    selectedClass = classes.firstWhere((c) => c.id == val);
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      // Hızlı Şablon Butonları
                      const Text(
                        'Hızlı Seçim Şablonları:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presets.map((p) {
                          final isSelected = titleCtrl.text == p['title'];
                          return ActionChip(
                            avatar: Text(p['icon']!, style: const TextStyle(fontSize: 13)),
                            label: Text(
                              p['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? (isDark ? AppTheme.brandDark : Colors.white)
                                    : (isDark ? AppTheme.inkDark : AppTheme.inkLight),
                              ),
                            ),
                            backgroundColor: isSelected
                                ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                                : (isDark ? AppTheme.cardDark : AppTheme.bgLight),
                            onPressed: () {
                              setSheetState(() {
                                titleCtrl.text = p['title']!;
                                examType = p['type']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Değerlendirme Başlığı *',
                          hintText: 'Örn: 1. Dönem 1. Yazılı',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: examType,
                              decoration: const InputDecoration(labelText: 'Türü'),
                              items: const [
                                DropdownMenuItem(value: 'written', child: Text('Yazılı Sınav')),
                                DropdownMenuItem(value: 'oral', child: Text('Sözlü / Katılım')),
                                DropdownMenuItem(value: 'performance', child: Text('Performans')),
                                DropdownMenuItem(value: 'project', child: Text('Proje Ödevi')),
                              ],
                              onChanged: (val) => setSheetState(() => examType = val ?? 'written'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                DateFormat('dd.MM.yyyy').format(examDate),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: examDate,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime(2030),
                                  locale: const Locale('tr', 'TR'),
                                );
                                if (picked != null) {
                                  setSheetState(() => examDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          await context.read<ExamsProvider>().createExam(
                                classId: selectedClass.id,
                                title: titleCtrl.text.trim(),
                                type: examType,
                                examDate: DateFormat('yyyy-MM-dd').format(examDate),
                              );
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.posLight,
                                content: Text('${selectedClass.name} dersine "${titleCtrl.text.trim()}" eklendi.'),
                              ),
                            );
                          }
                        },
                        child: const Text('Değerlendirmeyi Ekle'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Sınav Not Giriş Modalı
  void _openScoreEntrySheet(BuildContext context, ExamModel exam, ClassModel targetClass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScoreEntryModal(exam: exam, targetClass: targetClass),
    );
  }

  // Tüm Sınıf Not Çizelgesi (Matrix Not Tablosu)
  void _openClassGradeMatrix(BuildContext context, ClassModel classModel, List<ExamModel> classExams) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ClassGradeMatrixSheet(
        targetClass: classModel,
        exams: classExams,
        onOpenScoreEntry: (exam) => _openScoreEntrySheet(context, exam, classModel),
      ),
    );
  }

  Future<void> _exportExamGradesExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Not çizelgesi Excel olarak hazırlanıyor...'),
          ],
        ),
      ),
    );

    try {
      await ExcelExportService.exportExamGradesToExcel();
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text('Not çizelgesi başarıyla Excel dosyasına aktarıldı.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _importExamGradesExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ExcelExportService.importExamGradesFromExcel();
      if (mounted) {
        if (res.success) {
          await context.read<ExamsProvider>().fetchExams();
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.posLight,
              content: Text(res.message),
            ),
          );
        } else if (res.message != 'Dosya seçilmedi.') {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.negLight,
              content: Text(res.message),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('İçe aktarma hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesProv = context.watch<ClassesProvider>();
    final examsProv = context.watch<ExamsProvider>();
    final appProv = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final classes = classesProv.classes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınavlar & Notlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded, size: 26, color: Colors.green),
            onPressed: _exportExamGradesExcel,
            tooltip: "Not Çizelgesini Excel'e Aktar",
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_rounded, size: 26, color: Colors.blue),
            onPressed: _importExamGradesExcel,
            tooltip: "Excel'den Not Yükle / Güncelle",
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
            onPressed: () => _showAddExamSheet(context),
            tooltip: 'Yeni Değerlendirme Ekle',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'export_excel') {
                _exportExamGradesExcel();
              } else if (val == 'import_excel') {
                _importExamGradesExcel();
              } else if (val == 'add_exam') {
                _showAddExamSheet(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export_excel',
                child: Row(
                  children: [
                    Icon(Icons.file_download_rounded, size: 20, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Not Çizelgesini Excel'e Aktar",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_excel',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Excel'den Not Yükle / Güncelle",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_exam',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Yeni Değerlendirme Ekle',
                        style: TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: examsProv.isLoading || classesProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🏫', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        const Text('Henüz Sınıf Eklenmedi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'Sınav ve değerlendirme notları eklemek için önce Sınıflar sayfasından bir sınıf oluşturmalısınız.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: classes.length,
                  itemBuilder: (context, idx) {
                    final c = classes[idx];
                    final classExams = examsProv.exams.where((e) => e.classId == c.id).toList();

                    // Sınıfın bu dersine ait girilmiş sınavların genel ortalaması
                    final scoredExams = classExams.where((e) => e.averageScore > 0).toList();
                    final double classSubjectAverage = scoredExams.isNotEmpty
                        ? scoredExams.map((e) => e.averageScore).reduce((a, b) => a + b) / scoredExams.length
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sınıf ve Ders Başlığı Satırı
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isDark ? AppTheme.accent : AppTheme.brandLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.subject != null && c.subject!.isNotEmpty ? c.subject! : 'Ders Belirtilmedi',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${appProv.activeAcademicYear} • ${c.studentCount} Öğrenci',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // + Değerlendirme Ekle Butonu
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showAddExamSheet(context, preselectedClass: c),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Aynı Satırda Değerlendirmeler ve Genel Ortalama
                            if (classExams.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Bu derse henüz sınav/değerlendirme eklenmedi.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.add, size: 16),
                                      onPressed: () => _showAddExamSheet(context, preselectedClass: c),
                                      label: const Text('Şimdi Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    ...classExams.map((ex) {
                                      final hasAvg = ex.averageScore > 0;
                                      final isPos = ex.averageScore >= 50;

                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(14),
                                          onTap: () => _openScoreEntrySheet(context, ex, c),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: (isDark ? AppTheme.lineDark : AppTheme.lineLight),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(_getExamTypeIcon(ex.type), style: const TextStyle(fontSize: 15)),
                                                const SizedBox(width: 6),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      ex.title,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      hasAvg ? 'Ort: ${ex.averageScore.toStringAsFixed(1)}' : 'Not Girilmedi',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: hasAvg
                                                            ? (isPos ? AppTheme.posLight : AppTheme.negLight)
                                                            : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 4),
                                                PopupMenuButton<String>(
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(Icons.more_vert, size: 16),
                                                  onSelected: (val) {
                                                    if (val == 'enter') {
                                                      _openScoreEntrySheet(context, ex, c);
                                                    } else if (val == 'delete') {
                                                      context.read<ExamsProvider>().deleteExam(ex.id, classId: c.id);
                                                    }
                                                  },
                                                  itemBuilder: (ctx) => [
                                                    const PopupMenuItem(value: 'enter', child: Text('Notları Gir / Düzenle')),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text('Sınavı Sil', style: TextStyle(color: AppTheme.negLight)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),

                                    // Satır Sonunda Genel Ortalama Rozeti
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: classSubjectAverage > 0
                                            ? (classSubjectAverage >= 50
                                                ? AppTheme.posLight.withOpacity(0.15)
                                                : AppTheme.negLight.withOpacity(0.15))
                                            : (isDark ? AppTheme.bgDark : AppTheme.bgLight),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: classSubjectAverage > 0
                                              ? (classSubjectAverage >= 50
                                                  ? AppTheme.posLight.withOpacity(0.35)
                                                  : AppTheme.negLight.withOpacity(0.35))
                                              : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Genel Ortalama',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            classSubjectAverage > 0
                                                ? classSubjectAverage.toStringAsFixed(1)
                                                : 'Not Yok',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: classSubjectAverage > 0
                                                  ? (classSubjectAverage >= 50 ? AppTheme.posLight : AppTheme.negLight)
                                                  : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Not Çizelgesi Butonu
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _openClassGradeMatrix(context, c, classExams),
                                    child: const Text('📋 Sınıf Not Çizelgesi (Tüm Notlar)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _getExamTypeIcon(String type) {
    switch (type) {
      case 'written':
        return '📝';
      case 'oral':
        return '🗣️';
      case 'performance':
        return '⭐';
      case 'project':
        return '🎨';
      default:
        return '📄';
    }
  }
}

// ------------------------------------------------------------------------------------------------
// 🎯 NOT GİRİŞ MODALI (Tek rakam sorunu & Klavye altında kalma sorunu çözülmüş)
// ------------------------------------------------------------------------------------------------
class _ScoreEntryModal extends StatefulWidget {
  final ExamModel exam;
  final ClassModel targetClass;

  const _ScoreEntryModal({
    Key? key,
    required this.exam,
    required this.targetClass,
  }) : super(key: key);

  @override
  State<_ScoreEntryModal> createState() => _ScoreEntryModalState();
}

class _ScoreEntryModalState extends State<_ScoreEntryModal> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, double> _localScores = {};
  bool _isLoading = true;
  String _search = '';
  DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final examsProv = context.read<ExamsProvider>();
    final studentsProv = context.read<StudentsProvider>();

    await studentsProv.fetchStudents(widget.exam.classId);
    await examsProv.loadExamScores(widget.exam.id);
    _lastSavedAt = await examsProv.getExamLastSavedAt(widget.exam.id);

    final students = studentsProv.students;
    final existingScores = examsProv.examScores;

    for (final st in students) {
      final sc = existingScores[st.id];
      _localScores[st.id] = sc ?? 0.0;
      final scoreText = (sc != null && sc > 0)
          ? (sc == sc.roundToDouble() ? sc.toInt().toString() : sc.toString())
          : '';
      _controllers[st.id] = TextEditingController(text: scoreText);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _calculateCurrentAverage() {
    final validScores = _localScores.values.where((s) => s > 0).toList();
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a + b) / validScores.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = context.watch<StudentsProvider>().students;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final filteredStudents = students.where((s) {
      if (_search.isEmpty) return true;
      final q = TurkishSearchHelper.toLower(_search.trim());
      return TurkishSearchHelper.contains(s.fullName, q) || s.studentNo.contains(q);
    }).toList();

    final avg = _calculateCurrentAverage();

    return Padding(
      // Klavyenin altına girmeyi önlemek için viewInsets.bottom kadar alt padding
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık & Ortalama
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.exam.title,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.targetClass.name} • Sınıf Ortalaması: ${avg > 0 ? avg.toStringAsFixed(1) : "Henüz not girilmedi"}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: avg >= 50 ? AppTheme.posLight : (avg > 0 ? AppTheme.negLight : AppTheme.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Hızlı Arama
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Öğrenci ara (Ad, No)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (val) => setState(() => _search = val),
                  ),
                  const SizedBox(height: 10),
                  // Öğrenci Not Listesi
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? const Center(child: Text('Öğrenci bulunamadı.'))
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 4, bottom: 20),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final st = filteredStudents[i];
                              final controller = _controllers[st.id] ?? TextEditingController();

                              final hasPhoto = st.photoPath != null &&
                                  st.photoPath!.isNotEmpty &&
                                  File(st.photoPath!).existsSync();

                              return Card(
                                margin: EdgeInsets.zero,
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: st.gender == 'F' ? Colors.pink.shade100 : Colors.blue.shade100,
                                        backgroundImage: hasPhoto ? FileImage(File(st.photoPath!)) : null,
                                        child: hasPhoto
                                            ? null
                                            : Text(
                                                st.firstName.isNotEmpty ? st.firstName[0] : '?',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: st.gender == 'F' ? Colors.pink.shade800 : Colors.blue.shade800,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '#${st.studentNo} ${st.fullName}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      ),
                                      // Not Giriş Alanı (100'e kadar değer girişi)
                                      SizedBox(
                                        width: 80,
                                        child: TextField(
                                          controller: controller,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          textInputAction: i < filteredStudents.length - 1 ? TextInputAction.next : TextInputAction.done,
                                          scrollPadding: const EdgeInsets.all(90),
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                          decoration: InputDecoration(
                                            hintText: '0-100',
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                            isDense: true,
                                          ),
                                          inputFormatters: [
                                            // Sadece 0-100 arası sayılara izin verir
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
                                          ],
                                          onChanged: (val) {
                                            if (val.trim().isEmpty) {
                                              _localScores[st.id] = 0.0;
                                            } else {
                                              var numVal = double.tryParse(val) ?? 0.0;
                                              if (numVal > 100) {
                                                numVal = 100.0;
                                                controller.text = '100';
                                                controller.selection = TextSelection.fromPosition(
                                                  const TextPosition(offset: 3),
                                                );
                                              }
                                              _localScores[st.id] = numVal;
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Son Kaydedilme Zamanı Bilgisi
                  if (_lastSavedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Son Kayıt: ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(_lastSavedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Kaydet Butonu
                  ElevatedButton(
                    onPressed: () async {
                      await context.read<ExamsProvider>().saveExamScores(widget.exam.id, _localScores);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.posLight,
                            content: Text('${widget.exam.title} notları kaydedildi.'),
                          ),
                        );
                      }
                    },
                    child: const Text('Notları Kaydet'),
                  ),
                ],
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// 📋 TÜM SINIF NOT ÇİZELGESİ (E-Okul Not Matrisi)
// ------------------------------------------------------------------------------------------------
class _ClassGradeMatrixSheet extends StatefulWidget {
  final ClassModel targetClass;
  final List<ExamModel> exams;
  final Function(ExamModel) onOpenScoreEntry;

  const _ClassGradeMatrixSheet({
    Key? key,
    required this.targetClass,
    required this.exams,
    required this.onOpenScoreEntry,
  }) : super(key: key);

  @override
  State<_ClassGradeMatrixSheet> createState() => _ClassGradeMatrixSheetState();
}

class _ClassGradeMatrixSheetState extends State<_ClassGradeMatrixSheet> {
  bool _isLoading = true;
  Map<int, Map<int, double>> _allScores = {}; // examId -> {studentId: score}
  int? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    final examsProv = context.read<ExamsProvider>();
    final studentsProv = context.read<StudentsProvider>();

    await studentsProv.fetchStudents(widget.targetClass.id);
    final scores = await examsProv.loadClassAllScores(widget.targetClass.id);

    if (mounted) {
      setState(() {
        _allScores = scores;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportClassExcel() async {
    try {
      await ExcelExportService.exportSingleClassExamGradesToExcel(widget.targetClass);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Dışa aktarma hatası: $e')),
        );
      }
    }
  }

  Future<void> _importClassExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    final examsProv = context.read<ExamsProvider>();
    try {
      final res = await ExcelExportService.importExamGradesFromExcel(targetClassId: widget.targetClass.id);
      if (!mounted) return;

      if (res.success) {
        await examsProv.fetchExams();
        await _loadMatrix();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text(res.message),
          ),
        );
      } else if (res.message != 'Dosya seçilmedi.') {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text(res.message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('İçe aktarma hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = context.watch<StudentsProvider>().students;
    final examsProv = context.watch<ExamsProvider>();
    final classExams = examsProv.exams.where((e) => e.classId == widget.targetClass.id).toList();
    final examsToUse = classExams.isNotEmpty ? classExams : widget.exams;

    final classStudents = students.where((s) => s.classId == widget.targetClass.id).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Satır: Başlık ve Kapatma Butonu
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.targetClass.name} Not Çizelgesi',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.targetClass.subject ?? "Ders"} • ${examsToUse.length} Değerlendirme',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Satır: Excel İndir & Excel Yükle Butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.file_download_rounded, size: 18, color: Colors.green),
                  label: const Text('Excel İndir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _exportClassExcel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: AppTheme.brandLight,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.file_upload_rounded, size: 18),
                  label: const Text('Excel Yükle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _importClassExcel,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (classStudents.isEmpty)
            const Expanded(child: Center(child: Text('Sınıfta öğrenci bulunamadı.')))
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columnSpacing: 18,
                    headingRowColor: MaterialStateProperty.all(
                      isDark ? AppTheme.bgDark : AppTheme.bgLight,
                    ),
                    columns: [
                      const DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Öğrenci', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...examsToUse.map((ex) {
                        return DataColumn(
                          label: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onOpenScoreEntry(ex);
                            },
                            child: Row(
                              children: [
                                Text(ex.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_note_rounded, size: 14),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const DataColumn(
                        label: Text(
                          'Ortalama',
                          style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.accent),
                        ),
                      ),
                    ],
                    rows: classStudents.map((st) {
                      final isSelected = _selectedStudentId == st.id;
                      final List<double> studentValidScores = [];

                      final scoreCells = examsToUse.map((ex) {
                        final sc = _allScores[ex.id]?[st.id];
                        if (sc != null && sc > 0) {
                          studentValidScores.add(sc);
                        }
                        return DataCell(
                          Center(
                            child: Text(
                              sc != null && sc > 0 ? (sc == sc.roundToDouble() ? sc.toInt().toString() : sc.toStringAsFixed(1)) : '-',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                fontSize: isSelected ? 13 : 12,
                                color: sc != null && sc > 0
                                    ? (sc >= 50 ? AppTheme.posLight : AppTheme.negLight)
                                    : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                              ),
                            ),
                          ),
                        );
                      }).toList();

                      final studentAvg = studentValidScores.isNotEmpty
                          ? studentValidScores.reduce((a, b) => a + b) / studentValidScores.length
                          : 0.0;

                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: (_) {
                          setState(() {
                            _selectedStudentId = isSelected ? null : st.id;
                          });
                        },
                        color: MaterialStateProperty.resolveWith<Color?>((states) {
                          if (isSelected) {
                            return isDark
                                ? const Color(0xFF1B3D34)
                                : const Color(0xFFDCEDC8).withOpacity(0.75);
                          }
                          return null;
                        }),
                        cells: [
                          DataCell(
                            Text(
                              '#${st.studentNo}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                color: isSelected
                                    ? (isDark ? AppTheme.accent : const Color(0xFF1B5E20))
                                    : null,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              st.fullName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                fontSize: 13,
                                color: isSelected
                                    ? (isDark ? AppTheme.accent : const Color(0xFF1B5E20))
                                    : null,
                              ),
                            ),
                          ),
                          ...scoreCells,
                          DataCell(
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: studentAvg > 0
                                      ? (studentAvg >= 50 ? AppTheme.posLight.withOpacity(0.15) : AppTheme.negLight.withOpacity(0.15))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  studentAvg > 0 ? studentAvg.toStringAsFixed(1) : '-',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: studentAvg > 0
                                        ? (studentAvg >= 50 ? AppTheme.posLight : AppTheme.negLight)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
