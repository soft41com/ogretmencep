import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../theme/app_theme.dart';

class ClassStatisticsScreen extends StatefulWidget {
  const ClassStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<ClassStatisticsScreen> createState() => _ClassStatisticsScreenState();
}

class _ClassStatisticsScreenState extends State<ClassStatisticsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late TabController _tabController;

  // Genel Toplamlar
  int _totalStudents = 0;
  int _totalGirls = 0;
  int _totalBoys = 0;
  int _totalClasses = 0;

  // Seviye (Kademe) Dağılımı Listesi
  List<Map<String, dynamic>> _levelStats = [];

  // Sınıf Dağılımı Listesi
  List<Map<String, dynamic>> _classStats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Sınıfları çek
      final classRows = await db.query(
        'classes',
        where: 'deleted_at IS NULL',
        orderBy: 'name ASC',
      );

      // 2. Öğrencileri çek
      final studentRows = await db.rawQuery('''
        SELECT s.id, s.class_id, s.gender, c.name as class_name, c.grade_level
        FROM students s
        JOIN classes c ON c.id = s.class_id
        WHERE s.deleted_at IS NULL AND c.deleted_at IS NULL
      ''');

      int totalStudents = studentRows.length;
      int totalGirls = 0;
      int totalBoys = 0;

      // Sınıf bazlı gruplama
      final Map<int, Map<String, dynamic>> classMap = {};
      for (var c in classRows) {
        final id = c['id'] as int;
        final name = (c['name'] as String?) ?? '';
        final gradeLevel = (c['grade_level'] as String?) ?? '';
        classMap[id] = {
          'id': id,
          'name': name,
          'grade_level': gradeLevel,
          'total': 0,
          'girls': 0,
          'boys': 0,
        };
      }

      // Öğrenci sayılarını sınıflara ekle
      for (var s in studentRows) {
        final cId = s['class_id'] as int?;
        final gender = (s['gender'] as String?)?.toUpperCase() ?? '';

        final isGirl = gender == 'F' || gender == 'K' || gender == 'KIZ';
        if (isGirl) {
          totalGirls++;
        } else {
          totalBoys++;
        }

        if (cId != null && classMap.containsKey(cId)) {
          classMap[cId]!['total'] = (classMap[cId]!['total'] as int) + 1;
          if (isGirl) {
            classMap[cId]!['girls'] = (classMap[cId]!['girls'] as int) + 1;
          } else {
            classMap[cId]!['boys'] = (classMap[cId]!['boys'] as int) + 1;
          }
        }
      }

      final classList = classMap.values.toList();
      classList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Seviye / Kademe bazlı gruplama
      final Map<String, Map<String, dynamic>> levelMap = {};
      for (var c in classList) {
        String level = (c['grade_level'] as String).trim();
        if (level.isEmpty) {
          // Sınıf adından çıkarmayı dene (örn: 9-A -> 9. Sınıf)
          final match = RegExp(r'^(\d+)').firstMatch(c['name'] as String);
          level = match != null ? '${match.group(1)}. Sınıf' : 'Diğer';
        } else if (!level.toLowerCase().contains('sınıf') && !level.toLowerCase().contains('kademe')) {
          level = '$level. Sınıf';
        }

        if (!levelMap.containsKey(level)) {
          levelMap[level] = {
            'level': level,
            'classCount': 0,
            'total': 0,
            'girls': 0,
            'boys': 0,
          };
        }

        levelMap[level]!['classCount'] = (levelMap[level]!['classCount'] as int) + 1;
        levelMap[level]!['total'] = (levelMap[level]!['total'] as int) + (c['total'] as int);
        levelMap[level]!['girls'] = (levelMap[level]!['girls'] as int) + (c['girls'] as int);
        levelMap[level]!['boys'] = (levelMap[level]!['boys'] as int) + (c['boys'] as int);
      }

      final levelList = levelMap.values.toList();
      // Seviyeleri sırala (örn 5. Sınıf, 6. Sınıf...)
      levelList.sort((a, b) {
        final aNum = int.tryParse(RegExp(r'\d+').firstMatch(a['level'] as String)?.group(0) ?? '') ?? 999;
        final bNum = int.tryParse(RegExp(r'\d+').firstMatch(b['level'] as String)?.group(0) ?? '') ?? 999;
        return aNum.compareTo(bNum);
      });

      if (mounted) {
        setState(() {
          _totalStudents = totalStudents;
          _totalGirls = totalGirls;
          _totalBoys = totalBoys;
          _totalClasses = classRows.length;
          _levelStats = levelList;
          _classStats = classList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci İstatistikleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. GENEL TOPLAM ÖZET KARTI
                    _buildGeneralOverviewCard(isDark),
                    const SizedBox(height: 18),

                    // 2. SEKMELER (Seviyeler ve Sınıflar)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: [
                          Tab(
                            text: 'Seviye / Kademe (${_levelStats.length})',
                            icon: const Icon(Icons.layers_rounded, size: 18),
                          ),
                          Tab(
                            text: 'Sınıflar (${_classStats.length})',
                            icon: const Icon(Icons.class_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. SEKME İÇERİKLERİ
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return _tabController.index == 0
                            ? _buildLevelList(isDark)
                            : _buildClassList(isDark);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 🌟 GENEL TOPLAM KARTI
  Widget _buildGeneralOverviewCard(bool isDark) {
    final girlRatio = _totalStudents > 0 ? (_totalGirls / _totalStudents) : 0.0;
    final boyRatio = _totalStudents > 0 ? (_totalBoys / _totalStudents) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF17433B), const Color(0xFF0F2E28)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_rounded, color: Colors.amberAccent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Genel Dağılım',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalClasses Sınıf',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toplam Öğrenci Sayısı
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_totalStudents',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 38,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Toplam Kayıtlı Öğrenci',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Dağılım İlerleme Çubuğu (Kız: Pembe/Turuncu, Erkek: Mavi/Açık Yeşil)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (_totalStudents > 0) ...[
                    Flexible(
                      flex: (_totalGirls * 1000).toInt(),
                      child: Container(color: const Color(0xFFF472B6)), // Pembe
                    ),
                    Flexible(
                      flex: (_totalBoys * 1000).toInt(),
                      child: Container(color: const Color(0xFF60A5FA)), // Mavi
                    ),
                  ] else ...[
                    Expanded(child: Container(color: Colors.white24)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Kız ve Erkek Sayı Rozetleri
          Row(
            children: [
              // Kızlar
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF472B6).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF472B6).withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.female_rounded, color: Color(0xFFF472B6), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kız Öğrenci', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            '$_totalGirls (%${(girlRatio * 100).toStringAsFixed(1)})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Erkekler
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF60A5FA).withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.male_rounded, color: Color(0xFF60A5FA), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Erkek Öğrenci', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            '$_totalBoys (%${(boyRatio * 100).toStringAsFixed(1)})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🏢 SEVİYE / KADEME LİSTESİ
  Widget _buildLevelList(bool isDark) {
    if (_levelStats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Henüz sınıf verisi bulunmuyor.',
            style: TextStyle(color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _levelStats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = _levelStats[i];
        final levelName = item['level'] as String;
        final total = item['total'] as int;
        final girls = item['girls'] as int;
        final boys = item['boys'] as int;
        final classCount = item['classCount'] as int;

        final girlRatio = total > 0 ? (girls / total) : 0.0;
        final boyRatio = total > 0 ? (boys / total) : 0.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: AppTheme.accent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          levelName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                      ),
                      child: Text(
                        '$classCount Sınıf • $total Öğrenci',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dağılım Çubuğu
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (total > 0) ...[
                          Flexible(
                            flex: (girls * 1000).toInt(),
                            child: Container(color: const Color(0xFFF472B6)),
                          ),
                          Flexible(
                            flex: (boys * 1000).toInt(),
                            child: Container(color: const Color(0xFF60A5FA)),
                          ),
                        ] else ...[
                          Expanded(child: Container(color: isDark ? Colors.white12 : Colors.black12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Detaylar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.female_rounded, color: Color(0xFFF472B6), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Kız: $girls (%${(girlRatio * 100).toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.male_rounded, color: Color(0xFF60A5FA), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Erkek: $boys (%${(boyRatio * 100).toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 📚 SINIFLAR LİSTESİ
  Widget _buildClassList(bool isDark) {
    if (_classStats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Henüz sınıf verisi bulunmuyor.',
            style: TextStyle(color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _classStats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = _classStats[i];
        final name = c['name'] as String;
        final total = c['total'] as int;
        final girls = c['girls'] as int;
        final boys = c['boys'] as int;
        final gradeLevel = (c['grade_level'] as String).trim();

        final girlRatio = total > 0 ? (girls / total) : 0.0;
        final boyRatio = total > 0 ? (boys / total) : 0.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                        if (gradeLevel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            gradeLevel,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '$total Öğrenci',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dağılım Çubuğu
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (total > 0) ...[
                          Flexible(
                            flex: (girls * 1000).toInt(),
                            child: Container(color: const Color(0xFFF472B6)),
                          ),
                          Flexible(
                            flex: (boys * 1000).toInt(),
                            child: Container(color: const Color(0xFF60A5FA)),
                          ),
                        ] else ...[
                          Expanded(child: Container(color: isDark ? Colors.white12 : Colors.black12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Detaylar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.female_rounded, color: Color(0xFFF472B6), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Kız: $girls (%${(girlRatio * 100).toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.male_rounded, color: Color(0xFF60A5FA), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Erkek: $boys (%${(boyRatio * 100).toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
