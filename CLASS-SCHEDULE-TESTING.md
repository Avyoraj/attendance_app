# Class Schedule Integration - Testing Guide

## Quick Test Plan

### Test 1: Cooldown Display Shows Class Schedule
**Setup**: 
1. Mark attendance successfully at 10:15 AM
2. Observe cooldown card

**Expected Result**:
```
Cooldown Active
Class: [CLASS_ID]
────────────────
⏰ Class ends at 11:00 AM
   (in 45 minutes)

Next check-in available:
in 12 minutes

ℹ️ Class ends at 11:00 AM (in 45 minutes).
   Next check-in available after cooldown.
```

**Pass Criteria**:
- ✅ Shows "Class ends at 11:00 AM" (not just "45 minutes")
- ✅ Shows both class end time and cooldown remaining time
- ✅ Time formats are "11:00 AM" (12-hour format with AM/PM)
- ✅ Duration formats are "in 45 minutes" (human-readable)

---

### Test 2: Cancelled State Shows Next Class Time
**Setup**:
1. Mark attendance at 10:15 AM
2. Leave classroom (let timer expire or cancel manually)
3. Observe cancelled card

**Expected Result**:
```
❌ Attendance Cancelled
────────────────
⏰ Current class ends at 11:00 AM
   (in 45 minutes)

Try again in next class:
🎓 11:00 AM
   (in 45 minutes)

ℹ️ Attendance cancelled.
   Current class ends at 11:00 AM (in 45 minutes).
   Try again in next class at 11:00 AM.
```

**Pass Criteria**:
- ✅ Shows when current class ends
- ✅ Shows when next class starts
- ✅ Both times are in 12-hour format
- ✅ Full message provides clear guidance

---

### Test 3: Break Time Handling (1:30 PM - 2:00 PM)
**Setup**:
1. Cancel attendance at 1:15 PM
2. Observe next class time

**Expected Result**:
- Next class shown as "2:00 PM" (not 2:15 PM)
- System skips the break period

**Pass Criteria**:
- ✅ Next class time is 2:00 PM (after break)
- ✅ Not showing 2:15 PM (which would be during/after break)

---

### Test 4: Cooldown After Class Ends
**Setup**:
1. Mark attendance at 10:00 AM
2. Wait until 11:05 AM (class ended but cooldown still active)
3. Observe cooldown card

**Expected Result**:
```
Cooldown Active
Next check-in available:
in 10 minutes
```

**Pass Criteria**:
- ✅ Class end time no longer shown (class already ended)
- ✅ Only shows cooldown remaining time
- ✅ Message is "Next check-in available in X minutes"

---

### Test 5: Cancelled State Persistence (Backend Integration)
**Setup**:
1. Mark and cancel attendance at 10:15 AM
2. Close app completely
3. Reopen app at 10:20 AM (within same class hour)
4. Observe UI state

**Expected Result**:
- Cancelled card still visible (not switched to "Scanning")
- Shows schedule info: "Current class ends at 11:00 AM"
- Shows next class: "Try again at 11:00 AM"

**Pass Criteria**:
- ✅ Cancelled state persists (no confusion)
- ✅ Schedule info is calculated correctly after app restart
- ✅ No flash of "Scanning" state

---

### Test 6: After College Hours (After 5:30 PM)
**Setup**:
1. Cancel attendance at 5:00 PM
2. Observe next class time

**Expected Result**:
- Next class shown as "Tomorrow 10:30 AM" (or just "10:30 AM")

**Pass Criteria**:
- ✅ System recognizes college hours ended
- ✅ Shows tomorrow's first class time

---

### Test 7: Time Update Refresh
**Setup**:
1. Enter cooldown state
2. Wait 2-3 minutes without refreshing
3. Observe if times update

**Expected Result**:
- Time remaining counts down
- "in 45 minutes" becomes "in 43 minutes"
- Updates automatically every minute

**Pass Criteria**:
- ✅ Cooldown timer updates every minute
- ✅ All schedule-related times recalculate
- ✅ No need to manually refresh

---

## Visual Verification Checklist

