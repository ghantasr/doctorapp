-- ============================================
-- USER SUSPENSION & ROLE MANAGEMENT
-- Allow admins to suspend/activate users
-- ============================================

-- Add is_suspended column to doctors table
ALTER TABLE public.doctors 
ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;

-- Add suspended_at and suspended_by columns for tracking
ALTER TABLE public.doctors
ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES auth.users(id);

-- Add is_suspended to patients table as well
ALTER TABLE public.patients
ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES auth.users(id);

-- Function to suspend a doctor
CREATE OR REPLACE FUNCTION suspend_doctor(
    p_doctor_id UUID,
    p_suspended_by UUID,
    p_tenant_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_admin_role TEXT;
BEGIN
    -- Check if the user doing the suspension is an admin
    SELECT role INTO v_admin_role
    FROM user_tenant_roles
    WHERE user_id = p_suspended_by
      AND tenant_id = p_tenant_id
      AND role = 'admin';
    
    IF v_admin_role IS NULL THEN
        RAISE EXCEPTION 'Only admins can suspend users';
    END IF;
    
    -- Suspend the doctor
    UPDATE doctors
    SET is_suspended = true,
        suspended_at = NOW(),
        suspended_by = p_suspended_by
    WHERE id = p_doctor_id
      AND tenant_id = p_tenant_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to activate a doctor
CREATE OR REPLACE FUNCTION activate_doctor(
    p_doctor_id UUID,
    p_activated_by UUID,
    p_tenant_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_admin_role TEXT;
BEGIN
    -- Check if the user doing the activation is an admin
    SELECT role INTO v_admin_role
    FROM user_tenant_roles
    WHERE user_id = p_activated_by
      AND tenant_id = p_tenant_id
      AND role = 'admin';
    
    IF v_admin_role IS NULL THEN
        RAISE EXCEPTION 'Only admins can activate users';
    END IF;
    
    -- Activate the doctor
    UPDATE doctors
    SET is_suspended = false,
        suspended_at = NULL,
        suspended_by = NULL
    WHERE id = p_doctor_id
      AND tenant_id = p_tenant_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a user is admin in a tenant
CREATE OR REPLACE FUNCTION is_user_admin(
    p_user_id UUID,
    p_tenant_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role
    FROM user_tenant_roles
    WHERE user_id = p_user_id
      AND tenant_id = p_tenant_id
      AND role = 'admin';
    
    RETURN v_role IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if doctor is suspended
CREATE OR REPLACE FUNCTION is_doctor_suspended(
    p_doctor_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_suspended BOOLEAN;
BEGIN
    SELECT is_suspended INTO v_is_suspended
    FROM doctors
    WHERE id = p_doctor_id;
    
    RETURN COALESCE(v_is_suspended, false);
END;
$$ LANGUAGE plpgsql;

-- Add index for faster suspension checks
CREATE INDEX IF NOT EXISTS idx_doctors_suspended ON public.doctors(is_suspended) WHERE is_suspended = true;
CREATE INDEX IF NOT EXISTS idx_patients_suspended ON public.patients(is_suspended) WHERE is_suspended = true;

-- Add index for admin role checks
CREATE INDEX IF NOT EXISTS idx_user_tenant_roles_admin ON public.user_tenant_roles(user_id, tenant_id) WHERE role = 'admin';

-- NOTES:
-- 1. Suspended doctors cannot login to the system
-- 2. Only admins can suspend/activate users
-- 3. Suspension is per-hospital (a doctor can be suspended in one hospital but active in another)
-- 4. The app should check is_suspended before allowing access
