#!/bin/bash

DEVICE_ID="9620589237000P2"

echo "🔔 Live Notification Test"
echo "========================"
echo ""

# Clear logs
echo "1️⃣ Clearing device logs..."
adb -s $DEVICE_ID logcat -c

# Start monitoring logs in background
echo "2️⃣ Starting log monitor..."
adb -s $DEVICE_ID logcat | grep -i "fcm\|firebase\|notification\|flutter" &
LOGCAT_PID=$!

sleep 2

# Send notification
echo ""
echo "3️⃣ Sending test notification..."
curl -s -X POST "https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "new_assignment",
    "data": {
      "doctor_id": "781fff43-9453-4a2c-88ae-c877bd227067",
      "patient_name": "🚨 URGENT TEST - CHECK NOW"
    }
  }'

echo ""
echo ""
echo "4️⃣ Watching device logs for 15 seconds..."
echo "   (Look for FCM messages, notification displays, etc.)"
echo ""

sleep 15

# Stop log monitoring
kill $LOGCAT_PID 2>/dev/null

echo ""
echo "========================"
echo "✅ Test complete!"
echo ""
echo "Did you see:"
echo "  □ Notification appear on device?"
echo "  □ FCM message received in logs?"
echo "  □ Notification sound/vibration?"
