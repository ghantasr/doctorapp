# Medical Records & Follow-Up System - Setup Guide

## Issues Fixed

### 1. **Medical Visit Date/Time Display** ✅
**Problem**: Visits were showing "27 Dec 2025 at 00:00" because only the date part was being saved.

**Solution**: Updated `createVisit()` method to save full datetime with:
```dart
'record_date': now.toIso8601String()
```
Instead of:
```dart
'record_date': DateTime.now().toIso8601String().split('T')[0]
```

Now visits display correct time like "27 Dec 2025 at 18:56".

---

### 2. **Follow-Up Patients Not Showing** ✅
**Problem**: Patients weren't appearing in Follow-Up Patients list after setting follow-up date.

**Root Cause**: 
- The filtering logic requires `last_visit_date` column to exist
- Database migration needs to be run

**Solution**: 
1. Run the SQL migration: `supabase_follow_up_and_reminders.sql`
2. This adds `last_visit_date` column to `patient_assignments` table
3. Updated service with `markAsVisitedForFollowUp()` method

**How It Works Now**:
- Set follow-up date → Patient appears in list on that date
- Mark as visited → Updates `last_visit_date`, removes from current list
- Can set new follow-up date even when marking as visited
- Patient reappears on new follow-up date

---

### 3. **X-Ray Attachment Feature** ✅ NEW

**Added Functionality**:
- Upload X-ray images (JPG, PNG, PDF) during medical visits
- View uploaded X-rays from visit details
- X-rays stored in Supabase Storage
- URL saved in medical record content

**UI Features**:
- Purple card section in medical visit form
- File picker button "Attach X-Ray"
- Preview attached file with name
- View button to open X-ray in external viewer
- Delete button to remove attachment
- Supports JPG, PNG, PDF formats

**Implementation**:
- Uses `file_picker` package for file selection
- Uses `url_launcher` package to open files
- Uploads to Supabase Storage bucket `medical-records`
- Path structure: `xrays/{patient_id}/{timestamp}.{ext}`

---

## Required Steps

### 1. Run Database Migration
Execute in Supabase SQL Editor:
```bash
supabase_follow_up_and_reminders.sql
```

This adds the `last_visit_date` column needed for follow-up tracking.

### 2. Create Storage Bucket
Execute in Supabase SQL Editor:
```bash
supabase_storage_bucket.sql
```

This creates:
- Storage bucket: `medical-records`
- Public access enabled
- RLS policies for authenticated users

### 3. Install Dependencies
Already done automatically:
```yaml
file_picker: ^8.0.0+1
url_launcher: ^6.2.5
```

---

## How to Use

### Setting Follow-Up Dates
1. Open patient medical visit screen
2. Scroll to "Follow-Up Management" section (blue card)
3. Options:
   - ✓ **Mark as visited**: Records completion of current follow-up
   - 📅 **Set Follow-Up Date**: Schedule next visit
4. Can do both actions together!

### Attaching X-Rays
1. Create/edit medical visit
2. Scroll to "X-Ray Attachment" section (purple card)
3. Click "Attach X-Ray"
4. Select JPG, PNG, or PDF file
5. File uploads when you submit the visit
6. View anytime by clicking the view icon

### Viewing Follow-Up Patients
1. Open drawer menu → "Follow-Up Patients"
2. Shows patients categorized as:
   - **Overdue** (red): Past due date
   - **Today** (blue): Due today
   - **Upcoming** (green): Future dates
3. Only shows patients who haven't completed current follow-up

---

## Technical Details

### Medical Visit Model
```dart
class MedicalVisit {
  final DateTime visitDate;  // Now saves full datetime
  final String? xrayUrl;     // NEW: URL to uploaded X-ray
  // ... other fields
}
```

### Follow-Up Logic
Patient shows in list when:
- `follow_up_date` IS NOT NULL
- AND (`last_visit_date` IS NULL OR `last_visit_date` < `follow_up_date`)

### Storage Structure
```
medical-records/
  └── xrays/
      └── {patient_id}/
          ├── 1735315680123.jpg
          ├── 1735315820456.png
          └── 1735316000789.pdf
```

---

## Files Modified

1. `lib/core/medical/medical_records_service.dart`
   - Added `xrayUrl` field
   - Fixed datetime storage
   - Added `xrayUrl` parameter to create/update methods

2. `lib/app/doctor/create_visit_screen.dart`
   - Added X-ray upload functionality
   - Added file picker integration
   - Added URL launcher for viewing files
   - Added UI for X-ray attachment

3. `lib/core/patient/patient_assignment_service.dart`
   - Added `markAsVisitedForFollowUp()` method

4. `lib/app/doctor/follow_up_patients_view.dart`
   - Updated filtering logic for visited status

5. `pubspec.yaml`
   - Added `file_picker` and `url_launcher` packages

6. `supabase_follow_up_and_reminders.sql`
   - Added `last_visit_date` column

7. `supabase_storage_bucket.sql` (NEW)
   - Creates storage bucket and policies

---

## Testing Checklist

- [ ] Medical visits show correct date and time
- [ ] Follow-up date can be set during visit
- [ ] Mark as visited checkbox works
- [ ] Patient appears in Follow-Up Patients list
- [ ] Can attach X-ray files
- [ ] Can view attached X-rays
- [ ] X-rays persist after submission
- [ ] Both visited + new follow-up date works together
