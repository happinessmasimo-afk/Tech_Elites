using System.Security.Claims;
using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

/// <summary>
/// A deliberately fake payment: no external gateway, no real card data
/// (the app only ever sends the last 4 digits, for display purposes).
/// What IS real: marking the offer paid here fires a database trigger
/// (see supabase/migrations/008_auto_sold_on_payment.sql) that
/// automatically marks the listing sold and records the sale price, which
/// is exactly what makes it show up as sold on the farmer's side and in
/// their Finance total without any extra code here.
/// </summary>
[ApiController]
[Route("api/payments")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly SupabaseRestService _rest;

    public PaymentsController(SupabaseRestService rest) => _rest = rest;

    [HttpPost("dummy-pay")]
    public async Task<ActionResult<DummyPayResponse>> DummyPay(DummyPayRequest req)
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string
            ?? throw new UnauthorizedAccessException("No Supabase access token on this request.");
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? throw new UnauthorizedAccessException("No user id claim on this request.");

        if (string.IsNullOrWhiteSpace(req.CardHolderName))
            return BadRequest(new DummyPayResponse { Success = false, Message = "Enter a cardholder name." });

        var (ok, error, offer) = await _rest.GetOfferAsync(token, req.OfferId);
        if (!ok) return StatusCode(502, new DummyPayResponse { Success = false, Message = error });
        if (offer is null) return NotFound(new DummyPayResponse { Success = false, Message = "Offer not found." });
        if (offer.BuyerId != userId) return Forbid();
        if (offer.Status != "accepted")
            return BadRequest(new DummyPayResponse { Success = false, Message = "This offer hasn't been accepted yet." });
        if (offer.PaymentStatus == "paid")
            return BadRequest(new DummyPayResponse { Success = false, Message = "This offer has already been paid." });

        // Simulate the couple of seconds a real gateway would take, so the
        // app's "Processing payment..." step isn't instant and jarring.
        await Task.Delay(1200);

        var (markOk, markError, updated) = await _rest.MarkOfferPaidAsync(token, req.OfferId);
        if (!markOk) return BadRequest(new DummyPayResponse { Success = false, Message = markError });

        return Ok(new DummyPayResponse { Success = true, Message = "Payment successful.", Offer = updated });
    }
}
