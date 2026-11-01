using System.Text.Json;
using AgricastLivestock.Api.Models;
using Microsoft.Extensions.Options;

namespace AgricastLivestock.Api.Services;

/// <summary>
/// Real calls to Mapbox's Directions API (driving profile) to compute
/// distance and ETA between two points — used whenever a delivery's
/// distance/ETA needs (re)computing: once when the buyer sets their
/// address, and again each time the farmer's live position updates while
/// a delivery is in transit.
/// </summary>
public class MapboxDirectionsService
{
    private readonly IHttpClientFactory _factory;
    private readonly MapboxOptions _options;

    public MapboxDirectionsService(IHttpClientFactory factory, IOptions<MapboxOptions> options)
    {
        _factory = factory;
        _options = options.Value;
    }

    public async Task<(bool ok, double distanceKm, int etaMinutes)> GetRouteAsync(
        double originLat, double originLng, double destLat, double destLng)
    {
        if (string.IsNullOrWhiteSpace(_options.Token)) return (false, 0, 0);

        var client = _factory.CreateClient();
        var url =
            $"https://api.mapbox.com/directions/v5/mapbox/driving/{originLng},{originLat};{destLng},{destLat}" +
            $"?overview=false&access_token={_options.Token}";

        HttpResponseMessage response;
        try
        {
            response = await client.GetAsync(url);
        }
        catch
        {
            return (false, 0, 0);
        }

        if (!response.IsSuccessStatusCode) return (false, 0, 0);

        var body = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(body);
        var routes = doc.RootElement.TryGetProperty("routes", out var r) ? r : default;
        if (routes.ValueKind != JsonValueKind.Array || routes.GetArrayLength() == 0) return (false, 0, 0);

        var first = routes[0];
        var distanceMeters = first.GetProperty("distance").GetDouble();
        var durationSeconds = first.GetProperty("duration").GetDouble();

        return (true, distanceMeters / 1000.0, (int)Math.Ceiling(durationSeconds / 60.0));
    }
}
