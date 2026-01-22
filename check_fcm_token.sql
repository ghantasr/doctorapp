-- Check FCM tokens for the user
SELECT 
  user_id,
  LEFT(token, 40) as token_prefix,
  device_type,
  created_at,
  updated_at
FROM fcm_tokens 
WHERE user_id = '781fff43-9453-4a2c-88ae-c877bd227067';

-- Also check user details
SELECT 
  id,
  email,
  created_at
FROM auth.users
WHERE id = '781fff43-9453-4a2c-88ae-c877bd227067';
