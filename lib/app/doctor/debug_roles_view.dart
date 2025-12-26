import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/role_service.dart';
import '../../core/supabase/supabase_config.dart';
import '../../shared/widgets/hospital_selector.dart';

class DebugRolesView extends ConsumerWidget {
  const DebugRolesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentUserId = authService.currentUserId;
    final currentHospital = ref.watch(currentHospitalProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Roles & Permissions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current User Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current User',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('User ID: ${currentUserId ?? "Not logged in"}'),
                  Text('Hospital ID: ${currentHospital?.id ?? "No hospital selected"}'),
                  Text('Hospital Name: ${currentHospital?.name ?? "N/A"}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Admin Check
          if (currentUserId != null && currentHospital != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<bool>(
                      future: ref.read(roleServiceProvider).isUserAdmin(
                        userId: currentUserId,
                        tenantId: currentHospital.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        final isAdmin = snapshot.data ?? false;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isAdmin ? Icons.check_circle : Icons.cancel,
                                  color: isAdmin ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAdmin ? 'You are an ADMIN' : 'You are NOT an admin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Role from DB
          if (currentUserId != null && currentHospital != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Role from Database',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String?>(
                      future: ref.read(roleServiceProvider).getUserRole(
                        userId: currentUserId,
                        tenantId: currentHospital.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        final role = snapshot.data;
                        return Text(
                          'Role: ${role ?? "NOT FOUND"}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: role == 'admin' ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // All Roles for Current User
          if (currentUserId != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Your Roles',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: SupabaseConfig.client
                          .from('user_tenant_roles')
                          .select('*, tenants(name)')
                          .eq('user_id', currentUserId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        final roles = snapshot.data ?? [];
                        if (roles.isEmpty) {
                          return const Text('No roles found in database!');
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: roles.map((role) {
                            final tenantName = role['tenants']?['name'] ?? 'Unknown';
                            final roleName = role['role'];
                            final tenantId = role['tenant_id'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    roleName == 'admin' 
                                        ? Icons.admin_panel_settings 
                                        : Icons.person,
                                    color: roleName == 'admin' 
                                        ? Colors.green 
                                        : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$tenantName',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Role: $roleName | ID: $tenantId',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Instructions
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected Behavior:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• First doctor who creates a clinic = admin'),
                  Text('• Doctors who join via invite code = doctor (not admin)'),
                  Text('• Only admins should see invite codes and suspend buttons'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
