class AppSettings {
  bool darkMode;
  bool backgroundTracking;
  bool notificationEnabled;
  bool systemTheme;
  bool soundEnabled;
  bool vibrationEnabled;
  // Feature flags
  bool
      newAttendancePipelineEnabled; // Toggles two-stage attendance & correlation extras

  AppSettings({
    this.darkMode = false,
    this.backgroundTracking = false,
    this.notificationEnabled = true,
    this.systemTheme = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.newAttendancePipelineEnabled = true, // default ON for current build
  });
}
