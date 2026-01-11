# Notification System Implementation Checklist

Use this checklist to implement and verify the notification system fixes step by step.

---

## Phase 1: Understanding the Problem ✅

- [x] **Reviewed database data** - notification_logs show "no_token" or "pending" status
- [x] **Identified root cause** - Edge Functions log notifications but don't send them
- [x] **Understood schema limitation** - Only 1 device per user supported
- [x] **Reviewed solution files** - All fix files have been created

---

## Phase 2: Database Setup

### Step 1: Run Database Migration

- [ ] Open Supabase Dashboard
- [ ] Navigate to SQL Editor
- [ ] Copy contents of `supabase_notification_fixes.sql`
- [ ] Paste and execute the SQL script
- [ ] Verify no errors in execution

### Step 2: Verify Database Changes

Run these verification queries:

**Check user_fcm_tokens schema:**
```sql
\d user_fcm_tokens
```
- [ ] Table has `id` column (UUID, PRIMARY KEY)
- [ ] Table has `user_id` column (UUID, FOREIGN KEY)
- [ ] Table has `fcm_token` column (TEXT)
- [ ] Table has `device_identifier` column (TEXT)
- [ ] Table has `is_active` column (BOOLEAN)
- [ ] Table has `device_info` column (JSONB)
- [ ] Table has `created_at` column (TIMESTAMPTZ)
- [ ] Table has `updated_at` column (TIMESTAMPTZ)

**Check notification_logs schema:**
```sql
\d notification_logs
```
- [ ] Table has `retry_count` column (INTEGER)
- [ ] Table has `last_retry_at` column (TIMESTAMPTZ)

**Check new functions exist:**
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
  'get_user_fcm_tokens',
  'update_user_fcm_token',
  'cleanup_invalid_fcm_tokens'
);
```
- [ ] `get_user_fcm_tokens` function exists
- [ ] `update_user_fcm_token` function exists
- [ ] `cleanup_invalid_fcm_tokens` function exists

**Check view exists:**
```sql
SELECT table_name FROM information_schema.views 
WHERE table_name = 'notification_statistics';
```
- [ ] `notification_statistics` view exists

---

## Phase 3: Firebase Configuration

### Step 1: Get FCM Server Key

- [ ] Open [Firebase Console](https://console.firebase.google.com/)
- [ ] Select your project
- [ ] Click **Project Settings** (gear icon)
- [ ] Go to **Cloud Messaging** tab
- [ ] Find "Cloud Messaging API (Legacy)" section
- [ ] Copy the **Server key** (starts with `AAAA...`)
- [ ] Save it securely (you'll need it in the next step)

**Note:** If "Cloud Messaging API (Legacy)" is disabled:
- [ ] Go to Google Cloud Console
- [ ] Enable "Cloud Messaging API (Legacy)"
- [ ] Return to Firebase Console and copy the key

### Step 2: Verify Firebase App Configuration

- [ ] Android app has `google-services.json` in `android/app/` directory
- [ ] iOS app has `GoogleService-Info.plist` in `ios/Runner/` directory
- [ ] `pubspec.yaml` includes `firebase_core` dependency
- [ ] `pubspec.yaml` includes `firebase_messaging` dependency
- [ ] `pubspec.yaml` includes `flutter_local_notifications` dependency

---

## Phase 4: Supabase CLI Setup

### Step 1: Install Supabase CLI

Choose your platform:

**macOS/Linux:**
```bash
brew install supabase/tap/supabase
```
- [ ] Supabase CLI installed

**Windows (Scoop):**
```bash
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```
- [ ] Supabase CLI installed

**Verify installation:**
```bash
supabase --version
```
- [ ] Version number displays correctly

### Step 2: Login to Supabase

```bash
supabase login
```
- [ ] Successfully logged in to Supabase
- [ ] Browser authentication completed

### Step 3: Link Project

Get your project reference from Supabase Dashboard URL:
`https://app.supabase.com/project/YOUR_PROJECT_REF`

```bash
supabase link --project-ref YOUR_PROJECT_REF
```
- [ ] Project successfully linked
- [ ] Configuration file created locally

---

## Phase 5: Edge Function Deployment

### Step 1: Create Function Directories

```bash
# Create the directory structure
mkdir -p supabase/functions/send-pending-notifications
mkdir -p supabase/functions/send-fcm-simple
```
- [ ] Directories created successfully

### Step 2: Copy Function Files

