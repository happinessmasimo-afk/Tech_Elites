class Offer {
  final String id;
  final String listingId;
  final String? buyerId;
  final String? buyerName;
  final String? buyerPhone;
  final double? offerPrice;
  final String? message;
  final String status; // pending | accepted | declined | withdrawn
  final DateTime? createdAt;
  final String? listingTitle;
  final double? listingAskingPrice;
  final String paymentStatus;

  Offer({
    required this.id,
    required this.listingId,
    this.buyerId,
    this.buyerName,
    this.buyerPhone,
    this.offerPrice,
    this.message,
    required this.status,
    this.createdAt,
    this.listingTitle,
    this.listingAskingPrice,
    this.paymentStatus = 'unpaid',
  });

  /// What to actually charge/display — the buyer's stated offer, or the
  /// listing's asking price if they left it blank when offering.
  double get amount => offerPrice ?? listingAskingPrice ?? 0;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: json['id']?.toString() ?? '',
        listingId: json['listing_id']?.toString() ?? json['listingId']?.toString() ?? '',
        buyerId: json['buyer_id']?.toString() ?? json['buyerId']?.toString(),
        buyerName: json['buyer_name'] ?? json['buyerName'],
        buyerPhone: json['buyer_phone'] ?? json['buyerPhone'],
        offerPrice: json['offer_price'] != null || json['offerPrice'] != null
            ? double.tryParse('${json['offer_price'] ?? json['offerPrice']}')
            : null,
        message: json['message'],
        status: json['status'] ?? 'pending',
        createdAt: DateTime.tryParse('${json['created_at'] ?? json['createdAt'] ?? ''}'),
        listingTitle: (json['listings'] ?? json['listing'])?['title'],
        listingAskingPrice: (json['listings'] ?? json['listing'])?['asking_price'] != null
            ? double.tryParse('${(json['listings'] ?? json['listing'])['asking_price']}')
            : null,
        paymentStatus: json['payment_status'] ?? json['paymentStatus'] ?? 'unpaid',
      );
}
