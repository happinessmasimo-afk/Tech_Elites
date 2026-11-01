import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/finance_summary.dart';
import '../models/listing.dart';
import '../models/offer.dart';
import '../providers/auth_provider.dart';
import '../services/finance_service.dart';
import '../services/listing_service.dart';
import '../services/offer_service.dart';
import 'create_listing_screen.dart';
import 'finance_screen.dart';
import 'listing_detail_screen.dart';
import 'marketplace_screen.dart';
import 'my_listings_screen.dart';
import 'profile_screen.dart';
import 'received_offers_screen.dart';

class DashboardData {
  final List<Listing> myListings;
  final FinanceSummary finance;
  final List<Offer> receivedOffers;
  DashboardData({required this.myListings, required this.finance, required this.receivedOffers});
}

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardData> _load() async {
    final results = await Future.wait([
      ListingService().getMyListings(),
      FinanceService().getSummary(),
      OfferService().getMyOffers(),
    ]);
    return DashboardData(
      myListings: results[0] as List<Listing>,
      finance: results[1] as FinanceSummary,
      receivedOffers: results[2] as List<Offer>,
    );
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Could not load dashboard.\n${snapshot.error}', textAlign: TextAlign.center)),
                ],
              );
            }

            final data = snapshot.data!;
            final activeCount = data.myListings.where((l) => l.status == 'active').length;
            final pendingOffers = data.receivedOffers.where((o) => o.status == 'pending').length;
            final recentSold = data.finance.soldListings.take(3).toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Welcome back${profile?.fullName != null ? ', ${profile!.fullName!.split(' ').first}' : ''}',
                    style: AppFonts.heading(size: 22)),
                const SizedBox(height: 4),
                Text("Here's how your farm is doing on Agricast", style: AppFonts.body(color: AppColors.muted)),
                const SizedBox(height: 20),

                // --- Stat cards ---
                Row(
                  children: [
                    Expanded(child: _statCard('Active listings', '$activeCount', Icons.pets, AppColors.brandGreen)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Total revenue', 'R${data.finance.totalRevenue.toStringAsFixed(0)}', Icons.bar_chart, AppColors.brandGreenDark)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statCard('Sold', '${data.finance.soldCount}', Icons.check_circle_outline, AppColors.brandGreen)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        'Pending offers',
                        '$pendingOffers',
                        Icons.mail_outline,
                        pendingOffers > 0 ? AppColors.danger : AppColors.muted,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const ReceivedOffersScreen()))
                            .then((_) => _refresh()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                Text('Quick actions', style: AppFonts.headingSemibold(size: 16)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    _actionTile('New listing', Icons.add_circle_outline, () async {
                      final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreateListingScreen()));
                      if (created == true) _refresh();
                    }),
                    _actionTile('My listings', Icons.list_alt, () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const MyListingsScreen()))
                        .then((_) => _refresh())),
                    _actionTile('Offers received', Icons.mail_outline, () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ReceivedOffersScreen()))
                        .then((_) => _refresh())),
                    _actionTile('Finance', Icons.bar_chart, () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const FinanceScreen()))
                        .then((_) => _refresh())),
                    _actionTile('Browse marketplace', Icons.storefront_outlined, () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const MarketplaceScreen()))),
                  ],
                ),

                const SizedBox(height: 28),
                Text('Recently sold', style: AppFonts.headingSemibold(size: 16)),
                const SizedBox(height: 10),
                if (recentSold.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nothing sold yet — once you do, it shows up here.', style: AppFonts.body(color: AppColors.muted)),
                  )
                else
                  ...recentSold.map((listing) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(listing.title, style: AppFonts.bodySemibold()),
                        subtitle: Text(listing.species, style: AppFonts.body(color: AppColors.muted, size: 12)),
                        trailing: Text(
                          'R${(listing.soldPrice ?? listing.askingPrice).toStringAsFixed(0)}',
                          style: AppFonts.heading(size: 15, color: AppColors.brandGreen),
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: listing.id))),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value, style: AppFonts.heading(size: 20, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(label, style: AppFonts.body(color: AppColors.muted, size: 12)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.brandGreenLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandGreenDark, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppFonts.bodySemibold(size: 13), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
