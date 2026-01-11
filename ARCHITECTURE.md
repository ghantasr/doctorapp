# Healthcare SaaS - System Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Technology Stack](#technology-stack)
4. [Application Architecture](#application-architecture)
5. [Database Schema](#database-schema)
6. [Authentication Flow](#authentication-flow)
7. [Data Flow Diagrams](#data-flow-diagrams)
8. [Multi-Tenancy Architecture](#multi-tenancy-architecture)
9. [Integration Architecture](#integration-architecture)
10. [Deployment Architecture](#deployment-architecture)

---

## System Overview

This is a **multi-tenant healthcare SaaS platform** built with **Flutter** and **Supabase**, integrated with **Firebase** for push notifications. The system supports three application types:
- **Web Application** (unified portal)
- **Doctor Mobile App** (Android/iOS)
- **Patient Mobile App** (Android/iOS)

### Key Features
- Multi-tenant architecture with complete data isolation
- Role-based access control (Doctor, Admin, Patient)
- Real-time push notifications
- PDF generation for prescriptions and bills
- Medical records management
- Appointment scheduling
- Comprehensive billing system

---

## High-Level Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        WEB[Web Application<br/>Chrome/Safari/Edge]
        DOCTOR[Doctor Mobile App<br/>Android/iOS]
        PATIENT[Patient Mobile App<br/>Android/iOS]
    end
    
    subgraph "Flutter Framework"
        FLUTTER[Flutter SDK<br/>Dart Language]
        RIVERPOD[State Management<br/>Riverpod]
        ROUTER[Navigation<br/>Custom Router]
    end
    
    subgraph "Backend Services"
        SUPABASE[Supabase Backend]
        FIREBASE[Firebase Services]
    end
    
    subgraph "Supabase Components"
        AUTH[Authentication<br/>OTP/Password]
        DB[(PostgreSQL<br/>Database)]
        STORAGE[File Storage<br/>Medical Records]
        RLS[Row Level Security<br/>RLS Policies]
        EDGE[Edge Functions<br/>Reminders]
    end
    
    subgraph "Firebase Components"
        FCM[Cloud Messaging<br/>Push Notifications]
        ANALYTICS[Analytics<br/>Optional]
    end
    
    WEB --> FLUTTER
    DOCTOR --> FLUTTER
    PATIENT --> FLUTTER
    
    FLUTTER --> RIVERPOD
    FLUTTER --> ROUTER
    
    RIVERPOD --> SUPABASE
    RIVERPOD --> FIREBASE
    
    SUPABASE --> AUTH
    SUPABASE --> DB
    SUPABASE --> STORAGE
    SUPABASE --> EDGE
    
    DB --> RLS
    
    FIREBASE --> FCM
    FIREBASE --> ANALYTICS
    
    style WEB fill:#e1f5ff
    style DOCTOR fill:#e1f5ff
    style PATIENT fill:#e1f5ff
    style SUPABASE fill:#3ecf8e
    style FIREBASE fill:#ffa000
    style DB fill:#336791
```

---

## Technology Stack

### Frontend
```mermaid
graph LR
    A[Flutter 3.0+] --> B[Dart Language]
    A --> C[Material Design]
    
    D[State Management] --> E[Riverpod 2.5.0]
    
    F[Routing] --> G[Custom Router]
    
    H[UI Components] --> I[Google Fonts]
    H --> J[Custom Widgets]
    
    K[PDF Generation] --> L[pdf Package]
    K --> M[printing Package]
    
    N[File Handling] --> O[file_picker]
    N --> P[url_launcher]
```

### Backend Integration
| Technology | Version | Purpose |
|------------|---------|---------|
| **Supabase Flutter** | 2.5.0 | Database, Auth, Storage |
| **Firebase Core** | 3.6.0 | Firebase SDK initialization |
| **Firebase Messaging** | 15.1.3 | Push notifications (FCM) |
| **Flutter Local Notifications** | 18.0.1 | Local notification display |
| **Flutter Dotenv** | 5.1.0 | Environment configuration |

### Database
- **PostgreSQL** (via Supabase)
- Row Level Security (RLS) enabled
- Multi-tenant data isolation
- Automatic timestamp management

---

## Application Architecture

### Project Structure

```mermaid
graph TB
    subgraph "lib/"
        MAIN[Main Entry Points]
        APP[App Layer]
        CORE[Core Layer]
        SHARED[Shared Layer]
        WEB[Web Layer]
    end
    
    subgraph "Main Entry Points"
        MD[main_doctor.dart]
        MP[main_patient.dart]
        MW[main.dart - Web]
    end
    
    subgraph "App Layer - UI"
        DOCTOR_UI[Doctor Features<br/>- Dashboard<br/>- Appointments<br/>- Patients<br/>- Prescriptions<br/>- Bills<br/>- Analytics]
        PATIENT_UI[Patient Features<br/>- Dashboard<br/>- Appointments<br/>- Medical Records<br/>- Prescriptions<br/>- Bills]
        FLAVOR[App Flavor<br/>Configuration]
    end
    
    subgraph "Core Layer - Business Logic"
        AUTH_CORE[Authentication]
        TENANT_CORE[Tenant Management]
        PATIENT_CORE[Patient Service]
        DOCTOR_CORE[Doctor Service]
        APPT_CORE[Appointment Service]
        MED_CORE[Medical Records]
        PRESC_CORE[Prescription Service]
        BILL_CORE[Billing Service]
        NOTIF_CORE[Notifications]
        THEME_CORE[Theme Service]
    end
    
    subgraph "Shared Layer - Common"
        WIDGETS[Shared Widgets<br/>- Role Guard<br/>- Custom Components]
        UTILS[Utilities<br/>- Router<br/>- Helpers]
        MODELS[Data Models<br/>- Freezed Classes]
    end
    
    MAIN --> MD
    MAIN --> MP
    MAIN --> MW
    
    MD --> FLAVOR
    MP --> FLAVOR
    MW --> WEB
    
    FLAVOR --> DOCTOR_UI
    FLAVOR --> PATIENT_UI
    
    DOCTOR_UI --> AUTH_CORE
    PATIENT_UI --> AUTH_CORE
    
    AUTH_CORE --> TENANT_CORE
    DOCTOR_UI --> PATIENT_CORE
    DOCTOR_UI --> DOCTOR_CORE
    DOCTOR_UI --> APPT_CORE
    DOCTOR_UI --> MED_CORE
    DOCTOR_UI --> PRESC_CORE
    DOCTOR_UI --> BILL_CORE
    
    PATIENT_UI --> APPT_CORE
    PATIENT_UI --> MED_CORE
    PATIENT_UI --> PRESC_CORE
    PATIENT_UI --> BILL_CORE
    
    CORE --> NOTIF_CORE
    CORE --> THEME_CORE
    
    APP --> WIDGETS
    CORE --> UTILS
    CORE --> MODELS
    
    style DOCTOR_UI fill:#bbdefb
    style PATIENT_UI fill:#c8e6c9
    style AUTH_CORE fill:#fff9c4
    style TENANT_CORE fill:#fff9c4
```

### Layer Responsibilities

#### 1. **Main Entry Points**
- `main_doctor.dart` - Doctor app initialization
- `main_patient.dart` - Patient app initialization
- `main.dart` - Web app initialization
- Initialize Firebase (push notifications)
- Initialize Supabase (database, auth, storage)
- Set app flavor
- Configure providers

#### 2. **App Layer** (`lib/app/`)
- **UI Components**: Screens and views
- **Route Definitions**: App-specific routing
- **Flavor Configuration**: Doctor vs Patient app settings
- Organized by user role (doctor/, patient/)

#### 3. **Core Layer** (`lib/core/`)
- **Business Logic**: Services and data operations
- **Authentication**: OTP, password, role verification
- **Tenant Management**: Multi-tenant operations
- **Domain Services**: Patient, Doctor, Appointments, etc.
- **Notifications**: Push notification handling
- **Theme**: Dynamic theming based on tenant branding

#### 4. **Shared Layer** (`lib/shared/`)
- **Widgets**: Reusable UI components
- **Utilities**: Common helper functions
- **Router**: Navigation logic
- **Models**: Shared data structures

---

## Database Schema

### Entity Relationship Diagram

```mermaid
erDiagram
    TENANTS ||--o{ USER_TENANT_ROLES : "has"
    TENANTS ||--o{ PATIENTS : "manages"
    TENANTS ||--o{ DOCTORS : "employs"
    TENANTS ||--o{ APPOINTMENTS : "schedules"
    TENANTS ||--o{ MEDICAL_RECORDS : "stores"
    TENANTS ||--o{ PRESCRIPTIONS : "creates"
    TENANTS ||--o{ BILLS : "generates"
    TENANTS ||--o{ NOTIFICATIONS : "sends"
    
    AUTH_USERS ||--o{ USER_TENANT_ROLES : "assigned"
    AUTH_USERS ||--o| PATIENTS : "linked"
    AUTH_USERS ||--|| DOCTORS : "linked"
    AUTH_USERS ||--o{ USER_FCM_TOKENS : "has"
    
    PATIENTS ||--o{ APPOINTMENTS : "books"
    PATIENTS ||--o{ MEDICAL_RECORDS : "owns"
    PATIENTS ||--o{ PRESCRIPTIONS : "receives"
    PATIENTS ||--o{ BILLS : "pays"
    PATIENTS ||--o{ PATIENT_ASSIGNMENTS : "assigned_to"
    
    DOCTORS ||--o{ APPOINTMENTS : "conducts"
    DOCTORS ||--o{ MEDICAL_RECORDS : "creates"
    DOCTORS ||--o{ PRESCRIPTIONS : "writes"
    DOCTORS ||--o{ BILLS : "issues"
    DOCTORS ||--o{ PATIENT_ASSIGNMENTS : "manages"
    DOCTORS ||--o{ DOCTOR_SLOTS : "available"
    
    APPOINTMENTS ||--o{ FOLLOW_UPS : "requires"
    APPOINTMENTS ||--o| PRESCRIPTIONS : "generates"
    APPOINTMENTS ||--o| BILLS : "results_in"
    
    TENANTS {
        uuid id PK
        text name
        text logo
        jsonb branding
        timestamptz created_at
        timestamptz updated_at
    }
    
    USER_TENANT_ROLES {
        uuid id PK
        uuid user_id FK
        uuid tenant_id FK
        text role
        timestamptz created_at
    }
    
    PATIENTS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        text first_name
        text last_name
        text email
        text phone
        date date_of_birth
        text gender
        jsonb address
        jsonb medical_history
    }
    
    DOCTORS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        text first_name
        text last_name
        text specialty
        text license_number
        text phone
    }
    
    APPOINTMENTS {
        uuid id PK
        uuid tenant_id FK
        uuid patient_id FK
        uuid doctor_id FK
        timestamptz appointment_time
        int duration_minutes
        text status
        text notes
    }
    
    MEDICAL_RECORDS {
        uuid id PK
        uuid tenant_id FK
        uuid patient_id FK
        uuid doctor_id FK
        text record_type
        text description
        text file_url
        date record_date
    }
```

### Key Tables Overview

| Table | Purpose | RLS Enabled |
|-------|---------|-------------|
| **tenants** | Organization data and branding | ✅ Yes |
| **user_tenant_roles** | User role assignments per tenant | ✅ Yes |
| **patients** | Patient profiles and medical history | ✅ Yes |
| **doctors** | Doctor profiles and credentials | ✅ Yes |
| **appointments** | Appointment scheduling | ✅ Yes |
| **medical_records** | Medical documents and records | ✅ Yes |
| **prescriptions** | Prescription details | ✅ Yes |
| **bills** | Billing and invoices | ✅ Yes |
| **notifications** | System notifications | ✅ Yes |
| **user_fcm_tokens** | Firebase Cloud Messaging tokens | ✅ Yes |
| **follow_ups** | Follow-up appointments | ✅ Yes |
| **doctor_slots** | Doctor availability | ✅ Yes |

---

## Authentication Flow

### Login Flow Diagram

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant Auth as Auth Service
    participant Supabase as Supabase Auth
    participant DB as PostgreSQL
    participant Tenant as Tenant Service
    participant Router as App Router
    
    User->>App: Open App
    App->>App: Check auth state
    
    alt Not Authenticated
        App->>User: Show Login Screen
        User->>App: Enter Email
        App->>Auth: signInWithOTP(email)
        Auth->>Supabase: Send OTP request
        Supabase->>User: Email with OTP code
        User->>App: Enter OTP code
        App->>Auth: verifyOTP(email, token)
        Auth->>Supabase: Verify OTP
        Supabase-->>Auth: User session created
        Auth-->>App: Authentication successful
    end
    
    App->>Auth: Get current user ID
    Auth-->>App: User ID
    
    App->>Auth: fetchUserTenantRoles(userId)
    Auth->>DB: Query user_tenant_roles table
    DB-->>Auth: List of tenant roles
    Auth-->>App: User tenant roles
    
    alt Multiple Tenants
        App->>User: Show Tenant Selection
        User->>App: Select tenant
    end
    
    App->>Tenant: setCurrentTenant(tenantId)
    App->>Auth: getUserRoleForTenant(userId, tenantId)
    Auth->>DB: Query specific role
    DB-->>Auth: User role for tenant
    Auth-->>App: Role (doctor/admin/patient)
    
    App->>App: Validate role vs app flavor
    
    alt Role matches flavor
        App->>Tenant: loadTenantBranding(tenantId)
        Tenant->>DB: Query tenant details
        DB-->>Tenant: Tenant branding
        Tenant-->>App: Theme colors, logo
        App->>Router: Navigate to dashboard
        Router-->>User: Show role-specific dashboard
    else Role mismatch
        App-->>User: Show error message
        App->>Auth: signOut()
    end
```

### Role Validation Process

```mermaid
flowchart TD
    Start([User Authenticated]) --> GetRole[Get User Role for Tenant]
    GetRole --> CheckFlavor{Check App Flavor}
    
    CheckFlavor -->|Doctor App| IsDoctorOrAdmin{Role = doctor<br/>OR admin?}
    CheckFlavor -->|Patient App| IsPatient{Role = patient?}
    CheckFlavor -->|Web App| AllRoles[Any Role Allowed]
    
    IsDoctorOrAdmin -->|Yes| GrantAccess[Grant Access]
    IsDoctorOrAdmin -->|No| DenyAccess[Deny Access]
    
    IsPatient -->|Yes| GrantAccess
    IsPatient -->|No| DenyAccess
    
    AllRoles --> GrantAccess
    
    GrantAccess --> LoadBranding[Load Tenant Branding]
    LoadBranding --> ApplyTheme[Apply Theme]
    ApplyTheme --> InitNotifications[Initialize Push Notifications]
    InitNotifications --> Dashboard[Navigate to Dashboard]
    
    DenyAccess --> ShowError[Show Error Message]
    ShowError --> Logout[Sign Out User]
    Logout --> LoginScreen[Return to Login]
    
    style GrantAccess fill:#4caf50
    style DenyAccess fill:#f44336
    style Dashboard fill:#2196f3
```

---

## Data Flow Diagrams

### Patient Appointment Booking Flow

```mermaid
sequenceDiagram
    actor Patient
    participant UI as Patient App UI
    participant AppointmentService
    participant DoctorService
    participant Supabase
    participant DB as PostgreSQL
    participant Firebase as Firebase FCM
    
    Patient->>UI: Open Appointment Booking
    UI->>DoctorService: fetchDoctors(tenantId)
    DoctorService->>Supabase: Query doctors table
    Supabase->>DB: SELECT with RLS filter
    DB-->>Supabase: Filtered doctor list
    Supabase-->>DoctorService: Doctor data
    DoctorService-->>UI: List of doctors
    UI-->>Patient: Display doctors
    
    Patient->>UI: Select doctor
    UI->>DoctorService: fetchDoctorSlots(doctorId)
    DoctorService->>DB: Query available slots
    DB-->>UI: Available time slots
    
    Patient->>UI: Select date & time
    Patient->>UI: Confirm booking
    
    UI->>AppointmentService: createAppointment(data)
    AppointmentService->>Supabase: Insert appointment
    Supabase->>DB: INSERT with tenant_id
    DB->>DB: RLS policy check
    DB-->>Supabase: Appointment created
    Supabase-->>AppointmentService: Success
    
    AppointmentService->>Firebase: Send notification to doctor
    Firebase-->>Doctor: Push notification
    
    AppointmentService-->>UI: Booking confirmed
    UI-->>Patient: Show confirmation
```

### Doctor Creating Prescription Flow

```mermaid
sequenceDiagram
    actor Doctor
    participant UI as Doctor App UI
    participant PrescriptionService
    participant PDFService
    participant Supabase
    participant Storage as Supabase Storage
    participant DB as PostgreSQL
    participant Patient
    
    Doctor->>UI: Open Patient Details
    Doctor->>UI: Click Create Prescription
    
    UI-->>Doctor: Show prescription form
    Doctor->>UI: Enter medications & instructions
    Doctor->>UI: Submit prescription
    
    UI->>PrescriptionService: createPrescription(data)
    PrescriptionService->>Supabase: Insert prescription
    Supabase->>DB: INSERT with RLS check
    DB-->>Supabase: Prescription ID
    Supabase-->>PrescriptionService: Created
    
    PrescriptionService->>PDFService: generatePrescriptionPDF(prescriptionId)
    PDFService->>PDFService: Create PDF document
    PDFService->>Storage: Upload PDF
    Storage-->>PDFService: File URL
    
    PDFService->>DB: Update prescription with file_url
    DB-->>PDFService: Updated
    
    PDFService-->>PrescriptionService: PDF generated
    PrescriptionService->>Supabase: Create notification
    Supabase->>Patient: Push notification
    
    PrescriptionService-->>UI: Success
    UI-->>Doctor: Show confirmation
```

### Medical Records Upload Flow

```mermaid
flowchart TD
    Start([Doctor/Patient Opens Records]) --> SelectFile[Select File to Upload]
    SelectFile --> FilePicker[File Picker Dialog]
    FilePicker --> FileSelected{File Selected?}
    
    FileSelected -->|No| Cancel[Cancel Upload]
    FileSelected -->|Yes| ValidateFile[Validate File Type & Size]
    
    ValidateFile --> IsValid{Valid File?}
    IsValid -->|No| ShowError[Show Error Message]
    IsValid -->|Yes| UploadToStorage[Upload to Supabase Storage]
    
    UploadToStorage --> StoragePath[Generate unique file path<br/>tenant_id/patient_id/filename]
    StoragePath --> UploadFile[Upload file to storage bucket]
    UploadFile --> GetURL[Get public/signed URL]
    
    GetURL --> CreateRecord[Create medical_records entry]
    CreateRecord --> InsertDB[Insert into PostgreSQL]
    InsertDB --> RLSCheck{RLS Policy Check}
    
    RLSCheck -->|Denied| AccessDenied[Access Denied Error]
    RLSCheck -->|Allowed| RecordCreated[Record Created]
    
    RecordCreated --> NotifyPatient{Uploaded by Doctor?}
    NotifyPatient -->|Yes| SendNotification[Send Push Notification to Patient]
    NotifyPatient -->|No| SkipNotification[Skip Notification]
    
    SendNotification --> Success[Show Success Message]
    SkipNotification --> Success
    
    Success --> RefreshUI[Refresh Records List]
    
    Cancel --> End([End])
    ShowError --> End
    AccessDenied --> End
    RefreshUI --> End
    
    style RecordCreated fill:#4caf50
    style AccessDenied fill:#f44336
    style Success fill:#2196f3
```

---

## Multi-Tenancy Architecture

### Tenant Isolation Strategy

```mermaid
graph TB
    subgraph "Application Layer"
        A[User Request]
        B[Authentication Check]
        C[Tenant Context]
    end
    
    subgraph "Service Layer"
        D[Business Logic]
        E[Tenant ID Injection]
        F[Data Operations]
    end
    
    subgraph "Database Layer"
        G[PostgreSQL]
        H[Row Level Security]
        I[Tenant Scoped Queries]
    end
    
    subgraph "Data Storage"
        J[(Tenant 1 Data)]
        K[(Tenant 2 Data)]
        L[(Tenant N Data)]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    I --> K
    I --> L
    
    style H fill:#ff9800
    style I fill:#ff9800
    style C fill:#2196f3
```

### Tenant Branding Flow

```mermaid
sequenceDiagram
    participant App
    participant TenantService
    participant DB
    participant ThemeService
    participant UI
    
    App->>TenantService: setCurrentTenant(tenantId)
    TenantService->>DB: SELECT * FROM tenants WHERE id = tenantId
    DB-->>TenantService: Tenant data with branding JSON
    
    TenantService->>TenantService: Parse branding configuration
    Note over TenantService: {<br/>  primaryColor: "#2196F3",<br/>  secondaryColor: "#FF9800",<br/>  logo: "url",<br/>  fontFamily: "Roboto"<br/>}
    
    TenantService->>ThemeService: updateTheme(branding)
    ThemeService->>ThemeService: Create ThemeData
    ThemeService->>UI: Notify theme change
    UI->>UI: Rebuild with new theme
    UI-->>App: Updated UI with tenant branding
```

### Row Level Security (RLS) Example

```mermaid
flowchart LR
    subgraph "SQL Query"
        Q1[SELECT * FROM appointments<br/>WHERE patient_id = 'abc-123']
    end
    
    subgraph "RLS Policy Applied"
        Q2[SELECT * FROM appointments<br/>WHERE patient_id = 'abc-123'<br/>AND tenant_id = current_tenant_id<br/>AND authorized_user]
    end
    
    subgraph "Result"
        R[Only tenant-scoped<br/>& authorized records]
    end
    
    Q1 --> Q2
    Q2 --> R
    
    style Q2 fill:#ff9800
    style R fill:#4caf50
```

---

## Integration Architecture

### Supabase Integration

```mermaid
graph TB
    subgraph "Flutter App"
        FLUTTER[Flutter Application]
        SUPABASE_CLIENT[Supabase Client SDK]
    end
    
    subgraph "Supabase Platform"
        AUTH[Auth Service<br/>OTP & Password]
        REALTIME[Realtime<br/>Subscriptions]
        DB[(PostgreSQL<br/>Database)]
        STORAGE[Storage<br/>Files & Images]
        EDGE[Edge Functions<br/>Serverless]
    end
    
    subgraph "Features"
        F1[User Authentication]
        F2[Real-time Updates]
        F3[File Storage]
        F4[Database Operations]
        F5[Scheduled Tasks]
    end
    
    FLUTTER --> SUPABASE_CLIENT
    
    SUPABASE_CLIENT --> AUTH
    SUPABASE_CLIENT --> REALTIME
    SUPABASE_CLIENT --> DB
    SUPABASE_CLIENT --> STORAGE
    SUPABASE_CLIENT --> EDGE
    
    AUTH --> F1
    REALTIME --> F2
    STORAGE --> F3
    DB --> F4
    EDGE --> F5
    
    style SUPABASE_CLIENT fill:#3ecf8e
    style AUTH fill:#3ecf8e
    style DB fill:#336791
```

**Key Supabase Services Used:**
1. **Authentication**: Email/OTP, session management
2. **Database**: PostgreSQL with RLS policies
3. **Storage**: Medical records, X-rays, prescription PDFs
4. **Edge Functions**: Follow-up reminders, scheduled notifications
5. **Realtime**: (Optional) Real-time appointment updates

### Firebase Integration

```mermaid
graph TB
    subgraph "Flutter App"
        APP[Flutter Application]
        FB_SDK[Firebase SDK]
        LOCAL_NOTIF[Local Notifications Plugin]
    end
    
    subgraph "Firebase Platform"
        FCM[Firebase Cloud Messaging]
        ADMIN[Firebase Admin SDK]
    end
    
    subgraph "Notification Flow"
        SERVER[Backend Trigger<br/>Supabase Edge Function]
        SEND[Send Notification]
        DELIVER[Deliver to Device]
        DISPLAY[Display Notification]
    end
    
    APP --> FB_SDK
    APP --> LOCAL_NOTIF
    
    FB_SDK --> FCM
    
    SERVER --> ADMIN
    ADMIN --> SEND
    SEND --> FCM
    FCM --> DELIVER
    DELIVER --> FB_SDK
    FB_SDK --> LOCAL_NOTIF
    LOCAL_NOTIF --> DISPLAY
    
    style FCM fill:#ffa000
    style FB_SDK fill:#ffa000
```

**Firebase Services Used:**
1. **Cloud Messaging (FCM)**: Push notifications
2. **Admin SDK**: Server-side notification sending (via Edge Functions)
3. **Platform-specific config**: google-services.json for Android

### Integration Data Flow

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant Supabase
    participant DB as PostgreSQL
    participant EdgeFunction as Edge Function
    participant Firebase as Firebase FCM
    participant Device
    
    Note over App,Device: Example: Follow-up Reminder Flow
    
    App->>Supabase: Create appointment with follow_up_date
    Supabase->>DB: Insert appointment
    DB->>DB: Store with tenant_id
    DB-->>Supabase: Appointment created
    
    Note over EdgeFunction: Scheduled Edge Function runs daily
    EdgeFunction->>DB: Query due follow-ups
    DB-->>EdgeFunction: List of patients needing reminders
    
    loop For each patient
        EdgeFunction->>DB: Get patient FCM token
        DB-->>EdgeFunction: FCM token
        EdgeFunction->>Firebase: Send push notification
        Firebase->>Device: Deliver notification
        Device-->>App: Display notification
        App->>DB: Log notification sent
    end
```

---

## Deployment Architecture

### Multi-Platform Deployment

```mermaid
graph TB
    subgraph "Source Code"
        REPO[GitHub Repository<br/>Single Codebase]
    end
    
    subgraph "Build Process"
        FLUTTER[Flutter Build System]
        FLAVORS[Flavor Configuration<br/>Doctor | Patient | Web]
    end
    
    subgraph "Web Deployment"
        WEB_BUILD[flutter build web]
        WEB_HOSTING[Static Hosting<br/>Firebase/Netlify/Vercel]
        WEB_USERS[Web Users<br/>Any Browser]
    end
    
    subgraph "Android Deployment"
        ANDROID_BUILD[flutter build appbundle]
        PLAY_STORE[Google Play Store]
        ANDROID_USERS[Android Users]
    end
    
    subgraph "iOS Deployment"
        IOS_BUILD[flutter build ios]
        APP_STORE[Apple App Store]
        IOS_USERS[iOS Users]
    end
    
    REPO --> FLUTTER
    FLUTTER --> FLAVORS
    
    FLAVORS --> WEB_BUILD
    FLAVORS --> ANDROID_BUILD
    FLAVORS --> IOS_BUILD
    
    WEB_BUILD --> WEB_HOSTING
    ANDROID_BUILD --> PLAY_STORE
    IOS_BUILD --> APP_STORE
    
    WEB_HOSTING --> WEB_USERS
    PLAY_STORE --> ANDROID_USERS
    APP_STORE --> IOS_USERS
    
    style WEB_BUILD fill:#e1f5ff
    style ANDROID_BUILD fill:#a4c639
    style IOS_BUILD fill:#000000,color:#ffffff
```

### Environment Configuration

```mermaid
flowchart TD
    Start([App Starts]) --> LoadEnv[Load .env file]
    LoadEnv --> ParseEnv[Parse environment variables]
    
    ParseEnv --> SupabaseURL{SUPABASE_URL<br/>exists?}
    ParseEnv --> SupabaseKey{SUPABASE_ANON_KEY<br/>exists?}
    
    SupabaseURL -->|No| EnvError[Throw Configuration Error]
    SupabaseKey -->|No| EnvError
    
    SupabaseURL -->|Yes| InitSupabase[Initialize Supabase]
    SupabaseKey -->|Yes| InitSupabase
    
    InitSupabase --> InitFirebase[Initialize Firebase]
    InitFirebase --> CheckFlavor{Check App Flavor}
    
    CheckFlavor -->|Doctor| DoctorConfig[Load Doctor Configuration<br/>- firebase_options_doctor.dart<br/>- doctor/google-services.json]
    CheckFlavor -->|Patient| PatientConfig[Load Patient Configuration<br/>- firebase_options_patient.dart<br/>- patient/google-services.json]
    CheckFlavor -->|Web| WebConfig[Load Web Configuration<br/>- Unified portal]
    
    DoctorConfig --> StartApp[Start Application]
    PatientConfig --> StartApp
    WebConfig --> StartApp
    
    EnvError --> ShowError[Show Error to User]
    ShowError --> Exit([Exit])
    
    StartApp --> Ready([App Ready])
    
    style InitSupabase fill:#3ecf8e
    style InitFirebase fill:#ffa000
    style Ready fill:#4caf50
    style EnvError fill:#f44336
```

### Production Infrastructure

```mermaid
graph TB
    subgraph "Frontend"
        WEB[Web App<br/>Static Files]
        MOBILE[Mobile Apps<br/>APK/IPA]
    end
    
    subgraph "Backend - Supabase"
        AUTH[Authentication Service]
        API[RESTful API<br/>PostgREST]
        DB[(PostgreSQL<br/>Multi-tenant DB)]
        STORAGE[Object Storage<br/>Medical Files]
        EDGE[Edge Functions<br/>Serverless]
    end
    
    subgraph "Backend - Firebase"
        FCM[Cloud Messaging]
    end
    
    subgraph "Users"
        DOCTORS[Doctors & Admins]
        PATIENTS[Patients]
    end
    
    DOCTORS --> WEB
    DOCTORS --> MOBILE
    PATIENTS --> WEB
    PATIENTS --> MOBILE
    
    WEB --> AUTH
    MOBILE --> AUTH
    
    WEB --> API
    MOBILE --> API
    
    API --> DB
    AUTH --> DB
    
    WEB --> STORAGE
    MOBILE --> STORAGE
    
    EDGE --> DB
    EDGE --> FCM
    
    FCM --> MOBILE
    
    style DB fill:#336791
    style STORAGE fill:#3ecf8e
    style FCM fill:#ffa000
```

---

## Key Security Features

### Security Architecture

```mermaid
graph TB
    subgraph "Authentication Layer"
        A1[Email OTP Verification]
        A2[Session Management]
        A3[Token Refresh]
    end
    
    subgraph "Authorization Layer"
        B1[Role-Based Access Control]
        B2[Tenant-Based Access]
        B3[Row Level Security]
    end
    
    subgraph "Data Protection"
        C1[Encrypted at Rest]
        C2[HTTPS/TLS in Transit]
        C3[Secure File Storage]
    end
    
    subgraph "Application Security"
        D1[Input Validation]
        D2[SQL Injection Prevention]
        D3[XSS Protection]
    end
    
    A1 --> B1
    A2 --> B1
    A3 --> B1
    
    B1 --> B2
    B2 --> B3
    
    B3 --> C1
    B3 --> C2
    B3 --> C3
    
    C1 --> D1
    C2 --> D2
    C3 --> D3
    
    style B3 fill:#ff9800
    style C2 fill:#4caf50
```

### Row Level Security Policies

**Key RLS Policies:**

1. **Tenants Table**
   - Users can only view tenants they belong to
   - Admins can update their own tenant

2. **User Tenant Roles**
   - Users can only view their own roles
   - Only service role can modify roles

3. **Patients Table**
   - Patients can view only their own data
   - Doctors/admins can view patients in their tenant

4. **Appointments**
   - Patients see only their appointments
   - Doctors see appointments in their tenant

5. **Medical Records**
   - Patients can view their own records
   - Doctors can create/view records in their tenant

---

## Summary

### System Characteristics

| Aspect | Details |
|--------|---------|
| **Architecture Pattern** | Multi-tier, Multi-tenant SaaS |
| **Frontend Framework** | Flutter (cross-platform) |
| **Backend as a Service** | Supabase (PostgreSQL) |
| **Authentication** | Supabase Auth (Email OTP) |
| **Push Notifications** | Firebase Cloud Messaging |
| **State Management** | Riverpod |
| **Multi-tenancy** | Tenant-scoped RLS policies |
| **Security** | Row Level Security (RLS) + RBAC |
| **File Storage** | Supabase Storage |
| **PDF Generation** | Client-side (pdf package) |

### Current Integration Status

✅ **Fully Integrated:**
- Supabase (Database, Auth, Storage)
- Firebase (Push Notifications via FCM)
- Multi-tenant architecture
- Role-based access control
- PDF generation
- File upload/download

### Next Steps for Integration

If you want to extend or modify the Supabase/Firebase integration:

1. **Add Firebase Analytics**: Track user behavior
2. **Add Firebase Crashlytics**: Monitor app crashes
3. **Implement Realtime**: Use Supabase Realtime for live updates
4. **Add More Edge Functions**: Automate more background tasks
5. **Implement Firebase Remote Config**: Feature flags and A/B testing

---

## Development & Build Commands

### Prerequisites
```bash
# Install Flutter dependencies
flutter pub get

# Generate code (for freezed models)
flutter pub run build_runner build
```

### Run Applications

**Web:**
```bash
flutter run -d chrome
```

**Doctor App:**
```bash
# Android
flutter run --flavor doctor --target lib/main_doctor.dart

# iOS
flutter run --flavor doctor --target lib/main_doctor.dart
```

**Patient App:**
```bash
# Android
flutter run --flavor patient --target lib/main_patient.dart

# iOS
flutter run --flavor patient --target lib/main_patient.dart
```

### Build for Production

**Web:**
```bash
flutter build web --release
```

**Android:**
```bash
flutter build appbundle --release --flavor doctor --target lib/main_doctor.dart
flutter build appbundle --release --flavor patient --target lib/main_patient.dart
```

**iOS:**
```bash
flutter build ios --release --flavor doctor --target lib/main_doctor.dart
flutter build ios --release --flavor patient --target lib/main_patient.dart
```

---

## Additional Resources

- **Supabase Documentation**: https://supabase.com/docs
- **Firebase Documentation**: https://firebase.google.com/docs
- **Flutter Documentation**: https://docs.flutter.dev
- **Riverpod Documentation**: https://riverpod.dev

---

*This architecture documentation is maintained as the system evolves. Last updated: 2026-01-01*
