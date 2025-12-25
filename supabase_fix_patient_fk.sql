-- Fix foreign key on patients.user_id to reference auth.users
-- Run in Supabase SQL editor if you see FK violation: "patients_user_id_fkey"

DO $$
DECLARE
  r record;
BEGIN
  -- Drop ALL foreign keys on patients.user_id (any name)
  FOR r IN (
    SELECT tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
     AND tc.constraint_schema = ccu.constraint_schema
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'patients'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND ccu.column_name = 'user_id'
  ) LOOP
    EXECUTE format('ALTER TABLE public.patients DROP CONSTRAINT %I', r.constraint_name);
  END LOOP;

  -- Create a fresh FK pointing to auth.users
  ALTER TABLE public.patients
    ADD CONSTRAINT patients_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON DELETE SET NULL;
END $$;
