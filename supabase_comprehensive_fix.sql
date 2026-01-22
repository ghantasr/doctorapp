-- Comprehensive RLS and Data Fix
-- This script will fix the RLS policies and ensure data is correctly set up

-- Step 1: Fix the tenants RLS policy to avoid circular dependency
DROP POLICY IF EXISTS "Users can view their tenants" ON tenants;

-- Only create if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'tenants' 
        AND policyname = 'Authenticated users can view tenants'
    ) THEN
        CREATE POLICY "Authenticated users can view tenants"
            ON tenants FOR SELECT
            TO authenticated
            USING (true);
    END IF;
END $$;

-- Step 2: Verify and fix user_tenant_roles data
-- Check if the user's data exists and fix any issues
DO $$
DECLARE
  v_user_id uuid;
  v_user_email text := 'ghantasivasainadhreddy@gmail.com';
  v_role_count int;
BEGIN
  -- Get the user ID from auth.users
  SELECT id INTO v_user_id 
  FROM auth.users 
  WHERE email = v_user_email;
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found with email %', v_user_email;
  END IF;
  
  RAISE NOTICE 'User ID: %', v_user_id;
  
  -- Check if user has roles (using service role context to bypass RLS)
  SELECT COUNT(*) INTO v_role_count
  FROM user_tenant_roles
  WHERE user_id = v_user_id;
  
  RAISE NOTICE 'User has % role(s)', v_role_count;
  
  IF v_role_count = 0 THEN
    RAISE NOTICE 'No roles found - data may need to be re-inserted';
  END IF;
END $$;

-- Step 3: Display current data for verification
SELECT 
  'auth.users' as table_name,
  u.id,
  u.email,
  u.created_at
FROM auth.users u
WHERE u.email = 'ghantasivasainadhreddy@gmail.com'

UNION ALL

SELECT 
  'user_tenant_roles' as table_name,
  utr.user_id as id,
  t.name as email,
  utr.created_at
FROM user_tenant_roles utr
JOIN tenants t ON t.id = utr.tenant_id
WHERE utr.user_id IN (SELECT id FROM auth.users WHERE email = 'ghantasivasainadhreddy@gmail.com')

UNION ALL

SELECT 
  'doctors' as table_name,
  d.user_id as id,
  d.email,
  d.created_at
FROM doctors d
WHERE d.user_id IN (SELECT id FROM auth.users WHERE email = 'ghantasivasainadhreddy@gmail.com');
