import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/offer.dart';
import '../services/offer_service.dart';
import 'dummy_checkout_screen.dart';

class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
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

  Future<void> _pay(Offer offer) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DummyCheckoutScreen(offer: offer)),
    );
    if (result != false) _refresh();
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
      appBar: AppBar(title: const Text('My offers')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Offer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final offers = snapshot.data ?? [];
            if (offers.isEmpty) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
                children: [
                  Icon(Icons.local_offer_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'You have not made any offers yet. Browse the marketplace and tap "Make an offer" on a listing.',
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
                final canPay = offer.status == 'accepted' && offer.paymentStatus != 'paid';
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
                          Expanded(child: Text(offer.listingTitle ?? 'Listing', style: AppFonts.headingSemibold(size: 15))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(offer.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              offer.paymentStatus == 'paid' ? 'paid' : offer.status,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(offer.status)),
                            ),
                          ),
                        ],
                      ),
                      if (offer.offerPrice != null) ...[
                        const SizedBox(height: 4),
                        Text('Offer: R${offer.offerPrice!.toStringAsFixed(0)}', style: AppFonts.heading(size: 15, color: AppColors.brandGreen)),
                      ],
                      if (offer.message != null && offer.message!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('"${offer.message}"', style: AppFonts.body(size: 13)),
                      ],
                      const SizedBox(height: 10),
                      if (offer.status == 'pending')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await _service.updateStatus(offer.id, 'withdrawn');
                              _refresh();
                            },
                            child: const Text('Withdraw'),
                          ),
                        )
                      else if (canPay)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _pay(offer),
                            child: const Text('Pay now (demo checkout)'),
                          ),
                        ),
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
