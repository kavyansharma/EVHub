class AppConstants {
  // Storage Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyFirstLaunch = 'is_first_launch';
  static const String keyRememberMe = 'remember_me';
  static const String keyRememberedEmail = 'remembered_email';

  // App Metadata
  static const String appName = 'EVHub';
  static const String appVersion = '1.0.0';

  // Visual Assets
  static const String splashLogoText = 'EVHUB';

  // Firestore Collection Names
  static const String colUsers = 'users';
  static const String colWallets = 'wallets';
  static const String colTransactions = 'transactions';
  static const String colFavorites = 'favorites';
  static const String colChargingHistory = 'charging_history';
  static const String colTripHistory = 'trip_history';
  static const String colStations = 'stations';
  
  // Google Maps API Key
  static const String googleMapsApiKey = 'AIzaSyBkRQGLVDyA-tvIbGdK63H49GiF2yS12tw';

  // NREL Alternative Fuel Stations API Configuration
  static const String nrelApiBaseUrl = 'https://developer.nrel.gov/api/alt-fuel-stations/v1.json';
  static const String nrelApiKey = 'DEMO_KEY';

  // Open Charge Map API Configuration (India Bulk Importer)
  static const String openChargeMapApiBaseUrl = 'https://api.openchargemap.io/v3/poi/';
  static const String openChargeMapApiKey = ''; // Inject via UI or environment variable
}
