# Notification System Implementation Guide

## Overview
This guide provides step-by-step instructions to implement a comprehensive notification system for the doctor app with the following features:

1. **Follow-up Reminders**: Patients receive notifications 2 days before their follow-up appointment
2. **Mouthwash Reminders**: Patients receive daily reminders (morning and evening)
3. **Admin Dashboard**: Admins can view and call patients due for follow-up within 2 days
4. **Doctor View**: Doctors can see their follow-up patients

## Prerequisites

- Supabase project set up and running
- Firebase project for push notifications (optional but recommended)
- Supabase CLI installed (for Edge Functions deployment)

## Part 1: Supabase Database Setup

### Step 1: Run the Comprehensive Notification SQL Migration

Execute the SQL script `supabase_notifications_comprehensive.sql` in your Supabase SQL Editor:

1. Open Supabase Dashboard → SQL Editor
2. Copy the contents of `supabase_notifications_comprehensive.sql`
3. Paste and execute the script

**What this creates:**
- `user_fcm_tokens` table - Stores Firebase Cloud Messaging tokens
- `notification_logs` table - Logs all sent notifications
- `daily_reminders` table - Daily reminders for patients (mouthwash, etc.)
- `get_follow_up_patients_due_in_days()` function - Gets patients with follow-ups due in X days
- `get_active_mouthwash_reminders()` function - Gets all active mouthwash reminders
- `send_follow_up_notification()` function - Sends follow-up notifications
- `send_mouthwash_notification()` function - Sends mouthwash notifications
- `admin_follow_up_due_soon` view - Admin view of patients with follow-ups due within 2 days

### Step 2: Verify Table Creation

Run these queries to verify:

```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_fcm_tokens', 'notification_logs', 'daily_reminders');

-- Check if functions exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%notification%' OR routine_name LIKE '%reminder%';

-- Check if view exists
SELECT table_name FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name = 'admin_follow_up_due_soon';
```

### Step 3: Verify Default Mouthwash Reminders

Check that mouthwash reminders were created for existing patients:

```sql
SELECT 
  p.first_name || ' ' || p.last_name as patient_name,
  dr.reminder_type,
  dr.time_of_day,
  dr.is_active
FROM daily_reminders dr
JOIN patients p ON dr.patient_id = p.id
WHERE dr.reminder_type = 'mouthwash'
ORDER BY p.first_name, dr.time_of_day;
```

## Part 2: Firebase Setup (for Push Notifications)

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Add your Flutter app (Android and/or iOS)
4. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

### Step 2: Configure Flutter App

The app already has Firebase dependencies in `pubspec.yaml`:
- `firebase_core`
- `firebase_messaging`
- `flutter_local_notifications`

Place the configuration files:
- **Android**: Place `google-services.json` in `android/app/`
- **iOS**: Place `GoogleService-Info.plist` in `ios/Runner/`

### Step 3: Update Android Configuration

Edit `android/app/build.gradle` and ensure you have:

```gradle
apply plugin: 'com.google.gms.google-services'
```

Edit `android/build.gradle` and add:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

### Step 4: Initialize Firebase in the App

The app already has `PushNotificationService` in `lib/core/notifications/push_notification_service.dart`.

Initialize it in `main.dart` or `main_patient.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'core/notifications/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Push Notifications
  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();
  
  runApp(MyApp());
}
```

## Part 3: Deploy Supabase Edge Functions

### Step 1: Install Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# Windows (via Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Linux
brew install supabase/tap/supabase
```

### Step 2: Login to Supabase

```bash
supabase login
```

### Step 3: Link Your Project

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

### Step 4: Create Edge Function Directories

```bash
# Create functions directory
mkdir -p supabase/functions/send-follow-up-reminders
mkdir -p supabase/functions/send-mouthwash-reminders

# Copy the TypeScript files
cp supabase_edge_function_follow_up_reminders.ts supabase/functions/send-follow-up-reminders/index.ts
cp supabase_edge_function_mouthwash_reminders.ts supabase/functions/send-mouthwash-reminders/index.ts
```

### Step 5: Deploy Edge Functions

```bash
# Deploy follow-up reminders function
supabase functions deploy send-follow-up-reminders

