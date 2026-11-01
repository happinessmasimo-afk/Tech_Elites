using System.Text.Json.Serialization;

namespace AgricastLivestock.Api.Models;

public class DeliveryDto
{
    public string? Id { get; set; }
    [JsonPropertyName("offer_id")] public string OfferId { get; set; } = string.Empty;
    [JsonPropertyName("listing_id")] public string ListingId { get; set; } = string.Empty;
    [JsonPropertyName("farmer_id")] public string FarmerId { get; set; } = string.Empty;
    [JsonPropertyName("buyer_id")] public string BuyerId { get; set; } = string.Empty;
    public string Method { get; set; } = "pickup"; // pickup | delivery
    [JsonPropertyName("buyer_latitude")] public double? BuyerLatitude { get; set; }
    [JsonPropertyName("buyer_longitude")] public double? BuyerLongitude { get; set; }
    [JsonPropertyName("farmer_latitude")] public double? FarmerLatitude { get; set; }
    [JsonPropertyName("farmer_longitude")] public double? FarmerLongitude { get; set; }
    [JsonPropertyName("distance_km")] public double? DistanceKm { get; set; }
    [JsonPropertyName("eta_minutes")] public int? EtaMinutes { get; set; }
    public string Status { get; set; } = "pending"; // pending | in_transit | delivered
    [JsonPropertyName("started_at")] public DateTimeOffset? StartedAt { get; set; }
    [JsonPropertyName("created_at")] public DateTimeOffset? CreatedAt { get; set; }
    [JsonPropertyName("updated_at")] public DateTimeOffset? UpdatedAt { get; set; }

    /// <summary>Who is physically travelling on this trip: the buyer for a
    /// pickup, the farmer for a delivery. Convenience for the app so it
    /// doesn't need to re-derive this from Method every time.</summary>
    public string TravelerRole => Method == "pickup" ? "buyer" : "farmer";
}

public record CreateDeliveryRequest(
    string OfferId,
    string Method, // pickup | delivery
    double? BuyerLatitude,
    double? BuyerLongitude
);

public record UpdateDeliveryLocationRequest(double Latitude, double Longitude);

public record UpdateDeliveryStatusRequest(string Status); // in_transit | delivered
