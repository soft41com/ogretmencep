import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../services/holiday_service.dart';
import '../services/notification_service.dart';

class AppProvider with ChangeNotifier {
  SettingsModel? _settings;
  bool _isLoading = true;

  List<String> _subjects = [];
  List<HolidayModel> _holidays = [];
  bool _isLoadingHolidays = false;

  SettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  List<String> get subjects => _subjects;
  List<HolidayModel> get holidays => _holidays;
  bool get isLoadingHolidays => _isLoadingHolidays;

  /// Belirli bir tarihteki tatili döner (örn. 2026-04-23)
  HolidayModel? getHolidayForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    for (final h in _holidays) {
      if (h.date == dateStr) {
        return h;
      }
    }
    return null;
  }

  /// Belirli bir tarihin tatil olup olmadığını döner
  bool isHoliday(DateTime date) {
    return getHolidayForDate(date) != null;
  }

  ThemeMode get themeMode {
    if (_settings == null) return ThemeMode.system;
    switch (_settings!.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Dinamik varsayılan eğitim öğretim yılı (içinde bulunulan yıl ve sonraki yıl, örn: 2026-2027)
  static String get defaultAcademicYear {
    final year = DateTime.now().year;
    return '$year-${year + 1}';
  }

  String get activeAcademicYear => _settings?.academicYear ?? defaultAcademicYear;
  int get timetableDays => 7; // Her zaman 7 gün (Tüm hafta)
  int get dailyPeriodsCount => _settings?.dailyPeriodsCount ?? 8;
  bool get isOnboardingCompleted => _settings?.isOnboardingCompleted ?? false;
  bool get lessonNotifyEnabled => _settings?.lessonNotifyEnabled ?? true;
  bool get lessonStartNotifyEnabled => _settings?.lessonStartNotifyEnabled ?? true;
  int get lessonStartMinutes => _settings?.lessonStartMinutes ?? 5;
  bool get lessonEndNotifyEnabled => _settings?.lessonEndNotifyEnabled ?? true;
  int get lessonEndMinutes => _settings?.lessonEndMinutes ?? 5;
  String get lessonNotifyType => _settings?.lessonNotifyType ?? 'both';

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final res = await db.query('settings', limit: 1);

    if (res.isNotEmpty) {
      _settings = SettingsModel.fromMap(res.first);
      if (_settings!.timetableDays != 7) {
        await updateSettings(timetableDays: 7);
      }
    }
    _subjects = await DatabaseHelper.instance.getTeacherSubjects();
    await loadHolidays(notify: false);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSettings({
    String? teacherName,
    String? schoolName,
    String? branch,
    String? academicYear,
    String? themeMode,
    int? timetableDays,
    int? dailyPeriodsCount,
    bool? isOnboardingCompleted,
    bool? lessonNotifyEnabled,
    bool? lessonStartNotifyEnabled,
    int? lessonStartMinutes,
    bool? lessonEndNotifyEnabled,
    int? lessonEndMinutes,
    String? lessonNotifyType,
  }) async {
    if (_settings == null) {
      await loadSettings();
      if (_settings == null) return;
    }

    final updated = _settings!.copyWith(
      teacherName: teacherName,
      schoolName: schoolName,
      branch: branch,
      academicYear: academicYear,
      themeMode: themeMode,
      timetableDays: timetableDays,
      dailyPeriodsCount: dailyPeriodsCount,
      isOnboardingCompleted: isOnboardingCompleted,
      lessonNotifyEnabled: lessonNotifyEnabled,
      lessonStartNotifyEnabled: lessonStartNotifyEnabled,
      lessonStartMinutes: lessonStartMinutes,
      lessonEndNotifyEnabled: lessonEndNotifyEnabled,
      lessonEndMinutes: lessonEndMinutes,
      lessonNotifyType: lessonNotifyType,
    );

    final db = await DatabaseHelper.instance.database;
    await db.update('settings', updated.toMap(), where: 'id = ?', whereArgs: [_settings!.id]);

    _settings = updated;
    notifyListeners();
  }

  Future<void> updateLessonNotificationSettings({
    required bool enabled,
    required bool startEnabled,
    required int startMinutes,
    required bool endEnabled,
    required int endMinutes,
    required String notifyType,
  }) async {
    await updateSettings(
      lessonNotifyEnabled: enabled,
      lessonStartNotifyEnabled: startEnabled,
      lessonStartMinutes: startMinutes,
      lessonEndNotifyEnabled: endEnabled,
      lessonEndMinutes: endMinutes,
      lessonNotifyType: notifyType,
    );
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await updateSettings(isOnboardingCompleted: completed);
  }

  Future<void> clearAllDataForFreshStart() async {
    await DatabaseHelper.instance.clearAllDataForFreshStart();
    await loadSettings();
  }

  Future<void> setDailyPeriodsCount(int count) async {
    await updateSettings(dailyPeriodsCount: count);
  }

  Future<void> setTimetableDays(int days) async {
    await updateSettings(timetableDays: 7);
  }

  Future<void> setTheme(String mode) async {
    await updateSettings(themeMode: mode);
  }

  Future<void> addSubject(String name) async {
    final success = await DatabaseHelper.instance.addTeacherSubject(name);
    if (success) {
      _subjects = await DatabaseHelper.instance.getTeacherSubjects();
      notifyListeners();
    }
  }

  Future<void> removeSubject(String name) async {
    final success = await DatabaseHelper.instance.deleteTeacherSubject(name);
    if (success) {
      _subjects = await DatabaseHelper.instance.getTeacherSubjects();
      notifyListeners();
    }
  }

  // ===================== TATİL GÜNLERİ (HOLIDAYS) =====================

  /// Kayıtlı tatilleri veritabanından yükler
  Future<void> loadHolidays({bool notify = true}) async {
    _holidays = await DatabaseHelper.instance.getHolidays();
    if (notify) notifyListeners();
  }

  /// Uzak sunucudan (örn: https://dersprogram.okulsinav.com/json/2016tatil.json) tatil günlerini çeker ve kaydeder
  Future<int> fetchAndSaveHolidays({int? year, String? customUrl}) async {
    _isLoadingHolidays = true;
    notifyListeners();

    try {
      final targetYear = year ?? DateTime.now().year;
      final fetched = await HolidayService.instance.fetchHolidaysFromRemote(
        year: targetYear,
        customUrl: customUrl,
      );

      if (fetched.isNotEmpty) {
        // Önce o yılın tatillerini temizle, ardından yenileri ekle
        await DatabaseHelper.instance.clearHolidaysForYear(targetYear);
        await DatabaseHelper.instance.insertHolidays(fetched);
        await loadHolidays(notify: false);

        // Eğer bugün tatil ise anlık bildirimleri iptal et
        final now = DateTime.now();
        if (isHoliday(now)) {
          await NotificationService.instance.cancelLessonNotificationsForDate(now);
        }
      }

      _isLoadingHolidays = false;
      notifyListeners();
      return fetched.length;
    } catch (e) {
      _isLoadingHolidays = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Manuel yeni tatil ekleme
  Future<void> addHoliday(HolidayModel holiday) async {
    await DatabaseHelper.instance.insertOrUpdateHoliday(holiday);
    await loadHolidays();
  }

  /// Tatil silme
  Future<void> deleteHoliday(int id) async {
    await DatabaseHelper.instance.deleteHoliday(id);
    await loadHolidays();
  }
}
