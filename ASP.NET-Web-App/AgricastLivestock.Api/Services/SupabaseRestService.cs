using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AgricastLivestock.Api.Models;
using Microsoft.Extensions.Options;

namespace AgricastLivestock.Api.Services;

/// <summary>
/// Thin wrapper around Supabase's auto-generated REST API (PostgREST) for the
/// two tables this app needs: listings and listing_offers. Every call is
/// made with the *caller's own* access token (or the anon key for guest
/// browsing) so Postgres row-level security — not this API — is what decides
/// what's visible/writable. This service does not use the service-role key.
///
/// Every read method returns (ok, error, data) rather than just the data —
/// on failure the error string carries Supabase/Postgres's actual message
/// (e.g. "permission denied for table listings") up to the controller and
/// then to the app, instead of silently coming back as an empty list. An
/// empty list should only ever mean "genuinely no rows", never "something
/// went wrong".
/// </summary>
public class SupabaseRestService
{
    private readonly IHttpClientFactory _factory;
    private readonly SupabaseOptions _options;
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    public SupabaseRestService(IHttpClientFactory factory, IOptions<SupabaseOptions> options)
    {
        _factory = factory;
        _options = options.Value;
    }

    private HttpClient Client(string? bearerToken)
    {
        var client = _factory.CreateClient();
        client.BaseAddress = new Uri(_options.RestUrl + "/");
        client.DefaultRequestHeaders.Add("apikey", _options.AnonKey);
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", string.IsNullOrEmpty(bearerToken) ? _options.AnonKey : bearerToken);
        // Same Cloudflare-in-front-of-Supabase reasoning as SupabaseAuthService.
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AgricastLivestockApi/1.0");
        return client;
    }

    // ---- Profile ----------------------------------------------------------

