import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/models.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _channelBothId = 'lesson_channel_both';
  static const String _channelSoundId = 'lesson_channel_sound';
  static const String _channelVibrateId = 'lesson_channel_vibrate';
  static const String _channelNoteId = 'note_reminder_channel';

  // ID aralıkları:
  // Başlama bildirimleri: 100000 + (weekday * 1000) + periodId
  // Bitiş bildirimleri: 200000 + (weekday * 1000) + periodId
  // Not bildirimleri: 300000 + noteId
  // Test bildirimi: 999999

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      bool setTz = false;
      try {
        final name = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(name));
        setTz = true;
      } catch (_) {}

      if (!setTz) {
        try {
          tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
          setTz = true;
        } catch (_) {}
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Bildirime tıklandığında yapılacak işlem
        },
      );

      await _createNotificationChannels();
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // 1. Ses ve Titreşim Kanalı
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelBothId,
            'Ders Bildirimleri (Ses ve Titreşim)',
            description: 'Ders başlama ve bitişleri için sesli ve titreşimli uyarılar',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        // 2. Yalnızca Ses Kanalı
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelSoundId,
            'Ders Bildirimleri (Yalnızca Ses)',
            description: 'Ders başlama ve bitişleri için yalnızca sesli uyarılar',
            importance: Importance.high,
            playSound: true,
            enableVibration: false,
          ),
        );

        // 3. Yalnızca Titreşim Kanalı
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelVibrateId,
            'Ders Bildirimleri (Yalnızca Titreşim)',
            description: 'Ders başlama ve bitişleri için yalnızca titreşimli uyarılar',
            importance: Importance.high,
            playSound: false,
            enableVibration: true,
          ),
        );

        // 4. Not Hatırlatıcı Kanalı
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelNoteId,
            'Not Hatırlatıcıları',
            description: 'Önemli notlar ve görevler için hatırlatıcı bildirimler',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    return true;
  }

  /// Android 12+ (API 31+) cihazlarda tam zamanlı alarm izninin verilip verilmediğini denetler
  Future<bool> canScheduleExactNotifications() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return (await androidPlugin.canScheduleExactNotifications()) ?? false;
      }
    }
    return true;
  }

  /// Android sistemindeki "Alarmlar ve Hatırlatıcılar" izin ekranını açar
  Future<bool> requestExactAlarmsPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestExactAlarmsPermission();
        return granted ?? false;
      }
    }
    return true;
  }

  NotificationDetails _getNotificationDetails(String notifyType) {
    String channelId;
    String channelName;
    bool playSound = true;
    bool enableVibration = true;

    switch (notifyType) {
      case 'sound':
        channelId = _channelSoundId;
        channelName = 'Ders Bildirimleri (Yalnızca Ses)';
        enableVibration = false;
        break;
      case 'vibrate':
        channelId = _channelVibrateId;
        channelName = 'Ders Bildirimleri (Yalnızca Titreşim)';
        playSound = false;
        break;
      case 'both':
      default:
        channelId = _channelBothId;
        channelName = 'Ders Bildirimleri (Ses ve Titreşim)';
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Ders hatırlatıcı bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration ? Int64List.fromList([0, 500, 200, 500]) : null,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      autoCancel: true,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: playSound,
      presentBadge: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Tüm ders bildirimlerini iptal eder
  Future<void> cancelAllLessonNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Bildirim iptal hatası: $e');
    }
  }

  /// Belirli bir haftanın gününe ait ders bildirimlerini iptal eder (örn. tatil olduğunda)
  Future<void> cancelLessonNotificationsForWeekday(int weekday) async {
    try {
      for (int p = 1; p <= 35; p++) {
        await _notificationsPlugin.cancel(100000 + (weekday * 1000) + p);
        await _notificationsPlugin.cancel(200000 + (weekday * 1000) + p);
      }
    } catch (e) {
      debugPrint('Tatil günü bildirim iptal hatası: $e');
    }
  }

  /// Belirli bir tarihteki ders bildirimlerini iptal eder
  Future<void> cancelLessonNotificationsForDate(DateTime date) async {
    await cancelLessonNotificationsForWeekday(date.weekday);
  }

  /// Öğretmenin ders programına göre bildirimleri zamanlar
  Future<int> scheduleLessonNotifications({
    required List<TimetableEntryModel> timetable,
    required SettingsModel settings,
    List<HolidayModel>? holidays,
  }) async {
    await initialize();
    await requestPermissions();

    // Önce mevcut tüm bildirimleri temizle
    await cancelAllLessonNotifications();

    if (!settings.lessonNotifyEnabled) {
      return 0;
    }

    final bool canExact = await canScheduleExactNotifications();
    final AndroidScheduleMode preferredMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    int scheduledCount = 0;
    final notifyType = settings.lessonNotifyType;
    final details = _getNotificationDetails(notifyType);

    // Tatil tarihleri kümesi (yyyy-MM-dd)
    final holidayDates = holidays?.map((h) => h.date).toSet() ?? <String>{};

    for (final entry in timetable) {
      // Hafta içi / hafta sonu kontrolü (1=Pazartesi ... 7=Pazar)
      final weekday = entry.weekday;
      if (weekday < 1 || weekday > 7) continue;

      // 1. Ders Başlama Bildirimi
      if (settings.lessonStartNotifyEnabled && entry.startTime != null && entry.startTime!.isNotEmpty) {
        try {
          final parts = entry.startTime!.split(':');
          if (parts.length >= 2) {
            final startHour = int.parse(parts[0]);
            final startMin = int.parse(parts[1]);
            final startTotalMin = startHour * 60 + startMin;
            final notifyTotalMin = startTotalMin - settings.lessonStartMinutes;

            int notifyDay = weekday;
            int finalNotifyMin = notifyTotalMin;
            if (finalNotifyMin < 0) {
              finalNotifyMin += 24 * 60;
              notifyDay = (weekday == 1) ? 7 : weekday - 1;
            }

            final notifyHour = finalNotifyMin ~/ 60;
            final notifyMinute = finalNotifyMin % 60;

            final scheduledDate = _nextInstanceOfWeekdayAndTime(notifyDay, notifyHour, notifyMinute);
            final dateStr = '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
            if (holidayDates.contains(dateStr)) {
              // Tatil gününde ders bildirimi yapılmaz!
              continue;
            }
            final notificationId = 100000 + (weekday * 1000) + entry.periodId;

            final className = (entry.className != null && entry.className!.isNotEmpty) ? entry.className! : 'Ders';
            final subject = entry.subject.isNotEmpty ? entry.subject : 'Ders';
            final title = 'Ders Başlıyor 🔔 ($className)';
            final body = settings.lessonStartMinutes > 0
                ? '$className $subject dersinin başlamasına ${settings.lessonStartMinutes} dakika kaldı.'
                : '$className $subject dersi şimdi başlıyor!';

            try {
              await _notificationsPlugin.zonedSchedule(
                notificationId,
                title,
                body,
                scheduledDate,
                details,
                androidScheduleMode: preferredMode,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              );
              scheduledCount++;
            } catch (e) {
              debugPrint('Exact alarm error ($e), retrying with inexactAllowWhileIdle...');
              try {
                await _notificationsPlugin.zonedSchedule(
                  notificationId,
                  title,
                  body,
                  scheduledDate,
                  details,
                  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                );
                scheduledCount++;
              } catch (e2) {
                debugPrint('Ders başlama bildirimi zamanlama hatası: $e2');
              }
            }
          }
        } catch (e) {
          debugPrint('Ders başlama hesaplama hatası: $e');
        }
      }

      // 2. Ders Bitiş Bildirimi
      if (settings.lessonEndNotifyEnabled && entry.endTime != null && entry.endTime!.isNotEmpty) {
        try {
          final parts = entry.endTime!.split(':');
          if (parts.length >= 2) {
            final endHour = int.parse(parts[0]);
            final endMin = int.parse(parts[1]);
            final endTotalMin = endHour * 60 + endMin;
            final notifyTotalMin = endTotalMin - settings.lessonEndMinutes;

            int notifyDay = weekday;
            int finalNotifyMin = notifyTotalMin;
            if (finalNotifyMin < 0) {
              finalNotifyMin += 24 * 60;
              notifyDay = (weekday == 1) ? 7 : weekday - 1;
            }

            final notifyHour = finalNotifyMin ~/ 60;
            final notifyMinute = finalNotifyMin % 60;

            final scheduledDate = _nextInstanceOfWeekdayAndTime(notifyDay, notifyHour, notifyMinute);
            final dateStr = '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
            if (holidayDates.contains(dateStr)) {
              // Tatil gününde ders bitiş bildirimi yapılmaz!
              continue;
            }
            final notificationId = 200000 + (weekday * 1000) + entry.periodId;

            final className = (entry.className != null && entry.className!.isNotEmpty) ? entry.className! : 'Ders';
            final subject = entry.subject.isNotEmpty ? entry.subject : 'Ders';
            final title = 'Ders Bitiyor ⏳ ($className)';
            final body = settings.lessonEndMinutes > 0
                ? '$className $subject dersinin bitmesine ${settings.lessonEndMinutes} dakika kaldı.'
                : '$className $subject dersi şimdi bitti!';

            try {
              await _notificationsPlugin.zonedSchedule(
                notificationId,
                title,
                body,
                scheduledDate,
                details,
                androidScheduleMode: preferredMode,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              );
              scheduledCount++;
            } catch (e) {
              debugPrint('Exact alarm error ($e), retrying with inexactAllowWhileIdle...');
              try {
                await _notificationsPlugin.zonedSchedule(
                  notificationId,
                  title,
                  body,
                  scheduledDate,
                  details,
                  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                );
                scheduledCount++;
              } catch (e2) {
                debugPrint('Ders bitiş bildirimi zamanlama hatası: $e2');
              }
            }
          }
        } catch (e) {
          debugPrint('Ders bitiş hesaplama hatası: $e');
        }
      }
    }

    return scheduledCount;
  }

  /// Bir sonraki belirtilen gün ve saatteki TZDateTime nesnesini döndürür
  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Ayarları test etmek için anlık bildirim gösterir
  Future<void> showTestNotification({
    required String notifyType,
    required int minutes,
    required bool isStart,
    String? className,
    String? subject,
  }) async {
    await initialize();
    await requestPermissions();

    final details = _getNotificationDetails(notifyType);
    final cls = className ?? '9-A';
    final sbj = subject ?? 'Matematik';

    final title = isStart ? 'Ders Başlıyor 🔔 ($cls)' : 'Ders Bitiyor ⏳ ($cls)';
    final body = isStart
        ? '$cls $sbj dersinin başlamasına $minutes dakika kaldı. (Test Bildirimi)'
        : '$cls $sbj dersinin bitmesine $minutes dakika kaldı. (Test Bildirimi)';

    await _notificationsPlugin.show(
      999999,
      title,
      body,
      details,
    );
  }

  /// Planlı bildirimi test etmek için belirtilen saniye sonra zamanlı bildirim tetikler
  Future<void> showScheduledTestNotification({
    required String notifyType,
    int seconds = 10,
    String? className,
    String? subject,
  }) async {
    await initialize();
    await requestPermissions();

    final details = _getNotificationDetails(notifyType);
    final cls = className ?? '9-A';
    final sbj = subject ?? 'Matematik';

    final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    final bool canExact = await canScheduleExactNotifications();

    try {
      await _notificationsPlugin.zonedSchedule(
        999998,
        'Planlı Ders Uyarısı Testi 🔔 ($cls)',
        '$cls $sbj ders uyarısı ($seconds saniye sonra). Zamanlanmış bildirim başarıyla çalışıyor!',
        scheduledDate,
        details,
        androidScheduleMode: canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      await _notificationsPlugin.zonedSchedule(
        999998,
        'Planlı Ders Uyarısı Testi 🔔 ($cls)',
        '$cls $sbj ders uyarısı ($seconds saniye sonra). Zamanlanmış bildirim başarıyla çalışıyor!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  NotificationDetails _getNoteNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelNoteId,
      'Not Hatırlatıcıları',
      channelDescription: 'Önemli notlar ve görevler için hatırlatıcı bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      autoCancel: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Not için belirlenen saatte bildirim planlar
  Future<void> scheduleNoteNotification(DailyNoteModel note) async {
    if (note.id == null || !note.isReminderActive || note.reminderTime == null || note.reminderTime!.isEmpty) {
      return;
    }

    await initialize();
    await requestPermissions();

    final notificationId = 300000 + note.id!;

    // Varsa önceki bildirimi iptal et
    try {
      await _notificationsPlugin.cancel(notificationId);
    } catch (_) {}

    final parts = note.reminderTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final details = _getNoteNotificationDetails();
    final title = (note.title != null && note.title!.trim().isNotEmpty)
        ? 'Not Hatırlatıcı: ${note.title!.trim()}'
        : 'Not Hatırlatıcı 📌';
    final body = note.content.trim();

    final now = tz.TZDateTime.now(tz.local);
    final bool canExact = await canScheduleExactNotifications();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    if (note.isRecurring) {
      // Haftalık tekrarlanan gün bildirimi
      final targetWeekday = note.weekday ?? 1;
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('Haftalık not bildirimi planlama hatası: $e');
      }
    } else {
      // Belirli bir tarih için tek seferlik bildirim
      if (note.date == null || note.date!.isEmpty) return;
      try {
        final dateParts = note.date!.split('-');
        if (dateParts.length != 3) return;
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);

        final scheduledDate = tz.TZDateTime(
          tz.local,
          year,
          month,
          day,
          hour,
          minute,
        );

        // Geçmişte kalmış bir an ise planlama
        if (scheduledDate.isBefore(now)) {
          return;
        }

        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
        );
      } catch (e) {
        debugPrint('Tarihli not bildirimi planlama hatası: $e');
      }
    }
  }

  /// Not bildirimini iptal eder
  Future<void> cancelNoteNotification(int noteId) async {
    try {
      await _notificationsPlugin.cancel(300000 + noteId);
    } catch (e) {
      debugPrint('Not bildirim iptal hatası: $e');
    }
  }
}
