import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';
import '../models/offer.dart';
import '../services/delivery_service.dart';
import '../widgets/primary_button.dart';
import 'location_picker_screen.dart';
import 'marketplace_screen.dart';
import 'trip_traveler_screen.dart';
import 'trip_watch_screen.dart';

class DeliveryMethodScreen extends StatefulWidget {
  final Offer offer;
  const DeliveryMethodScreen({super.key, required this.offer});

  @override
  State<DeliveryMethodScreen> createState() => _DeliveryMethodScreenState();
}

class _DeliveryMethodScreenState extends State<DeliveryMethodScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _choosePickup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Pickup is e-hailing in the other direction: the buyer is the one
      // who travels, so this takes them straight into the traveller
      // screen (Start pickup journey / live GPS / arrived) rather than
      // just recording a choice and ending here.
      final delivery = await DeliveryService().create(offerId: widget.offer.id, method: 'pickup');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TripTravelerScreen(deliveryId: delivery.id)),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not save your choice: $e';
      });
    }
  }

  Future<void> _chooseDelivery() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (picked == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final delivery = await DeliveryService().create(
        offerId: widget.offer.id,
        method: 'delivery',
        buyerLatitude: picked.latitude,
        buyerLongitude: picked.longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TripWatchScreen(deliveryId: delivery.id)),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not start delivery tracking: $e';
      });
    }
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How will you get it?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose one', style: AppFonts.heading(size: 20)),
              const SizedBox(height: 8),
              Text(
                'This is just for "${widget.offer.listingTitle ?? "your purchase"}" — you can arrange the details with the farmer directly too.',
                style: AppFonts.body(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              _optionCard(
                icon: Icons.storefront_outlined,
                title: "I'll collect it myself",
                subtitle: "Start a live trip to the farm when you're on your way — the farmer sees you coming.",
                onTap: _loading ? null : _choosePickup,
              ),
              const SizedBox(height: 14),
              _optionCard(
                icon: Icons.local_shipping_outlined,
                title: 'Farmer delivers to me',
                subtitle: "Pin your location and track the farmer's live position on the way.",
                onTap: _loading ? null : _chooseDelivery,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
              ],
              if (_loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const Spacer(),
              PrimaryButton(label: "I'll decide later", outlined: true, onPressed: _loading ? null : _finish),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard({required IconData icon, required String title, required String subtitle, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandGreenDark, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppFonts.headingSemibold(size: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppFonts.body(color: AppColors.muted, size: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
