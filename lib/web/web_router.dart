import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/app_flavor.dart';
import '../core/auth/login_screen.dart';
import '../core/tenant/tenant_selection_screen.dart';
import '../app/doctor/doctor_dashboard.dart';
import '../app/patient/patient_dashboard.dart';
import '../web/portal_selection_screen.dart';
import '../shared/widgets/role_guard.dart';

final webRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/',
        name: 'portal',
        builder: (context, state) => const PortalSelectionScreen(),
      ),
      GoRoute(
        path: '/doctor/login',
        name: 'doctorLogin',
        builder: (context, state) {
          AppFlavor.setFlavor(AppFlavor.doctor);
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/patient/login',
        name: 'patientLogin',
        builder: (context, state) {
          AppFlavor.setFlavor(AppFlavor.patient);
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/select-tenant',
        name: 'selectTenant',
        builder: (context, state) => const TenantSelectionScreen(),
      ),
      GoRoute(
        path: '/doctor/dashboard',
        name: 'doctorDashboard',
        builder: (context, state) => const RoleGuardScreen(
          child: DoctorDashboard(),
        ),
      ),
      GoRoute(
        path: '/patient/dashboard',
        name: 'patientDashboard',
        builder: (context, state) => const RoleGuardScreen(
          child: PatientDashboard(),
        ),
      ),
    ],
  );
});