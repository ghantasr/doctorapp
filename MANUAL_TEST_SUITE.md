# Manual Test Suite - Notification System

## Test Environment Setup

### Prerequisites
- [ ] Supabase database with all tables and functions created
- [ ] Flutter app installed on test device
- [ ] Firebase project configured
- [ ] Test accounts: 1 admin, 1 doctor, 2 patients

### Test Data Setup

Create test data using these SQL commands:

```sql
-- Create test patient with follow-up in 2 days
-- (Replace YOUR_PATIENT_ID, YOUR_DOCTOR_ID, YOUR_TENANT_ID, YOUR_ADMIN_ID with actual values)

-- Update existing patient assignment with follow-up
UPDATE patient_assignments
SET 
  follow_up_date = NOW() + INTERVAL '2 days',
  last_visit_date = NULL,
  status = 'active'
WHERE patient_id = 'YOUR_PATIENT_ID' 
  AND doctor_id = 'YOUR_DOCTOR_ID';

-- Verify the update
SELECT 
  pa.id,
  p.first_name || ' ' || p.last_name as patient_name,
  d.first_name || ' ' || d.last_name as doctor_name,
  pa.follow_up_date,
  pa.status
FROM patient_assignments pa
JOIN patients p ON pa.patient_id = p.id
JOIN doctors d ON pa.doctor_id = d.id
WHERE pa.patient_id = 'YOUR_PATIENT_ID';
```

---

## Test Cases

### TC-001: Database Setup Verification

**Objective:** Verify all database tables, functions, and views are created correctly

**Steps:**
1. Open Supabase Dashboard → SQL Editor
2. Execute verification query:
   ```sql
   -- Check tables
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name IN ('user_fcm_tokens', 'notification_logs', 'daily_reminders');
   ```
3. Verify all 3 tables exist
4. Execute function check:
   ```sql
   SELECT routine_name FROM information_schema.routines 
   WHERE routine_schema = 'public' 
   AND (routine_name LIKE '%notification%' OR routine_name LIKE '%reminder%');
   ```
5. Verify functions exist
6. Execute view check:
   ```sql
   SELECT * FROM admin_follow_up_due_soon LIMIT 5;
   ```

**Expected Result:**
- ✅ All tables exist
- ✅ All functions exist
- ✅ Admin view returns data (if test patients exist)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-002: Default Mouthwash Reminders Creation

**Objective:** Verify mouthwash reminders were automatically created for all patients

**Steps:**
1. Open Supabase Dashboard → SQL Editor
2. Execute query:
   ```sql
   SELECT 
     p.first_name || ' ' || p.last_name as patient_name,
     dr.reminder_type,
     dr.time_of_day,
     dr.is_active,
     dr.reminder_text
   FROM daily_reminders dr
   JOIN patients p ON dr.patient_id = p.id
   WHERE dr.reminder_type = 'mouthwash'
   ORDER BY p.first_name, dr.time_of_day;
   ```
3. Verify each patient has 2 reminders (morning and evening)

**Expected Result:**
- ✅ Each patient has a morning mouthwash reminder
- ✅ Each patient has an evening mouthwash reminder
- ✅ All reminders are active (is_active = true)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-003: Follow-up Patients Function Test

**Objective:** Test the get_follow_up_patients_due_in_days function

**Steps:**
1. Create test patient with follow-up in 2 days (see Test Data Setup)
2. Execute function:
   ```sql
   SELECT * FROM get_follow_up_patients_due_in_days(2);
   ```
3. Verify test patient appears in results
4. Test with different day values:
   ```sql
   SELECT * FROM get_follow_up_patients_due_in_days(0);  -- Today
   SELECT * FROM get_follow_up_patients_due_in_days(1);  -- Tomorrow
   SELECT * FROM get_follow_up_patients_due_in_days(7);  -- In 7 days
   ```

