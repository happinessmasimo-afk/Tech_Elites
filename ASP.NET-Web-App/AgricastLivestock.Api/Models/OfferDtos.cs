using System.Text.Json.Serialization;

namespace AgricastLivestock.Api.Models;

public class OfferDto
{
    public string? Id { get; set; }
    [JsonPropertyName("listing_id")] public string ListingId { get; set; } = string.Empty;
    [JsonPropertyName("buyer_id")] public string? BuyerId { get; set; }
    [JsonPropertyName("buyer_name")] public string? BuyerName { get; set; }
    [JsonPropertyName("buyer_phone")] public string? BuyerPhone { get; set; }
    [JsonPropertyName("offer_price")] public decimal? OfferPrice { get; set; }
    public string? Message { get; set; }
    public string Status { get; set; } = "pending";
    [JsonPropertyName("created_at")] public DateTimeOffset? CreatedAt { get; set; }
    [JsonPropertyName("payment_status")] public string PaymentStatus { get; set; } = "unpaid";
    // Column exists from an earlier real-gateway version of this flow;
    // unused now that payment is a dummy toggle, kept so the DB schema
    // doesn't need another migration just to drop it.
    [JsonPropertyName("yoco_checkout_id")] public string? YocoCheckoutId { get; set; }
    // Populated when the query embeds the parent listing (see
    // SupabaseRestService's "&select=*,listings(title)") so the app can
    // show which listing an offer is for without a second round trip.
    [JsonPropertyName("listings")] public EmbeddedListingRef? Listing { get; set; }
}

public class EmbeddedListingRef
{
    public string? Title { get; set; }
    [JsonPropertyName("asking_price")] public decimal? AskingPrice { get; set; }
}

public record CreateOfferRequest(string BuyerName, string BuyerPhone, decimal? OfferPrice, string? Message);

public record BuyNowRequest(string BuyerName, string BuyerPhone);

public record UpdateOfferStatusRequest(string Status); // accepted | declined | withdrawn
