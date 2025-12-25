-- ============================================
-- SUPABASE DATABASE SCHEMA WITH RLS POLICIES
-- Multi-tenant Healthcare SaaS
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TENANTS TABLE
-- ============================================
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    logo TEXT,
    branding JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- RLS Policies for tenants
CREATE POLICY "Users can view their tenants"
    ON tenants FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = tenants.id
            AND user_tenant_roles.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can manage their tenant"
    ON tenants FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = tenants.id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role = 'admin'
        )
    );

-- ============================================
-- USER_TENANT_ROLES TABLE
-- ============================================
CREATE TABLE user_tenant_roles (
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

-- RLS Policies for user_tenant_roles
CREATE POLICY "Users can view their own roles"
    ON user_tenant_roles FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Admins can manage roles in their tenant"
    ON user_tenant_roles FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles utr
            WHERE utr.tenant_id = user_tenant_roles.tenant_id
            AND utr.user_id = auth.uid()
            AND utr.role = 'admin'
        )
    );

-- Indexes
CREATE INDEX idx_user_tenant_roles_user ON user_tenant_roles(user_id);
CREATE INDEX idx_user_tenant_roles_tenant ON user_tenant_roles(tenant_id);
CREATE INDEX idx_user_tenant_roles_role ON user_tenant_roles(role);

-- ============================================
-- PATIENTS TABLE
-- ============================================
CREATE TABLE patients (
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

-- RLS Policies for patients
CREATE POLICY "Patients can view their own data"
    ON patients FOR SELECT
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = patients.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role IN ('doctor', 'admin')
        )
    );

CREATE POLICY "Doctors and admins can manage patients in their tenant"
    ON patients FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = patients.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role IN ('doctor', 'admin')
        )
    );

-- Indexes
CREATE INDEX idx_patients_tenant ON patients(tenant_id);
CREATE INDEX idx_patients_user ON patients(user_id);

-- ============================================
-- DOCTORS TABLE
-- ============================================
CREATE TABLE doctors (
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

-- RLS Policies for doctors
CREATE POLICY "Users in tenant can view doctors"
    ON doctors FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = doctors.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
        )
    );

CREATE POLICY "Doctors can update their own profile"
    ON doctors FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "Admins can manage doctors in their tenant"
    ON doctors FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = doctors.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role = 'admin'
        )
    );

-- Indexes
CREATE INDEX idx_doctors_tenant ON doctors(tenant_id);
CREATE INDEX idx_doctors_user ON doctors(user_id);

-- ============================================
-- APPOINTMENTS TABLE
-- ============================================
CREATE TABLE appointments (
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

-- RLS Policies for appointments
CREATE POLICY "Patients can view their appointments"
    ON appointments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM patients
            WHERE patients.id = appointments.patient_id
            AND patients.user_id = auth.uid()
        )
    );

CREATE POLICY "Doctors can view appointments in their tenant"
    ON appointments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = appointments.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role IN ('doctor', 'admin')
        )
    );

CREATE POLICY "Doctors and admins can manage appointments"
    ON appointments FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = appointments.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role IN ('doctor', 'admin')
        )
    );

-- Indexes
CREATE INDEX idx_appointments_tenant ON appointments(tenant_id);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);

-- ============================================
-- MEDICAL_RECORDS TABLE
-- ============================================
CREATE TABLE medical_records (
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

-- RLS Policies for medical_records
CREATE POLICY "Patients can view their medical records"
    ON medical_records FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM patients
            WHERE patients.id = medical_records.patient_id
            AND patients.user_id = auth.uid()
        )
    );

CREATE POLICY "Doctors can view medical records in their tenant"
    ON medical_records FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = medical_records.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role IN ('doctor', 'admin')
        )
    );

CREATE POLICY "Doctors can create medical records"
    ON medical_records FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_tenant_roles
            WHERE user_tenant_roles.tenant_id = medical_records.tenant_id
            AND user_tenant_roles.user_id = auth.uid()
            AND user_tenant_roles.role IN ('doctor', 'admin')
        )
    );

-- Indexes
CREATE INDEX idx_medical_records_tenant ON medical_records(tenant_id);
CREATE INDEX idx_medical_records_patient ON medical_records(patient_id);
CREATE INDEX idx_medical_records_doctor ON medical_records(doctor_id);

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
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_tenant_roles_updated_at BEFORE UPDATE ON user_tenant_roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_doctors_updated_at BEFORE UPDATE ON doctors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_medical_records_updated_at BEFORE UPDATE ON medical_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SAMPLE DATA (FOR TESTING ONLY)
-- ============================================

-- Insert sample tenant
INSERT INTO tenants (id, name, branding) VALUES
    ('11111111-1111-1111-1111-111111111111', 'HealthCare Plus', 
     '{"primaryColor": "#2196F3", "secondaryColor": "#64B5F6", "accentColor": "#FFC107", "fontFamily": "Roboto"}');

-- Note: To add users, they must first authenticate through Supabase Auth
-- Then you can insert their roles:
-- INSERT INTO user_tenant_roles (user_id, tenant_id, role) VALUES
--     ('USER_UUID_FROM_AUTH', '11111111-1111-1111-1111-111111111111', 'doctor');
