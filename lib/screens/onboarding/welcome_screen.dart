import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../home_shell.dart';
import 'setup_wizard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final bool isFromSettings;

  const WelcomeScreen({Key? key, this.isFromSettings = false}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  final List<_ValuePropItem> _features = const [
    _ValuePropItem(
      icon: Icons.fact_check_rounded,
      color: Color(0xFF10B981),
      title: 'Hızlı & Pratik Yoklama',
      description: 'Ders bazında tek dokunuşla yoklama alın. Gelmeyen, geç kalan veya izinli öğrencileri kaydedin, geçmiş yoklamaları tek ekranda inceleyin.',
      tag: 'Yoklama & Devamsızlık',
    ),
    _ValuePropItem(
      icon: Icons.timer_outlined,
      color: Color(0xFF3B82F6),
      title: 'Canlı Ders & Zil Takibi',
      description: 'Zil saatlerine göre derste geçen süreyi ve kalan dakikaları canlı takip edin. Teneffüs vakitleri ve sıradaki dersiniz anlık ekranınızda.',
      tag: 'Akıllı Zamanlayıcı',
    ),
    _ValuePropItem(
      icon: Icons.add_circle_outline_rounded,
      color: Color(0xFFF59E0B),
      title: 'Öğrenci Puanları & Notlar',
      description: 'Derse katılım, ödev ve etkinliklere göre anında +/- puan verin. Öğrenci bazında rehberlik ve veli görüşme notlarını arşivleyin.',
      tag: 'Performans & Gözlem',
    ),
    _ValuePropItem(
      icon: Icons.calendar_month_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Haftalık Ders Programı',
      description: 'Hangi gün hangi sınıfta olduğunuzu kolayca planlayın. Günlük ve haftalık matris görünümüyle ders çakışmalarını önleyin.',
      tag: 'Ders Programı',
    ),
    _ValuePropItem(
      icon: Icons.menu_book_rounded,
      color: Color(0xFFEC4899),
      title: '36 Haftalık Yıllık Planlar',
      description: 'MEB müfredatına uygun yıllık ders planlarınızı sınıflarınızla eşleştirin, hafta hafta işlenen kazanımları işaretleyin.',
      tag: 'Müfredat & Kazanım',
    ),
    _ValuePropItem(
      icon: Icons.shield_rounded,
      color: Color(0xFF06B6D4),
      title: '%100 Güvenli & Yerel Veri',
      description: 'İnternet bağlantısı gerekmez. Verileriniz ve fotoğraflarınız sunuculara yüklenmez; yalnızca kendi telefonunuzda güvenle saklanır.',
      tag: 'Gizlilik & Güvenlik',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _features.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleStartWizard() async {
    if (widget.isFromSettings) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupWizardScreen(isFromSettings: true)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetupWizardScreen(isFromSettings: false)),
      );
    }
  }

  Future<void> _handleExploreWithSample() async {
    final appProv = context.read<AppProvider>();
    await appProv.setOnboardingCompleted(true);

    if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Üst Başlık & Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.school_rounded,
                          color: isDark ? AppTheme.accent : AppTheme.brandLight,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ÖğretmenCep',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : AppTheme.brandLight,
                          ),
                        ),
                        Text(
                          'Kişisel Asistanınız & Sınıf Defteriniz',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isFromSettings)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    TextButton(
                      onPressed: _handleExploreWithSample,
                      child: const Text('Atla', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Orta Alan: Karşılama ve Değer Önerisi Carousel
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) {
                        setState(() => _currentPage = idx);
                        _startAutoSlide(); // Kullanıcı kaydırınca timer'ı sıfırla
                      },
                      itemCount: _features.length,
                      itemBuilder: (context, index) {
                        final item = _features[index];
                        return _buildFeatureSlide(item, isDark);
                      },
                    ),
                  ),

                  // Sayfa Göstergeleri (Dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_features.length, (i) {
                      final isActive = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? AppTheme.accent : AppTheme.brandLight)
                              : (isDark ? Colors.grey[700] : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Alt Alan: Seçenek Butonları
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Adım Adım Kuruluma Başla (Önerilen)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandLight,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _handleStartWizard,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                      label: const Text(
                        'Adım Adım Kuruluma Başla',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Kurulumu Atla
                  TextButton(
                    onPressed: _handleExploreWithSample,
                    child: Text(
                      'Kurulumu atla ve doğrudan uygulamaya geç →',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.accent : AppTheme.brandLight,
                      ),
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

  Widget _buildFeatureSlide(_ValuePropItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İkon Rozeti
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 46,
              color: item.color,
            ),
          ),
          const SizedBox(height: 20),

          // Etiket Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Başlık
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Açıklama
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePropItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String tag;

  const _ValuePropItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.tag,
  });
}
