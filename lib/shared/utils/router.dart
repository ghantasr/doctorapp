import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/doctor/doctor_dashboard.dart';
import '../../app/patient/patient_dashboard.dart';
import '../../core/auth/login_screen.dart';
import '../../core/auth/doctor_registration_screen.dart';
import '../../core/auth/patient_registration_screen.dart';
import '../../core/tenant/tenant_selection_screen.dart';
import '../../shared/widgets/role_guard.dart';

// Simple navigation helper without GoRouter
class AppRouter {
  static const String loginRoute = '/login';
  static const String doctorRegisterRoute = '/doctorRegister';
  static const String patientRegisterRoute = '/patientRegister';
  static const String selectTenantRoute = '/selectTenant';
  static const String doctorDashboardRoute = '/doctorDashboard';
  static const String patientDashboardRoute = '/patientDashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginRoute:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case doctorRegisterRoute:
        return MaterialPageRoute(
          builder: (_) => const DoctorRegistrationScreen(),
          settings: settings,
        );
      case patientRegisterRoute:
        return MaterialPageRoute(
          builder: (_) => const PatientRegistrationScreen(),
          settings: settings,
        );
      case selectTenantRoute:
        return MaterialPageRoute(
          builder: (_) => const TenantSelectionScreen(),
          settings: settings,
        );
      case doctorDashboardRoute:
        return MaterialPageRoute(
          builder: (_) => const RoleGuardScreen(
            child: DoctorDashboard(),
          ),
          settings: settings,
        );
      case patientDashboardRoute:
        return MaterialPageRoute(
          builder: (_) => const RoleGuardScreen(
            child: PatientDashboard(),
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}

final routerProvider = Provider<void>((ref) {
  // This provider exists for compatibility
});
