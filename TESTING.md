# Testing Guide

## Running Both Apps Simultaneously

### Quick Start
```bash
./run_both_apps.sh
```

This will launch:
- **Doctor App**: http://localhost:5001
- **Patient App**: http://localhost:5002

### Manual Start (Alternative)
```bash
# Terminal 1 - Doctor App
flutter run -d chrome --web-port=5001 --dart-define=FLAVOR=doctor lib/main_doctor.dart

# Terminal 2 - Patient App
flutter run -d chrome --web-port=5002 --dart-define=FLAVOR=patient lib/main_patient.dart
```

---

## Testing Patient Invitation Flow

### Step 1: Doctor Shares Clinic Code
1. Open doctor app at http://localhost:5001
2. Login with doctor credentials
3. Click the **Share** icon (top-right corner of dashboard)
4. Copy the 8-character clinic code from the dialog
5. Share this code with the patient

### Step 2: Patient Registers
1. Open patient app at http://localhost:5002
2. Click **"Register as Patient"** button
3. Fill in the registration form:
   - **Clinic Code**: Paste the code from Step 1
   - **First Name**: Patient's first name
   - **Last Name**: Patient's last name
   - **Phone**: Contact number
   - **Email**: Patient's email
   - **Password**: Create a secure password
4. Click **"Register"**
5. Patient is automatically assigned to the doctor's clinic

### Step 3: Verify Registration
- Patient should see their dashboard after registration
- Doctor can verify the new patient in the clinic's patient list (once implemented)
- Check Supabase dashboard → `patients` table → new record with matching `tenant_id`

---

## Testing Credentials

### Doctor Account
If you've already registered a doctor, use those credentials. Otherwise:
1. Go to http://localhost:5001
2. Click "Register as Doctor"
3. Complete doctor registration form
4. Login with created credentials

### Patient Account
Use the invitation flow above with the clinic code from your doctor account.

---

## Troubleshooting

### Port Already in Use
If you see "Port 5001 already in use":
```bash
# Kill processes on ports
lsof -ti:5001 | xargs kill -9
lsof -ti:5002 | xargs kill -9

# Then rerun
./run_both_apps.sh
```

### App Not Loading
- Ensure Flutter SDK is installed
- Check Chrome browser is available
- Run `flutter doctor` to verify setup

### Database Connection Errors
- Verify Supabase project is running
- Check `supabase_url` and `supabase_anon_key` in `SupabaseConfig`
- Ensure RLS is disabled (see `supabase_schema_clean.sql`)

### Clinic Code Not Found
- Make sure the tenants table has an `invite_code` column (run `supabase_invite_code.sql` in Supabase SQL editor)
- Try the code in uppercase (generated code is uppercase by default)

### FK error on patients.user_id (patients_user_id_fkey)
- Run `supabase_fix_patient_fk.sql` in Supabase SQL editor to point `patients.user_id` to `auth.users(id)`
- Retry patient registration

---

## Next Steps After Testing

Once patient invitation works:
1. **Appointment Slots**: Implement doctor slot creation UI
2. **Booking System**: Allow patients to book available slots
3. **Patient Management**: Doctor view to see all registered patients
4. **Phone Mapping**: Auto-link patients when phone number matches

---

## Database Verification

Check registration in Supabase:
```sql
-- View all patients with their clinic info
SELECT 
  p.first_name, 
  p.last_name, 
  p.email, 
  t.name as clinic_name,
  utr.role
FROM patients p
JOIN tenants t ON p.tenant_id = t.id
JOIN user_tenant_roles utr ON p.user_id = utr.user_id
ORDER BY p.created_at DESC;
```
