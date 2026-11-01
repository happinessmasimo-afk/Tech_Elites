using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

[ApiController]
[Route("api/offers")]
[Authorize]
public class OffersController : ControllerBase
{
    private readonly SupabaseRestService _rest;

    public OffersController(SupabaseRestService rest) => _rest = rest;

    /// <summary>Offers the logged-in farmer made as a buyer.</summary>
    [HttpGet("mine")]
    public async Task<ActionResult<List<OfferDto>>> GetMine()
    {
        var token = RequireToken();
        var (ok, error, data) = await _rest.GetMyOffersAsync(token);
        if (!ok) return StatusCode(502, new { error });
        return Ok(data);
    }

    /// <summary>Accept / decline (listing owner) or withdraw (buyer) — RLS
    /// decides which of those the caller is actually allowed to do.</summary>
    [HttpPatch("{id}")]
    public async Task<ActionResult<OfferDto>> UpdateStatus(string id, UpdateOfferStatusRequest req)
    {
        var allowed = new[] { "accepted", "declined", "withdrawn" };
        if (!allowed.Contains(req.Status))
            return BadRequest(new { error = $"Status must be one of: {string.Join(", ", allowed)}" });

        var token = RequireToken();
        var (ok, error, offer) = await _rest.UpdateOfferStatusAsync(token, id, req.Status);
        if (!ok) return BadRequest(new { error });
        if (offer is null) return NotFound();
        return Ok(offer);
    }

    private string RequireToken() =>
        HttpContext.Items["SupabaseAccessToken"] as string
        ?? throw new UnauthorizedAccessException("No Supabase access token on this request.");
}