# Deploy mouthwash reminders function
supabase functions deploy send-mouthwash-reminders
```

### Step 6: Set Environment Variables

Set the Supabase URL and service role key for the functions:

```bash
supabase secrets set SUPABASE_URL=https://your-project.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### Step 7: Schedule the Edge Functions

**Follow-up Reminders (Daily at 8 AM):**
```bash
supabase functions schedule send-follow-up-reminders --cron "0 8 * * *"
```

**Mouthwash Reminders (Morning at 8 AM):**
```bash
supabase functions schedule send-mouthwash-reminders --cron "0 8 * * *" --env TIME_OF_DAY=morning
```

**Mouthwash Reminders (Evening at 8 PM):**
```bash
supabase functions schedule send-mouthwash-reminders --cron "0 20 * * *" --env TIME_OF_DAY=evening
```

**Note:** Supabase Edge Function scheduling requires a paid plan. For the free tier, you can:
1. Use external cron services (e.g., GitHub Actions, cron-job.org)
2. Call the functions manually via HTTP requests
3. Use Supabase's pg_cron extension (if available)

## Part 4: Test the System Manually

### Test Follow-up Notifications

1. Create a test patient assignment with a follow-up date 2 days from now:

```sql
-- Insert a test follow-up
UPDATE patient_assignments
SET follow_up_date = NOW() + INTERVAL '2 days'
WHERE patient_id = 'YOUR_PATIENT_ID' AND doctor_id = 'YOUR_DOCTOR_ID';
```

2. Call the Edge Function manually:

```bash
curl -X POST 'https://your-project.supabase.co/functions/v1/send-follow-up-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json'
```

3. Check the notification logs:

```sql
SELECT * FROM notification_logs 
WHERE notification_type = 'follow_up_reminder' 
ORDER BY sent_at DESC 
LIMIT 10;
```

### Test Mouthwash Notifications

1. Verify mouthwash reminders exist:

```sql
SELECT * FROM daily_reminders 
WHERE reminder_type = 'mouthwash' 
LIMIT 10;
```

2. Call the Edge Function manually:

```bash
# Morning reminders
curl -X POST 'https://your-project.supabase.co/functions/v1/send-mouthwash-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"timeOfDay": "morning"}'

# Evening reminders
curl -X POST 'https://your-project.supabase.co/functions/v1/send-mouthwash-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"timeOfDay": "evening"}'
```

3. Check the notification logs:

```sql
SELECT * FROM notification_logs 
WHERE notification_type = 'mouthwash_reminder' 
ORDER BY sent_at DESC 
LIMIT 10;
```

### Test Admin Dashboard

1. Check the admin view:

```sql
SELECT * FROM admin_follow_up_due_soon;
```

