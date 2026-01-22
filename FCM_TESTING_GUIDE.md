# FCM Notification Testing Guide

## Project Setup

Your app uses **one Firebase project** (`doctorapp-7f7e1`) for both:
- **Doctor App** (package: `com.sagha.doctor`)
- **Patient App** (package: `com.sagha.patient`)

## Quick Start

### Step 1: Install Dependencies
```bash
npm install
```

### Step 2: Download Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **doctorapp-7f7e1**
3. Click the gear icon ⚙️ → **Project Settings**
4. Navigate to **Service Accounts** tab
5. Click **Generate New Private Key**
6. Save the downloaded JSON file as `firebase-service-account.json` in this directory

### Step 3: Run Tests

#### Test Doctor App
```bash
npm run test-doctor
```

#### Test Patient App
```bash
npm run test-patient
```
*Note: Update the FCM token in `test_fcm_notification_patient.js` first*

#### Test Both Apps
```bash
npm run test-both
```

## What the Test Does

The script will send 5 different test notifications to your device:

1. **Simple Test** - Basic notification to verify FCM is working
2. **Follow-up Reminder** - Simulates a patient follow-up notification
3. **Appointment Reminder** - Simulates an upcoming appointment
4. **New Patient Assignment** - Simulates a new patient being assigned
5. **Prescription Reminder** - Simulates a prescription refill reminder

## Expected Results

✅ **Success**: You should see:
- Console output showing each notification was sent
- Notifications appearing on your device
- Ability to tap notifications to open the app

❌ **If notifications don't appear**:
- Make sure the app has notification permission
- Check that the app is running or in background
- Verify the FCM token is correct
- Check device notification settings

## Troubleshooting

### Error: "ENOENT: no such file or directory, open './firebase-service-account.json'"
- You need to download the service account key from Firebase Console
- Save it as `firebase-service-account.json` in the project root

### Error: "Requested entity was not found"
- Check that your Firebase project ID is correct
- Verify the service account key is from the correct project

### Error: "The registration token is not a valid FCM registration token"
- The FCM token might be expired
- Get a fresh token from the app console log
- Update the FCM_TOKEN in test_fcm_notification.js

### Notifications not showing on device
- Check app notification permissions in device settings
- Make sure the app is installed and has run at least once
- Try restarting the app
- Check if Do Not Disturb is enabled on your device

## Testing Different States

### Foreground (App Open)
1. Keep the app open
2. Run the test script
3. Notifications should appear as in-app alerts

### Background (App Minimized)
1. Open the app
2. Minimize/go to home screen
3. Run the test script
4. Notifications should appear in notification tray

### Terminated (App Closed)
1. Close the app completely
2. Run the test script
3. Notifications should appear in notification tray
4. Tapping should open the app

## Next Steps

Once testing is successful:

1. **Integrate with Supabase Edge Functions**
   - Create edge functions to send notifications
   - Trigger on database events (new appointment, etc.)

2. **Set Up Scheduled Notifications**
   - Use Supabase cron jobs
   - Send daily follow-up reminders
   - Send appointment reminders

3. **Add Notification Handling in App**
   - Handle different notification types
   - Navigate to specific screens on tap
   - Show appropriate UI based on notification data

## Your FCM Tokens

### Doctor App Token (Already Configured)
```
fgpu-Y7Ryu7IQ63YT6EzD:APA91bEsNynkP_yFbdaYapawM9khk5m1ijB56XqUGd7PKRYdq-514PxLpi1LG11zgijLTJNcNCNPtYu9coKmW9PaDngtJriAQzuZ6B78NUWe5gZikCh9aHs
```
✅ This token is configured in `test_fcm_notification.js`

### Patient App Token
❗ **To test patient app:**
1. Run the patient app
2. Check console for FCM token
3. Update `FCM_TOKEN` in `test_fcm_notification_patient.js`

## Testing Workflow

### Doctor App Notifications
The doctor app receives:
- Follow-up reminders
- Appointment reminders
- New patient assignments
- Prescription reminders

### Patient App Notifications
The patient app receives:
- Appointment reminders
- Follow-up reminders
- Prescription ready notifications
- Treatment plan updates
