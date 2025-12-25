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
import '../web/portal_selection_screen.dart';

final webRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final selectedTenant = ref.watch(selectedTenantProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.value?.session != null;
      final hasTenant = selectedTenant != null;
      final currentFlavor = AppFlavor.current;

      final isOnPortalSelection = state.matchedLocation == '/';
      final isOnDoctorLogin = state.matchedLocation == '/doctor/login';
      final isOnPatientLogin = state.matchedLocation == '/patient/login';
      final isSelectingTenant = state.matchedLocation == '/select-tenant';

      // If not authenticated and not on portal selection or login screens
      if (!isAuthenticated && !isOnPortalSelection && !isOnDoctorLogin && !isOnPatientLogin) {
        return '/';
      }

      // If authenticated but no tenant selected and not on tenant selection screen
      if (isAuthenticated && !hasTenant && !isSelectingTenant) {
        return '/select-tenant';
      }

      // If authenticated with tenant, redirect to appropriate dashboard
      if (isAuthenticated && hasTenant) {
        if (isOnPortalSelection || isOnDoctorLogin || isOnPatientLogin || isSelectingTenant) {
          return currentFlavor.isDoctor ? '/doctor/dashboard' : '/patient/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PortalSelectionScreen(),
      ),
      GoRoute(
        path: '/doctor/login',
        builder: (context, state) {
          AppFlavor.setFlavor(AppFlavor.doctor);
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/patient/login',
        builder: (context, state) {
          AppFlavor.setFlavor(AppFlavor.patient);
          return const LoginScreen();
        },
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
