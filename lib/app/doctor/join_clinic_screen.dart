import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/invite/doctor_invite_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/supabase/supabase_config.dart';
import '../../shared/widgets/hospital_selector.dart';

class JoinClinicScreen extends ConsumerStatefulWidget {
  const JoinClinicScreen({super.key});

  @override
  ConsumerState<JoinClinicScreen> createState() => _JoinClinicScreenState();
}

class _JoinClinicScreenState extends ConsumerState<JoinClinicScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  String? _validatedClinicName;
  bool _isValidating = false;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateInviteCode() async {
    if (_inviteCodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an invite code';
        _validatedClinicName = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _validatedClinicName = null;
    });

    try {
      final inviteService = ref.read(doctorInviteServiceProvider);
      final validation = await inviteService.validateInviteCode(
        _inviteCodeController.text.trim(),
      );

      setState(() {
        if (validation.isValid && validation.tenantName != null) {
          _validatedClinicName = validation.tenantName;
          _errorMessage = null;
        } else {
          _errorMessage = validation.errorMessage ?? 'Invalid invite code';
          _validatedClinicName = null;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _validatedClinicName = null;
      });
    } finally {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _joinClinic() async {
    if (!_formKey.currentState!.validate() || _validatedClinicName == null) {
      setState(() => _errorMessage = 'Please validate the invite code first');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final inviteService = ref.read(doctorInviteServiceProvider);
      final validation = await inviteService.validateInviteCode(
        _inviteCodeController.text.trim(),
      );

      if (!validation.isValid || validation.tenantId == null) {
        throw Exception(validation.errorMessage ?? 'Invalid invite code');
      }

      final tenantId = validation.tenantId!;

      // Check if doctor already exists in this clinic
      final existingDoctor = await SupabaseConfig.client
          .from('doctors')
          .select('id')
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (existingDoctor != null) {
        throw Exception('You are already registered in this clinic');
      }

      // Get current doctor's profile from any existing clinic to copy details
      final currentDoctorProfile = await ref.read(doctorProfileProvider.future);
      
      if (currentDoctorProfile == null) {
        throw Exception('Could not find your doctor profile');
      }

      // Create doctor profile in the new clinic
      final doctorResponse = await SupabaseConfig.client
          .from('doctors')
          .insert({
            'user_id': userId,
            'tenant_id': tenantId,
            'first_name': currentDoctorProfile.firstName,
            'last_name': currentDoctorProfile.lastName,
            'specialty': currentDoctorProfile.specialty,
            'license_number': currentDoctorProfile.licenseNumber,
            'phone': currentDoctorProfile.phone,
            'email': currentDoctorProfile.email,
          })
          .select()
          .single();

      // Set user role as doctor (not admin) in the new clinic
      await authService.setUserRole(
        userId: userId,
        tenantId: tenantId,
        role: 'doctor',
      );

      // Record invite code usage
      await inviteService.useInviteCode(
        code: _inviteCodeController.text.trim(),
        userId: userId,
        doctorId: doctorResponse['id'],
      );

      // Refresh the hospitals list
      ref.invalidate(doctorHospitalsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined $_validatedClinicName!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Another Clinic'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Join Additional Clinic',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter an invite code provided by the clinic admin to join their clinic. '
                      'You will be able to work at multiple clinics and switch between them.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _inviteCodeController,
              decoration: InputDecoration(
                labelText: 'Invite Code',
                border: const OutlineInputBorder(),
                hintText: 'DR-XXXXXXXX',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: _isValidating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: _validateInviteCode,
                        tooltip: 'Validate Code',
                      ),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter invite code' : null,
              onChanged: (value) {
                if (_validatedClinicName != null) {
                  setState(() {
                    _validatedClinicName = null;
                    _errorMessage = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            if (_validatedClinicName != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valid Invite Code',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Clinic: $_validatedClinicName',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isJoining || _validatedClinicName == null
                  ? null
                  : _joinClinic,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isJoining
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Clinic'),
            ),
            const SizedBox(height: 16),
            
            OutlinedButton(
              onPressed: _isJoining ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
