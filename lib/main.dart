import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'constants/app_theme.dart';
import 'constants/app_colors.dart';
import 'services/auth_service.dart';
import 'services/report_service.dart';
import 'services/accessibility_service.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF040E1F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const NizhalApp());
}

class NizhalApp extends StatelessWidget {
  const NizhalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ReportService>(create: (_) => ReportService()),
        ChangeNotifierProvider<AccessibilityService>(
          create: (_) => AccessibilityService(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authService = context.read<AuthService>();
          final router = AppRouter.router(authService);

          return MaterialApp.router(
            title: 'Nizhal',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (context, child) {
              final accessibility = context.watch<AccessibilityService>();
              return Container(
                color: const Color(
                  0xFFE2E8F0,
                ), // Soft light gray outer background for contrast on desktop/web
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(accessibility.textScale),
                  ),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      color: AppColors.background,
                      child: child!,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
