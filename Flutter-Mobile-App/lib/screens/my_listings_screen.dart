import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/listing.dart';
import '../services/listing_service.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _service = ListingService();
  late Future<List<Listing>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyListings();
  }

  Future<void> _refresh() async {
    setState(() { _future = _service.getMyListings(); });
    await _future;
  }

  Future<void> _markSold(Listing listing) async {
    final soldPrice = await _promptSoldPrice(listing);
    if (soldPrice == null) return; // farmer cancelled
    await _service.markSold(listing.id, soldPrice);
    _refresh();
  }

  Future<double?> _promptSoldPrice(Listing listing) async {
    final controller = TextEditingController(text: listing.askingPrice.toStringAsFixed(0));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as sold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What did "${listing.title}" actually sell for?', style: AppFonts.body(color: AppColors.muted, size: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Sale price', prefixText: 'R'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? listing.askingPrice;
              Navigator.of(ctx).pop(value);
            },
            child: const Text('Confirm sold'),
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw(Listing listing) async {
    await _service.markStatus(listing.id, 'withdrawn');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Listing>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final listings = snapshot.data ?? [];
            if (listings.isEmpty) {
              return ListView(children: const [SizedBox(height: 80), Center(child: Text('You have no listings yet.'))]);
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return Stack(
                  children: [
                    ListingCard(
                      showStatus: true,
                      listing: listing,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: listing.id))),
                    ),
                    if (listing.status == 'active')
                      Positioned(
                        top: 6,
                        right: 22,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.muted),
                          onSelected: (value) => value == 'sold' ? _markSold(listing) : _withdraw(listing),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
                            PopupMenuItem(value: 'withdraw', child: Text('Withdraw')),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
