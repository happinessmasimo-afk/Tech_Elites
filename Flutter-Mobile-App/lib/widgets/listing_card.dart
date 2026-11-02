import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/listing.dart';

/// Mirrors the original app's marketplace card: white rounded card with a
/// hairline border, a status pill, brand-green price, muted location line.
class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;
  final bool showStatus;

  const ListingCard({super.key, required this.listing, required this.onTap, this.showStatus = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Always reserve this thumbnail column, photo or not — a
              // card that skips it entirely misaligns against cards that
              // have one, which is the "alignment issue" this fixes.
              if (listing.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    listing.photoUrls.first,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholderThumb(),
                  ),
                )
              else
                _placeholderThumb(),
              const SizedBox(width: 14),
              Expanded(child: _cardBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: AppColors.brandGreenLight, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.pets, color: AppColors.brandGreenDark),
    );
  }

  Widget _cardBody(BuildContext context) {
    return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(listing.title, style: AppFonts.heading(size: 16, color: AppColors.text))),
                  if (showStatus)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: listing.status == 'active' ? AppColors.brandGreenLight : AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing.status,
                        style: AppFonts.headingSemibold(size: 11, color: AppColors.brandGreen),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${listing.species}${listing.breed != null ? " · ${listing.breed}" : ""}'
                '${listing.sex != null ? " · ${listing.sex}" : ""}',
                style: AppFonts.body(color: AppColors.muted, size: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Qty ${listing.quantity}${listing.ageMonths != null ? " · ${listing.ageMonths} months" : ""}',
                style: AppFonts.bodyMedium(color: AppColors.brandGreenDark, size: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(listing.priceLabel, style: AppFonts.heading(size: 16, color: AppColors.brandGreen)),
                  if (listing.location != null)
                    Text(listing.location!, style: AppFonts.body(color: AppColors.muted, size: 12)),
                ],
              ),
            ],
    );
  }
}
