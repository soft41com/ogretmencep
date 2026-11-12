import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'class_detail_screen.dart';
import 'plans_screen.dart';
import 'timetable_matrix_screen.dart';

enum TodayLiveState {
  noClassesToday,
  beforeFirstClass,
  inProgress,
  recess,
  justFinished,
  allFinishedHidden,
  schoolActiveTeacherFree,
}

class TodayLiveInfo {
  final TodayLiveState state;
  final TimetableEntryModel? currentClass;
  final TimetableEntryModel? nextClass;
  final BellPeriodModel? activeSchoolPeriod;
  final int elapsedMinutes;
  final int remainingMinutes;
  final int totalMinutes;
  final double progress;
  final int minutesUntilNext;
  final int minutesSinceLastEnd;

  TodayLiveInfo({
    required this.state,
    this.currentClass,
    this.nextClass,
    this.activeSchoolPeriod,
    this.elapsedMinutes = 0,
    this.remainingMinutes = 0,
    this.totalMinutes = 0,
    this.progress = 0.0,
    this.minutesUntilNext = 0,
    this.minutesSinceLastEnd = 0,
  });

  bool get shouldShowBox => state == TodayLiveState.inProgress;
}

enum LiveIntervalType {
  beforeFirstLesson,
  recess,
  freePeriod,
}

class InClassProgressData {
  final int elapsedMinutes;
  final int remainingMinutes;
  final int totalMinutes;
  final double progress;

  InClassProgressData({
    required this.elapsedMinutes,
    required this.remainingMinutes,
    required this.totalMinutes,
    required this.progress,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedWeekday = DateTime.now().weekday <= 5 ? DateTime.now().weekday : 1;
  Timer? _liveTimer;

  final List<String> _days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  @override
  void initState() {
    super.initState();
    // 5 saniyede bir saati ve ilerleme çubuğunu otomatik canlı güncelle
    _liveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.brandLight;
    }
  }

  String _formatTimeRemaining(int totalMinutes) {
    if (totalMinutes <= 0) return 'Başlamak üzere';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '$hours saat $minutes dakika';
    } else if (hours > 0) {
      return '$hours saat';
    } else {
      return '$minutes dakika';
    }
  }

