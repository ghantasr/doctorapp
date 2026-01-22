#!/bin/bash

# Complete FCM Notification Test & Troubleshooting Script
# Run this to send a test notification and check device status

USER_ID="781fff43-9453-4a2c-88ae-c877bd227067"
DEVICE_ID="9620589237000P2"

echo "🔔 FCM NOTIFICATION TEST SUITE"
echo "=============================="
echo ""

# Check if app is running
echo "1️⃣ Checking if app is installed and running..."
adb -s $DEVICE_ID shell "pm list packages | grep com.sagha.doctor"
if [ $? -eq 0 ]; then
    echo "   ✅ App is installed"
else
    echo "   ❌ App is NOT installed!"
    exit 1
fi

# Check notification permissions
echo ""
echo "2️⃣ Checking notification permissions..."
adb -s $DEVICE_ID shell "dumpsys notification | grep -A 5 com.sagha.doctor"

# Launch the app
echo ""
echo "3️⃣ Launching the app..."
adb -s $DEVICE_ID shell am start -n com.sagha.doctor/com.healthcare.doctorapp.MainActivity
sleep 3

# Send test notification
echo ""
echo "4️⃣ Sending test notification..."
RESPONSE=$(curl -s -X POST 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification' \
  -H 'Content-Type: application/json' \
  -d "{
    \"type\": \"new_assignment\",
    \"data\": {
      \"doctor_id\": \"$USER_ID\",
      \"patient_name\": \"🧪 AUTOMATED TEST - $(date +%H:%M:%S)\"
    }
  }")

echo "   Response: $RESPONSE"

# Monitor logcat for FCM messages
echo ""
echo "5️⃣ Monitoring device logs for 10 seconds..."
echo "   (Looking for FCM/notification messages...)"
timeout 10 adb -s $DEVICE_ID logcat | grep -i "fcm\|firebase\|notification" || echo "   No FCM logs detected"

echo ""
echo "=============================="
echo "✅ Test complete!"
echo ""
echo "If you didn't receive the notification, try:"
echo "1. Open Settings > Apps > Doctor App > Notifications"
echo "2. Ensure all notification categories are enabled"
echo "3. Check Do Not Disturb is OFF"
echo "4. Try restarting the app"
echo "5. Check notification history: Settings > Notifications > Notification history"
