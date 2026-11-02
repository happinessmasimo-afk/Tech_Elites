using System.Text.Json.Serialization;

namespace AgricastLivestock.Api.Models;

public record RegisterRequest(string FullName, string Email, string Phone, string Password);

public record LoginRequest(string Email, string Password);

public record RefreshRequest(string RefreshToken);

public record UpdateProfileRequest(string? FullName, string? Phone, string? Location);

/// <summary>What our API returns after register/login/refresh — the Flutter
/// app stores AccessToken + RefreshToken and sends AccessToken as a Bearer
/// token on every subsequent call.</summary>
public class AuthResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
    public bool RequiresEmailConfirmation { get; set; }
    public FarmerProfile? Profile { get; set; }
}

public class FarmerProfile
{
    public string Id { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? FullName { get; set; }
    public string? Phone { get; set; }
    public string? Location { get; set; }
    /// <summary>"farmer" (the one account that can publish listings) or
    /// "buyer" (everyone else — the default for all new signups).</summary>
    public string Role { get; set; } = "buyer";
}

// -- Shapes returned by Supabase's GoTrue (auth) REST API --------------------

internal class SupabaseTokenResponse
{
    [JsonPropertyName("access_token")] public string? AccessToken { get; set; }
    [JsonPropertyName("refresh_token")] public string? RefreshToken { get; set; }
    [JsonPropertyName("user")] public SupabaseUser? User { get; set; }
}

internal class SupabaseUser
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("email")] public string? Email { get; set; }
}

internal class SupabaseErrorResponse
{
    [JsonPropertyName("error_description")] public string? ErrorDescription { get; set; }
    [JsonPropertyName("msg")] public string? Msg { get; set; }
    [JsonPropertyName("message")] public string? Message { get; set; }
}
