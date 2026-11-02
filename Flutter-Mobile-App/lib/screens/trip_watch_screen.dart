import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/delivery.dart';
import '../services/delivery_service.dart';

/// The passive side of the trip: polls the backend every few seconds and
/// watches the travelling party's marker move on the map — simple polling
/// rather than a live socket, which is plenty for how often a position
/// realistically changes on a drive, and needs no extra backend
/// infrastructure beyond the REST endpoint already there. Works either
/// way: a farmer watching a buyer travel in for pickup, or a buyer
/// watching a farmer travel out for delivery.
class TripWatchScreen extends StatefulWidget {
  final String deliveryId;
  const TripWatchScreen({super.key, required this.deliveryId});

  @override
  State<TripWatchScreen> createState() => _TripWatchScreenState();
}

class _TripWatchScreenState extends State<TripWatchScreen> {
  final _service = DeliveryService();
  final _mapController = MapController();
  Delivery? _delivery;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isPickup => _delivery?.method == 'pickup';
  String get _travelerName => _isPickup ? 'The buyer' : 'The farmer';
  String get _title => _isPickup ? 'Track the buyer' : 'Track your delivery';
  String get _finishedLabel => _isPickup ? 'Picked up' : 'Delivered';

  Future<void> _load() async {
    try {
      final delivery = await _service.getById(widget.deliveryId);
      if (!mounted) return;
      setState(() {
        _delivery = delivery;
        _error = null;
      });
      if (delivery.status == 'delivered') _timer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: delivery == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildMap(delivery)),
                _buildStatusBar(delivery),
              ],
            ),
    );
  }

  Widget _buildMap(Delivery delivery) {
    final traveler = (delivery.travelerLatitude != null && delivery.travelerLongitude != null)
        ? LatLng(delivery.travelerLatitude!, delivery.travelerLongitude!)
        : null;
    final destination = (delivery.destinationLatitude != null && delivery.destinationLongitude != null)
        ? LatLng(delivery.destinationLatitude!, delivery.destinationLongitude!)
        : null;
    final center = traveler ?? destination ?? const LatLng(-28.4793, 24.6727);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: center, initialZoom: 11),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl('streets-v12'),
          userAgentPackageName: 'com.example.agricast_livestock_lite',
        ),
        MarkerLayer(markers: [
          if (destination != null)
            Marker(point: destination, width: 40, height: 40, child: const Icon(Icons.flag, color: AppColors.brandGreenDark, size: 34)),
          if (traveler != null)
            Marker(
              point: traveler,
              width: 44,
              height: 44,
              child: Icon(_isPickup ? Icons.directions_car : Icons.local_shipping, color: AppColors.danger, size: 36),
            ),
        ]),
      ],
    );
  }

  Widget _buildStatusBar(Delivery delivery) {
    final finished = delivery.status == 'delivered';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finished ? Icons.check_circle : Icons.directions_car_outlined,
                color: finished ? AppColors.brandGreen : AppColors.brandGreenDark,
              ),
              const SizedBox(width: 8),
              Text(
                finished
                    ? _finishedLabel
                    : delivery.status == 'in_transit'
                        ? '$_travelerName is on the way'
                        : 'Waiting for ${_travelerName.toLowerCase()} to start the trip',
                style: AppFonts.headingSemibold(size: 15),
              ),
            ],
          ),
          if (!finished && delivery.distanceKm != null) ...[
            const SizedBox(height: 8),
            Text(
              '${delivery.distanceKm!.toStringAsFixed(1)} km away'
              '${delivery.etaMinutes != null ? " · ETA ${delivery.etaMinutes} min" : ""}',
              style: AppFonts.body(color: AppColors.muted, size: 13),
            ),
          ],
        ],
      ),
    );
  }
}
