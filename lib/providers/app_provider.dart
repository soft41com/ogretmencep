import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class AppProvider with ChangeNotifier {
  SettingsModel? _settings;
  bool _isLoading = true;

  List<String> _subjects = [];

  SettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  List<String> get subjects => _subjects;

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
  int get timetableDays => _settings?.timetableDays ?? 5;
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
    }
    _subjects = await DatabaseHelper.instance.getTeacherSubjects();

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
    if (_settings == null) return;

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
    await updateSettings(timetableDays: days);
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
}
