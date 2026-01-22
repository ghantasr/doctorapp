-- Diagnostic script to check user data and RLS policies
-- Run this to understand why the app can't see the user's roles

-- Check 1: Verify user exists in auth.users
SELECT 
  'User in auth.users' as check_name,
  id as user_id,
  email,
  created_at
FROM auth.users 
WHERE email = 'ghantasivasainadhreddy@gmail.com';

-- Check 2: Verify user_tenant_roles data exists (service role view)
SELECT 
  'Roles data exists' as check_name,
  utr.user_id,
  utr.tenant_id,
  utr.role,
  t.name as tenant_name
FROM user_tenant_roles utr
JOIN tenants t ON t.id = utr.tenant_id
WHERE utr.user_id = (SELECT id FROM auth.users WHERE email = 'ghantasivasainadhreddy@gmail.com');

-- Check 3: Verify RLS policies on user_tenant_roles
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_tenant_roles'
ORDER BY policyname;

-- Check 4: Verify RLS policies on tenants
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'tenants'
ORDER BY policyname;

-- Check 5: Test if RLS is the issue - try to select as the user would
-- This simulates what the app sees
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "781fff43-9453-4a2c-88ae-c877bd227067"}';

SELECT 
  'What user can see in user_tenant_roles' as check_name,
  COUNT(*) as role_count
FROM user_tenant_roles
WHERE user_id = '781fff43-9453-4a2c-88ae-c877bd227067';

RESET ROLE;
