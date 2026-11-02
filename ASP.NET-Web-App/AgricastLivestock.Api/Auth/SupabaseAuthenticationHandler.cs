using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using AgricastLivestock.Api.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace AgricastLivestock.Api.Auth;

public class SupabaseAuthSchemeOptions : AuthenticationSchemeOptions { }

/// <summary>
/// Validates the caller's Supabase access token by asking Supabase's Auth
/// server (GoTrue) who it belongs to (GET /auth/v1/user). This avoids having
/// to know or configure the project's JWT signing algorithm/secret in this
/// API at all — Supabase remains the single source of truth for "is this
/// token valid", and the same call also catches revoked/expired tokens.
///
/// The raw token is also stashed on HttpContext.Items["SupabaseAccessToken"]
/// so controllers can forward it, unchanged, to PostgREST — that's what
/// makes row-level security in the database apply per-user.
/// </summary>
public class SupabaseAuthenticationHandler : AuthenticationHandler<SupabaseAuthSchemeOptions>
{
    public const string SchemeName = "SupabaseToken";

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly SupabaseOptions _supabase;

    public SupabaseAuthenticationHandler(
        IOptionsMonitor<SupabaseAuthSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        IHttpClientFactory httpClientFactory,
        IOptions<SupabaseOptions> supabase)
        : base(options, logger, encoder)
    {
        _httpClientFactory = httpClientFactory;
        _supabase = supabase.Value;
    }

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("Authorization", out var authHeader))
            return AuthenticateResult.NoResult();

        var header = authHeader.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return AuthenticateResult.Fail("Missing Bearer token.");

        var token = header["Bearer ".Length..].Trim();
        if (string.IsNullOrWhiteSpace(token))
            return AuthenticateResult.Fail("Empty bearer token.");

        var client = _httpClientFactory.CreateClient();
        var request = new HttpRequestMessage(HttpMethod.Get, $"{_supabase.AuthUrl}/user");
        request.Headers.Add("apikey", _supabase.AnonKey);
        request.Headers.Add("Authorization", $"Bearer {token}");
        request.Headers.UserAgent.ParseAdd("AgricastLivestockApi/1.0");

        HttpResponseMessage response;
        try
        {
            response = await client.SendAsync(request);
        }
        catch (Exception ex)
        {
            return AuthenticateResult.Fail($"Could not reach Supabase Auth: {ex.Message}");
        }

        if (!response.IsSuccessStatusCode)
            return AuthenticateResult.Fail("Invalid or expired session.");

        var body = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;

        var userId = root.TryGetProperty("id", out var idProp) ? idProp.GetString() : null;
        var email = root.TryGetProperty("email", out var emailProp) ? emailProp.GetString() : null;

        if (string.IsNullOrEmpty(userId))
            return AuthenticateResult.Fail("Supabase user response had no id.");

        // Stash the raw token so controllers can forward it to PostgREST.
        Context.Items["SupabaseAccessToken"] = token;

        var claims = new List<Claim> { new(ClaimTypes.NameIdentifier, userId) };
        if (!string.IsNullOrEmpty(email)) claims.Add(new Claim(ClaimTypes.Email, email));

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return AuthenticateResult.Success(ticket);
    }
}
