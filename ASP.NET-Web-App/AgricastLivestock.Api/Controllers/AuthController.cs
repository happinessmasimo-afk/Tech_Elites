using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly SupabaseAuthService _auth;
    private readonly SupabaseRestService _rest;

    public AuthController(SupabaseAuthService auth, SupabaseRestService rest)
    {
        _auth = auth;
        _rest = rest;
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req)
    {
        var (ok, message, requiresConfirmation, token) =
            await _auth.SignUpAsync(req.Email, req.Password, req.FullName, req.Phone);

        if (!ok) return BadRequest(new AuthResponse { Success = false, Message = message });

        return Ok(new AuthResponse
        {
            Success = true,
            Message = message,
            RequiresEmailConfirmation = requiresConfirmation,
            AccessToken = token?.AccessToken,
            RefreshToken = token?.RefreshToken,
            Profile = token is null ? null : new FarmerProfile { Id = token.UserId, Email = token.Email, FullName = req.FullName, Phone = req.Phone, Role = "buyer" }
        });
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest req)
    {
        var (ok, message, token) = await _auth.SignInAsync(req.Email, req.Password);
        if (!ok || token is null) return Unauthorized(new AuthResponse { Success = false, Message = message });

        var profile = await LoadProfileAsync(token.AccessToken, token.UserId, token.Email);

        return Ok(new AuthResponse
        {
            Success = true,
            Message = message,
            AccessToken = token.AccessToken,
            RefreshToken = token.RefreshToken,
            Profile = profile
        });
    }

    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest req)
    {
        var (ok, message, token) = await _auth.RefreshAsync(req.RefreshToken);
        if (!ok || token is null) return Unauthorized(new AuthResponse { Success = false, Message = message });

        return Ok(new AuthResponse
        {
            Success = true,
            Message = message,
            AccessToken = token.AccessToken,
            RefreshToken = token.RefreshToken
        });
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout()
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string;
        if (!string.IsNullOrEmpty(token)) await _auth.SignOutAsync(token);
        return Ok(new { success = true, message = "Logged out." });
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<FarmerProfile>> Me()
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string;
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value;
        if (token is null || userId is null) return Unauthorized();

        var profile = await LoadProfileAsync(token, userId, email);
        return Ok(profile);
    }

    [HttpPut("me")]
    [Authorize]
    public async Task<ActionResult<FarmerProfile>> UpdateMe(UpdateProfileRequest req)
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string;
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value;
        if (token is null || userId is null) return Unauthorized();

        var (ok, error) = await _rest.UpdateProfileAsync(token, userId, req);
        if (!ok) return BadRequest(new { error });

        var profile = await LoadProfileAsync(token, userId, email);
        return Ok(profile);
    }

    private async Task<FarmerProfile> LoadProfileAsync(string accessToken, string userId, string? email)
    {
        // profiles.id/email/full_name/phone are populated by the
        // handle_new_user() trigger (see 001_init.sql) right after signup,
        // so this row should already exist by the time login succeeds.
        var profile = await _rest.GetProfileAsync(accessToken, userId);
        return profile ?? new FarmerProfile { Id = userId, Email = email };
    }
}
