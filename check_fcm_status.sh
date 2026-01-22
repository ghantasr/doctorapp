#!/bin/bash

echo "🔍 FCM Notification Diagnostic Tool"
echo "===================================="
echo ""

USER_ID="781fff43-9453-4a2c-88ae-c877bd227067"
EDGE_FUNCTION_URL="https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification"

echo "📋 Your User ID: $USER_ID"
echo ""

echo "Step 1: Checking if FCM token exists in database..."
echo "❌ Cannot check database directly without psql"
echo "   Solution: Check Supabase dashboard -> Table Editor -> fcm_tokens"
echo "   Look for user_id: $USER_ID"
echo ""

echo "Step 2: Testing edge function..."
RESPONSE=$(curl -s -X POST "$EDGE_FUNCTION_URL" \
  -H 'Content-Type: application/json' \
  -d "{
    \"type\": \"new_assignment\",
    \"data\": {
      \"doctor_id\": \"$USER_ID\",
      \"patient_name\": \"🔔 Diagnostic Test $(date +%H:%M:%S)\"
    }
  }")

echo "Response: $RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✅ Edge function is working"
    NOTIFICATIONS_SENT=$(echo "$RESPONSE" | grep -o '"notificationsSent":[0-9]*' | cut -d':' -f2)
    if [ "$NOTIFICATIONS_SENT" = "1" ]; then
        echo "✅ Notification was sent to Firebase"
        echo ""
        echo "⚠️  If you didn't receive notification on your device:"
        echo "   1. Open Settings -> Apps -> Doctor App -> Notifications"
        echo "   2. Ensure 'All Doctor App notifications' is ON"
        echo "   3. Check 'Default Notifications' channel is enabled"
        echo "   4. Disable Do Not Disturb mode"
        echo "   5. Check if app has notification permission in Android settings"
    else
        echo "❌ No notifications were sent (token might not be in database)"
        echo "   → Launch the app and check logs for FCM token registration"
    fi
else
    echo "❌ Edge function error"
fi

echo ""
echo "Step 3: Device Notification Settings Checklist"
echo "----------------------------------------------"
echo "On your Android device (9620589237000P2):"
echo ""
echo "□ Settings -> Notifications -> App notifications -> Doctor App"
echo "  └─ Should show 'All Doctor App notifications' as ON"
echo ""
echo "□ Check notification categories:"
echo "  └─ 'Default Notifications' should be enabled"
echo ""
echo "□ Do Not Disturb:"
echo "  └─ Swipe down notification panel and check DND is OFF"
echo ""
echo "□ App notification permission:"
echo "  └─ Settings -> Apps -> Doctor App -> Permissions -> Notifications"
echo "  └─ Should be 'Allowed'"
echo ""
echo "Step 4: App Launch Checklist"
echo "----------------------------"
echo "When you launch the app with:"
echo "flutter run --flavor doctor --target lib/main_doctor.dart -d 9620589237000P2"
echo ""
echo "Watch for these log messages:"
echo "□ 'User granted notification permission'"
echo "□ '🔑 FCM Token Generated: ...' "
echo "□ '📋 User ID: $USER_ID'"
echo "□ '✅ FCM token saved to database successfully!'"
echo ""
echo "If you see '⚠️ Cannot save FCM token - user not authenticated':"
echo "→ App is trying to save token before login completes"
echo "→ Token will be saved after you login"
echo ""
echo "======================================"
echo "Quick Test: Send notification now"
echo "======================================"
read -p "Press Enter to send another test notification..."

curl -X POST "$EDGE_FUNCTION_URL" \
  -H 'Content-Type: application/json' \
  -d "{
    \"type\": \"new_assignment\",
    \"data\": {
      \"doctor_id\": \"$USER_ID\",
      \"patient_name\": \"📱 Manual Test - $(date +%H:%M:%S)\"
    }
  }"

echo ""
echo ""
echo "Did you receive the notification on your device? (check phone now)"
