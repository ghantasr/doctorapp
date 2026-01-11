-- ============================================
-- NOTIFICATION SYSTEM FIXES
-- Fixes for multi-device support and proper notification handling
-- ============================================

-- Fix 1: Update user_fcm_tokens to support multiple devices per user
-- Current issue: PRIMARY KEY on user_id allows only one device per user
-- Solution: Add id column as primary key, make user_id + fcm_token unique

-- Step 1: Check if we need to migrate the schema
DO $$
BEGIN
  -- Check if the table already has id column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_fcm_tokens' 
    AND column_name = 'id'
  ) THEN
    -- Add id column and make it the new primary key
    ALTER TABLE public.user_fcm_tokens 
      DROP CONSTRAINT IF EXISTS user_fcm_tokens_pkey;
    
    ALTER TABLE public.user_fcm_tokens 
      ADD COLUMN id UUID DEFAULT gen_random_uuid();
    
    -- Update existing rows to have unique IDs
    UPDATE public.user_fcm_tokens SET id = gen_random_uuid() WHERE id IS NULL;
    
    -- Make id the primary key
    ALTER TABLE public.user_fcm_tokens 
      ADD CONSTRAINT user_fcm_tokens_pkey PRIMARY KEY (id);
    
    -- Create unique index on user_id + fcm_token to prevent duplicate tokens for same user
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_fcm_token_unique 
      ON public.user_fcm_tokens(user_id, fcm_token);
    
    -- Create index on user_id for faster lookups
    CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id 
      ON public.user_fcm_tokens(user_id);
    
    RAISE NOTICE 'Successfully migrated user_fcm_tokens table to support multiple devices';
  ELSE
    RAISE NOTICE 'user_fcm_tokens table already has id column, skipping migration';
  END IF;
END $$;

-- Fix 2: Add device_identifier column to better track devices
ALTER TABLE public.user_fcm_tokens 
  ADD COLUMN IF NOT EXISTS device_identifier TEXT;

-- Add index on device_identifier for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_device 
  ON public.user_fcm_tokens(user_id, device_identifier) 
  WHERE device_identifier IS NOT NULL;

-- Fix 3: Add is_active column to support device token invalidation
ALTER TABLE public.user_fcm_tokens 
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add index for active tokens only
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_active 
  ON public.user_fcm_tokens(user_id) 
  WHERE is_active = true;

-- Fix 4: Update the RLS policy to work with new schema
DROP POLICY IF EXISTS "Users can manage their own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage their own FCM tokens"
  ON public.user_fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Fix 5: Create function to get all active FCM tokens for a user
CREATE OR REPLACE FUNCTION get_user_fcm_tokens(p_user_id UUID)
RETURNS TABLE(
  id UUID,
  fcm_token TEXT,
  device_identifier TEXT,
  device_info JSONB,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    uft.id,
    uft.fcm_token,
    uft.device_identifier,
    uft.device_info,
    uft.updated_at
  FROM public.user_fcm_tokens uft
  WHERE uft.user_id = p_user_id
    AND uft.is_active = true
  ORDER BY uft.updated_at DESC;
END;
$$;

-- Fix 6: Create function to deactivate old tokens for a device
CREATE OR REPLACE FUNCTION update_user_fcm_token(
  p_user_id UUID,
  p_fcm_token TEXT,
  p_device_identifier TEXT DEFAULT NULL,
  p_device_info JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token_id UUID;
BEGIN
  -- If device_identifier is provided, deactivate old tokens for this device
  IF p_device_identifier IS NOT NULL THEN
    UPDATE public.user_fcm_tokens
    SET is_active = false
    WHERE user_id = p_user_id
      AND device_identifier = p_device_identifier
      AND fcm_token != p_fcm_token;
  END IF;

  -- Insert or update the token
  INSERT INTO public.user_fcm_tokens (
    user_id,
    fcm_token,
    device_identifier,
    device_info,
    is_active,
    updated_at
  )
  VALUES (
    p_user_id,
    p_fcm_token,
    p_device_identifier,
    p_device_info,
    true,
    NOW()
  )
  ON CONFLICT (user_id, fcm_token) 
  DO UPDATE SET
    device_identifier = EXCLUDED.device_identifier,
    device_info = EXCLUDED.device_info,
    is_active = true,
    updated_at = NOW()
  RETURNING id INTO v_token_id;

  RETURN v_token_id;
END;
$$;

-- Fix 7: Add retry_count and last_retry_at to notification_logs
ALTER TABLE public.notification_logs 
  ADD COLUMN IF NOT EXISTS retry_count INTEGER DEFAULT 0;

ALTER TABLE public.notification_logs 
  ADD COLUMN IF NOT EXISTS last_retry_at TIMESTAMPTZ;

-- Create index for retrying failed notifications
CREATE INDEX IF NOT EXISTS idx_notification_logs_retry 
  ON public.notification_logs(status, retry_count, last_retry_at) 
  WHERE status IN ('failed', 'pending');

-- Fix 8: Update send_follow_up_notification to handle multiple devices
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
  v_fcm_tokens TEXT[];
  v_title TEXT;
  v_body TEXT;
  v_notification_id UUID;
BEGIN
  -- Get patient's user ID
  SELECT user_id INTO v_patient_user_id FROM public.patients WHERE id = p_patient_id;
  
  IF v_patient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Patient has no linked user account');
  END IF;
  
  -- Get all active FCM tokens for the user
  SELECT array_agg(fcm_token) INTO v_fcm_tokens
  FROM public.user_fcm_tokens 
  WHERE user_id = v_patient_user_id AND is_active = true;
  
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
  
  -- Log the notification (will be picked up by send-pending-notifications edge function)
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
    jsonb_build_object('follow_up_date', p_follow_up_date, 'patient_id', p_patient_id),
    CASE 
      WHEN v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 
      THEN 'pending' 
      ELSE 'no_token' 
    END
  ) RETURNING id INTO v_notification_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'notification_id', v_notification_id,
    'has_tokens', v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0,
    'token_count', COALESCE(array_length(v_fcm_tokens, 1), 0)
  );
