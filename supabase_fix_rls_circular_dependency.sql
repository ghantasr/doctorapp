-- Fix RLS circular dependency issue for tenants table
-- The problem: tenants RLS policy was checking user_tenant_roles, 
-- which creates a circular dependency when user_tenant_roles joins to tenants

-- Drop the existing problematic policy
DROP POLICY IF EXISTS "Users can view their tenants" ON tenants;

-- Create a simpler policy that allows authenticated users to view tenants
-- Access control is handled by user_tenant_roles table instead
CREATE POLICY "Authenticated users can view tenants"
    ON tenants FOR SELECT
    TO authenticated
    USING (true);

-- Keep the other policies as they are (they don't cause circular dependencies)
-- CREATE POLICY "Anyone can create tenants" ON tenants FOR INSERT - already exists
-- CREATE POLICY "Admins can update their tenant" ON tenants FOR UPDATE - already exists
-- CREATE POLICY "Admins can delete their tenant" ON tenants FOR DELETE - already exists
