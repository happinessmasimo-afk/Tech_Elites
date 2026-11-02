import '../models/listing.dart';
import 'api_client.dart';

class ListingService {
  final ApiClient _api = ApiClient();

  Future<List<Listing>> getActiveListings() async {
    // Not "auth: false" — a guest naturally has no stored token so this
    // still works for them, but a logged-in farmer/buyer needs their token
    // sent so RLS can recognize them (this used to be hardcoded to never
    // send it at all, which is what broke viewing anything non-active).
    final data = await _api.get('/api/listings');
    return (data as List).map((e) => Listing.fromJson(e)).toList();
  }

  Future<List<Listing>> getMyListings() async {
    final data = await _api.get('/api/listings/mine');
    return (data as List).map((e) => Listing.fromJson(e)).toList();
  }

  Future<Listing> getListing(String id) async {
    final data = await _api.get('/api/listings/$id');
    return Listing.fromJson(data);
  }

  Future<Listing> createListing({
    required String title,
    required String species,
    String? breed,
    String? sex,
    required int quantity,
    int? ageMonths,
    required double askingPrice,
    required String priceUnit,
    String? description,
    String? location,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _api.post('/api/listings', {
      'title': title,
      'species': species,
      'breed': breed,
      'sex': sex,
      'quantity': quantity,
      'ageMonths': ageMonths,
      'askingPrice': askingPrice,
      'priceUnit': priceUnit,
      'description': description,
      'location': location,
      'photoUrls': photoUrls ?? [],
      'latitude': latitude,
      'longitude': longitude,
    });
    return Listing.fromJson(data);
  }

  Future<Listing> markStatus(String id, String status) async {
    final data = await _api.put('/api/listings/$id', {'status': status});
    return Listing.fromJson(data);
  }

  /// Marks a listing sold and records what it actually sold for — this is
  /// what feeds the Finance summary's total revenue.
  Future<Listing> markSold(String id, double soldPrice) async {
    final data = await _api.put('/api/listings/$id', {'status': 'sold', 'soldPrice': soldPrice});
    return Listing.fromJson(data);
  }

  Future<void> deleteListing(String id) => _api.delete('/api/listings/$id');
}
