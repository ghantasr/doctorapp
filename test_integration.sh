#!/bin/bash

echo "🧪 NOTIFICATION INTEGRATION TEST"
echo "================================="
echo ""

USER_ID="781fff43-9453-4a2c-88ae-c877bd227067"

echo "1️⃣  Testing New Assignment Notification..."
RESPONSE1=$(curl -s -X POST 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification' \
  -H 'Content-Type: application/json' \
  -d "{
    \"type\": \"new_assignment\",
    \"data\": {
      \"doctor_id\": \"$USER_ID\",
      \"patient_name\": \"Integration Test Patient\"
    }
  }")

echo "Response: $RESPONSE1"
echo ""

echo "2️⃣  Testing Follow-Up Reminder..."
RESPONSE2=$(curl -s -X POST 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification' \
  -H 'Content-Type: application/json' \
  -d "{
    \"type\": \"follow_up_reminder\",
    \"data\": {
      \"doctor_id\": \"$USER_ID\",
      \"patient_name\": \"John Doe\",
      \"follow_up_date\": \"2026-01-23\"
    }
  }")

echo "Response: $RESPONSE2"
echo ""

echo "3️⃣  Testing Appointment Reminder..."
RESPONSE3=$(curl -s -X POST 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification' \
  -H 'Content-Type: application/json' \
  -d "{
    \"type\": \"appointment_reminder\",
    \"data\": {
      \"user_id\": \"$USER_ID\",
      \"patient_name\": \"Jane Smith\",
      \"appointment_time\": \"2:30 PM Today\",
      \"is_doctor\": true
    }
  }")

echo "Response: $RESPONSE3"
echo ""

echo "================================="
echo "✅ Integration test complete!"
echo ""
echo "Check your device for 3 notifications:"
echo "  1. New Patient Assignment"
echo "  2. Follow-up Reminder"
echo "  3. Appointment Reminder"
