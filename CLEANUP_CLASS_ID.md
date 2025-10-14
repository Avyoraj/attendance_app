# 🧹 Clean Up Old Class ID Data

## Problem
Your dashboard shows inconsistent class IDs:
- Some entries: `CS1` (alphanumeric) ❌
- Other entries: `101` (numeric) ✅

## Root Cause
- **Old test data** or **manual API calls** used "CS1"
- **Current app** correctly uses "101" (from beacon minor value)

---

## Solution 1: Delete Old CS1 Records (Clean Slate)

### Option A: Delete via MongoDB Shell
```javascript
// Connect to MongoDB
use attendance-db

// Delete all CS1 records
db.attendances.deleteMany({ classId: "CS1" })

// Verify deletion
db.attendances.find({ classId: "CS1" }).count()  // Should return 0

// Check remaining records
db.attendances.find({ classId: "101" }).pretty()
```

### Option B: Delete via Backend API (Add this endpoint)

Add to `attendance-backend/server.js`:

```javascript
/**
 * DELETE /api/attendance/cleanup
 * Clean up test data with old class IDs
 */
app.delete('/api/attendance/cleanup', async (req, res) => {
  try {
    const { oldClassId } = req.body;
    
    if (!oldClassId) {
      return res.status(400).json({ error: 'oldClassId required' });
    }
    
    const result = await Attendance.deleteMany({ classId: oldClassId });
    
    res.json({
      message: 'Cleanup successful',
      deletedCount: result.deletedCount
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

Then call it:
```bash
curl -X DELETE https://attendance-backend-omega.vercel.app/api/attendance/cleanup \
  -H "Content-Type: application/json" \
  -d '{"oldClassId":"CS1"}'
```

---

## Solution 2: Update CS1 to 101 (Preserve Data)

If you want to **keep the attendance records** but fix the class ID:

### Option A: MongoDB Update
```javascript
// Connect to MongoDB
use attendance-db

// Update all CS1 to 101
db.attendances.updateMany(
  { classId: "CS1" },
  { $set: { classId: "101" } }
)

// Verify update
db.attendances.find({ classId: "CS1" }).count()  // Should be 0
db.attendances.find({ classId: "101" }).count()  // Should include updated records
```

### Option B: Backend Endpoint

Add to `server.js`:

```javascript
/**
 * POST /api/attendance/migrate-class-id
 * Migrate old class IDs to new format
 */
app.post('/api/attendance/migrate-class-id', async (req, res) => {
  try {
    const { oldClassId, newClassId } = req.body;
    
    if (!oldClassId || !newClassId) {
      return res.status(400).json({ 
        error: 'Both oldClassId and newClassId required' 
      });
    }
    
    const result = await Attendance.updateMany(
      { classId: oldClassId },
      { $set: { classId: newClassId } }
    );
    
    res.json({
      message: 'Migration successful',
      modifiedCount: result.modifiedCount
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

Then call it:
```bash
curl -X POST https://attendance-backend-omega.vercel.app/api/attendance/migrate-class-id \
  -H "Content-Type: application/json" \
  -d '{"oldClassId":"CS1","newClassId":"101"}'
```

---

## Solution 3: Prevent Future Inconsistencies

### Add Validation in Backend

Update `server.js` check-in endpoint to enforce numeric class IDs:

```javascript
app.post('/api/check-in', async (req, res) => {
  try {
    const { studentId, classId, deviceId, rssi, distance, beaconMajor, beaconMinor } = req.body;

    // Validation
    if (!studentId || !classId) {
      return res.status(400).json({ 
        error: 'Missing required fields',
        required: ['studentId', 'classId']
      });
    }

    // NEW: Enforce numeric class ID format
    if (!/^\d+$/.test(classId)) {
      return res.status(400).json({
        error: 'Invalid classId format',
        message: 'Class ID must be numeric (e.g., "101", "102")',
        received: classId
      });
    }
    
    // ... rest of the code
```

This will reject any non-numeric class IDs in the future.

---

## Recommended Approach 🌟

**Step 1:** Clean up old data (Solution 1 or 2)

**Step 2:** Add validation (Solution 3) to prevent future issues

**Step 3:** Verify your app always sends numeric:
```dart
// This is already correct in your code!
String getClassIdFromBeacon(Beacon beacon) {
  return beacon.minor.toString();  // Always numeric ✅
}
```

---

## Quick Fix (MongoDB Shell)

If you just want to **delete the CS1 records** quickly:

```bash
# 1. Connect to your MongoDB (local or cloud)
mongo "mongodb://your-connection-string"

# 2. Switch to database
use attendance-db

# 3. Delete CS1 records
db.attendances.deleteMany({ classId: "CS1" })

# 4. Verify
db.attendances.find({}).pretty()
```

Or if using **MongoDB Compass** (GUI):
1. Open Compass
2. Connect to database
3. Go to "attendances" collection
4. Click "Filter" and enter: `{ "classId": "CS1" }`
5. Select all → Delete

---

## Verification

After cleanup, your dashboard should only show:
- ✅ **Student 90, Class ID: 101** (numeric only)

No more CS1! 🎉

---

## Summary

| Issue | Cause | Fix |
|-------|-------|-----|
| Mixed class IDs (CS1 & 101) | Old test data | Delete or update old records |
| Current app behavior | ✅ Already correct | No app changes needed |
| Future prevention | Need validation | Add backend validation (optional) |

**Your app code is already correct!** Just clean up the database. 🚀
