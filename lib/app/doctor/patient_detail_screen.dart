import 'package:flutter/material.dart';
import '../../core/patient/patient_service.dart';

class PatientDetailScreen extends StatelessWidget {
  final PatientInfo patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold
    (
      appBar: AppBar(title: Text(patient.fullName),
          automaticallyImplyLeading: false,
),
      
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('ID: ${patient.id}'),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(patient.email ?? 'Not provided'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone'),
                  subtitle: Text(patient.phone ?? 'Not provided'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cake),
                  title: const Text('DOB'),
                  subtitle: Text(patient.dateOfBirth?.toIso8601String().split('T').first ?? 'Not provided'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people_alt),
                  title: const Text('Gender'),
                  subtitle: Text(patient.gender ?? 'Not provided'),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Medical Records'),
              subtitle: const Text('Coming soon'),
            ),
          ),
        ],
      ),
    );
  }
}
