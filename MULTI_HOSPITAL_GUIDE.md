# Multi-Hospital Doctor Support Guide

## Overview
Your DoctorApp now supports **two critical features**:
1. ✅ **Multiple doctors per hospital** - One hospital can have many doctors
2. ✅ **Doctors working at multiple hospitals** - One doctor can work at multiple hospitals

## Architecture

### How It Works

#### Database Structure
```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   auth.users    │         │user_tenant_roles │         │    tenants      │
│  (Supabase)     │────────▶│  (Permissions)   │◀────────│  (Hospitals)    │
└─────────────────┘         └──────────────────┘         └─────────────────┘
        │                            │
        │                            │
        ▼                            ▼
┌─────────────────┐         ┌──────────────────┐
│    doctors      │         │    patients      │
│ (Doctor Profiles)│        │                  │
└─────────────────┘         └──────────────────┘
```

#### Key Tables

**1. `user_tenant_roles` - Access Control**
- Links users to hospitals (tenants) with roles
- One user can have multiple entries (multiple hospitals)
- Role can be: 'doctor', 'admin', or 'patient'

**2. `doctors` - Doctor Profiles**
- Stores doctor information per hospital
- One user_id can have multiple doctor records (one per hospital)
- Each record can have different specialty/details per hospital

**3. `tenants` - Hospitals**
- Each tenant represents a hospital/clinic
- Stores hospital name, logo, branding

## Setup Instructions

### Step 1: Run Database Migration

Execute the SQL migration to allow multi-hospital support:

```bash
# Copy the file: supabase_multi_hospital_doctors.sql
# Run in Supabase SQL Editor
```

**What this does:**
- Removes UNIQUE constraint on (tenant_id, user_id) in doctors table
- Adds `is_primary` flag to mark default hospital
- Adds `display_name` for hospital-specific names
- Creates performance indexes

### Step 2: Update Existing Code

The following files have been created/updated:

**New Files:**
1. `/lib/shared/widgets/hospital_selector.dart` - Hospital switcher UI
2. `supabase_multi_hospital_doctors.sql` - Database migration

**Updated Files:**
1. `/lib/app/doctor/doctor_dashboard.dart` - Shows current hospital in app bar

### Step 3: Understanding the Flow

#### For Doctors Working at Multiple Hospitals

**Registration Flow:**
1. Doctor signs up with email/password
2. Creates first hospital → Creates tenant + doctor profile
3. Gets invited to second hospital → Creates another doctor profile

**Login Flow:**
1. Doctor logs in
2. App fetches all hospitals via `user_tenant_roles`
3. Hospital selector shows all available hospitals
4. Doctor selects which hospital context to work in
5. All data (patients, appointments, etc.) filtered by selected hospital

#### For Hospitals with Multiple Doctors

**Adding Doctors:**
```dart
// Hospital admin invites doctor
final tenantService = ref.read(tenantServiceProvider);
await tenantService.createDoctorProfile(
  userId: doctorUserId,
  tenantId: hospitalId,
  firstName: 'John',
  lastName: 'Doe',
  specialty: 'Cardiology',
);

// Also create user_tenant_role entry
final authService = ref.read(authServiceProvider);
await authService.setUserRole(
  userId: doctorUserId,
  tenantId: hospitalId,
  role: 'doctor',
);
```

**Viewing Doctors:**
```dart
// Get all doctors in a hospital
final doctors = await client
  .from('doctors')
  .select('*')
  .eq('tenant_id', hospitalId);
```

## Using the Hospital Selector

### Option 1: Hospital Chip (Compact)
```dart
// In app bar
AppBar(
  title: Text('Dashboard'),
  actions: [
    HospitalChip(), // Shows current hospital, tappable to switch
  ],
)
```

### Option 2: Full Selector (Dropdown)
```dart
// In drawer or settings
HospitalSelectorWidget()
```

