import '../models/delivery.dart';
import 'api_client.dart';

class DeliveryService {
  final ApiClient _api = ApiClient();

  Future<Delivery> create({
    required String offerId,
    required String method,
    double? buyerLatitude,
    double? buyerLongitude,
  }) async {
    final data = await _api.post('/api/deliveries', {
      'offerId': offerId,
      'method': method,
      'buyerLatitude': buyerLatitude,
      'buyerLongitude': buyerLongitude,
    });
    return Delivery.fromJson(data);
  }

  Future<Delivery> getByOffer(String offerId) async {
    final data = await _api.get('/api/deliveries/by-offer/$offerId');
    return Delivery.fromJson(data);
  }

  Future<Delivery> getById(String id) async {
    final data = await _api.get('/api/deliveries/$id');
    return Delivery.fromJson(data);
  }

  /// The travelling party taps Start — this is the "e-hailing" moment
  /// the other side effectively gets notified, since their tracking
  /// screen is already polling this same delivery.
  Future<Delivery> start(String id) async {
    final data = await _api.post('/api/deliveries/$id/start', {});
    return Delivery.fromJson(data);
  }

  Future<Delivery> updateLocation(String id, double latitude, double longitude) async {
    final data = await _api.patch('/api/deliveries/$id/location', {
      'latitude': latitude,
      'longitude': longitude,
    });
    return Delivery.fromJson(data);
  }

  Future<Delivery> updateStatus(String id, String status) async {
    final data = await _api.patch('/api/deliveries/$id/status', {'status': status});
    return Delivery.fromJson(data);
  }
}
