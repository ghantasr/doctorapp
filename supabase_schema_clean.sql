-- ============================================
-- SUPABASE DATABASE SCHEMA WITH RLS POLICIES
-- Multi-tenant Healthcare SaaS - CLEAN VERSION
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TENANTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    logo TEXT,
    branding JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- ============================================
-- USER_TENANT_ROLES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_tenant_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('doctor', 'admin', 'patient')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, tenant_id)
);

-- Enable RLS
ALTER TABLE user_tenant_roles ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_tenant_roles_user ON user_tenant_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tenant_roles_tenant ON user_tenant_roles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_user_tenant_roles_role ON user_tenant_roles(role);

-- ============================================
-- PATIENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    date_of_birth DATE,
    gender TEXT,
    address JSONB,
    medical_history JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_patients_tenant ON patients(tenant_id);
CREATE INDEX IF NOT EXISTS idx_patients_user ON patients(user_id);

-- ============================================
-- DOCTORS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    specialty TEXT,
    license_number TEXT,
    phone TEXT,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, user_id)
);

-- Enable RLS
ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_doctors_tenant ON doctors(tenant_id);
CREATE INDEX IF NOT EXISTS idx_doctors_user ON doctors(user_id);

-- ============================================
-- APPOINTMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    appointment_date TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER DEFAULT 30,
    status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_appointments_tenant ON appointments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_appointments_patient ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);

-- ============================================
-- MEDICAL_RECORDS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS medical_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES doctors(id) ON DELETE SET NULL,
    record_type TEXT NOT NULL,
    title TEXT NOT NULL,
    content JSONB,
    file_url TEXT,
    record_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_medical_records_tenant ON medical_records(tenant_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_patient ON medical_records(patient_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_doctor ON medical_records(doctor_id);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_tenants_updated_at ON tenants;
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_tenant_roles_updated_at ON user_tenant_roles;
CREATE TRIGGER update_user_tenant_roles_updated_at BEFORE UPDATE ON user_tenant_roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_patients_updated_at ON patients;
CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_doctors_updated_at ON doctors;
CREATE TRIGGER update_doctors_updated_at BEFORE UPDATE ON doctors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_appointments_updated_at ON appointments;
CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_medical_records_updated_at ON medical_records;
CREATE TRIGGER update_medical_records_updated_at BEFORE UPDATE ON medical_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- CLEAN ALL OLD RLS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view their tenants" ON tenants;
DROP POLICY IF EXISTS "Admins can manage their tenant" ON tenants;
DROP POLICY IF EXISTS "Anyone can create tenants" ON tenants;
DROP POLICY IF EXISTS "Admins can update their tenant" ON tenants;
DROP POLICY IF EXISTS "Admins can delete their tenant" ON tenants;
DROP POLICY IF EXISTS "Enable create for authenticated users" ON tenants;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON tenants;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON tenants;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON tenants;

DROP POLICY IF EXISTS "Users can view their own roles" ON user_tenant_roles;
DROP POLICY IF EXISTS "Admins can manage roles in their tenant" ON user_tenant_roles;
DROP POLICY IF EXISTS "Only service role can manage roles" ON user_tenant_roles;
DROP POLICY IF EXISTS "Only service role can update roles" ON user_tenant_roles;
DROP POLICY IF EXISTS "Only service role can delete roles" ON user_tenant_roles;

DROP POLICY IF EXISTS "Patients can view their own data" ON patients;
DROP POLICY IF EXISTS "Doctors and admins can manage patients in their tenant" ON patients;

DROP POLICY IF EXISTS "Users in tenant can view doctors" ON doctors;
DROP POLICY IF EXISTS "Doctors can update their own profile" ON doctors;
DROP POLICY IF EXISTS "Admins can manage doctors in their tenant" ON doctors;

DROP POLICY IF EXISTS "Patients can view their appointments" ON appointments;
DROP POLICY IF EXISTS "Doctors can view appointments in their tenant" ON appointments;
DROP POLICY IF EXISTS "Doctors and admins can manage appointments" ON appointments;

DROP POLICY IF EXISTS "Patients can view their medical records" ON medical_records;
DROP POLICY IF EXISTS "Doctors can view medical records in their tenant" ON medical_records;
DROP POLICY IF EXISTS "Doctors can create medical records" ON medical_records;

-- ============================================
-- SIMPLE RLS POLICIES - START FRESH
-- ============================================

-- TENANTS: Allow authenticated users to create/view/update/delete
CREATE POLICY "Allow authenticated users for tenants"
    ON tenants FOR ALL
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- USER_TENANT_ROLES: Allow authenticated users to view their own roles
CREATE POLICY "Users can view their own roles"
    ON user_tenant_roles FOR SELECT
    USING (user_id = auth.uid());

-- USER_TENANT_ROLES: Allow insert/update/delete for authenticated users
CREATE POLICY "Users can manage tenant roles"
    ON user_tenant_roles FOR ALL
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- PATIENTS: Allow authenticated users in the system
CREATE POLICY "Allow authenticated users for patients"
    ON patients FOR ALL
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- DOCTORS: Allow authenticated users in the system
CREATE POLICY "Allow authenticated users for doctors"
    ON doctors FOR ALL
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- APPOINTMENTS: Allow authenticated users in the system
CREATE POLICY "Allow authenticated users for appointments"
    ON appointments FOR ALL
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- MEDICAL_RECORDS: Allow authenticated users in the system
CREATE POLICY "Allow authenticated users for medical records"
    ON medical_records FOR ALL
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================
-- SAMPLE DATA (FOR TESTING ONLY)
-- ============================================

-- Insert sample tenant
INSERT INTO tenants (id, name, branding) 
VALUES ('11111111-1111-1111-1111-111111111111', 'HealthCare Plus', 
        '{"primaryColor": "#2196F3", "secondaryColor": "#64B5F6", "accentColor": "#FFC107", "fontFamily": "Roboto"}')
ON CONFLICT DO NOTHING;
