import 'listing.dart';

class FinanceSummary {
  final double totalRevenue;
  final int soldCount;
  final List<Listing> soldListings;

  FinanceSummary({required this.totalRevenue, required this.soldCount, required this.soldListings});

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        totalRevenue: double.tryParse('${json['totalRevenue'] ?? json['total_revenue'] ?? 0}') ?? 0,
        soldCount: (json['soldCount'] ?? json['sold_count'] ?? 0) is int
            ? json['soldCount'] ?? json['sold_count']
            : int.tryParse('${json['soldCount'] ?? json['sold_count']}') ?? 0,
        soldListings: ((json['soldListings'] ?? json['sold_listings'] ?? []) as List)
            .map((e) => Listing.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
