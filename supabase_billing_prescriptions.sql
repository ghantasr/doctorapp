-- ============================================
-- BILLING AND PRESCRIPTIONS SYSTEM
-- For generating bills, prescriptions, and medication reminders
-- ============================================

-- ============================================
-- BILLS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.bills (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  patient_id UUID NOT NULL,
  doctor_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  visit_id UUID,
  bill_number TEXT NOT NULL UNIQUE,
  bill_date DATE NOT NULL DEFAULT CURRENT_DATE,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0,
  tax DECIMAL(10, 2) NOT NULL DEFAULT 0,
  discount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(10, 2) NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partial', 'paid')),
  payment_method TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT bills_patient_fkey FOREIGN KEY (patient_id) 
    REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT bills_doctor_fkey FOREIGN KEY (doctor_id) 
    REFERENCES doctors(id) ON DELETE CASCADE,
  CONSTRAINT bills_tenant_fkey FOREIGN KEY (tenant_id) 
    REFERENCES tenants(id) ON DELETE CASCADE,
  CONSTRAINT bills_visit_fkey FOREIGN KEY (visit_id) 
    REFERENCES medical_records(id) ON DELETE SET NULL
);

-- Bill number sequence for auto-generation
CREATE SEQUENCE IF NOT EXISTS bill_number_seq START 1000;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bills_patient ON public.bills(patient_id);
CREATE INDEX IF NOT EXISTS idx_bills_doctor ON public.bills(doctor_id);
CREATE INDEX IF NOT EXISTS idx_bills_tenant ON public.bills(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bills_date ON public.bills(bill_date);
CREATE INDEX IF NOT EXISTS idx_bills_status ON public.bills(payment_status);

-- Update trigger
DROP TRIGGER IF EXISTS update_bills_updated_at ON bills;
CREATE TRIGGER update_bills_updated_at
  BEFORE UPDATE ON bills
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bills_tenant_isolation ON public.bills;
CREATE POLICY bills_tenant_isolation ON public.bills
  FOR ALL
  USING (
    tenant_id IN (
      SELECT tenant_id FROM user_tenant_roles 
      WHERE user_id = auth.uid()
    )
  );

-- ============================================
-- PRESCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.prescriptions (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  patient_id UUID NOT NULL,
  doctor_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  visit_id UUID,
  prescription_number TEXT NOT NULL UNIQUE,
  prescription_date DATE NOT NULL DEFAULT CURRENT_DATE,
  medications JSONB NOT NULL DEFAULT '[]'::jsonb,
  instructions TEXT,
  valid_until DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT prescriptions_patient_fkey FOREIGN KEY (patient_id) 
    REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT prescriptions_doctor_fkey FOREIGN KEY (doctor_id) 
    REFERENCES doctors(id) ON DELETE CASCADE,
  CONSTRAINT prescriptions_tenant_fkey FOREIGN KEY (tenant_id) 
    REFERENCES tenants(id) ON DELETE CASCADE,
  CONSTRAINT prescriptions_visit_fkey FOREIGN KEY (visit_id) 
    REFERENCES medical_records(id) ON DELETE SET NULL
);

-- Prescription number sequence
CREATE SEQUENCE IF NOT EXISTS prescription_number_seq START 1000;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON public.prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_doctor ON public.prescriptions(doctor_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_tenant ON public.prescriptions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_date ON public.prescriptions(prescription_date);
CREATE INDEX IF NOT EXISTS idx_prescriptions_status ON public.prescriptions(status);

-- Update trigger
DROP TRIGGER IF EXISTS update_prescriptions_updated_at ON prescriptions;
CREATE TRIGGER update_prescriptions_updated_at
  BEFORE UPDATE ON prescriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS prescriptions_tenant_isolation ON public.prescriptions;
CREATE POLICY prescriptions_tenant_isolation ON public.prescriptions
  FOR ALL
  USING (
    tenant_id IN (
      SELECT tenant_id FROM user_tenant_roles 
      WHERE user_id = auth.uid()
    )
  );

-- ============================================
-- MEDICATION REMINDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.medication_reminders (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  patient_id UUID NOT NULL,
  prescription_id UUID NOT NULL,
  medication_name TEXT NOT NULL,
  dosage TEXT NOT NULL,
  frequency TEXT NOT NULL,
  reminder_times TEXT[] NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT medication_reminders_patient_fkey FOREIGN KEY (patient_id) 
    REFERENCES patients(id) ON DELETE CASCADE,
  CONSTRAINT medication_reminders_prescription_fkey FOREIGN KEY (prescription_id) 
    REFERENCES prescriptions(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_medication_reminders_patient ON public.medication_reminders(patient_id);
CREATE INDEX IF NOT EXISTS idx_medication_reminders_prescription ON public.medication_reminders(prescription_id);
CREATE INDEX IF NOT EXISTS idx_medication_reminders_active ON public.medication_reminders(is_active);

-- Update trigger
DROP TRIGGER IF EXISTS update_medication_reminders_updated_at ON medication_reminders;
CREATE TRIGGER update_medication_reminders_updated_at
  BEFORE UPDATE ON medication_reminders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.medication_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS medication_reminders_patient_access ON public.medication_reminders;
CREATE POLICY medication_reminders_patient_access ON public.medication_reminders
  FOR ALL
  USING (
    patient_id IN (
      SELECT id FROM patients 
      WHERE user_id = auth.uid()
    )
    OR
    patient_id IN (
      SELECT patient_id FROM patient_assignments
      WHERE doctor_id IN (
        SELECT id FROM doctors WHERE user_id = auth.uid()
      )
    )
  );

-- ============================================
-- ORAL HYGIENE REMINDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.oral_hygiene_reminders (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  patient_id UUID NOT NULL,
  reminder_type TEXT NOT NULL CHECK (reminder_type IN ('brushing', 'flossing', 'mouthwash', 'general')),
  reminder_times TEXT[] NOT NULL,
  message TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT oral_hygiene_reminders_patient_fkey FOREIGN KEY (patient_id) 
    REFERENCES patients(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_oral_hygiene_reminders_patient ON public.oral_hygiene_reminders(patient_id);
CREATE INDEX IF NOT EXISTS idx_oral_hygiene_reminders_active ON public.oral_hygiene_reminders(is_active);

-- Update trigger
DROP TRIGGER IF EXISTS update_oral_hygiene_reminders_updated_at ON oral_hygiene_reminders;
CREATE TRIGGER update_oral_hygiene_reminders_updated_at
  BEFORE UPDATE ON oral_hygiene_reminders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE public.oral_hygiene_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS oral_hygiene_reminders_patient_access ON public.oral_hygiene_reminders;
CREATE POLICY oral_hygiene_reminders_patient_access ON public.oral_hygiene_reminders
  FOR ALL
  USING (
    patient_id IN (
      SELECT id FROM patients 
      WHERE user_id = auth.uid()
    )
  );

-- ============================================
-- NOTES AND SAMPLE DATA STRUCTURE
-- ============================================

-- Bill items JSONB structure example:
-- [
--   {
--     "description": "Dental Cleaning",
--     "quantity": 1,
--     "unit_price": 100.00,
--     "total": 100.00
--   },
--   {
--     "description": "X-Ray",
--     "quantity": 2,
--     "unit_price": 50.00,
--     "total": 100.00
--   }
-- ]

-- Medications JSONB structure example:
-- [
--   {
--     "name": "Amoxicillin",
--     "dosage": "500mg",
--     "frequency": "3 times daily",
--     "duration": "7 days",
--     "instructions": "Take with food"
--   },
--   {
--     "name": "Chlorhexidine Mouthwash",
--     "dosage": "15ml",
--     "frequency": "Twice daily",
--     "duration": "14 days",
--     "instructions": "Rinse for 30 seconds after brushing"
--   }
-- ]
