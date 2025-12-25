import 'package:go_router/go_router.dart';
import '../../shared/widgets/role_guard.dart';
import 'doctor_dashboard.dart';

final doctorRoutes = [
  GoRoute(
    path: '/doctor/dashboard',
    builder: (context, state) => const RoleGuardScreen(
      child: DoctorDashboard(),
    ),
  ),
];
