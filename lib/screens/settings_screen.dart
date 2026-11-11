import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/plans_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/backup_service.dart';
import '../services/institution_share_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'onboarding/setup_wizard_screen.dart';
import 'onboarding/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _branchCtrl = TextEditingController();
  final TextEditingController _yearCtrl = TextEditingController();
  final TextEditingController _dailyPeriodsCtrl = TextEditingController();
  final TextEditingController _newSubjectCtrl = TextEditingController();

  bool _isInit = false;
  bool _isSaving = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoadingBackups = false;
  bool _isSharingInstitution = false;
  bool _isImportingInstitution = false;
  List<BackupItemInfo> _backups = [];

  // Ders bildirim ayarları state'leri
  bool _lessonNotifyEnabled = true;
  bool _lessonStartNotifyEnabled = true;
  int _lessonStartMinutes = 5;
  bool _lessonEndNotifyEnabled = true;
  int _lessonEndMinutes = 5;
  String _lessonNotifyType = 'both';
  bool _isSavingNotifications = false;
  bool _isTestingNotification = false;
  bool _isTestingScheduledNotification = false;
  bool _canScheduleExact = true;

  String _getCurrentAcademicYear(AppProvider appProv) {
    final year = _yearCtrl.text.trim();
    if (year.isNotEmpty) return year;
    return appProv.settings?.academicYear ?? AppProvider.defaultAcademicYear;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBackups();
        _checkExactAlarmPermission();
      }
    });
  }

  Future<void> _checkExactAlarmPermission() async {
    final canExact = await NotificationService.instance.canScheduleExactNotifications();
    if (mounted) {
      setState(() => _canScheduleExact = canExact);
    }
  }

  Future<void> _loadBackups() async {
    if (mounted) {
      setState(() => _isLoadingBackups = true);
    }
    try {
      final list = await BackupService.listLocalBackups();
      if (mounted) {
        setState(() {
          _backups = list;
          _isLoadingBackups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBackups = false);
    }
  }

  Future<void> _shareInstitutionData() async {
    setState(() => _isSharingInstitution = true);
    try {
      final schoolName = _schoolCtrl.text.trim();
      await InstitutionShareService.exportAndShareInstitutionData(
        customSchoolName: schoolName.isNotEmpty ? schoolName : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text('Paylaşım hatası: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingInstitution = false);
      }
    }
  }

  Future<void> _importInstitutionData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Kurum Veri Paketi Seçin (.ogretmencep veya .zip)',
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      setState(() => _isImportingInstitution = true);
      final file = File(result.files.first.path!);

      final importResult = await InstitutionShareService.importInstitutionData(file);

      if (!mounted) return;
      setState(() => _isImportingInstitution = false);

      if (importResult.success) {
        // Provider'ları yenile
        context.read<ClassesProvider>().fetchClasses();
        context.read<ScheduleProvider>().fetchBellPeriods();
        context.read<AppProvider>().loadSettings();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.posLight, size: 28),
                SizedBox(width: 10),
                Text('Kurum Verisi Aktarıldı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              'Tebrikler! Kurum verileri sisteme başarıyla işlendi:\n\n'
              '• ${importResult.classCount} sınıf eklendi / güncellendi\n'
              '• ${importResult.studentCount} öğrenci kaydedildi\n'
              '• ${importResult.photoCount} fotoğraf yüklendi\n'
              '• ${importResult.bellPeriodCount} zil saati güncellendi',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text(importResult.errorMessage ?? 'İçe aktarma başarısız oldu.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImportingInstitution = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text('Hata oluştu: $e'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _branchCtrl.dispose();
    _yearCtrl.dispose();
    _dailyPeriodsCtrl.dispose();
    _newSubjectCtrl.dispose();
    super.dispose();
  }

  void _syncSettings(SettingsModel? settings) {
    if (settings != null && !_isInit) {
      _nameCtrl.text = settings.teacherName;
      _schoolCtrl.text = settings.schoolName;
      _branchCtrl.text = settings.branch;
      _yearCtrl.text = settings.academicYear;
      _dailyPeriodsCtrl.text = settings.dailyPeriodsCount.toString();
      _lessonNotifyEnabled = settings.lessonNotifyEnabled;
      _lessonStartNotifyEnabled = settings.lessonStartNotifyEnabled;
      _lessonStartMinutes = settings.lessonStartMinutes;
      _lessonEndNotifyEnabled = settings.lessonEndNotifyEnabled;
      _lessonEndMinutes = settings.lessonEndMinutes;
      _lessonNotifyType = settings.lessonNotifyType;
      _isInit = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<AppProvider>(context, listen: false).settings;
    _syncSettings(settings);
  }

  String _normalizeTimeString(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '00:00';
    if (clean.contains(':')) {
      final parts = clean.split(':');
      final h = (int.tryParse(parts[0]) ?? 0).clamp(0, 23);
      final m = (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0).clamp(0, 59);
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    if (clean.length == 4) {
      final h = (int.tryParse(clean.substring(0, 2)) ?? 0).clamp(0, 23);
      final m = (int.tryParse(clean.substring(2, 4)) ?? 0).clamp(0, 59);
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return clean;
  }

  Future<void> _pickBellTime(
    BuildContext context,
    TextEditingController controller,
    Function(String) onSelected,
  ) async {
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    final text = controller.text.trim();
    if (text.contains(':')) {
      final parts = text.split(':');
      final h = int.tryParse(parts[0]);
      final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        initial = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Saat ve Dakika Seçin',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      builder: (dialogContext, child) {
        return MediaQuery(
          data: MediaQuery.of(dialogContext).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formatted;
      onSelected(formatted);
    }
  }

  void _showBellPeriodsSheet(BuildContext context) {
    final scheduleProv = context.read<ScheduleProvider>();
    final periods = List<BellPeriodModel>.from(scheduleProv.bellPeriods);
    final startControllers = periods.map((p) => TextEditingController(text: p.startTime)).toList();
    final endControllers = periods.map((p) => TextEditingController(text: p.endTime)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final screenHeight = MediaQuery.of(ctx).size.height;
        final availableHeight = (screenHeight - bottomInset) * 0.88;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            height: availableHeight,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Zil Saatleri Yönetimi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: periods.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = periods[i];

                      return Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 68,
                                child: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: startControllers[i],
                                  readOnly: true,
                                  onTap: () => _pickBellTime(ctx, startControllers[i], (v) {
                                    periods[i] = BellPeriodModel(
                                      id: p.id,
                                      periodNo: p.periodNo,
                                      startTime: v,
                                      endTime: periods[i].endTime,
                                      label: p.label,
                                    );
                                  }),
                                  keyboardType: TextInputType.datetime,
                                  inputFormatters: [_TimeTextInputFormatter()],
                                  scrollPadding: const EdgeInsets.all(40),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Başlangıç',
                                    hintText: '08:30',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.access_time_rounded, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Saat Seç',
                                      onPressed: () => _pickBellTime(ctx, startControllers[i], (v) {
                                        periods[i] = BellPeriodModel(
                                          id: p.id,
                                          periodNo: p.periodNo,
                                          startTime: v,
                                          endTime: periods[i].endTime,
                                          label: p.label,
                                        );
                                      }),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    periods[i] = BellPeriodModel(
                                      id: p.id,
                                      periodNo: p.periodNo,
                                      startTime: v,
                                      endTime: periods[i].endTime,
                                      label: p.label,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: endControllers[i],
                                  readOnly: true,
                                  onTap: () => _pickBellTime(ctx, endControllers[i], (v) {
                                    periods[i] = BellPeriodModel(
                                      id: p.id,
                                      periodNo: p.periodNo,
                                      startTime: periods[i].startTime,
                                      endTime: v,
                                      label: p.label,
                                    );
                                  }),
                                  keyboardType: TextInputType.datetime,
                                  inputFormatters: [_TimeTextInputFormatter()],
                                  scrollPadding: const EdgeInsets.all(40),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Bitiş',
                                    hintText: '09:10',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.access_time_rounded, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Saat Seç',
                                      onPressed: () => _pickBellTime(ctx, endControllers[i], (v) {
                                        periods[i] = BellPeriodModel(
                                          id: p.id,
                                          periodNo: p.periodNo,
                                          startTime: periods[i].startTime,
                                          endTime: v,
                                          label: p.label,
                                        );
                                      }),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    periods[i] = BellPeriodModel(
                                      id: p.id,
                                      periodNo: p.periodNo,
                                      startTime: periods[i].startTime,
                                      endTime: v,
                                      label: p.label,
                                    );
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
                ElevatedButton(
                  onPressed: () async {
                    for (int i = 0; i < periods.length; i++) {
                      periods[i] = BellPeriodModel(
                        id: periods[i].id,
                        periodNo: periods[i].periodNo,
                        startTime: _normalizeTimeString(startControllers[i].text),
                        endTime: _normalizeTimeString(endControllers[i].text),
                        label: periods[i].label,
                      );
                    }
                    Navigator.pop(ctx);
                    await scheduleProv.updateBellPeriods(periods);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Zil saatleri başarıyla güncellendi.'),
                          backgroundColor: AppTheme.posLight,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Zil Saatlerini Kaydet'),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      for (final c in startControllers) {
        c.dispose();
      }
      for (final c in endControllers) {
        c.dispose();
      }
    });
  }

  // Eğitim Öğretim Yılına Göre Telefon İçine Tam Yedek Al (DB + Fotoğraflar)
  Future<void> _createBackupAndPrompt() async {
    final appProv = context.read<AppProvider>();
    final activeYear = _yearCtrl.text.trim().isNotEmpty
        ? _yearCtrl.text.trim()
        : (appProv.settings?.academicYear ?? AppProvider.defaultAcademicYear);

    final bool alreadyExists = _backups.any(
      (b) => b.academicYear.trim().toLowerCase() == activeYear.trim().toLowerCase(),
    );

    setState(() => _isBackingUp = true);

    try {
      await BackupService.createAcademicYearBackup(academicYear: activeYear);
      await _loadBackups();

      if (!mounted) return;
      setState(() => _isBackingUp = false);

      // Soru: Yeni eğitim öğretim yılı için tüm verileri temizlememi ister misiniz?
      final shouldClear = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.posLight, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadyExists ? 'Yedek Güncellendi' : 'Yedekleme Tamamlandı',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alreadyExists
                    ? '$activeYear eğitim öğretim yılına ait mevcut yedeğin üzerine başarıyla yazıldı ve güncellendi.'
                    : '$activeYear eğitim öğretim yılına ait veritabanı ve tüm öğrenci fotoğrafları telefon hafızasına güvenle kaydedildi.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.brandLight.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.brandLight.withOpacity(0.2)),
                ),
                child: const Text(
                  'Yeni eğitim öğretim yılı için tüm verileri (sınıflar, öğrenciler, yoklamalar, notlar, planlar) temizlememi ister misiniz?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hayır, Verileri Koru'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.negLight,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet, Verileri Temizle'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (shouldClear == true) {
        // İkinci onay uyarısı
        final doubleConfirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Tüm Veriler Temizlensin mi?', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.negLight)),
            content: const Text(
              'Bu işlem mevcut sınıfları, öğrencileri, ders programını, yoklamaları ve sınavları sıfırlayacaktır.\n\nİstediğiniz zaman aşağıdaki listeden bu yedeği seçerek tek tıkla geri dönebilirsiniz.',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tümünü Temizle'),
              ),
            ],
          ),
        );

        if (!mounted || doubleConfirmed != true) return;

        await BackupService.clearAcademicYearData();

        if (!mounted) return;
        final classesProv = context.read<ClassesProvider>();
        final scheduleProv = context.read<ScheduleProvider>();
        final plansProv = context.read<PlansProvider>();
        final messenger = ScaffoldMessenger.of(context);

        await classesProv.fetchClasses();
        await scheduleProv.fetchTimetable();
        await plansProv.fetchPlans();

        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text('Yeni eğitim öğretim yılı için veriler sıfırlandı. Yedek listede saklanmaktadır.'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text(
              alreadyExists
                  ? '$activeYear yedeği güncellendi (üzerine yazıldı). Mevcut verileriniz korundu.'
                  : 'Yedek telefon hafızasına kaydedildi. Mevcut verileriniz korundu.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Yedekleme sırasında hata: $e')),
        );
      }
    }
  }

  // Telefonda Kayıtlı Yedeği Geri Yükle
  Future<void> _restoreBackup(BackupItemInfo backup) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${backup.academicYear} Yedeğini Geri Yükle', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '${backup.academicYear} yılına ait (${DateFormat('dd.MM.yyyy HH:mm').format(backup.createdAt)}) yedek geri yüklenecektir.\n\nBu işlem mevcut sınıflarınızın ve verilerinizin üzerine bu yedekteki verileri yazacaktır. Devam etmek istiyor musunuz?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandLight, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yedeği Geri Yükle'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isRestoring = true);

    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 4),
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Yedek geri yükleniyor... Lütfen bekleyin.'),
          ],
        ),
      ),
    );

    try {
      await BackupService.restoreFromBackup(backup.file);

      if (!mounted) return;
      final appProv = context.read<AppProvider>();
      final classesProv = context.read<ClassesProvider>();
      final scheduleProv = context.read<ScheduleProvider>();
      final plansProv = context.read<PlansProvider>();

      await appProv.loadSettings();
      await classesProv.fetchClasses();
      await scheduleProv.fetchTimetable();
      await scheduleProv.fetchBellPeriods();
      await plansProv.fetchPlans();

      if (!mounted) return;
      final settings = appProv.settings;
      if (settings != null) {
        _nameCtrl.text = settings.teacherName;
        _schoolCtrl.text = settings.schoolName;
        _branchCtrl.text = settings.branch;
        _yearCtrl.text = settings.academicYear;
      }

      await _loadBackups();
      setState(() => _isRestoring = false);

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.posLight,
          content: Text('${backup.academicYear} yedeği ve fotoğrafları başarıyla geri yüklendi!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(backgroundColor: AppTheme.negLight, content: Text('Geri yükleme hatası: $e')),
        );
      }
    }
  }

  // Telefonda Kayıtlı Yedeği Sil
  Future<void> _deleteBackup(BackupItemInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Yedeği Sil', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '${backup.academicYear} tarihli "${backup.fileName}" yedeği telefon hafızasından silinecektir. Onaylıyor musunuz?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BackupService.deleteBackup(backup.file);
      await _loadBackups();
    }
  }

  Future<void> _changeDailyPeriodsCount(int count) async {
    final appProv = context.read<AppProvider>();
    final scheduleProv = context.read<ScheduleProvider>();
    final currentCount = appProv.dailyPeriodsCount;

    if (count < 1 || count > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text('Günlük ders saati 1 ile 15 arasında olmalıdır.'),
          ),
        );
      }
      _dailyPeriodsCtrl.text = currentCount.toString();
      return;
    }

    if (count == currentCount) {
      _dailyPeriodsCtrl.text = count.toString();
      return;
    }

    if (count < currentCount) {
      final hasAssignedLessons = scheduleProv.timetable.any((t) {
        final period = scheduleProv.bellPeriods.firstWhere(
          (p) => p.id == t.periodId,
          orElse: () => BellPeriodModel(id: -1, periodNo: 0, startTime: '', endTime: '', label: ''),
        );
        return period.periodNo > count;
      });

      if (hasAssignedLessons) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Ders Saati Azaltma', style: TextStyle(fontWeight: FontWeight.w900)),
            content: Text(
              'Günlük ders saatini $count saate düşürdüğünüzde, $count. saatten sonraki saatlere atanmış dersler programdan kaldırılacaktır. Devam etmek istiyor musunuz?',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.negLight,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Evet, Azalt'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          _dailyPeriodsCtrl.text = currentCount.toString();
          return;
        }
      }
    }

    _dailyPeriodsCtrl.text = count.toString();
    await appProv.setDailyPeriodsCount(count);
    await scheduleProv.syncBellPeriodsCount(count);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.posLight,
          content: Text('Günlük ders saati $count saat olarak güncellendi.'),
        ),
      );
    }
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                : (isDark ? AppTheme.bgDark : AppTheme.bgLight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                  : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? AppTheme.brandDark : Colors.white)
                    : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? AppTheme.brandDark : Colors.white)
                        : (isDark ? AppTheme.inkDark : AppTheme.inkLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCountOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                : (isDark ? AppTheme.bgDark : AppTheme.bgLight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                  : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isSelected
                        ? (isDark ? AppTheme.brandDark : Colors.white)
                        : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected
                          ? (isDark ? AppTheme.brandDark : Colors.white)
                          : (isDark ? AppTheme.inkDark : AppTheme.inkLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? (isDark ? AppTheme.brandDark.withOpacity(0.85) : Colors.white.withOpacity(0.85))
                      : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifyTypeOption({
    required String typeKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _lessonNotifyType = typeKey;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.accent.withOpacity(0.18) : AppTheme.brandLight.withOpacity(0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? (isDark ? AppTheme.accent : AppTheme.brandLight) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? (isDark ? AppTheme.accent : AppTheme.brandLight) : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: typeKey,
              groupValue: _lessonNotifyType,
              activeColor: isDark ? AppTheme.accent : AppTheme.brandLight,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _lessonNotifyType = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonNotificationTab(
    BuildContext context,
    AppProvider appProv,
    ScheduleProvider scheduleProv,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ana Bildirim Kartı
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: isDark ? AppTheme.accent : AppTheme.brandLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ders Başlama & Bitiş Bildirimleri',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ders programınıza göre akıllı zamanlı uyarılar',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _lessonNotifyEnabled,
                      activeColor: AppTheme.accent,
                      onChanged: (val) {
                        setState(() {
                          _lessonNotifyEnabled = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Haftalık ders programınızda tanımlanan ders saatleri baz alınarak, ders başlamadan ve ders bitmeden önce belirlediğiniz dakikada sesli veya titreşimli bildirim gönderilir.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_lessonNotifyEnabled) ...[
          if (!_canScheduleExact) ...[
            Card(
              color: isDark ? const Color(0xFF451A03).withOpacity(0.5) : Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.amber.shade400),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alarm_on_rounded, color: Colors.amber.shade800, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tam Zamanında Alarm İzni Gerekli',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Android sisteminde ders bildirimlerinin zil saatinde tam dakikasında çalabilmesi için "Alarmlar ve Hatırlatıcılar" sistem iznini açmanız önerilir.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await NotificationService.instance.requestExactAlarmsPermission();
                          final canExact = await NotificationService.instance.canScheduleExactNotifications();
                          if (mounted) setState(() => _canScheduleExact = canExact);
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('İzni Etkinleştir (Sistem Ayarlarını Aç)', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 1. Ders Başlama Bildirimi Ayarları Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ders Başlama Uyarısı',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: _lessonStartNotifyEnabled,
                        activeColor: AppTheme.brandLight,
                        onChanged: (val) {
                          setState(() {
                            _lessonStartNotifyEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_lessonStartNotifyEnabled) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ders başlamadan kaç dakika önce bildirilsin?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 2, 3, 5, 10, 15].map((mins) {
                        final isSel = _lessonStartMinutes == mins;
                        return ChoiceChip(
                          label: Text('$mins dakika'),
                          selected: isSel,
                          selectedColor: AppTheme.brandLight,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _lessonStartMinutes = mins);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Önizleme Kutusu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.bgDark : Colors.green.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? AppTheme.lineDark : Colors.green.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 20, color: isDark ? AppTheme.accent : Colors.green.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ders Başlıyor (Örnek Sınıf)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.accent : Colors.green.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ders başlıyor. $_lessonStartMinutes dakika kaldı.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Ders Bitiş Bildirimi Ayarları Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('⏳', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ders Bitiş Uyarısı',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: _lessonEndNotifyEnabled,
                        activeColor: AppTheme.brandLight,
                        onChanged: (val) {
                          setState(() {
                            _lessonEndNotifyEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_lessonEndNotifyEnabled) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ders bitmeden kaç dakika önce bildirilsin?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 2, 3, 5, 10, 15].map((mins) {
                        final isSel = _lessonEndMinutes == mins;
                        return ChoiceChip(
                          label: Text('$mins dakika'),
                          selected: isSel,
                          selectedColor: AppTheme.accent,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _lessonEndMinutes = mins);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Önizleme Kutusu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.bgDark : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? AppTheme.lineDark : Colors.orange.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 20, color: isDark ? AppTheme.accent : Colors.orange.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ders Bitiyor (Örnek Sınıf)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.accent : Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ders bitiyor. $_lessonEndMinutes dakika kaldı.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Ses ve Titreşim Tercihi Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🔊', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('Bildirim Türü', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bildirimlerin nasıl iletileceğini belirleyin.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 12),
                  _buildNotifyTypeOption(
                    typeKey: 'both',
                    icon: Icons.notifications_active_rounded,
                    title: 'Sesli ve Titreşimli',
                    subtitle: 'Hem ses çalar hem de cihaz titreşir',
                    isSelected: _lessonNotifyType == 'both',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildNotifyTypeOption(
                    typeKey: 'sound',
                    icon: Icons.volume_up_rounded,
                    title: 'Yalnızca Sesli',
                    subtitle: 'Yalnızca ses çalar, titreşim olmaz',
                    isSelected: _lessonNotifyType == 'sound',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildNotifyTypeOption(
                    typeKey: 'vibrate',
                    icon: Icons.vibration_rounded,
                    title: 'Yalnızca Titreşimli',
                    subtitle: 'Sessiz ortamlar ve ders esnası için idealdir',
                    isSelected: _lessonNotifyType == 'vibrate',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Program Bilgi Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 28,
                    color: scheduleProv.timetable.isNotEmpty ? AppTheme.posLight : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scheduleProv.timetable.isNotEmpty
                              ? 'Ders Programı Entegre Edildi'
                              : 'Henüz Ders Tanımlanmadı',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scheduleProv.timetable.isNotEmpty
                              ? 'Haftalık programınızdaki toplam ${scheduleProv.timetable.length} ders saati için bildirimler zil saatlerine göre otomatik planlanır.'
                              : 'Ders Programı sekmesinden derslerinizi girdiğinizde bildirimler otomatik devreye girecektir.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test Butonları (Anlık ve 10sn Zamanlı Test)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.science_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Bildirim Testleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hem anlık bildirimi hem de arka plan zamanlayıcısını (10 saniye sonra) test edebilirsiniz.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isTestingNotification
                              ? null
                              : () async {
                                  setState(() => _isTestingNotification = true);
                                  try {
                                    await NotificationService.instance.showTestNotification(
                                      notifyType: _lessonNotifyType,
                                      minutes: _lessonStartNotifyEnabled ? _lessonStartMinutes : _lessonEndMinutes,
                                      isStart: _lessonStartNotifyEnabled,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppTheme.posLight,
                                          content: Text('Anlık test bildirimi gönderildi!'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.negLight,
                                          content: Text('Test hatası: $e'),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isTestingNotification = false);
                                  }
                                },
                          icon: const Icon(Icons.touch_app_rounded, size: 16),
                          label: Text(_isTestingNotification ? 'Gönderiliyor...' : 'Anlık Test'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isTestingScheduledNotification
                              ? null
                              : () async {
                                  setState(() => _isTestingScheduledNotification = true);
                                  try {
                                    await NotificationService.instance.showScheduledTestNotification(
                                      notifyType: _lessonNotifyType,
                                      seconds: 10,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppTheme.posLight,
                                          duration: Duration(seconds: 4),
                                          content: Text('10 saniye sonra zamanlı test uyarısı çalacak. Uygulamayı simge durumuna alıp test edebilirsiniz!'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.negLight,
                                          content: Text('Zamanlı test hatası: $e'),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isTestingScheduledNotification = false);
                                  }
                                },
                          icon: const Icon(Icons.timer_outlined, size: 16),
                          label: Text(_isTestingScheduledNotification ? 'Planlandı...' : '10 Sn Sonra Test'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Ayarları Kaydet Butonu
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSavingNotifications
                ? null
                : () async {
                    setState(() => _isSavingNotifications = true);
                    try {
                      // Android 13+ bildirim iznini garanti et
                      await NotificationService.instance.requestPermissions();

                      await appProv.updateLessonNotificationSettings(
                        enabled: _lessonNotifyEnabled,
                        startEnabled: _lessonStartNotifyEnabled,
                        startMinutes: _lessonStartMinutes,
                        endEnabled: _lessonEndNotifyEnabled,
                        endMinutes: _lessonEndMinutes,
                        notifyType: _lessonNotifyType,
                      );

                      final scheduledCount = await scheduleProv.rescheduleNotifications();
                      await _checkExactAlarmPermission();

                      if (mounted) {
                        String msg;
                        if (!_lessonNotifyEnabled) {
                          msg = 'Ders bildirimleri kapatıldı.';
                        } else if (scheduledCount > 0) {
                          msg = 'Bildirim ayarları kaydedildi ve $scheduledCount ders uyarısı başarıyla planlandı.';
                        } else {
                          msg = 'Bildirim ayarları kaydedildi. Ders programında kayıtlı ders bulunmadığı için aktif uyarı oluşturulmadı.';
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.posLight,
                            content: Text(msg),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.negLight,
                            content: Text('Kayıt hatası: $e'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSavingNotifications = false);
                    }
                  },
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              _isSavingNotifications ? 'Kaydediliyor...' : 'Bildirim Ayarlarını Kaydet ve Başlat',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ] else ...[
          // Kapalı durumu için kaydet butonu
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await appProv.updateLessonNotificationSettings(
                enabled: false,
                startEnabled: _lessonStartNotifyEnabled,
                startMinutes: _lessonStartMinutes,
                endEnabled: _lessonEndNotifyEnabled,
                endMinutes: _lessonEndMinutes,
                notifyType: _lessonNotifyType,
              );
              await scheduleProv.rescheduleNotifications();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.posLight,
                    content: Text('Ders bildirimleri kapatıldı.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Değişikliği Kaydet'),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final scheduleProv = context.watch<ScheduleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAcademicYear = _getCurrentAcademicYear(appProv);

    if (!_isInit && appProv.settings != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isInit) {
          setState(() {
            _syncSettings(appProv.settings);
          });
        }
      });
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayarlar'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorWeight: 3,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(
                icon: Icon(Icons.person_rounded, size: 20),
                text: 'Profil & Genel',
              ),
              Tab(
                icon: Icon(Icons.calendar_month_rounded, size: 20),
                text: 'Ders & Program',
              ),
              Tab(
                icon: Icon(Icons.notifications_active_rounded, size: 20),
                text: 'Bildirimler',
              ),
              Tab(
                icon: Icon(Icons.cloud_sync_rounded, size: 20),
                text: 'Yedek & Kurum',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Sekme: Profil & Genel
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileCard(context, appProv, isDark),
                const SizedBox(height: 12),
                _buildThemeCard(appProv, isDark),
                const SizedBox(height: 12),
                _buildWizardCard(context, isDark),
                const SizedBox(height: 12),
                _buildAppInfoCard(isDark),
                const SizedBox(height: 24),
              ],
            ),

            // 2. Sekme: Ders & Program
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSubjectsCard(context, appProv, isDark),
                const SizedBox(height: 12),
                _buildDailyPeriodsCard(context, appProv, scheduleProv, isDark),
                const SizedBox(height: 12),
                _buildTimetableDaysCard(appProv, isDark),
                const SizedBox(height: 12),
                _buildBellPeriodsCard(context, scheduleProv, isDark),
                const SizedBox(height: 24),
              ],
            ),

            // 3. Sekme: Bildirimler
            _buildLessonNotificationTab(context, appProv, scheduleProv, isDark),

            // 4. Sekme: Yedek & Kurum
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInstitutionShareCard(context, isDark),
                const SizedBox(height: 12),
                _buildBackupRestoreCard(context, appProv, isDark, currentAcademicYear),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1. Öğretmen Profili & Eğitim Öğretim Yılı Kartı
  Widget _buildProfileCard(BuildContext context, AppProvider appProv, bool isDark) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Text('👤', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('Öğretmen Profili', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _schoolCtrl,
                    decoration: const InputDecoration(labelText: 'Okul Adı'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _branchCtrl,
                    decoration: const InputDecoration(labelText: 'Branş'),
                  ),
                  const SizedBox(height: 14),

                  // Merkezi Eğitim Öğretim Yılı Yönetimi
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Eğitim Öğretim Yılı',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tüm sınıflar için varsayılan',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _yearCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Örn: ${AppProvider.defaultAcademicYear}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sınıf eklerken bu değer otomatik olarak atanır. Tekrar sormaz.',
                          style: TextStyle(fontSize: 10, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            await appProv.updateSettings(
                              teacherName: _nameCtrl.text.trim(),
                              schoolName: _schoolCtrl.text.trim(),
                              branch: _branchCtrl.text.trim(),
                              academicYear: _yearCtrl.text.trim(),
                            );
                            setState(() => _isSaving = false);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.posLight,
                                  content: Text('Profil ve Eğitim Yılı ayarları kaydedildi.'),
                                ),
                              );
                            }
                          },
                    child: Text(_isSaving ? 'Kaydediliyor...' : 'Profil Bilgilerini Güncelle'),
                  ),
                ],
              ),
            ),
          );
  }

  // 2. Girdiğim Dersler Kartı
  Widget _buildSubjectsCard(BuildContext context, AppProvider appProv, bool isDark) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📚', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Girdiğim Dersler',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${appProv.subjects.length} Ders',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.accent : AppTheme.brandLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Haftalık programınızı ve sınıflarınızı oluştururken bu listedeki dersleri hızlıca seçebilirsiniz.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 12),
                  // Yeni Ders Ekleme Kutusu
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSubjectCtrl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              appProv.addSubject(val.trim());
                              _newSubjectCtrl.clear();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Ders adı yazın (Örn: Matematik, Fizik)',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle, color: AppTheme.brandLight),
                              tooltip: 'Ders Ekle',
                              onPressed: () {
                                if (_newSubjectCtrl.text.trim().isNotEmpty) {
                                  appProv.addSubject(_newSubjectCtrl.text.trim());
                                  _newSubjectCtrl.clear();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Ekli Dersler
                  if (appProv.subjects.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: appProv.subjects.map((sub) {
                        return Chip(
                          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                          side: BorderSide(
                            color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                          ),
                          label: Text(
                            sub,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => appProv.removeSubject(sub),
                        );
                      }).toList(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Henüz ders eklenmedi. Yukarıdaki alandan ders ekleyebilirsiniz.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
  }

  // 3. Günlük Ders Saati Kartı
  Widget _buildDailyPeriodsCard(
    BuildContext context,
    AppProvider appProv,
    ScheduleProvider scheduleProv,
    bool isDark,
  ) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('⏱️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Günlük Ders Saati',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${appProv.dailyPeriodsCount} Ders / Gün',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.accent : AppTheme.brandLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Günde kaç ders saati işleneceğini sayısal olarak belirleyin (1 - 15 saat arası, Varsayılan: 8 Ders). Ders programı ve zil saatleri bu değere göre güncellenir.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Eksi Butonu
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                          foregroundColor: isDark ? AppTheme.brandDark : Colors.white,
                        ),
                        onPressed: appProv.dailyPeriodsCount > 1
                            ? () => _changeDailyPeriodsCount(appProv.dailyPeriodsCount - 1)
                            : null,
                        icon: const Icon(Icons.remove, size: 20),
                        tooltip: '1 Azalt',
                      ),
                      const SizedBox(width: 8),

                      // Sayısal Giriş Alanı
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _dailyPeriodsCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 2,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '8',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null) {
                              _changeDailyPeriodsCount(parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Artı Butonu
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                          foregroundColor: isDark ? AppTheme.brandDark : Colors.white,
                        ),
                        onPressed: appProv.dailyPeriodsCount < 15
                            ? () => _changeDailyPeriodsCount(appProv.dailyPeriodsCount + 1)
                            : null,
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: '1 Artır',
                      ),
                      const SizedBox(width: 10),

                      // Uygula Butonu
                      ElevatedButton(
                        onPressed: () {
                          final parsed = int.tryParse(_dailyPeriodsCtrl.text.trim());
                          if (parsed != null) {
                            _changeDailyPeriodsCount(parsed);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.negLight,
                                content: Text('Lütfen 1 ile 15 arasında bir sayı girin.'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 44),
                          backgroundColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                          foregroundColor: isDark ? AppTheme.brandDark : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  // Varsayılan (8) Butonu
                  if (appProv.dailyPeriodsCount != 8) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _changeDailyPeriodsCount(8),
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Varsayılan 8 saate sıfırla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
  }

  // 4. Zil Saatleri Kartı
  Widget _buildBellPeriodsCard(
    BuildContext context,
    ScheduleProvider scheduleProv,
    bool isDark,
  ) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Zil Saatleri (Periyotlar)',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showBellPeriodsSheet(context),
                        child: const Text('Düzenle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kayıtlı ${scheduleProv.bellPeriods.length} ders periyodu bulunuyor.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                ],
              ),
            ),
          );
  }

  // 5. Haftalık Ders Programı Gün Sayısı Kartı
  Widget _buildTimetableDaysCard(AppProvider appProv, bool isDark) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📅', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Haftalık Ders Programı Gün Sayısı',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${appProv.timetableDays} Günlük',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.accent : AppTheme.brandLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ders programınızın hafta sonunu (Cumartesi - Pazar) içerip içermeyeceğini belirleyin.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDayCountOption(
                        title: '5 Günlük',
                        subtitle: 'Pazartesi - Cuma',
                        isSelected: appProv.timetableDays == 5,
                        onTap: () => appProv.setTimetableDays(5),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildDayCountOption(
                        title: '7 Günlük',
                        subtitle: 'Tüm Hafta (Pzt - Paz)',
                        isSelected: appProv.timetableDays == 7,
                        onTap: () => appProv.setTimetableDays(7),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }

  // 6. Kurum Verisi Paylaşımı & İçe Aktarma Kartı
  Widget _buildInstitutionShareCard(BuildContext context, bool isDark) {
    return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFF25D366).withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kurum İçin Paylaş (WhatsApp)',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            Text(
                              'Sınıflar, Öğrenciler, Fotoğraflar ve Zil Saatleri',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tüm sınıfları, sınıflardaki öğrencileri, fotoğraflarını ve okul zil saatlerini tek paket halinde WhatsApp üzerinden diğer öğretmenlerle paylaşın. Dosyayı alan öğretmen doğrudan açtığında veya "İçe Aktar" butonuna bastığında tüm veriler programına otomatik işlenir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // WhatsApp ile Paylaş Butonu
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_isSharingInstitution || _isImportingInstitution)
                              ? null
                              : _shareInstitutionData,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSharingInstitution
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSharingInstitution ? 'Hazırlanıyor...' : 'WhatsApp ile Paylaş',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // İçe Aktar Butonu
                      OutlinedButton.icon(
                        onPressed: (_isSharingInstitution || _isImportingInstitution)
                            ? null
                            : _importInstitutionData,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isImportingInstitution
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          'İçe Aktar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }

  // 7. Eğitim Öğretim Yılı Yedekleme ve Geri Yükleme Kartı
  Widget _buildBackupRestoreCard(
    BuildContext context,
    AppProvider appProv,
    bool isDark,
    String currentAcademicYear,
  ) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('💾', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Eğitim Öğretim Yılı Yedekleme & Geri Yükleme',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.brandLight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentAcademicYear,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.posDark : AppTheme.brandLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Veritabanınız ve tüm öğrenci fotoğrafları telefonun dahili hafızasına güvenle arşivlenir. Her eğitim öğretim yılı için tek ve benzersiz bir yedek tutulur, aynı yıl için tekrar yedek alındığında mevcut yedeğin üzerine yazılır.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: (_isBackingUp || _isRestoring) ? null : _createBackupAndPrompt,
                    icon: _isBackingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.archive_rounded),
                    label: Text(
                      _isBackingUp
                          ? 'Yedekleniyor...'
                          : '$currentAcademicYear Yılını Yedekle (DB + Fotoğraflar)',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      backgroundColor: AppTheme.brandLight,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: isDark ? AppTheme.posDark : AppTheme.brandLight,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Cihazdaki Kayıtlı Yedekler',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_backups.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Listeyi Yenile',
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        onPressed: _isLoadingBackups ? null : _loadBackups,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingBackups)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_backups.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Telefon hafızasında henüz kayıtlı yedek bulunmuyor.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _backups.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final b = _backups[index];
                        final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(b.createdAt);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardDark : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppTheme.posDark : AppTheme.brandLight).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.folder_zip_rounded,
                                      size: 20,
                                      color: isDark ? AppTheme.posDark : AppTheme.brandLight,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              b.academicYear,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                b.formattedSize,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Yedeği Sil',
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: (_isBackingUp || _isRestoring) ? null : () => _deleteBackup(b),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${b.classCount} sınıf • ${b.studentCount} öğrenci • ${b.photoCount} fotoğraf',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: (_isBackingUp || _isRestoring) ? null : () => _restoreBackup(b),
                                    icon: const Icon(Icons.restore_rounded, size: 16),
                                    label: const Text('Geri Yükle', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
  }

  // 8. Görünüm & Tema Kartı
  Widget _buildThemeCard(AppProvider appProv, bool isDark) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🎨', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('Görünüm ve Tema', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildThemeOption(
                        icon: Icons.light_mode_rounded,
                        label: 'Açık',
                        isSelected: appProv.themeMode == ThemeMode.light,
                        onTap: () => appProv.setTheme('light'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        icon: Icons.dark_mode_rounded,
                        label: 'Koyu',
                        isSelected: appProv.themeMode == ThemeMode.dark,
                        onTap: () => appProv.setTheme('dark'),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        icon: Icons.brightness_auto_rounded,
                        label: 'Sistem',
                        isSelected: appProv.themeMode == ThemeMode.system,
                        onTap: () => appProv.setTheme('system'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }

  // 9. Kurulum & Karşılama Sihirbazı Kartı
  Widget _buildWizardCard(BuildContext context, bool isDark) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🚀', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Kurulum & Karşılama Sihirbazı',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Rehber',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.accent : AppTheme.brandLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'İlk kurulum ekranlarını ve adım adım veri giriş sihirbazını dilediğiniz zaman buradan yeniden başlatabilir veya temiz verilerle çalışmaya başlayabilirsiniz.',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(isFromSettings: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline_rounded, size: 16),
                          label: const Text('Karşılama Ekranı', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SetupWizardScreen(isFromSettings: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Kurulum Sihirbazı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }

  // 10. Uygulama Bilgisi & Logo Kartı
  Widget _buildAppInfoCard(bool isDark) {
    return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ÖğretmenCep',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Akıllı Öğretmen Asistanı • v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tamamen yerel & güvenli SQLite veritabanı',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
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

class _TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final text = newValue.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) {
        buffer.write(':');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