**Expected Result:**
- ✅ Function returns correct patients based on days_advance parameter
- ✅ Only active assignments are returned
- ✅ Patients with last_visit_date after follow_up_date are excluded

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-004: Mouthwash Reminders Function Test

**Objective:** Test the get_active_mouthwash_reminders function

**Steps:**
1. Execute function:
   ```sql
   SELECT * FROM get_active_mouthwash_reminders();
   ```
2. Verify all active mouthwash reminders are returned
3. Count morning vs evening reminders:
   ```sql
   SELECT 
     time_of_day,
     COUNT(*) as count
   FROM get_active_mouthwash_reminders()
   GROUP BY time_of_day;
   ```

**Expected Result:**
- ✅ All active mouthwash reminders are returned
- ✅ Both morning and evening reminders are present
- ✅ Count matches total active patients

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-005: Send Follow-up Notification Function Test

**Objective:** Test the send_follow_up_notification function

**Steps:**
1. Get a test patient ID with follow-up:
   ```sql
   SELECT patient_id, follow_up_date 
   FROM patient_assignments 
   WHERE follow_up_date IS NOT NULL 
   LIMIT 1;
   ```
2. Call the notification function:
   ```sql
   SELECT send_follow_up_notification(
     'YOUR_PATIENT_ID'::uuid,
     NOW() + INTERVAL '2 days'
   );
   ```
3. Check notification_logs:
   ```sql
   SELECT * FROM notification_logs 
   WHERE notification_type = 'follow_up_reminder' 
   ORDER BY sent_at DESC 
   LIMIT 5;
   ```

**Expected Result:**
- ✅ Function returns success response
- ✅ Notification is logged in notification_logs table
- ✅ Status is 'sent' if FCM token exists, 'no_token' otherwise

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-006: Send Mouthwash Notification Function Test

**Objective:** Test the send_mouthwash_notification function

**Steps:**
1. Get a test patient ID:
   ```sql
   SELECT patient_id FROM daily_reminders LIMIT 1;
   ```
2. Call the notification function:
   ```sql
   SELECT send_mouthwash_notification(
     'YOUR_PATIENT_ID'::uuid,
     'Good morning! Time for your mouthwash rinse.',
     'morning'
   );
   ```
3. Check notification_logs:
   ```sql
   SELECT * FROM notification_logs 
   WHERE notification_type = 'mouthwash_reminder' 
   ORDER BY sent_at DESC 
   LIMIT 5;
   ```

**Expected Result:**
- ✅ Function returns success response
- ✅ Notification is logged in notification_logs table
- ✅ Correct reminder text and time_of_day in data field

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-007: Admin Follow-up Due Soon View Test

**Objective:** Test the admin_follow_up_due_soon view

**Steps:**
1. Create test patients with various follow-up dates:
   ```sql
   -- Patient due today
   UPDATE patient_assignments SET follow_up_date = NOW() 
   WHERE patient_id = 'PATIENT_1_ID';
   
   -- Patient due tomorrow
   UPDATE patient_assignments SET follow_up_date = NOW() + INTERVAL '1 day' 
   WHERE patient_id = 'PATIENT_2_ID';
   
   -- Patient due in 2 days
   UPDATE patient_assignments SET follow_up_date = NOW() + INTERVAL '2 days' 
   WHERE patient_id = 'PATIENT_3_ID';
   
   -- Patient due in 3 days (should not appear)
   UPDATE patient_assignments SET follow_up_date = NOW() + INTERVAL '3 days' 
   WHERE patient_id = 'PATIENT_4_ID';
   ```
2. Query the view:
   ```sql
   SELECT * FROM admin_follow_up_due_soon 
   ORDER BY follow_up_date;
   ```
3. Verify only patients due within 2 days appear

**Expected Result:**
- ✅ View shows patients due today, tomorrow, and in 2 days
- ✅ Patients due in 3+ days are excluded
- ✅ Patient name, phone, email, and doctor info are displayed
- ✅ days_until_follow_up is calculated correctly

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-008: Firebase Initialization in Flutter App