END;
$$;

-- Fix 9: Update send_mouthwash_notification to handle multiple devices
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
  v_fcm_tokens TEXT[];
  v_title TEXT;
  v_body TEXT;
  v_template_key TEXT;
  v_notification_id UUID;
BEGIN
  -- Get patient's user ID
  SELECT user_id INTO v_patient_user_id FROM public.patients WHERE id = p_patient_id;
  
  IF v_patient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Patient has no linked user account');
  END IF;
  
  -- Get all active FCM tokens for the user
  SELECT array_agg(fcm_token) INTO v_fcm_tokens
  FROM public.user_fcm_tokens 
  WHERE user_id = v_patient_user_id AND is_active = true;
  
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
  
  -- Log the notification (will be picked up by send-pending-notifications edge function)
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
    jsonb_build_object('time_of_day', p_time_of_day, 'patient_id', p_patient_id),
    CASE 
      WHEN v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0 
      THEN 'pending' 
      ELSE 'no_token' 
    END
  ) RETURNING id INTO v_notification_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'notification_id', v_notification_id,
    'has_tokens', v_fcm_tokens IS NOT NULL AND array_length(v_fcm_tokens, 1) > 0,
    'token_count', COALESCE(array_length(v_fcm_tokens, 1), 0)
  );
END;
$$;

-- Fix 10: Create function to clean up old/invalid FCM tokens
CREATE OR REPLACE FUNCTION cleanup_invalid_fcm_tokens()
RETURNS TABLE(
  deactivated_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Deactivate tokens that haven't been updated in 90 days
  UPDATE public.user_fcm_tokens
  SET is_active = false
  WHERE is_active = true
    AND updated_at < NOW() - INTERVAL '90 days';
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  
  RETURN QUERY SELECT v_count;
END;
$$;

-- Fix 11: Add index on notification_type and sent_at for analytics
CREATE INDEX IF NOT EXISTS idx_notification_logs_type_date 
  ON public.notification_logs(notification_type, sent_at DESC);

-- Fix 12: Create view for notification statistics
CREATE OR REPLACE VIEW notification_statistics AS
SELECT 
  notification_type,
  status,
  COUNT(*) as count,
  DATE(sent_at) as date,
  MIN(sent_at) as first_sent,
  MAX(sent_at) as last_sent
FROM public.notification_logs
WHERE sent_at >= NOW() - INTERVAL '30 days'
GROUP BY notification_type, status, DATE(sent_at)
ORDER BY date DESC, notification_type, status;

-- Grant access to the view
GRANT SELECT ON notification_statistics TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION get_user_fcm_tokens IS 'Gets all active FCM tokens for a user (multi-device support)';
COMMENT ON FUNCTION update_user_fcm_token IS 'Upserts FCM token and manages device token lifecycle';
COMMENT ON FUNCTION cleanup_invalid_fcm_tokens IS 'Deactivates FCM tokens that haven''t been updated in 90 days';
COMMENT ON VIEW notification_statistics IS 'Daily notification statistics for the past 30 days';

-- Log completion
DO $$
BEGIN
  RAISE NOTICE 'Notification system fixes applied successfully';
  RAISE NOTICE 'Key improvements:';
  RAISE NOTICE '1. Multi-device support for FCM tokens';
  RAISE NOTICE '2. Device tracking with device_identifier';
  RAISE NOTICE '3. Token lifecycle management (is_active flag)';
  RAISE NOTICE '4. Retry mechanism for failed notifications';
  RAISE NOTICE '5. Updated notification functions to use pending status';
  RAISE NOTICE '6. Token cleanup function for old tokens';
  RAISE NOTICE '7. Notification statistics view';
END $$;
