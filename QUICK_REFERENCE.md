# Quick Reference Guide - Healthcare SaaS

## 📋 Quick Links
- **Main Documentation**: [README.md](README.md)
- **Architecture Details**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Build Commands**: [BUILD_COMMANDS.md](BUILD_COMMANDS.md)
- **Testing Guide**: [TESTING.md](TESTING.md)

---

## 🏗️ System Architecture at a Glance

### Technology Stack
| Component | Technology |
|-----------|------------|
| **Frontend** | Flutter 3.0+ (Dart) |
| **Backend Database** | Supabase (PostgreSQL) |
| **Authentication** | Supabase Auth (Email OTP) |
| **Push Notifications** | Firebase Cloud Messaging |
| **State Management** | Riverpod 2.5.0 |
| **File Storage** | Supabase Storage |
| **PDF Generation** | pdf + printing packages |

### Application Variants
1. **Web Application** - Unified portal (doctor/patient login)
2. **Doctor Mobile App** - Android/iOS for doctors & admins
3. **Patient Mobile App** - Android/iOS for patients

---

## 🔐 Authentication Flow (Simplified)

```
User Opens App
    ↓
Login Screen → Enter Email → Send OTP
    ↓
Verify OTP → Authentication Success
    ↓
Fetch User Tenants → Select Tenant (if multiple)
    ↓
Get User Role for Tenant → Validate Role
    ↓
Load Tenant Branding → Apply Theme
    ↓
Navigate to Dashboard (Doctor/Patient)
```

---

## 🗄️ Database Tables Overview

| Table | Purpose |
|-------|---------|
| `tenants` | Organization/hospital data |
| `user_tenant_roles` | User role assignments |
| `patients` | Patient profiles |
| `doctors` | Doctor profiles |
| `appointments` | Appointment scheduling |
| `medical_records` | Medical documents |
| `prescriptions` | Prescription details |
| `bills` | Billing information |
| `notifications` | System notifications |
| `user_fcm_tokens` | Firebase push notification tokens |

**All tables include:**
- ✅ `tenant_id` for multi-tenancy
- ✅ Row Level Security (RLS) enabled
- ✅ Automatic timestamps

---

## 🔄 Key User Flows

### Patient Booking Appointment
```
Patient Dashboard → View Doctors → Select Doctor
    ↓
View Available Slots → Select Time → Confirm
    ↓
Appointment Created → Doctor Notified → Confirmation Shown
```

### Doctor Creating Prescription
```
Doctor Dashboard → Select Patient → Patient Details
    ↓
Create Prescription → Enter Medications → Submit
    ↓
Save to Database → Generate PDF → Upload to Storage
    ↓
Notify Patient → Show Confirmation
```

### Medical Record Upload
```
Select Patient → Medical Records → Upload File
    ↓
File Picker → Validate File → Upload to Storage
    ↓
Create Database Entry → Apply RLS → Notify Patient
    ↓
Show Success → Refresh List
```

---

## 🔧 Environment Setup

### 1. Required Environment Variables (.env)
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 2. Firebase Configuration
- **Doctor App**: `android/app/src/doctor/google-services.json`
- **Patient App**: `android/app/src/patient/google-services.json`
- **Dart Config**: `lib/firebase_options_doctor.dart` & `lib/firebase_options_patient.dart`

---

## 🚀 Quick Start Commands

### Install Dependencies
```bash
flutter pub get
flutter pub run build_runner build
```

### Run Apps Locally

**Web (Development):**
```bash
flutter run -d chrome
```

**Doctor App (Android):**
```bash
flutter run --flavor doctor --target lib/main_doctor.dart
```

**Patient App (Android):**
```bash
flutter run --flavor patient --target lib/main_patient.dart
```

### Build for Production

**Web:**
```bash
flutter build web --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release --flavor doctor --target lib/main_doctor.dart
flutter build appbundle --release --flavor patient --target lib/main_patient.dart
```

---

## 🏢 Multi-Tenancy Explained

### How It Works
1. Each organization (hospital/clinic) = 1 Tenant
2. Every data record has a `tenant_id` field
3. Row Level Security (RLS) automatically filters data
4. Users can belong to multiple tenants
5. User selects active tenant during login

### Tenant Isolation
- **Database Level**: RLS policies enforce tenant_id filtering
- **Application Level**: All queries include tenant_id
- **UI Level**: Tenant branding (colors, logo) applied dynamically

### Example RLS Policy
```sql
-- Patients can only see their own data
CREATE POLICY "Patients view own data"
ON patients FOR SELECT
USING (user_id = auth.uid());

-- Doctors see patients in their tenant
CREATE POLICY "Doctors view tenant patients"
ON patients FOR SELECT
USING (
  tenant_id IN (
    SELECT tenant_id FROM user_tenant_roles
    WHERE user_id = auth.uid()
    AND role IN ('doctor', 'admin')
  )
);
```

---

