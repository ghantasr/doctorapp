# Complete Notification System Setup Guide

## What Was Wrong

Based on your database data, here are the issues I found:

### 🔴 **Critical Issues:**

1. **Notifications are being logged but NOT sent** 
   - Status shows "no_token" or "pending" 
   - The Edge Functions have TODO comments where actual FCM sending should happen
   - No actual push notifications are being delivered to devices

2. **All users have the same FCM token**
   - All 3 users have token: `ezgpu-Y7Ryu7IQ63YT6EzD:APA91b...`
   - This indicates test environment with one shared device
   - In production, each device should have a unique token

3. **Database schema limitation**
   - `user_fcm_tokens` table only supports ONE device per user
   - Multi-device support not possible with current schema

4. **No FCM sending implementation**
   - Edge Functions log notifications but don't send them
   - Firebase Admin SDK integration is missing

---

## 📋 Complete Fix Implementation

I've created the following files to fix all issues:

### 1. **supabase_notification_fixes.sql** 
   - Fixes database schema to support multiple devices per user
   - Adds device tracking and token lifecycle management
   - Adds retry mechanism for failed notifications
   - Updates all notification functions to use 'pending' status
   - Creates cleanup function for old tokens

### 2. **supabase_edge_function_send_pending_notifications.ts**
   - New Edge Function that processes all pending notifications
   - Sends actual FCM push notifications
   - Updates notification status (sent/failed)
   - Deactivates invalid tokens automatically
   - Uses simple FCM HTTP API (no complex JWT signing needed)

### 3. **supabase_edge_function_send_fcm_simple.ts**
   - Standalone FCM sending function
   - Can be called directly to send a single notification
   - Uses legacy FCM HTTP API for simplicity

### 4. **NOTIFICATION_TROUBLESHOOTING.md**
   - Comprehensive checklist to verify your setup
   - SQL queries to diagnose issues
   - Common problems and solutions

---

## 🚀 Step-by-Step Implementation

### Step 1: Apply Database Fixes

Run the SQL migration in Supabase SQL Editor:

```bash
# In Supabase Dashboard:
# 1. Go to SQL Editor
# 2. Copy contents of supabase_notification_fixes.sql
# 3. Paste and execute
```

**What this does:**
- ✅ Updates `user_fcm_tokens` to support multiple devices
- ✅ Adds `device_identifier` and `is_active` columns
- ✅ Updates all notification functions to use 'pending' status
- ✅ Adds retry mechanism columns
- ✅ Creates helper functions for token management

**Verify it worked:**

```sql
-- Check schema update
\d user_fcm_tokens

-- Should show columns: id, user_id, fcm_token, device_identifier, is_active, etc.
```

### Step 2: Get Firebase Server Key

You need the FCM Server Key (also called "Legacy Server Key"):

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Project Settings** (gear icon)
4. Go to **Cloud Messaging** tab
5. Under "Cloud Messaging API (Legacy)", copy the **Server key**
   - It looks like: `AAAA...` (about 150+ characters)
   - If disabled, enable "Cloud Messaging API (Legacy)" in Google Cloud Console

**⚠️ Important:** Do NOT use the "Sender ID" - you need the actual Server Key

### Step 3: Deploy Edge Functions

#### 3.1 Install Supabase CLI (if not already installed)

```bash
# macOS/Linux
brew install supabase/tap/supabase

# Windows (via Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

#### 3.2 Login and Link Project

```bash
# Login to Supabase
supabase login

# Link to your project (get project ref from Supabase dashboard URL)
supabase link --project-ref YOUR_PROJECT_REF
```

#### 3.3 Create Function Directories

```bash
# Create functions directory if it doesn't exist
mkdir -p supabase/functions/send-pending-notifications
mkdir -p supabase/functions/send-fcm-simple

# Copy the TypeScript files
cp supabase_edge_function_send_pending_notifications.ts supabase/functions/send-pending-notifications/index.ts
cp supabase_edge_function_send_fcm_simple.ts supabase/functions/send-fcm-simple/index.ts
```

#### 3.4 Set Environment Variables

```bash
# Set Supabase URL and Service Role Key
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Set FCM Server Key (the one you got from Firebase Console)
supabase secrets set FCM_SERVER_KEY=AAAA....your-fcm-server-key
```

**To get your Supabase Service Role Key:**
1. Supabase Dashboard → Settings → API
2. Copy the "service_role" key (not the "anon" key)

#### 3.5 Deploy Functions

```bash
# Deploy the send-pending-notifications function
supabase functions deploy send-pending-notifications

# Deploy the send-fcm-simple function (optional)
supabase functions deploy send-fcm-simple
```

### Step 4: Schedule the Pending Notifications Function

You need to call `send-pending-notifications` regularly (every 5-15 minutes) to process pending notifications.

#### Option A: Use Supabase Cron (Paid Plan Only)

```bash
# Run every 10 minutes
supabase functions schedule send-pending-notifications --cron "*/10 * * * *"
```

#### Option B: Use GitHub Actions (Free)

Create `.github/workflows/send-notifications.yml`:

```yaml
name: Process Pending Notifications

on:
  schedule:
    # Run every 10 minutes
    - cron: '*/10 * * * *'
  # Allow manual trigger
  workflow_dispatch:

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

Then add secrets in GitHub:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anon key (from Settings → API)

#### Option C: Use cron-job.org (Free)

