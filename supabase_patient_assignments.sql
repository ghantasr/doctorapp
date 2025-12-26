-- ============================================
-- PATIENT ASSIGNMENTS TABLE
-- For managing which doctors are assigned to which patients
-- ============================================

-- Create patient_assignments table
CREATE TABLE IF NOT EXISTS public.patient_assignments (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  patient_id UUID NOT NULL,
  doctor_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  assigned_by UUID NOT NULL, -- admin who assigned
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'returned')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT patient_assignments_patient_fkey FOREIGN KEY (patient_id) 
    REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT patient_assignments_doctor_fkey FOREIGN KEY (doctor_id) 
    REFERENCES doctors(id) ON DELETE CASCADE,
  CONSTRAINT patient_assignments_tenant_fkey FOREIGN KEY (tenant_id) 
    REFERENCES tenants(id) ON DELETE CASCADE,
  CONSTRAINT patient_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) 
    REFERENCES users(id) ON DELETE SET NULL
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_patient_assignments_patient ON public.patient_assignments(patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_assignments_doctor ON public.patient_assignments(doctor_id);
CREATE INDEX IF NOT EXISTS idx_patient_assignments_tenant ON public.patient_assignments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_patient_assignments_status ON public.patient_assignments(status);
CREATE INDEX IF NOT EXISTS idx_patient_assignments_doctor_status ON public.patient_assignments(doctor_id, status);

-- Add update trigger
CREATE TRIGGER update_patient_assignments_updated_at
  BEFORE UPDATE ON patient_assignments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE public.patient_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see assignments in their tenant
CREATE POLICY patient_assignments_tenant_isolation ON public.patient_assignments
  FOR ALL
  USING (
    tenant_id IN (
      SELECT tenant_id FROM user_tenant_roles 
      WHERE user_id = auth.uid()
    )
  );

-- NOTES:
-- 1. status: 'active' = currently assigned, 'completed' = doctor finished treatment, 'returned' = sent back to admin for reassignment
-- 2. assigned_by tracks which admin made the assignment
-- 3. Only active assignments are used for filtering patient visibility
-- 4. Doctors can only see patients with active assignments to them
-- 5. Admins can see all patients regardless of assignments
