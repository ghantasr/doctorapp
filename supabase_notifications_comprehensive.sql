-- ============================================
-- COMPREHENSIVE NOTIFICATION SYSTEM
-- For follow-up reminders, mouthwash reminders, and admin management
-- ============================================

-- 1. Ensure user_fcm_tokens table exists
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_info JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage their own FCM tokens"
  ON public.user_fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Ensure notification_logs table exists
CREATE TABLE IF NOT EXISTS public.notification_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'sent',
  error_message TEXT
);

ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notification logs" ON public.notification_logs;
CREATE POLICY "Users can view their own notification logs"
  ON public.notification_logs
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON public.notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON public.notification_logs(notification_type);
CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at ON public.notification_logs(sent_at);

-- 3. Ensure daily_reminders table exists (for mouthwash, etc.)
CREATE TABLE IF NOT EXISTS public.daily_reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  reminder_type TEXT NOT NULL,
  reminder_text TEXT NOT NULL,
  time_of_day TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.daily_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients can view their own reminders" ON public.daily_reminders;
CREATE POLICY "Patients can view their own reminders"
  ON public.daily_reminders
  FOR SELECT
  USING (
    patient_id IN (
      SELECT id FROM public.patients WHERE id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_daily_reminders_patient ON public.daily_reminders(patient_id, is_active) 
WHERE is_active = true;

-- 4. Create notification_templates table for customizable messages
CREATE TABLE IF NOT EXISTS public.notification_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  template_key TEXT UNIQUE NOT NULL,
  template_type TEXT NOT NULL,
  title_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  language_code TEXT DEFAULT 'en',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read notification templates
DROP POLICY IF EXISTS "Users can read notification templates" ON public.notification_templates;
CREATE POLICY "Users can read notification templates"
  ON public.notification_templates
  FOR SELECT
  USING (is_active = true);

-- Insert default notification templates
INSERT INTO public.notification_templates (template_key, template_type, title_template, body_template, language_code)
VALUES 
  ('follow_up_reminder_2day', 'follow_up_reminder', 'Follow-up Reminder', 'You have a follow-up appointment in 2 days on {follow_up_date}', 'en'),
  ('mouthwash_morning', 'mouthwash_reminder', 'Mouthwash Reminder', 'Good morning! Time for your mouthwash rinse to maintain oral hygiene.', 'en'),
  ('mouthwash_evening', 'mouthwash_reminder', 'Mouthwash Reminder', 'Good evening! Don''t forget your mouthwash rinse before bed.', 'en')
ON CONFLICT (template_key) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_notification_templates_key ON public.notification_templates(template_key) 
WHERE is_active = true;

-- 5. Function to get follow-up patients due in 2 days (for notifications)
CREATE OR REPLACE FUNCTION get_follow_up_patients_due_in_days(days_advance INTEGER DEFAULT 2)
RETURNS TABLE(
  patient_id UUID,
  patient_first_name TEXT,
  patient_last_name TEXT,
  patient_phone TEXT,
  doctor_id UUID,
  doctor_first_name TEXT,
  doctor_last_name TEXT,
  follow_up_date TIMESTAMPTZ,
  tenant_id UUID,
  patient_user_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as patient_id,
    p.first_name as patient_first_name,
    p.last_name as patient_last_name,
    p.phone as patient_phone,
    d.id as doctor_id,
    d.first_name as doctor_first_name,
    d.last_name as doctor_last_name,
    pa.follow_up_date,
    pa.tenant_id,
    p.id as patient_user_id
  FROM public.patient_assignments pa
  JOIN public.patients p ON pa.patient_id = p.id
  JOIN public.doctors d ON pa.doctor_id = d.id
  WHERE 
    pa.status = 'active'
    AND pa.follow_up_date IS NOT NULL
    AND pa.follow_up_date::date = (CURRENT_DATE + days_advance)
    AND (pa.last_visit_date IS NULL OR pa.last_visit_date < pa.follow_up_date);
END;
$$;

-- 6. Function to get all active mouthwash reminders that should be sent
CREATE OR REPLACE FUNCTION get_active_mouthwash_reminders()
RETURNS TABLE(
  patient_id UUID,
  patient_first_name TEXT,
  patient_last_name TEXT,
  reminder_text TEXT,
  time_of_day TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as patient_id,
    p.first_name as patient_first_name,
    p.last_name as patient_last_name,
    dr.reminder_text,
    dr.time_of_day
  FROM public.daily_reminders dr
  JOIN public.patients p ON dr.patient_id = p.id
  WHERE 
    dr.is_active = true
    AND dr.reminder_type = 'mouthwash';
END;
$$;

-- 7. Function to send follow-up notification (to be called by Edge Function)
-- Uses notification templates for customizable messages
CREATE OR REPLACE FUNCTION send_follow_up_notification(
  p_patient_id UUID,
  p_follow_up_date TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_user_id UUID;
  v_fcm_token TEXT;
  v_title TEXT;
  v_body TEXT;
  v_result JSONB;
BEGIN
  -- Get patient's user ID and FCM token
  SELECT id INTO v_patient_user_id FROM public.patients WHERE id = p_patient_id;
  
  IF v_patient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Patient not found');
  END IF;
  
  -- Get FCM token
  SELECT fcm_token INTO v_fcm_token 
  FROM public.user_fcm_tokens 
  WHERE user_id = v_patient_user_id;
  
  -- Get notification template
  SELECT title_template, body_template INTO v_title, v_body
  FROM public.notification_templates
  WHERE template_key = 'follow_up_reminder_2day' AND is_active = true
  LIMIT 1;
  
  -- Fallback to default if template not found
  IF v_title IS NULL THEN
    v_title := 'Follow-up Reminder';
    v_body := 'You have a follow-up appointment in 2 days on ' || to_char(p_follow_up_date, 'Mon DD, YYYY');
  ELSE
    -- Replace template placeholders
    v_body := REPLACE(v_body, '{follow_up_date}', to_char(p_follow_up_date, 'Mon DD, YYYY'));
  END IF;
  
  -- Log the notification
  INSERT INTO public.notification_logs (
    user_id,
    notification_type,
    title,
    body,
    data,
    status
  ) VALUES (
    v_patient_user_id,
    'follow_up_reminder',
    v_title,
    v_body,
    jsonb_build_object('follow_up_date', p_follow_up_date),
    CASE WHEN v_fcm_token IS NOT NULL THEN 'sent' ELSE 'no_token' END
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'has_token', v_fcm_token IS NOT NULL,
    'fcm_token', v_fcm_token
  );
END;
$$;

-- 8. Function to send mouthwash reminder (to be called by Edge Function)
-- Uses notification templates for customizable messages
CREATE OR REPLACE FUNCTION send_mouthwash_notification(
  p_patient_id UUID,
  p_reminder_text TEXT,
  p_time_of_day TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_user_id UUID;
  v_fcm_token TEXT;
  v_title TEXT;
  v_body TEXT;
  v_template_key TEXT;
  v_result JSONB;
BEGIN
  -- Get patient's user ID and FCM token
  SELECT id INTO v_patient_user_id FROM public.patients WHERE id = p_patient_id;
  
  IF v_patient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Patient not found');
  END IF;
  
  -- Get FCM token
  SELECT fcm_token INTO v_fcm_token 
  FROM public.user_fcm_tokens 
  WHERE user_id = v_patient_user_id;
  
  -- Determine template key based on time of day
  v_template_key := 'mouthwash_' || p_time_of_day;
  
  -- Get notification template
  SELECT title_template, body_template INTO v_title, v_body
  FROM public.notification_templates
  WHERE template_key = v_template_key AND is_active = true
  LIMIT 1;
  
  -- Fallback to provided reminder text if template not found
  IF v_title IS NULL THEN
    v_title := 'Mouthwash Reminder';
    v_body := p_reminder_text;
  END IF;
  
  -- Log the notification
  INSERT INTO public.notification_logs (
    user_id,
    notification_type,
    title,
    body,
    data,
    status
  ) VALUES (
    v_patient_user_id,
    'mouthwash_reminder',
    v_title,
    v_body,
    jsonb_build_object('time_of_day', p_time_of_day),
    CASE WHEN v_fcm_token IS NOT NULL THEN 'sent' ELSE 'no_token' END
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'has_token', v_fcm_token IS NOT NULL,
    'fcm_token', v_fcm_token
  );
END;
$$;

-- 9. Insert default mouthwash reminders for all existing patients (morning and evening)
INSERT INTO public.daily_reminders (patient_id, reminder_type, reminder_text, time_of_day, is_active)
SELECT 
  id,
  'mouthwash',
  'Good morning! Time for your mouthwash rinse to maintain oral hygiene.',
  'morning',
  true
FROM public.patients
WHERE NOT EXISTS (
  SELECT 1 FROM public.daily_reminders 
  WHERE patient_id = patients.id 
  AND reminder_type = 'mouthwash' 
  AND time_of_day = 'morning'
);

INSERT INTO public.daily_reminders (patient_id, reminder_type, reminder_text, time_of_day, is_active)
SELECT 
  id,
  'mouthwash',
  'Good evening! Don''t forget your mouthwash rinse before bed.',
  'evening',
  true
FROM public.patients
WHERE NOT EXISTS (
  SELECT 1 FROM public.daily_reminders 
  WHERE patient_id = patients.id 
  AND reminder_type = 'mouthwash' 
  AND time_of_day = 'evening'
);

-- 10. Create a view for admin to see follow-up patients due in 2 days
CREATE OR REPLACE VIEW admin_follow_up_due_soon AS
SELECT 
  p.id as patient_id,
  p.first_name || ' ' || p.last_name as patient_name,
  p.phone as patient_phone,
  p.email as patient_email,
  d.first_name || ' ' || d.last_name as doctor_name,
  pa.follow_up_date,
  pa.tenant_id,
  EXTRACT(DAY FROM (pa.follow_up_date - NOW())) as days_until_follow_up
FROM public.patient_assignments pa
JOIN public.patients p ON pa.patient_id = p.id
JOIN public.doctors d ON pa.doctor_id = d.id
WHERE 
  pa.status = 'active'
  AND pa.follow_up_date IS NOT NULL
  AND pa.follow_up_date BETWEEN NOW() AND NOW() + INTERVAL '2 days'
  AND (pa.last_visit_date IS NULL OR pa.last_visit_date < pa.follow_up_date)
ORDER BY pa.follow_up_date ASC;

-- Grant access to the view
GRANT SELECT ON admin_follow_up_due_soon TO authenticated;

COMMENT ON TABLE public.user_fcm_tokens IS 'Stores Firebase Cloud Messaging tokens for push notifications';
COMMENT ON TABLE public.notification_logs IS 'Logs all sent notifications for auditing and tracking';
COMMENT ON TABLE public.daily_reminders IS 'Daily reminders for patients (mouthwash, medication, etc.)';
COMMENT ON TABLE public.notification_templates IS 'Customizable notification message templates with multi-language support';
COMMENT ON FUNCTION get_follow_up_patients_due_in_days IS 'Returns patients with follow-ups due in specified days (default 2)';
COMMENT ON FUNCTION get_active_mouthwash_reminders IS 'Returns all active mouthwash reminders for patients';
COMMENT ON FUNCTION send_follow_up_notification IS 'Sends follow-up reminder notification to patient using templates';
COMMENT ON FUNCTION send_mouthwash_notification IS 'Sends mouthwash reminder notification to patient using templates';
COMMENT ON VIEW admin_follow_up_due_soon IS 'Admin view of patients with follow-ups due within 2 days';
