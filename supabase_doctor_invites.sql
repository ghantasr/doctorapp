-- ============================================
-- DOCTOR INVITE SYSTEM
-- Allow hospital admins to invite doctors to join their clinic
-- ============================================

-- Create doctor invite codes table
CREATE TABLE IF NOT EXISTS public.doctor_invite_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ,
    max_uses INTEGER DEFAULT 1,
    current_uses INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_doctor_invites_code ON public.doctor_invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_doctor_invites_tenant ON public.doctor_invite_codes(tenant_id);
CREATE INDEX IF NOT EXISTS idx_doctor_invites_active ON public.doctor_invite_codes(is_active) WHERE is_active = true;

-- Track which doctors joined via which invite code
CREATE TABLE IF NOT EXISTS public.doctor_invite_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invite_code_id UUID NOT NULL REFERENCES public.doctor_invite_codes(id) ON DELETE CASCADE,
    doctor_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    used_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doctor_invite_usage_code ON public.doctor_invite_usage(invite_code_id);
CREATE INDEX IF NOT EXISTS idx_doctor_invite_usage_doctor ON public.doctor_invite_usage(doctor_user_id);

-- Function to generate random invite code
CREATE OR REPLACE FUNCTION generate_doctor_invite_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := 'DR-';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to validate and use invite code
CREATE OR REPLACE FUNCTION validate_doctor_invite_code(invite_code TEXT)
RETURNS TABLE(
    is_valid BOOLEAN,
    tenant_id UUID,
    tenant_name TEXT,
    error_message TEXT
) AS $$
DECLARE
    invite_record RECORD;
    tenant_record RECORD;
BEGIN
    -- Find the invite code
    SELECT * INTO invite_record
    FROM public.doctor_invite_codes
    WHERE code = invite_code;
    
    -- Check if code exists
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, 'Invalid invite code';
        RETURN;
    END IF;
    
    -- Check if active
    IF NOT invite_record.is_active THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, 'Invite code has been deactivated';
        RETURN;
    END IF;
    
    -- Check if expired
    IF invite_record.expires_at IS NOT NULL AND invite_record.expires_at < NOW() THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, 'Invite code has expired';
        RETURN;
    END IF;
    
    -- Check usage limit
    IF invite_record.current_uses >= invite_record.max_uses THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, 'Invite code has reached maximum uses';
        RETURN;
    END IF;
    
    -- Get tenant info
    SELECT * INTO tenant_record
    FROM public.tenants
    WHERE id = invite_record.tenant_id;
    
    -- Return success
    RETURN QUERY SELECT true, invite_record.tenant_id, tenant_record.name, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for updated_at
CREATE TRIGGER update_doctor_invite_codes_updated_at 
BEFORE UPDATE ON public.doctor_invite_codes
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Sample data (optional - remove in production)
-- INSERT INTO public.doctor_invite_codes (tenant_id, code, created_by, max_uses)
-- SELECT id, 'DR-SAMPLE01', (SELECT user_id FROM doctors WHERE tenant_id = id LIMIT 1), 10
-- FROM tenants LIMIT 1;
