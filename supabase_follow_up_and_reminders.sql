-- Add follow_up_date to patient_assignments table
ALTER TABLE patient_assignments ADD COLUMN IF NOT EXISTS follow_up_date TIMESTAMP WITH TIME ZONE;

-- Add last_visit_date to track when patient was last seen for follow-up
ALTER TABLE patient_assignments ADD COLUMN IF NOT EXISTS last_visit_date TIMESTAMP WITH TIME ZONE;

-- Create index for efficient follow-up queries
CREATE INDEX IF NOT EXISTS idx_patient_assignments_follow_up 
ON patient_assignments(doctor_id, follow_up_date) 
WHERE follow_up_date IS NOT NULL;

-- Create medication_reminders table for tracking patient medication schedules
CREATE TABLE IF NOT EXISTS medication_reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  medication_name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT NOT NULL, -- e.g., "twice daily", "every 8 hours"
  time_of_day TEXT[], -- e.g., ["09:00", "21:00"]
  start_date DATE NOT NULL,
  end_date DATE,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for active medication queries
CREATE INDEX IF NOT EXISTS idx_medication_reminders_patient 
ON medication_reminders(patient_id, is_active) 
WHERE is_active = true;

-- Create daily_reminders table for general health reminders (like mouthwash)
CREATE TABLE IF NOT EXISTS daily_reminders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  reminder_type TEXT NOT NULL, -- e.g., "mouthwash", "floss", "brush"
  reminder_text TEXT NOT NULL,
  time_of_day TEXT NOT NULL, -- e.g., "morning", "night", or specific time "09:00"
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for active daily reminders
CREATE INDEX IF NOT EXISTS idx_daily_reminders_patient 
ON daily_reminders(patient_id, is_active) 
WHERE is_active = true;

-- Insert default mouthwash reminder for all existing patients
INSERT INTO daily_reminders (patient_id, reminder_type, reminder_text, time_of_day, is_active)
SELECT 
  id,
  'mouthwash',
  'Time for your daily mouthwash rinse to maintain oral hygiene',
  'night',
  true
FROM patients
ON CONFLICT DO NOTHING;
