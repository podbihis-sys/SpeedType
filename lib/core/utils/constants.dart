library constants;

class Constants {
  Constants._();

  // App
  static const String appName = 'SpeedType';
  static const String appVersion = '1.0.0';

  // AdMob IDs - Replace with your actual IDs
  static const String admobAndroidAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  static const String admobIosAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';

  // Ad Unit IDs - Android
  static const String androidBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String androidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String androidRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // Ad Unit IDs - iOS
  static const String iosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // Test durations
  static const List<int> testDurations = [15, 30, 60, 120];

  // SharedPreferences keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserId = 'user_id';
  static const String keyLanguage = 'language';
}
