import '../constants/app_constants.dart';

/// Utility class for college schedule calculations
/// Handles class timing, cooldown periods, and schedule-aware messaging
class ScheduleUtils {
  /// Get the end time of the current class (1 hour from start)
  static DateTime getClassEndTime(DateTime classStartTime) {
    return classStartTime.add(AppConstants.classDuration);
  }

  /// Get the cooldown end time (15 minutes after confirmation)
  static DateTime getCooldownEndTime(DateTime confirmationTime) {
    return confirmationTime.add(AppConstants.cooldownDuration);
  }

  /// Check if current time is during break (1:30 PM - 2:00 PM)
  static bool isDuringBreak(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    // After 1:30 PM and before 2:00 PM
    if (hour == AppConstants.breakStartHour &&
        minute >= AppConstants.breakStartMinute) {
      return true;
    }
    if (hour == AppConstants.breakEndHour &&
        minute < AppConstants.breakEndMinute) {
      return true;
    }

    return false;
  }

  /// Check if current time is within college hours (10:30 AM - 5:30 PM)
  static bool isDuringCollegeHours(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    // Before college starts
    if (hour < AppConstants.collegeStartHour) return false;
    if (hour == AppConstants.collegeStartHour &&
        minute < AppConstants.collegeStartMinute) return false;

    // After college ends
    if (hour > AppConstants.collegeEndHour) return false;
    if (hour == AppConstants.collegeEndHour &&
        minute >= AppConstants.collegeEndMinute) return false;

    return true;
  }

  /// Get the next class start time after the current cooldown/cancelled state
  /// This helps show "Next class at 11:00 AM" type messages
  static DateTime getNextClassStartTime(DateTime currentTime) {
    // If during break, next class is at 2:00 PM
    if (isDuringBreak(currentTime)) {
      return DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
        AppConstants.breakEndHour,
        AppConstants.breakEndMinute,
      );
    }

    // Otherwise, next class is 1 hour after current time
    // (Assuming each class is 1 hour)
    final nextClassTime = currentTime.add(AppConstants.classDuration);

    // If next class would be during break, skip to 2:00 PM
    if (isDuringBreak(nextClassTime)) {
      return DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
        AppConstants.breakEndHour,
        AppConstants.breakEndMinute,
      );
    }

    // If next class would be after college hours, return tomorrow's first class
    if (!isDuringCollegeHours(nextClassTime)) {
      final tomorrow = currentTime.add(const Duration(days: 1));
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        AppConstants.collegeStartHour,
        AppConstants.collegeStartMinute,
      );
    }

    return nextClassTime;
  }

  /// Format time in 12-hour format (e.g., "11:00 AM")
  static String formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Format time remaining in human-readable format
  /// Examples: "in 45 minutes", "in 1 hour 15 minutes"
  static String formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return "now";

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      if (minutes > 0) {
        return "in $hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}";
      } else {
        return "in $hours hour${hours > 1 ? 's' : ''}";
      }
    } else {
      return "in $minutes minute${minutes > 1 ? 's' : ''}";
    }
  }

  /// Get cooldown message with class schedule context
  /// Returns a user-friendly message like:
  /// "Class ends at 11:00 AM. Next check-in available in 12 minutes."
  static String getCooldownMessage(DateTime classStartTime, DateTime now) {
    final classEndTime = getClassEndTime(classStartTime);
    final cooldownEndTime = getCooldownEndTime(classStartTime);
    final remainingTime = cooldownEndTime.difference(now);

    if (remainingTime.isNegative) {
      return "Cooldown expired. You can check in now.";
    }

    // If class hasn't ended yet, show class end time
    if (now.isBefore(classEndTime)) {
      final classTimeLeft = classEndTime.difference(now);
      return "Class ends at ${formatTime(classEndTime)} (${formatTimeRemaining(classTimeLeft)}).\nNext check-in available after cooldown.";
    }

    // If class ended but still in cooldown
    return "Next check-in available ${formatTimeRemaining(remainingTime)}.";
  }

  /// Get cancelled state message with next class context
  /// Returns a user-friendly message like:
  /// "Try again in next class at 11:00 AM"
  static String getCancelledMessage(DateTime cancelledTime, DateTime now) {
    final classEndTime = getClassEndTime(cancelledTime);
    final nextClassTime = getNextClassStartTime(classEndTime);

    // If current class hasn't ended yet
    if (now.isBefore(classEndTime)) {
      final timeLeft = classEndTime.difference(now);
      return "Attendance cancelled.\nCurrent class ends at ${formatTime(classEndTime)} (${formatTimeRemaining(timeLeft)}).\nTry again in next class at ${formatTime(nextClassTime)}.";
    }

    // If current class ended, show next class time
    final timeUntilNext = nextClassTime.difference(now);
    return "Attendance cancelled.\nNext class starts at ${formatTime(nextClassTime)} (${formatTimeRemaining(timeUntilNext)}).";
  }

  /// Get schedule-aware cooldown info for UI display
  /// Returns a map with all the information needed for the UI
  static Map<String, dynamic> getScheduleAwareCooldownInfo({
    required DateTime classStartTime,
    required DateTime now,
  }) {
    final classEndTime = getClassEndTime(classStartTime);
    final cooldownEndTime = getCooldownEndTime(classStartTime);
    final remainingTime = cooldownEndTime.difference(now);
    final classTimeLeft = classEndTime.difference(now);

    return {
      'inCooldown': remainingTime.inSeconds > 0,
      'classEndTime': classEndTime,
      'classEndTimeFormatted': formatTime(classEndTime),
      'cooldownEndTime': cooldownEndTime,
      'cooldownEndTimeFormatted': formatTime(cooldownEndTime),
      'remainingMinutes': remainingTime.inMinutes,
      'remainingSeconds': remainingTime.inSeconds,
      'remainingTimeFormatted': formatTimeRemaining(remainingTime),
      'classEnded': now.isAfter(classEndTime),
      'classTimeLeftMinutes': classTimeLeft.inMinutes.clamp(0, 60),
      'classTimeLeftFormatted': classTimeLeft.isNegative
          ? "ended"
          : formatTimeRemaining(classTimeLeft),
      'message': getCooldownMessage(classStartTime, now),
    };
  }

  /// Get schedule-aware cancelled info for UI display
  static Map<String, dynamic> getScheduleAwareCancelledInfo({
    required DateTime cancelledTime,
    required DateTime now,
  }) {
    final classEndTime = getClassEndTime(cancelledTime);
    final nextClassTime = getNextClassStartTime(classEndTime);
    final classTimeLeft = classEndTime.difference(now);
    final timeUntilNext = nextClassTime.difference(now);

    return {
      'cancelled': true,
      'classEndTime': classEndTime,
      'classEndTimeFormatted': formatTime(classEndTime),
      'nextClassTime': nextClassTime,
      'nextClassTimeFormatted': formatTime(nextClassTime),
      'classEnded': now.isAfter(classEndTime),
      'classTimeLeftMinutes': classTimeLeft.inMinutes.clamp(0, 60),
      'classTimeLeftFormatted': classTimeLeft.isNegative
          ? "ended"
          : formatTimeRemaining(classTimeLeft),
      'timeUntilNextMinutes': timeUntilNext.inMinutes,
      'timeUntilNextFormatted': formatTimeRemaining(timeUntilNext),
      'message': getCancelledMessage(cancelledTime, now),
    };
  }
}
