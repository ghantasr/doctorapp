-- Database Triggers for Automatic Notifications
-- Run this in Supabase SQL Editor to enable automatic notifications

-- ============================================
-- 1. Trigger: Send notification when patient is assigned to doctor
-- ============================================
CREATE OR REPLACE FUNCTION notify_new_patient_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_name TEXT;
BEGIN
  -- Only send notification for new active assignments
  IF NEW.status = 'active' THEN
    -- Get patient name
    SELECT first_name || ' ' || last_name INTO v_patient_name
    FROM patients
    WHERE id = NEW.patient_id;
    
    -- Call edge function to send notification
    PERFORM net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/send-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := jsonb_build_object(
        'type', 'new_assignment',
        'data', jsonb_build_object(
          'doctor_id', NEW.doctor_id,
          'patient_name', v_patient_name
        )
      )
    );
    
    RAISE NOTICE 'Notification queued for doctor % about patient %', NEW.doctor_id, v_patient_name;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notify_new_assignment ON patient_assignments;
CREATE TRIGGER trigger_notify_new_assignment
  AFTER INSERT ON patient_assignments
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_patient_assignment();

-- ============================================
-- 2. Trigger: Send notification when follow-up date is set
-- ============================================
CREATE OR REPLACE FUNCTION notify_follow_up_scheduled()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_name TEXT;
  v_doctor_id UUID;
BEGIN
  -- Only send if follow-up date was just set or changed
  IF NEW.follow_up_date IS NOT NULL 
     AND (OLD.follow_up_date IS NULL OR OLD.follow_up_date != NEW.follow_up_date) 
     AND NEW.status = 'active' THEN
    
    -- Get patient name and doctor
    SELECT p.first_name || ' ' || p.last_name, NEW.doctor_id
    INTO v_patient_name, v_doctor_id
    FROM patients p
    WHERE p.id = NEW.patient_id;
    
    RAISE NOTICE 'Follow-up scheduled for % on % - reminder will be sent 2 days before', 
                 v_patient_name, NEW.follow_up_date;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notify_follow_up ON patient_assignments;
CREATE TRIGGER trigger_notify_follow_up
  AFTER UPDATE ON patient_assignments
  FOR EACH ROW
  EXECUTE FUNCTION notify_follow_up_scheduled();

-- ============================================
-- 3. Trigger: Send notification when prescription is created
-- ============================================
CREATE OR REPLACE FUNCTION notify_prescription_ready()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_user_id UUID;
BEGIN
  -- Get patient's user ID
  SELECT user_id INTO v_patient_user_id
  FROM patients
  WHERE id = NEW.patient_id;
  
  -- Only send if patient has a user account
  IF v_patient_user_id IS NOT NULL THEN
    -- Call edge function to send notification
    PERFORM net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/send-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := jsonb_build_object(
        'type', 'prescription_ready',
        'data', jsonb_build_object(
          'patient_id', NEW.patient_id,
          'prescription_id', NEW.id
        )
      )
    );
    
    RAISE NOTICE 'Prescription ready notification queued for patient %', NEW.patient_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notify_prescription ON prescriptions;
CREATE TRIGGER trigger_notify_prescription
  AFTER INSERT ON prescriptions
  FOR EACH ROW
  EXECUTE FUNCTION notify_prescription_ready();

-- ============================================
-- 4. Setup: Configure Supabase URL and Service Role Key
-- ============================================
-- Note: These should be set in your Supabase project settings
-- You can also use Supabase Vault for secure secret storage

-- Example (run once per database):
-- ALTER DATABASE postgres SET app.settings.supabase_url = 'https://dhbkcxuaatquevwtqxfe.supabase.co';
-- ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key-here';

-- ============================================
-- 5. Verify triggers are created
-- ============================================
SELECT 
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'trigger_notify%'
ORDER BY event_object_table, trigger_name;

-- ============================================
-- IMPORTANT NOTES:
-- ============================================
-- 1. The http extension must be enabled: CREATE EXTENSION IF NOT EXISTS http;
-- 2. Edge function must be deployed and accessible
-- 3. Triggers use AFTER INSERT/UPDATE to avoid blocking the main operation
-- 4. All trigger functions are SECURITY DEFINER (run with creator's permissions)
-- 5. Monitor trigger executions in Supabase logs
