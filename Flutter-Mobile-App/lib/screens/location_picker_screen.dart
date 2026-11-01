import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../services/geocoding_service.dart';
import '../widgets/primary_button.dart';

/// Returns the picked LatLng via Navigator.pop, or null if cancelled.
/// Three ways to pick a spot: drag the map, type an address (autocomplete
/// kicks in after 3 characters), or use the device's real GPS position.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _center;
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  final _geocoding = GeocodingService();

  Timer? _debounce;
  List<GeocodeSuggestion> _suggestions = [];
  String? _searchError;
  bool _searching = false;
  bool _locating = false;
  String? _locationError;

  // Defaults to roughly the center of South Africa if the farmer hasn't
  // picked a spot before — just a sensible starting view, not a real GPS fix.
  static const _defaultCenter = LatLng(-28.4793, 24.6727);

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? _defaultCenter;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _searchError = null;
      });
      return;
    }
    // Debounce so it doesn't fire a network request on every keystroke —
    // waits for a short pause after typing before searching.
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _searching = true;
        _searchError = null;
      });
      try {
        final results = await _geocoding.search(query);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _searching = false;
          _searchError = '$e';
        });
      }
    });
  }

  void _selectSuggestion(GeocodeSuggestion suggestion) {
    setState(() {
      _center = suggestion.location;
      _suggestions = [];
      _searchController.text = suggestion.placeName;
    });
    _mapController.move(suggestion.location, 13);
    FocusScope.of(context).unfocus();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permission denied. Enable it in device settings, or type an address above.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationError = 'Turn on location services, or type an address above instead.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final here = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = here;
        _searchController.clear();
        _suggestions = [];
      });
      _mapController.move(here, 14);
    } catch (e) {
      setState(() => _locationError = 'Could not get your current location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pin the location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial != null ? 12 : 5,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) _center = position.center;
              },
              onTap: (_, __) => FocusScope.of(context).unfocus(),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl('streets-v12'),
                userAgentPackageName: 'com.example.agricast_livestock_lite',
              ),
            ],
          ),
          // Fixed center pin — the map moves under it, which is simpler
          // and far less error-prone than tracking a draggable marker.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_on, size: 44, color: AppColors.brandGreen),
              ),
            ),
          ),

          // --- Search bar + suggestions ---
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Type an address or place...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.transparent,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _suggestions = []);
                                  },
                                )
                              : null),
                    ),
                  ),
                ),
                if (_searchError != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text(_searchError!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 12)),
                  ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: AppColors.brandGreenDark),
                          title: Text(s.placeName, style: AppFonts.body(size: 13)),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // --- Use current location button ---
          Positioned(
            right: 16,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'use-current-location',
              onPressed: _locating ? null : _useCurrentLocation,
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.brandGreenDark,
              child: _locating
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_locationError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text(_locationError!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 12)),
                  ),
                PrimaryButton(
                  label: 'Use this location',
                  onPressed: () => Navigator.of(context).pop(_center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