**Objective:** Verify Firebase is initialized correctly in the Flutter app

**Steps:**
1. Launch the Flutter app (patient app)
2. Check console/logs for Firebase initialization message
3. Verify no errors during initialization
4. Check for FCM token generation message

**Expected Result:**
- ✅ Firebase initializes without errors
- ✅ FCM token is generated
- ✅ Token is printed in console (for debugging)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-009: FCM Token Storage in Database

**Objective:** Verify FCM tokens are stored in the database

**Steps:**
1. Launch the Flutter app and log in as a patient
2. Wait for Firebase initialization
3. Check the database:
   ```sql
   SELECT 
     u.email,
     uft.fcm_token,
     uft.created_at,
     uft.updated_at
   FROM user_fcm_tokens uft
   JOIN auth.users u ON uft.user_id = u.id
   ORDER BY uft.created_at DESC
   LIMIT 10;
   ```
4. Verify the logged-in user's FCM token is stored

**Expected Result:**
- ✅ FCM token is stored in user_fcm_tokens table
- ✅ Token is associated with correct user_id
- ✅ Timestamp is recent

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-010: Doctor Follow-up Patients View

**Objective:** Verify doctors can see their follow-up patients in the app

**Steps:**
1. Create test patient with follow-up assigned to test doctor:
   ```sql
   UPDATE patient_assignments
   SET 
     follow_up_date = NOW() + INTERVAL '3 days',
     status = 'active',
     last_visit_date = NULL
   WHERE patient_id = 'TEST_PATIENT_ID' 
     AND doctor_id = 'TEST_DOCTOR_ID';
   ```
2. Launch the doctor app and log in as test doctor
3. Navigate to "Follow-Up Patients" screen
4. Verify the test patient appears in the list

**Expected Result:**
- ✅ Follow-up patients screen loads without errors
- ✅ Test patient appears in the list
- ✅ Patient details are displayed correctly
- ✅ Follow-up date is shown
- ✅ Patients are categorized (Overdue, Today, Upcoming)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-011: Admin Follow-up Due Soon View in Flutter

**Objective:** Test the admin follow-up due soon screen in Flutter app

**Steps:**
1. Ensure there are patients with follow-ups due within 2 days
2. Launch the doctor app and log in as admin
3. Navigate to "Follow-Ups Due Soon" screen
4. Verify patients are listed
5. Test the "Call Patient" button
6. Test the "Auto Reminder" button

**Expected Result:**
- ✅ Screen loads without errors
- ✅ Patients with follow-ups due within 2 days are displayed
- ✅ Patient info (name, phone, email, doctor) is shown
- ✅ Urgency badges (TODAY, TOMORROW, IN X DAYS) are displayed correctly
- ✅ "Call Patient" button opens phone dialer
- ✅ "Auto Reminder" button shows confirmation message

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-012: Edge Function - Follow-up Reminders (Manual Trigger)

**Objective:** Test the follow-up reminders Edge Function manually

**Prerequisites:** Edge Function deployed to Supabase

**Steps:**
1. Ensure there's a patient with follow-up in 2 days
2. Trigger the Edge Function via HTTP:
   ```bash
   curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-follow-up-reminders' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json'
   ```
3. Check the response
4. Verify notification_logs:
   ```sql
   SELECT * FROM notification_logs 
   WHERE notification_type = 'follow_up_reminder' 
   AND sent_at > NOW() - INTERVAL '5 minutes'
   ORDER BY sent_at DESC;
   ```

**Expected Result:**
- ✅ Edge Function returns success response
- ✅ Response includes processed patients
- ✅ Notifications are logged in database
- ✅ No errors in function logs

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-013: Edge Function - Mouthwash Reminders Morning (Manual Trigger)

**Objective:** Test the mouthwash reminders Edge Function for morning reminders

**Prerequisites:** Edge Function deployed to Supabase

