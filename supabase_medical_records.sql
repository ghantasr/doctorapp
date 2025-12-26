-- Create medical visits table
CREATE TABLE IF NOT EXISTS public.medical_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  doctor_id uuid NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  visit_date timestamp with time zone NOT NULL DEFAULT now(),
  chief_complaint text,
  diagnosis text,
  treatment_plan text,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create tooth records table for dental charting
CREATE TABLE IF NOT EXISTS public.tooth_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id uuid NOT NULL REFERENCES public.medical_visits(id) ON DELETE CASCADE,
  tooth_number integer NOT NULL CHECK (tooth_number >= 1 AND tooth_number <= 32),
  status text NOT NULL CHECK (status IN ('problem', 'in_progress', 'completed', 'healthy')),
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(visit_id, tooth_number)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_medical_visits_patient 
ON public.medical_visits(patient_id, visit_date DESC);

CREATE INDEX IF NOT EXISTS idx_medical_visits_doctor 
ON public.medical_visits(doctor_id, visit_date DESC);

CREATE INDEX IF NOT EXISTS idx_medical_visits_tenant 
ON public.medical_visits(tenant_id, visit_date DESC);

CREATE INDEX IF NOT EXISTS idx_tooth_records_visit 
ON public.tooth_records(visit_id);

-- Add comments for documentation
COMMENT ON TABLE public.medical_visits IS 'Stores medical visit records for patients';
COMMENT ON TABLE public.tooth_records IS 'Stores dental tooth chart information for each visit';
COMMENT ON COLUMN public.tooth_records.tooth_number IS 'Universal numbering system: 1-32 (1=Upper Right 3rd Molar, 32=Lower Right 3rd Molar)';
COMMENT ON COLUMN public.tooth_records.status IS 'problem=has issue, in_progress=treatment started, completed=treatment done, healthy=no issues';