### Cooldown Card
- [ ] Header: "🕐 Cooldown Active" with blue gradient background
- [ ] Class ID badge with rounded background
- [ ] Divider line below class ID
- [ ] Clock icon (⏰) next to class end time
- [ ] Class end time in bold (e.g., "11:00 AM")
- [ ] Time remaining in lighter text (e.g., "(in 45 minutes)")
- [ ] "Next check-in available:" label
- [ ] Large bold countdown (e.g., "in 12 minutes")
- [ ] Info box with full schedule message
- [ ] All text readable with good contrast

### Cancelled Card
- [ ] Header: "❌ Attendance Cancelled" with red gradient background
- [ ] Divider line below header
- [ ] Clock icon (⏰) next to current class end time
- [ ] "Current class ends at" label
- [ ] Bold class end time
- [ ] Time remaining in lighter text
- [ ] White info box with "Try again in next class:"
- [ ] Class icon (🎓) next to next class time
- [ ] Large bold next class time
- [ ] Time until next class in lighter text
- [ ] Full message at bottom with clear guidance

## Console Log Verification

### Expected Logs During Cooldown Load:
```
🔄 Syncing attendance state from backend...
✅ Synced 1 attendance records on startup
✅ Found confirmed attendance for Class CS101
🎓 Cooldown info updated with schedule awareness
```

### Expected Logs During Cancelled Load:
```
🔄 Syncing attendance state from backend...
✅ Synced 1 attendance records on startup
❌ Found cancelled attendance for Class CS101
🎓 Cancelled state loaded with schedule awareness
```

### Expected Logs During Refresh:
```
🎓 Cooldown info updated with schedule awareness
```
OR
```
🎓 Cancelled info updated with schedule awareness
```

## Common Issues & Solutions

### Issue: Times not updating
**Solution**: Check if `_startCooldownRefreshTimer()` is called in `initState()`

### Issue: Schedule info not showing
**Solution**: Verify `cooldownInfo` contains keys like `classEndTimeFormatted`, `nextClassTimeFormatted`

### Issue: Cancelled state disappears immediately
**Solution**: Check backend two-stage cleanup is working (records should persist for 1 hour)

### Issue: Wrong class end time calculation
**Solution**: Verify `AppConstants.classDuration` is set to `Duration(hours: 1)`

### Issue: Break time not handled correctly
**Solution**: Check `ScheduleUtils.isDuringBreak()` logic and break constants in `AppConstants`

## Performance Verification

- [ ] UI renders smoothly without lag
- [ ] Schedule calculations complete instantly (<100ms)
- [ ] Cooldown refresh timer doesn't cause UI jank
- [ ] No memory leaks from timer (check with DevTools)
- [ ] Backend API calls complete within 2 seconds

## Edge Case Testing

### During Break (1:30 PM - 2:00 PM)
1. Mark attendance at 1:25 PM
2. Cancel at 1:35 PM (during break)
3. Verify next class shown as 2:00 PM

### Class Transition
1. Mark attendance at 10:50 AM (near end of class)
2. Wait until 11:00 AM (class ends)
3. Verify cooldown card updates correctly
4. Verify next class calculations update

### Multiple Cancelled Records
1. Cancel attendance for Class A
2. Cancel attendance for Class B
3. Verify UI shows most recent cancelled state
4. Verify schedule info is for correct class

### App Lifecycle
1. Enter cooldown state
2. Put app in background for 5 minutes
3. Return to app
4. Verify times updated correctly
5. Verify no state loss

## Acceptance Criteria

✅ **All 7 test scenarios pass**
✅ **Visual verification checklist complete**
✅ **Console logs show expected messages**
✅ **No performance issues**
✅ **Edge cases handled correctly**

## Deployment Readiness

Before deploying to production:
1. [ ] All tests pass on debug build
2. [ ] All tests pass on release build
3. [ ] Test on multiple devices (different screen sizes)
4. [ ] Test during actual college hours (10:30 AM - 5:30 PM)
5. [ ] Verify backend two-stage cleanup is deployed
6. [ ] Document any edge cases discovered
7. [ ] Get user feedback from beta testers
