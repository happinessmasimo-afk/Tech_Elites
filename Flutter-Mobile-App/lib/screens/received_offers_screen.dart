import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/offer.dart';
import '../services/offer_service.dart';
import '../services/delivery_service.dart';
import 'trip_traveler_screen.dart';
import 'trip_watch_screen.dart';

/// The farmer's view of incoming offers — same backend data as
/// MyOffersScreen (a buyer's own offers), but RLS returns a completely
/// different set of rows for a farmer's token (offers on listings they
/// own), so this is a distinct screen with Accept/Decline actions instead
/// of Withdraw.
class ReceivedOffersScreen extends StatefulWidget {
  const ReceivedOffersScreen({super.key});

  @override
  State<ReceivedOffersScreen> createState() => _ReceivedOffersScreenState();
}

class _ReceivedOffersScreenState extends State<ReceivedOffersScreen> {
  final _service = OfferService();
  late Future<List<Offer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyOffers();
  }

  Future<void> _refresh() async {
    setState(() { _future = _service.getMyOffers(); });
    await _future;
  }

  Future<void> _respond(Offer offer, String status) async {
    try {
      await _service.updateStatus(offer.id, status);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update offer: $e')));
    }
  }

  Future<void> _openDelivery(Offer offer) async {
    try {
      final delivery = await DeliveryService().getByOffer(offer.id);
      if (!mounted) return;
      if (delivery.status == 'delivered') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(delivery.method == 'pickup' ? 'Already marked picked up.' : 'Already marked delivered.')),
        );
        return;
      }
      if (delivery.method == 'pickup') {
        // Buyer is the one travelling to collect it — the farmer just
        // watches the buyer's live position approach, same e-hailing-style
        // screen a buyer uses to watch a farmer's delivery.
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripWatchScreen(deliveryId: delivery.id)));
      } else {
        // Farmer is the one travelling to deliver it.
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripTravelerScreen(deliveryId: delivery.id)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("The buyer hasn't arranged delivery or pickup yet.")),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.brandGreen;
      case 'declined':
        return AppColors.danger;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers received')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Offer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Could not load offers.\n${snapshot.error}', textAlign: TextAlign.center)),
                ],
              );
            }
            final offers = snapshot.data ?? [];
            if (offers.isEmpty) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No offers yet. When a buyer makes an offer on one of your listings, it shows up here.',
                      textAlign: TextAlign.center,
                      style: AppFonts.body(color: AppColors.muted),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(offer.listingTitle ?? 'Listing', style: AppFonts.headingSemibold(size: 15)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(offer.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              offer.status,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(offer.status)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'From ${offer.buyerName ?? "a buyer"}${offer.buyerPhone != null ? " · ${offer.buyerPhone}" : ""}',
                        style: AppFonts.body(color: AppColors.muted, size: 13),
                      ),
                      if (offer.offerPrice != null) ...[
                        const SizedBox(height: 4),
                        Text('Offer: R${offer.offerPrice!.toStringAsFixed(0)}', style: AppFonts.heading(size: 15, color: AppColors.brandGreen)),
                      ],
                      if (offer.message != null && offer.message!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('"${offer.message}"', style: AppFonts.body(color: AppColors.text, size: 13)),
                      ],
                      if (offer.status == 'pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respond(offer, 'declined'),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _respond(offer, 'accepted'),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (offer.paymentStatus == 'paid') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openDelivery(offer),
                            icon: const Icon(Icons.local_shipping_outlined, size: 18),
                            label: const Text('Delivery / pickup'),
                          ),
                        ),
                      ],
                    ],
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
