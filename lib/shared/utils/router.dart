import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/app_flavor.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/login_screen.dart';
import '../core/tenant/tenant_selection_screen.dart';
import '../core/tenant/tenant_service.dart';
import '../app/doctor/doctor_routes.dart';
import '../app/patient/patient_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final selectedTenant = ref.watch(selectedTenantProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.value?.session != null;
      final hasTenant = selectedTenant != null;

      final isLoggingIn = state.matchedLocation == '/';
      final isSelectingTenant = state.matchedLocation == '/select-tenant';

      if (!isAuthenticated) {
        return '/';
      }

      if (isAuthenticated && !hasTenant && !isSelectingTenant) {
        return '/select-tenant';
      }

      if (isAuthenticated && hasTenant) {
        if (isLoggingIn || isSelectingTenant) {
          return AppFlavor.current.isDoctor 
              ? '/doctor/dashboard' 
              : '/patient/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/select-tenant',
        builder: (context, state) => const TenantSelectionScreen(),
      ),
      ...doctorRoutes,
      ...patientRoutes,
    ],
  );
});
