    -- Fix appointments table to properly handle patient relationships
    -- This resolves the foreign key error when querying appointments

    -- First, drop the existing foreign key constraint
    ALTER TABLE public.appointments 
    DROP CONSTRAINT IF EXISTS appointments_patient_id_fkey;

    -- Clean up orphaned records - set patient_id to NULL for appointments 
    -- that reference non-existent patients
    UPDATE public.appointments 
    SET patient_id = NULL 
    WHERE patient_id IS NOT NULL 
    AND patient_id NOT IN (SELECT id FROM public.patients);

    -- Allow null patient_id (for available slots)
    ALTER TABLE public.appointments 
    ALTER COLUMN patient_id DROP NOT NULL;

    -- Recreate foreign key with proper ON DELETE behavior
    ALTER TABLE public.appointments 
    ADD CONSTRAINT appointments_patient_id_fkey 
    FOREIGN KEY (patient_id) 
    REFERENCES public.patients(id) 
    ON DELETE SET NULL;

    -- Create helpful indexes if they don't exist
    CREATE INDEX IF NOT EXISTS idx_appointments_patient_id 
    ON public.appointments(patient_id) 
    WHERE patient_id IS NOT NULL;

    CREATE INDEX IF NOT EXISTS idx_appointments_doctor_status 
    ON public.appointments(doctor_id, status);

    CREATE INDEX IF NOT EXISTS idx_appointments_date 
    ON public.appointments(appointment_date);

    -- Ensure scheduled status means patient_id is not null
    -- Available status means patient_id is null
    UPDATE public.appointments 
    SET status = 'available' 
    WHERE patient_id IS NULL AND status = 'scheduled';

    UPDATE public.appointments 
    SET status = 'scheduled' 
    WHERE patient_id IS NOT NULL AND status = 'available';
