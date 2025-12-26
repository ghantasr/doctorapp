import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/tenant/tenant_service.dart';
import '../../core/tenant/tenant.dart';

/// Provider to track the currently selected hospital (tenant)
final currentHospitalProvider = StateProvider<Tenant?>((ref) => null);

/// Provider to fetch all hospitals where the current doctor works
final doctorHospitalsProvider = FutureProvider<List<Tenant>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  
  if (userId == null) return [];
  
  final tenantService = ref.watch(tenantServiceProvider);
  return await tenantService.fetchUserTenants(userId);
});

class HospitalSelectorWidget extends ConsumerWidget {
  const HospitalSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentHospital = ref.watch(currentHospitalProvider);
    final hospitalsAsync = ref.watch(doctorHospitalsProvider);

    return hospitalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hospitals) {
        if (hospitals.isEmpty) return const SizedBox.shrink();
        if (hospitals.length == 1 && currentHospital == null) {
          // Auto-select if only one hospital
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentHospitalProvider.notifier).state = hospitals.first;
          });
          return const SizedBox.shrink();
        }

        return PopupMenuButton<Tenant>(
          initialValue: currentHospital,
          tooltip: 'Switch Hospital',
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.local_hospital),
                  if (hospitals.length > 1)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${hospitals.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                currentHospital?.name ?? 'Select Hospital',
                style: const TextStyle(fontSize: 14),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          onSelected: (Tenant hospital) {
            ref.read(currentHospitalProvider.notifier).state = hospital;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to ${hospital.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          itemBuilder: (BuildContext context) {
            return hospitals.map((Tenant hospital) {
              final isSelected = currentHospital?.id == hospital.id;
              return PopupMenuItem<Tenant>(
                value: hospital,
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.local_hospital,
                      color: isSelected ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hospital.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (hospital.id.length > 8)
                            Text(
                              'ID: ${hospital.id.substring(0, 8)}...',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}

/// Compact hospital chip widget for app bars
class HospitalChip extends ConsumerWidget {
  const HospitalChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentHospital = ref.watch(currentHospitalProvider);
    final hospitalsAsync = ref.watch(doctorHospitalsProvider);

    return hospitalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hospitals) {
        if (hospitals.isEmpty) return const SizedBox.shrink();
        
        // Auto-select first hospital if none selected
        if (currentHospital == null && hospitals.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentHospitalProvider.notifier).state = hospitals.first;
          });
        }

        // Don't show switcher if only one hospital
        if (hospitals.length == 1) {
          return Chip(
            avatar: const Icon(Icons.local_hospital, size: 16),
            label: Text(
              currentHospital?.name ?? hospitals.first.name,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.blue.shade50,
          );
        }

        return ActionChip(
          avatar: const Icon(Icons.local_hospital, size: 16),
          label: Text(
            currentHospital?.name ?? 'Select Hospital',
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () {
            _showHospitalSwitcher(context, ref, hospitals, currentHospital);
          },
          backgroundColor: Colors.blue.shade100,
        );
      },
    );
  }

  void _showHospitalSwitcher(
    BuildContext context,
    WidgetRef ref,
    List<Tenant> hospitals,
    Tenant? currentHospital,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Switch Hospital',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...hospitals.map((hospital) {
              final isSelected = currentHospital?.id == hospital.id;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.local_hospital,
                  color: isSelected ? Colors.green : Colors.blue,
                ),
                title: Text(
                  hospital.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Chip(
                        label: Text('Active', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    : null,
                onTap: () {
                  ref.read(currentHospitalProvider.notifier).state = hospital;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${hospital.name}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
