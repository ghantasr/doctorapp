-- ============================================
-- TOOTH RECORDS TABLE
-- For dental/medical visit tooth tracking
-- ============================================

-- Create tooth_records table
CREATE TABLE IF NOT EXISTS public.tooth_records (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  visit_id UUID NOT NULL,
  tooth_number INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('problem', 'in_progress', 'completed', 'healthy')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT tooth_records_visit_id_fkey FOREIGN KEY (visit_id) 
    REFERENCES medical_records(id) ON DELETE CASCADE
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_tooth_records_visit ON public.tooth_records(visit_id);
CREATE INDEX IF NOT EXISTS idx_tooth_records_tooth_number ON public.tooth_records(tooth_number);

-- Add update trigger
CREATE TRIGGER update_tooth_records_updated_at
  BEFORE UPDATE ON tooth_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- NOTES:
-- 1. tooth_number: Standard dental numbering (1-32 for adults)
-- 2. status: problem, in_progress, completed, healthy
-- 3. visit_id references medical_records table (record_type = 'visit')