```bash
# Copy the TypeScript files
cp supabase_edge_function_send_pending_notifications.ts supabase/functions/send-pending-notifications/index.ts
cp supabase_edge_function_send_fcm_simple.ts supabase/functions/send-fcm-simple/index.ts
```
- [ ] Files copied successfully
- [ ] Verified files exist in correct locations

### Step 3: Set Environment Variables

Get your Supabase credentials:
- **Service Role Key:** Supabase Dashboard → Settings → API → service_role key
- **FCM Server Key:** From Phase 3 Step 1

```bash
# Set Supabase URL
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT.supabase.co

# Set Service Role Key
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...your-service-role-key

# Set FCM Server Key
supabase secrets set FCM_SERVER_KEY=AAAA...your-fcm-server-key
```

**Verify secrets:**
```bash
supabase secrets list
```
- [ ] SUPABASE_URL is set
- [ ] SUPABASE_SERVICE_ROLE_KEY is set
- [ ] FCM_SERVER_KEY is set

### Step 4: Deploy Edge Functions

```bash
# Deploy send-pending-notifications
supabase functions deploy send-pending-notifications
```
- [ ] `send-pending-notifications` deployed successfully
- [ ] No deployment errors

```bash
# Deploy send-fcm-simple (optional)
supabase functions deploy send-fcm-simple
```
- [ ] `send-fcm-simple` deployed successfully (optional)

### Step 5: Verify Deployment

- [ ] Open Supabase Dashboard → Edge Functions
- [ ] Confirm `send-pending-notifications` appears in the list
- [ ] Function status shows as "Active"

---

## Phase 6: Scheduling Setup

Choose ONE of these options:

### Option A: GitHub Actions (Recommended for Free Tier)

Create `.github/workflows/send-notifications.yml`:

```yaml
name: Process Pending Notifications

on:
  schedule:
    - cron: '*/10 * * * *'  # Every 10 minutes
  workflow_dispatch:  # Allow manual trigger

jobs:
  send-notifications:
    runs-on: ubuntu-latest
    steps:
      - name: Send Pending Notifications
        run: |
          curl -X POST '${{ secrets.SUPABASE_URL }}/functions/v1/send-pending-notifications' \
            -H 'Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}' \
            -H 'Content-Type: application/json'
```

**Then in GitHub:**
- [ ] Go to repository → Settings → Secrets and variables → Actions
- [ ] Add secret: `SUPABASE_URL` = `https://YOUR_PROJECT.supabase.co`
- [ ] Add secret: `SUPABASE_ANON_KEY` = your anon key from Supabase Dashboard
- [ ] Commit and push the workflow file
- [ ] Verify workflow appears in Actions tab
- [ ] Manually trigger workflow to test

### Option B: cron-job.org (Alternative)