## 🔔 Push Notifications Flow

```
Trigger Event (e.g., New Appointment)
    ↓
Supabase Edge Function Triggered
    ↓
Query User FCM Token from Database
    ↓
Send via Firebase Cloud Messaging
    ↓
Device Receives → Display Notification
```

### Notification Types
- ✅ New appointment booked
- ✅ Appointment reminder
- ✅ New prescription available
- ✅ Follow-up reminder
- ✅ Bill generated

---

## 📂 Project Structure (Simplified)

```
lib/
├── main_doctor.dart          # Doctor app entry point
├── main_patient.dart         # Patient app entry point
├── main.dart                 # Web app entry point
├── app/                      # UI Layer
│   ├── doctor/              # Doctor screens
│   ├── patient/             # Patient screens
│   └── app_flavor.dart      # Flavor configuration
├── core/                     # Business Logic
│   ├── auth/                # Authentication
│   ├── tenant/              # Tenant management
│   ├── patient/             # Patient service
│   ├── doctor/              # Doctor service
│   ├── prescription/        # Prescription service
│   ├── billing/             # Billing service
│   ├── notifications/       # Push notifications
│   └── supabase/            # Supabase config
└── shared/                   # Shared Components
    ├── widgets/             # Reusable widgets
    └── utils/               # Helper functions
```

---

## 🔒 Security Features

### Authentication
- ✅ Email OTP verification
- ✅ Session management
- ✅ Automatic token refresh

### Authorization
- ✅ Role-based access control (RBAC)
- ✅ Tenant-based data isolation
- ✅ Row Level Security (RLS)

### Data Protection
- ✅ HTTPS/TLS for all communication
- ✅ Encrypted data at rest (Supabase)
- ✅ Secure file storage with access control

---

## 🎨 Tenant Branding

### Supported Customizations
- Primary color
- Secondary color
- Logo image
- Font family
- Organization name

### How It's Applied
1. User selects tenant during login
2. App fetches tenant branding from database
3. Theme service generates Flutter ThemeData
4. UI rebuilds with new theme
5. Logo displayed in app bar

---

## 📊 Key Metrics & Features

### Supported Features
- ✅ Patient management
- ✅ Appointment scheduling
- ✅ Medical records with file upload
- ✅ Prescription generation (with PDF)
- ✅ Billing & invoicing (with PDF)
- ✅ Push notifications
- ✅ Follow-up reminders
- ✅ Multi-doctor/multi-clinic support
- ✅ Team management
- ✅ Analytics dashboard
- ✅ X-ray/dental records

### User Roles
| Role | Permissions |
|------|-------------|
| **Patient** | View own data, book appointments, view prescriptions/bills |
| **Doctor** | Manage patients, create prescriptions, view appointments, create bills |
| **Admin** | All doctor permissions + manage team, analytics, clinic settings |

---

## 🐛 Troubleshooting

### Common Issues

**"Supabase has not been initialized"**
- ✅ Ensure `.env` file exists with correct credentials
- ✅ Check `SupabaseConfig.initialize()` is called in main()

**"RLS policy violation"**
- ✅ Verify user has correct role for tenant
- ✅ Check tenant_id is included in query
- ✅ Review RLS policies in Supabase dashboard

**Push notifications not working**
- ✅ Verify Firebase is initialized before Supabase
- ✅ Check google-services.json is in correct flavor folder
- ✅ Ensure user granted notification permissions

**App flavor not recognized**
- ✅ Use `--flavor` flag when running: `--flavor doctor`
- ✅ Verify flavor configuration in android/app/build.gradle
- ✅ Check iOS scheme configuration in Xcode

---

## 📚 Additional Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Complete system architecture with detailed diagrams |
| [BUILD_COMMANDS.md](BUILD_COMMANDS.md) | Build and deployment commands |
| [TESTING.md](TESTING.md) | Testing strategy and manual test suite |
| [MULTI_HOSPITAL_GUIDE.md](MULTI_HOSPITAL_GUIDE.md) | Multi-tenant setup guide |
| [PUSH_NOTIFICATIONS_SETUP.md](PUSH_NOTIFICATIONS_SETUP.md) | Push notification configuration |
| [WEB_DEPLOYMENT.md](WEB_DEPLOYMENT.md) | Web deployment instructions |

---

## 🔗 External Resources

- **Supabase Docs**: https://supabase.com/docs
- **Firebase Docs**: https://firebase.google.com/docs
- **Flutter Docs**: https://docs.flutter.dev
- **Riverpod Docs**: https://riverpod.dev
- **Mermaid Diagrams**: https://mermaid.js.org

---

## 📞 Support

For detailed architecture diagrams and flow charts, refer to [ARCHITECTURE.md](ARCHITECTURE.md).

For build issues, check [BUILD_COMMANDS.md](BUILD_COMMANDS.md).

For testing procedures, see [TESTING.md](TESTING.md).

---

*Last updated: 2026-01-01*
