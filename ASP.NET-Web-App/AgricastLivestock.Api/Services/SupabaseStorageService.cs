using System.Net.Http.Headers;
using AgricastLivestock.Api.Models;
using Microsoft.Extensions.Options;

namespace AgricastLivestock.Api.Services;

/// <summary>
/// Uploads listing photos to the "listing-photos" Supabase Storage bucket
/// (created by supabase/migrations/002_marketplace.sql) using the calling
/// farmer's own access token, so the storage RLS policies there — not this
/// API — decide who can upload where. The bucket is public for reads, so
/// once uploaded a photo's URL can go straight into listings.photo_urls
/// and be shown to anyone browsing the marketplace, guests included.
/// </summary>
public class SupabaseStorageService
{
    private const string Bucket = "listing-photos";

    private readonly IHttpClientFactory _factory;
    private readonly SupabaseOptions _options;

    public SupabaseStorageService(IHttpClientFactory factory, IOptions<SupabaseOptions> options)
    {
        _factory = factory;
        _options = options.Value;
    }

    public async Task<(bool ok, string error, string? url)> UploadListingPhotoAsync(
        string bearerToken, string ownerId, Stream fileStream, string contentType, string originalFileName)
    {
        var ext = Path.GetExtension(originalFileName);
        if (string.IsNullOrWhiteSpace(ext)) ext = ".jpg";
        var path = $"{ownerId}/{Guid.NewGuid():N}{ext}";

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("apikey", _options.AnonKey);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AgricastLivestockApi/1.0");

        using var content = new StreamContent(fileStream);
        content.Headers.ContentType = new MediaTypeHeaderValue(string.IsNullOrWhiteSpace(contentType) ? "image/jpeg" : contentType);

        var uploadUrl = $"{_options.Url.TrimEnd('/')}/storage/v1/object/{Bucket}/{path}";
        var response = await client.PostAsync(uploadUrl, content);

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync();
            return (false, string.IsNullOrWhiteSpace(body) ? $"Upload failed ({(int)response.StatusCode})." : body, null);
        }

        var publicUrl = $"{_options.Url.TrimEnd('/')}/storage/v1/object/public/{Bucket}/{path}";
        return (true, "", publicUrl);
    }
}
