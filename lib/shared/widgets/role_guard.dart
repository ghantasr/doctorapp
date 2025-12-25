import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_flavor.dart';
import '../../core/auth/auth_service.dart';
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

    // Check if the user's role is allowed for this flavor
    final allowedRoles = flavor.allowedRoles;
    
    // Check both the enum name and the original role string
    final roleMatch = allowedRoles.contains(userRole.role.name) ||
        allowedRoles.contains(userRole.role.toString().split('.').last);
    
    return roleMatch;
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
      // If no tenant is selected yet, attempt to auto-select the first tenant for the user
      final authService = ref.read(authServiceProvider);
      final tenantService = ref.read(tenantServiceProvider);
      final userId = authService.currentUserId;
      final tenant = ref.read(selectedTenantProvider);

      if (userId != null && tenant == null) {
        try {
          final roles = await authService.fetchUserTenantRoles(userId);

          if (roles.isEmpty) {
            // Send user to select clinic instead of looping registration/signout
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('selectTenant', (route) => false);
            }
            setState(() {
              _isAuthorized = false;
              _isValidating = false;
              _errorMessage = 'No clinic found for this account. Please select or create one.';
            });
            return;
          }

          final firstTenantId = roles.first.tenantId;
          final fetchedTenant = await tenantService.getTenantById(firstTenantId);
          if (fetchedTenant != null) {
            ref.read(selectedTenantProvider.notifier).setTenant(fetchedTenant);
          }
        } catch (_) {
          // ignore and let validation proceed
        }
      }

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
                  onPressed: () {
                    // Let the user pick a tenant if they have one but it wasn't selected
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    Navigator.of(context).pushNamed('selectTenant');
                  },
                  child: const Text('Select Clinic'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('login', (route) => false);
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
