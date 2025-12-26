import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/invite/doctor_invite_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/role_service.dart';
import '../../shared/widgets/hospital_selector.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/supabase/supabase_config.dart';

/// Provider to get all doctors in a hospital (Stream for real-time updates)
final hospitalDoctorsProvider = StreamProvider.family<List<DoctorProfile>, String>(
  (ref, tenantId) {
    return SupabaseConfig.client
        .from('doctors')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .map((data) => (data as List)
            .map((json) => DoctorProfile.fromJson(json))
            .toList());
  },
);

class TeamManagementView extends ConsumerStatefulWidget {
  const TeamManagementView({super.key});

  @override
  ConsumerState<TeamManagementView> createState() => _TeamManagementViewState();
}

class _TeamManagementViewState extends ConsumerState<TeamManagementView> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final currentHospital = ref.watch(currentHospitalProvider);
    final isAdminAsync = ref.watch(isCurrentUserAdminProvider);
    
    if (currentHospital == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Please select a hospital first'),
            SizedBox(height: 24),
            HospitalSelectorWidget(),
          ],
        ),
      );
    }

    return isAdminAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildTeamManagementContent(context, currentHospital, isAdmin: false),
      data: (isAdmin) => _buildTeamManagementContent(context, currentHospital, isAdmin: isAdmin),
    );
  }

  Widget _buildTeamManagementContent(BuildContext context, dynamic currentHospital, {required bool isAdmin}) {
    final inviteCodesAsync = ref.watch(hospitalInviteCodesProvider(currentHospital.id));
    final doctorsAsync = ref.watch(hospitalDoctorsProvider(currentHospital.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(hospitalInviteCodesProvider(currentHospital.id));
        ref.invalidate(hospitalDoctorsProvider(currentHospital.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Team Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentHospital.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Doctors Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medical_services),
                      SizedBox(width: 8),
                      Text(
                        'Doctors',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  doctorsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('Error: $error'),
                    data: (doctors) {
                      if (doctors.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No doctors yet'),
                          ),
                        );
                      }
                      return Column(
                        children: doctors.map((doctor) {
                          final authService = ref.read(authServiceProvider);
                          final currentUserId = authService.currentUserId;
                          final isCurrentUser = doctor.userId == currentUserId;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: doctor.isSuspended 
                                  ? Colors.red.shade100 
                                  : Colors.blue.shade100,
                              child: Text(
                                doctor.firstName.isNotEmpty ? doctor.firstName[0] : 'D',
                                style: TextStyle(
                                  color: doctor.isSuspended ? Colors.red : Colors.blue,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text('${doctor.firstName} ${doctor.lastName}'),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  const Chip(
                                    label: Text('You', style: TextStyle(fontSize: 10)),
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doctor.specialty),
                                if (doctor.isSuspended)
                                  Text(
                                    'Suspended',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: (isCurrentUser || !isAdmin)
                                ? null
                                : PopupMenuButton<String>(
                                    itemBuilder: (context) => [
                                      if (!doctor.isSuspended)
                                        const PopupMenuItem(
                                          value: 'suspend',
                                          child: Row(
                                            children: [
                                              Icon(Icons.block, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Suspend'),
                                            ],
                                          ),
                                        ),
                                      if (doctor.isSuspended)
                                        const PopupMenuItem(
                                          value: 'activate',
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green),
                                              SizedBox(width: 8),
                                              Text('Activate'),
                                            ],
                                          ),
                                        ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'suspend') {
                                        _suspendDoctor(doctor, currentHospital.id);
                                      } else if (value == 'activate') {
                                        _activateDoctor(doctor, currentHospital.id);
                                      }
                                    },
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

          // Invite Codes Section (Admin only)
          if (isAdmin) Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Doctor Invite Codes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : () => _generateInviteCode(currentHospital.id),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Generate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  inviteCodesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('Error: $error'),
                    data: (inviteCodes) {
                      if (inviteCodes.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.qr_code_2, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'No invite codes yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Generate a code to invite doctors',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: inviteCodes.map((invite) {
                          return _InviteCodeCard(
                            inviteCode: invite,
                            onDeactivate: () => _deactivateCode(
                              invite.id,
                              currentHospital.id,
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
        ],
      ),
    );
  }

  Future<void> _generateInviteCode(String tenantId) async {
    setState(() => _isGenerating = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final inviteService = ref.read(doctorInviteServiceProvider);
      await inviteService.generateInviteCode(
        tenantId: tenantId,
        createdByUserId: userId,
        maxUses: 10, // Allow 10 doctors to use this code
        expiresIn: const Duration(days: 30), // Expires in 30 days
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite code generated successfully')),
        );
        ref.invalidate(hospitalInviteCodesProvider(tenantId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _suspendDoctor(DoctorProfile doctor, String tenantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Doctor'),
        content: Text(
          'Are you sure you want to suspend ${doctor.fullName}? '
          'They will not be able to access this hospital until reactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final roleService = ref.read(roleServiceProvider);
      await roleService.suspendDoctor(
        doctorId: doctor.id,
        suspendedBy: userId,
        tenantId: tenantId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doctor.fullName} has been suspended')),
        );
        ref.invalidate(hospitalDoctorsProvider(tenantId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _activateDoctor(DoctorProfile doctor, String tenantId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final roleService = ref.read(roleServiceProvider);
      await roleService.activateDoctor(
        doctorId: doctor.id,
        activatedBy: userId,
        tenantId: tenantId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doctor.fullName} has been activated'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(hospitalDoctorsProvider(tenantId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deactivateCode(String inviteCodeId, String tenantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Invite Code'),
        content: const Text('Are you sure you want to deactivate this invite code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final inviteService = ref.read(doctorInviteServiceProvider);
      await inviteService.deactivateInviteCode(inviteCodeId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite code deactivated')),
        );
        ref.invalidate(hospitalInviteCodesProvider(tenantId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _InviteCodeCard extends StatelessWidget {
  final DoctorInviteCode inviteCode;
  final VoidCallback onDeactivate;

  const _InviteCodeCard({
    required this.inviteCode,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = inviteCode.expiresAt != null &&
        inviteCode.expiresAt!.isBefore(DateTime.now());
    final isFull = inviteCode.currentUses >= inviteCode.maxUses;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: inviteCode.isValid
          ? null
          : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    inviteCode.code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard')),
                    );
                  },
                  tooltip: 'Copy code',
                ),
                if (inviteCode.isActive)
                  IconButton(
                    icon: const Icon(Icons.block, color: Colors.red),
                    onPressed: onDeactivate,
                    tooltip: 'Deactivate',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${inviteCode.remainingUses}/${inviteCode.maxUses} uses left',
                    style: const TextStyle(fontSize: 12),
                  ),
                  avatar: Icon(
                    Icons.person,
                    size: 16,
                    color: isFull ? Colors.red : Colors.blue,
                  ),
                  backgroundColor: isFull
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                ),
                if (inviteCode.expiresAt != null)
                  Chip(
                    label: Text(
                      isExpired
                          ? 'Expired'
                          : 'Expires ${_formatDate(inviteCode.expiresAt!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: isExpired ? Colors.red : Colors.orange,
                    ),
                    backgroundColor: isExpired
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                  ),
                Chip(
                  label: Text(
                    inviteCode.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(fontSize: 12),
                  ),
                  avatar: Icon(
                    inviteCode.isActive ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: inviteCode.isActive ? Colors.green : Colors.grey,
                  ),
                  backgroundColor: inviteCode.isActive
                      ? Colors.green.shade50
                      : Colors.grey.shade200,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.inDays > 0) {
      return 'in ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return 'in ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'in ${diff.inMinutes}m';
    } else {
      return 'soon';
    }
  }
}
