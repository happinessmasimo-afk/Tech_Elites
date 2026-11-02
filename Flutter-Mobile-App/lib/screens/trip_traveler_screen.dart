import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/delivery.dart';
import '../services/delivery_service.dart';
import '../widgets/primary_button.dart';

/// The travelling party's screen, e-hailing style: tap Start, the other
/// side's tracking screen sees it immediately (it's already polling this
/// same delivery), then this device's real GPS streams live as they move,
/// with distance/ETA recalculated via Mapbox on every update. Works for
/// either direction — a buyer travelling to collect a pickup, or a farmer
/// travelling to deliver — the delivery's `method` decides which.
class TripTravelerScreen extends StatefulWidget {
  final String deliveryId;
  const TripTravelerScreen({super.key, required this.deliveryId});

  @override
  State<TripTravelerScreen> createState() => _TripTravelerScreenState();
}

class _TripTravelerScreenState extends State<TripTravelerScreen> {
  final _service = DeliveryService();
  StreamSubscription<Position>? _positionSub;
  Delivery? _delivery;
  String? _error;
  bool _starting = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  bool get _isPickup => _delivery?.method == 'pickup';
  String get _destinationLabel => _isPickup ? 'the farm' : 'the buyer';
  String get _startLabel => _isPickup ? 'Start pickup journey' : 'Start delivery';
  String get _finishLabel => _isPickup ? "I've arrived — mark picked up" : 'Mark as delivered';
  String get _travellingLabel => _isPickup ? "You're on your way to collect it" : "You're on your way to deliver it";

  Future<void> _load() async {
    try {
      final delivery = await _service.getById(widget.deliveryId);
      if (!mounted) return;
      setState(() => _delivery = delivery);
      if (delivery.status == 'in_transit') _beginSharingLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// The actual "Start" tap: e-hailing style — flips the trip to in_transit
  /// immediately (the other side sees this the moment their screen next
  /// polls), then location sharing kicks in right after.
  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final updated = await _service.start(widget.deliveryId);
      if (!mounted) return;
      setState(() => _delivery = updated);
      await _beginSharingLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start the trip: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _beginSharingLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is required to share your live position. Enable it in device settings.');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Turn on location services to start sharing your position.');
      return;
    }

    // distanceFilter avoids hammering the backend/Mapbox on every tiny GPS
    // jitter — an update fires only once the traveller has actually moved
    // roughly 100m.
    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100);
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen((position) async {
      try {
        final updated = await _service.updateLocation(widget.deliveryId, position.latitude, position.longitude);
        if (!mounted) return;
        setState(() => _delivery = updated);
      } catch (_) {
        // A single missed update isn't worth surfacing — the next GPS fix
        // will just try again.
      }
    });
  }

  Future<void> _markFinished() async {
    setState(() => _finishing = true);
    try {
      await _positionSub?.cancel();
      await _service.updateStatus(widget.deliveryId, 'delivered');
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _error = 'Could not update the trip: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    return Scaffold(
      appBar: AppBar(title: Text(_isPickup ? 'Pick up your order' : 'Deliver to buyer')),
      body: delivery == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildMap(delivery)),
                _buildControls(delivery),
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

  Widget _buildControls(Delivery delivery) {
    final started = delivery.status == 'in_transit';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (delivery.distanceKm != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${delivery.distanceKm!.toStringAsFixed(1)} km to $_destinationLabel'
                '${delivery.etaMinutes != null ? " · ETA ${delivery.etaMinutes} min" : ""}',
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
            ),
          if (_error != null) ...[
            Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
            const SizedBox(height: 8),
          ],
          if (!started)
            PrimaryButton(label: _startLabel, onPressed: _starting ? null : _start, loading: _starting)
          else ...[
            Text(_travellingLabel, style: AppFonts.bodyMedium(color: AppColors.brandGreen)),
            const SizedBox(height: 10),
            PrimaryButton(label: _finishLabel, onPressed: _finishing ? null : _markFinished, loading: _finishing),
          ],
        ],
      ),
    );
  }
}
