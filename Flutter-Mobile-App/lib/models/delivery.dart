class Delivery {
  final String id;
  final String offerId;
  final String listingId;
  final String farmerId;
  final String buyerId;
  final String method; // pickup | delivery
  final double? buyerLatitude;
  final double? buyerLongitude;
  final double? farmerLatitude;
  final double? farmerLongitude;
  final double? distanceKm;
  final int? etaMinutes;
  final String status; // pending | in_transit | delivered
  final DateTime? startedAt;

  Delivery({
    required this.id,
    required this.offerId,
    required this.listingId,
    required this.farmerId,
    required this.buyerId,
    required this.method,
    this.buyerLatitude,
    this.buyerLongitude,
    this.farmerLatitude,
    this.farmerLongitude,
    this.distanceKm,
    this.etaMinutes,
    required this.status,
    this.startedAt,
  });

  /// Who is physically travelling on this trip: the buyer for a pickup,
  /// the farmer for a delivery.
  bool get buyerIsTraveler => method == 'pickup';

  /// The traveller's own live position (updates repeatedly en route).
  double? get travelerLatitude => buyerIsTraveler ? buyerLatitude : farmerLatitude;
  double? get travelerLongitude => buyerIsTraveler ? buyerLongitude : farmerLongitude;

  /// The fixed point the traveller is heading toward: the farm for a
  /// pickup, the buyer's pinned address for a delivery.
  double? get destinationLatitude => buyerIsTraveler ? farmerLatitude : buyerLatitude;
  double? get destinationLongitude => buyerIsTraveler ? farmerLongitude : buyerLongitude;

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
        id: json['id']?.toString() ?? '',
        offerId: json['offer_id']?.toString() ?? json['offerId']?.toString() ?? '',
        listingId: json['listing_id']?.toString() ?? json['listingId']?.toString() ?? '',
        farmerId: json['farmer_id']?.toString() ?? json['farmerId']?.toString() ?? '',
        buyerId: json['buyer_id']?.toString() ?? json['buyerId']?.toString() ?? '',
        method: json['method'] ?? 'pickup',
        buyerLatitude: json['buyer_latitude'] != null ? double.tryParse('${json['buyer_latitude']}') : null,
        buyerLongitude: json['buyer_longitude'] != null ? double.tryParse('${json['buyer_longitude']}') : null,
        farmerLatitude: json['farmer_latitude'] != null ? double.tryParse('${json['farmer_latitude']}') : null,
        farmerLongitude: json['farmer_longitude'] != null ? double.tryParse('${json['farmer_longitude']}') : null,
        distanceKm: json['distance_km'] != null ? double.tryParse('${json['distance_km']}') : null,
        etaMinutes: json['eta_minutes'] != null ? int.tryParse('${json['eta_minutes']}') : null,
        status: json['status'] ?? 'pending',
        startedAt: json['started_at'] != null || json['startedAt'] != null
            ? DateTime.tryParse('${json['started_at'] ?? json['startedAt']}')
            : null,
      );
}
