using System.Security.Claims;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

[ApiController]
[Route("api/uploads")]
[Authorize]
public class UploadsController : ControllerBase
{
    private const long MaxFileBytes = 8 * 1024 * 1024; // 8MB per photo

    private readonly SupabaseStorageService _storage;

    public UploadsController(SupabaseStorageService storage) => _storage = storage;

    /// <summary>
    /// Upload one listing photo. The Flutter app calls this once per photo
    /// the farmer picks (they can pick as many as they like beforehand);
    /// each call returns a public URL to add to the listing's photo_urls.
    /// </summary>
    [HttpPost("listing-photo")]
    [RequestSizeLimit(MaxFileBytes)]
    public async Task<IActionResult> UploadListingPhoto(IFormFile file)
    {
        if (file is null || file.Length == 0) return BadRequest(new { error = "No file received." });
        if (file.Length > MaxFileBytes) return BadRequest(new { error = "Photo is too large (max 8MB)." });

        var token = HttpContext.Items["SupabaseAccessToken"] as string
            ?? throw new UnauthorizedAccessException("No Supabase access token on this request.");
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? throw new UnauthorizedAccessException("No user id claim on this request.");

        await using var stream = file.OpenReadStream();
        var (ok, error, url) = await _storage.UploadListingPhotoAsync(token, userId, stream, file.ContentType, file.FileName);

        if (!ok) return BadRequest(new { error });
        return Ok(new { url });
    }
}
