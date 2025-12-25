import 'package:go_router/go_router.dart';
import '../../shared/widgets/role_guard.dart';
import 'patient_dashboard.dart';

final patientRoutes = [
  GoRoute(
    path: '/patient/dashboard',
    builder: (context, state) => const RoleGuardScreen(
      child: PatientDashboard(),
    ),
  ),
];
