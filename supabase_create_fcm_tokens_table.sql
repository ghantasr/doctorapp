-- Create FCM tokens table if it doesn't exist
CREATE TABLE IF NOT EXISTS fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type TEXT, -- 'web', 'android', 'ios'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Enable RLS
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can manage their own FCM tokens"
    ON fcm_tokens FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);

-- Insert your current FCM token
INSERT INTO fcm_tokens (user_id, token, device_type)
VALUES (
    '781fff43-9453-4a2c-88ae-c877bd227067',
    'ezgpu-Y7Ryu7IQ63YT6EzD:APA91bEsNynkP_yFbdaYapawM9khk5m1ijB56XqUGd7PKRYdq-514PxLpi1LG11zgijLTJNcNCNPtYu9coKmW9PaDngtJriAQzuZ6B78NUWe5gZikCh9aHs',
    'web'
)
ON CONFLICT (user_id, token) DO UPDATE
SET updated_at = NOW();
