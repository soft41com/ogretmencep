import 'package:flutter/material.dart';
import '../services/intent_file_handler.dart';
import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'classes_screen.dart';
import 'exams_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Varsayılan olarak 2: Bugün sekmesi
  int _currentIndex = 2;
  final List<int> _tabHistory = [2];
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IntentFileHandler.initialize(context);
    });
  }

  final List<Widget> _screens = const [
    ClassesScreen(),    // 0: Sınıflar
    AttendanceScreen(), // 1: Yoklama
    HomeScreen(),       // 2: Bugün (Ortada)
    ExamsScreen(),      // 3: Sınavlar
    SettingsScreen(),   // 4: Ayarlar
  ];

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _tabHistory.remove(index);
      _tabHistory.add(index);
    });
  }

  Future<bool> _handleWillPop() async {
    // Eğer sekme geçmişinde önceki sekmeler varsa onlara geri dön
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = _tabHistory.last;
      });
      return false;
    }

    // Ana sekme olan Bugün'de değilsek, Bugün'e dön
    if (_currentIndex != 2) {
      setState(() {
        _currentIndex = 2;
        _tabHistory.clear();
        _tabHistory.add(2);
      });
      return false;
    }

    // Bugün sekmesindeyken yanlışlıkla uygulamadan çıkmayı önlemek için çift tıklama onayı
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uygulamadan çıkmak için tekrar geri tuşuna basın'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups_rounded),
              label: 'Sınıflar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              activeIcon: Icon(Icons.fact_check_rounded),
              label: 'Yoklama',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.calendar_today_rounded, size: 28),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month_rounded, size: 30),
              ),
              label: 'Bugün',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Sınavlar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}
