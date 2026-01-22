## FCM Notification Debugging Guide

### Current Status
✅ FCM Token Generated: `ezgpu-Y7Ryu7IQ63YT6EzD...`
✅ User ID: `781fff43-9453-4a2c-88ae-c877bd227067`
✅ Notification Permission: Granted
✅ Token Saved in Database: Yes (duplicate key error confirms)
✅ Edge Function: Deployed and working (returned notificationsSent: 1)

### Why You Might Not See the Notification

1. **App State**: Notifications behave differently based on app state:
   - **Foreground**: Shows as local notification (should appear as banner)
   - **Background**: Shows as system notification
   - **Terminated**: Doesn't show until app restarts

2. **Android 13+ Notification Permission**: 
   - Must explicitly grant POST_NOTIFICATIONS permission (we added this)
   - Check: Settings > Apps > Doctor App > Notifications > Allowed

3. **Notification Channel**: 
   - Android requires notification channels
   - Our app uses "default_channel" which we created in code

4. **Device Settings**:
   - Do Not Disturb mode
   - Battery optimization killing background app
   - App-specific notification settings

### Steps to Test Properly

1. **Make sure the app is running** (either foreground or background)
2. **Check device settings**:
   - Settings > Apps > Doctor App > Notifications = ON
   - Settings > Sound & vibration > Do Not Disturb = OFF

3. **Send test notification while app is OPEN**:
```bash
curl -X POST 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification' \\
  -H 'Content-Type: application/json' \\
  -d '{
    "type": "new_assignment",
    "data": {
      "doctor_id": "781fff43-9453-4a2c-88ae-c877bd227067",
      "patient_name": "TEST - Check your phone!"
    }
  }'
```

4. **Check app logs** for "Foreground message:" or "Background message:"

### Device Validation Checklist
- [ ] App is installed and running
- [ ] Notification permission granted (check in app settings)
- [ ] Do Not Disturb is OFF
- [ ] Battery optimization allows background activity
- [ ] Notification channel is enabled

### Next Steps for User
1. Open the Doctor App on your device
2. Keep it open (foreground)
3. Have someone send the curl command above
4. You should see a local notification banner appear

If still no notification:
- Check Android notification settings
- Try uninstalling and reinstalling the app
- Check if other apps can send notifications
