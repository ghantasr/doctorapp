-- Check current FCM tokens
SELECT user_id, LEFT(token, 50) as token_start, device_type, updated_at 
FROM fcm_tokens 
WHERE user_id = '781fff43-9453-4a2c-88ae-c877bd227067'
ORDER BY updated_at DESC;

-- Delete old tokens for this user
DELETE FROM fcm_tokens 
WHERE user_id = '781fff43-9453-4a2c-88ae-c877bd227067';

-- Insert the new token from the app
INSERT INTO fcm_tokens (user_id, token, device_type, updated_at)
VALUES (
    '781fff43-9453-4a2c-88ae-c877bd227067',
    'cS0rhyfRQtuiSYd4vfW70o:APA91bH5Okc50C1K2IfPZNrz2c942UmgG481OHGEDTdYxzVW-gIc-PGY34jZNujmVdYUIktcvIO82R_K42bqri03HtsfLSEk-bCCHX9GlbKEjleDReGHbkI',
    'android',
    NOW()
);
