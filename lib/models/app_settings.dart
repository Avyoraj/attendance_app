class AppSettings {
  bool darkMode;
  bool backgroundTracking;
  bool notificationEnabled;
  bool systemTheme;
  bool soundEnabled;
  bool vibrationEnabled;

  AppSettings({
    this.darkMode = false,
    this.backgroundTracking = false,
    this.notificationEnabled = true,
    this.systemTheme = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });
}
