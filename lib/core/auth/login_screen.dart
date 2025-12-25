import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../app/app_flavor.dart';
import '../../core/tenant/tenant_service.dart';
import '../../shared/utils/router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Check if user is already authenticated (e.g., from OTP link click)
    _checkAuthState();
  }

  void _checkAuthState() {
    // This will be called when the widget is built
    // We'll use the authStateProvider in the build method instead
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
      });
      return;
    }

    if (password.isEmpty || password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final tenantService = ref.read(tenantServiceProvider);
      
      await authService.signInWithPassword(
        email: email,
        password: password,
      );

      // Fetch user's tenants and set the first one as selected
      final userId = authService.currentUser?.id;
      if (userId != null) {
        try {
          final roles = await authService.fetchUserTenantRoles(userId);
          if (roles.isNotEmpty) {
            final firstTenantId = roles[0].tenantId;
            final tenant = await tenantService.getTenantById(firstTenantId);
            if (tenant != null) {
              ref.read(selectedTenantProvider.notifier).setTenant(tenant);
            }
          } else {
            // No tenant yet: go to tenant selection (works for both flavors)
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(AppRouter.selectTenantRoute);
              return;
            }
          }
        } catch (e) {
          // If we can't fetch tenant, just continue
          print('Error fetching tenant: $e');
        }
      }

      // After successful sign in, navigate to dashboard
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            AppFlavor.current.isDoctor ? AppRouter.doctorDashboardRoute : AppRouter.patientDashboardRoute,
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is already authenticated
    final authService = ref.watch(authServiceProvider);
    final currentUser = authService.currentUser;
    
    // If user is authenticated, navigate to dashboard
    if (currentUser != null) {
      // Use addPostFrameCallback to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            AppFlavor.current.isDoctor ? AppRouter.doctorDashboardRoute : AppRouter.patientDashboardRoute,
          );
        }
      });
    }
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.medical_services,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 24),
                // Show "Register as Doctor" button only in Doctor app
                if (AppFlavor.current.isDoctor)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(AppRouter.doctorRegisterRoute),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register as Doctor'),
                  ),
                // Show "Register as Patient" button only in Patient app
                if (AppFlavor.current.isPatient)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(AppRouter.patientRegisterRoute),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register as Patient'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
