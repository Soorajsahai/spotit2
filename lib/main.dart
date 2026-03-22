import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'user_service.dart';
import 'theme_service.dart';
import 'splash_screen.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'report_issue_page.dart';
import 'admin_dashboard.dart';
import 'forgot_password.dart';
import 'my_issue_page.dart';
import 'reports_display_page.dart';
import 'track_issues_page.dart';
import 'settings_page.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UserService.loadSession();
  await ThemeService().ensureLoaded();

  // Set up error widget builder to catch rendering errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'An error occurred',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                details.exception.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  };
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e, stackTrace) {
    print('Firebase initialization error: $e');
    print('Stack trace: $stackTrace');
    // Continue anyway - some Firebase features might still work
  }
  
  runApp(const SpotItAI());
}

class SpotItAI extends StatefulWidget {
  const SpotItAI({super.key});

  @override
  State<SpotItAI> createState() => _SpotItAIState();
}

class _SpotItAIState extends State<SpotItAI> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotIt AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeService.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      onGenerateRoute: (settings) {
        // Fallback for unknown routes
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      },
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/report': (_) => const ReportIssuePage(),
        '/admin': (_) => const AdminDashboard(),
        '/forgot': (_) => const ForgotPasswordPage(),
        '/my-reports': (_) => const MyIssuesPage(),
        '/reports-display': (_) => const ReportsDisplayPage(),
        '/track-issues': (_) => const TrackIssuesPage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}
