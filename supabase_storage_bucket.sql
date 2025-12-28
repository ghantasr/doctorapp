-- Create storage bucket for medical records (X-rays, etc.)
INSERT INTO storage.buckets (id, name, public)
VALUES ('medical-records', 'medical-records', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for medical-records bucket
CREATE POLICY "Authenticated users can upload medical records"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'medical-records');

CREATE POLICY "Authenticated users can view medical records"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'medical-records');

CREATE POLICY "Authenticated users can update their medical records"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'medical-records');

CREATE POLICY "Authenticated users can delete their medical records"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'medical-records');
