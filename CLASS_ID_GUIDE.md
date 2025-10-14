# 🏷️ Class ID Configuration Guide

## Current Setup

Your beacon is broadcasting:
- **UUID:** `215d0698-0b3d-34a6-a844-5ce2b2447f1a` (School identifier)
- **Major:** (not shown in logs)
- **Minor:** `101` ← **This becomes your Class ID**

## How App Reads Class ID

```dart
// beacon_service.dart line 333
String getClassIdFromBeacon(Beacon beacon) {
  return beacon.minor.toString();  // Returns "101"
}
```

---

## Option 1: Add Class Name Mapping (Recommended) ✅

### Pros
- Easy to implement
- No beacon reconfiguration needed
- Human-readable class names

### Implementation

**Step 1:** Open `lib/core/services/beacon_service.dart`

**Step 2:** Replace `getClassIdFromBeacon` method (around line 333):

```dart
String getClassIdFromBeacon(Beacon beacon) {
  // Map beacon minor values to class names
  final classMapping = {
    101: 'cs1',      // Computer Science 1
    102: 'cs2',      // Computer Science 2
    201: 'math1',    // Mathematics 1
    202: 'math2',    // Mathematics 2
    301: 'phys1',    // Physics 1
    // Add more mappings as needed
  };
  
  final minor = beacon.minor;
  return classMapping[minor] ?? 'class_$minor';  // Fallback to "class_101"
}
```

**Step 3:** Hot restart app

---

## Option 2: Use Major Value

### Pros
- Simple logic
- Consistent naming

### Implementation

```dart
String getClassIdFromBeacon(Beacon beacon) {
  return 'cs${beacon.major}';  // e.g., major=1 → "cs1"
}
```

**Requirement:** Configure your beacon with `major=1` for CS1, `major=2` for CS2, etc.

---

## Option 3: Combined Major + Minor

### Pros
- Supports many classes
- Hierarchical structure

### Implementation

```dart
String getClassIdFromBeacon(Beacon beacon) {
  final major = beacon.major;  // Building or floor
  final minor = beacon.minor;  // Room or class number
  
  // Example: major=1 (Building 1), minor=101 (Room 101)
  return 'b${major}_r${minor}';  // Returns "b1_r101"
}
```

---

## Option 4: Keep Numeric (Current)

### Pros
- No changes needed
- Matches beacon configuration

### Current Behavior
- Beacon `minor=101` → Class ID `"101"`
- Backend stores: `classId: "101"`
- UI displays: `"Check-in recorded for Class 101!"`

**To keep this:** Do nothing! It already works.

---

## Recommendation 🌟

**Use Option 1 (Class Name Mapping)** because:
1. **No beacon reconfiguration** needed
2. **Human-readable** names in database and UI
3. **Flexible** - add new classes easily
4. **Backward compatible** - uses same minor values

### Example Result

**Before (current):**
```
✅ Check-in recorded for Class 101!
📊 Student 88 in Class 101 - Confirmed
```

**After (with mapping):**
```
✅ Check-in recorded for Class cs1!
📊 Student 88 in Class cs1 - Confirmed
```

---

## Testing Your Choice

### If using Option 1:

1. Add mapping to `beacon_service.dart`
2. Hot restart app
3. Approach beacon
4. Check logs for:
   ```
   📱 Submitting check-in: Student=88, Class=cs1, Device=...
   ```

### Verify in Backend

```bash
# Check what's stored in MongoDB
db.attendances.find({ studentId: "88" }).pretty()

# Should show:
{
  studentId: "88",
  classId: "cs1",  // ← Changed!
  status: "confirmed",
  ...
}
```

---

## Beacon Configuration Reference

If you need to reconfigure your beacon:

| Property | Current Value | Purpose |
|----------|---------------|---------|
| UUID | `215d0698-0b3d-34a6-a844-5ce2b2447f1a` | School/Organization ID (don't change) |
| Major | Unknown | Building/Floor/Department ID |
| Minor | `101` | Room/Class ID (currently used) |

**Beacon App Settings:**
- Most beacon apps (e.g., "Beacon Simulator") let you edit Major/Minor values
- Look for "Edit Beacon" or "Configure" in your beacon app
- Change `minor` to `1` if you want `class_1` or use mapping for `101 → cs1`

---

## Quick Decision Tree

```
Do you want human-readable class names (cs1, math1)?
├─ YES → Use Option 1 (Mapping) ✅
└─ NO  → Keep current (numeric IDs) ✅

Can you reconfigure beacon hardware?
├─ YES → Options 1, 2, or 3 available
└─ NO  → Use Option 1 (no hardware change needed) ✅

Do you have multiple buildings/floors?
├─ YES → Use Option 3 (Combined Major+Minor)
└─ NO  → Use Option 1 or 2
```

---

## Final Notes

- **Database Impact:** Changing class ID format affects historical data
- **Consistency:** Pick one format and stick with it
- **Testing:** Test with beacon before deploying to production
- **Documentation:** Document your class ID scheme for future reference

Need help implementing? Let me know which option you prefer! 🚀
