import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app_flavor.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'shared/utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppFlavor.setFlavor(AppFlavor.doctor);
  
  await SupabaseConfig.initialize();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppFlavor.current.appName,
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
