import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import 'dialogs/bulk_timetable_import_dialog.dart';

class TimetableMatrixScreen extends StatefulWidget {
  const TimetableMatrixScreen({Key? key}) : super(key: key);

  @override
  State<TimetableMatrixScreen> createState() => _TimetableMatrixScreenState();
}

class _TimetableMatrixScreenState extends State<TimetableMatrixScreen> {
  bool _isStampMode = false;
  ClassModel? _selectedStampClass;
  String _selectedSubject = '';

  final List<String> _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.brandLight;
    }
  }

  void _showCellActionSheet({
    required BuildContext context,
    required BellPeriodModel bp,
    required int weekday,
    required TimetableEntryModel entry,
    required bool hasEntry,
  }) {
    final classesProv = context.read<ClassesProvider>();
    final scheduleProv = context.read<ScheduleProvider>();
    final appProv = context.read<AppProvider>();

    if (classesProv.classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Henüz eklenmiş bir sınıf bulunmuyor.')),
      );
      return;
    }

    int selectedClassId = hasEntry ? entry.classId : classesProv.classes.first.id;
    final initialClass = classesProv.classes.firstWhere(
      (c) => c.id == selectedClassId,
      orElse: () => classesProv.classes.first,
    );

    // List of subjects: teacher's subjects from settings, plus class subject
    final Set<String> subjectSet = {};
    if (appProv.subjects.isNotEmpty) subjectSet.addAll(appProv.subjects);
    if (initialClass.subject != null && initialClass.subject!.isNotEmpty) {
      subjectSet.add(initialClass.subject!);
    }
    if (hasEntry && entry.subject.isNotEmpty) subjectSet.add(entry.subject);
    if (subjectSet.isEmpty) subjectSet.add('Ders');

    String selectedSub = hasEntry && entry.subject.isNotEmpty
        ? entry.subject
        : (subjectSet.contains(_selectedSubject) && _selectedSubject.isNotEmpty
            ? _selectedSubject
            : subjectSet.first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final curClass = classesProv.classes.firstWhere(
              (c) => c.id == selectedClassId,
              orElse: () => classesProv.classes.first,
            );

            // Recompute available subjects for currently picked class
            final currentSubjectSet = <String>{};
            if (appProv.subjects.isNotEmpty) currentSubjectSet.addAll(appProv.subjects);
            if (curClass.subject != null && curClass.subject!.isNotEmpty) {
              currentSubjectSet.add(curClass.subject!);
            }
            if (selectedSub.isNotEmpty) currentSubjectSet.add(selectedSub);
            if (currentSubjectSet.isEmpty) currentSubjectSet.add('Ders');

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${bp.label} (${_weekdays[weekday - 1]})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            hasEntry ? 'Mevcut dersi güncelle veya kaldır' : 'Bu saate ders ata',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sınıf Seçimi
                  const Text('Sınıf Seçin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedClassId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: classesProv.classes.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.name} (${c.gradeLevel}. Sınıf)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedClassId = val;
                          final cls = classesProv.classes.firstWhere((c) => c.id == val);
                          if (cls.subject != null && cls.subject!.isNotEmpty) {
                            selectedSub = cls.subject!;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Ders Seçimi (Ayarlardaki Girdiğim Dersler'den)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ders Seçin (Girdiğim Dersler)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (appProv.subjects.isEmpty)
                        const Text(
                          'Ayarlar > Dersler ekleyebilirsiniz',
                          style: TextStyle(fontSize: 10, color: AppTheme.accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentSubjectSet.map((sub) {
                      final isSel = selectedSub == sub;
                      return ChoiceChip(
                        label: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel
                                ? (isDark ? AppTheme.brandDark : Colors.white)
                                : (isDark ? AppTheme.inkDark : AppTheme.inkLight),
                          ),
                        ),
                        selected: isSel,
                        selectedColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedSub = sub);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Eylemler
                  Row(
                    children: [
                      if (hasEntry) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.negLight,
                              side: const BorderSide(color: AppTheme.negLight),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Kaldır'),
                            onPressed: () async {
                              await scheduleProv.removeTimetableCell(bp.id, weekday);
                              if (mounted) Navigator.pop(ctx);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await scheduleProv.setTimetableCell(
                              classId: selectedClassId,
                              periodId: bp.id,
                              weekday: weekday,
                              subject: selectedSub,
                            );
                            if (mounted) Navigator.pop(ctx);
                          },
                          child: Text(hasEntry ? 'Güncelle' : 'Dersi Ata'),
                        ),
                      ),
                    ],
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
    final scheduleProv = context.watch<ScheduleProvider>();
    final classesProv = context.watch<ClassesProvider>();
    final appProv = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final periods = scheduleProv.bellPeriods;
    final entries = scheduleProv.timetable;

    // Available subjects for stamp mode
    final Set<String> stampSubjectSet = {};
    if (appProv.subjects.isNotEmpty) stampSubjectSet.addAll(appProv.subjects);
    if (_selectedStampClass?.subject != null && _selectedStampClass!.subject!.isNotEmpty) {
      stampSubjectSet.add(_selectedStampClass!.subject!);
    }
    if (stampSubjectSet.isEmpty) stampSubjectSet.add('Ders');
    final availableStampSubjects = stampSubjectSet.toList();

    if (_selectedSubject.isEmpty || !stampSubjectSet.contains(_selectedSubject)) {
      if (stampSubjectSet.isNotEmpty) {
        _selectedSubject = stampSubjectSet.first;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık Ders Matrisi'),
        actions: [
          IconButton(
            icon: const Text('📊', style: TextStyle(fontSize: 18)),
            tooltip: 'Toplu Program Aktar',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const BulkTimetableImportDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ⚡ Hızlı Doldurma (Damga) Kontrol Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hızlı Doldurma (Damga) Modu',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              'Seçili sınıf ve dersi hücrelere dokunarak anında ata',
                              style: TextStyle(fontSize: 10, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isStampMode,
                      activeColor: AppTheme.accent,
                      onChanged: (val) {
                        setState(() {
                          _isStampMode = val;
                          if (_isStampMode && _selectedStampClass == null && classesProv.classes.isNotEmpty) {
                            _selectedStampClass = classesProv.classes.first;
                            if (stampSubjectSet.isNotEmpty) {
                              _selectedSubject = stampSubjectSet.first;
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_isStampMode && classesProv.classes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Sınıf Seçimi
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: _selectedStampClass?.id ?? classesProv.classes.first.id,
                          decoration: const InputDecoration(
                            labelText: 'Sınıf',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          items: classesProv.classes.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedStampClass = classesProv.classes.firstWhere((c) => c.id == val);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Ders Seçimi (Ayarlardaki Girdiğim Dersler'den)
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: availableStampSubjects.contains(_selectedSubject)
                              ? _selectedSubject
                              : availableStampSubjects.first,
                          decoration: const InputDecoration(
                            labelText: 'Ders',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          items: availableStampSubjects.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSubject = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // 5x8 Matris Tablosu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(80),
                  columnWidths: const {
                    0: FixedColumnWidth(64), // Saat sütunu
                  },
                  border: TableBorder.all(
                    color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  children: [
                    // Başlık Satırı (Pzt, Sal, Çar, Per, Cum)
                    TableRow(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : AppTheme.bgLight,
                      ),
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text('Saat', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        ),
                        ...List.generate(appProv.timetableDays, (dayIdx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                _weekdays[dayIdx],
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    // Ders Satırları (1..8)
                    ...periods.map((bp) {
                      return TableRow(
                        children: [
                          // Ders Saati Bilgisi
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Column(
                              children: [
                                Text('${bp.periodNo}. Ders', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                                Text(
                                  '${bp.startTime}\n${bp.endTime}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Günlük Hücreler (5 veya 7 Gün)
                          ...List.generate(appProv.timetableDays, (dIdx) {
                            final weekday = dIdx + 1;
                            final entry = entries.firstWhere(
                              (e) => e.periodId == bp.id && e.weekday == weekday,
                              orElse: () => TimetableEntryModel(
                                id: 0,
                                classId: 0,
                                periodId: bp.id,
                                weekday: weekday,
                                subject: '',
                              ),
                            );

                            final hasEntry = entry.id != 0;
                            final cellColor = hasEntry && entry.classColor != null
                                ? _parseHex(entry.classColor!)
                                : null;

                            return InkWell(
                              onTap: () async {
                                if (_isStampMode && _selectedStampClass != null) {
                                  if (hasEntry && entry.classId == _selectedStampClass!.id) {
                                    // Aynıysa temizle
                                    await scheduleProv.removeTimetableCell(bp.id, weekday);
                                  } else {
                                    // Ata
                                    await scheduleProv.setTimetableCell(
                                      classId: _selectedStampClass!.id,
                                      periodId: bp.id,
                                      weekday: weekday,
                                      subject: _selectedSubject.isNotEmpty ? _selectedSubject : 'Ders',
                                    );
                                  }
                                } else {
                                  // Normal tıklama: Sınıf ve ayarlı derslerden seçim paneli
                                  _showCellActionSheet(
                                    context: context,
                                    bp: bp,
                                    weekday: weekday,
                                    entry: entry,
                                    hasEntry: hasEntry,
                                  );
                                }
                              },
                              child: Container(
                                height: 56,
                                padding: const EdgeInsets.all(4),
                                color: hasEntry ? cellColor?.withOpacity(0.18) : null,
                                child: hasEntry
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            entry.className ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                              color: cellColor,
                                            ),
                                          ),
                                          Text(
                                            entry.subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 9),
                                          ),
                                        ],
                                      )
                                    : Center(
                                        child: Text(
                                          '+',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: (isDark ? AppTheme.mutedDark : AppTheme.mutedLight).withOpacity(0.4),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