2. In the Flutter app, navigate to the Admin Follow-up Due View screen (you'll need to add this to your routes).

## Part 5: Flutter App Integration

### Add Admin Route

Add the admin follow-up view to your doctor routes in `lib/app/doctor/doctor_routes.dart`:

```dart
import 'admin_follow_up_due_view.dart';

// Add to your routes
GoRoute(
  path: 'admin-follow-up-due',
  builder: (context, state) => const AdminFollowUpDueView(),
),
```

### Add Navigation Menu Item

In your doctor dashboard or admin menu, add a navigation item:

```dart
ListTile(
  leading: const Icon(Icons.notification_important),
  title: const Text('Follow-Ups Due Soon'),
  subtitle: const Text('Patients needing reminders'),
  onTap: () {
    context.push('/doctor/admin-follow-up-due');
  },
),
```

## Part 6: Testing Checklist

### Database Tests
- [ ] Verify `user_fcm_tokens` table exists and has correct schema
- [ ] Verify `notification_logs` table exists and has correct schema
- [ ] Verify `daily_reminders` table exists and has correct schema
- [ ] Verify default mouthwash reminders created for all patients
- [ ] Test `get_follow_up_patients_due_in_days()` function
- [ ] Test `get_active_mouthwash_reminders()` function
- [ ] Test `send_follow_up_notification()` function
- [ ] Test `send_mouthwash_notification()` function
- [ ] Test `admin_follow_up_due_soon` view

### Edge Function Tests
- [ ] Deploy follow-up reminders Edge Function
- [ ] Deploy mouthwash reminders Edge Function
- [ ] Test follow-up reminders Edge Function manually
- [ ] Test mouthwash reminders Edge Function manually (morning)
- [ ] Test mouthwash reminders Edge Function manually (evening)
- [ ] Verify notifications are logged in `notification_logs`
- [ ] Schedule Edge Functions (if on paid plan)

### Flutter App Tests
- [ ] Initialize Firebase in the app
- [ ] Test FCM token generation and storage
- [ ] Test push notification reception (foreground)
- [ ] Test push notification reception (background)
- [ ] Test local notification display
- [ ] Test notification tap handling
- [ ] View follow-up patients in doctor app
- [ ] View admin follow-up due soon screen
- [ ] Test phone call functionality from admin screen
- [ ] Test notification history view

### Integration Tests
- [ ] Create test patient with follow-up in 2 days
- [ ] Verify patient appears in doctor's follow-up view
- [ ] Verify patient appears in admin's due soon view
- [ ] Trigger follow-up notification manually
- [ ] Verify notification received on patient's device
- [ ] Create mouthwash reminder for test patient
- [ ] Trigger mouthwash notification manually
- [ ] Verify notification received on patient's device
- [ ] Test notification timing (2 days before follow-up)

## Part 7: Troubleshooting

### Issue: Follow-up patients not showing in doctor app

**Check:**
1. Verify patient assignment has `status = 'active'`
2. Verify `follow_up_date` is set
3. Verify `last_visit_date` is null or before `follow_up_date`

```sql
SELECT * FROM patient_assignments 
WHERE doctor_id = 'YOUR_DOCTOR_ID' 
AND status = 'active' 
AND follow_up_date IS NOT NULL;
```

### Issue: Notifications not being sent

**Check:**
1. Verify FCM token is stored in `user_fcm_tokens`
2. Check Edge Function logs in Supabase dashboard
3. Verify notification appears in `notification_logs`
4. Check Firebase console for delivery status

### Issue: Edge Functions not scheduling

**Solution:**
If on free tier, use external cron service:

**GitHub Actions Example:**

Create `.github/workflows/send-notifications.yml`:

```yaml
name: Send Notifications

on:
  schedule:
    - cron: '0 8 * * *'  # 8 AM daily for follow-ups
    - cron: '0 8 * * *'  # 8 AM daily for morning mouthwash
    - cron: '0 20 * * *' # 8 PM daily for evening mouthwash

jobs:
  send-notifications:
    runs-on: ubuntu-latest
    steps:
      - name: Send Follow-up Reminders
        run: |
          curl -X POST '${{ secrets.SUPABASE_URL }}/functions/v1/send-follow-up-reminders' \
            -H 'Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}'
      
      - name: Send Morning Mouthwash Reminders
        run: |
          curl -X POST '${{ secrets.SUPABASE_URL }}/functions/v1/send-mouthwash-reminders' \
            -H 'Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}' \
            -H 'Content-Type: application/json' \
            -d '{"timeOfDay": "morning"}'
      
      - name: Send Evening Mouthwash Reminders (if 8 PM)
        if: ${{ github.event.schedule == '0 20 * * *' }}
        run: |
          curl -X POST '${{ secrets.SUPABASE_URL }}/functions/v1/send-mouthwash-reminders' \
            -H 'Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}' \
            -H 'Content-Type: application/json' \
            -d '{"timeOfDay": "evening"}'
```

## Summary

This implementation provides:

1. ✅ **2-day advance follow-up notifications** for patients
2. ✅ **Morning and evening mouthwash reminders** for patients
3. ✅ **Admin dashboard** to view and call patients due for follow-up
4. ✅ **Doctor view** of follow-up patients
5. ✅ **Automated notification system** via Supabase Edge Functions
6. ✅ **Notification logging** for audit and tracking
7. ✅ **Firebase integration** for push notifications

All components are ready for deployment and testing!
