import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/plans_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/students_provider.dart';
import '../theme/app_theme.dart';
import 'class_detail_screen.dart';
import 'dialogs/bulk_student_import_dialog.dart';
import 'dialogs/bulk_all_classes_import_dialog.dart';
import 'class_statistics_screen.dart';
import 'plans_screen.dart';
import 'student_profile_screen.dart';
import '../services/excel_export_service.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({Key? key}) : super(key: key);

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final TextEditingController _studentSearchCtrl = TextEditingController();
  List<StudentModel> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchingLoading = false;

  final List<Map<String, dynamic>> _colorPalette = [
    {'name': 'Yeşil Marka', 'hex': '#17433B'},
    {'name': 'Zümrüt', 'hex': '#1F8A5B'},
    {'name': 'Mavi', 'hex': '#2563EB'},
    {'name': 'Mor', 'hex': '#7C3AED'},
    {'name': 'Gül Pembesi', 'hex': '#E11D48'},
    {'name': 'Kehribar', 'hex': '#D97706'},
    {'name': 'Koyu Orman', 'hex': '#064E3B'},
    {'name': 'Arduvaz', 'hex': '#475569'},
  ];

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.brandLight;
    }
  }

  void _showAddClassSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final gradeCtrl = TextEditingController(text: '9');
    final subjectCtrl = TextEditingController();
    String selectedColor = '#17433B';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
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
                          'Yeni Sınıf Ekle',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sınıf Adı *',
                        hintText: 'Örn: 9-A, 11-B',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gradeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kademe / Seviye',
                              hintText: '9, 10, 11, 12',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: subjectCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ders / Branş',
                              hintText: 'Örn: Matematik',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Builder(builder: (context) {
                      final appProv = context.read<AppProvider>();
                      if (appProv.subjects.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: appProv.subjects.map((s) {
                            return ActionChip(
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              label: Text(s, style: const TextStyle(fontSize: 10)),
                              onPressed: () => setSheetState(() => subjectCtrl.text = s),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Sınıf Vurgu Rengi',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorPalette.map((item) {
                        final hex = item['hex'] as String;
                        final isSel = selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _parseHex(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: _parseHex(hex).withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sınıf adı zorunludur.')),
                          );
                          return;
                        }

                        final appProv = context.read<AppProvider>();
                        final classesProv = context.read<ClassesProvider>();

                        await classesProv.createClass(
                          name: nameCtrl.text.trim(),
                          gradeLevel: gradeCtrl.text.trim().isEmpty ? '9' : gradeCtrl.text.trim(),
                          subject: subjectCtrl.text.trim(),
                          academicYear: appProv.activeAcademicYear,
                          color: selectedColor,
                        );

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.posLight,
                              content: Text('${nameCtrl.text} sınıfı oluşturuldu.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Sınıfı Oluştur'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditClassSheet(BuildContext context, ClassModel cls) {
    final nameCtrl = TextEditingController(text: cls.name);
    final gradeCtrl = TextEditingController(text: cls.gradeLevel);
    final subjectCtrl = TextEditingController(text: cls.subject ?? '');
    String selectedColor = cls.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
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
                          'Sınıfı Düzenle',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Sınıf Adı *'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gradeCtrl,
                            decoration: const InputDecoration(labelText: 'Kademe'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: subjectCtrl,
                            decoration: const InputDecoration(labelText: 'Ders / Branş'),
                          ),
                        ),
                      ],
                    ),
                    Builder(builder: (context) {
                      final appProv = context.read<AppProvider>();
                      if (appProv.subjects.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: appProv.subjects.map((s) {
                            return ActionChip(
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              label: Text(s, style: const TextStyle(fontSize: 10)),
                              onPressed: () => setSheetState(() => subjectCtrl.text = s),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _colorPalette.map((item) {
                        final hex = item['hex'] as String;
                        final isSel = selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _parseHex(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        await context.read<ClassesProvider>().updateClass(
                              id: cls.id,
                              name: nameCtrl.text.trim(),
                              gradeLevel: gradeCtrl.text.trim(),
                              subject: subjectCtrl.text.trim(),
                              color: selectedColor,
                            );
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Değişiklikleri Kaydet'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _seedTestData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final classesProv = context.read<ClassesProvider>();
    final scheduleProv = context.read<ScheduleProvider>();
    final plansProv = context.read<PlansProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Test Verilerini Yükle', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'Örnek 6 sınıf (9-A, 9-B, 10-A, 10-B, 11-A, 12-A), her sınıfta 30 öğrenci (toplam 180 öğrenci), haftalık ders programı ve 36 haftalık yıllık planlar yüklenecektir. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yükle')),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 4),
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Test verileri yükleniyor... Lütfen bekleyin.'),
          ],
        ),
      ),
    );

    try {
      final res = await DatabaseHelper.instance.seedTestData();

      if (mounted) {
        await classesProv.fetchClasses();
        await scheduleProv.fetchTimetable();
        await plansProv.fetchPlans();

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text(
              '${res['classes']} sınıf, ${res['students']} öğrenci, ${res['timetable_entries']} ders saati ve ${res['plans']} yıllık plan başarıyla yüklendi!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _exportAllStudentsExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Excel dosyası hazırlanıyor...'),
          ],
        ),
      ),
    );

    try {
      await ExcelExportService.exportAllStudentsToExcel();
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text('Tüm sınıf listeleri başarıyla Excel dosyasına aktarıldı.'),
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

  @override
  void dispose() {
    _studentSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performStudentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _isSearchingLoading = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchingLoading = true;
    });

    final results = await context.read<StudentsProvider>().searchAllStudents(trimmed);
    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearchingLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final classesProv = context.watch<ClassesProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınıflar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            onPressed: () => _showAddClassSheet(context),
            tooltip: 'Yeni Sınıf Ekle',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'statistics') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClassStatisticsScreen()),
                );
              } else if (val == 'export_excel') {
                _exportAllStudentsExcel(context);
              } else if (val == 'bulk_import') {
                showDialog(
                  context: context,
                  builder: (_) => const BulkAllClassesImportDialog(),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, size: 20, color: AppTheme.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "İstatistik",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_excel',
                child: Row(
                  children: [
                    Icon(Icons.file_download_rounded, size: 20, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Excel'e Aktar (Tüm Sınıflar)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bulk_import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file_rounded, size: 20, color: AppTheme.posLight),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Excel'den Toplu Aktar",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
      body: Column(
        children: [
          // 🔍 Öğrenci Arama Çubuğu (Tüm Sınıflarda Anında Arama)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _studentSearchCtrl,
              onChanged: _performStudentSearch,
              decoration: InputDecoration(
                hintText: 'Tüm sınıflarda öğrenci ara (Ad, Soyad, No, Veli, Kulüp)...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                ),
                prefixIcon: const Icon(Icons.person_search_rounded, size: 22, color: AppTheme.accent),
                suffixIcon: _studentSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _studentSearchCtrl.clear();
                          _performStudentSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
              ),
            ),
          ),

          // Gövde İçeriği: Arama Sonuçları veya Sınıflar Listesi
          Expanded(
            child: _isSearching
                ? _buildSearchResults(context, isDark)
                : _buildClassesList(context, classesProv, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, bool isDark) {
    if (_isSearchingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Eşleşen Öğrenci Bulunamadı',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '"${_studentSearchCtrl.text}" araması ile eşleşen öğrenci numarası, adı, soyadı, kulübü veya veli bilgisi bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bulunan Öğrenciler (${_searchResults.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.accent),
              ),
              Text(
                'Profile gitmek için dokunun',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final student = _searchResults[i];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentProfileScreen(
                          student: student,
                        ),
                      ),
                    );
                    if (mounted) {
                      _performStudentSearch(_studentSearchCtrl.text);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        GestureAvatar(student: student, radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '#${student.studentNo}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      student.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (student.className != null && student.className!.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandLight.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.brandLight.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        student.className!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          color: AppTheme.brandLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (student.club != null && student.club!.isNotEmpty) ...[
                                    const Icon(Icons.diversity_3_rounded, size: 12, color: AppTheme.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      student.club!,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (student.guardianName != null && student.guardianName!.isNotEmpty) ...[
                                    Icon(Icons.person_pin_circle_outlined, size: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Veli: ${student.guardianName}',
                                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassesList(BuildContext context, ClassesProvider classesProv, bool isDark) {
    if (classesProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (classesProv.classes.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👥', style: TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Henüz Sınıfınız Bulunmuyor',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Öğrencilerinizi organize etmek için ilk sınıfınızı ekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showAddClassSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Sınıf Ekle'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const BulkAllClassesImportDialog(),
                  );
                },
                icon: const Icon(Icons.table_chart_rounded, size: 16),
                label: const Text("Excel'den Toplu Sınıf & Öğrenci Aktar", style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 12),
              // Gri renkle, sade ve kompakt Test Verilerini Yükle butonu
              OutlinedButton.icon(
                onPressed: () => _seedTestData(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  side: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 15,
                  color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                ),
                label: const Text(
                  'Örnek Test Verilerini Yükle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classesProv.classes.length,
      itemBuilder: (context, i) {
        final cls = classesProv.classes[i];
        final classColor = _parseHex(cls.color);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassDetailScreen(classModel: cls),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: classColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cls.gradeLevel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cls.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cls.subject ?? 'Ders belirtilmedi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (val) {
                          if (val == 'bulk_student') {
                            showDialog(
                              context: context,
                              builder: (_) => BulkStudentImportDialog(targetClass: cls),
                            ).then((_) {
                              context.read<ClassesProvider>().fetchClasses();
                            });
                          } else if (val == 'plan') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlansScreen(initialClassId: cls.id),
                              ),
                            );
                          } else if (val == 'edit') {
                            _showEditClassSheet(context, cls);
                          } else if (val == 'delete') {
                            context.read<ClassesProvider>().deleteClass(cls.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'bulk_student',
                            child: Row(
                              children: [
                                Icon(Icons.upload_file_rounded, size: 18, color: AppTheme.accent),
                                SizedBox(width: 8),
                                Text("Toplu Öğrenci Aktar (Excel)"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'plan',
                            child: Row(
                              children: [
                                Icon(Icons.menu_book_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Yıllık Planı Gör'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Düzenle'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: AppTheme.negLight),
                                SizedBox(width: 8),
                                Text('Sil', style: TextStyle(color: AppTheme.negLight)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '👤 ${cls.studentCount} Öğrenci',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Öğrencileri Gör',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.accent : AppTheme.brandLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: isDark ? AppTheme.accent : AppTheme.brandLight,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
