import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.school_rounded,
                    size: 80,
                    color: isDark ? AppTheme.accent : AppTheme.brandLight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ÖğretmenCep',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppTheme.brandLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Akıllı Öğretmen Asistanı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppTheme.accent : AppTheme.brandLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
