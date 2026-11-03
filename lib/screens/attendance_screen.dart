import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../providers/attendance_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/students_provider.dart';
import '../services/excel_export_service.dart';
import '../services/student_photo_service.dart';
import '../theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  final ClassModel? initialClass;

  const AttendanceScreen({Key? key, this.initialClass}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  ClassModel? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final Map<String, Map<String, dynamic>> _statusMeta = {
    'present': {
      'label': 'Geldi',
      'color': AppTheme.posLight,
      'bgLight': const Color(0xFFEFF8F3),
      'bgDark': const Color(0xFF14291F),
      'icon': Icons.check_circle_rounded,
    },
    'absent': {
      'label': 'Gelmedi',
      'color': const Color(0xFFE53935),
      'bgLight': const Color(0xFFFDEDED),
      'bgDark': const Color(0xFF2F1416),
      'icon': Icons.cancel_rounded,
    },
    'late': {
      'label': 'Geç',
      'color': const Color(0xFFFB8C00),
      'bgLight': const Color(0xFFFFF9E6),
      'bgDark': const Color(0xFF2E2413),
      'icon': Icons.access_time_filled_rounded,
    },
    'excused': {
      'label': 'İzinli',
      'color': const Color(0xFF1E88E5),
      'bgLight': const Color(0xFFEAF2FD),
      'bgDark': const Color(0xFF141F2F),
      'icon': Icons.mark_email_read_rounded,
    },
    'sick': {
      'label': 'Raporlu',
      'color': const Color(0xFF8E24AA),
      'bgLight': const Color(0xFFF6EEFB),
      'bgDark': const Color(0xFF26142F),
      'icon': Icons.local_hospital_rounded,
    },
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final classesProv = context.read<ClassesProvider>();
      if (classesProv.classes.isEmpty) {
        await classesProv.fetchClasses();
      }
      if (!mounted) return;
      final classes = classesProv.classes;
      setState(() {
        if (widget.initialClass != null) {
          _selectedClass = widget.initialClass;
        } else if (classes.isNotEmpty) {
          _selectedClass = classes.first;
        }
      });
      _loadData();
    });
  }

  void _loadData() {
    if (_selectedClass == null) {
      final classes = context.read<ClassesProvider>().classes;
      if (classes.isNotEmpty) {
        _selectedClass = classes.first;
      } else {
        return;
      }
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    context.read<StudentsProvider>().fetchStudents(_selectedClass!.id);
    context.read<AttendanceProvider>().loadAttendance(
      classId: _selectedClass!.id,
      date: dateStr,
    );
  }

  void _cycleStudentStatus(int studentId, String currentStatus) {
    const order = ['present', 'absent', 'late', 'excused', 'sick'];
    final idx = order.indexOf(currentStatus);
    final nextStatus = order[(idx + 1) % order.length];
    context.read<AttendanceProvider>().setStudentStatus(studentId, nextStatus);
  }

  Future<void> _handleSave() async {
    final classes = context.read<ClassesProvider>().classes;
    if (_selectedClass == null && classes.isNotEmpty) {
      _selectedClass = classes.first;
    }

    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.negLight,
          content: Text('Lütfen önce bir sınıf seçin.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final students = context.read<StudentsProvider>().students;

    await context.read<AttendanceProvider>().saveAttendance(
      classId: _selectedClass!.id,
      date: dateStr,
      studentList: students,
    );

    setState(() => _isSaving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.posLight,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('${_selectedClass!.name} yoklaması başarıyla kaydedildi.'),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAttendanceReportExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Devamsızlık raporu Excel olarak hazırlanıyor...'),
          ],
        ),
      ),
    );

    try {
      await ExcelExportService.exportAttendanceReportToExcel();
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text('Devamsızlık raporu başarıyla Excel dosyasına aktarıldı.'),
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

  Future<void> _showAttendanceReportDialog() async {
    if (_selectedClass == null) return;
    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery('''
      SELECT s.id, s.student_no, s.first_name, s.last_name, s.photo_path,
        COALESCE(COUNT(CASE WHEN a.status = 'absent' THEN 1 END), 0) as absent_count,
        COALESCE(COUNT(CASE WHEN a.status = 'late' THEN 1 END), 0) as late_count,
        COALESCE(COUNT(CASE WHEN a.status = 'excused' THEN 1 END), 0) as excused_count,
        COALESCE(COUNT(CASE WHEN a.status = 'sick' OR a.status = 'report' THEN 1 END), 0) as report_count,
        COALESCE(COUNT(CASE WHEN a.status != 'present' AND a.status IS NOT NULL THEN 1 END), 0) as total_absence
      FROM students s
      LEFT JOIN attendances a ON a.student_id = s.id
      WHERE s.class_id = ? AND s.deleted_at IS NULL
      GROUP BY s.id
      ORDER BY total_absence DESC, absent_count DESC, CAST(s.student_no AS INTEGER) ASC
    ''', [_selectedClass!.id]);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedClass!.name} Devamsızlık Sıralaması',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const Text(
                              'En çok devamsızlık yapandan en aza (Azalan Sıra)',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandLight,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportAttendanceReportExcel();
                    },
                    icon: const Icon(Icons.file_download_rounded, size: 18),
                    label: const Text("Tüm Sınıfların Raporunu Excel'e Aktar"),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('Öğrenci bulunmuyor.'))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final r = rows[i];
                              final total = (r['total_absence'] as num?)?.toInt() ?? 0;
                              final absent = (r['absent_count'] as num?)?.toInt() ?? 0;
                              final excused = (r['excused_count'] as num?)?.toInt() ?? 0;
                              final lateCount = (r['late_count'] as num?)?.toInt() ?? 0;
                              final reportCount = (r['report_count'] as num?)?.toInt() ?? 0;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: total > 5
                                      ? Colors.red.shade100
                                      : (total > 0 ? Colors.amber.shade100 : Colors.green.shade100),
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: total > 5
                                          ? Colors.red.shade900
                                          : (total > 0 ? Colors.amber.shade900 : Colors.green.shade900),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '#${r['student_no']} ${r['first_name']} ${r['last_name']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  'Gelmedi: $absent | İzinli: $excused | Geç: $lateCount | Raporlu: $reportCount',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: total > 5
                                        ? Colors.red.shade50
                                        : (total > 0 ? Colors.amber.shade50 : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: total > 5
                                          ? Colors.red.shade300
                                          : (total > 0 ? Colors.amber.shade300 : Colors.green.shade300),
                                    ),
                                  ),
                                  child: Text(
                                    '$total Ders',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: total > 5
                                          ? Colors.red.shade900
                                          : (total > 0 ? Colors.amber.shade900 : Colors.green.shade900),
                                    ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesProv = context.watch<ClassesProvider>();
    final studentsProv = context.watch<StudentsProvider>();
    final attendanceProv = context.watch<AttendanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dateFormatted = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(_selectedDate);

    final classIds = classesProv.classes.map((c) => c.id).toSet();
    final effectiveClass = (_selectedClass != null && classIds.contains(_selectedClass!.id))
        ? _selectedClass
        : (classesProv.classes.isNotEmpty ? classesProv.classes.first : null);

    if (_selectedClass == null && effectiveClass != null) {
      _selectedClass = effectiveClass;
    }

    final selectedClassId = effectiveClass?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yoklama'),
            Text(
              dateFormatted,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_rounded),
            tooltip: 'Devamsızlık Sıralaması',
            onPressed: _showAttendanceReportDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'export_excel') {
                _exportAttendanceReportExcel();
              } else if (val == 'show_report') {
                _showAttendanceReportDialog();
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
                        "Devamsızlık Raporu (Excel)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'show_report',
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 20, color: AppTheme.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sınıf Devamsızlık Sıralaması',
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
        ],
      ),
      body: classesProv.classes.isEmpty
          ? const Center(child: Text('Yoklama almak için önce sınıf oluşturun.'))
          : Column(
              children: [
                // Kompakt Sınıf ve Tarih Seçici Çubuğu
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedClassId,
                              isDense: true,
                              decoration: const InputDecoration(
                                labelText: 'Sınıf Seçin',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: classesProv.classes.map((c) {
                                return DropdownMenuItem(value: c.id, child: Text(c.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() {
                                  _selectedClass = classesProv.classes.firstWhere((c) => c.id == val);
                                });
                                _loadData();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime(2030),
                                  locale: const Locale('tr', 'TR'),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                  _loadData();
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Toplam Değerler & İstatistik Rozetleri
                      Builder(
                        builder: (context) {
                          final students = studentsProv.students;
                          final totalCount = students.length;
                          final presentCount = students.where((s) => (attendanceProv.statuses[s.id] ?? 'present') == 'present').length;
                          final absentCount = students.where((s) => attendanceProv.statuses[s.id] == 'absent').length;
                          final lateCount = students.where((s) => attendanceProv.statuses[s.id] == 'late').length;
                          final excusedCount = students.where((s) => attendanceProv.statuses[s.id] == 'excused' || attendanceProv.statuses[s.id] == 'sick').length;

                          return Column(
                            children: [
                              Row(
                                children: [
                                  _buildSummaryBadge('Toplam', totalCount, isDark ? AppTheme.mutedDark : Colors.blueGrey, isDark),
                                  const SizedBox(width: 4),
                                  _buildSummaryBadge('Gelen', presentCount, AppTheme.posLight, isDark),
                                  const SizedBox(width: 4),
                                  _buildSummaryBadge('Gelmeyen', absentCount, AppTheme.negLight, isDark),
                                  const SizedBox(width: 4),
                                  _buildSummaryBadge('Geç', lateCount, Colors.orange.shade700, isDark),
                                  const SizedBox(width: 4),
                                  _buildSummaryBadge('İzinli', excusedCount, Colors.purple.shade600, isDark),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Durumu değiştirmek için karta dokunun',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.posLight,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      attendanceProv.markAllPresent(studentsProv.students);
                                    },
                                    icon: const Icon(Icons.done_all, size: 14),
                                    label: const Text(
                                      'Tümünü Geldi Yap',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Öğrenci Yoklama Listesi
                Expanded(
                  child: studentsProv.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : studentsProv.students.isEmpty
                          ? const Center(child: Text('Bu sınıfta öğrenci bulunmuyor.'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              itemCount: studentsProv.students.length,
                              itemBuilder: (context, i) {
                                final st = studentsProv.students[i];
                                final status = attendanceProv.statuses[st.id] ?? 'present';
                                final meta = _statusMeta[status] ?? _statusMeta['present']!;

                                final statusColor = (meta['color'] as Color?) ?? AppTheme.posLight;
                                final bgColor = isDark
                                    ? ((meta['bgDark'] as Color?) ?? AppTheme.cardDark)
                                    : ((meta['bgLight'] as Color?) ?? AppTheme.cardLight);
                                final isPresent = status == 'present';

                                final hasPhoto = st.photoPath != null &&
                                    st.photoPath!.isNotEmpty &&
                                    File(st.photoPath!).existsSync();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  elevation: isPresent ? 0.5 : 1.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isPresent
                                          ? (isDark ? AppTheme.lineDark : AppTheme.lineLight)
                                          : statusColor.withOpacity(0.8),
                                      width: isPresent ? 1.0 : 1.5,
                                    ),
                                  ),
                                  color: bgColor,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _cycleStudentStatus(st.id, status),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          // Öğrenci Fotoğrafı (Tıklandığında Büyüt)
                                          GestureDetector(
                                            onTap: hasPhoto
                                                ? () => StudentPhotoService.showPhotoPreview(context, st)
                                                : null,
                                            child: Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                color: st.gender == 'F' ? Colors.pink.shade50 : Colors.blue.shade50,
                                                border: Border.all(
                                                  color: isPresent
                                                      ? (st.gender == 'F' ? Colors.pink.shade200 : Colors.blue.shade200)
                                                      : statusColor.withOpacity(0.6),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: hasPhoto
                                                    ? Stack(
                                                        fit: StackFit.expand,
                                                        children: [
                                                          Image.file(
                                                            File(st.photoPath!),
                                                            width: 48,
                                                            height: 48,
                                                            fit: BoxFit.cover,
                                                          ),
                                                          Positioned(
                                                            right: 2,
                                                            bottom: 2,
                                                            child: Container(
                                                              padding: const EdgeInsets.all(2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.black54,
                                                                borderRadius: BorderRadius.circular(3),
                                                              ),
                                                              child: const Icon(Icons.zoom_in, size: 8, color: Colors.white),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Center(
                                                        child: Text(
                                                          st.firstName.isNotEmpty ? st.firstName[0] : '?',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w900,
                                                            color: st.gender == 'F'
                                                                ? Colors.pink.shade700
                                                                : Colors.blue.shade700,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // Öğrenci Bilgileri
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: Text(
                                                        '#${st.studentNo}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  st.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Durum Rozeti
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: statusColor.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1.5),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  meta['icon'] as IconData,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  meta['label'] as String,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
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
                            ),
                ),

                // Kompakt & Şık Alt Kaydet Çubuğu (Yer Tasarruflu)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Sol taraf: Son Kayıt Saati veya Bilgi
                        Expanded(
                          child: attendanceProv.lastSavedAt != null
                              ? Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 15,
                                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Son: ${DateFormat('dd.MM HH:mm', 'tr_TR').format(attendanceProv.lastSavedAt!)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Kaydedilmedi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),

                        // Sağ taraf: Kompakt Kaydet Butonu
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.posLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _isSaving ? 'Kaydediliyor...' : 'Yoklamayı Kaydet',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBadge(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
