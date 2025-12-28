-- Create user_fcm_tokens table to store Firebase Cloud Messaging tokens
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_info JSONB DEFAULT '{}'::jsonb, -- Can store device type, OS version, etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only manage their own tokens
CREATE POLICY "Users can manage their own FCM tokens"
  ON user_fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create notification_logs table to track sent notifications
CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL, -- 'follow_up_reminder', 'appointment_reminder', 'new_assignment'
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'sent', -- 'sent', 'delivered', 'failed'
  error_message TEXT
);

-- Enable RLS
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own notification logs
CREATE POLICY "Users can view their own notification logs"
  ON notification_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON notification_logs(notification_type);
CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at ON notification_logs(sent_at);

-- Function to send follow-up reminders (called by cron job or edge function)
CREATE OR REPLACE FUNCTION send_follow_up_reminders()
RETURNS TABLE(patient_id UUID, patient_name TEXT, doctor_id UUID, fcm_token TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as patient_id,
    p.first_name || ' ' || p.last_name as patient_name,
    pa.doctor_id,
    uft.fcm_token
  FROM patient_assignments pa
  JOIN patients p ON pa.patient_id = p.id
  JOIN user_fcm_tokens uft ON pa.doctor_id = uft.user_id
  WHERE 
    pa.status = 'active'
    AND pa.follow_up_date IS NOT NULL
    AND pa.follow_up_date::date = CURRENT_DATE -- Follow-up is today
    AND (pa.last_visit_date IS NULL OR pa.last_visit_date < pa.follow_up_date);
END;
$$;

-- Function to send appointment reminders (24 hours before appointment)
CREATE OR REPLACE FUNCTION send_appointment_reminders()
RETURNS TABLE(appointment_id UUID, patient_name TEXT, doctor_name TEXT, appointment_time TIMESTAMP WITH TIME ZONE, fcm_token TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id as appointment_id,
    p.first_name || ' ' || p.last_name as patient_name,
    d.first_name || ' ' || d.last_name as doctor_name,
    a.appointment_date as appointment_time,
    COALESCE(uft_patient.fcm_token, uft_doctor.fcm_token) as fcm_token
  FROM appointments a
  JOIN patients p ON a.patient_id = p.id
  LEFT JOIN doctors d ON a.doctor_id = d.id
  LEFT JOIN user_fcm_tokens uft_patient ON p.id = uft_patient.user_id
  LEFT JOIN user_fcm_tokens uft_doctor ON d.id = uft_doctor.user_id
  WHERE 
    a.status = 'scheduled'
    AND a.appointment_date BETWEEN NOW() AND NOW() + INTERVAL '24 hours'
    AND (uft_patient.fcm_token IS NOT NULL OR uft_doctor.fcm_token IS NOT NULL);
END;
$$;

-- Create scheduled job (if using pg_cron extension)
-- Note: This requires pg_cron extension to be enabled in Supabase
-- SELECT cron.schedule(
--   'send-follow-up-reminders',
--   '0 8 * * *', -- Every day at 8 AM
--   $$SELECT send_follow_up_reminders()$$
-- );

-- SELECT cron.schedule(
--   'send-appointment-reminders', 
--   '0 9,17 * * *', -- Every day at 9 AM and 5 PM
--   $$SELECT send_appointment_reminders()$$
-- );
