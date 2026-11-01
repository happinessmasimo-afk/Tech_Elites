class Listing {
  final String id;
  final String ownerId;
  final String title;
  final String species;
  final String? breed;
  final String? sex;
  final int quantity;
  final int? ageMonths;
  final double askingPrice;
  final String priceUnit; // per_head | per_kg
  final String status; // active | sold | withdrawn
  final String? description;
  final String? location;
  final List<String> photoUrls;
  final double? latitude;
  final double? longitude;
  final double? soldPrice;
  final DateTime? soldAt;
  final DateTime? createdAt;

  Listing({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.species,
    this.breed,
    this.sex,
    required this.quantity,
    this.ageMonths,
    required this.askingPrice,
    required this.priceUnit,
    required this.status,
    this.description,
    this.location,
    this.photoUrls = const [],
    this.latitude,
    this.longitude,
    this.soldPrice,
    this.soldAt,
    this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id']?.toString() ?? '',
        ownerId: json['owner_id']?.toString() ?? json['ownerId']?.toString() ?? '',
        title: json['title'] ?? '',
        species: json['species'] ?? '',
        breed: json['breed'],
        sex: json['sex'],
        quantity: (json['quantity'] ?? 1) is int ? json['quantity'] : int.tryParse('${json['quantity']}') ?? 1,
        ageMonths: json['age_months'] ?? json['ageMonths'],
        askingPrice: double.tryParse('${json['asking_price'] ?? json['askingPrice'] ?? 0}') ?? 0,
        priceUnit: json['price_unit'] ?? json['priceUnit'] ?? 'per_head',
        status: json['status'] ?? 'active',
        description: json['description'],
        location: json['location'],
        photoUrls: (json['photo_urls'] ?? json['photoUrls'] ?? []) is List
            ? List<String>.from((json['photo_urls'] ?? json['photoUrls'] ?? []).map((e) => e.toString()))
            : const [],
        latitude: json['latitude'] != null ? double.tryParse('${json['latitude']}') : null,
        longitude: json['longitude'] != null ? double.tryParse('${json['longitude']}') : null,
        soldPrice: (json['sold_price'] ?? json['soldPrice']) != null
            ? double.tryParse('${json['sold_price'] ?? json['soldPrice']}')
            : null,
        soldAt: DateTime.tryParse('${json['sold_at'] ?? json['soldAt'] ?? ''}'),
        createdAt: DateTime.tryParse('${json['created_at'] ?? json['createdAt'] ?? ''}'),
      );

  String get priceLabel {
    final unit = priceUnit == 'per_kg' ? '/kg' : '/head';
    return 'R${askingPrice.toStringAsFixed(0)} $unit';
  }
}
