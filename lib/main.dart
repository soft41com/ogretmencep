import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/classes_provider.dart';
import 'providers/exams_provider.dart';
import 'providers/plans_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/students_provider.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await NotificationService.instance.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Arayüz Hatası:\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => ClassesProvider()..fetchClasses()),
        ChangeNotifierProvider(create: (_) => StudentsProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()..fetchTimetable()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ExamsProvider()..fetchExams()),
        ChangeNotifierProvider(create: (_) => PlansProvider()..fetchPlans()),
      ],
      child: const OgretmenCepApp(),
    ),
  );
}

class OgretmenCepApp extends StatelessWidget {
  const OgretmenCepApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();

    return MaterialApp(
      title: 'ÖğretmenCep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appProv.themeMode,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: appProv.isLoading
          ? const SplashScreen()
          : (appProv.isOnboardingCompleted
              ? const HomeShell()
              : const WelcomeScreen()),
    );
  }
}
