import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app_flavor.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'web/web_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with doctor flavor by default (will be changed based on portal selection)
  AppFlavor.setFlavor(AppFlavor.doctor);
  
  await SupabaseConfig.initialize();
  
  runApp(const ProviderScope(child: WebApp()));
}

class WebApp extends ConsumerWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(webRouterProvider);
    final theme = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'HealthCare Portal',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
