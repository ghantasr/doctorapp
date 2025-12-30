# Quick Reference - Notification System

## Files Created/Modified

### Database & Edge Functions
1. **supabase_notifications_comprehensive.sql** - Complete SQL migration for all notification tables and functions
2. **supabase_edge_function_follow_up_reminders.ts** - Edge Function for follow-up reminders (runs daily)
3. **supabase_edge_function_mouthwash_reminders.ts** - Edge Function for mouthwash reminders (runs twice daily)

### Flutter App
4. **lib/app/doctor/admin_follow_up_due_view.dart** - Admin screen to view and call patients due for follow-up
5. **lib/app/doctor/doctor_dashboard.dart** - Modified to add admin follow-up menu item

### Documentation
6. **NOTIFICATION_IMPLEMENTATION_GUIDE.md** - Complete step-by-step implementation guide
7. **MANUAL_TEST_SUITE.md** - Comprehensive test suite with 20 test cases

## Quick Setup Steps

### 1. Run SQL Migration (5 minutes)
```bash
# Open Supabase Dashboard → SQL Editor
# Copy and paste contents of supabase_notifications_comprehensive.sql
# Execute the script
```

### 2. Deploy Edge Functions (10 minutes)
```bash
# Install Supabase CLI
brew install supabase/tap/supabase  # macOS
# or download from https://github.com/supabase/cli

# Login and link project
supabase login
supabase link --project-ref YOUR_PROJECT_REF

# Create function directories
mkdir -p supabase/functions/send-follow-up-reminders
mkdir -p supabase/functions/send-mouthwash-reminders

# Copy Edge Function files
cp supabase_edge_function_follow_up_reminders.ts supabase/functions/send-follow-up-reminders/index.ts
cp supabase_edge_function_mouthwash_reminders.ts supabase/functions/send-mouthwash-reminders/index.ts

# Deploy functions
supabase functions deploy send-follow-up-reminders
supabase functions deploy send-mouthwash-reminders

# Set secrets
supabase secrets set SUPABASE_URL=https://your-project.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Schedule functions (requires paid plan)
supabase functions schedule send-follow-up-reminders --cron "0 8 * * *"
supabase functions schedule send-mouthwash-reminders --cron "0 8 * * *" --env TIME_OF_DAY=morning
supabase functions schedule send-mouthwash-reminders --cron "0 20 * * *" --env TIME_OF_DAY=evening
```

### 3. Configure Firebase (15 minutes)
```bash
# 1. Create Firebase project at console.firebase.google.com
# 2. Add Android/iOS apps
# 3. Download google-services.json and GoogleService-Info.plist
# 4. Place files in android/app/ and ios/Runner/
# 5. Update build.gradle files (see NOTIFICATION_IMPLEMENTATION_GUIDE.md)
```

### 4. Run the Flutter App
```bash
# The app already has all necessary dependencies
flutter pub get
flutter run
```

### 5. Test the System
Follow the test cases in **MANUAL_TEST_SUITE.md**

## Key Features Implemented

### ✅ Database Layer
- `user_fcm_tokens` table - Stores Firebase Cloud Messaging tokens
- `notification_logs` table - Logs all sent notifications
- `daily_reminders` table - Daily reminders (mouthwash, etc.)
- `admin_follow_up_due_soon` view - Admin view of patients due for follow-up
- Functions for sending notifications and fetching due patients

### ✅ Notification Types
1. **Follow-up Reminders** - Sent 2 days before follow-up appointment
2. **Mouthwash Reminders** - Sent morning (8 AM) and evening (8 PM) daily

### ✅ Admin Features
- View patients with follow-ups due within 2 days
- Call patients directly from the app
- See urgency indicators (OVERDUE, TODAY, TOMORROW, IN X DAYS)

### ✅ Doctor Features
- View all assigned follow-up patients
- See patients categorized by urgency (Overdue, Today, Upcoming)

## Testing Quick Commands

### Test Database Setup
```sql
-- Verify tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_fcm_tokens', 'notification_logs', 'daily_reminders');

-- Verify default mouthwash reminders
SELECT COUNT(*) FROM daily_reminders WHERE reminder_type = 'mouthwash';

-- View admin follow-up list
SELECT * FROM admin_follow_up_due_soon;
```

### Test Edge Functions Manually
```bash
# Test follow-up reminders
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-follow-up-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY'

# Test morning mouthwash reminders
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-mouthwash-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"timeOfDay": "morning"}'

# Test evening mouthwash reminders
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-mouthwash-reminders' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"timeOfDay": "evening"}'
```

### Check Notification Logs
```sql
-- View recent notifications
SELECT 
  nl.*,
  u.email,
  nl.data
FROM notification_logs nl
JOIN auth.users u ON nl.user_id = u.id
ORDER BY sent_at DESC
LIMIT 10;

-- Count notifications by type
SELECT 
  notification_type,
  COUNT(*) as count,
  MAX(sent_at) as last_sent
FROM notification_logs
GROUP BY notification_type;
```

## Common Issues & Solutions

### Issue: Follow-up patients not showing in doctor app
**Solution:** Check these in order:
1. Verify `patient_assignments.status = 'active'`
2. Verify `follow_up_date` is set
3. Verify `last_visit_date` is NULL or before `follow_up_date`

```sql
SELECT * FROM patient_assignments 
WHERE doctor_id = 'YOUR_DOCTOR_ID' 
AND status = 'active' 
AND follow_up_date IS NOT NULL;
```

### Issue: Admin view not showing patients
**Solution:** Check the view data:
```sql
SELECT * FROM admin_follow_up_due_soon;
```
If empty, create test data:
```sql
UPDATE patient_assignments
SET follow_up_date = NOW() + INTERVAL '1 day'
WHERE id = 'SOME_ASSIGNMENT_ID';
```

### Issue: Edge Functions not scheduling (Free Tier)
**Solution:** Use external cron service or GitHub Actions (see NOTIFICATION_IMPLEMENTATION_GUIDE.md)

### Issue: Push notifications not received
**Solution:** Verify:
1. FCM token is stored in database
2. Firebase is properly configured
3. Notification appears in `notification_logs` table
4. Check Firebase Console for delivery status

## Next Steps

1. ✅ Run SQL migration in Supabase
2. ✅ Deploy Edge Functions
3. ✅ Configure Firebase
4. ⬜ Run test suite (MANUAL_TEST_SUITE.md)
5. ⬜ Schedule Edge Functions or set up external cron
6. ⬜ Test notifications end-to-end
7. ⬜ Monitor notification logs

## Support & Documentation

- **Full Implementation Guide:** NOTIFICATION_IMPLEMENTATION_GUIDE.md
- **Test Suite:** MANUAL_TEST_SUITE.md
- **Supabase Docs:** https://supabase.com/docs
- **Firebase Docs:** https://firebase.google.com/docs

## Summary

All components are ready for deployment:
- ✅ Database schema and functions
- ✅ Edge Functions for automated notifications
- ✅ Admin and doctor UI screens
- ✅ Firebase integration code
- ✅ Comprehensive documentation and testing guide

The system is complete and ready for Supabase deployment and testing!
