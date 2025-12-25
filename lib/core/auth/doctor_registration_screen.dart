import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import '../tenant/tenant_service.dart';
import '../../shared/utils/router.dart';

class DoctorRegistrationScreen extends ConsumerStatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  ConsumerState<DoctorRegistrationScreen> createState() =>
      _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState
    extends ConsumerState<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  
  // Branding fields
  final _primaryColorController = TextEditingController(text: '#2196F3');
  final _secondaryColorController = TextEditingController(text: '#64B5F6');
  final _accentColorController = TextEditingController(text: '#FFC107');
  String _selectedFont = 'Roboto';
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _clinicNameController.dispose();
    _specialtyController.dispose();
    _licenseNumberController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _accentColorController.dispose();
    super.dispose();
  }

  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final tenantService = ref.read(tenantServiceProvider);

      // Step 1: Register the doctor user
      final user = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Small delay to ensure user is created
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Create tenant (clinic) with branding
      final tenant = await tenantService.createTenant(
        name: _clinicNameController.text.trim(),
        branding: {
          'primaryColor': _primaryColorController.text.trim(),
          'secondaryColor': _secondaryColorController.text.trim(),
          'accentColor': _accentColorController.text.trim(),
          'fontFamily': _selectedFont,
        },
      );

      if (tenant == null) {
        throw Exception('Failed to create clinic');
      }

      // Step 3: Create doctor profile
      await tenantService.createDoctorProfile(
        userId: user.id,
        tenantId: tenant.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        specialty: _specialtyController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
        email: _emailController.text.trim(),
      );

      // Step 4: Set user role as admin for their clinic
      await authService.setUserRole(
        userId: user.id,
        tenantId: tenant.id,
        role: 'admin',
      );

      // Step 5: Set selected tenant
      ref.read(selectedTenantProvider.notifier).setTenant(tenant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Redirecting to dashboard...'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        // Use Navigator to avoid GoRouter assertion error
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.doctorDashboardRoute,
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Your Clinic',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up your medical practice and customize your branding',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Personal Information Section
                  Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (!value!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (value!.length < 6) return 'Min 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _specialtyController,
                    decoration: const InputDecoration(
                      labelText: 'Specialty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _licenseNumberController,
                    decoration: const InputDecoration(
                      labelText: 'License Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Clinic Information Section
                  Text(
                    'Clinic Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _clinicNameController,
                    decoration: const InputDecoration(
                      labelText: 'Clinic Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 32),

                  // Branding Section
                  Text(
                    'Clinic Branding',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customize the look of your clinic app',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _primaryColorController,
                    decoration: const InputDecoration(
                      labelText: 'Primary Color (Hex)',
                      border: OutlineInputBorder(),
                      hintText: '#2196F3',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _secondaryColorController,
                    decoration: const InputDecoration(
                      labelText: 'Secondary Color (Hex)',
                      border: OutlineInputBorder(),
                      hintText: '#64B5F6',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _accentColorController,
                    decoration: const InputDecoration(
                      labelText: 'Accent Color (Hex)',
                      border: OutlineInputBorder(),
                      hintText: '#FFC107',
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedFont,
                    decoration: const InputDecoration(
                      labelText: 'Font Family',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                      DropdownMenuItem(value: 'Lato', child: Text('Lato')),
                      DropdownMenuItem(value: 'OpenSans', child: Text('Open Sans')),
                      DropdownMenuItem(value: 'Montserrat', child: Text('Montserrat')),
                      DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFont = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 32),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerDoctor,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Clinic & Register'),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