1. Go to [cron-job.org](https://cron-job.org)
2. Create free account
3. Create new cron job:
   - URL: `https://YOUR_PROJECT.supabase.co/functions/v1/send-pending-notifications`
   - Schedule: Every 10 minutes
   - Add header: `Authorization: Bearer YOUR_ANON_KEY`

### Step 5: Test the System

#### 5.1 Create a Test Notification

```sql
-- Create a test pending notification
INSERT INTO notification_logs (
  user_id,
  notification_type,
  title,
  body,
  data,
  status
)
VALUES (
  'YOUR_USER_ID',  -- Replace with a user ID that has an FCM token
  'test',
  'Test Notification',
  'This is a test notification from the updated system',
  '{"test": "true"}'::jsonb,
  'pending'
);
```

#### 5.2 Manually Trigger the Function

```bash
# Get your Supabase URL and Anon Key from dashboard
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-pending-notifications' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json'
```

#### 5.3 Check the Result

```sql
-- Check if notification was sent
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

**Expected Results:**
- Status should change from 'pending' to 'sent'
- User should receive notification on their device
- If status is 'failed', check error_message column

#### 5.4 Check Edge Function Logs

In Supabase Dashboard:
1. Go to **Edge Functions**
2. Click on `send-pending-notifications`
3. Click **Logs** tab
4. Check for any errors

### Step 6: Update Existing Edge Functions

Update the existing follow-up and mouthwash reminder functions to use the new system:

The functions already create notification logs with 'pending' status (after applying the SQL fixes), so they will automatically be picked up by `send-pending-notifications`.

No code changes needed - the SQL migration handles this!

---

## 🔄 How It Works Now

### Flow for New Assignment Notifications:

1. **Patient is assigned to doctor** → Triggers database trigger
2. **Trigger creates notification log** with status 'pending'
3. **send-pending-notifications runs** (every 10 mins via cron)
4. **Function gets user's FCM token(s)** from user_fcm_tokens
5. **Sends notification via FCM API**
6. **Updates status** to 'sent' or 'failed'
7. **User receives notification** on their device

### Flow for Follow-up Reminders:

1. **Edge Function runs** (scheduled daily at 8 AM)
2. **Gets patients with follow-up in 2 days**
3. **Creates notification logs** with status 'pending'
4. **send-pending-notifications processes them** (within 10 mins)
5. **Sends to patient's device(s)**

---

## ✅ Verification Checklist

After implementation, verify:

### Database
- [ ] Run `supabase_notification_fixes.sql` successfully
- [ ] `user_fcm_tokens` table has `id`, `is_active`, `device_identifier` columns
- [ ] All notification logs have status 'pending', 'sent', 'failed', or 'no_token'

### Edge Functions
- [ ] `send-pending-notifications` function deployed
- [ ] FCM_SERVER_KEY secret is set
- [ ] Function runs without errors (check logs)

### Scheduling
- [ ] Cron job configured (GitHub Actions, cron-job.org, or Supabase cron)
- [ ] Cron job runs every 10-15 minutes
- [ ] Can manually trigger function successfully

### End-to-End Test
- [ ] Create test notification with status 'pending'
- [ ] Wait for cron to run (or trigger manually)
- [ ] Notification status changes to 'sent'
- [ ] User receives notification on device

---

## 🐛 Troubleshooting

### Issue: "FCM_SERVER_KEY not configured"

**Solution:**
```bash
# Set the FCM Server Key
supabase secrets set FCM_SERVER_KEY=YOUR_FCM_SERVER_KEY

# Verify it's set
supabase secrets list
```

### Issue: "No FCM token found for user"

**Cause:** User hasn't logged into the app or token wasn't saved

**Solution:**
1. Make sure user has installed the app
2. User must login at least once
3. Check if token was saved:

```sql
SELECT * FROM user_fcm_tokens WHERE user_id = 'USER_ID';
```

### Issue: Notifications stay in 'pending' status

**Possible causes:**
1. Cron job not running
2. FCM_SERVER_KEY not set
3. Edge Function has errors

**Debug:**
```bash
# Manually trigger the function and check output
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-pending-notifications' \
  -H 'Authorization: Bearer YOUR_ANON_KEY'
```

Check Edge Function logs in Supabase Dashboard

### Issue: "Invalid FCM token" error

**Cause:** User uninstalled app or token expired

**Solution:** The system automatically deactivates invalid tokens. User needs to:
1. Reinstall the app
2. Login again
3. New token will be registered

---

## 📊 Monitoring

### Check Notification Statistics

```sql
-- View notification statistics
SELECT * FROM notification_statistics
WHERE date >= CURRENT_DATE - 7
ORDER BY date DESC, notification_type;
```

### Check Pending Notifications

```sql
-- See what's waiting to be sent
SELECT 
  id,
  user_id,
  notification_type,
  title,
  status,
  sent_at,
  EXTRACT(MINUTE FROM NOW() - sent_at) as minutes_pending
FROM notification_logs
WHERE status = 'pending'
ORDER BY sent_at;
```

### Check Failed Notifications

```sql
-- See failures
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

---

## 🎯 Summary

**What you need to do:**

1. ✅ Run `supabase_notification_fixes.sql` in Supabase SQL Editor
2. ✅ Get FCM Server Key from Firebase Console
3. ✅ Deploy `send-pending-notifications` Edge Function
4. ✅ Set FCM_SERVER_KEY secret
5. ✅ Set up cron job (GitHub Actions, cron-job.org, or Supabase)
6. ✅ Test with a manual notification
7. ✅ Verify users receive notifications

**After this, your notification system will:**
- ✅ Actually send FCM push notifications (not just log them)
- ✅ Support multiple devices per user
- ✅ Automatically retry failed notifications
- ✅ Clean up invalid tokens
- ✅ Provide statistics and monitoring

**Need help?** Check `NOTIFICATION_TROUBLESHOOTING.md` for detailed verification steps and common issues.
