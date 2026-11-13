import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/test_data_seeder.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/classes_provider.dart';
import '../../providers/plans_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/students_provider.dart';
import '../../theme/app_theme.dart';
import '../home_shell.dart';

class SetupWizardScreen extends StatefulWidget {
  final bool isFromSettings;

  const SetupWizardScreen({Key? key, this.isFromSettings = false}) : super(key: key);

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  static const int _totalSteps = 7;

  // Adım 1: Profil
  late TextEditingController _nameCtrl;
  late TextEditingController _schoolCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _yearCtrl;

  // Adım 2: Ders İsimleri
  final TextEditingController _newSubjectCtrl = TextEditingController();

  // Adım 3: Zil Saatleri
  int _dailyPeriodsCount = 8;
  int _timetableDays = 5;

  // Adım 4: Ders Programı
  int _selectedWeekday = 1; // 1: Pazartesi ... 5: Cuma

  // Adım 5: Sınıf Tanımlama
  final TextEditingController _classNameCtrl = TextEditingController();
  final TextEditingController _classGradeCtrl = TextEditingController();
  String _selectedClassColor = '#17433B';
  String? _selectedClassSubject;

  // Adım 6: Ders Planları
  int? _selectedPlanClassId;
  bool _isGeneratingPlan = false;

  // Adım 7: Öğrenci Fotoğrafları
  int? _selectedPhotoClassId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final appProv = context.read<AppProvider>();
    final settings = appProv.settings;

