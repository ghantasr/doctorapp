-- Add address column to tenants table
-- This allows storing clinic/hospital physical address

ALTER TABLE tenants 
ADD COLUMN IF NOT EXISTS address TEXT;

-- Add comment to document the field
COMMENT ON COLUMN tenants.address IS 'Physical address of the clinic/hospital';
