import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/auth_provider.dart';
import '../services/listing_service.dart';
import '../widgets/listing_card.dart';
import 'create_listing_screen.dart';
import 'finance_screen.dart';
import 'listing_detail_screen.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'my_offers_screen.dart';
import 'profile_screen.dart';
import 'received_offers_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final bool guest;
  const MarketplaceScreen({super.key, this.guest = false});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

enum _SortOption { newest, oldest, priceLowHigh, priceHighLow }

extension on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.newest:
        return 'Newest first';
      case _SortOption.oldest:
        return 'Oldest first';
      case _SortOption.priceLowHigh:
        return 'Price: low to high';
      case _SortOption.priceHighLow:
        return 'Price: high to low';
    }
  }
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _service = ListingService();
  late Future<List<Listing>> _future;
  _SortOption _sort = _SortOption.newest;

  @override
  void initState() {
    super.initState();
    _future = _service.getActiveListings();
  }

  Future<void> _refresh() async {
    setState(() { _future = _service.getActiveListings(); });
    await _future;
  }

  List<Listing> _sorted(List<Listing> listings) {
    final copy = List<Listing>.from(listings);
    switch (_sort) {
      case _SortOption.newest:
        copy.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
        break;
      case _SortOption.oldest:
        copy.sort((a, b) => (a.createdAt ?? DateTime(1970)).compareTo(b.createdAt ?? DateTime(1970)));
        break;
      case _SortOption.priceLowHigh:
        copy.sort((a, b) => a.askingPrice.compareTo(b.askingPrice));
        break;
      case _SortOption.priceHighLow:
        copy.sort((a, b) => b.askingPrice.compareTo(a.askingPrice));
        break;
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loggedIn = auth.status == AuthStatus.authenticated;
    final isFarmer = auth.isFarmer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          PopupMenuButton<_SortOption>(
            tooltip: 'Sort: ${_sort.label}',
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => _SortOption.values
                .map((option) => PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          if (option == _sort) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(option.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
          if (loggedIn) ...[
            if (isFarmer) ...[
              IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: 'Finance',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FinanceScreen()))
                    .then((_) => _refresh()),
              ),
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'My listings',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const MyListingsScreen()))
                    .then((_) => _refresh()),
              ),
              IconButton(
                icon: const Icon(Icons.mail_outline),
                tooltip: 'Offers received',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceivedOffersScreen())),
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.local_offer_outlined),
                tooltip: 'My offers',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOffersScreen())),
              ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              ),
              child: const Text('Log in'),
            ),
        ],
      ),
      floatingActionButton: isFarmer
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New listing'),
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateListingScreen()),
                );
                if (created == true) _refresh();
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Listing>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Could not load listings.\n${snapshot.error}', textAlign: TextAlign.center)),
                ],
              );
            }
            final listings = _sorted(snapshot.data ?? []);
            if (listings.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No active listings yet.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return ListingCard(
                  listing: listing,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: listing.id)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