    _nameCtrl = TextEditingController(text: settings?.teacherName ?? '');
    _schoolCtrl = TextEditingController(text: settings?.schoolName ?? '');
    _branchCtrl = TextEditingController(text: settings?.branch ?? '');
    _yearCtrl = TextEditingController(text: settings?.academicYear ?? AppProvider.defaultAcademicYear);
    _dailyPeriodsCount = appProv.dailyPeriodsCount;
    _timetableDays = appProv.timetableDays;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().fetchBellPeriods();
      context.read<ScheduleProvider>().fetchTimetable();
      context.read<ClassesProvider>().fetchClasses();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _branchCtrl.dispose();
    _yearCtrl.dispose();
    _newSubjectCtrl.dispose();
    _classNameCtrl.dispose();
    _classGradeCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    } else {
      _finishSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _finishSetup() async {
    final appProv = context.read<AppProvider>();
    final teacherNameInput = _nameCtrl.text.trim();
    final schoolNameInput = _schoolCtrl.text.trim();
    final branchInput = _branchCtrl.text.trim();
    final yearInput = _yearCtrl.text.trim();

    // Kurulum tamamlanırken profil bilgilerini kesin olarak veritabanına kaydet
    await appProv.updateSettings(
      teacherName: teacherNameInput.isNotEmpty
          ? teacherNameInput
          : (appProv.settings?.teacherName.trim().isNotEmpty == true
              ? appProv.settings!.teacherName.trim()
              : 'Öğretmen'),
      schoolName: schoolNameInput.isNotEmpty
          ? schoolNameInput
          : (appProv.settings?.schoolName.trim().isNotEmpty == true
              ? appProv.settings!.schoolName.trim()
              : ''),
      branch: branchInput.isNotEmpty
          ? branchInput
          : (appProv.settings?.branch.trim().isNotEmpty == true
              ? appProv.settings!.branch.trim()
              : ''),
      academicYear: yearInput.isNotEmpty
          ? yearInput
          : appProv.activeAcademicYear,
      isOnboardingCompleted: true,
    );

    // Güncel ayarları yeniden yükle
    await appProv.loadSettings();

    if (!mounted) return;
    if (widget.isFromSettings) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    }
  }

  Future<void> _skipEntireWizard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kurulumu Atla', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Kurulum sihirbazını dilediğiniz zaman Ayarlar menüsünden tekrar çalıştırabilirsiniz. Doğrudan Bugün sayfasına geçmek istiyor musunuz?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandLight,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Şimdi Başla'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _finishSetup();
    }
  }

  // --- ADIM 1: PROFİL KAYDET ---
  Future<void> _saveStep1() async {
    final appProv = context.read<AppProvider>();
    final teacherNameInput = _nameCtrl.text.trim();
    final schoolNameInput = _schoolCtrl.text.trim();
    final branchInput = _branchCtrl.text.trim();
    final yearInput = _yearCtrl.text.trim();

    await appProv.updateSettings(
      teacherName: teacherNameInput.isNotEmpty ? teacherNameInput : 'Öğretmen',
      schoolName: schoolNameInput,
      branch: branchInput,
      academicYear: yearInput.isNotEmpty ? yearInput : AppProvider.defaultAcademicYear,
    );
    _nextStep();
  }

  // --- ADIM 2: DERS KAYDET ---
  void _saveStep2() {
    _nextStep();
  }

  // --- ADIM 3: ZİL SAATLERİ KAYDET ---
  Future<void> _saveStep3() async {
    final appProv = context.read<AppProvider>();
    final scheduleProv = context.read<ScheduleProvider>();

    if (_dailyPeriodsCount != appProv.dailyPeriodsCount) {
      await appProv.setDailyPeriodsCount(_dailyPeriodsCount);
      await scheduleProv.syncBellPeriodsCount(_dailyPeriodsCount);
    }
    if (_timetableDays != appProv.timetableDays) {
      await appProv.setTimetableDays(_timetableDays);
    }
    _nextStep();
  }

  // --- ADIM 4: DERS PROGRAMI KAYDET ---
  void _saveStep4() {
    _nextStep();
  }

  // --- ADIM 5: SINIF KAYDET ---
  void _saveStep5() {
    _nextStep();
  }

  // --- ADIM 6: DERS PLANI KAYDET ---
  void _saveStep6() {
    _nextStep();
  }

  // --- ADIM 7: FOTOĞRAF KAYDET ---
  void _saveStep7() {
    _nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_currentStep) / _totalSteps;

    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _previousStep();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _previousStep,
          ),
          title: Text(
            _currentStep < _totalSteps
                ? 'Hızlı Kurulum (${_currentStep + 1} / $_totalSteps)'
                : 'Kurulum Tamamlandı',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          actions: [
            if (_currentStep < _totalSteps)
              TextButton(
                onPressed: _skipEntireWizard,
                child: const Text('Kurulumu Atla', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppTheme.accent : AppTheme.brandLight,
              ),
              minHeight: 4,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildCurrentStepContent(isDark),
                ),
              ),

              // Alt Buton Çubuğu
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (_currentStep < _totalSteps) ...[
                      // Adımı Atla Butonu
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (_currentStep == 0) {
                              final name = _nameCtrl.text.trim();
                              final school = _schoolCtrl.text.trim();
                              final branch = _branchCtrl.text.trim();
                              final year = _yearCtrl.text.trim();
                              if (name.isNotEmpty || school.isNotEmpty || branch.isNotEmpty) {
                                await context.read<AppProvider>().updateSettings(
                                  teacherName: name.isNotEmpty ? name : null,
                                  schoolName: school.isNotEmpty ? school : null,
                                  branch: branch.isNotEmpty ? branch : null,
                                  academicYear: year.isNotEmpty ? year : null,
                                );
                              }
                            }
                            _nextStep();
                          },
                          child: const Text(
                            'Bu Adımı Atla',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Kaydet ve İlerle Butonu
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandLight,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(80, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _onSaveStepPressed(),
                          child: const Text(
                            'Kaydet & İlerle →',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Son Adım: Bugün Sayfasına Git
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _finishSetup,
                          icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                          label: const Text(
                            'Bugün Sayfasına Başla 🚀',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSaveStepPressed() async {
    switch (_currentStep) {
      case 0:
        await _saveStep1();
        break;
      case 1:
        _saveStep2();
        break;
      case 2:
        await _saveStep3();
        break;
      case 3:
        _saveStep4();
        break;
      case 4:
        _saveStep5();
        break;
      case 5:
        _saveStep6();
        break;
      case 6:
        _saveStep7();
        break;
      default:
        _nextStep();
    }
  }

  Widget _buildCurrentStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Profile(isDark);
      case 1:
        return _buildStep2Subjects(isDark);
      case 2:
        return _buildStep3BellPeriods(isDark);
      case 3:
        return _buildStep4Timetable(isDark);
      case 4:
        return _buildStep5Classes(isDark);
      case 5:
        return _buildStep6LessonPlans(isDark);
      case 6:
        return _buildStep7Photos(isDark);
      case 7:
        return _buildStepCompletion(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // ADIM 1: PROFİL BİLGİLERİ
  // ==========================================
  Widget _buildStep1Profile(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.badge_rounded,
          color: const Color(0xFF3B82F6),
          title: 'Öğretmen Profilinizi Belirleyin',
          description: 'Uygulama raporlarında, yoklama listelerinde ve ders programında görünecek bilgilerinizi girin. Bu alanları dilediğiniz zaman değiştirebilirsiniz.',
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Adınız Soyadınız',
            hintText: 'Örn: Ahmet Yılmaz',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _branchCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Ana Branşınız',
            hintText: 'Örn: Matematik, Fizik, Bilişim...',
            prefixIcon: Icon(Icons.school_outlined),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _schoolCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Okulunuzun Adı',
            hintText: 'Örn: Atatürk Anadolu Lisesi',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _yearCtrl,
          decoration: InputDecoration(
            labelText: 'Eğitim-Öğretim Yılı',
            hintText: 'Örn: ${AppProvider.defaultAcademicYear}',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ADIM 2: DERS İSİMLERİ TANIMLAMA
  // ==========================================
  Widget _buildStep2Subjects(bool isDark) {
    final appProv = context.watch<AppProvider>();
    final subjects = appProv.subjects;

    final popularSuggestions = [
      'Matematik', 'Geometri', 'Türk Dili ve Edebiyatı', 'Türkçe',
      'Fizik', 'Kimya', 'Biyoloji', 'Fen Bilimleri',
      'Tarih', 'T.C. İnkılap Tarihi', 'Coğrafya', 'Felsefe',
      'İngilizce', 'Almanca', 'Din Kültürü ve Ahlak Bilgisi',
      'Beden Eğitimi', 'Müzik', 'Görsel Sanatlar',
      'Bilişim Teknolojileri', 'Robotik Kodlama', 'Rehberlik',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF10B981),
          title: 'Girdiğiniz Ders İsimleri',
          description: 'Haftalık ders programınızda ve sınıflarınızda yer alacak ders isimlerini ekleyin veya aşağıdaki önerilerden tek dokunuşla seçin.',
        ),
        const SizedBox(height: 20),

        // Yeni Ders Ekleme Girişi
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
                decoration: const InputDecoration(
                  labelText: 'Ders Adı Yazın',
                  hintText: 'Örn: Mantık, Astronomi...',
                  prefixIcon: Icon(Icons.add_task_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandLight,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (_newSubjectCtrl.text.trim().isNotEmpty) {
                  appProv.addSubject(_newSubjectCtrl.text.trim());
                  _newSubjectCtrl.clear();
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Tanımlı Dersler Listesi
        Text(
          'Tanımlı Dersleriniz (${subjects.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),

        if (subjects.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Henüz ekli bir dersiniz yok. Aşağıdaki önerilerden seçebilir veya yukarıdan yazıp ekleyebilirsiniz.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subjects.map((sub) {
              return Chip(
                backgroundColor: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                label: Text(
                  sub,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.accent : AppTheme.brandLight,
                  ),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => appProv.removeSubject(sub),
              );
            }).toList(),
          ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),

        // Popüler Ders Önerileri
        const Text(
          'Hızlı Seçim (Tek Dokunuşla Ekleyin):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: popularSuggestions.map((sug) {
            final isAdded = subjects.contains(sug);
            return ActionChip(
              avatar: Icon(
                isAdded ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 16,
                color: isAdded ? Colors.green : null,
              ),
              label: Text(sug),
              onPressed: () {
                if (!isAdded) {
                  appProv.addSubject(sug);
                } else {
                  appProv.removeSubject(sug);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // ADIM 3: ZİL SAATLERİ & GÜNLÜK DERS SAYISI
  // ==========================================
  Widget _buildStep3BellPeriods(bool isDark) {
    final scheduleProv = context.watch<ScheduleProvider>();
    final periods = scheduleProv.bellPeriods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFF59E0B),
          title: 'Ders Zil Saatleri & Gün Sayısı',
          description: 'Okulunuzda günde kaç ders işlendiğini ve zil saatlerini belirleyin. Canlı ders takibi ve teneffüs bildirimleri bu saatlere göre çalışır.',
        ),
        const SizedBox(height: 20),

        // Günlük Ders Sayısı
        const Text('Günde Kaç Ders İşleniyor?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [6, 7, 8, 9, 10].map((c) {
            final isSelected = _dailyPeriodsCount == c;
            return ChoiceChip(
              label: Text('$c Ders'),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _dailyPeriodsCount = c);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Haftalık Gün Sayısı
        const Text('Haftalık Program Kaç Gün?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('5 Gün (Haftaiçi)'),
              selected: _timetableDays == 5,
              onSelected: (val) {
                if (val) setState(() => _timetableDays = 5);
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('7 Gün (Tüm Hafta)'),
              selected: _timetableDays == 7,
              onSelected: (val) {
                if (val) setState(() => _timetableDays = 7);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Standart Zil Saatleri Listesi
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Zil Saatleri (${periods.length} Periyot)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            TextButton.icon(
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text('Standart Saatleri Yükle', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                await scheduleProv.syncBellPeriodsCount(_dailyPeriodsCount);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: periods.take(_dailyPeriodsCount).length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, idx) {
            final p = periods[idx];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.brandLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${p.periodNo}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${p.startTime} - ${p.endTime}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // ADIM 4: HAFTALIK DERS PROGRAMI
  // ==========================================
  Widget _buildStep4Timetable(bool isDark) {
    final scheduleProv = context.watch<ScheduleProvider>();
    final classesProv = context.watch<ClassesProvider>();
    final periods = scheduleProv.bellPeriods.take(_dailyPeriodsCount).toList();
    final dayEntries = scheduleProv.getDayEntries(_selectedWeekday);

    final days = [
      {'name': 'Pzt', 'day': 1},
      {'name': 'Sal', 'day': 2},
      {'name': 'Çar', 'day': 3},
      {'name': 'Per', 'day': 4},
      {'name': 'Cum', 'day': 5},
      if (_timetableDays == 7) ...[
        {'name': 'Cmt', 'day': 6},
        {'name': 'Paz', 'day': 7},
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'Haftalık Ders Programınız',
          description: 'Hangi gün ve saatte hangi sınıfın dersinde olduğunuzu belirleyin. İstediğiniz saate dokunarak hızlıca sınıf ve ders atayabilirsiniz.',
        ),
        const SizedBox(height: 16),

        // Gün Seçici Segment
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days.map((d) {
              final dayNum = d['day'] as int;
              final isSel = _selectedWeekday == dayNum;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(d['name'] as String),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedWeekday = dayNum);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Seçilen Günün Ders Saatleri
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: periods.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final period = periods[idx];
            final entry = dayEntries.firstWhere(
              (e) => e.periodId == period.id,
              orElse: () => TimetableEntryModel(
                id: 0,
                classId: 0,
                periodId: period.id,
                weekday: _selectedWeekday,
                subject: '',
              ),
            );

            final hasLesson = entry.id > 0;

            return InkWell(
              onTap: () => _showAssignTimetableBottomSheet(period, entry, classesProv),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasLesson
                      ? (isDark ? AppTheme.cardDark : Colors.white)
                      : (isDark ? Colors.grey[900] : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasLesson
                        ? (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.5)
                        : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${period.periodNo}. Ders',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          Text(
                            '${period.startTime}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: hasLesson
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.className ?? 'Sınıf',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  entry.subject,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Boş Saat (Ders atamak için dokunun)',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                    ),
                    Icon(
                      hasLesson ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
                      size: 20,
                      color: hasLesson ? AppTheme.brandLight : Colors.grey,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAssignTimetableBottomSheet(
    BellPeriodModel period,
    TimetableEntryModel entry,
    ClassesProvider classesProv,
  ) {
    final appProv = context.read<AppProvider>();
    final scheduleProv = context.read<ScheduleProvider>();
    final classes = classesProv.classes;
    final subjects = appProv.subjects;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        int? selClassId = entry.classId > 0 ? entry.classId : (classes.isNotEmpty ? classes.first.id : null);
        String selSubject = entry.subject.isNotEmpty ? entry.subject : (subjects.isNotEmpty ? subjects.first : 'Ders');

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${period.periodNo}. Ders Ataması',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (entry.id > 0)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text('Dersi Kaldır', style: TextStyle(color: Colors.red, fontSize: 12)),
                          onPressed: () async {
                            await scheduleProv.deleteTimetableCell(entry.id);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (classes.isEmpty) ...[
                    const Text('Önce bir sınıf eklemeniz önerilir (Adım 5). Yine de bir sonraki adıma geçebilirsiniz.'),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Text('Sınıf Seçin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selClassId,
                      items: classes.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) => setSheetState(() => selClassId = val),
                    ),
                    const SizedBox(height: 12),

                    const Text('Ders Seçin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: subjects.contains(selSubject) ? selSubject : (subjects.isNotEmpty ? subjects.first : null),
                      items: (subjects.isNotEmpty ? subjects : ['Ders']).map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selSubject = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandLight,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (selClassId != null) {
                            await scheduleProv.setTimetableCell(
                              classId: selClassId!,
                              periodId: period.id,
                              weekday: _selectedWeekday,
                              subject: selSubject,
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('Bu Saate Dersi Kaydet'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ADIM 5: SINIF LİSTELERİ TANIMLAMA
  // ==========================================
  Widget _buildStep5Classes(bool isDark) {
    final classesProv = context.watch<ClassesProvider>();
    final appProv = context.watch<AppProvider>();
    final classes = classesProv.classes;
    final subjects = appProv.subjects;

    final quickClassTemplates = ['9-A', '9-B', '10-A', '10-B', '11-A', '12-A'];
    final colorOptions = [
      '#17433B', '#2563EB', '#7C3AED', '#D97706', '#E11D48', '#059669', '#0891B2',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.groups_rounded,
          color: const Color(0xFF059669),
          title: 'Sınıflarınızı Tanımlayın',
          description: 'Dersine girdiğiniz veya sınıf rehber öğretmeni olduğunuz sınıfları ekleyin. Hızlı şablon butonlarına dokunarak anında sınıf oluşturabilirsiniz.',
        ),
        const SizedBox(height: 20),

        // Hızlı Şablon Butonları
        const Text('Hızlı Şube Ekle (Tek Dokunuş):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: quickClassTemplates.map((tmpl) {
            final exists = classes.any((c) => c.name.toLowerCase() == tmpl.toLowerCase());
            return ActionChip(
              avatar: Icon(
                exists ? Icons.check_circle_rounded : Icons.add_circle_outline,
                size: 16,
                color: exists ? Colors.green : null,
              ),
              label: Text(tmpl),
              onPressed: () async {
                if (!exists) {
                  final grade = tmpl.split('-').first;
                  await classesProv.createClass(
                    name: tmpl,
                    gradeLevel: grade,
                    subject: subjects.isNotEmpty ? subjects.first : null,
                    academicYear: appProv.activeAcademicYear,
                    color: colorOptions[(tmpl.hashCode.abs()) % colorOptions.length],
                  );
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Manuel Yeni Sınıf Ekleme Formu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Özel Sınıf Ekle:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _classNameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Sınıf Adı',
                        hintText: 'Örn: 11-C',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _classGradeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kademe',
                        hintText: '11',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Ders Seçimi
              DropdownButtonFormField<String>(
                value: _selectedClassSubject ?? (subjects.isNotEmpty ? subjects.first : null),
                decoration: const InputDecoration(labelText: 'Varsayılan Ders'),
                items: subjects.map((s) {
                  return DropdownMenuItem<String>(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) => setState(() => _selectedClassSubject = val),
              ),
              const SizedBox(height: 12),

              // Renk Seçimi
              Wrap(
                spacing: 8,
                children: colorOptions.map((cHex) {
                  final color = Color(int.parse(cHex.replaceFirst('#', '0xFF')));
                  final isSelected = _selectedClassColor == cHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedClassColor = cHex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandLight, foregroundColor: Colors.white),
                  onPressed: () async {
                    final name = _classNameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      final grade = _classGradeCtrl.text.trim().isNotEmpty
                          ? _classGradeCtrl.text.trim()
                          : name.replaceAll(RegExp(r'\D'), '');
                      await classesProv.createClass(
                        name: name,
                        gradeLevel: grade.isNotEmpty ? grade : '9',
                        subject: _selectedClassSubject ?? (subjects.isNotEmpty ? subjects.first : null),
                        academicYear: appProv.activeAcademicYear,
                        color: _selectedClassColor,
                      );
                      _classNameCtrl.clear();
                      _classGradeCtrl.clear();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Bu Sınıfı Ekle'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Ekli Sınıflar Listesi
        Text(
          'Tanımlı Sınıflarınız (${classes.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),

        if (classes.isEmpty)
          const Text('Henüz ekli bir sınıf yok. Yukarıdan hızlıca ekleyebilirsiniz.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final c = classes[idx];
              Color clr = AppTheme.brandLight;
              try {
                clr = Color(int.parse(c.color.replaceFirst('#', '0xFF')));
              } catch (_) {}

              return ListTile(
                tileColor: isDark ? AppTheme.cardDark : Colors.grey[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: CircleAvatar(
                  backgroundColor: clr,
                  child: Text(
                    c.gradeLevel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${c.subject ?? "Ders"} • ${c.studentCount} Öğrenci'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                  onPressed: () => classesProv.deleteClass(c.id),
                ),
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // ADIM 6: YILLIK DERS PLANLARI
  // ==========================================
  Widget _buildStep6LessonPlans(bool isDark) {
    final classesProv = context.watch<ClassesProvider>();
    final plansProv = context.watch<PlansProvider>();
    final classes = classesProv.classes;

    if (_selectedPlanClassId == null && classes.isNotEmpty) {
      _selectedPlanClassId = classes.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        plansProv.fetchPlans(classId: _selectedPlanClassId);
      });
    }

    final currentClass = classes.firstWhere(
      (c) => c.id == _selectedPlanClassId,
      orElse: () => classes.isNotEmpty ? classes.first : ClassModel(id: 0, name: '', gradeLevel: '', academicYear: '', color: ''),
    );

    final plans = plansProv.plans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.assignment_rounded,
          color: const Color(0xFFEC4899),
          title: 'Ders Planlarınızı Yükleyin',
          description: 'Hangi sınıfta hangi hafta hangi kazanımın işleneceğini takip edin. Dilerseniz "36 Haftalık MEB Örnek Planı" şablonunu tek tıkla yükleyebilirsiniz.',
        ),
        const SizedBox(height: 16),

        if (classes.isEmpty) ...[
          const Text('Henüz sınıf eklemediniz. Bu adımı atlayıp daha sonra Planlar menüsünden oluşturabilirsiniz.'),
          const SizedBox(height: 16),
        ] else ...[
          // Sınıf Seçimi
          DropdownButtonFormField<int>(
            value: _selectedPlanClassId,
            decoration: const InputDecoration(labelText: 'Plan Yüklenecek Sınıf'),
            items: classes.map((c) {
              return DropdownMenuItem<int>(
                value: c.id,
                child: Text('${c.name} (${c.subject ?? "Ders"})'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedPlanClassId = val);
              if (val != null) plansProv.fetchPlans(classId: val);
            },
          ),
          const SizedBox(height: 14),

          // 36 Haftalık MEB Planı Tek Tıkla Yükleme Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isGeneratingPlan
                  ? null
                  : () async {
                      if (_selectedPlanClassId == null) return;
                      setState(() => _isGeneratingPlan = true);

                      final sub = currentClass.subject ?? 'Matematik';
                      await TestDataSeeder.seedPlanForClass(
                        classId: _selectedPlanClassId!,
                        subject: sub,
                      );
                      await plansProv.fetchPlans(classId: _selectedPlanClassId);

                      setState(() => _isGeneratingPlan = false);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.posLight,
                            content: Text('${currentClass.name} için 36 haftalık MEB planı yüklendi!'),
                          ),
                        );
                      }
                    },
              icon: _isGeneratingPlan
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_stories_rounded, size: 20),
              label: Text(_isGeneratingPlan ? 'Planlar Hazırlanıyor...' : '36 Haftalık MEB Plan Şablonunu Yükle'),
            ),
          ),
          const SizedBox(height: 16),

          // Yüklü Plan Durumu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yüklü Haftalık Planlar (${plans.length} Hafta)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (plans.isNotEmpty)
                TextButton(
                  onPressed: () => plansProv.clearPlansForClass(_selectedPlanClassId!),
                  child: const Text('Temizle', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),

          if (plans.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Bu sınıf için henüz plan eklenmemiş. Yukarıdaki butona basarak 36 haftalık planı anında yükleyebilirsiniz.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plans.take(6).length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final p = plans[idx];
                return ListTile(
                  dense: true,
                  tileColor: isDark ? AppTheme.cardDark : Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.brandLight.withOpacity(0.1),
                    child: Text('${p.weekNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p.topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${p.term}. Dönem • ${p.subject}', style: const TextStyle(fontSize: 11)),
                );
              },
            ),
        ],
      ],
    );
  }

  // ==========================================
  // ADIM 7: ÖĞRENCİ FOTOĞRAFLARI YÜKLEME
  // ==========================================
  Widget _buildStep7Photos(bool isDark) {
    final classesProv = context.watch<ClassesProvider>();
    final studentsProv = context.watch<StudentsProvider>();
    final classes = classesProv.classes;

    if (_selectedPhotoClassId == null && classes.isNotEmpty) {
      _selectedPhotoClassId = classes.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        studentsProv.fetchStudents(_selectedPhotoClassId!);
      });
    }

    final students = studentsProv.students;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.photo_camera_front_rounded,
          color: const Color(0xFF06B6D4),
          title: 'Öğrenci Fotoğraflarını Yükleyin',
          description: 'Öğrencilerinizi yüzleriyle tanıyın. Yoklama alırken ve sözlü notu verirken fotoğraflı listeler büyük kolaylık sağlar. Bu adımı dilediğiniz zaman atlayabilirsiniz.',
        ),
        const SizedBox(height: 16),

        // Bilgilendirme Kutusu
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF06B6D4), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Toplu Fotoğraf İpucu: Sınıf detay sayfasından fotoğrafları öğrenci numarasıyla (Örn: 101.jpg) adlandırarak tek seferde de içe aktarabilirsiniz.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (classes.isEmpty) ...[
          const Text('Henüz sınıf eklenmedi. Bu adımı atlayabilirsiniz.'),
        ] else ...[
          DropdownButtonFormField<int>(
            value: _selectedPhotoClassId,
            decoration: const InputDecoration(labelText: 'Sınıf Seçin'),
            items: classes.map((c) {
              return DropdownMenuItem<int>(
                value: c.id,
                child: Text('${c.name} (${c.studentCount} Öğrenci)'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedPhotoClassId = val);
              if (val != null) studentsProv.fetchStudents(val);
            },
          ),
          const SizedBox(height: 14),

          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Bu sınıfta henüz kayıtlı öğrenci yok. Sınıflar sekmesinden öğrenci ekleyebilir veya Excel listesi yükleyebilirsiniz.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            )
          else ...[
            Text('Öğrenciler (${students.length}) - Fotoğraf eklemek için kameraya dokunun:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final s = students[idx];
                final hasPhoto = s.photoPath != null && s.photoPath!.isNotEmpty && File(s.photoPath!).existsSync();

                return ListTile(
                  dense: true,
                  tileColor: isDark ? AppTheme.cardDark : Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: CircleAvatar(
                    backgroundImage: hasPhoto ? FileImage(File(s.photoPath!)) : null,
                    backgroundColor: AppTheme.brandLight.withOpacity(0.1),
                    child: !hasPhoto
                        ? Text(
                            s.studentNo,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('No: ${s.studentNo}'),
                  trailing: IconButton(
                    icon: Icon(
                      hasPhoto ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
                      color: hasPhoto ? Colors.green : AppTheme.brandLight,
                      size: 22,
                    ),
                    onPressed: () async {
                      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (picked != null && _selectedPhotoClassId != null) {
                        await studentsProv.updatePhoto(s.id, _selectedPhotoClassId!, picked.path);
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  // ==========================================
  // ADIM 8: TEBRİKLER & BİTİŞ EKRANI
  // ==========================================
  Widget _buildStepCompletion(bool isDark) {
    final appProv = context.watch<AppProvider>();
    final classesProv = context.watch<ClassesProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 56,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Tebrikler, Kurulum Tamamlandı!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'ÖğretmenCep artık derslerinizi, yoklamalarınızı ve öğrencilerinizi kolayca yönetmeye hazır.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Özet Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.person_outline_rounded,
                  'Öğretmen',
                  _nameCtrl.text.trim().isNotEmpty
                      ? _nameCtrl.text.trim()
                      : (appProv.settings?.teacherName.trim().isNotEmpty == true
                          ? appProv.settings!.teacherName.trim()
                          : 'Tanımlanmadı'),
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  Icons.menu_book_rounded,
                  'Girdiğiniz Dersler',
                  '${appProv.subjects.length} Ders',
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  Icons.groups_rounded,
                  'Tanımlı Sınıflar',
                  '${classesProv.classes.length} Sınıf',
                ),
                const Divider(height: 18),
                _buildSummaryRow(
                  Icons.timer_outlined,
                  'Günlük Ders Sayısı',
                  '${appProv.dailyPeriodsCount} Ders / Gün (${appProv.timetableDays} Gün)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.brandLight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
