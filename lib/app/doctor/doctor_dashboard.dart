import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/tenant/tenant_service.dart';
import '../../core/dashboard/dashboard_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/patient/patient_service.dart';
import '../../core/supabase/supabase_config.dart';
import 'patient_detail_screen.dart';
import '../../shared/widgets/share_clinic_dialog.dart';
import '../../shared/widgets/hospital_selector.dart';
import 'team_management_view.dart';
import 'debug_roles_view.dart';

class DoctorDashboard extends ConsumerStatefulWidget {
  const DoctorDashboard({super.key});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DoctorHomeView(),
    const DoctorPatientsView(),
    const DoctorAppointmentsView(),
    const TeamManagementView(),
    const DoctorProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentHospital = ref.watch(currentHospitalProvider);
    final hospitalsAsync = ref.watch(doctorHospitalsProvider);

    // Auto-select first hospital if none selected
    hospitalsAsync.whenData((hospitals) {
      if (hospitals.isNotEmpty && currentHospital == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(currentHospitalProvider.notifier).state = hospitals.first;
        });
      }
    });

    final displayName = currentHospital?.name ?? 'Doctor App';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Doctor App', style: TextStyle(fontSize: 16)),
            Text(
              displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          const HospitalChip(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Clinic',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ShareClinicDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Home View
// ============================================================================

class DoctorHomeView extends ConsumerWidget {
  const DoctorHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(selectedTenantProvider);
    final doctorProfileAsync = ref.watch(doctorProfileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final appointmentsAsync = ref.watch(upcomingAppointmentsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: tenant?.logo != null 
                          ? NetworkImage(tenant!.logo!) 
                          : null,
                      child: tenant?.logo == null 
                          ? const Icon(Icons.person, size: 32) 
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          doctorProfileAsync.when(
                            loading: () => Text(
                              'Welcome, Doctor',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            error: (_, __) => Text(
                              'Welcome, Doctor',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            data: (profile) => Text(
                              profile?.firstName.isNotEmpty == true
                                  ? 'Welcome, ${profile!.firstName}'
                                  : 'Welcome, Doctor',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tenant?.name ?? 'Clinic',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
        statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error: $error'),
          data: (stats) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Patients',
                      value: stats.totalPatients.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Today\'s Appointments',
                      value: stats.appointmentsToday.toString(),
                      icon: Icons.calendar_today,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Appointments',
                      value: stats.totalAppointments.toString(),
                      icon: Icons.event_note,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending',
                      value: '3',
                      icon: Icons.pending_actions,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Upcoming Appointments',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        appointmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error loading appointments: $error'),
          data: (appointments) {
            if (appointments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No upcoming appointments'),
                ),
              );
            }
            return Column(
              children: appointments
                  .map((appointment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _AppointmentCard(
                          patientName: appointment.patientName,
                          time: appointment.appointmentTime,
                          type: appointment.type,
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String patientName;
  final String time;
  final String type;

  const _AppointmentCard({
    required this.patientName,
    required this.time,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$type • $time'),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {},
        ),
      ),
    );
  }
}

class DoctorPatientsView extends ConsumerWidget {
  const DoctorPatientsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsListProvider);

    return Scaffold(
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading patients: $error'),
            ],
          ),
        ),
        data: (patients) {
          if (patients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No Patients Yet', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Add your first patient to get started', 
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/addPatient');
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Patient'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Patients: ${patients.length}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/addPatient');
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Patient'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...patients.map((patient) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          patient.firstName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        patient.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (patient.email != null)
                            Text('📧 ${patient.email}'),
                          if (patient.phone != null)
                            Text('📞 ${patient.phone}'),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PatientDetailScreen(patient: patient),
                          ),
                        );
                      },
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class DoctorAppointmentsView extends ConsumerWidget {
  const DoctorAppointmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(doctorProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Profile not found'));
        }

        final slotsStream = SupabaseConfig.client
            .from('appointments')
            .stream(primaryKey: ['id'])
            .eq('doctor_id', profile.id)
            .order('appointment_date');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appointment Slots',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/createSlots');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Slots'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Create time slots for patients to book appointments',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: slotsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_available,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No slots created yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create time slots for patients to book',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/createSlots');
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Create Your First Slot'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Group slots by date
                final groupedSlots = <String, List<Map<String, dynamic>>>{};
                for (var row in rows) {
                  final date = DateTime.parse(row['appointment_date']).toLocal();
                  final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  groupedSlots.putIfAbsent(dateKey, () => []);
                  groupedSlots[dateKey]!.add(row);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildLegendItem(Colors.green, 'Available', rows.where((r) => r['status'] == 'available').length),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.blue, 'Booked', rows.where((r) => r['status'] == 'scheduled').length),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...groupedSlots.entries.map((entry) {
                      final slots = entry.value;
                      final date = DateTime.parse(slots.first['appointment_date']).toLocal();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)} ${date.year}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: slots.map((row) {
                              final status = row['status'] ?? 'available';
                              final start = DateTime.parse(row['appointment_date']).toLocal();
                              final isAvailable = status == 'available';
                              
                              return InkWell(
                                onLongPress: isAvailable
                                    ? () => _showDeleteSlotDialog(context, row['id'], start)
                                    : null,
                                child: Chip(
                                  backgroundColor: isAvailable ? Colors.green.shade50 : Colors.blue.shade50,
                                  side: BorderSide(
                                    color: isAvailable ? Colors.green : Colors.blue,
                                  ),
                                  label: Text(
                                    '${TimeOfDay.fromDateTime(start).format(context)} (${row['duration_minutes']}m)',
                                    style: TextStyle(
                                      color: isAvailable ? Colors.green.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                  avatar: Icon(
                                    isAvailable ? Icons.event_available : Icons.event_busy,
                                    size: 18,
                                    color: isAvailable ? Colors.green : Colors.blue,
                                  ),
                                  deleteIcon: isAvailable ? const Icon(Icons.close, size: 18) : null,
                                  onDeleted: isAvailable
                                      ? () => _deleteSlot(context, row['id'])
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Future<void> _deleteSlot(BuildContext context, String slotId) async {
    try {
      await SupabaseConfig.client
          .from('appointments')
          .delete()
          .eq('id', slotId)
          .eq('status', 'available'); // Extra safety: only delete if still available

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete slot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteSlotDialog(BuildContext context, String slotId, DateTime time) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Slot'),
          content: Text(
            'Are you sure you want to delete the slot at ${TimeOfDay.fromDateTime(time).format(context)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteSlot(context, slotId);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class DoctorProfileView extends ConsumerWidget {
  const DoctorProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(doctorProfileProvider);
    final currentHospital = ref.watch(currentHospitalProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        profileAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading profile: $error'),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Profile not found'),
                ),
              );
            }
            
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      child: Icon(Icons.person, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.fullName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.specialty,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (profile.licenseNumber.isNotEmpty)
                      Text(
                        'License: ${profile.licenseNumber}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clinic Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Clinic Name'),
                  subtitle: Text(currentHospital?.name ?? 'N/A'),
                ),
                if (currentHospital?.branding != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Primary Color'),
                    subtitle: Text(currentHospital!.branding!.primaryColor ?? 'Default'),
                  ),
                  if (currentHospital.branding!.fontFamily != null) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.font_download),
                      title: const Text('Font Family'),
                      subtitle: Text(currentHospital.branding!.fontFamily!),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.orange),
                title: const Text('Debug: Roles & Permissions', style: TextStyle(color: Colors.orange)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DebugRolesView(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                  
                  // Clear both providers
                  ref.read(selectedTenantProvider.notifier).clearTenant();
                  ref.read(currentHospitalProvider.notifier).state = null;
                  
                  // Navigate back to login
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('login');
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
