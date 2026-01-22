#!/bin/bash

DEVICE_ID="9620589237000P2"
USER_ID="781fff43-9453-4a2c-88ae-c877bd227067"

echo "🔍 COMPLETE NOTIFICATION DIAGNOSTIC"
echo "===================================="
echo ""

# Check 1: App installation
echo "1️⃣ Checking app installation..."
adb -s $DEVICE_ID shell dumpsys package com.sagha.doctor | grep -E "versionName|versionCode|Package \[" | head -3
if [ $? -eq 0 ]; then
    echo "   ✅ Doctor app is installed"
else
    echo "   ❌ Doctor app NOT installed!"
    exit 1
fi
echo ""

# Check 2: Notification permission
echo "2️⃣ Checking notification permission..."
NOTIF_STATUS=$(adb -s $DEVICE_ID shell dumpsys notification | grep "com.sagha.doctor" | grep "importance=" | head -1)
echo "   $NOTIF_STATUS"
if echo "$NOTIF_STATUS" | grep -q "importance=DEFAULT\|importance=HIGH"; then
    echo "   ✅ Notifications are enabled"
else
    echo "   ⚠️  Check notification permissions in Settings"
fi
echo ""

# Check 3: Google Play Services (required for FCM)
echo "3️⃣ Checking Google Play Services..."
GPS_VERSION=$(adb -s $DEVICE_ID shell dumpsys package com.google.android.gms | grep versionName | head -1)
echo "   $GPS_VERSION"
if [ -n "$GPS_VERSION" ]; then
    echo "   ✅ Google Play Services installed"
else
    echo "   ❌ Google Play Services NOT found (FCM won't work!)"
fi
echo ""

# Check 4: App is running
echo "4️⃣ Checking if app is running..."
APP_PID=$(adb -s $DEVICE_ID shell pidof com.sagha.doctor)
if [ -n "$APP_PID" ]; then
    echo "   ✅ App is running (PID: $APP_PID)"
else
    echo "   ⚠️  App is NOT running - launching now..."
    adb -s $DEVICE_ID shell am start -n com.sagha.doctor/com.healthcare.doctorapp.MainActivity
    sleep 3
fi
echo ""

# Check 5: Firebase initialization logs
echo "5️⃣ Checking Firebase/FCM logs..."
echo "   Looking for FCM token registration..."
FCM_LOGS=$(adb -s $DEVICE_ID logcat -d | grep -i "fcm token\|firebase" | tail -5)
if [ -n "$FCM_LOGS" ]; then
    echo "$FCM_LOGS"
else
    echo "   ⚠️  No FCM logs found - app may not have initialized Firebase"
fi
echo ""

# Check 6: Do Not Disturb
echo "6️⃣ Checking Do Not Disturb status..."
DND_STATUS=$(adb -s $DEVICE_ID shell settings get global zen_mode)
if [ "$DND_STATUS" = "0" ]; then
    echo "   ✅ Do Not Disturb is OFF"
else
    echo "   ⚠️  Do Not Disturb is ON - this may block notifications"
fi
echo ""

# Check 7: Send test notification with live monitoring
echo "7️⃣ Sending test notification with live monitoring..."
echo "   Clearing logs..."
adb -s $DEVICE_ID logcat -c

echo "   Starting log monitor..."
adb -s $DEVICE_ID logcat *:E FirebaseMessaging:D FirebaseInstanceId:D flutter:D | grep -v "\.so" &
LOGCAT_PID=$!

sleep 2

echo "   Sending notification via edge function..."
RESPONSE=$(curl -s -X POST "https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"new_assignment\",
    \"data\": {
      \"doctor_id\": \"$USER_ID\",
      \"patient_name\": \"🔔 DIAGNOSTIC TEST $(date +%H:%M:%S)\"
    }
  }")

echo "   Response: $RESPONSE"
echo ""
echo "   Monitoring device for 10 seconds..."
echo "   (Watch for FCM message delivery...)"
sleep 10

kill $LOGCAT_PID 2>/dev/null

echo ""
echo "===================================="
echo "✅ Diagnostic complete!"
echo ""
echo "📋 NEXT STEPS:"
echo ""
echo "If notifications still don't appear:"
echo "1. Restart the app completely (kill and relaunch)"
echo "2. Check: Settings > Apps > Doctor App > Notifications"
echo "3. Ensure 'Default Notifications' channel is enabled"
echo "4. Check notification history: Settings > Notifications > Notification history"
echo "5. Try rebooting the device"
echo ""
echo "To view full device logs:"
echo "  adb -s $DEVICE_ID logcat | grep -i fcm"
