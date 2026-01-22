#!/bin/bash

# Direct Firebase Cloud Messaging API test
# This bypasses our edge function and tests FCM directly

FCM_TOKEN="ezgpu-Y7Ryu7IQ63YT6EzD:APA91bEsNynkP_yFbdaYapawM9khk5m1ijB56XqUGd7PKRYdq-514PxLpi1LG11zgijLTJNcNCNPtYu9coKmW9PaDngtJriAQzuZ6B78NUWe5gZikCh9aHs"
PROJECT_ID="doctorapp-7f7e1"

echo "🚀 Sending direct FCM notification..."
echo "📱 Token: ${FCM_TOKEN:0:30}..."
echo ""

# Note: This requires Firebase Server Key (legacy API)
# We'll use the edge function instead with proper OAuth2

curl -X POST "https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoYmtjeHVhYXRxdWV2d3RxeGZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzUwNjY5MTcsImV4cCI6MjA1MDY0MjkxN30.eQ_-G3PphMEHb-mSx5HxTxC_SiCGvUbmZB3lY6gKlug" \
  -d "{
    \"type\": \"new_assignment\",
    \"data\": {
      \"doctor_id\": \"781fff43-9453-4a2c-88ae-c877bd227067\",
      \"patient_name\": \"Emergency Patient - CHECK YOUR PHONE\"
    }
  }"

echo ""
echo "✅ Request sent!"
