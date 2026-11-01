namespace AgricastLivestock.Api.Models;

/// <summary>Bound from the "Supabase" section of appsettings / env vars.</summary>
public class SupabaseOptions
{
    public const string SectionName = "Supabase";

    public string Url { get; set; } = string.Empty;
    public string AnonKey { get; set; } = string.Empty;

    public string AuthUrl => $"{Url.TrimEnd('/')}/auth/v1";
    public string RestUrl => $"{Url.TrimEnd('/')}/rest/v1";
}

/// <summary>Bound from the "Mapbox" section of appsettings / env vars —
/// used server-side to compute real distance/ETA via the Directions API.
/// This is the same public (pk.) token the Flutter app ships with; Mapbox
/// public tokens are designed to be shared like this.</summary>
public class MapboxOptions
{
    public const string SectionName = "Mapbox";
    public string Token { get; set; } = string.Empty;
}
