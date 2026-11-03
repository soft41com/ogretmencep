import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
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

  bool get shouldShowBox =>
      state != TodayLiveState.noClassesToday &&
      state != TodayLiveState.allFinishedHidden;
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

  // 🏫 Okulda Aktif Ders Devam Ederken Öğretmenin Dersi Yoksa Gösterilecek Sade Bilgilendirme Kutusu
  Widget _buildSimpleSchoolActiveCard(
    BuildContext context,
    TodayLiveInfo liveInfo,
    bool isDark,
  ) {
    final period = liveInfo.activeSchoolPeriod;
    final nextClass = liveInfo.nextClass;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Üst Rozet Satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.posLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Okulda ${period?.label ?? "Ders"} Devam Ediyor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.accent : AppTheme.brandLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (period != null)
                Text(
                  '${period.startTime} - ${period.endTime}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Ana Başlık & Durum
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber.shade900 : Colors.amber.shade100).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('☕', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bu Saatte Dersiniz Yok (Boş Saat)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dersin bitimine ${liveInfo.remainingMinutes} dakika kaldı',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: liveInfo.progress,
              minHeight: 5,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppTheme.accent : AppTheme.brandLight,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Sıradaki Ders veya Gün Sonu Bilgisi
          if (nextClass != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.lineDark : AppTheme.lineLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: isDark ? AppTheme.accent : AppTheme.brandLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sıradaki Dersiniz: ${nextClass.periodLabel ?? ""} (${nextClass.startTime}) • ${nextClass.className} ${nextClass.subject}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppTheme.posLight),
                const SizedBox(width: 6),
                Text(
                  'Bugün için başka dersiniz bulunmuyor.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  ),
                ),
              ],
            ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final scheduleProv = context.watch<ScheduleProvider>();
    final classesProv = context.watch<ClassesProvider>();
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
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🌟 Canlı Ders Bilgilendirme Kutusu
            if (liveInfo.state == TodayLiveState.schoolActiveTeacherFree)
              _buildSimpleSchoolActiveCard(context, liveInfo, isDark)
            else if (liveInfo.shouldShowBox)
              _buildLiveHeroCard(context, liveInfo, classesProv, isDark),

            // Gün Seçici Hap Butonlar (Pazartesi ... Cuma)
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

            // Seçili Günün Dersleri
            if (dayEntries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Text('☕', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 12),
                      Text(
                        '${_days[_selectedWeekday - 1]} günü için ders programı boş.',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hızlı matris ile saniyeler içinde ders ekleyebilirsiniz.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
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
                ),
              )
            else
              ...dayEntries.map((entry) {
                final classColor = entry.classColor != null ? _parseHex(entry.classColor!) : AppTheme.brandLight;
                final now = DateTime.now();
                final isToday = _selectedWeekday == todayWeekday;
                bool isCurrentActive = false;

                if (isToday && entry.startTime != null && entry.endTime != null) {
                  try {
                    final currentMinutes = now.hour * 60 + now.minute;
                    final startParts = entry.startTime!.split(':').map(int.parse).toList();
                    final endParts = entry.endTime!.split(':').map(int.parse).toList();
                    final startM = startParts[0] * 60 + startParts[1];
                    final endM = endParts[0] * 60 + endParts[1];
                    if (currentMinutes >= startM && currentMinutes < endM) {
                      isCurrentActive = true;
                    }
                  } catch (_) {}
                }

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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
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
                    title: Row(
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
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${entry.periodLabel ?? ""} (${entry.startTime ?? ""} - ${entry.endTime ?? ""})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentActive
                              ? (isDark ? AppTheme.posLight : const Color(0xFF1B5E20))
                              : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                        ),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: isCurrentActive ? AppTheme.posLight : null,
                    ),
                    onTap: () {
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
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
