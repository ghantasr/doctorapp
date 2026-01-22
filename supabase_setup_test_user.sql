-- Setup test user with a tenant and role
-- Run this to give your logged-in user access to a tenant

-- First, let's check if the user exists and get their ID
-- Replace 'ghantasivasainadhreddy@gmail.com' with your actual email if different
DO $$
DECLARE
  v_user_id uuid;
  v_tenant_id uuid;
BEGIN
  -- Get the user ID from auth.users
  SELECT id INTO v_user_id 
  FROM auth.users 
  WHERE email = 'ghantasivasainadhreddy@gmail.com';
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found with email ghantasivasainadhreddy@gmail.com';
  END IF;
  
  RAISE NOTICE 'Found user ID: %', v_user_id;
  
  -- Check if user already has any tenants
  IF EXISTS (SELECT 1 FROM user_tenant_roles WHERE user_id = v_user_id) THEN
    RAISE NOTICE 'User already has tenant roles assigned';
  ELSE
    RAISE NOTICE 'User has no tenant roles - need to create tenant and assign role';
    
    -- Create a new tenant for this user
    INSERT INTO tenants (name, logo, branding, created_at)
    VALUES (
      'My Test Clinic',
      NULL,
      jsonb_build_object(
        'primaryColor', '#2196F3',
        'secondaryColor', '#FF9800',
        'fontFamily', 'Roboto'
      ),
      NOW()
    )
    RETURNING id INTO v_tenant_id;
    
    RAISE NOTICE 'Created tenant ID: %', v_tenant_id;
    
    -- Assign user as admin of this tenant
    INSERT INTO user_tenant_roles (user_id, tenant_id, role, created_at)
    VALUES (v_user_id, v_tenant_id, 'admin', NOW());
    
    RAISE NOTICE 'Assigned user as admin of tenant';
    
    -- Also create a doctor profile for this user
    INSERT INTO doctors (
      user_id,
      tenant_id,
      first_name,
      last_name,
      specialty,
      license_number,
      email,
      created_at
    )
    VALUES (
      v_user_id,
      v_tenant_id,
      'Test',
      'Doctor',
      'General Practice',
      'LIC-12345',
      'ghantasivasainadhreddy@gmail.com',
      NOW()
    );
    
    RAISE NOTICE 'Created doctor profile';
  END IF;
END $$;

-- Verify the setup
SELECT 
  u.email,
  t.name as tenant_name,
  utr.role,
  d.first_name || ' ' || d.last_name as doctor_name
FROM auth.users u
LEFT JOIN user_tenant_roles utr ON utr.user_id = u.id
LEFT JOIN tenants t ON t.id = utr.tenant_id
LEFT JOIN doctors d ON d.user_id = u.id AND d.tenant_id = utr.tenant_id
WHERE u.email = 'ghantasivasainadhreddy@gmail.com';
