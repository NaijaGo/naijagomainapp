// lib/screens/Main/add_edit_address_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart'; // Import for reverse geocoding
import '../../constants.dart'; // Import constants for colors
import '../../widgets/tech_glow_background.dart';
// Import the Address model

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = Color(
  0xFF000080,
); // Deep Navy Blue - primary for backgrounds, cards
const Color greenYellow = Color(
  0xFFADFF2F,
); // Green Yellow - accent for important text, buttons
const Color whiteBackground = Colors
    .white; // Explicitly defining white for main backgrounds, text on navy

class AddEditAddressScreen extends StatefulWidget {
  final dynamic address;
  final int? addressIndex;
  final double? initialLatitude; // New: Latitude from geolocation
  final double? initialLongitude; // New: Longitude from geolocation

  const AddEditAddressScreen({
    super.key,
    this.address,
    this.addressIndex,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  bool _isDefault = false;
  bool _isLoading = false; // Add a loading state for geocoding

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _postalCodeController = TextEditingController();
    _countryController = TextEditingController();
    _loadInitialData();
  }

  void _loadInitialData() async {
    // If editing an existing address
    if (widget.address != null) {
      _addressController.text = widget.address['address'] ?? '';
      _cityController.text = widget.address['city'] ?? '';
      _postalCodeController.text = widget.address['postalCode'] ?? '';
      _countryController.text = widget.address['country'] ?? '';
      _isDefault = widget.address['isDefault'] ?? false;
    }
    // If adding a new address from geolocation
    else if (widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          _addressController.text =
              '${placemark.street ?? ''}, ${placemark.subLocality ?? ''}';
          _cityController.text = placemark.locality ?? '';
          _postalCodeController.text = placemark.postalCode ?? '';
          _countryController.text = placemark.country ?? '';
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get address details from location: $e'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Authentication token missing. Please log in again.',
              ),
            ),
          );
        }
        return;
      }

      final addressData = {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'country': _countryController.text.trim(),
        'isDefault': _isDefault,
      };

      final isEditing = widget.address != null;
      final Uri url = isEditing
          ? Uri.parse('$baseUrl/api/auth/addresses/${widget.addressIndex}')
          : Uri.parse('$baseUrl/api/auth/addresses');
      final int successCode = isEditing ? 200 : 201;

      try {
        final response = isEditing
            ? await http.put(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode(addressData),
              )
            : await http.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode(addressData),
              );

        if (response.statusCode == successCode) {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          final error = jsonDecode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error['message'] ?? 'Failed to save address'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving address: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;

    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Address' : 'Add New Address',
            style: const TextStyle(color: whiteBackground),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: whiteBackground),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: greenYellow))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: whiteBackground.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: whiteBackground.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Address',
                            labelStyle: const TextStyle(color: deepNavyBlue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: greenYellow,
                                width: 2.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: deepNavyBlue.withValues(alpha: 0.5),
                              ),
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              color: deepNavyBlue,
                            ),
                          ),
                          cursorColor: deepNavyBlue,
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter an address' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: 'City',
                            labelStyle: const TextStyle(color: deepNavyBlue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: greenYellow,
                                width: 2.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: deepNavyBlue.withValues(alpha: 0.5),
                              ),
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.location_city_outlined,
                              color: deepNavyBlue,
                            ),
                          ),
                          cursorColor: deepNavyBlue,
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter a city' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _postalCodeController,
                          decoration: InputDecoration(
                            labelText: 'Postal Code',
                            labelStyle: const TextStyle(color: deepNavyBlue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: greenYellow,
                                width: 2.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: deepNavyBlue.withValues(alpha: 0.5),
                              ),
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.local_post_office_outlined,
                              color: deepNavyBlue,
                            ),
                          ),
                          cursorColor: deepNavyBlue,
                          validator: (value) => value!.isEmpty
                              ? 'Please enter postal code'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _countryController,
                          decoration: InputDecoration(
                            labelText: 'Country',
                            labelStyle: const TextStyle(color: deepNavyBlue),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: greenYellow,
                                width: 2.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: deepNavyBlue.withValues(alpha: 0.5),
                              ),
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.flag_outlined,
                              color: deepNavyBlue,
                            ),
                          ),
                          cursorColor: deepNavyBlue,
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter a country' : null,
                        ),
                        const SizedBox(height: 20),
                        CheckboxListTile(
                          title: const Text(
                            'Set as default address',
                            style: TextStyle(color: deepNavyBlue),
                          ),
                          value: _isDefault,
                          onChanged: (bool? value) {
                            setState(() {
                              _isDefault = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: deepNavyBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              isEditing ? 'Update Address' : 'Add Address',
                              style: const TextStyle(
                                color: whiteBackground,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
