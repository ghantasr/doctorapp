# Notification System Troubleshooting & Verification Checklist

## Issue Summary
Based on your database data, the notification system is logging notifications but **NOT actually sending them** to user devices. Here's what's happening and what you need to check.

---

## 🔴 Critical Issues Identified

### Issue 1: Notifications Not Being Sent (Status: "no_token" or "pending")
**Problem:** Most notification_logs entries show `status: "no_token"` or `status: "pending"`, meaning:
- The system creates notification log entries ✅
- But no actual push notifications are sent to devices ❌

**Root Cause:** 
- Edge Functions have `TODO` comments where actual FCM sending should happen
- No Firebase Admin SDK integration implemented
- Notifications are only being **logged**, not **sent**

### Issue 2: Duplicate FCM Tokens
**Problem:** All 3 users in `user_fcm_tokens` table have the SAME token:
```
ezgpu-Y7Ryu7IQ63YT6EzD:APA91bEsNynkP_yFbdaYapawM9khk5m1ijB56XqUGd7PKRYdq-514PxLpi1LG11zgijLTJNcNCNPtYu9coKmW9PaDngtJriAQzuZ6B78NUWe5gZikCh9aHs
```

**This indicates:**
- Test/development environment with shared device
- OR a bug in token registration
- Real production should have unique tokens per device

### Issue 3: Database Schema Limitation
**Problem:** `user_fcm_tokens` table has `user_id UUID PRIMARY KEY`, which means:
- Only ONE device per user is supported
- If a user logs in on a new device, the old token is replaced
- Multi-device support is not possible

---

## ✅ Verification Checklist

### Part 1: Database Setup Verification

#### 1.1 Check Tables Exist
Run this SQL in Supabase SQL Editor:

```sql
-- Verify all required tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_fcm_tokens', 'notification_logs', 'daily_reminders', 'notification_templates', 'patient_assignments');
```

**Expected Result:** All 5 tables should be listed

- [ ] `user_fcm_tokens` table exists
- [ ] `notification_logs` table exists
- [ ] `daily_reminders` table exists
- [ ] `notification_templates` table exists
- [ ] `patient_assignments` table exists

#### 1.2 Check Functions Exist
```sql
-- Verify all required functions exist
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
  'get_follow_up_patients_due_in_days',
  'get_active_mouthwash_reminders',
  'send_follow_up_notification',
  'send_mouthwash_notification',
  'handle_new_patient_assignment',
  'normalize_notification_log_user'
);
```

**Expected Result:** All 6 functions should be listed

- [ ] `get_follow_up_patients_due_in_days` function exists
- [ ] `get_active_mouthwash_reminders` function exists
- [ ] `send_follow_up_notification` function exists
- [ ] `send_mouthwash_notification` function exists
- [ ] `handle_new_patient_assignment` function exists
- [ ] `normalize_notification_log_user` function exists

#### 1.3 Check Triggers Exist
```sql
-- Verify triggers are active
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name IN ('handle_new_patient_assignment_trigger', 'normalize_notification_log_user_trigger');
```

**Expected Result:** 2 triggers should be listed

- [ ] `handle_new_patient_assignment_trigger` exists on `patient_assignments` table
- [ ] `normalize_notification_log_user_trigger` exists on `notification_logs` table

### Part 2: FCM Token Verification

#### 2.1 Check Unique FCM Tokens
```sql
-- Check if users have unique FCM tokens
SELECT 
  fcm_token,
  COUNT(*) as user_count,
  array_agg(user_id) as user_ids
FROM user_fcm_tokens
GROUP BY fcm_token
HAVING COUNT(*) > 1;
```

**Expected Result:** Empty result (no duplicate tokens)

- [ ] All FCM tokens are unique (if not, this indicates a test environment or bug)

#### 2.2 Check User-Token Mapping
```sql
-- Verify users with tokens
SELECT 
  uft.user_id,
  COALESCE(d.first_name, p.first_name) as first_name,
  COALESCE(d.last_name, p.last_name) as last_name,
  CASE 
    WHEN d.id IS NOT NULL THEN 'Doctor'
    WHEN p.id IS NOT NULL THEN 'Patient'
    ELSE 'Unknown'
  END as role,
  LEFT(uft.fcm_token, 50) || '...' as token_preview,
  uft.updated_at
FROM user_fcm_tokens uft
LEFT JOIN doctors d ON d.user_id = uft.user_id
LEFT JOIN patients p ON p.user_id = uft.user_id
ORDER BY uft.updated_at DESC;
```

- [ ] All users with tokens are correctly identified
- [ ] Tokens have recent `updated_at` timestamps
- [ ] Each user role (Doctor/Patient) is correctly shown

### Part 3: Notification Logs Analysis

#### 3.1 Check Notification Status Distribution
```sql
-- Analyze notification statuses
SELECT 
  status,
  COUNT(*) as count,
  MIN(sent_at) as first_sent,
  MAX(sent_at) as last_sent
FROM notification_logs
GROUP BY status
ORDER BY count DESC;
```