- [ ] Go to [cron-job.org](https://cron-job.org) and create account
- [ ] Create new cron job
- [ ] Set URL: `https://YOUR_PROJECT.supabase.co/functions/v1/send-pending-notifications`
- [ ] Set schedule: Every 10 minutes (`*/10 * * * *`)
- [ ] Add header: `Authorization: Bearer YOUR_ANON_KEY`
- [ ] Save and enable the job
- [ ] Verify first run succeeds

### Option C: Supabase Cron (Paid Plans Only)

```bash
supabase functions schedule send-pending-notifications --cron "*/10 * * * *"
```
- [ ] Schedule created successfully
- [ ] Verify in Supabase Dashboard

---

## Phase 7: Testing

### Test 1: Manual Function Trigger

```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-pending-notifications' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json'
```
- [ ] Function returns success response
- [ ] No errors in response
- [ ] Check Edge Function logs in Supabase Dashboard

### Test 2: Create Test Notification

Get a user_id that has an FCM token:
```sql
SELECT user_id FROM user_fcm_tokens WHERE is_active = true LIMIT 1;
```

Create test notification:
```sql
INSERT INTO notification_logs (
  user_id,
  notification_type,
  title,
  body,
  data,
  status
)
VALUES (
  'USER_ID_HERE',  -- Replace with actual user_id
  'test',
  'Test Notification',
  'This is a test notification to verify the system works',
  '{"test": "true"}'::jsonb,
  'pending'
);
```
- [ ] Notification created successfully
- [ ] Appears in notification_logs table

### Test 3: Wait for Processing

Wait 10 minutes (or manually trigger function), then check:

```sql
SELECT 
  id,
  title,
  body,
  status,
  error_message,
  sent_at
FROM notification_logs
WHERE notification_type = 'test'
ORDER BY sent_at DESC
LIMIT 1;
```
- [ ] Status changed from 'pending' to 'sent'
- [ ] error_message is null
- [ ] sent_at timestamp is recent

### Test 4: Verify Device Received Notification

- [ ] User received notification on their device
- [ ] Notification title matches
- [ ] Notification body matches
- [ ] Tapping notification works (if navigation implemented)

---

## Phase 8: Monitoring Setup

### Step 1: Create Monitoring Dashboard

Save these queries for regular monitoring:

**Current Status:**
```sql
SELECT 
  status,
  COUNT(*) as count,
  MAX(sent_at) as last_occurrence
FROM notification_logs
WHERE sent_at >= NOW() - INTERVAL '24 hours'
GROUP BY status;
```

**Pending Notifications:**
```sql
SELECT 
  id,
  notification_type,
  title,
  EXTRACT(MINUTE FROM NOW() - sent_at) as minutes_pending
FROM notification_logs
WHERE status = 'pending'
ORDER BY sent_at;
```

**Failed Notifications:**
```sql
SELECT 
  id,
  user_id,
  notification_type,
  title,
  error_message,
  sent_at
FROM notification_logs
WHERE status = 'failed'
  AND sent_at >= NOW() - INTERVAL '24 hours'
ORDER BY sent_at DESC;
```

**Daily Statistics:**
```sql
SELECT * FROM notification_statistics
WHERE date >= CURRENT_DATE - 7
ORDER BY date DESC, notification_type;
```

- [ ] Saved monitoring queries for future use
- [ ] Tested each query successfully

### Step 2: Set Up Alerts (Optional)

Consider setting up alerts for:
- [ ] High number of failed notifications (>10 per hour)
- [ ] Pending notifications older than 30 minutes
- [ ] Edge Function errors

---

## Phase 9: Production Verification

### Verify User Experience

- [ ] Doctors receive "New Patient Assignment" notifications when patients are assigned
- [ ] Patients receive follow-up reminders 2 days before appointment
- [ ] Patients receive mouthwash reminders (morning and evening)
- [ ] Notifications appear correctly on both Android and iOS
- [ ] Notification taps navigate to correct screens

### Verify Data Integrity

```sql
-- Check all users with tokens are receiving notifications
SELECT 
  uft.user_id,
  COUNT(DISTINCT nl.id) as notification_count,
  MAX(nl.sent_at) as last_notification
FROM user_fcm_tokens uft
LEFT JOIN notification_logs nl ON nl.user_id = uft.user_id
WHERE uft.is_active = true
GROUP BY uft.user_id;
```
- [ ] Users with tokens are receiving notifications
- [ ] No users stuck with 0 notifications when they should receive them

### Verify Performance

- [ ] Edge Function completes within 30 seconds (check logs)
- [ ] Database queries are fast (< 1 second)
- [ ] No timeout errors in Edge Function logs
- [ ] Cron job runs reliably every 10 minutes

---

## Phase 10: Documentation & Handoff

### Update Team Documentation

- [ ] Share `NOTIFICATION_QUICK_START.md` with team
- [ ] Add monitoring queries to team wiki/docs
- [ ] Document FCM Server Key location (secure vault)
- [ ] Document cron job setup (GitHub Actions, cron-job.org, etc.)

### Knowledge Transfer

- [ ] Team knows how to check notification status
- [ ] Team knows how to check Edge Function logs
- [ ] Team knows how to manually trigger function for testing
- [ ] Team knows how to troubleshoot common issues

---

## ✅ Final Verification

All green? Your notification system is ready!

- [ ] Database schema updated for multi-device support
- [ ] Edge Functions deployed and working
- [ ] FCM Server Key configured
- [ ] Cron job running every 10 minutes
- [ ] Test notifications sent successfully
- [ ] Production users receiving notifications
- [ ] Monitoring queries ready
- [ ] Team trained on the system

---

## 🎉 Success Criteria

You can mark this complete when:

1. ✅ Test notification sent and received on device
2. ✅ Real notification sent and received by user
3. ✅ Status changes from 'pending' to 'sent' automatically
4. ✅ No notifications stuck in 'pending' for > 15 minutes
5. ✅ Edge Function logs show no errors
6. ✅ Cron job runs reliably

---

## 📞 Need Help?

If you encounter issues:

1. Check `NOTIFICATION_TROUBLESHOOTING.md` for common problems
2. Review Edge Function logs in Supabase Dashboard
3. Run diagnostic queries from Phase 8
4. Verify all secrets are set correctly
5. Check Firebase Console for FCM delivery logs

---

**Good luck with your implementation! 🚀**
