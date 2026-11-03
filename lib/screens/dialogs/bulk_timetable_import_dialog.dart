import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/classes_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_theme.dart';

class BulkTimetableImportDialog extends StatefulWidget {
  const BulkTimetableImportDialog({Key? key}) : super(key: key);

  @override
  State<BulkTimetableImportDialog> createState() => _BulkTimetableImportDialogState();
}

class _BulkTimetableImportDialogState extends State<BulkTimetableImportDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _clearExisting = false;
  bool _isSaving = false;

  final Map<String, int> _dayMap = {
    'pzt': 1, 'pazartesi': 1, '1': 1,
    'sal': 2, 'salı': 2, 'sali': 2, '2': 2,
    'çar': 3, 'çarşamba': 3, 'carsamba': 3, '3': 3,
    'per': 4, 'perşembe': 4, 'persembe': 4, '4': 4,
    'cum': 5, 'cuma': 5, '5': 5,
  };

  Future<void> _handleImport() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen yapıştırılan ders programı metnini girin.')),
      );
      return;
    }

    final scheduleProv = context.read<ScheduleProvider>();
    final classesProv = context.read<ClassesProvider>();
    final appProv = context.read<AppProvider>();

    final bellPeriods = scheduleProv.bellPeriods;
    final classes = classesProv.classes;

    if (bellPeriods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zil saatleri bulunamadı.')),
      );
      return;
    }

    final lines = const LineSplitter().convert(text);
    final List<Map<String, dynamic>> entries = [];

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
        parts = trimmed.split(RegExp(r'\s+'));
      }

      parts = parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length < 3) continue;

      // Format: Gün | Ders Saati (1-8) | Sınıf Adı | [Ders Adı]
      final rawDay = parts[0].toLowerCase();
      final weekday = _dayMap[rawDay];
      if (weekday == null) continue;

      final periodNo = int.tryParse(parts[1]) ?? 1;
      final targetPeriod = bellPeriods.firstWhere(
        (bp) => bp.periodNo == periodNo,
        orElse: () => bellPeriods.first,
      );

      final className = parts[2];
      final targetClass = classes.firstWhere(
        (c) => c.name.toLowerCase() == className.toLowerCase(),
        orElse: () => classes.isNotEmpty ? classes.first : throw Exception('Sınıf bulunamadı'),
      );

      final defaultSub = targetClass.subject ?? (appProv.subjects.isNotEmpty ? appProv.subjects.first : 'Ders');
      final subject = parts.length > 3 ? parts[3] : defaultSub;

      entries.add({
        'class_id': targetClass.id,
        'period_id': targetPeriod.id,
        'weekday': weekday,
        'subject': subject,
      });
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli ders satırı tespit edilemedi. Örnek: Pazartesi\t1\t9-A\tMatematik')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final count = await scheduleProv.bulkSaveTimetable(entries, clearExisting: _clearExisting);
    setState(() => _isSaving = false);

    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.posLight,
        content: Text('$count ders programı hücresi başarıyla kaydedildi.'),
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('📅', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplu Program Girişi',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text('Excel veya panodan haftalık dersleri yapıştırın', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
              ),
              child: const Text(
                'Format: Gün\tDers Saati\tSınıf\tDers\nÖrn:\nPazartesi\t1\t9-A\tMatematik\nPazartesi\t2\t9-A\tMatematik\nSalı\t3\t10-B\tGeometri',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Program satırlarını buraya yapıştırın...',
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _clearExisting,
              onChanged: (v) => setState(() => _clearExisting = v ?? false),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Mevcut programı temizle ve yenisini kaydet', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleImport,
              child: Text(_isSaving ? 'Kaydediliyor...' : 'Programı İçe Aktar'),
            ),
          ],
        ),
      ),
    );
  }
}