  int? _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    try {
      final parts = timeStr.trim().split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return h * 60 + m;
    } catch (_) {
      return null;
    }
  }

  TodayLiveInfo _computeTodayLiveInfo(
    List<TimetableEntryModel> todayEntries,
    List<BellPeriodModel> bellPeriods,
    int timetableDays,
  ) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Hafta sonu / ders dışı gün kontrolü
    if (now.weekday > timetableDays) {
      return TodayLiveInfo(state: TodayLiveState.noClassesToday);
    }

    // 1. Okulun geçerli zil periyotlarını başlangıç saatine göre sırala
    final validPeriods = bellPeriods.where((p) => p.startTime.isNotEmpty && p.endTime.isNotEmpty).toList();
    validPeriods.sort((a, b) {
      final aParts = a.startTime.split(':').map(int.parse).toList();
      final bParts = b.startTime.split(':').map(int.parse).toList();
      return (aParts[0] * 60 + aParts[1]).compareTo(bParts[0] * 60 + bParts[1]);
    });

    // 2. Okulda şu anda aktif bir ders periyodu var mı?
    BellPeriodModel? activeSchoolPeriod;
    int schoolElapsed = 0;
    int schoolRemaining = 0;
    int schoolTotal = 0;
    double schoolProgress = 0.0;

    for (final bp in validPeriods) {
      final sParts = bp.startTime.split(':').map(int.parse).toList();
      final eParts = bp.endTime.split(':').map(int.parse).toList();
      final sM = sParts[0] * 60 + sParts[1];
      final eM = eParts[0] * 60 + eParts[1];

      if (currentMinutes >= sM && currentMinutes < eM) {
        activeSchoolPeriod = bp;
        schoolTotal = eM - sM;
        schoolElapsed = currentMinutes - sM;
        schoolRemaining = eM - currentMinutes;
        schoolProgress = schoolTotal > 0 ? (schoolElapsed / schoolTotal).clamp(0.0, 1.0) : 0.0;
        break;
      }
    }

    // Yalnızca başlangıç ve bitiş saati tanımlı olan öğretmenin derslerini al
    final validEntries = todayEntries.where((e) => e.startTime != null && e.endTime != null).toList();
    validEntries.sort((a, b) {
      final aParts = a.startTime!.split(':').map(int.parse).toList();
      final bParts = b.startTime!.split(':').map(int.parse).toList();
      return (aParts[0] * 60 + aParts[1]).compareTo(bParts[0] * 60 + bParts[1]);
    });

    // 3. ŞU AN ÖĞRETMENİN DERSİ VAR MI?
    for (int i = 0; i < validEntries.length; i++) {
      final entry = validEntries[i];
      final startParts = entry.startTime!.split(':').map(int.parse).toList();
      final endParts = entry.endTime!.split(':').map(int.parse).toList();
      final startM = startParts[0] * 60 + startParts[1];
      final endM = endParts[0] * 60 + endParts[1];

      if (currentMinutes >= startM && currentMinutes < endM) {
        final total = endM - startM;
        final elapsed = currentMinutes - startM;
        final remaining = endM - currentMinutes;
        final progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
        final nextClass = (i + 1 < validEntries.length) ? validEntries[i + 1] : null;

        return TodayLiveInfo(
          state: TodayLiveState.inProgress,
          currentClass: entry,
          nextClass: nextClass,
          elapsedMinutes: elapsed,
          remainingMinutes: remaining,
          totalMinutes: total,
          progress: progress,
        );
      }
    }

    // 4. ÖĞRETMENİN ŞU AN DERSİ YOK AMA OKULDA AKTİF DERS DEVAM EDİYOR! (İstenen Özellik)
    if (activeSchoolPeriod != null) {
      // Öğretmenin gün içindeki sıradaki ilk dersini bul
      TimetableEntryModel? nextTeacherClass;
      for (final entry in validEntries) {
        final startParts = entry.startTime!.split(':').map(int.parse).toList();
        final startM = startParts[0] * 60 + startParts[1];
        if (startM > currentMinutes) {
          nextTeacherClass = entry;
          break;
        }
      }

      return TodayLiveInfo(
        state: TodayLiveState.schoolActiveTeacherFree,
        activeSchoolPeriod: activeSchoolPeriod,
        nextClass: nextTeacherClass,
        elapsedMinutes: schoolElapsed,
        remainingMinutes: schoolRemaining,
        totalMinutes: schoolTotal,
        progress: schoolProgress,
      );
    }

    if (validEntries.isEmpty) {
      return TodayLiveInfo(state: TodayLiveState.noClassesToday);
    }

    // 5. HENÜZ BAŞLAMAMIŞ SIRADAKİ DERS VAR MI?
    TimetableEntryModel? nextEntry;
    TimetableEntryModel? prevEntry;

    for (int i = 0; i < validEntries.length; i++) {
      final entry = validEntries[i];
      final startParts = entry.startTime!.split(':').map(int.parse).toList();
      final startM = startParts[0] * 60 + startParts[1];

      if (startM > currentMinutes) {
        nextEntry = entry;
        if (i > 0) prevEntry = validEntries[i - 1];
        break;
      }
    }

    if (nextEntry != null) {
      final startParts = nextEntry.startTime!.split(':').map(int.parse).toList();
      final startM = startParts[0] * 60 + startParts[1];
      final diff = startM - currentMinutes;

      if (prevEntry != null) {
        // İki ders arası teneffüsteyiz
        return TodayLiveInfo(
          state: TodayLiveState.recess,
          currentClass: prevEntry,
          nextClass: nextEntry,
          minutesUntilNext: diff,
        );
      } else {
        // Günün ilk dersinden önceyiz
        return TodayLiveInfo(
          state: TodayLiveState.beforeFirstClass,
          nextClass: nextEntry,
          minutesUntilNext: diff,
        );
      }
    }

    // 6. GÜNÜN TÜM DERSLERİ BİTTİ Mİ?
    final lastEntry = validEntries.last;
    final endParts = lastEntry.endTime!.split(':').map(int.parse).toList();
    final lastEndM = endParts[0] * 60 + endParts[1];
    final sinceEnd = currentMinutes - lastEndM;

    // Son dersten sonra 10 dakika boyunca kutu açık kalır, 10 dk sonra kaldırılır
    if (sinceEnd >= 0 && sinceEnd <= 10) {
      return TodayLiveInfo(
        state: TodayLiveState.justFinished,
        currentClass: lastEntry,
        minutesSinceLastEnd: sinceEnd,
      );
    }

    return TodayLiveInfo(
      state: TodayLiveState.allFinishedHidden,
      currentClass: lastEntry,
      minutesSinceLastEnd: sinceEnd,
    );
  }

  Widget _buildLiveHeroCard(
    BuildContext context,
    TodayLiveInfo liveInfo,
    ClassesProvider classesProv,
    bool isDark,
  ) {
    final entry = liveInfo.currentClass ?? liveInfo.nextClass;
    if (entry == null) return const SizedBox.shrink();

    // Eşleşen sınıf modelini bul
    final matchedClass = classesProv.classes.firstWhere(
      (c) => c.id == entry.classId,
      orElse: () => classesProv.classes.isNotEmpty
          ? classesProv.classes.first
          : ClassModel(
              id: entry.classId,
              name: entry.className ?? 'Sınıf',
              gradeLevel: '9',
              academicYear: '',
              color: '#17433B',
              studentCount: 0,
            ),
    );

    // Canlı durum renkleri ve başlıkları
    Color badgeBg;
    Color badgeTextColor;
    String badgeTitle;
    IconData badgeIcon;

    switch (liveInfo.state) {
      case TodayLiveState.inProgress:
        badgeBg = AppTheme.posLight;
        badgeTextColor = Colors.white;
        badgeTitle = entry.periodLabel ?? '1. Ders';
        badgeIcon = Icons.sensors_rounded;
        break;
      case TodayLiveState.beforeFirstClass:
        badgeBg = Colors.amber.shade700;
        badgeTextColor = Colors.white;
        badgeTitle = entry.periodLabel ?? '1. Ders';
        badgeIcon = Icons.alarm_rounded;
        break;
      case TodayLiveState.recess:
        badgeBg = Colors.orange.shade700;
        badgeTextColor = Colors.white;
        badgeTitle = 'Teneffüs (${liveInfo.nextClass?.periodLabel ?? "Sıradaki"})';
        badgeIcon = Icons.coffee_rounded;
        break;
      case TodayLiveState.justFinished:
        badgeBg = Colors.teal.shade600;
        badgeTextColor = Colors.white;
        badgeTitle = 'Dersler Bitti';
        badgeIcon = Icons.task_alt_rounded;
        break;
      default:
        badgeBg = AppTheme.accent;
        badgeTextColor = const Color(0xFF14231F);
        badgeTitle = 'Ders Programı';
        badgeIcon = Icons.school_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B3126), const Color(0xFF0F1E17)]
              : [const Color(0xFF17433B), const Color(0xFF0D2924)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: liveInfo.state == TodayLiveState.inProgress
              ? AppTheme.accent.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (liveInfo.state == TodayLiveState.inProgress
                    ? AppTheme.accent
                    : AppTheme.brandLight)
                .withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Üst Rozet Satırı (Durum Rozeti ve Saat Aralığı)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeTextColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          badgeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entry.startTime ?? ""} - ${entry.endTime ?? ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Ana Ders Başlığı ve Detayları
          if (liveInfo.state == TodayLiveState.justFinished) ...[
            const Text(
              'Günün Programı Tamamlandı',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Son dersiniz (${entry.className} • ${entry.subject}) bitti. Bugünkü tüm derslerinizi tamamladınız.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.className ?? '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (matchedClass.studentCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '👤 ${matchedClass.studentCount} Öğrenci',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.subject} • ${entry.classroom ?? "Derslik belirtilmedi"}',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 16),

          // 3. CANLI DURUM ALANI (BAR veya GERİ SAYIM)
          if (liveInfo.state == TodayLiveState.inProgress) ...[
            // Canlı Ders Barı ve Dakika İstatistikleri
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timelapse_rounded, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Geçen: ${liveInfo.elapsedMinutes} dk',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded, size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Kalan: ${liveInfo.remainingMinutes} dk',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // İlerleme Çubuğu
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: LinearProgressIndicator(
                  value: liveInfo.progress,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '%${(liveInfo.progress * 100).toInt()} tamamlandı',
                  style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600),
                ),
                if (liveInfo.nextClass != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sonraki: ${liveInfo.nextClass!.className} (${liveInfo.nextClass!.startTime})',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (liveInfo.state == TodayLiveState.beforeFirstClass || liveInfo.state == TodayLiveState.recess) ...[
            // Başlamamış Ders İçin Canlı Geri Sayım Kutusu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, size: 20, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dersin başlamasına ${_formatTimeRemaining(liveInfo.minutesUntilNext)} kaldı',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          liveInfo.state == TodayLiveState.recess
                              ? 'Teneffüsün tadını çıkarın. Ders saati: ${entry.startTime}'
                              : 'Bugünün ilk dersi saat ${entry.startTime}\'de başlıyor.',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (liveInfo.state == TodayLiveState.justFinished) ...[
            // Son Ders Bittiğinde 10 Dakika Gösterim Uyarısı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration_rounded, size: 24, color: Colors.amberAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İyi Dinlenmeler Öğretmenim!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bu bilgilendirme kutusu ${10 - liveInfo.minutesSinceLastEnd} dakika sonra otomatik kapanacaktır.',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 4. HIZLI EYLEMLER BUTONLARI
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.brandLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(40),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceScreen(initialClass: matchedClass),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check_rounded, size: 16),
                  label: const Text('Yoklama Al', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassDetailScreen(classModel: matchedClass),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_rounded, size: 16),
                  label: const Text('Sınıf Detayı', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlansScreen(initialClassId: matchedClass.id),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIntervalBar({
    required BuildContext context,
    required LiveIntervalType intervalType,
    required int remainingMinutes,
    required double progress,
    required bool isDark,
  }) {
    Color primaryColor;
    Color bgColor;
    Color borderColor;
    IconData headerIcon;

    switch (intervalType) {
      case LiveIntervalType.beforeFirstLesson:
        primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        bgColor = isDark ? const Color(0xFF0C2438) : const Color(0xFFF0F9FF);
        borderColor = primaryColor.withOpacity(isDark ? 0.35 : 0.25);
        headerIcon = Icons.alarm_rounded;
        break;
      case LiveIntervalType.recess:
        primaryColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        bgColor = isDark ? const Color(0xFF2B2011) : const Color(0xFFFFFBEB);
        borderColor = primaryColor.withOpacity(isDark ? 0.35 : 0.25);
        headerIcon = Icons.coffee_rounded;
        break;
      case LiveIntervalType.freePeriod:
        primaryColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        bgColor = isDark ? const Color(0xFF0F261E) : const Color(0xFFECFDF5);
        borderColor = primaryColor.withOpacity(isDark ? 0.35 : 0.25);
        headerIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(headerIcon, size: 14, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$remainingMinutes dk kaldı',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard({
    required BuildContext context,
    required TimetableEntryModel entry,
    required ClassesProvider classesProv,
    required bool isCurrentActive,
    required InClassProgressData? inClassProgress,
    required bool isDark,
  }) {
    final classColor = entry.classColor != null ? _parseHex(entry.classColor!) : AppTheme.brandLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentActive ? 3 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCurrentActive
              ? AppTheme.posLight
              : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
          width: isCurrentActive ? 2 : 1,
        ),
      ),
      color: isCurrentActive
          ? (isDark
              ? AppTheme.posLight.withOpacity(0.14)
              : const Color(0xFFE8F5E9))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (classesProv.classes.isEmpty) return;
          final matchedClass = classesProv.classes.firstWhere(
            (c) => c.id == entry.classId,
            orElse: () => classesProv.classes.first,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassDetailScreen(classModel: matchedClass),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCurrentActive
                          ? AppTheme.posLight
                          : classColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isCurrentActive
                          ? [
                              BoxShadow(
                                color: AppTheme.posLight.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.periodLabel?.split(".").first ?? "D",
                      style: TextStyle(
                        color: isCurrentActive ? Colors.white : classColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${entry.className} • ${entry.subject}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.posLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sensors_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'ŞU AN DERSTESİNİZ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${entry.periodLabel ?? ""} (${entry.startTime ?? ""} - ${entry.endTime ?? ""})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentActive
                                ? (isDark ? AppTheme.posLight : const Color(0xFF1B5E20))
                                : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isCurrentActive ? AppTheme.posLight : null,
                  ),
                ],
              ),
              if (isCurrentActive && inClassProgress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: inClassProgress.progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.posLight),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${inClassProgress.elapsedMinutes} dk geçti (%${(inClassProgress.progress * 100).toInt()})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                      ),
                    ),
                    Text(
                      'Dersin bitimine ${inClassProgress.remainingMinutes} dk kaldı',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.posLight : const Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayFinishedNotice(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, size: 20, color: AppTheme.posLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Günün tüm dersleri tamamlandı. İyi dinlenmeler! 🎉',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.inkDark : AppTheme.inkLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScheduleListWithLiveBars({
    required BuildContext context,
    required List<TimetableEntryModel> dayEntries,
    required List<BellPeriodModel> bellPeriods,
    required ClassesProvider classesProv,
    required bool isDark,
  }) {
    // Dersleri başlangıç saatine göre sırala
    final sortedEntries = List<TimetableEntryModel>.from(dayEntries);
    sortedEntries.sort((a, b) {
      final aM = _parseTimeToMinutes(a.startTime) ?? 0;
      final bM = _parseTimeToMinutes(b.startTime) ?? 0;
      return aM.compareTo(bM);
    });

    final now = DateTime.now();
    final isToday = _selectedWeekday == now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;

    if (!isToday || sortedEntries.isEmpty) {
      return sortedEntries
          .map((entry) => _buildLessonCard(
                context: context,
                entry: entry,
                classesProv: classesProv,
                isCurrentActive: false,
                inClassProgress: null,
                isDark: isDark,
              ))
          .toList();
    }

    // Okulun ilk zil başlangıç saatini bul (örn. 09:00)
    int? schoolStartM;
    for (final bp in bellPeriods) {
      final m = _parseTimeToMinutes(bp.startTime);
      if (m != null) {
        if (schoolStartM == null || m < schoolStartM) {
          schoolStartM = m;
        }
      }
    }

    final List<Widget> widgets = [];
    final firstStartM = _parseTimeToMinutes(sortedEntries.first.startTime);

    // 1. DURUM: Günün ilk dersinden önce miyiz?
    // Örnek: Okul başlangıcı 09:00, ilk ders 10:15, aktif saat 09:30 -> 75 dk'lık bar, 45 dk kaldı.
    if (firstStartM != null && currentMinutes < firstStartM) {
      int gapStartM;
      if (schoolStartM != null && schoolStartM < firstStartM) {
        gapStartM = currentMinutes < schoolStartM ? currentMinutes : schoolStartM;
      } else {
        final windowStart = firstStartM - 60;
        gapStartM = (windowStart > 0 && currentMinutes >= windowStart)
            ? windowStart
            : currentMinutes;
      }

      final totalM = (firstStartM - gapStartM).clamp(1, 24 * 60);
      final elapsedM = (currentMinutes - gapStartM).clamp(0, totalM);
      final remainingM = (firstStartM - currentMinutes).clamp(0, totalM);
      final progress = (elapsedM / totalM).clamp(0.0, 1.0);

      widgets.add(
        _buildLiveIntervalBar(
          context: context,
          intervalType: LiveIntervalType.beforeFirstLesson,
          remainingMinutes: remainingM,
          progress: progress,
          isDark: isDark,
        ),
      );
    }

    // 2. DERS KARTLARI VE ARALAR (Teneffüs / Boş Ders)
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final startM = _parseTimeToMinutes(entry.startTime);
      final endM = _parseTimeToMinutes(entry.endTime);

      bool isCurrentActive = false;
      InClassProgressData? inClassProgress;

      if (startM != null && endM != null && currentMinutes >= startM && currentMinutes < endM) {
        isCurrentActive = true;
        final classTotal = (endM - startM).clamp(1, 180);
        final classElapsed = (currentMinutes - startM).clamp(0, classTotal);
        final classRemaining = (endM - currentMinutes).clamp(0, classTotal);
        final classProg = (classElapsed / classTotal).clamp(0.0, 1.0);

        inClassProgress = InClassProgressData(
          elapsedMinutes: classElapsed,
          remainingMinutes: classRemaining,
          totalMinutes: classTotal,
          progress: classProg,
        );
      }

      // Ders Kartını Ekle
      widgets.add(
        _buildLessonCard(
          context: context,
          entry: entry,
          classesProv: classesProv,
          isCurrentActive: isCurrentActive,
          inClassProgress: inClassProgress,
          isDark: isDark,
        ),
      );

      // İki ders arası kontrolü (Teneffüs veya Boş Ders)
      if (i < sortedEntries.length - 1) {
        final nextEntry = sortedEntries[i + 1];
        final currentEndM = endM;
        final nextStartM = _parseTimeToMinutes(nextEntry.startTime);

        if (currentEndM != null && nextStartM != null && nextStartM > currentEndM) {
          // Eğer şu anki saat bu iki dersin arasındaysa
          if (currentMinutes >= currentEndM && currentMinutes < nextStartM) {
            final totalGap = nextStartM - currentEndM;
            final elapsedGap = (currentMinutes - currentEndM).clamp(0, totalGap);
            final remainingGap = (nextStartM - currentMinutes).clamp(0, totalGap);
            final progressGap = totalGap > 0 ? (elapsedGap / totalGap).clamp(0.0, 1.0) : 0.0;
            final isRecess = totalGap <= 25;

            widgets.add(
              _buildLiveIntervalBar(
                context: context,
                intervalType: isRecess ? LiveIntervalType.recess : LiveIntervalType.freePeriod,
                remainingMinutes: remainingGap,
                progress: progressGap,
                isDark: isDark,
              ),
            );
          }
        }
      }
    }

    // 3. GÜN BİTİMİ KONTROLÜ
    final lastEndM = _parseTimeToMinutes(sortedEntries.last.endTime);
    if (lastEndM != null && currentMinutes >= lastEndM) {
      widgets.add(
        _buildDayFinishedNotice(context, isDark),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final scheduleProv = context.watch<ScheduleProvider>();
    final classesProv = context.watch<ClassesProvider>();
    final notesProv = context.watch<NotesProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final teacherName = appProv.settings?.teacherName ?? 'Öğretmenim';
    final timetableDays = appProv.timetableDays;

    if (_selectedWeekday > timetableDays) {
      _selectedWeekday = 1;
    }

    // Bugünün gerçek gününe göre canlı durum hesaplaması
    final todayWeekday = DateTime.now().weekday;
    final todayEntries = scheduleProv.getDayEntries(todayWeekday);
    final liveInfo = _computeTodayLiveInfo(todayEntries, scheduleProv.bellPeriods, timetableDays);

    // Aşağıdaki gün listesinde seçili olan günün dersleri
    final dayEntries = scheduleProv.getDayEntries(_selectedWeekday);

    // Seçili güne ait tarih ve notlar
    final selectedDate = _getDateForWeekday(_selectedWeekday);
    final dayNotes = notesProv.getNotesForDay(_selectedWeekday, selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İyi Dersler, $teacherName 👋', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(
              '${appProv.settings?.schoolName.isNotEmpty == true ? appProv.settings!.schoolName : "ÖğretmenCep"} • ${appProv.activeAcademicYear}',
              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
            ),
          ],
        ),
        actions: [
          // 🕒 Aktif Canlı Saat Rozeti (Sade, ikonsuz ve tıklamasız gösterim)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontFamily: 'monospace',
                    color: isDark ? AppTheme.accent : AppTheme.brandLight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await scheduleProv.fetchTimetable();
          await classesProv.fetchClasses();
          await notesProv.fetchNotes();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🌟 Canlı Ders Bilgilendirme Kutusu (Yalnızca aktif ders saatindeyken gösterilir)
            if (liveInfo.state == TodayLiveState.inProgress && _selectedWeekday == todayWeekday)
              _buildLiveHeroCard(context, liveInfo, classesProv, isDark),

            // 📅 Ders Programı Başlığı ve Gün Seçici Hap Butonlar (Pazartesi ... Cuma)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ders Programı',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TimetableMatrixScreen()),
                    );
                  },
                  icon: const Icon(Icons.grid_on_rounded, size: 16),
                  label: const Text('Tüm Haftayı Gör', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(timetableDays, (index) {
                  final weekday = index + 1;
                  final isSelected = _selectedWeekday == weekday;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_days[index]),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppTheme.inkDark : AppTheme.inkLight),
                      ),
                      selectedColor: AppTheme.brandLight,
                      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      onSelected: (_) => setState(() => _selectedWeekday = weekday),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // 1. KUTU: Ders Programı Kutusu
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.18 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dayEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                      child: Column(
                        children: [
                          const Text('☕', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            '${_days[_selectedWeekday - 1]} günü için ders programı boş.',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hızlı matris ile saniyeler içinde ders ekleyebilirsiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandLight,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TimetableMatrixScreen()),
                              );
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Matristen Ders Ata'),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._buildScheduleListWithLiveBars(
                      context: context,
                      dayEntries: dayEntries,
                      bellPeriods: scheduleProv.bellPeriods,
                      classesProv: classesProv,
                      isDark: isDark,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. KUTU: Notlar Kutusu
            _buildNotesContainer(
              context: context,
              dayNotes: dayNotes,
              isDark: isDark,
              selectedDate: selectedDate,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Seçili haftanın gününün mevcut takvimdeki DateTime karşılığını döner
  DateTime _getDateForWeekday(int targetWeekday) {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Pazartesi, 7 = Pazar
    final diff = targetWeekday - currentWeekday;
    return DateTime(now.year, now.month, now.day).add(Duration(days: diff));
  }

  /// 2. Container: Notlar Kutusu
  Widget _buildNotesContainer({
    required BuildContext context,
    required List<DailyNoteModel> dayNotes,
    required bool isDark,
    required DateTime selectedDate,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Notlar Başlığı ve Not Ekle Butonu Hizalı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sticky_note_2_rounded, size: 18, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Notlar',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  if (dayNotes.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${dayNotes.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppTheme.accent : AppTheme.brandLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.brandDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddEditNoteSheet(context, defaultDate: selectedDate),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Not Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Günün Notları Listesi
          if (dayNotes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FAF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.lineDark.withOpacity(0.5) : AppTheme.lineLight,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 28,
                    color: (isDark ? AppTheme.mutedDark : AppTheme.mutedLight).withOpacity(0.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_days[_selectedWeekday - 1]} günü için henüz not bulunmuyor.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: dayNotes.map((note) => _buildNoteItem(context, note, isDark)).toList(),
            ),
        ],
      ),
    );
  }

  /// Not Öğesi Kartı (2 satırlık gösterim)
  Widget _buildNoteItem(BuildContext context, DailyNoteModel note, bool isDark) {
    final isRecurring = note.isRecurring;
    String badgeText;
    final IconData badgeIcon;
    if (isRecurring) {
      final dayName = (note.weekday != null && note.weekday! >= 1 && note.weekday! <= 7)
          ? _days[note.weekday! - 1]
          : _days[_selectedWeekday - 1];
      badgeText = 'Her $dayName (Haftalık)';
      badgeIcon = Icons.repeat_rounded;
    } else {
      if (note.date != null && note.date!.isNotEmpty) {
        try {
          final parsed = DateTime.parse(note.date!);
          badgeText = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(parsed);
        } catch (_) {
          badgeText = note.date!;
        }
      } else {
        badgeText = 'Tarihli Not';
      }
      badgeIcon = Icons.calendar_today_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242E2B) : const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showNoteDetailSheet(context, note),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rozet (Tarih ya da Haftalık Tekrar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRecurring
                            ? (isDark ? const Color(0xFF1B3B36) : const Color(0xFFE0F2F1))
                            : (isDark ? const Color(0xFF2E3345) : const Color(0xFFEDE7F6)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            badgeIcon,
                            size: 11,
                            color: isRecurring
                                ? (isDark ? AppTheme.accent : const Color(0xFF00796B))
                                : (isDark ? const Color(0xFFB39DDB) : const Color(0xFF5E35B1)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isRecurring
                                  ? (isDark ? AppTheme.accent : const Color(0xFF00796B))
                                  : (isDark ? const Color(0xFFB39DDB) : const Color(0xFF5E35B1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: (isDark ? AppTheme.mutedDark : AppTheme.mutedLight).withOpacity(0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 7),

                // Başlık varsa
                if (note.title != null && note.title!.trim().isNotEmpty) ...[
                  Text(
                    note.title!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                ],

                // Not Açıklaması: Kullanıcı isteği -> 2 satırlık gösterim
                Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? AppTheme.inkDark.withOpacity(0.85) : AppTheme.inkLight.withOpacity(0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Not Detay Penceresi (Alt panel, silme ve düzenleme butonları ile)
  void _showNoteDetailSheet(BuildContext context, DailyNoteModel note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecurring = note.isRecurring;
    String timingText;
    if (isRecurring) {
      final dayName = (note.weekday != null && note.weekday! >= 1 && note.weekday! <= 7)
          ? _days[note.weekday! - 1]
          : _days[_selectedWeekday - 1];
      timingText = 'Her $dayName (Haftalık Tekrarlanan)';
    } else {
      if (note.date != null && note.date!.isNotEmpty) {
        try {
          final parsed = DateTime.parse(note.date!);
          timingText = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(parsed);
        } catch (_) {
          timingText = note.date!;
        }
      } else {
        timingText = 'Tarih Belirtilmedi';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sticky_note_2_rounded, size: 22, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Not Detayı',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              isRecurring ? Icons.repeat_rounded : Icons.calendar_today_rounded,
                              size: 12,
                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                timingText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Content Area
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.title != null && note.title!.trim().isNotEmpty) ...[
                        Text(
                          note.title!.trim(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SelectableText(
                        note.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? AppTheme.inkDark : AppTheme.inkLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Aksiyon Butonları (Sil ve Düzenle)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _confirmDeleteNote(context, note);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _showAddEditNoteSheet(context, existingNote: note);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Düzenle', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Not Silme Onay Penceresi
  Future<void> _confirmDeleteNote(BuildContext context, DailyNoteModel note) async {
    if (note.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Notu Sil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('Bu notu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<NotesProvider>().deleteNote(note.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Not başarıyla silindi.' : 'Not silinirken hata oluştu.'),
            backgroundColor: success ? AppTheme.posLight : Colors.red,
          ),
        );
      }
    }
  }

  /// Yeni Not Ekleme veya Düzenleme Alt Paneli
  void _showAddEditNoteSheet(
    BuildContext context, {
    DailyNoteModel? existingNote,
    DateTime? defaultDate,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = existingNote != null;

    // Başlangıç değerleri
    bool isRecurring = existingNote?.isRecurring ?? false;
    int selectedWeekday = existingNote?.weekday ?? _selectedWeekday;

    DateTime selectedDate;
    if (existingNote?.date != null && existingNote!.date!.isNotEmpty) {
      try {
        selectedDate = DateTime.parse(existingNote.date!);
      } catch (_) {
        selectedDate = defaultDate ?? _getDateForWeekday(_selectedWeekday);
      }
    } else {
      selectedDate = defaultDate ?? _getDateForWeekday(_selectedWeekday);
    }

    final titleCtrl = TextEditingController(text: existingNote?.title ?? '');
    final contentCtrl = TextEditingController(text: existingNote?.content ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
                              color: AppTheme.accent,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Notu Düzenle' : 'Yeni Not Ekle',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Not Zamanlama Türü (Tarih mi Haftalık Tekrar mı?)
                    const Text(
                      'Not Zamanlaması',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14),
                                  SizedBox(width: 6),
                                  Text('Belirli Tarih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            selected: !isRecurring,
                            selectedColor: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.2),
                            onSelected: (val) {
                              if (val) setModalState(() => isRecurring = false);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.repeat_rounded, size: 14),
                                  SizedBox(width: 6),
                                  Text('Haftalık Tekrarla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            selected: isRecurring,
                            selectedColor: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.2),
                            onSelected: (val) {
                              if (val) setModalState(() => isRecurring = true);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Seçime Göre Tarih veya Gün Seçimi
                    if (!isRecurring) ...[
                      // Tarih Seçici Butonu
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetCtx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            locale: const Locale('tr', 'TR'),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDate = picked;
                              selectedWeekday = picked.weekday;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Haftalık Gün Seçimi
                      Text(
                        'Tekrarlanacak Gün: ${_days[selectedWeekday - 1]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(7, (index) {
                            final dayIdx = index + 1;
                            final isSel = selectedWeekday == dayIdx;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(_days[index]),
                                selected: isSel,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.w900 : FontWeight.normal,
                                  color: isSel ? Colors.white : null,
                                ),
                                selectedColor: AppTheme.brandLight,
                                onSelected: (_) => setModalState(() => selectedWeekday = dayIdx),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Başlık (İsteğe bağlı)
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Başlık (İsteğe bağlı)',
                        hintText: 'Örn: Sınav Hatırlatması, Ödev',
                        prefixIcon: const Icon(Icons.title_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Not Açıklaması (Zorunlu)
                    TextField(
                      controller: contentCtrl,
                      maxLines: 4,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Not Açıklaması *',
                        hintText: 'Notunuzu buraya giriniz...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kaydet / Vazgeç Butonları
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final content = contentCtrl.text.trim();
                              if (content.isEmpty) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lütfen not açıklamasını giriniz.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final title = titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim();
                              final dateStr = isRecurring ? null : DateFormat('yyyy-MM-dd').format(selectedDate);
                              final weekdayVal = isRecurring ? selectedWeekday : selectedDate.weekday;

                              Navigator.pop(sheetCtx);

                              final notesProv = context.read<NotesProvider>();
                              if (isEditing) {
                                final updated = existingNote.copyWith(
                                  title: title,
                                  content: content,
                                  date: dateStr,
                                  weekday: weekdayVal,
                                  isRecurring: isRecurring,
                                );
                                final ok = await notesProv.updateNote(updated);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Not güncellendi.' : 'Not güncellenemedi.'),
                                      backgroundColor: ok ? AppTheme.posLight : Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                final created = await notesProv.addNote(
                                  title: title,
                                  content: content,
                                  date: dateStr,
                                  weekday: weekdayVal,
                                  isRecurring: isRecurring,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(created != null ? 'Not eklendi.' : 'Not eklenemedi.'),
                                      backgroundColor: created != null ? AppTheme.posLight : Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              isEditing ? 'Güncelle' : 'Kaydet',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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
}
