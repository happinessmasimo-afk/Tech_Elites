using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AgricastLivestock.Api.Controllers;

[ApiController]
[Route("api/finance")]
[Authorize]
public class FinanceController : ControllerBase
{
    private readonly SupabaseRestService _rest;

    public FinanceController(SupabaseRestService rest) => _rest = rest;

    /// <summary>Total revenue and per-listing breakdown for everything the
    /// logged-in farmer has marked as sold. RLS (listings_select_own)
    /// already limits this to their own listings, so no extra filtering
    /// is needed here.</summary>
    [HttpGet("summary")]
    public async Task<ActionResult<FinanceSummaryDto>> GetSummary()
    {
        var token = HttpContext.Items["SupabaseAccessToken"] as string
            ?? throw new UnauthorizedAccessException("No Supabase access token on this request.");

        var (ok, error, sold) = await _rest.GetSoldListingsAsync(token);
        if (!ok) return StatusCode(502, new { error });

        var totalRevenue = sold.Sum(l => l.SoldPrice ?? l.AskingPrice);

        return Ok(new FinanceSummaryDto
        {
            TotalRevenue = totalRevenue,
            SoldCount = sold.Count,
            SoldListings = sold
        });
    }
}
