import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/tenant/tenant_service.dart';
import '../../core/patient/patient_service.dart';
import '../../core/supabase/supabase_config.dart';
import '../../shared/utils/router.dart';
import 'appointments_view.dart';
import 'patient_bills_view.dart';
import 'patient_prescriptions_view.dart';

class PatientDashboard extends ConsumerStatefulWidget {
  const PatientDashboard({super.key});

  @override
  ConsumerState<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends ConsumerState<PatientDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PatientHomeView(),
    const AppointmentsView(),
    const PatientProfileView(),
  ];
  
  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(selectedTenantProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant?.name ?? 'Patient App'),
        automaticallyImplyLeading: false,
        actions: [
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
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

class PatientHomeView extends ConsumerWidget {
  const PatientHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(selectedTenantProvider);

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
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tenant?.name ?? '',
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
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book an Appointment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find and book appointments with healthcare providers',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Switch to booking tab
                          final dashboardState = context.findAncestorStateOfType<_PatientDashboardState>();
                          if (dashboardState != null) {
                            dashboardState._changeTab(1);
                          }
                        },
                        child: const Text('Book Now'),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_month, size: 64),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.receipt_long,
                label: 'My Bills',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PatientBillsView(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.medication,
                label: 'Prescriptions',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PatientPrescriptionsView(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history,
                label: 'Medical History',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.science,
                label: 'Lab Results',
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Upcoming Appointments',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _UpcomingAppointmentsWidget(),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String doctorName;
  final String specialty;
  final String date;
  final String time;

  const _AppointmentCard({
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.medical_services),
        ),
        title: Text(
          doctorName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$specialty • $date at $time'),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {},
        ),
      ),
    );
  }
}

class PatientAppointmentsView extends StatelessWidget {
  const PatientAppointmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Your Appointments', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('View and manage your appointments', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class PatientRecordsView extends StatelessWidget {
  const PatientRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Medical Records', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Access your medical records and documents', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class PatientProfileView extends ConsumerWidget {
  const PatientProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(currentPatientProfileProvider);

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading profile: $error'),
          ],
        ),
      ),
      data: (patient) {
        if (patient == null) {
          return const Center(
            child: Text('No patient profile found'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                      patient.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient ID: ${patient.id.substring(0, 8)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (patient.email != null)
                      _buildInfoRow(Icons.email, 'Email', patient.email!),
                    if (patient.phone != null)
                      _buildInfoRow(Icons.phone, 'Phone', patient.phone!),
                    if (patient.dateOfBirth != null)
                      _buildInfoRow(
                        Icons.cake,
                        'Date of Birth',
                        '${patient.dateOfBirth!.day}/${patient.dateOfBirth!.month}/${patient.dateOfBirth!.year}',
                      ),
                    if (patient.gender != null)
                      _buildInfoRow(
                          Icons.person_outline, 'Gender', patient.gender!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.medical_information),
                    title: const Text('Medical History'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
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
                    title: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();

                      // Clear the selected tenant
                      ref.read(selectedTenantProvider.notifier).clearTenant();

                      // Navigate back to login
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushReplacementNamed(AppRouter.loginRoute);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingAppointmentsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(currentPatientProfileProvider);

    return patientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(child: Text('Error loading appointments')),
      data: (patient) {
        if (patient == null) {
          return const Text('No patient profile found');
        }

        final appointmentsStream = SupabaseConfig.client
            .from('appointments')
            .stream(primaryKey: ['id'])
            .order('appointment_date')
            .asyncMap((rows) async {
              // Filter to patient's scheduled appointments
              final filtered = rows.where((apt) {
                try {
                  if (apt['patient_id'] != patient.id) return false;
                  if (apt['status'] != 'scheduled') return false;
                  final aptDate = DateTime.parse(apt['appointment_date']);
                  return aptDate.isAfter(DateTime.now());
                } catch (e) {
                  return false;
                }
              }).toList();
              // Take only first 3
              return filtered.take(3).toList();
            });

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: appointmentsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final appointments = snapshot.data ?? [];

            if (appointments.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.event_note, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        'No upcoming appointments',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          // Switch to booking tab
                          final dashboardContext = context.findAncestorStateOfType<_PatientDashboardState>();
                          if (dashboardContext != null) {
                            dashboardContext._changeTab(1);
                          }
                        },
                        child: const Text('Book Now'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: appointments.map((apt) {
                final date = DateTime.parse(apt['appointment_date']);
                final time = apt['appointment_time'] ?? '';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AppointmentCard(
                    doctorName: apt['doctor_name'] ?? 'Doctor',
                    specialty: apt['specialty'] ?? 'General',
                    date: '${date.day}/${date.month}/${date.year}',
                    time: time,
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
