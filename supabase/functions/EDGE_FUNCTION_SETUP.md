# Supabase Edge Function - Send Notifications

## Setup Instructions

### 1. Install Supabase CLI

```bash
brew install supabase/tap/supabase
```

Or download from: https://github.com/supabase/cli

### 2. Login to Supabase

```bash
supabase login
```

### 3. Link to Your Project

```bash
cd /Users/apple/Desktop/DoctorApp/doctorapp
supabase link --project-ref YOUR_PROJECT_REF
```

Get your project ref from: https://supabase.com/dashboard/project/_/settings/general

### 4. Set Environment Variables (Secrets)

```bash
# Firebase private key (from the service account JSON)
supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCtNFEEZMdmyUC6
... (your full private key here)
-----END PRIVATE KEY-----"

# Firebase client email
supabase secrets set FIREBASE_CLIENT_EMAIL="firebase-adminsdk-fbsvc@doctorapp-7f7e1.iam.gserviceaccount.com"
```

### 5. Deploy the Function

```bash
supabase functions deploy send-notification
```

### 6. Get the Function URL

After deployment, you'll get a URL like:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification
```

## Usage Examples

### Send Follow-up Reminder

```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "follow_up_reminder",
    "data": {
      "doctor_id": "781fff43-9453-4a2c-88ae-c877bd227067",
      "patient_name": "John Doe",
      "follow_up_date": "2026-01-25"
    }
  }'
```

### Send Appointment Reminder (Doctor)

```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "appointment_reminder",
    "data": {
      "user_id": "781fff43-9453-4a2c-88ae-c877bd227067",
      "patient_name": "Jane Smith",
      "appointment_time": "2:00 PM",
      "is_doctor": true
    }
  }'
```

### Send New Patient Assignment

```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "new_assignment",
    "data": {
      "doctor_id": "781fff43-9453-4a2c-88ae-c877bd227067",
      "patient_name": "Sarah Johnson"
    }
  }'
```

## Call from Your Flutter App

```dart
Future<void> sendNotification({
  required String type,
  required Map<String, dynamic> data,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'send-notification',
    body: {
      'type': type,
      'data': data,
    },
  );

  if (response.status == 200) {
    print('Notification sent successfully');
  } else {
    print('Failed to send notification: ${response.data}');
  }
}

// Example usage:
await sendNotification(
  type: 'follow_up_reminder',
  data: {
    'doctor_id': doctorId,
    'patient_name': patientName,
    'follow_up_date': followUpDate,
  },
);
```

## Automate with Database Triggers

Create a Supabase database trigger to automatically call this function:

```sql
-- Function to send follow-up reminder
CREATE OR REPLACE FUNCTION notify_follow_up_reminder()
RETURNS TRIGGER AS $$
BEGIN
  -- Call the edge function
  PERFORM
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object(
        'type', 'follow_up_reminder',
        'data', jsonb_build_object(
          'doctor_id', NEW.doctor_id,
          'patient_name', (SELECT first_name || ' ' || last_name FROM patients WHERE id = NEW.patient_id),
          'follow_up_date', NEW.follow_up_date::text
        )
      )
    );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger when follow-up is created
CREATE TRIGGER on_follow_up_created
  AFTER INSERT ON follow_ups
  FOR EACH ROW
  WHEN (NEW.follow_up_date IS NOT NULL)
  EXECUTE FUNCTION notify_follow_up_reminder();
```

## Schedule Daily Reminders

Create a cron job in Supabase:

1. Go to Database > Cron Jobs
2. Create new job:

```sql
-- Run daily at 9 AM to send follow-up reminders
SELECT cron.schedule(
  'send-daily-follow-up-reminders',
  '0 9 * * *',  -- Every day at 9 AM
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object(
        'type', 'follow_up_reminder',
        'data', jsonb_build_object(
          'doctor_id', doctor_id,
          'patient_name', patient_name,
          'follow_up_date', follow_up_date::text
        )
      )
    )
  FROM (
    SELECT
      f.doctor_id,
      p.first_name || ' ' || p.last_name AS patient_name,
      f.follow_up_date
    FROM follow_ups f
    JOIN patients p ON p.id = f.patient_id
    WHERE f.follow_up_date = CURRENT_DATE
    AND f.completed = false
  ) reminders;
  $$
);
```

## Testing

Test the function locally before deploying:

```bash
supabase functions serve send-notification
```

Then call it:

```bash
curl -X POST 'http://localhost:54321/functions/v1/send-notification' \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "follow_up_reminder",
    "data": {
      "doctor_id": "781fff43-9453-4a2c-88ae-c877bd227067",
      "patient_name": "Test Patient",
      "follow_up_date": "2026-01-25"
    }
  }'
```

## Monitoring

View function logs:

```bash
supabase functions logs send-notification
```

Or in the Supabase Dashboard:
- Go to Edge Functions
- Click on send-notification
- View Logs tab
