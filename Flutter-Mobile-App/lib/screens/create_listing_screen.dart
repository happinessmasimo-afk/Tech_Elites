import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';
import '../services/listing_service.dart';
import '../services/upload_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'location_picker_screen.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _species = TextEditingController();
  final _breed = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _ageMonths = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  String _sex = 'mixed';
  String _priceUnit = 'per_head';

  final ImagePicker _picker = ImagePicker();
  // As many photos as the farmer wants to pick — no cap on count here;
  // each is capped at 8MB server-side (see UploadsController).
  final List<XFile> _photos = [];
  LatLng? _pickedLocation;

  bool _loading = false;
  String? _error;
  String? _statusMessage;

  Future<void> _pickPhotos() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) {
        setState(() => _photos.addAll(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open photo picker: $e')));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = _photos.isEmpty ? null : 'Uploading photos...';
    });

    try {
      // Upload every picked photo first, one at a time, collecting the
      // public URLs Supabase Storage hands back for each.
      final uploadService = UploadService();
      final photoUrls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        setState(() => _statusMessage = 'Uploading photo ${i + 1} of ${_photos.length}...');
        final url = await uploadService.uploadListingPhoto(_photos[i].path);
        photoUrls.add(url);
      }

      setState(() => _statusMessage = 'Publishing listing...');

      await ListingService().createListing(
        title: _title.text.trim(),
        species: _species.text.trim(),
        breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
        sex: _sex,
        quantity: int.tryParse(_quantity.text) ?? 1,
        ageMonths: int.tryParse(_ageMonths.text),
        askingPrice: double.tryParse(_price.text) ?? 0,
        priceUnit: _priceUnit,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        photoUrls: photoUrls,
        latitude: _pickedLocation?.latitude,
        longitude: _pickedLocation?.longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _loading = false;
        _statusMessage = null;
        _error = 'Could not create listing: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New listing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Photos', style: AppFonts.bodyMedium(color: AppColors.muted, size: 13)),
                const SizedBox(height: 8),
                _buildPhotoPicker(),
                const SizedBox(height: 18),
                AppTextField(controller: _title, label: 'Title (e.g. "6 Boer goats")', validator: (v) => v!.isEmpty ? 'Required' : null),
                AppTextField(controller: _species, label: 'Species (e.g. Cattle, Goat, Sheep)', validator: (v) => v!.isEmpty ? 'Required' : null),
                AppTextField(controller: _breed, label: 'Breed (optional)'),
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                  ],
                  onChanged: (v) => setState(() => _sex = v ?? 'mixed'),
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _quantity, label: 'Quantity', keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
                AppTextField(controller: _ageMonths, label: 'Age in months (optional)', keyboardType: TextInputType.number),
                AppTextField(controller: _price, label: 'Asking price', keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
                DropdownButtonFormField<String>(
                  value: _priceUnit,
                  decoration: const InputDecoration(labelText: 'Price unit'),
                  items: const [
                    DropdownMenuItem(value: 'per_head', child: Text('Per head')),
                    DropdownMenuItem(value: 'per_kg', child: Text('Per kg')),
                  ],
                  onChanged: (v) => setState(() => _priceUnit = v ?? 'per_head'),
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _location, label: 'Location (optional)'),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          final picked = await Navigator.of(context).push<LatLng>(
                            MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _pickedLocation)),
                          );
                          if (picked != null) setState(() => _pickedLocation = picked);
                        },
                  icon: Icon(_pickedLocation != null ? Icons.check_circle : Icons.map_outlined),
                  label: Text(_pickedLocation != null ? 'Location pinned on map' : 'Pin exact location on map (optional)'),
                ),
                const SizedBox(height: 10),
                AppTextField(controller: _description, label: 'Description (optional)'),
                if (_error != null) ...[
                  Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
                  const SizedBox(height: 8),
                ],
                if (_statusMessage != null) ...[
                  Text(_statusMessage!, style: AppFonts.bodyMedium(color: AppColors.brandGreenDark, size: 13)),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(label: 'Publish listing', onPressed: _submit, loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_photos[i].path), width: 92, height: 92, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _loading ? null : () => _removePhoto(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _loading ? null : _pickPhotos,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.brandGreenLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: AppColors.brandGreenDark),
            ),
          ),
        ],
      ),
    );
  }
}
