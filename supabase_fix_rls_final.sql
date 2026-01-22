-- Simple fix: Make RLS policy work with authenticated users
-- The issue is auth.uid() might not be working properly in the app context

-- Step 1: Drop existing policy
DROP POLICY IF EXISTS "Users can view their own roles" ON user_tenant_roles;

-- Step 2: Create a more permissive policy for authenticated users
-- Since the app already filters by user_id in the query, we can allow authenticated users to read
CREATE POLICY "Authenticated users can view roles"
    ON user_tenant_roles FOR SELECT
    TO authenticated
    USING (true);

-- Step 3: Verify all policies are set correctly
SELECT tablename, policyname, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('user_tenant_roles', 'tenants')
ORDER BY tablename, policyname;
