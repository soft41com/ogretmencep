import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/plans_provider.dart';
import '../theme/app_theme.dart';
import 'classes_screen.dart';
import 'dialogs/bulk_plan_import_dialog.dart';

class PlansScreen extends StatefulWidget {
  final int? initialClassId;

  const PlansScreen({Key? key, this.initialClassId}) : super(key: key);

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int? _selectedClassId;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final classesProv = context.read<ClassesProvider>();
      if (_selectedClassId == null && classesProv.classes.isNotEmpty) {
        _selectedClassId = classesProv.classes.first.id;
      }
      if (_selectedClassId != null) {
        context.read<PlansProvider>().fetchPlans(classId: _selectedClassId);
      }
      _isInit = true;
    }
  }

  void _onClassChanged(int newClassId) {
    if (_selectedClassId == newClassId) return;
    setState(() => _selectedClassId = newClassId);
    context.read<PlansProvider>().fetchPlans(classId: newClassId);
  }

  void _openBulkImportDialog() {
    if (_selectedClassId == null) return;
    showDialog(
      context: context,
      builder: (_) => BulkPlanImportDialog(targetClassId: _selectedClassId!),
    ).then((val) {
      if (val == true && mounted && _selectedClassId != null) {
        context.read<PlansProvider>().fetchPlans(classId: _selectedClassId);
      }
    });
  }

  void _showAddOrEditPlanSheet({LessonPlanModel? editPlan}) {
    if (_selectedClassId == null) return;

    final plansProv = context.read<PlansProvider>();
    final classesProv = context.read<ClassesProvider>();

    final activeClass = classesProv.classes.firstWhere(
      (c) => c.id == _selectedClassId,
      orElse: () => classesProv.classes.first,
    );
    final defaultSubject = (activeClass.subject != null && activeClass.subject!.isNotEmpty)
        ? activeClass.subject!
        : 'Ders';

    final weekCtrl = TextEditingController(
      text: editPlan != null ? editPlan.weekNo.toString() : (plansProv.plans.length + 1).toString(),
    );
    final topicCtrl = TextEditingController(text: editPlan?.topic ?? '');
    final outcomesCtrl = TextEditingController(text: editPlan?.learningOutcomes ?? '');
    final activitiesCtrl = TextEditingController(text: editPlan?.activities ?? '');
    int term = editPlan?.term ?? ((int.tryParse(weekCtrl.text) ?? 1) > 18 ? 2 : 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                        Text(
                          editPlan == null ? '${activeClass.name} - Hafta Ekle' : '${activeClass.name} - Haftayı Düzenle',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: weekCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Hafta No *', hintText: '1'),
                                    onChanged: (val) {
                                      final w = int.tryParse(val) ?? 1;
                                      setSheetState(() => term = w > 18 ? 2 : 1);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: SegmentedButton<int>(
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return isDark ? AppTheme.accent : AppTheme.brandLight;
                                        }
                                        return isDark ? AppTheme.bgDark : AppTheme.bgLight;
                                      }),
                                      foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return isDark ? AppTheme.brandDark : Colors.white;
                                        }
                                        return isDark ? AppTheme.inkDark : AppTheme.inkLight;
                                      }),
                                    ),
                                    segments: const [
                                      ButtonSegment(value: 1, label: Text('1. Dönem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                      ButtonSegment(value: 2, label: Text('2. Dönem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    ],
                                    selected: {term},
                                    onSelectionChanged: (val) => setSheetState(() => term = val.first),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: topicCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Konu / Ünite *',
                                hintText: 'Örn: Temel Kavramlar ve Sayı Kümeleri',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: outcomesCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Kazanımlar / Öğrenme Çıktıları',
                                hintText: 'Örn: Doğal sayılar ve tam sayılar arasındaki ilişkiyi kavrar.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: activitiesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Etkinlikler, Yöntem ve Teknikler',
                                hintText: 'Örn: Soru çözümü, akıllı tahta uygulamaları, grup çalışması',
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final topic = topicCtrl.text.trim();
                                final weekNo = int.tryParse(weekCtrl.text.trim()) ?? 1;
                                if (topic.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Lütfen konu başlığını girin.')),
                                  );
                                  return;
                                }

                                if (editPlan == null) {
                                  await plansProv.addPlan(
                                    classId: _selectedClassId!,
                                    weekNo: weekNo,
                                    term: term,
                                    subject: defaultSubject,
                                    topic: topic,
                                    learningOutcomes: outcomesCtrl.text.trim(),
                                    activities: activitiesCtrl.text.trim(),
                                  );
                                } else {
                                  await plansProv.updatePlan(
                                    id: editPlan.id,
                                    weekNo: weekNo,
                                    term: term,
                                    subject: editPlan.subject,
                                    topic: topic,
                                    learningOutcomes: outcomesCtrl.text.trim(),
                                    activities: activitiesCtrl.text.trim(),
                                  );
                                }

                                if (mounted) Navigator.pop(ctx);
                              },
                              child: Text(editPlan == null ? 'Haftayı Kaydet' : 'Değişiklikleri Güncelle'),
                            ),
                          ],
                        ),
                      ),
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

  void _showCopyFromDialog() {
    final classesProv = context.read<ClassesProvider>();
    final plansProv = context.read<PlansProvider>();

    final otherClasses = classesProv.classes.where((c) => c.id != _selectedClassId).toList();
    if (otherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan kopyalanabilecek başka bir sınıfınız bulunmuyor.')),
      );
      return;
    }

    int? sourceId = otherClasses.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Başka Sınıftan Kopyala', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Seçtiğiniz sınıfın tüm yıllık planı ve kazanımları bu sınıfa kopyalanacaktır.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: sourceId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kaynak Sınıf'),
                    items: otherClasses
                        .map((c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text('${c.name} (${c.subject ?? "Ders"})', style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) => setDlgState(() => sourceId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  onPressed: () async {
                    if (sourceId == null || _selectedClassId == null) return;
                    Navigator.pop(ctx);

                    final targetCls = classesProv.classes.firstWhere((c) => c.id == _selectedClassId);
                    final sub = targetCls.subject ?? 'Ders';

                    await plansProv.copyPlansFrom(
                      sourceClassId: sourceId!,
                      targetClassId: _selectedClassId!,
                      subject: sub,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppTheme.posLight,
                          content: Text('Yıllık plan başarıyla kopyalandı.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Kopyala ve Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showClearConfirmDialog(String className) {
    if (_selectedClassId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('$className Planını Temizle', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text('$className sınıfına ait tüm yıllık plan ve kazanımlar silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<PlansProvider>().clearPlansForClass(_selectedClassId!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan temizlendi.')),
                );
              }
            },
            child: const Text('Tümünü Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansProv = context.watch<PlansProvider>();
    final classesProv = context.watch<ClassesProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Eğer hiç sınıf yoksa yönlendirme ekranı göster
    if (classesProv.classes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yıllık Plan & Kazanımlar')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 64, color: AppTheme.brandLight.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'Henüz Eklenmiş Bir Sınıfınız Bulunmuyor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  'Yıllık planlar doğrudan sınıflara ve derslere atanır. Plan oluşturabilmek için lütfen önce sınıfınızı ekleyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ClassesScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Sınıf Ekle'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeClass = classesProv.classes.firstWhere(
      (c) => c.id == _selectedClassId,
      orElse: () => classesProv.classes.first,
    );

    final completedCount = plansProv.plans.where((p) => p.status == 'completed').length;
    final totalCount = plansProv.plans.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yıllık Plan & Kazanımlar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            Text(
              '${activeClass.name} • ${activeClass.subject ?? "Ders"}',
              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
            ),
          ],
        ),
        actions: [
          // Excel Yükleme Butonu
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: "Excel'den Yükle",
            onPressed: _openBulkImportDialog,
          ),
          // Yeni Hafta Ekle
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Yeni Hafta Ekle',
            onPressed: () => _showAddOrEditPlanSheet(),
          ),
          // Menü
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'import') {
                _openBulkImportDialog();
              } else if (val == 'add') {
                _showAddOrEditPlanSheet();
              } else if (val == 'copy') {
                _showCopyFromDialog();
              } else if (val == 'clear') {
                _showClearConfirmDialog(activeClass.name);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, size: 18),
                    SizedBox(width: 8),
                    Text("Excel ile Yükle / Şablon"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 8),
                    Text('Yeni Hafta Ekle'),
                  ],
                ),
              ),
              if (classesProv.classes.length > 1)
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Başka Sınıftan Kopyala'),
                    ],
                  ),
                ),
              if (plansProv.plans.isNotEmpty)
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_rounded, size: 18, color: AppTheme.negLight),
                      const SizedBox(width: 8),
                      Text('${activeClass.name} Planını Temizle', style: const TextStyle(color: AppTheme.negLight)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Sınıf Seçim Çubuğu (Yalnızca Sınıflar, Genel Plan Kaldırıldı)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
              border: Border(
                bottom: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight, width: 0.8),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: classesProv.classes.map((cls) {
                  final isSel = _selectedClassId == cls.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        '${cls.name} (${cls.subject ?? "Ders"})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          color: isSel
                              ? (isDark ? AppTheme.brandDark : Colors.white)
                              : (isDark ? AppTheme.inkDark : AppTheme.inkLight),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      onSelected: (_) => _onClassChanged(cls.id),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // İlerleme Durumu Kartı (Yalnızca plan varsa gösterilir)
          if (plansProv.plans.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${activeClass.name} Müfredat İlerlemesi',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      Text(
                        '$completedCount / $totalCount Hafta (${(progress * 100).toInt()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.accent : AppTheme.brandLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                    color: AppTheme.posLight,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Liste Görünümü veya Düzgün Boş Durum
          Expanded(
            child: plansProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : plansProv.plans.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 480),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 56,
                                  color: isDark ? AppTheme.accent : AppTheme.brandLight,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '${activeClass.name} Sınıfına Ait Yıllık Plan Bulunmuyor',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bu sınıf ve ders için henüz haftalık plan eklenmedi. Excel dosyanızı yükleyerek tüm yılı saniyeler içinde içeri aktarabilir veya haftalık konuları manuel ekleyebilirsiniz.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _openBulkImportDialog,
                                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                                      label: const Text("Excel'den Yükle"),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      onPressed: () => _showAddOrEditPlanSheet(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Hafta Ekle'),
                                    ),
                                  ],
                                ),
                                if (classesProv.classes.length > 1) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _showCopyFromDialog,
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text(
                                      'Başka Sınıfın Planını Bu Sınıfa Kopyala',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: plansProv.plans.length,
                        itemBuilder: (context, i) {
                          final p = plansProv.plans[i];
                          final isDone = p.status == 'completed';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isDone,
                                    activeColor: AppTheme.posLight,
                                    onChanged: (_) => plansProv.togglePlanStatus(p.id),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDone
                                                    ? AppTheme.posLight.withOpacity(0.16)
                                                    : AppTheme.brandLight.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${p.weekNo}. Hafta',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDone ? AppTheme.posLight : (isDark ? AppTheme.accent : AppTheme.brandLight),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                '${p.term}. Dönem',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          p.topic,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                            color: isDone ? (isDark ? AppTheme.mutedDark : AppTheme.mutedLight) : null,
                                          ),
                                        ),
                                        if (p.learningOutcomes != null && p.learningOutcomes!.isNotEmpty) ...[
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: (isDark ? AppTheme.bgDark : AppTheme.bgLight).withOpacity(0.8),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark ? AppTheme.lineDark.withOpacity(0.5) : AppTheme.lineLight,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('🎯 ', style: TextStyle(fontSize: 10)),
                                                Expanded(
                                                  child: Text(
                                                    p.learningOutcomes!,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      height: 1.35,
                                                      color: isDark ? AppTheme.inkDark : AppTheme.inkLight,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (p.activities != null && p.activities!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Yöntem & Etkinlik: ${p.activities}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showAddOrEditPlanSheet(editPlan: p);
                                      } else if (val == 'delete') {
                                        plansProv.deletePlan(p.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 16),
                                            SizedBox(width: 8),
                                            Text('Düzenle'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 16, color: AppTheme.negLight),
                                            SizedBox(width: 8),
                                            Text('Sil', style: TextStyle(color: AppTheme.negLight)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
