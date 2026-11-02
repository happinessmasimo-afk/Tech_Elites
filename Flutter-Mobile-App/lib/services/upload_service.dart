import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'secure_storage.dart';
import 'api_client.dart';

/// Uploads a single image file to the backend, which forwards it to
/// Supabase Storage under the farmer's own account. Call once per photo —
/// the create-listing screen calls this in a loop for every photo picked.
class UploadService {
  Future<String> uploadListingPhoto(String filePath) async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) throw ApiException('You need to be logged in to upload photos.');

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/uploads/listing-photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Photo upload failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
      } catch (_) {
        // non-JSON error body, keep generic message
      }
      throw ApiException(message, statusCode: response.statusCode);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['url'] as String;
  }
}
