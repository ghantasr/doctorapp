# Multi-Tenant Healthcare SaaS - Flutter App

Production-grade multi-tenant healthcare application built with Flutter and Supabase, deployed as:
- **Web Application**: Unified portal with doctor and patient login
- **Doctor Mobile App**: For healthcare providers (doctors and admins)
- **Patient Mobile App**: For patients

All applications share:
- Same Flutter repository
- Same Supabase backend
- Same database with tenant isolation
- Same authentication system

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete system architecture with detailed diagrams and flow charts
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference guide for developers
- **[BUILD_COMMANDS.md](BUILD_COMMANDS.md)** - Build and deployment commands
- **[TESTING.md](TESTING.md)** - Testing procedures and guidelines

## Features

### Multi-Tenancy
- Tenant isolation using `tenant_id`
- Dynamic tenant branding (colors, fonts, logo)
- Tenant selection for users belonging to multiple organizations
- Row Level Security (RLS) for data isolation

### Role-Based Access Control
- **Doctor App**: Allows `doctor` and `admin` roles only
- **Patient App**: Allows `patient` role only
- Role validation on both client and server
- Automatic role-based navigation

### Authentication
- OTP-based email authentication
- Supabase Auth integration
- Automatic session management
- Secure role verification

### Security
- Mandatory Row Level Security (RLS) on all tables
- Tenant-scoped queries
- Server-side role validation
- No client-side security reliance

## Project Structure

```
lib/
├── app/
│   ├── doctor/
│   │   ├── doctor_routes.dart
│   │   └── doctor_dashboard.dart
│   ├── patient/
│   │   ├── patient_routes.dart
│   │   └── patient_dashboard.dart
│   └── app_flavor.dart
├── core/
│   ├── auth/
│   │   ├── auth_service.dart
│   │   ├── login_screen.dart
│   │   └── user_role.dart
│   ├── tenant/
│   │   ├── tenant.dart
│   │   ├── tenant_service.dart
│   │   └── tenant_selection_screen.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── supabase/
│       └── supabase_config.dart
├── shared/
│   ├── widgets/
│   │   └── role_guard.dart
│   └── utils/
│       └── router.dart
├── main_doctor.dart
└── main_patient.dart
```

## Setup

### 1. Prerequisites
- Flutter SDK 3.0+
- Supabase account
- Android Studio / Xcode for mobile development

### 2. Supabase Setup

1. Create a new Supabase project
2. Run the SQL schema in `supabase_schema.sql` in your Supabase SQL editor
3. Copy your Supabase URL and anon key

### 3. Environment Configuration

Create `.env` file in the root directory:
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 4. Install Dependencies

```bash
flutter pub get
flutter pub run build_runner build
```

### 5. Build and Run

#### Web Application
```bash
# Run in Chrome
flutter run -d chrome

# Build for production
flutter build web --release

# The output will be in build/web directory
```

#### Doctor Mobile App
```bash
# Android
flutter run --flavor doctor --target lib/main_doctor.dart

# iOS
flutter run --flavor doctor --target lib/main_doctor.dart

# Build release APK
flutter build apk --release --flavor doctor --target lib/main_doctor.dart
```

#### Patient Mobile App
```bash
# Android
flutter run --flavor patient --target lib/main_patient.dart

# iOS
flutter run --flavor patient --target lib/main_patient.dart

# Build release APK
flutter build apk --release --flavor patient --target lib/main_patient.dart
```

## App Flow

### Web Application Flow
1. User visits the web portal
2. Landing page displays portal selection (Doctor or Patient)
3. User selects their portal
4. User authenticates via OTP
5. System fetches user's tenants
6. User selects tenant (if multiple available)
7. System fetches user role for selected tenant
8. Role is validated against selected portal
9. Tenant branding is applied
10. User navigates to role-specific dashboard

### Mobile App Flow
1. App launches with flavor detection (doctor or patient)
2. User authenticates via OTP
3. System fetches user's tenants
4. User selects tenant (if multiple available)
5. System fetches user role for selected tenant
6. Role is validated against app flavor
7. Tenant branding is applied
8. User navigates to role-specific dashboard

## Database Schema

### Core Tables
- `tenants`: Organization data and branding
- `user_tenant_roles`: User-tenant-role associations
- `patients`: Patient profiles
- `doctors`: Doctor profiles
- `appointments`: Appointment scheduling
- `medical_records`: Medical records and documents

All tables include:
- Tenant scoping via `tenant_id`
- Row Level Security policies
- Automatic timestamp management

## Security Policies

### Tenants
- Users can view tenants they belong to
- Admins can manage their tenant

### User Roles
- Users can view their own roles
- Admins can manage roles in their tenant

### Patients
- Patients can view their own data
- Doctors and admins can view patients in their tenant

### Appointments
- Patients can view their appointments
- Doctors and admins can manage appointments in their tenant

### Medical Records
- Patients can view their records
- Doctors can view and create records in their tenant

## Flavors Configuration

### Android
Configured in `android/app/build.gradle`:
- Different application IDs
- Different app names
- Separate build configurations

### iOS
Configured via schemes in Xcode:
- Separate bundle identifiers
- Different display names
- Independent build configurations

## Development Guidelines

### Adding New Features
1. Create models with `freezed` for immutability
2. Add Riverpod providers for state management
3. Implement RLS policies in Supabase
4. Add tenant_id scoping to all queries
5. Validate roles before data access

### Testing
1. Test with multiple tenants
2. Verify role restrictions
3. Test flavor-specific features
4. Validate RLS policies in Supabase

## Deployment

### Web Deployment
```bash
# Build for production
flutter build web --release

# Deploy build/web directory to:
# - Firebase Hosting: firebase deploy --only hosting
# - Netlify: netlify deploy --prod --dir=build/web
# - Vercel: vercel --prod build/web
# - Any static hosting service
```

### Android Deployment
```bash
# Build App Bundles for Play Store
flutter build appbundle --release --flavor doctor --target lib/main_doctor.dart
flutter build appbundle --release --flavor patient --target lib/main_patient.dart

# Or build APKs
flutter build apk --release --flavor doctor --target lib/main_doctor.dart
flutter build apk --release --flavor patient --target lib/main_patient.dart
```

### iOS Deployment
```bash
# Build iOS apps
flutter build ios --release --flavor doctor --target lib/main_doctor.dart
flutter build ios --release --flavor patient --target lib/main_patient.dart

# Then use Xcode to archive and upload to App Store
```

## Support

For issues and questions:
1. Check Supabase logs for backend errors
2. Verify RLS policies are enabled
3. Ensure tenant_id is included in queries
4. Validate role assignments in database

## License

Proprietary - All rights reserved