**Steps:**
1. Trigger the Edge Function for morning:
   ```bash
   curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-mouthwash-reminders' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json' \
     -d '{"timeOfDay": "morning"}'
   ```
2. Check the response
3. Verify notification_logs:
   ```sql
   SELECT 
     nl.*,
     nl.data->>'time_of_day' as time_of_day
   FROM notification_logs nl
   WHERE notification_type = 'mouthwash_reminder' 
   AND sent_at > NOW() - INTERVAL '5 minutes'
   AND data->>'time_of_day' = 'morning'
   ORDER BY sent_at DESC;
   ```

**Expected Result:**
- ✅ Edge Function returns success response
- ✅ Only morning reminders are sent
- ✅ Notifications are logged with correct time_of_day
- ✅ Count matches active morning reminders

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-014: Edge Function - Mouthwash Reminders Evening (Manual Trigger)

**Objective:** Test the mouthwash reminders Edge Function for evening reminders

**Prerequisites:** Edge Function deployed to Supabase

**Steps:**
1. Trigger the Edge Function for evening:
   ```bash
   curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-mouthwash-reminders' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json' \
     -d '{"timeOfDay": "evening"}'
   ```
2. Check the response
3. Verify notification_logs:
   ```sql
   SELECT 
     nl.*,
     nl.data->>'time_of_day' as time_of_day
   FROM notification_logs nl
   WHERE notification_type = 'mouthwash_reminder' 
   AND sent_at > NOW() - INTERVAL '5 minutes'
   AND data->>'time_of_day' = 'evening'
   ORDER BY sent_at DESC;
   ```

**Expected Result:**
- ✅ Edge Function returns success response
- ✅ Only evening reminders are sent
- ✅ Notifications are logged with correct time_of_day
- ✅ Count matches active evening reminders

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-015: Push Notification - Foreground Reception

**Objective:** Test push notification reception when app is in foreground

**Prerequisites:** 
- Firebase configured
- FCM token stored in database
- Push notification sent manually via Firebase Console

**Steps:**
1. Launch patient app and keep it in foreground
2. Send test notification via Firebase Console:
   - Go to Firebase Console → Cloud Messaging
   - Click "Send your first message"
   - Title: "Test Follow-up Reminder"
   - Body: "You have a follow-up in 2 days"
   - Target: Single device, enter FCM token
3. Observe the app

**Expected Result:**
- ✅ Local notification appears on device
- ✅ Notification title and body are correct
- ✅ Console logs show notification received

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-016: Push Notification - Background Reception

**Objective:** Test push notification reception when app is in background

**Prerequisites:** 
- Firebase configured
- FCM token stored in database

**Steps:**
1. Launch patient app
2. Put app in background (home button)
3. Send test notification via Firebase Console
4. Observe notification tray

**Expected Result:**
- ✅ Notification appears in notification tray
- ✅ Tapping notification opens the app
- ✅ Notification data is handled correctly

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-017: Notification History View

**Objective:** Test notification history in the app

**Prerequisites:** Several notifications sent to test patient

**Steps:**
1. Log in as patient with notification history
2. Navigate to notification history screen (if implemented)
3. Verify past notifications are displayed
4. Check notification details

**Expected Result:**
- ✅ Notification history loads successfully
- ✅ All sent notifications are displayed
- ✅ Most recent notifications appear first
- ✅ Notification type, title, body, and timestamp are shown

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-018: 2-Day Advance Timing Test

**Objective:** Verify follow-up notifications are sent exactly 2 days in advance

**Steps:**
1. Create patient with follow-up in exactly 2 days:
   ```sql
   UPDATE patient_assignments
   SET follow_up_date = (CURRENT_DATE + INTERVAL '2 days')::timestamp + TIME '10:00:00'
   WHERE patient_id = 'TEST_PATIENT_ID';
   ```
2. Trigger follow-up reminder function:
   ```sql
   SELECT * FROM get_follow_up_patients_due_in_days(2);
   ```
