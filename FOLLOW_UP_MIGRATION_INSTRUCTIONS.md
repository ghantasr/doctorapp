# Follow-Up System Migration Instructions

## Overview
This migration adds a `last_visit_date` field to track when patients complete their follow-up visits, enabling proper follow-up scheduling workflow.

## Database Migration Required

Run this SQL in your Supabase SQL Editor:

```sql
-- Add last_visit_date to track when patient was last seen for follow-up
ALTER TABLE patient_assignments ADD COLUMN IF NOT EXISTS last_visit_date TIMESTAMP WITH TIME ZONE;
```

This is already included in `supabase_follow_up_and_reminders.sql` - just run that file in Supabase.

## How the New System Works

### 1. **During Medical Visit**
- Doctor can check "Mark patient as visited for follow-up"
  - This sets `last_visit_date` to current timestamp
  - Patient is removed from current/overdue follow-up list
  
- Doctor can also schedule next follow-up date
  - Sets `follow_up_date` to selected future date
  - Both actions can be done together or separately

### 2. **Follow-Up Patients View**
Shows patients where:
- `follow_up_date` is set (not null)
- AND either:
  - `last_visit_date` is null (never visited)
  - OR `last_visit_date` < `follow_up_date` (visited before current follow-up date)

### 3. **Example Workflow**

**Scenario 1: Initial Follow-Up**
1. Patient has `follow_up_date` = Jan 10, 2026
2. `last_visit_date` = null
3. Patient shows in follow-up list on/after Jan 10

**Scenario 2: Patient Visits**
1. Doctor marks as visited on Jan 10
2. `last_visit_date` = Jan 10, 2026
3. Patient removed from follow-up list

**Scenario 3: Schedule Next Visit**
1. During same visit, doctor schedules next follow-up for Feb 15
2. `follow_up_date` = Feb 15, 2026
3. Patient will reappear in follow-up list on Feb 15

**Scenario 4: Mark Visited + Schedule Together**
1. Check "Mark as visited" ✓
2. Set next follow-up date to Feb 15
3. Both actions saved:
   - Current visit tracked (`last_visit_date` = today)
   - Next visit scheduled (`follow_up_date` = Feb 15)

## Key Benefits

✅ **Proper Visit Tracking**: Know when patient last visited
✅ **Flexible Scheduling**: Can schedule future visits even when marking as visited
✅ **Clean Follow-Up List**: Only shows patients who haven't completed their current follow-up
✅ **Historical Data**: Maintains both last visit and next visit dates
✅ **No Data Loss**: Patients aren't removed from system, just from current follow-up view

## Code Changes Summary

1. **Database**: Added `last_visit_date` column
2. **Service**: Added `markAsVisitedForFollowUp()` method
3. **UI**: Removed conditional hiding of follow-up date picker
4. **Logic**: Updated filtering to check both dates
