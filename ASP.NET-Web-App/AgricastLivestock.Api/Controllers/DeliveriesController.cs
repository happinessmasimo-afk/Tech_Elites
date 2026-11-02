using System.Security.Claims;
using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

/// <summary>
/// Works like an e-hailing trip in both directions: for "pickup" the buyer
/// is the one travelling (to the farm); for "delivery" the farmer is the
/// one travelling (to the buyer). Whoever isn't travelling is a passive
/// viewer watching the other side's live position and ETA update.
/// </summary>
[ApiController]
[Route("api/deliveries")]
[Authorize]
public class DeliveriesController : ControllerBase
{
    private readonly SupabaseRestService _rest;
    private readonly MapboxDirectionsService _directions;

    public DeliveriesController(SupabaseRestService rest, MapboxDirectionsService directions)
    {
        _rest = rest;
        _directions = directions;
    }

    /// <summary>Buyer calls this right after paying, to say how they'll get
    /// the livestock — collect it themselves, or have the farmer deliver.
    /// For pickup, the buyer's own starting position isn't known yet (they
    /// haven't started travelling) — it fills in once they tap Start.</summary>
    [HttpPost]
    public async Task<ActionResult<DeliveryDto>> Create(CreateDeliveryRequest req)
    {
        var token = RequireToken();
        var userId = CurrentUserId();

        var (offerOk, offerError, offer) = await _rest.GetOfferAsync(token, req.OfferId);
        if (!offerOk) return StatusCode(502, new { error = offerError });
        if (offer is null) return NotFound(new { error = "Offer not found." });
        if (offer.BuyerId != userId) return Forbid();
        if (offer.PaymentStatus != "paid")
            return BadRequest(new { error = "Pay for this offer before arranging delivery." });

        var (listingOk, listingError, listing) = await _rest.GetListingAsync(token, offer.ListingId);
        if (!listingOk) return StatusCode(502, new { error = listingError });
        if (listing is null) return NotFound(new { error = "Listing not found." });

        if (req.Method == "delivery" && (req.BuyerLatitude is null || req.BuyerLongitude is null))
            return BadRequest(new { error = "Pin your delivery address on the map first." });

        double? distanceKm = null;
        int? etaMinutes = null;
        if (req.Method == "delivery" && listing.Latitude is not null && listing.Longitude is not null
            && req.BuyerLatitude is not null && req.BuyerLongitude is not null)
        {
            var (routeOk, km, minutes) = await _directions.GetRouteAsync(
                listing.Latitude.Value, listing.Longitude.Value, req.BuyerLatitude.Value, req.BuyerLongitude.Value);
            if (routeOk)
            {
                distanceKm = Math.Round(km, 1);
                etaMinutes = minutes;
            }
        }

        var payload = new
        {
            offer_id = req.OfferId,
            listing_id = offer.ListingId,
            farmer_id = listing.OwnerId,
            buyer_id = userId,
            method = req.Method,
            // Pickup: buyer's position is unknown until they start travelling —
            // left null here on purpose. Delivery: buyer's fixed address, pinned now.
            buyer_latitude = req.BuyerLatitude,
            buyer_longitude = req.BuyerLongitude,
            // The farm's fixed location either way — it's the pickup
            // destination for a pickup, or the delivery starting point.
            farmer_latitude = listing.Latitude,
            farmer_longitude = listing.Longitude,
            distance_km = distanceKm,
            eta_minutes = etaMinutes,
        };

        var (ok, error, delivery) = await _rest.CreateDeliveryAsync(token, payload);
        if (!ok) return BadRequest(new { error });
        return Ok(delivery);
    }