### Accessing Current Hospital
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentHospital = ref.watch(currentHospitalProvider);
    
    if (currentHospital == null) {
      return Text('Please select a hospital');
    }
    
    return Text('Working at: ${currentHospital.name}');
  }
}
```

### Filtering Data by Hospital
```dart
// Patients filtered by current hospital
final patientsProvider = StreamProvider<List<PatientInfo>>((ref) async* {
  final currentHospital = ref.watch(currentHospitalProvider);
  if (currentHospital == null) {
    yield [];
    return;
  }
  
  yield* SupabaseConfig.client
    .from('patients')
    .stream(primaryKey: ['id'])
    .eq('tenant_id', currentHospital.id)
    .map((data) => data.map((json) => PatientInfo.fromJson(json)).toList());
});
```

## Example Scenarios

### Scenario 1: Dr. Smith Works at 2 Hospitals

**Database State:**
```sql
-- auth.users table
user_id: abc-123
email: dr.smith@email.com

-- user_tenant_roles table
Row 1: user_id=abc-123, tenant_id=hospital-A, role=doctor
Row 2: user_id=abc-123, tenant_id=hospital-B, role=doctor

-- doctors table
Row 1: user_id=abc-123, tenant_id=hospital-A, specialty=Cardiology
Row 2: user_id=abc-123, tenant_id=hospital-B, specialty=General Medicine

-- tenants table
Row 1: id=hospital-A, name=City General Hospital
Row 2: id=hospital-B, name=Downtown Clinic
```

**App Behavior:**
1. Dr. Smith logs in
2. Hospital selector shows: "City General Hospital" and "Downtown Clinic"
3. Selects "City General Hospital"
4. Sees only patients from City General Hospital
5. Switches to "Downtown Clinic"
6. Sees only patients from Downtown Clinic

### Scenario 2: City Hospital Has 3 Doctors

**Database State:**
```sql
-- tenants table
id=hospital-A, name=City Hospital

-- user_tenant_roles table
Row 1: user_id=doc1, tenant_id=hospital-A, role=doctor
Row 2: user_id=doc2, tenant_id=hospital-A, role=doctor
Row 3: user_id=doc3, tenant_id=hospital-A, role=doctor

-- doctors table
Row 1: user_id=doc1, tenant_id=hospital-A, first_name=John, specialty=Cardiology
Row 2: user_id=doc2, tenant_id=hospital-A, first_name=Jane, specialty=Neurology
Row 3: user_id=doc3, tenant_id=hospital-A, first_name=Bob, specialty=Pediatrics
```

**App Behavior:**
- Each doctor logs in independently
- Each sees the same hospital name "City Hospital"
- Each has access to hospital's patient list
- Appointments can be created for any doctor
- Medical records track which doctor performed the visit

## Important Queries

### Get all hospitals for a doctor
```sql
SELECT d.*, t.name as hospital_name, t.logo
FROM doctors d
JOIN tenants t ON d.tenant_id = t.id
WHERE d.user_id = '<doctor_user_id>';
```

### Get all doctors in a hospital
```sql
SELECT d.*, u.email
FROM doctors d
JOIN auth.users u ON d.user_id = u.id
WHERE d.tenant_id = '<hospital_tenant_id>';
```

### Check if user is doctor at specific hospital
```sql
SELECT *
FROM user_tenant_roles
WHERE user_id = '<user_id>'
  AND tenant_id = '<tenant_id>'
  AND role = 'doctor';
```

### Get patient count per doctor in a hospital
```sql
SELECT 
  d.first_name || ' ' || d.last_name as doctor_name,
  COUNT(DISTINCT a.patient_id) as patient_count
FROM doctors d
LEFT JOIN appointments a ON d.id = a.doctor_id
WHERE d.tenant_id = '<hospital_id>'
GROUP BY d.id, d.first_name, d.last_name;
```

## Best Practices

### 1. Always Filter by Current Hospital
```dart
// ✅ GOOD
final patients = await client
  .from('patients')
  .select()
  .eq('tenant_id', currentHospital.id);

// ❌ BAD - Shows patients from all hospitals
final patients = await client
  .from('patients')
  .select();
