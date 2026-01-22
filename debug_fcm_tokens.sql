-- Temporarily allow reading fcm_tokens for debugging
DROP POLICY IF EXISTS "Users can view their own FCM tokens" ON fcm_tokens;

CREATE POLICY "Allow authenticated users to read fcm_tokens"
ON fcm_tokens FOR SELECT
TO authenticated
USING (true);

-- Check the data
SELECT 
  user_id,
  LEFT(token, 60) as token_prefix,
  device_type,
  created_at,
  updated_at
FROM fcm_tokens 
WHERE user_id = '781fff43-9453-4a2c-88ae-c877bd227067';
