using System.Net.Http.Json;
using System.Text.Json;
using AgricastLivestock.Api.Models;
using Microsoft.Extensions.Options;

namespace AgricastLivestock.Api.Services;

/// <summary>Thin wrapper around Supabase's Auth (GoTrue) REST API: signup,
/// password login, refresh, logout, "who am I".</summary>
public class SupabaseAuthService
{
    private readonly HttpClient _http;
    private readonly SupabaseOptions _options;

    public SupabaseAuthService(IHttpClientFactory factory, IOptions<SupabaseOptions> options)
    {
        _options = options.Value;
        _http = factory.CreateClient();
        _http.DefaultRequestHeaders.Add("apikey", _options.AnonKey);
        // Supabase sits behind Cloudflare, which blocks requests with no
        // User-Agent header (returns a bare 403 before GoTrue even sees the
        // request). .NET's HttpClient sends none by default, so set one.
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("AgricastLivestockApi/1.0");
    }

    public async Task<(bool ok, string message, bool requiresConfirmation, SupabaseTokenLike? token)> SignUpAsync(
        string email, string password, string fullName, string phone)
    {
        var payload = new
        {
            email,
            password,
            data = new { full_name = fullName, phone }
        };

        var response = await _http.PostAsJsonAsync($"{_options.AuthUrl}/signup", payload);
        var body = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
            return (false, ExtractError(body), false, null);

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;

        // No "access_token" in the signup response means email confirmation
        // is required before the account can log in.
        var hasSession = root.TryGetProperty("access_token", out _);

        if (!hasSession)
            return (true, "Verification email sent. Confirm it, then log in.", true, null);

        var tokenLike = ParseToken(root);
        return (true, "Account created.", false, tokenLike);
    }

    public async Task<(bool ok, string message, SupabaseTokenLike? token)> SignInAsync(string email, string password)
    {
        var url = $"{_options.AuthUrl}/token?grant_type=password";
        var response = await _http.PostAsJsonAsync(url, new { email, password });
        var body = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
            return (false, ExtractError(body), null);

        using var doc = JsonDocument.Parse(body);
        return (true, "Logged in.", ParseToken(doc.RootElement));
    }

    public async Task<(bool ok, string message, SupabaseTokenLike? token)> RefreshAsync(string refreshToken)
    {
        var url = $"{_options.AuthUrl}/token?grant_type=refresh_token";
        var response = await _http.PostAsJsonAsync(url, new { refresh_token = refreshToken });
        var body = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
            return (false, ExtractError(body), null);

        using var doc = JsonDocument.Parse(body);
        return (true, "Session refreshed.", ParseToken(doc.RootElement));
    }

    public async Task<bool> SignOutAsync(string accessToken)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, $"{_options.AuthUrl}/logout?scope=local");
        request.Headers.Add("Authorization", $"Bearer {accessToken}");
        var response = await _http.SendAsync(request);
        // Supabase returns 204 on success; treat anything 2xx/404 as "logged out".
        return response.IsSuccessStatusCode || response.StatusCode == System.Net.HttpStatusCode.NotFound;
    }

    private static SupabaseTokenLike ParseToken(JsonElement root)
    {
        var accessToken = root.GetProperty("access_token").GetString() ?? "";
        var refreshToken = root.TryGetProperty("refresh_token", out var rt) ? rt.GetString() ?? "" : "";
        var user = root.GetProperty("user");
        var userId = user.GetProperty("id").GetString() ?? "";
        var email = user.TryGetProperty("email", out var e) ? e.GetString() : null;
        return new SupabaseTokenLike(accessToken, refreshToken, userId, email);
    }

    private static string ExtractError(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            foreach (var field in new[] { "error_description", "msg", "message", "error" })
            {
                if (root.TryGetProperty(field, out var val) && val.ValueKind == JsonValueKind.String)
                    return val.GetString() ?? "Request failed.";
            }
        }
        catch (JsonException) { /* fall through */ }
        return "Request failed.";
    }
}

public record SupabaseTokenLike(string AccessToken, string RefreshToken, string UserId, string? Email);
