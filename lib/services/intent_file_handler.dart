import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/classes_provider.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import 'institution_share_service.dart';

class IntentFileHandler {
  static const MethodChannel _channel = MethodChannel('com.ogretmencep.app/intent');
  static bool _isListening = false;
  static BuildContext? _currentContext;

  /// Ana ekran (HomeShell) açıldığında context ile dinlemeyi başlatır
  static void initialize(BuildContext context) {
    _currentContext = context;
    if (_isListening) return;
    _isListening = true;

    // Kanal çağrılarını dinle
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        final filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty) {
          _handleIncomingFile(filePath);
        }
      }
    });

    // İlk açılışta intent ile gelmiş dosya var mı kontrol et
    _checkInitialFile();
  }

  static void updateContext(BuildContext context) {
    _currentContext = context;
  }

  static Future<void> _checkInitialFile() async {
    try {
      final initialPath = await _channel.invokeMethod<String>('getInitialFile');
      if (initialPath != null && initialPath.isNotEmpty) {
        _handleIncomingFile(initialPath);
      }
    } catch (_) {}
  }

  static bool _isDialogShowing = false;
  static String? _lastHandledPath;
  static DateTime? _lastHandledTime;

  static void _handleIncomingFile(String filePath) {
    if (_currentContext == null) return;
    if (_isDialogShowing) return;

    // Aynı dosya son 3 saniye içinde işlendiyse mükerrer dialogu engelle
    if (_lastHandledPath == filePath &&
        _lastHandledTime != null &&
        DateTime.now().difference(_lastHandledTime!).inSeconds < 3) {
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) return;

    _isDialogShowing = true;
    _lastHandledPath = filePath;
    _lastHandledTime = DateTime.now();

    // Kullanıcıya şık bir onay dialogu göster
    showDialog(
      context: _currentContext!,
      barrierDismissible: false,
      builder: (ctx) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandLight.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded, color: AppTheme.brandLight, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kurum Veri Paketi Algılandı',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WhatsApp veya dış kaynaktan bir okul kurum veri paketi (.ogretmencep) alındı.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bu işlemle sisteme aktarılacaklar:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                        ),
                        SizedBox(height: 6),
                        Text('• Tüm sınıflar', style: TextStyle(fontSize: 12)),
                        Text('• Tüm sınıflardaki öğrenciler', style: TextStyle(fontSize: 12)),
                        Text('• Öğrencilerin fotoğrafları', style: TextStyle(fontSize: 12)),
                        Text('• Okul zil saatleri', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isProcessing) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Veriler işleniyor, lütfen bekleyin...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isProcessing) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      setDialogState(() => isProcessing = true);
                      final result = await InstitutionShareService.importInstitutionData(file);

                      if (dialogCtx.mounted) {
                        Navigator.pop(ctx);
                      }

                      if (_currentContext != null && _currentContext!.mounted) {
                        if (result.success) {
                          // Provider'ları yenile
                          _currentContext!.read<ClassesProvider>().fetchClasses();
                          _currentContext!.read<ScheduleProvider>().fetchBellPeriods();
                          _currentContext!.read<AppProvider>().loadSettings();

                          showDialog(
                            context: _currentContext!,
                            builder: (sCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: AppTheme.posLight, size: 28),
                                  SizedBox(width: 10),
                                  Text('Kurum Verisi Aktarıldı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              content: Text(
                                'Tebrikler! Kurum verileri başarıyla işlendi:\n\n'
                                '• ${result.classCount} sınıf eklendi / güncellendi\n'
                                '• ${result.studentCount} öğrenci kaydedildi\n'
                                '• ${result.photoCount} fotoğraf yüklendi\n'
                                '• ${result.bellPeriodCount} zil saati güncellendi',
                                style: const TextStyle(fontSize: 13, height: 1.5),
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(sCtx),
                                  child: const Text('Harika'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(_currentContext!).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.negLight,
                              content: Text(result.errorMessage ?? 'İçe aktarma başarısız.'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_done_rounded, size: 18),
                    label: const Text('Şimdi İçe Aktar'),
                  ),
                ],
              ],
            );
          },
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }
}
