import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/tenant/tenant.dart';
import '../../core/tenant/tenant_service.dart';
import '../../shared/utils/router.dart';
import '../../app/app_flavor.dart';

class TenantSelectionScreen extends ConsumerStatefulWidget {
  const TenantSelectionScreen({super.key});

  @override
  ConsumerState<TenantSelectionScreen> createState() => _TenantSelectionScreenState();
}

class _TenantSelectionScreenState extends ConsumerState<TenantSelectionScreen> {
  bool _isLoading = true;
  List<Tenant> _tenants = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final tenantService = ref.read(tenantServiceProvider);
      final tenants = await tenantService.fetchUserTenants(userId);

      print('✅ Successfully fetched ${tenants.length} tenants');

      setState(() {
        _tenants = tenants;
        _isLoading = false;
      });

      if (tenants.length == 1) {
        _selectTenant(tenants.first);
      }
    } catch (e) {
      print('❌ Error in tenant selection screen: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectTenant(Tenant tenant) {
    ref.read(selectedTenantProvider.notifier).setTenant(tenant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Organization'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadTenants,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _tenants.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.business_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No organizations found',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Get started by creating your clinic or joining an existing one',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 32),
                            
                            // Show different options based on flavor
                            if (AppFlavor.current.isDoctor) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.doctorRegisterRoute,
                                    );
                                  },
                                  icon: const Icon(Icons.add_business),
                                  label: const Text('Create New Clinic'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'or',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.doctorRegisterRoute,
                                    );
                                  },
                                  icon: const Icon(Icons.group_add),
                                  label: const Text('Join Existing Clinic'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Please contact your administrator to get access',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton(
                                onPressed: () async {
                                  final authService = ref.read(authServiceProvider);
                                  await authService.signOut();
                                  if (context.mounted) {
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.loginRoute,
                                      (route) => false,
                                    );
                                  }
                                },
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tenants.length,
                      itemBuilder: (context, index) {
                        final tenant = _tenants[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: tenant.logo != null
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(tenant.logo!),
                                  )
                                : const CircleAvatar(
                                    child: Icon(Icons.business),
                                  ),
                            title: Text(
                              tenant.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => _selectTenant(tenant),
                          ),
                        );
                      },
                    ),
    );
  }
}
