namespace AgricastLivestock.Api.Models;

/// <summary>
/// A dummy card capture — this app never touches, stores, or validates a
/// real card. It exists purely so the app's checkout flow looks and feels
/// like a real one (order summary -> card details -> processing -> paid),
/// with no external payment gateway wired up at all.
/// </summary>
public record DummyPayRequest(string OfferId, string CardHolderName, string CardNumberLast4);

public class DummyPayResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public OfferDto? Offer { get; set; }
}