    public async Task<FarmerProfile?> GetProfileAsync(string bearerToken, string userId)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync($"profiles?id=eq.{userId}&limit=1");
        var (ok, _, list) = await ReadListAsync<ProfileRow>(res);
        var row = ok ? list.FirstOrDefault() : null;
        if (row is null) return null;
        return new FarmerProfile { Id = row.Id, Email = row.Email, FullName = row.FullName, Phone = row.Phone, Location = row.Location, Role = row.Role };
    }

    public async Task<(bool ok, string error)> UpdateProfileAsync(string bearerToken, string userId, UpdateProfileRequest req)
    {
        var patch = new Dictionary<string, object?>();
        if (req.FullName is not null) patch["full_name"] = req.FullName;
        if (req.Phone is not null) patch["phone"] = req.Phone;
        if (req.Location is not null) patch["location"] = req.Location;
        if (patch.Count == 0) return (true, "");

        var client = Client(bearerToken);
        var request = new HttpRequestMessage(HttpMethod.Patch, $"profiles?id=eq.{userId}")
        {
            Content = JsonContent.Create(patch, options: JsonOpts)
        };
        var res = await client.SendAsync(request);
        return res.IsSuccessStatusCode ? (true, "") : (false, await res.Content.ReadAsStringAsync());
    }

    private class ProfileRow
    {
        public string Id { get; set; } = string.Empty;
        public string? Email { get; set; }
        [System.Text.Json.Serialization.JsonPropertyName("full_name")] public string? FullName { get; set; }
        public string? Phone { get; set; }
        public string? Location { get; set; }
        public string Role { get; set; } = "buyer";
    }

    // ---- Listings -----------------------------------------------------

    public async Task<(bool ok, string error, List<ListingDto> data)> GetActiveListingsAsync(string? bearerToken)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync("listings?status=eq.active&order=created_at.desc");
        return await ReadListAsync<ListingDto>(res);
    }

    public async Task<(bool ok, string error, List<ListingDto> data)> GetMyListingsAsync(string bearerToken)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync("listings?order=created_at.desc");
        return await ReadListAsync<ListingDto>(res);
    }

    public async Task<(bool ok, string error, List<ListingDto> data)> GetSoldListingsAsync(string bearerToken)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync("listings?status=eq.sold&order=sold_at.desc,created_at.desc");
        return await ReadListAsync<ListingDto>(res);
    }

    public async Task<(bool ok, string error, ListingDto? listing)> GetListingAsync(string bearerToken, string id)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync($"listings?id=eq.{id}&limit=1");
        var (ok, error, list) = await ReadListAsync<ListingDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, ListingDto? listing)> CreateListingAsync(
        string bearerToken, string ownerId, CreateListingRequest req)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");

        var payload = new
        {
            owner_id = ownerId,
            title = req.Title,
            species = req.Species,
            breed = req.Breed,
            sex = req.Sex,
            quantity = req.Quantity,
            age_months = req.AgeMonths,
            asking_price = req.AskingPrice,
            price_unit = req.PriceUnit,
            description = req.Description,
            location = req.Location,
            photo_urls = req.PhotoUrls ?? new List<string>(),
            latitude = req.Latitude,
            longitude = req.Longitude
        };

        var res = await client.PostAsJsonAsync("listings", payload, JsonOpts);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);

        var (ok, error, list) = await ReadListAsync<ListingDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, ListingDto? listing)> UpdateListingAsync(
        string bearerToken, string id, UpdateListingRequest req)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");

        // Only send fields that were actually provided, so a partial edit
        // (e.g. just marking something "sold") doesn't null out the rest.
        var patch = new Dictionary<string, object?>();
        if (req.Title is not null) patch["title"] = req.Title;
        if (req.Breed is not null) patch["breed"] = req.Breed;
        if (req.Quantity is not null) patch["quantity"] = req.Quantity;
        if (req.AskingPrice is not null) patch["asking_price"] = req.AskingPrice;
        if (req.PriceUnit is not null) patch["price_unit"] = req.PriceUnit;
        if (req.Status is not null) patch["status"] = req.Status;
        if (req.Description is not null) patch["description"] = req.Description;
        if (req.Location is not null) patch["location"] = req.Location;
        if (req.PhotoUrls is not null) patch["photo_urls"] = req.PhotoUrls;

        // Marking a listing sold: record what it actually sold for (falls
        // back to the asking price if not given) and stamp the time
        // server-side — the client never sets sold_at directly.
        if (req.Status == "sold")
        {
            var soldPrice = req.SoldPrice ?? req.AskingPrice;
            if (soldPrice is not null) patch["sold_price"] = soldPrice;
            patch["sold_at"] = DateTimeOffset.UtcNow;
        }
        else if (req.SoldPrice is not null)
        {
            patch["sold_price"] = req.SoldPrice;
        }

        var request = new HttpRequestMessage(HttpMethod.Patch, $"listings?id=eq.{id}")
        {
            Content = JsonContent.Create(patch, options: JsonOpts)
        };
        var res = await client.SendAsync(request);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);

        var (ok, error, list) = await ReadListAsync<ListingDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error)> DeleteListingAsync(string bearerToken, string id)
    {
        var client = Client(bearerToken);
        var res = await client.DeleteAsync($"listings?id=eq.{id}");
        return res.IsSuccessStatusCode ? (true, "") : (false, await res.Content.ReadAsStringAsync());
    }

    // ---- Offers ---------------------------------------------------------

    public async Task<(bool ok, string error, List<OfferDto> data)> GetOffersForListingAsync(string bearerToken, string listingId)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync($"listing_offers?listing_id=eq.{listingId}&select=*,listings(title,asking_price)&order=created_at.desc");
        return await ReadListAsync<OfferDto>(res);
    }

    public async Task<(bool ok, string error, List<OfferDto> data)> GetMyOffersAsync(string bearerToken)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync("listing_offers?select=*,listings(title,asking_price)&order=created_at.desc");
        return await ReadListAsync<OfferDto>(res);
    }

    public async Task<(bool ok, string error, OfferDto? offer)> CreateOfferAsync(
        string bearerToken, string listingId, string buyerId, CreateOfferRequest req)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");

        var payload = new
        {
            listing_id = listingId,
            buyer_id = buyerId,
            buyer_name = req.BuyerName,
            buyer_phone = req.BuyerPhone,
            offer_price = req.OfferPrice,
            message = req.Message
        };

        var res = await client.PostAsJsonAsync("listing_offers?select=*,listings(title,asking_price)", payload, JsonOpts);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);

        var (ok, error, list) = await ReadListAsync<OfferDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    /// <summary>"Buy Now" — skips negotiation entirely by inserting the
    /// offer already accepted, at the listing's asking price. This is a
    /// separate method (rather than letting CreateOfferRequest accept a
    /// status field) so a buyer can never set an arbitrary status through
    /// the normal make-an-offer path — only this explicit, intentional
    /// action does that.</summary>
    public async Task<(bool ok, string error, OfferDto? offer)> CreateAcceptedOfferAsync(
        string bearerToken, string listingId, string buyerId, string buyerName, string buyerPhone, decimal price)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");

        var payload = new
        {
            listing_id = listingId,
            buyer_id = buyerId,
            buyer_name = buyerName,
            buyer_phone = buyerPhone,
            offer_price = price,
            message = "Direct purchase (Buy Now)",
            status = "accepted"
        };

        var res = await client.PostAsJsonAsync("listing_offers?select=*,listings(title,asking_price)", payload, JsonOpts);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);

        var (ok, error, list) = await ReadListAsync<OfferDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, OfferDto? offer)> UpdateOfferStatusAsync(
        string bearerToken, string id, string status)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");

        var request = new HttpRequestMessage(HttpMethod.Patch, $"listing_offers?id=eq.{id}")
        {
            Content = JsonContent.Create(new { status }, options: JsonOpts)
        };
        var res = await client.SendAsync(request);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);

        var (ok, error, list) = await ReadListAsync<OfferDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, OfferDto? offer)> GetOfferAsync(string bearerToken, string id)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync($"listing_offers?id=eq.{id}&select=*,listings(title,asking_price)&limit=1");
        var (ok, error, list) = await ReadListAsync<OfferDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, OfferDto? offer)> SetOfferCheckoutIdAsync(string bearerToken, string id, string checkoutId)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");
        var request = new HttpRequestMessage(HttpMethod.Patch, $"listing_offers?id=eq.{id}")
        {
            Content = JsonContent.Create(new { yoco_checkout_id = checkoutId }, options: JsonOpts)
        };
        var res = await client.SendAsync(request);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);
        var (ok, error, list) = await ReadListAsync<OfferDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, OfferDto? offer)> MarkOfferPaidAsync(string bearerToken, string id)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");
        var request = new HttpRequestMessage(HttpMethod.Patch, $"listing_offers?id=eq.{id}")
        {
            Content = JsonContent.Create(new { payment_status = "paid" }, options: JsonOpts)
        };
        var res = await client.SendAsync(request);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);
        var (ok, error, list) = await ReadListAsync<OfferDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    // ---- Deliveries -------------------------------------------------------

    public async Task<(bool ok, string error, DeliveryDto? delivery)> CreateDeliveryAsync(string bearerToken, object payload)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");
        var res = await client.PostAsJsonAsync("deliveries", payload, JsonOpts);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);
        var (ok, error, list) = await ReadListAsync<DeliveryDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, DeliveryDto? delivery)> GetDeliveryByOfferAsync(string bearerToken, string offerId)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync($"deliveries?offer_id=eq.{offerId}&limit=1");
        var (ok, error, list) = await ReadListAsync<DeliveryDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, DeliveryDto? delivery)> GetDeliveryAsync(string bearerToken, string id)
    {
        var client = Client(bearerToken);
        var res = await client.GetAsync($"deliveries?id=eq.{id}&limit=1");
        var (ok, error, list) = await ReadListAsync<DeliveryDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    public async Task<(bool ok, string error, DeliveryDto? delivery)> PatchDeliveryAsync(string bearerToken, string id, object patch)
    {
        var client = Client(bearerToken);
        client.DefaultRequestHeaders.Add("Prefer", "return=representation");
        var request = new HttpRequestMessage(HttpMethod.Patch, $"deliveries?id=eq.{id}")
        {
            Content = JsonContent.Create(patch, options: JsonOpts)
        };
        var res = await client.SendAsync(request);
        if (!res.IsSuccessStatusCode) return (false, await res.Content.ReadAsStringAsync(), null);
        var (ok, error, list) = await ReadListAsync<DeliveryDto>(res);
        return (ok, error, ok ? list.FirstOrDefault() : null);
    }

    // ---- helpers ----------------------------------------------------------

    private static async Task<(bool ok, string error, List<T> data)> ReadListAsync<T>(HttpResponseMessage res)
    {
        if (!res.IsSuccessStatusCode)
        {
            var errorBody = await res.Content.ReadAsStringAsync();
            return (false, string.IsNullOrWhiteSpace(errorBody) ? $"Supabase returned {(int)res.StatusCode}." : errorBody, new List<T>());
        }
        var body = await res.Content.ReadAsStringAsync();
        if (string.IsNullOrWhiteSpace(body)) return (true, "", new List<T>());
        return (true, "", JsonSerializer.Deserialize<List<T>>(body, JsonOpts) ?? new List<T>());
    }
}