3. Verify patient appears
4. Test with 1 day and 3 days:
   ```sql
   SELECT * FROM get_follow_up_patients_due_in_days(1);  -- Should be empty
   SELECT * FROM get_follow_up_patients_due_in_days(3);  -- Should be empty
   ```

**Expected Result:**
- ✅ Patient appears when checking 2 days advance
- ✅ Patient does not appear for 1 day or 3 days advance
- ✅ Timing is precise to the day

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-019: Phone Call Functionality from Admin Screen

**Objective:** Test making phone calls from admin follow-up screen

**Prerequisites:** Test device with phone capability

**Steps:**
1. Launch doctor app as admin
2. Navigate to "Follow-Ups Due Soon"
3. Find patient with phone number
4. Tap "Call Patient" button
5. Verify phone dialer opens
6. Verify correct number is populated

**Expected Result:**
- ✅ "Call Patient" button is enabled for patients with phone numbers
- ✅ Tapping button opens device phone dialer
- ✅ Correct phone number is pre-populated
- ✅ User can make the call

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

### TC-020: End-to-End Integration Test

**Objective:** Complete workflow test from patient creation to notification delivery

**Steps:**
1. Create new patient via admin/doctor app
2. Assign patient to doctor
3. Set follow-up date to 2 days from now
4. Verify patient appears in:
   - Doctor's follow-up patients view
   - Admin's follow-ups due soon view
   - Database function: get_follow_up_patients_due_in_days(2)
5. Manually trigger follow-up notification Edge Function
6. Verify notification is logged
7. Check patient app for notification (if FCM configured)
8. Admin calls patient from admin screen
9. Doctor marks patient as visited

**Expected Result:**
- ✅ All steps complete without errors
- ✅ Patient data flows correctly through all views
- ✅ Notification is sent and logged
- ✅ Phone call can be initiated
- ✅ Patient can be marked as visited

**Status:** [ ] Pass [ ] Fail

**Notes:**
_______________________________________________________________________________________

---

## Test Summary

### Database Tests
- [ ] TC-001: Database Setup Verification
- [ ] TC-002: Default Mouthwash Reminders Creation
- [ ] TC-003: Follow-up Patients Function Test
- [ ] TC-004: Mouthwash Reminders Function Test
- [ ] TC-005: Send Follow-up Notification Function Test
- [ ] TC-006: Send Mouthwash Notification Function Test
- [ ] TC-007: Admin Follow-up Due Soon View Test

### Flutter App Tests
- [ ] TC-008: Firebase Initialization in Flutter App
- [ ] TC-009: FCM Token Storage in Database
- [ ] TC-010: Doctor Follow-up Patients View
- [ ] TC-011: Admin Follow-up Due Soon View in Flutter

### Edge Function Tests
- [ ] TC-012: Edge Function - Follow-up Reminders (Manual Trigger)
- [ ] TC-013: Edge Function - Mouthwash Reminders Morning (Manual Trigger)
- [ ] TC-014: Edge Function - Mouthwash Reminders Evening (Manual Trigger)

### Notification Tests
- [ ] TC-015: Push Notification - Foreground Reception
- [ ] TC-016: Push Notification - Background Reception
- [ ] TC-017: Notification History View

### Integration Tests
- [ ] TC-018: 2-Day Advance Timing Test
- [ ] TC-019: Phone Call Functionality from Admin Screen
- [ ] TC-020: End-to-End Integration Test

### Overall Test Results

**Total Tests:** 20
**Passed:** ___
**Failed:** ___
**Blocked:** ___
**Not Executed:** ___

**Pass Rate:** ___%

---

## Issues Found

| ID | Test Case | Severity | Description | Status |
|----|-----------|----------|-------------|--------|
| 1  |           |          |             |        |
| 2  |           |          |             |        |
| 3  |           |          |             |        |

---

## Sign-off

**Tester Name:** _______________________

**Date:** _______________________

**Signature:** _______________________
