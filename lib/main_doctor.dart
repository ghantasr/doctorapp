import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app_flavor.dart';
import 'core/supabase/supabase_config.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'shared/utils/router.dart';
import 'core/auth/auth_service.dart';
import 'firebase_options_doctor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppFlavor.setFlavor(AppFlavor.doctor);
  
  // Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Then initialize Supabase
  await SupabaseConfig.initialize();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    // Watch auth state
    ref.listen(authStateProvider, (previous, next) {
      // Initialize push notifications after user logs in
      if (next.value != null) {
        ref.read(pushNotificationServiceProvider).initialize();
      }
    });

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