import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/offer.dart';
import '../services/payment_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'delivery_method_screen.dart';

/// A deliberately fake checkout — no real payment gateway anywhere in this
/// flow. It exists to look and feel like a real one (order summary, card
/// details, a "processing" wait, then success) while the actual payment
/// logic is a one-line dummy toggle on the backend. See PaymentsController
/// for exactly what "paying" does and doesn't do.
class DummyCheckoutScreen extends StatefulWidget {
  final Offer offer;
  const DummyCheckoutScreen({super.key, required this.offer});

  @override
  State<DummyCheckoutScreen> createState() => _DummyCheckoutScreenState();
}

enum _CheckoutStep { summary, cardDetails, processing, success }

class _DummyCheckoutScreenState extends State<DummyCheckoutScreen> {
  _CheckoutStep _step = _CheckoutStep.summary;
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String? _error;
  Offer? _paidOffer;

  double get _amount => widget.offer.amount;

  Future<void> _submitPayment() async {
    if (_nameController.text.trim().isEmpty ||
        _numberController.text.replaceAll(' ', '').length < 12 ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().length < 3) {
      setState(() => _error = 'Fill in all card details (any values work — this is a demo).');
      return;
    }

    setState(() {
      _error = null;
      _step = _CheckoutStep.processing;
    });

    final digits = _numberController.text.replaceAll(' ', '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;

    try {
      final paid = await PaymentService().dummyPay(
        offerId: widget.offer.id,
        cardHolderName: _nameController.text.trim(),
        cardNumberLast4: last4,
      );
      if (!mounted) return;
      setState(() {
        _paidOffer = paid;
        _step = _CheckoutStep.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _CheckoutStep.cardDetails;
        _error = 'Payment failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_step) {
            _CheckoutStep.summary => _buildSummary(),
            _CheckoutStep.cardDetails => _buildCardForm(),
            _CheckoutStep.processing => _buildProcessing(),
            _CheckoutStep.success => _buildSuccess(),
          },
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Order summary', style: AppFonts.heading(size: 20)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.offer.listingTitle ?? 'Listing', style: AppFonts.headingSemibold(size: 16)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount', style: AppFonts.body(color: AppColors.muted)),
                  Text('R${_amount.toStringAsFixed(0)}', style: AppFonts.heading(size: 18, color: AppColors.brandGreen)),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'This is a demo checkout — no real payment gateway is used and no real money moves.',
          style: AppFonts.body(color: AppColors.muted, size: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Continue to payment', onPressed: () => setState(() => _step = _CheckoutStep.cardDetails)),
      ],
    );
  }

  Widget _buildCardForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Card details', style: AppFonts.heading(size: 20)),
          const SizedBox(height: 4),
          Text('Enter anything — this is a simulated payment.', style: AppFonts.body(color: AppColors.muted, size: 13)),
          const SizedBox(height: 16),
          AppTextField(controller: _nameController, label: 'Cardholder name'),
          AppTextField(controller: _numberController, label: 'Card number', keyboardType: TextInputType.number),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _expiryController, label: 'MM/YY')),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: _cvvController, label: 'CVV', keyboardType: TextInputType.number)),
            ],
          ),
          if (_error != null) ...[
            Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          PrimaryButton(label: 'Pay R${_amount.toStringAsFixed(0)}', onPressed: _submitPayment),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.brandGreen),
        const SizedBox(height: 20),
        Text('Processing payment...', style: AppFonts.bodyMedium()),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: AppColors.brandGreen, size: 72),
        const SizedBox(height: 16),
        Center(child: Text('Payment successful!', style: AppFonts.heading(size: 20))),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'The farmer has been notified and this listing is now marked sold.',
            style: AppFonts.body(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Arrange delivery / pickup',
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => DeliveryMethodScreen(offer: _paidOffer ?? widget.offer)),
            );
          },
        ),
      ],
    );
  }
}
