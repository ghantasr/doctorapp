import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app_flavor.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'shared/utils/router.dart';
import 'core/auth/auth_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'firebase_options_doctor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppFlavor.setFlavor(AppFlavor.doctor);
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await SupabaseConfig.initialize();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize push notifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePushNotifications();
    });
  }

  Future<void> _initializePushNotifications() async {
    final pushService = ref.read(pushNotificationServiceProvider);
    await pushService.initialize();
    
    // Subscribe to doctor-specific topics if user is logged in
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      await pushService.subscribeToTopic('doctor_${user.id}');
      await pushService.subscribeToTopic('all_doctors');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    // Watch auth state to handle navigation
    ref.watch(authStateProvider);

    return MaterialApp(
      title: AppFlavor.current.appName,
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.loginRoute,
    );
  }
}
