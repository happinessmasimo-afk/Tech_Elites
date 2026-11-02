using System.Text.Json.Serialization;

namespace AgricastLivestock.Api.Models;

public class ListingDto
{
    public string? Id { get; set; }
    [JsonPropertyName("owner_id")] public string? OwnerId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Species { get; set; } = string.Empty;
    public string? Breed { get; set; }
    public string? Sex { get; set; }
    public int Quantity { get; set; } = 1;
    [JsonPropertyName("age_months")] public int? AgeMonths { get; set; }
    [JsonPropertyName("asking_price")] public decimal AskingPrice { get; set; }
    [JsonPropertyName("price_unit")] public string PriceUnit { get; set; } = "per_head";
    public string Status { get; set; } = "active";
    public string? Description { get; set; }
    public string? Location { get; set; }
    [JsonPropertyName("photo_urls")] public List<string> PhotoUrls { get; set; } = new();
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    [JsonPropertyName("sold_price")] public decimal? SoldPrice { get; set; }
    [JsonPropertyName("sold_at")] public DateTimeOffset? SoldAt { get; set; }
    [JsonPropertyName("created_at")] public DateTimeOffset? CreatedAt { get; set; }
    [JsonPropertyName("updated_at")] public DateTimeOffset? UpdatedAt { get; set; }
}

public record CreateListingRequest(
    string Title,
    string Species,
    string? Breed,
    string? Sex,
    int Quantity,
    int? AgeMonths,
    decimal AskingPrice,
    string PriceUnit,
    string? Description,
    string? Location,
    List<string>? PhotoUrls,
    double? Latitude,
    double? Longitude
);

public record UpdateListingRequest(
    string? Title,
    string? Breed,
    int? Quantity,
    decimal? AskingPrice,
    string? PriceUnit,
    string? Status,
    string? Description,
    string? Location,
    List<string>? PhotoUrls,
    decimal? SoldPrice
);

public class FinanceSummaryDto
{
    public decimal TotalRevenue { get; set; }
    public int SoldCount { get; set; }
    public List<ListingDto> SoldListings { get; set; } = new();
}
