import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_flavor.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/user_role.dart';
import '../../core/tenant/tenant_service.dart';
import '../../core/theme/app_theme.dart';

class RoleValidator {
  static Future<bool> validateRoleForFlavor({
    required WidgetRef ref,
    required AppFlavor flavor,
  }) async {
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUserId;
    final tenant = ref.read(selectedTenantProvider);

    if (userId == null || tenant == null) {
      return false;
    }

    final userRole = await authService.getUserRoleForTenant(
      userId: userId,
      tenantId: tenant.id,
    );

    if (userRole == null) {
      return false;
    }

    final allowedRoles = flavor.allowedRoles;
    return allowedRoles.contains(userRole.role.name);
  }

  static Future<void> applyTenantBranding({
    required WidgetRef ref,
  }) async {
    final tenant = ref.read(selectedTenantProvider);
    
    if (tenant?.branding != null) {
      final themeData = AppThemeData.fromBranding(tenant!.branding);
      ref.read(themeProvider.notifier).state = themeData;
    }
  }
}

class RoleGuardScreen extends ConsumerStatefulWidget {
  final Widget child;

  const RoleGuardScreen({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<RoleGuardScreen> createState() => _RoleGuardScreenState();
}

class _RoleGuardScreenState extends ConsumerState<RoleGuardScreen> {
  bool _isValidating = true;
  bool _isAuthorized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _validateRole();
  }

  Future<void> _validateRole() async {
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final isValid = await RoleValidator.validateRoleForFlavor(
        ref: ref,
        flavor: AppFlavor.current,
      );

      if (isValid) {
        await RoleValidator.applyTenantBranding(ref: ref);
      }

      setState(() {
        _isAuthorized = isValid;
        _isValidating = false;
        if (!isValid) {
          _errorMessage = 'You do not have permission to access this app with your current role.';
        }
      });
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isValidating = false;
        _errorMessage = 'Failed to validate permissions: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidating) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.block,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage ?? 'Access Denied',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please contact your administrator or use the correct app for your role.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
