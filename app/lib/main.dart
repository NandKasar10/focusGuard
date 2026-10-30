import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/database_helper.dart';
import 'core/notification_service.dart';
import 'core/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/summary_provider.dart';
import 'providers/usage_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/intervention_manager.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services
  final storage = StorageService();
  await storage.init();

  final db = DatabaseHelper();
  await db.database;

  final notifications = NotificationService();
  await notifications.init();

  // Attach NavigatorKey to InterventionManager for global modal overlay triggers
  InterventionManager().setNavigatorKey(rootNavigatorKey);

  runApp(const FocusGuardApp());
}

class FocusGuardApp extends StatelessWidget {
  const FocusGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
        ChangeNotifierProvider(create: (_) => SummaryProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final storage = StorageService();

    if (auth.status == AuthStatus.loading || auth.status == AuthStatus.initial) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, size: 64, color: Colors.indigo),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (auth.isAuthenticated) {
      if (!storage.isOnboardingCompleted() || !storage.hasLocalVideo()) {
        return const OnboardingScreen();
      }
      return const DashboardScreen();
    }

    return const LoginScreen();
  }
}
