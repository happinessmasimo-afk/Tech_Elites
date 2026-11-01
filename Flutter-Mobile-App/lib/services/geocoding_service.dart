import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

class GeocodeSuggestion {
  final String placeName;
  final LatLng location;
  GeocodeSuggestion({required this.placeName, required this.location});
}

class GeocodingException implements Exception {
  final String message;
  GeocodingException(this.message);
  @override
  String toString() => message;
}

/// Real calls to Mapbox's Geocoding API — same public token the rest of
/// the app already uses. Called directly from the app (no backend hop
/// needed, same as fetching map tiles) since this is just a GET with a
/// public token.
class GeocodingService {
  Future<List<GeocodeSuggestion>> search(String query) async {
    if (query.trim().length < 3) return [];

    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
      '?access_token=${MapConfig.mapboxToken}&autocomplete=true&limit=5',
    );

    http.Response response;
    try {
      response = await http.get(url).timeout(const Duration(seconds: 8));
    } catch (e) {
      // Network-level failure (no internet, DNS, timeout) — surface it
      // rather than silently showing "no results", which looks identical
      // to "this place doesn't exist" and gives no way to diagnose it.
      throw GeocodingException('Could not reach Mapbox: $e');
    }

    if (response.statusCode != 200) {
      String detail = 'HTTP ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) detail = body['message'].toString();
      } catch (_) {
        // response body wasn't JSON we could read a message out of
      }
      throw GeocodingException('Mapbox search failed ($detail)');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? [];

    return features.map((f) {
      final center = f['center'] as List; // Mapbox returns [lng, lat]
      return GeocodeSuggestion(
        placeName: f['place_name'] as String,
        location: LatLng((center[1] as num).toDouble(), (center[0] as num).toDouble()),
      );
    }).toList();
  }
}
