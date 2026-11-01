import '../models/offer.dart';
import 'api_client.dart';

class OfferService {
  final ApiClient _api = ApiClient();

  Future<List<Offer>> getOffersForListing(String listingId) async {
    final data = await _api.get('/api/listings/$listingId/offers');
    return (data as List).map((e) => Offer.fromJson(e)).toList();
  }

  Future<List<Offer>> getMyOffers() async {
    final data = await _api.get('/api/offers/mine');
    return (data as List).map((e) => Offer.fromJson(e)).toList();
  }

  Future<Offer> makeOffer(
    String listingId, {
    required String buyerName,
    required String buyerPhone,
    double? offerPrice,
    String? message,
  }) async {
    final data = await _api.post('/api/listings/$listingId/offers', {
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'offerPrice': offerPrice,
      'message': message,
    });
    return Offer.fromJson(data);
  }

  Future<Offer> updateStatus(String offerId, String status) async {
    final data = await _api.patch('/api/offers/$offerId', {'status': status});
    return Offer.fromJson(data);
  }

  /// Buy Now — skips negotiation, creates an offer that's already
  /// "accepted" at the listing's asking price, ready to pay for
  /// immediately. "Make an offer" (makeOffer above) is unaffected and
  /// stays available for anyone who wants to negotiate instead.
  Future<Offer> buyNow(String listingId, {required String buyerName, required String buyerPhone}) async {
    final data = await _api.post('/api/listings/$listingId/buy-now', {
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
    });
    return Offer.fromJson(data);
  }
}
