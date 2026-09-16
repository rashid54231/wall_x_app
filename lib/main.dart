import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/colors.dart';
import 'features/user/screens/user_dashboard.dart';
import 'features/user/screens/onboarding_screen.dart';
import 'features/user/providers/auth_provider.dart';

import 'features/user/controllers/wallpaper_cache.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? true;
  final isFirstTime = prefs.getBool('isFirstTime') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  await Supabase.initialize(
    url: 'https://vqtrxblmptqglosmwpql.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxdHJ4YmxtcHRxZ2xvc213cHFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzMDAzMTAsImV4cCI6MjA5NTg3NjMxMH0.izA5tv6gguYmotg-b6rSJgr5w9Bbyz9_GsNasOthJ2c',
  );

  // ⚡ Pre-warm local cache from disk so Home & Tabs render in 0ms!
  await WallpaperCache().initFromDisk();

  // Initialize OneSignal Push Notifications asynchronously without blocking UI startup
  Future.microtask(() {
    try {
      const oneSignalAppId = "YOUR_ONESIGNAL_APP_ID";
      if (oneSignalAppId != "YOUR_ONESIGNAL_APP_ID" && oneSignalAppId.isNotEmpty) {
        OneSignal.Debug.setLogLevel(OSLogLevel.none);
        OneSignal.initialize(oneSignalAppId);
        OneSignal.Notifications.requestPermission(true);
      }
    } catch (_) {}
  });

  runApp(ProviderScope(child: MyApp(isFirstTime: isFirstTime)));
}

class MyApp extends ConsumerStatefulWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // App start pe session restore karo (taake role fetch ho jaye)
    Future.microtask(() => ref.read(authProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Wallpaper App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(color: Colors.black),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.background,
            primarySwatch: Colors.purple,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white),
            ),
          ),
          home: widget.isFirstTime ? const OnboardingScreen() : UserDashboard(),
        );
      },
    );
  }
}