#!/bin/bash

# This script tests FCM notification delivery by querying the database
# and sending test notifications directly using Firebase

USER_ID="781fff43-9453-4a2c-88ae-c877bd227067"

echo "🔍 Checking FCM token in database for user: $USER_ID"
echo ""

# Use Supabase CLI to execute SQL
SUPABASE_WORKDIR=/Users/apple/Desktop/DoctorApp/doctorapp supabase db query "
SELECT 
  user_id,
  LEFT(token, 50) as token_start,
  device_type,
  created_at
FROM fcm_tokens 
WHERE user_id = '$USER_ID'
" 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Failed to query database"
    echo "Token should be: ezgpu-Y7Ryu7IQ63YT6EzD:APA91bEsNynkP_yFbdaYapawM9khk5m1ijB56XqUGd7PKRYdq-514PxLpi1LG11zgijLTJNcNCNPtYu9coKmW9PaDngtJriAQzuZ6B78NUWe5gZikCh9aHs"
else
    echo ""
    echo "✅ Query executed successfully"
fi
