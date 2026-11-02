import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/finance_summary.dart';
import '../services/finance_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _service = FinanceService();
  late Future<FinanceSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getSummary();
  }

  Future<void> _refresh() async {
    setState(() { _future = _service.getSummary(); });
    await _future;
  }

  String _money(double amount) => 'R${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<FinanceSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Could not load finance data.\n${snapshot.error}', textAlign: TextAlign.center)),
                ],
              );
            }

            final summary = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total revenue', style: AppFonts.bodyMedium(color: Colors.white70, size: 13)),
                      const SizedBox(height: 6),
                      Text(
                        _money(summary.totalRevenue),
                        style: AppFonts.heading(size: 34, color: Colors.white, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${summary.soldCount} listing${summary.soldCount == 1 ? '' : 's'} sold',
                        style: AppFonts.bodyMedium(color: Colors.white70, size: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Sold listings', style: AppFonts.headingSemibold(size: 16)),
                const SizedBox(height: 8),
                if (summary.soldListings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing marked as sold yet. Once you mark a listing sold from '
                      '"My listings", it shows up here with what it sold for.',
                      style: AppFonts.body(color: AppColors.muted),
                    ),
                  )
                else
                  ...summary.soldListings.map((listing) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(listing.title, style: AppFonts.headingSemibold(size: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    listing.soldAt != null
                                        ? 'Sold ${_formatDate(listing.soldAt!)}'
                                        : 'Sold',
                                    style: AppFonts.body(color: AppColors.muted, size: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _money(listing.soldPrice ?? listing.askingPrice),
                              style: AppFonts.heading(size: 16, color: AppColors.brandGreen),
                            ),
                          ],
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