- [ ] Document the count for each status:
  - `no_token`: _____ (indicates users without FCM tokens)
  - `pending`: _____ (indicates logged but not sent)
  - `sent`: _____ (indicates successfully sent)
  - `failed`: _____ (indicates send failures)

#### 3.2 Identify Users Without Tokens
```sql
-- Find users receiving notifications but without FCM tokens
SELECT DISTINCT
  nl.user_id,
  COALESCE(d.first_name, p.first_name) as first_name,
  COALESCE(d.last_name, p.last_name) as last_name,
  CASE 
    WHEN d.id IS NOT NULL THEN 'Doctor'
    WHEN p.id IS NOT NULL THEN 'Patient'
    ELSE 'Unknown'
  END as role,
  COUNT(nl.id) as notification_count
FROM notification_logs nl
LEFT JOIN doctors d ON d.user_id = nl.user_id
LEFT JOIN patients p ON p.user_id = nl.user_id
WHERE nl.status = 'no_token'
  AND nl.user_id NOT IN (SELECT user_id FROM user_fcm_tokens)
GROUP BY nl.user_id, d.first_name, d.last_name, p.first_name, p.last_name, d.id, p.id
ORDER BY notification_count DESC;
```

- [ ] List users who need to register FCM tokens (install and login to the app)

#### 3.3 Check New Assignment Notifications
```sql
-- Analyze new_assignment notifications
SELECT 
  nl.user_id,
  d.first_name || ' ' || d.last_name as doctor_name,
  nl.title,
  nl.body,
  nl.status,
  nl.sent_at,
  (nl.data->>'patient_id')::uuid as patient_id,
  (nl.data->>'assignment_id')::uuid as assignment_id
FROM notification_logs nl
LEFT JOIN doctors d ON d.user_id = nl.user_id
WHERE nl.notification_type = 'new_assignment'
ORDER BY nl.sent_at DESC
LIMIT 20;
```

- [ ] Verify new assignment notifications are being created when patients are assigned
- [ ] Check if doctors who should receive notifications have FCM tokens

### Part 4: Firebase & Edge Functions Setup

#### 4.1 Firebase Project Setup
- [ ] Firebase project is created
- [ ] Firebase Cloud Messaging (FCM) is enabled
- [ ] `google-services.json` (Android) is added to `android/app/`
- [ ] `GoogleService-Info.plist` (iOS) is added to `ios/Runner/`
- [ ] Firebase Admin SDK credentials are available (service account JSON)

#### 4.2 Supabase Edge Functions Deployment
Check if Edge Functions are deployed:

```bash
# Login to Supabase CLI
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# List deployed functions
supabase functions list
```

- [ ] `send-follow-up-reminders` function is deployed
- [ ] `send-mouthwash-reminders` function is deployed
- [ ] `send-new-assignment-notification` function is deployed (if created)

#### 4.3 Edge Function Environment Variables
Check if required secrets are set:

```bash
# List secrets
supabase secrets list
```

Required secrets:
- [ ] `SUPABASE_URL` is set
- [ ] `SUPABASE_SERVICE_ROLE_KEY` is set
- [ ] `FIREBASE_SERVICE_ACCOUNT_KEY` is set (required for sending FCM)
- [ ] `FIREBASE_PROJECT_ID` is set

#### 4.4 Test Edge Functions Manually
Test follow-up reminders:

```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-follow-up-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json'
```

- [ ] Function returns success response
- [ ] Check notification_logs table for new entries
- [ ] Check Edge Function logs in Supabase Dashboard for errors

### Part 5: Flutter App Verification

#### 5.1 Firebase Initialization
Check `lib/main_doctor.dart` and `lib/main_patient.dart`:

- [ ] `Firebase.initializeApp()` is called before `runApp()`
- [ ] `PushNotificationService().initialize()` is called
- [ ] No errors during Firebase initialization

#### 5.2 FCM Token Registration
When a user logs in to the app:

- [ ] FCM token is generated (check console logs for "FCM Token: ...")
- [ ] Token is saved to Supabase `user_fcm_tokens` table
- [ ] Check database to verify token was saved:

```sql
-- Check most recent token updates
SELECT 
  user_id,
  LEFT(fcm_token, 50) || '...' as token,
  updated_at
FROM user_fcm_tokens
ORDER BY updated_at DESC
LIMIT 10;
```

#### 5.3 Notification Reception
Test receiving notifications:

- [ ] App can receive foreground notifications (when app is open)
- [ ] App can receive background notifications (when app is minimized)
- [ ] App can receive notifications when terminated
- [ ] Tapping notification navigates to correct screen

### Part 6: End-to-End Testing

#### 6.1 Test New Assignment Notification Flow
1. Create a new patient assignment:

```sql
-- Create test assignment
INSERT INTO patient_assignments (patient_id, doctor_id, tenant_id, status, assigned_date)
VALUES (
  'PATIENT_ID_HERE',
  'DOCTOR_ID_HERE',
  'TENANT_ID_HERE',
  'active',
  NOW()
);
```

2. Check notification was logged:

