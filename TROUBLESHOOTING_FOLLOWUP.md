# Troubleshooting Follow-Up Patients Not Showing

## Quick Diagnosis Steps

### Step 1: Check if SQL Migration Was Run ⚠️ CRITICAL

**The most common reason patients don't show up is that the database migration hasn't been run yet.**

1. Open your Supabase dashboard
2. Go to SQL Editor
3. Run the file: `supabase_follow_up_and_reminders.sql`

This adds the required columns:
- `follow_up_date` - When the patient should return
- `last_visit_date` - When the patient was last seen

**Without this migration, the follow-up system cannot work!**

### Step 2: Check Debug Logs

I've added extensive debug logging to the follow-up patients view. 

1. Run the app in debug mode
2. Navigate to Follow-Up Patients screen
3. Check the console/terminal for DEBUG messages

Look for:
```
DEBUG: Total assignments received: X
DEBUG: Status: active
DEBUG: Follow-up date: 2026-01-24T00:00:00.000Z (or null)
DEBUG: Should show: true/false
```

### Step 3: Verify Data in Database

If you have access to Supabase dashboard:

1. Go to Table Editor
2. Open `patient_assignments` table
3. Look for rows where:
   - `doctor_id` = your doctor's ID
   - `status` = 'active'
   - `follow_up_date` is NOT NULL

**Expected columns you should see:**
- id
- patient_id
- doctor_id
- tenant_id
- assigned_by
- assigned_at
- status
- notes
- **follow_up_date** ← If this column is missing, run the migration!
- **last_visit_date** ← If this column is missing, run the migration!

### Step 4: Check Follow-Up Date Format

The follow-up date should be saved as a full ISO timestamp:
```
2026-01-24T00:00:00.000Z
```

NOT just a date:
```
2026-01-24
```

## Common Issues & Solutions

### Issue 1: "follow_up_date column doesn't exist"
**Solution**: Run `supabase_follow_up_and_reminders.sql`

### Issue 2: Follow-up date is set but patient doesn't show
**Possible causes**:
- The `status` is not 'active'
- The `last_visit_date` is after the `follow_up_date` (patient already visited)
- The patient record is missing or deleted

**Check the debug logs** - they will tell you exactly why each patient is being skipped.

### Issue 3: Patient shows up then disappears
**This is actually correct behavior!**

When you mark a patient as visited (checkbox in Create Visit screen), it sets `last_visit_date` to now.

The filter logic is:
```dart
shouldShow = lastVisitDate == null || lastVisitDate.isBefore(followUpDate)
```

So if `last_visit_date` (27 Dec) is AFTER `follow_up_date` (24 Jan), the patient won't show until you set a NEW follow-up date in the future.

## Test Scenario

To properly test:

1. **Set follow-up WITHOUT marking as visited**:
   - Create/edit medical visit
   - Set follow-up date (e.g., tomorrow)
   - DO NOT check "Mark as visited"
   - Submit
   - Patient should appear in Follow-Up Patients list

2. **Mark as visited**:
   - Create another visit for same patient
   - Check "Mark as visited"
   - Submit
   - Patient should DISAPPEAR from list (they've completed their follow-up)

3. **Set new follow-up after visiting**:
   - Create another visit
   - Check "Mark as visited"
   - Also set NEW follow-up date (e.g., next week)
   - Submit
   - Patient should REAPPEAR on the new follow-up date

## Debug Log Example

What you should see in console when it works:

```
DEBUG: ========================================
DEBUG: Total assignments received: 1
DEBUG: --- Assignment ID: abc-123 ---
DEBUG:   Status: active
DEBUG:   Follow-up date: 2026-01-24T00:00:00.000Z
DEBUG:   Last visit date: null
DEBUG:   Patient ID: xyz-789
DEBUG:   Parsed follow-up: 2026-01-24 00:00:00.000Z
DEBUG:   Parsed last visit: null
DEBUG:   Should show: true (lastVisit null: true, or before followUp: false)
DEBUG:   ✓ Added patient: John Doe
DEBUG: ========================================
DEBUG: FINAL COUNT - Total follow-up patients to show: 1
```

What you'll see if the column doesn't exist:

```
DEBUG: Total assignments received: 1
DEBUG: --- Assignment ID: abc-123 ---
DEBUG:   Status: active
DEBUG:   Follow-up date: null  ← PROBLEM: This should have a date!
DEBUG:   SKIPPED - No follow-up date set
DEBUG: FINAL COUNT - Total follow-up patients to show: 0
```

## Still Not Working?

If after running the migration and checking the logs it still doesn't work:

1. Share the debug logs with me
2. Take a screenshot of the `patient_assignments` table in Supabase
3. Share the exact steps you're taking to set the follow-up date

The debug logs will tell us exactly what's happening!
