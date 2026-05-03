import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../services/address_resolution_service.dart';
import '../../services/location_access_service.dart';

class VendorBusinessProfileScreen extends StatefulWidget {
  const VendorBusinessProfileScreen({super.key});

  @override
  State<VendorBusinessProfileScreen> createState() =>
      _VendorBusinessProfileScreenState();
}

class _VendorBusinessProfileScreenState
    extends State<VendorBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _deliveryRadiusController = TextEditingController(text: '15');
  final _prepTimeController = TextEditingController(text: '30');
  final _closureReasonController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUsingLocation = false;
  bool _isTemporarilyClosed = false;
  String? _errorMessage;
  List<_OperatingHour> _operatingHours = _OperatingHour.defaults();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _logoUrlController.dispose();
    _whatsappController.dispose();
    _supportPhoneController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _deliveryRadiusController.dispose();
    _prepTimeController.dispose();
    _closureReasonController.dispose();
    super.dispose();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      };

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = await _token();
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication token not found. Please log in again.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/vendor/profile'),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        setState(() {
          _errorMessage =
              body['message']?.toString() ?? 'Failed to load store profile.';
        });
        return;
      }

      final location = body['businessLocation'] as Map<String, dynamic>?;
      final hours = body['operatingHours'] as List?;

      setState(() {
        _businessNameController.text = body['businessName']?.toString() ?? '';
        _logoUrlController.text = body['businessLogoUrl']?.toString() ?? '';
        _whatsappController.text =
            body['businessWhatsAppNumber']?.toString() ?? '';
        _supportPhoneController.text =
            body['businessSupportPhone']?.toString() ?? '';
        _addressController.text =
            location?['formattedAddress']?.toString() ?? '';
        _latitudeController.text = location?['latitude']?.toString() ?? '';
        _longitudeController.text = location?['longitude']?.toString() ?? '';
        _deliveryRadiusController.text =
            (body['deliveryRadiusKm'] ?? 15).toString();
        _prepTimeController.text = (body['prepTimeMinutes'] ?? 30).toString();
        _isTemporarilyClosed = body['isTemporarilyClosed'] == true;
        _closureReasonController.text =
            body['temporaryClosureReason']?.toString() ?? '';
        _operatingHours = hours == null
            ? _OperatingHour.defaults()
            : hours
                .whereType<Map>()
                .map((item) =>
                    _OperatingHour.fromJson(Map<String, dynamic>.from(item)))
                .toList();
        if (_operatingHours.length != 7) {
          _operatingHours = _OperatingHour.defaults();
        }
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Unable to load store profile: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isUsingLocation = true);
    try {
      final access = await LocationAccessService.ensureAccess();
      if (!access.granted) {
        if (mounted) {
          await LocationAccessService.presentIssue(context, access);
        }
        return;
      }

      await LocationAccessService.requestPreciseLocationIfNeeded();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationAccessService.currentLocationSettings(),
      );

      String address = 'Current store location';
      try {
        final resolved = await AddressResolutionService.resolveFromCoordinates(
          position.latitude,
          position.longitude,
        );
        address = resolved.formattedAddress;
      } catch (error) {
        debugPrint('Store reverse geocoding failed: $error');
      }

      if (!mounted) return;
      setState(() {
        _addressController.text = address;
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to get store location: $error');
    } finally {
      if (mounted) {
        setState(() => _isUsingLocation = false);
      }
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      _showSnack('Authentication token not found. Please log in again.');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/uploads/cloudinary/vendor-logo'),
      )..headers['Authorization'] = 'Bearer $token';

      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name.isNotEmpty ? image.name : 'store-logo.jpg',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 200 && body['url'] != null) {
        setState(() {
          _logoUrlController.text = body['url'].toString();
        });
        _showSnack('Logo uploaded. Save profile to publish it.');
      } else {
        _showSnack(body['message']?.toString() ?? 'Failed to upload logo.');
      }
    } catch (error) {
      _showSnack('Unable to upload logo: $error');
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = await _token();
    if (token == null || token.isEmpty) {
      _showSnack('Authentication token not found. Please log in again.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final latitude = double.tryParse(_latitudeController.text.trim());
      final longitude = double.tryParse(_longitudeController.text.trim());

      final payload = <String, dynamic>{
        'businessName': _businessNameController.text.trim(),
        'businessLogoUrl': _logoUrlController.text.trim(),
        'businessWhatsAppNumber': _whatsappController.text.trim(),
        'businessSupportPhone': _supportPhoneController.text.trim(),
        'deliveryRadiusKm':
            double.tryParse(_deliveryRadiusController.text.trim()) ?? 15,
        'prepTimeMinutes': int.tryParse(_prepTimeController.text.trim()) ?? 30,
        'isTemporarilyClosed': _isTemporarilyClosed,
        'temporaryClosureReason': _closureReasonController.text.trim(),
        'operatingHours':
            _operatingHours.map((hour) => hour.toJson()).toList(),
      };

      if (latitude != null && longitude != null) {
        payload['businessLocation'] = {
          'latitude': latitude,
          'longitude': longitude,
          'formattedAddress': _addressController.text.trim(),
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/vendor/profile'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        _showSnack('Store profile updated.');
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showSnack(body['message']?.toString() ?? 'Failed to update profile.');
      }
    } catch (error) {
      _showSnack('Unable to update store profile: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickTime({
    required _OperatingHour hour,
    required String field,
  }) async {
    final source = switch (field) {
      'open' => hour.openTime,
      'close' => hour.closeTime,
      _ => hour.lastOrderTime,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(source),
    );
    if (picked == null) return;

    setState(() {
      final value = _formatTime(picked);
      if (field == 'open') {
        hour.openTime = value;
      } else if (field == 'close') {
        hour.closeTime = value;
      } else {
        hour.lastOrderTime = value;
      }
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError(color)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSection(
                        color: color,
                        title: 'Business Details',
                        icon: Icons.storefront_rounded,
                        children: [
                          _buildLogoUploader(color),
                          _buildTextField(
                            controller: _businessNameController,
                            label: 'Business name',
                            icon: Icons.badge_outlined,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Business name is required'
                                    : null,
                          ),
                          _buildTextField(
                            controller: _logoUrlController,
                            label: 'Logo URL',
                            icon: Icons.image_outlined,
                          ),
                          _buildTextField(
                            controller: _whatsappController,
                            label: 'WhatsApp number',
                            icon: Icons.chat_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          _buildTextField(
                            controller: _supportPhoneController,
                            label: 'Support phone',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                      _buildSection(
                        color: color,
                        title: 'Location and Delivery',
                        icon: Icons.location_on_outlined,
                        children: [
                          _buildTextField(
                            controller: _addressController,
                            label: 'Store address',
                            icon: Icons.place_outlined,
                            maxLines: 2,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _latitudeController,
                                  label: 'Latitude',
                                  icon: Icons.my_location_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: _longitudeController,
                                  label: 'Longitude',
                                  icon: Icons.explore_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _isUsingLocation ? null : _useCurrentLocation,
                            icon: _isUsingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.near_me_outlined),
                            label: Text(
                              _isUsingLocation
                                  ? 'Finding location...'
                                  : 'Use current location',
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _deliveryRadiusController,
                                  label: 'Delivery radius (km)',
                                  icon: Icons.radar_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: _prepTimeController,
                                  label: 'Prep time (min)',
                                  icon: Icons.timer_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildSection(
                        color: color,
                        title: 'Operating Status',
                        icon: Icons.schedule_outlined,
                        children: [
                          SwitchListTile.adaptive(
                            value: _isTemporarilyClosed,
                            onChanged: (value) =>
                                setState(() => _isTemporarilyClosed = value),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Temporarily closed'),
                            subtitle: const Text(
                              'Use this for holidays, stock issues, or short breaks.',
                            ),
                          ),
                          if (_isTemporarilyClosed)
                            _buildTextField(
                              controller: _closureReasonController,
                              label: 'Closure reason',
                              icon: Icons.info_outline,
                              maxLines: 2,
                            ),
                          const SizedBox(height: 8),
                          ..._operatingHours.map(
                            (hour) => _buildHourRow(color, hour),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving ? 'Saving profile...' : 'Save store profile',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: color.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(ColorScheme color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 52, color: color.primary),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadProfile,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required ColorScheme color,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLogoUploader(ColorScheme color) {
    final logoUrl = _logoUrlController.text.trim();
    final hasLogo = logoUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              color: color.surface,
              child: hasLogo
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.storefront_rounded,
                        color: color.primary,
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.storefront_rounded,
                      color: color.primary,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store logo',
                  style: TextStyle(
                    color: color.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload a clear square logo for restaurant, pharmacy, or shop listings.',
                  style: TextStyle(
                    color: color.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _isUploadingLogo ? null : _pickAndUploadLogo,
                      icon: _isUploadingLogo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(
                        _isUploadingLogo ? 'Uploading...' : 'Upload logo',
                      ),
                    ),
                    if (hasLogo)
                      TextButton.icon(
                        onPressed: _isUploadingLogo
                            ? null
                            : () => setState(() {
                                  _logoUrlController.clear();
                                }),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildHourRow(ColorScheme color, _OperatingHour hour) {
    final label = '${hour.day[0].toUpperCase()}${hour.day.substring(1)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: hour.isOpen,
            onChanged: (value) => setState(() => hour.isOpen = value),
            contentPadding: EdgeInsets.zero,
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              hour.isOpen
                  ? '${hour.openTime} - ${hour.closeTime}, last order ${hour.lastOrderTime}'
                  : 'Closed',
            ),
          ),
          if (hour.isOpen)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeButton('Open ${hour.openTime}', () {
                  _pickTime(hour: hour, field: 'open');
                }),
                _buildTimeButton('Close ${hour.closeTime}', () {
                  _pickTime(hour: hour, field: 'close');
                }),
                _buildTimeButton('Last ${hour.lastOrderTime}', () {
                  _pickTime(hour: hour, field: 'last');
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.access_time_rounded, size: 16),
      label: Text(label),
    );
  }
}

class _OperatingHour {
  _OperatingHour({
    required this.day,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
    required this.lastOrderTime,
  });

  final String day;
  bool isOpen;
  String openTime;
  String closeTime;
  String lastOrderTime;

  factory _OperatingHour.fromJson(Map<String, dynamic> json) {
    return _OperatingHour(
      day: json['day']?.toString() ?? 'monday',
      isOpen: json['isOpen'] != false,
      openTime: json['openTime']?.toString() ?? '09:00',
      closeTime: json['closeTime']?.toString() ?? '19:00',
      lastOrderTime: json['lastOrderTime']?.toString() ?? '18:30',
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'isOpen': isOpen,
        'openTime': openTime,
        'closeTime': closeTime,
        'lastOrderTime': lastOrderTime,
      };

  static List<_OperatingHour> defaults() {
    return const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ].map((day) {
      return _OperatingHour(
        day: day,
        isOpen: true,
        openTime: '09:00',
        closeTime: '19:00',
        lastOrderTime: '18:30',
      );
    }).toList();
  }
}
