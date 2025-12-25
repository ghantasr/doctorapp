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
    const DoctorProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(selectedTenantProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant?.name ?? 'Doctor App'),
        actions: [
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
          setState(() {
            _selectedIndex = index;
          });
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
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

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

    return patientsAsync.when(
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No Patients Yet', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text('Patients who register will appear here', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Total Patients: ${patients.length}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
    );
  }
}

class DoctorAppointmentsView extends ConsumerStatefulWidget {
  const DoctorAppointmentsView({super.key});

  @override
  ConsumerState<DoctorAppointmentsView> createState() => _DoctorAppointmentsViewState();
}

class _DoctorAppointmentsViewState extends ConsumerState<DoctorAppointmentsView> {
  DateTime? _slotStart;
  int _duration = 30;
  bool _saving = false;

  Future<void> _pickSlot(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _slotStart = combined.toUtc());
  }

  Future<void> _saveSlot(DoctorProfile profile) async {
    if (_slotStart == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseConfig.client.from('appointments').insert({
        'tenant_id': profile.tenantId,
        'doctor_id': profile.id,
        'patient_id': null,
        'appointment_date': _slotStart!.toIso8601String(),
        'duration_minutes': _duration,
        'status': 'available',
      });
      setState(() => _slotStart = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save slot: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Add Available Slot', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _slotStart == null
                          ? 'Pick start time'
                          : 'Starts: ${_slotStart!.toLocal()}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _pickSlot(context),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<int>(
                    value: _duration,
                    decoration: const InputDecoration(labelText: 'Minutes', border: OutlineInputBorder()),
                    items: const [15, 30, 45, 60]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                        .toList(),
                    onChanged: (v) => setState(() => _duration = v ?? 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _slotStart == null || _saving ? null : () => _saveSlot(profile),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Slot'),
            ),
            const SizedBox(height: 24),
            Text('Your Slots', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
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
                  return const Text('No slots yet');
                }
                return Column(
                  children: rows.map((row) {
                    final status = row['status'] ?? 'available';
                    final start = DateTime.parse(row['appointment_date']).toLocal();
                    final patientId = row['patient_id'] as String?;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          status == 'available' ? Icons.event_available : Icons.event,
                          color: status == 'available' ? Colors.green : Colors.blue,
                        ),
                        title: Text('${start.toString()} • ${row['duration_minutes']} min'),
                        subtitle: Text(
                          patientId == null ? 'Available' : 'Booked by patient $patientId',
                        ),
                        trailing: Text(status),
                      ),
                    );
                  }).toList(),
                );
              },
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
    final tenant = ref.watch(selectedTenantProvider);

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
                  subtitle: Text(tenant?.name ?? 'N/A'),
                ),
                if (tenant?.branding != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Primary Color'),
                    subtitle: Text(tenant!.branding!.primaryColor ?? 'Default'),
                  ),
                  if (tenant.branding!.fontFamily != null) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.font_download),
                      title: const Text('Font Family'),
                      subtitle: Text(tenant.branding!.fontFamily!),
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
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                  
                  // Clear the selected tenant
                  ref.read(selectedTenantProvider.notifier).clearTenant();
                  
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
