import 'api_client.dart';
import '../models/offer.dart';

/// Talks to the backend's dummy payment endpoint — no real gateway, no
/// real card data. The last 4 digits sent along are for on-screen display
/// only; nothing about them is validated as a real card.
class PaymentService {
  final ApiClient _api = ApiClient();

  Future<Offer> dummyPay({
    required String offerId,
    required String cardHolderName,
    required String cardNumberLast4,
  }) async {
    final data = await _api.post('/api/payments/dummy-pay', {
      'offerId': offerId,
      'cardHolderName': cardHolderName,
      'cardNumberLast4': cardNumberLast4,
    });
    return Offer.fromJson(data['offer'] as Map<String, dynamic>);
  }
}