```

### 2. Auto-select Hospital for Single-Hospital Doctors
```dart
// The HospitalChip widget already does this automatically
final hospitals = await fetchDoctorHospitals();
if (hospitals.length == 1) {
  ref.read(currentHospitalProvider.notifier).state = hospitals.first;
}
```

### 3. Handle Hospital Context Loss
```dart
// Always check if hospital is selected
Widget build(BuildContext context, WidgetRef ref) {
  final hospital = ref.watch(currentHospitalProvider);
  
  if (hospital == null) {
    return Center(
      child: Column(
        children: [
          Text('Please select a hospital'),
          HospitalSelectorWidget(),
        ],
      ),
    );
  }
  
  // Continue with hospital-specific logic
}
```

### 4. Mark Primary Hospital
```dart
// When creating first doctor profile, mark as primary
await client.from('doctors').insert({
  'user_id': userId,
  'tenant_id': tenantId,
  'is_primary': true, // ← Primary hospital
  // ... other fields
});
```

## UI Components Summary

### HospitalChip
- **Use in:** App bars, headers
- **Shows:** Current hospital name
- **Action:** Tap to open hospital switcher
- **Auto-hides:** If only one hospital

### HospitalSelectorWidget
- **Use in:** Settings, drawer menus
- **Shows:** Dropdown menu with all hospitals
- **Action:** Select to switch context
- **Displays:** Hospital name and ID

### currentHospitalProvider
- **Type:** StateProvider<Tenant?>
- **Purpose:** Tracks currently selected hospital
- **Usage:** `ref.watch(currentHospitalProvider)`

### doctorHospitalsProvider
- **Type:** FutureProvider<List<Tenant>>
- **Purpose:** Fetches all hospitals for current doctor
- **Usage:** `ref.watch(doctorHospitalsProvider)`

## Testing Checklist

- [ ] Run `supabase_multi_hospital_doctors.sql` migration
- [ ] Create test hospital A and B
- [ ] Create test doctor user
- [ ] Add doctor to both hospitals (create 2 doctor profiles)
- [ ] Login as doctor
- [ ] Verify hospital selector shows both hospitals
- [ ] Switch between hospitals
- [ ] Verify patient lists are different per hospital
- [ ] Create appointment in hospital A
- [ ] Switch to hospital B, verify appointment not visible
- [ ] Switch back to hospital A, verify appointment visible
- [ ] Test with single-hospital doctor (selector should auto-select)

## Migration Path for Existing Data

If you already have doctors in the system:

```sql
-- Step 1: Check current doctors
SELECT d.*, u.email, t.name as hospital
FROM doctors d
JOIN auth.users u ON d.user_id = u.id
JOIN tenants t ON d.tenant_id = t.id;

-- Step 2: Mark existing doctors as primary at their current hospital
UPDATE doctors
SET is_primary = true;

-- Step 3: If a doctor needs to be added to another hospital
INSERT INTO doctors (user_id, tenant_id, first_name, last_name, specialty)
VALUES ('<existing_user_id>', '<new_tenant_id>', 'First', 'Last', 'Specialty');

INSERT INTO user_tenant_roles (user_id, tenant_id, role)
VALUES ('<existing_user_id>', '<new_tenant_id>', 'doctor');
```

## Troubleshooting

### Issue: Hospital selector doesn't show
**Solution:** Check that `user_tenant_roles` has entries for the doctor

### Issue: Can't create second doctor profile
**Solution:** Ensure migration removed UNIQUE constraint

### Issue: Wrong patients showing
**Solution:** Verify all queries filter by `currentHospital.id`

### Issue: Hospital selection not persisting
**Solution:** StateProvider is session-based; implement persistence if needed

## Future Enhancements

Consider implementing:
- [ ] Persistent hospital selection (SharedPreferences)
- [ ] Hospital-specific themes/branding
- [ ] Cross-hospital patient transfers
- [ ] Aggregated statistics across all hospitals
- [ ] Hospital-specific working hours for doctors
- [ ] Automatic hospital detection based on location
- [ ] Hospital-specific permissions (e.g., admin at one, doctor at another)
