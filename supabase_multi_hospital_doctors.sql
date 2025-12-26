-- ============================================
-- MULTI-HOSPITAL DOCTOR SUPPORT
-- Allow doctors to work at multiple hospitals
-- ============================================

-- Step 1: Remove the UNIQUE constraint that prevents doctors from being in multiple hospitals
-- This constraint: UNIQUE(tenant_id, user_id) prevents the same user from being a doctor in multiple tenants
ALTER TABLE public.doctors 
DROP CONSTRAINT IF EXISTS doctors_tenant_id_user_id_key;

-- Step 2: Add a new composite unique constraint that allows same user_id across different tenants
-- but prevents duplicate doctor records for same user in same tenant
-- We can use (tenant_id, user_id) for a different purpose - ensuring unique doctor profile per hospital
-- Actually, we want to ALLOW multiple entries, so we'll just remove the constraint above

-- Step 3: Add an 'is_active' flag to track which hospital context the doctor is currently using
-- This helps when a doctor works at multiple hospitals
ALTER TABLE public.doctors 
ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;

-- Step 4: Create index for better performance when querying doctors by user across all tenants
CREATE INDEX IF NOT EXISTS idx_doctors_user_all_tenants ON public.doctors(user_id);

-- Step 5: Add a display_name field for hospital-specific doctor names (optional)
-- Some doctors might want different display names at different hospitals
ALTER TABLE public.doctors 
ADD COLUMN IF NOT EXISTS display_name TEXT;

-- ============================================
-- HELPFUL QUERIES FOR MULTI-HOSPITAL SETUP
-- ============================================

-- Query to see all hospitals a doctor works at:
-- SELECT d.*, t.name as hospital_name 
-- FROM doctors d 
-- JOIN tenants t ON d.tenant_id = t.id 
-- WHERE d.user_id = '<user_id>';

-- Query to see all doctors in a hospital:
-- SELECT d.*, u.email 
-- FROM doctors d 
-- JOIN auth.users u ON d.user_id = u.id 
-- WHERE d.tenant_id = '<tenant_id>';

-- ============================================
-- NOTES
-- ============================================
-- After running this migration:
-- 1. Doctors can have multiple doctor profiles (one per hospital)
-- 2. Each profile can have different specialties or details per hospital
-- 3. The user_tenant_roles table tracks access permissions
-- 4. The doctors table now stores hospital-specific doctor information
-- 5. Use is_primary flag to indicate default/preferred hospital
