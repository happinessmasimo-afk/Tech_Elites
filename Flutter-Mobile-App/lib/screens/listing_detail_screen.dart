import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/listing.dart';
import '../providers/auth_provider.dart';
import '../services/listing_service.dart';
import '../services/offer_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_text_field.dart';
import 'dummy_checkout_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _listingService = ListingService();
  late Future<Listing> _future;

  @override
  void initState() {
    super.initState();
    _future = _listingService.getListing(widget.listingId);
  }

  Future<void> _openOfferSheet(Listing listing) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final priceController = TextEditingController();
    final messageController = TextEditingController();
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Make an offer on "${listing.title}"', style: AppFonts.headingSemibold(size: 16)),
              const SizedBox(height: 4),
              Text('Negotiate a different price — the farmer can accept, decline, or you can withdraw anytime.',
                  style: AppFonts.body(color: AppColors.muted, size: 12)),
              const SizedBox(height: 12),
              AppTextField(controller: nameController, label: 'Your name'),
              AppTextField(controller: phoneController, label: 'Your phone', keyboardType: TextInputType.phone),
              AppTextField(controller: priceController, label: 'Offer price (optional)', keyboardType: TextInputType.number),
              AppTextField(controller: messageController, label: 'Message (optional)'),
              PrimaryButton(
                label: 'Send offer',
                loading: sending,
                onPressed: () async {
                  setSheetState(() => sending = true);
                  try {
                    await OfferService().makeOffer(
                      listing.id,
                      buyerName: nameController.text.trim(),
                      buyerPhone: phoneController.text.trim(),
                      offerPrice: double.tryParse(priceController.text),
                      message: messageController.text.trim().isEmpty ? null : messageController.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer sent!')));
                    }
                  } catch (e) {
                    setSheetState(() => sending = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not send offer: $e')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBuyNowSheet(Listing listing) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Buy "${listing.title}" now', style: AppFonts.headingSemibold(size: 16)),
              const SizedBox(height: 4),
              Text(
                'Skips negotiation — buys immediately at the listed price of ${listing.priceLabel}.',
                style: AppFonts.body(color: AppColors.muted, size: 12),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: nameController, label: 'Your name'),
              AppTextField(controller: phoneController, label: 'Your phone', keyboardType: TextInputType.phone),
              PrimaryButton(
                label: 'Continue to payment',
                loading: sending,
                onPressed: () async {
                  if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter your name and phone.')));
                    return;
                  }
                  setSheetState(() => sending = true);
                  try {
                    final offer = await OfferService().buyNow(
                      listing.id,
                      buyerName: nameController.text.trim(),
                      buyerPhone: phoneController.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DummyCheckoutScreen(offer: offer)));
                  } catch (e) {
                    setSheetState(() => sending = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Could not start purchase: $e')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Listing')),
      body: FutureBuilder<Listing>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Could not load listing.\n${snapshot.error ?? ""}'));
          }
          final listing = snapshot.data!;
          final isOwner = context.read<AuthProvider>().profile?.id == listing.ownerId;
          final canTransact = !isOwner && listing.status == 'active';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (listing.photoUrls.isNotEmpty) ...[
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: listing.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        listing.photoUrls[i],
                        width: 260,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _photoPlaceholder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                Container(
                  height: 160,
                  decoration: BoxDecoration(color: AppColors.brandGreenLight, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Icon(Icons.pets, size: 48, color: AppColors.brandGreenDark)),
                ),
                const SizedBox(height: 18),
              ],

              // --- Title + price header ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.title, style: AppFonts.heading(size: 22, color: AppColors.text)),
                        const SizedBox(height: 4),
                        Text(
                          '${listing.species}${listing.breed != null ? " · ${listing.breed}" : ""}',
                          style: AppFonts.body(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: listing.status == 'active' ? AppColors.brandGreenLight : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(listing.status, style: AppFonts.headingSemibold(size: 11, color: AppColors.brandGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(listing.priceLabel, style: AppFonts.heading(size: 24, color: AppColors.brandGreen)),

              const SizedBox(height: 20),

              // --- Spec sheet card ---
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildSpecRows([
                  (Icons.pets, 'Species', listing.species),
                  if (listing.breed != null) (Icons.badge_outlined, 'Breed', listing.breed!),
                  if (listing.sex != null) (Icons.male, 'Sex', listing.sex!),
                  (Icons.numbers, 'Quantity', '${listing.quantity}'),
                  if (listing.ageMonths != null) (Icons.cake_outlined, 'Age', '${listing.ageMonths} months'),
                  if (listing.location != null) (Icons.location_on_outlined, 'Location', listing.location!),
                ]),
              ),

              if (listing.latitude != null && listing.longitude != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 150,
                    child: IgnorePointer(
                      // Static preview only — tapping doesn't pan/zoom, keeps
                      // this a lightweight "here's roughly where" rather than
                      // a full interactive map on the detail page.
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(listing.latitude!, listing.longitude!),
                          initialZoom: 11,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: MapConfig.tileUrl('streets-v12'),
                            userAgentPackageName: 'com.example.agricast_livestock_lite',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(listing.latitude!, listing.longitude!),
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_on, color: AppColors.brandGreen, size: 36),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              if (listing.description != null && listing.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Description', style: AppFonts.headingSemibold(size: 14, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text(listing.description!, style: AppFonts.body()),
              ],

              const SizedBox(height: 28),

              if (canTransact) ...[
                PrimaryButton(
                  label: loggedIn ? 'Buy now · ${listing.priceLabel}' : 'Log in to buy',
                  onPressed: () {
                    if (loggedIn) {
                      _openBuyNowSheet(listing);
                    } else {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: loggedIn ? 'Make an offer instead' : 'Log in to make an offer',
                  outlined: true,
                  onPressed: () {
                    if (loggedIn) {
                      _openOfferSheet(listing);
                    } else {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ],
              if (isOwner)
                Text('This is your listing — status: ${listing.status}', style: AppFonts.body(color: AppColors.muted)),
            ],
          );
        },
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 260,
      height: 200,
      color: AppColors.brandGreenLight,
      child: const Icon(Icons.pets, color: AppColors.brandGreenDark, size: 40),
    );
  }

  Widget _buildSpecRows(List<(IconData, String, String)> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final (icon, label, value) = rows[i];
      children.add(_specRow(icon, label, value));
      if (i != rows.length - 1) children.add(const Divider(height: 1, color: AppColors.border));
    }
    return Column(children: children);
  }

  Widget _specRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.brandGreenDark),
          const SizedBox(width: 12),
          Text(label, style: AppFonts.body(color: AppColors.muted, size: 13)),
          const Spacer(),
          Text(value, style: AppFonts.bodySemibold(size: 13)),
        ],
      ),
    );
  }
}
