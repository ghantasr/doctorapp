-- Cron Jobs for Scheduled Notifications
-- Run this in Supabase SQL Editor to set up automatic scheduled notifications

-- ============================================
-- Prerequisites
-- ============================================
-- 1. pg_cron extension must be enabled (Supabase Pro plan required)
-- 2. Edge function 'send-notification' must be deployed
-- 3. fcm_tokens table must have valid tokens

-- ============================================
-- 1. Daily Follow-Up Reminders (8 AM UTC)
-- ============================================
-- Sends reminders to doctors about patients with follow-ups in 2 days

SELECT cron.schedule(
  'send-daily-follow-up-reminders',
  '0 8 * * *', -- Every day at 8:00 AM UTC
  $$
  SELECT net.http_post(
    url := 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'type', 'follow_up_reminder',
      'data', jsonb_build_object(
        'doctor_id', doctor_id,
        'patient_name', patient_name,
        'follow_up_date', follow_up_date::text
      )
    )
  )
  FROM (
    SELECT DISTINCT
      pa.doctor_id,
      p.first_name || ' ' || p.last_name as patient_name,
      pa.follow_up_date
    FROM patient_assignments pa
    JOIN patients p ON pa.patient_id = p.id
    WHERE pa.status = 'active'
      AND pa.follow_up_date IS NOT NULL
      AND pa.follow_up_date::date = CURRENT_DATE + INTERVAL '2 days'
      AND (pa.last_visit_date IS NULL OR pa.last_visit_date < pa.follow_up_date)
  ) reminders;
  $$
);

-- ============================================
-- 2. Appointment Reminders (9 AM & 5 PM UTC)
-- ============================================
-- Sends reminders about appointments 24 hours in advance

SELECT cron.schedule(
  'send-appointment-reminders',
  '0 9,17 * * *', -- Every day at 9 AM and 5 PM UTC
  $$
  -- This assumes you have an appointments table
  -- Adjust based on your actual schema
  SELECT net.http_post(
    url := 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'type', 'appointment_reminder',
      'data', jsonb_build_object(
        'user_id', user_id,
        'doctor_name', doctor_name,
        'patient_name', patient_name,
        'appointment_time', appointment_time::text,
        'is_doctor', is_doctor
      )
    )
  )
  FROM (
    -- Add your appointments query here
    -- Example structure:
    SELECT 
      doctor_id as user_id,
      'Dr. Smith' as doctor_name,
      'John Doe' as patient_name,
      appointment_time,
      true as is_doctor
    FROM appointments
    WHERE appointment_time BETWEEN NOW() + INTERVAL '23 hours' AND NOW() + INTERVAL '25 hours'
      AND status = 'scheduled'
  ) appointments;
  $$
);

-- ============================================
-- 3. Weekly Summary for Doctors (Monday 8 AM)
-- ============================================
-- Sends weekly summary of upcoming follow-ups

SELECT cron.schedule(
  'send-weekly-summary',
  '0 8 * * 1', -- Every Monday at 8 AM UTC
  $$
  -- Send summary email/notification to doctors
  -- This would integrate with your notification system
  SELECT net.http_post(
    url := 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'type', 'weekly_summary',
      'data', jsonb_build_object(
        'doctor_id', doctor_id,
        'follow_ups_count', count,
        'week_start', CURRENT_DATE::text
      )
    )
  )
  FROM (
    SELECT 
      pa.doctor_id,
      COUNT(*) as count
    FROM patient_assignments pa
    WHERE pa.status = 'active'
      AND pa.follow_up_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
    GROUP BY pa.doctor_id
    HAVING COUNT(*) > 0
  ) summaries;
  $$
);

-- ============================================
-- View All Scheduled Jobs
-- ============================================
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active,
  jobname
FROM cron.job
WHERE jobname LIKE 'send-%'
ORDER BY jobname;

-- ============================================
-- Unschedule a Job (if needed)
-- ============================================
-- SELECT cron.unschedule('send-daily-follow-up-reminders');
-- SELECT cron.unschedule('send-appointment-reminders');
-- SELECT cron.unschedule('send-weekly-summary');

-- ============================================
-- Monitor Job Execution
-- ============================================
-- Check recent job runs and their status
SELECT 
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname LIKE 'send-%')
ORDER BY start_time DESC
LIMIT 20;

-- ============================================
-- ALTERNATIVE: GitHub Actions (Free Tier)
-- ============================================
-- If you're on Supabase free tier (no pg_cron), use GitHub Actions
-- Create .github/workflows/notifications.yml:

/*
name: Send Notifications
on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM UTC
  workflow_dispatch:  # Allow manual trigger

jobs:
  send-follow-up-reminders:
    runs-on: ubuntu-latest
    steps:
      - name: Call Supabase Edge Function
        run: |
          curl -X POST 'https://dhbkcxuaatquevwtqxfe.supabase.co/functions/v1/send-follow-up-reminders' \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}'
*/

-- ============================================
-- NOTES
-- ============================================
-- 1. Cron expressions use UTC timezone
-- 2. Adjust times based on your users' timezone
-- 3. Monitor execution in Supabase Dashboard > Database > Cron Jobs
-- 4. Use pg_cron documentation for complex schedules
-- 5. Consider rate limiting for edge functions
-- 6. Test with workflow_dispatch first before relying on schedule
