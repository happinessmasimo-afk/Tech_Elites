using System.Security.Claims;
using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

[ApiController]
[Route("api/listings")]
public class ListingsController : ControllerBase
{
    private readonly SupabaseRestService _rest;

    public ListingsController(SupabaseRestService rest) => _rest = rest;

    /// <summary>Public marketplace browse — works for guests too (no auth
    /// header required), and for logged-in farmers.</summary>
    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<ListingDto>>> GetActive()
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string;
        var (ok, error, data) = await _rest.GetActiveListingsAsync(token);
        if (!ok) return StatusCode(502, new { error = $"Could not load listings from Supabase: {error}" });
        return Ok(data);
    }

    [HttpGet("mine")]
    [Authorize]
    public async Task<ActionResult<List<ListingDto>>> GetMine()
    {
        var token = RequireToken();
        var (ok, error, data) = await _rest.GetMyListingsAsync(token);
        if (!ok) return StatusCode(502, new { error = $"Could not load your listings from Supabase: {error}" });
        return Ok(data);
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<ActionResult<ListingDto>> GetById(string id)
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string;
        var (ok, error, listing) = await _rest.GetListingAsync(token ?? "", id);
        if (!ok) return StatusCode(502, new { error });
        if (listing is null) return NotFound();
        return Ok(listing);
    }

    [HttpPost]
    [Authorize]
    public async Task<ActionResult<ListingDto>> Create(CreateListingRequest req)
    {
        var token = RequireToken();
        var ownerId = CurrentUserId();
        var (ok, error, listing) = await _rest.CreateListingAsync(token, ownerId, req);
        if (!ok) return BadRequest(new { error });
        return CreatedAtAction(nameof(GetById), new { id = listing!.Id }, listing);
    }

    [HttpPut("{id}")]
    [Authorize]
    public async Task<ActionResult<ListingDto>> Update(string id, UpdateListingRequest req)
    {
        var token = RequireToken();
        // RLS (listings_update_own) already guarantees a farmer can only
        // patch their own row, so there's no ownership check needed here.
        var (ok, error, listing) = await _rest.UpdateListingAsync(token, id, req);
        if (!ok) return BadRequest(new { error });
        if (listing is null) return NotFound();
        return Ok(listing);
    }

    [HttpDelete("{id}")]
    [Authorize]
    public async Task<IActionResult> Delete(string id)
    {
        var token = RequireToken();
        var (ok, error) = await _rest.DeleteListingAsync(token, id);
        return ok ? NoContent() : BadRequest(new { error });
    }

    // ---- offers nested under a listing -------------------------------

    [HttpGet("{id}/offers")]
    [Authorize]
    public async Task<ActionResult<List<OfferDto>>> GetOffersForListing(string id)
    {
        var token = RequireToken();
        var (ok, error, data) = await _rest.GetOffersForListingAsync(token, id);
        if (!ok) return StatusCode(502, new { error });
        return Ok(data);
    }

    [HttpPost("{id}/offers")]
    [Authorize]
    public async Task<ActionResult<OfferDto>> MakeOffer(string id, CreateOfferRequest req)
    {
        var token = RequireToken();
        var buyerId = CurrentUserId();
        var (ok, error, offer) = await _rest.CreateOfferAsync(token, id, buyerId, req);
        if (!ok) return BadRequest(new { error });
        return Ok(offer);
    }

    /// <summary>Buy Now — skips negotiation, buys at the listed asking
    /// price immediately. "Make an offer" (above) stays available
    /// alongside this for anyone who wants to negotiate instead.</summary>
    [HttpPost("{id}/buy-now")]
    [Authorize]
    public async Task<ActionResult<OfferDto>> BuyNow(string id, BuyNowRequest req)
    {
        var token = RequireToken();
        var buyerId = CurrentUserId();

        var (listingOk, listingError, listing) = await _rest.GetListingAsync(token, id);
        if (!listingOk) return StatusCode(502, new { error = listingError });
        if (listing is null) return NotFound(new { error = "Listing not found." });
        if (listing.Status != "active") return BadRequest(new { error = "This listing is no longer available." });

        var (ok, error, offer) = await _rest.CreateAcceptedOfferAsync(token, id, buyerId, req.BuyerName, req.BuyerPhone, listing.AskingPrice);
        if (!ok) return BadRequest(new { error });
        return Ok(offer);
    }

    private string RequireToken() =>
        HttpContext.Items["SupabaseAccessToken"] as string
        ?? throw new UnauthorizedAccessException("No Supabase access token on this request.");

    private string CurrentUserId() =>
        User.FindFirst(ClaimTypes.NameIdentifier)?.Value
        ?? throw new UnauthorizedAccessException("No user id claim on this request.");
}
