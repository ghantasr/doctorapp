-- Fix appointments table to allow null patient_id for available slots
-- This allows doctors to create appointment slots that are not yet booked

-- Drop ALL check constraints that might conflict
ALTER TABLE public.appointments 
DROP CONSTRAINT IF EXISTS appointments_patient_status_check;

ALTER TABLE public.appointments 
DROP CONSTRAINT IF EXISTS appointments_status_check;

-- Remove the NOT NULL constraint on patient_id
ALTER TABLE public.appointments 
ALTER COLUMN patient_id DROP NOT NULL;

-- Create an index on doctor_id and status for efficient querying of available slots
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_status 
ON public.appointments(doctor_id, status);

-- Create an index on appointment_date for efficient date-based queries
CREATE INDEX IF NOT EXISTS idx_appointments_date 
ON public.appointments(appointment_date);
