/// Base URL of the ASP.NET API (backend-aspnet/). Point this at wherever
/// you run/deploy that project.
///
/// - Android emulator talking to a backend running on your own machine:
///   use 10.0.2.2 instead of localhost.
/// - iOS simulator: localhost works fine.
/// - Real device / production: use your deployed API's https URL.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}

/// Mapbox public (pk_) token — safe to embed client-side, same as a
/// Supabase anon key; scope/restrict it to your app in the Mapbox
/// dashboard if you want to tighten this further. Used to fetch map tiles
/// for the location picker and listing detail map.
class MapConfig {
  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  static String tileUrl(String styleId) => '';
}