```sql
SELECT * FROM notification_logs 
WHERE notification_type = 'new_assignment' 
ORDER BY sent_at DESC 
LIMIT 1;
```

- [ ] Notification log entry was created
- [ ] Status is 'pending' or 'sent' (not 'no_token')
- [ ] Doctor received push notification on their device

#### 6.2 Test Follow-up Reminder Flow
1. Create a patient assignment with follow-up in 2 days:

```sql
-- Set follow-up date to 2 days from now
UPDATE patient_assignments
SET follow_up_date = (CURRENT_DATE + INTERVAL '2 days')::timestamptz
WHERE patient_id = 'PATIENT_ID_HERE' 
  AND doctor_id = 'DOCTOR_ID_HERE'
  AND status = 'active';
```

2. Manually trigger the edge function:

```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-follow-up-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY'
```

3. Verify notification:

```sql
SELECT * FROM notification_logs 
WHERE notification_type = 'follow_up_reminder' 
ORDER BY sent_at DESC 
LIMIT 1;
```

- [ ] Patient received follow-up reminder notification
- [ ] Notification appears in notification_logs with status 'sent'

#### 6.3 Test Mouthwash Reminder Flow
1. Verify patient has mouthwash reminders:

```sql
SELECT * FROM daily_reminders 
WHERE patient_id = 'PATIENT_ID_HERE' 
  AND reminder_type = 'mouthwash'
  AND is_active = true;
```

2. Manually trigger the edge function:

```bash
# Morning reminder
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-mouthwash-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"timeOfDay": "morning"}'
```

- [ ] Patient received mouthwash reminder
- [ ] Notification appears in notification_logs

---

## 🔧 Required Fixes

Based on the analysis, here are the fixes needed:

### Fix 1: Implement Actual FCM Sending in Edge Functions
The Edge Functions currently have this TODO:
```typescript
// TODO: Integrate Firebase Admin SDK to send actual push notification
```

**Action Required:**
1. Set up Firebase Admin SDK in Edge Functions
2. Add FCM sending logic to replace the TODO
3. Update notification status to 'sent' or 'failed' based on result

### Fix 2: Support Multiple Devices Per User
Current schema only allows one token per user (PRIMARY KEY on user_id).

**Recommended Schema Update:**
```sql
-- Add support for multiple devices per user
ALTER TABLE user_fcm_tokens DROP CONSTRAINT user_fcm_tokens_pkey;
ALTER TABLE user_fcm_tokens ADD COLUMN id UUID DEFAULT gen_random_uuid() PRIMARY KEY;
CREATE UNIQUE INDEX idx_user_device_token ON user_fcm_tokens(user_id, fcm_token);
```

### Fix 3: Create Edge Function to Process Pending Notifications
Notifications with status 'pending' need to be processed.

**Action Required:**
Create a new Edge Function: `send-pending-notifications` that:
1. Queries notification_logs WHERE status = 'pending'
2. Gets FCM token for each user
3. Sends the notification via Firebase Admin SDK
4. Updates status to 'sent' or 'failed'

### Fix 4: Add Retry Logic for Failed Notifications
**Action Required:**
- Add retry mechanism for failed notifications
- Store retry count in notification_logs
- Implement exponential backoff

---

## 📋 Quick Action Plan

**Immediate Actions (Do These First):**
1. [ ] Run all SQL verification queries above and document results
2. [ ] Check if any users actually have the app installed and logged in
3. [ ] Verify Firebase project is set up correctly
4. [ ] Check if Edge Functions are deployed

**Short-term Fixes:**
1. [ ] Implement Firebase Admin SDK in Edge Functions
2. [ ] Update user_fcm_tokens schema to support multiple devices
3. [ ] Create send-pending-notifications Edge Function
4. [ ] Add proper error handling and logging

**Testing:**
1. [ ] Install app on a test device
2. [ ] Login as a doctor user
3. [ ] Verify FCM token is saved to database
4. [ ] Create a test patient assignment
5. [ ] Verify notification is received on device

---

## 🆘 Common Issues & Solutions

### Issue: "No FCM tokens found"
**Cause:** Users haven't installed/logged into the app yet
**Solution:** Install the app on devices and have users log in

### Issue: "Duplicate FCM tokens"
**Cause:** Multiple users using same test device
**Solution:** This is normal in development; test with separate devices in production

### Issue: "Notifications logged but not sent"
**Cause:** Firebase Admin SDK not implemented in Edge Functions
**Solution:** Implement FCM sending logic as described in Fix 1 above

### Issue: "Edge Functions not running on schedule"
**Cause:** Supabase free tier doesn't support cron scheduling
**Solution:** Use external cron service (GitHub Actions, cron-job.org, etc.)

---

## 📞 Next Steps

After completing this checklist, you should have:
1. Clear understanding of what's working and what's not
2. List of users who need to install/login to the app
3. Identified missing components (Firebase Admin SDK, Edge Function deployment, etc.)
4. Action plan to fix notification sending

**Share your findings from the verification checklist, and I can help with the specific fixes needed!**