    [HttpGet("by-offer/{offerId}")]
    public async Task<ActionResult<DeliveryDto>> GetByOffer(string offerId)
    {
        var token = RequireToken();
        var (ok, error, delivery) = await _rest.GetDeliveryByOfferAsync(token, offerId);
        if (!ok) return StatusCode(502, new { error });
        if (delivery is null) return NotFound();
        return Ok(delivery);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<DeliveryDto>> GetById(string id)
    {
        var token = RequireToken();
        var (ok, error, delivery) = await _rest.GetDeliveryAsync(token, id);
        if (!ok) return StatusCode(502, new { error });
        if (delivery is null) return NotFound();
        return Ok(delivery);
    }

    /// <summary>The travelling party taps "Start" — this is the moment the
    /// other side effectively "gets notified": their tracking screen polls
    /// this same delivery and sees status flip to in_transit right away.
    /// Works for either direction: only the actual traveller for this
    /// delivery's method is allowed to start it.</summary>
    [HttpPost("{id}/start")]
    public async Task<ActionResult<DeliveryDto>> Start(string id)
    {
        var token = RequireToken();
        var userId = CurrentUserId();

        var (getOk, getError, delivery) = await _rest.GetDeliveryAsync(token, id);
        if (!getOk) return StatusCode(502, new { error = getError });
        if (delivery is null) return NotFound();

        var expectedTraveler = delivery.Method == "pickup" ? delivery.BuyerId : delivery.FarmerId;
        if (userId != expectedTraveler) return Forbid();

        var patch = new Dictionary<string, object?>
        {
            ["status"] = "in_transit",
            ["started_at"] = DateTimeOffset.UtcNow,
        };
        var (ok, error, updated) = await _rest.PatchDeliveryAsync(token, id, patch);
        if (!ok) return BadRequest(new { error });
        return Ok(updated);
    }

    /// <summary>The travelling party's app calls this repeatedly while en
    /// route — each call recomputes distance/ETA via Mapbox and is what
    /// the other side's tracking screen polls for. Direction-aware: for a
    /// pickup the buyer's position updates and the route runs toward the
    /// farm; for a delivery the farmer's position updates and the route
    /// runs toward the buyer.</summary>
    [HttpPatch("{id}/location")]
    public async Task<ActionResult<DeliveryDto>> UpdateLocation(string id, UpdateDeliveryLocationRequest req)
    {
        var token = RequireToken();
        var userId = CurrentUserId();

        var (getOk, getError, delivery) = await _rest.GetDeliveryAsync(token, id);
        if (!getOk) return StatusCode(502, new { error = getError });
        if (delivery is null) return NotFound();

        var isPickup = delivery.Method == "pickup";
        var expectedTraveler = isPickup ? delivery.BuyerId : delivery.FarmerId;
        if (userId != expectedTraveler) return Forbid();

        // The fixed point the traveller is heading toward: the farm for a
        // pickup, the buyer's pinned address for a delivery.
        double? destLat = isPickup ? delivery.FarmerLatitude : delivery.BuyerLatitude;
        double? destLng = isPickup ? delivery.FarmerLongitude : delivery.BuyerLongitude;

        double? distanceKm = delivery.DistanceKm;
        int? etaMinutes = delivery.EtaMinutes;
        if (destLat is not null && destLng is not null)
        {
            var (routeOk, km, minutes) = await _directions.GetRouteAsync(req.Latitude, req.Longitude, destLat.Value, destLng.Value);
            if (routeOk)
            {
                distanceKm = Math.Round(km, 1);
                etaMinutes = minutes;
            }
        }

        var patch = new Dictionary<string, object?>
        {
            [isPickup ? "buyer_latitude" : "farmer_latitude"] = req.Latitude,
            [isPickup ? "buyer_longitude" : "farmer_longitude"] = req.Longitude,
            ["distance_km"] = distanceKm,
            ["eta_minutes"] = etaMinutes,
        };
        if (delivery.Status == "pending") patch["status"] = "in_transit";

        var (ok, error, updated) = await _rest.PatchDeliveryAsync(token, id, patch);
        if (!ok) return BadRequest(new { error });
        return Ok(updated);
    }

    [HttpPatch("{id}/status")]
    public async Task<ActionResult<DeliveryDto>> UpdateStatus(string id, UpdateDeliveryStatusRequest req)
    {
        var allowed = new[] { "pending", "in_transit", "delivered" };
        if (!allowed.Contains(req.Status)) return BadRequest(new { error = $"Status must be one of: {string.Join(", ", allowed)}" });

        var token = RequireToken();
        var (ok, error, updated) = await _rest.PatchDeliveryAsync(token, id, new { status = req.Status });
        if (!ok) return BadRequest(new { error });
        return Ok(updated);
    }

    private string RequireToken() =>
        HttpContext.Items["SupabaseAccessToken"] as string
        ?? throw new UnauthorizedAccessException("No Supabase access token on this request.");

    private string CurrentUserId() =>
        User.FindFirst(ClaimTypes.NameIdentifier)?.Value
        ?? throw new UnauthorizedAccessException("No user id claim on this request.");
}
