import '../../models/delivery_address_details.dart';
// lib/screens/Main/add_edit_address_screen.dart

import 'package:flutter/material.dart';

import 'dart:async';

import '../../widgets/visible_back_button.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../../constants.dart'; // Import constants for colors
import '../../models/address.dart';
import '../../services/address_resolution_service.dart';
import '../../services/address_autocomplete_service.dart';
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
  final Address? address;
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
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _stateController = TextEditingController();
  int _addressRevision = 0;

  late TextEditingController _addressController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  final GlobalKey _addressFieldKey = GlobalKey();
  final FocusNode _addressFocusNode = FocusNode();
  bool _isDefault = false;
  bool _isLoading = false; // Add a loading state for geocoding
  double? _latitude;
  double? _longitude;
  double? _searchBiasLatitude;
  double? _searchBiasLongitude;
  final AddressAutocompleteService _autocompleteService =
      AddressAutocompleteService();
  Timer? _searchDebounce;
  final ScrollController _suggestionsScrollController = ScrollController();
  List<AddressSuggestion> _suggestions = const [];
  bool _isSearchingAddress = false;
  String? _searchMessage;

  void _onAddressChanged(String value) {
    _searchBiasLatitude ??= _latitude;
    _searchBiasLongitude ??= _longitude;
    _addressRevision++;
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _isSearchingAddress = false;
        _searchMessage = null;
      });
      return;
    }
    final cached = _autocompleteService.cachedSuggestions(query);
    final shouldSearchImmediately =
        cached.isEmpty && !_isSearchingAddress && _suggestions.isEmpty;
    setState(() {
      _suggestions = cached;
      _isSearchingAddress = true;
      _searchMessage = null;
    });
    if (shouldSearchImmediately) {
      _searchAddresses(query);
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 120), () {
        _searchAddresses(query);
      });
    }
  }

  void _ensureAddressFieldVisible() {
    if (!_addressFocusNode.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      final context = _addressFieldKey.currentContext;
      if (mounted && context != null && context.mounted) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.12,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _invalidateCoordinates(String _) {
    _addressRevision++;
    _searchDebounce?.cancel();
    setState(() {
      _suggestions = const [];
      _isSearchingAddress = false;
      _searchMessage = null;
    });
  }

  Future<void> _searchAddresses(String query) async {
    if (!mounted) return;
    final revision = _addressRevision;
    setState(() {
      _isSearchingAddress = true;
      _searchMessage = null;
    });
    try {
      final results = await _autocompleteService.search(
        query,
        latitude: _searchBiasLatitude,
        longitude: _searchBiasLongitude,
      );
      if (!mounted ||
          revision != _addressRevision ||
          _addressController.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = results;
        _searchMessage = results.isEmpty ? 'No matching address found.' : null;
      });
    } catch (_) {
      if (!mounted ||
          revision != _addressRevision ||
          _addressController.text.trim() != query)
        return;
      setState(() {
        _suggestions = const [];
        _searchMessage =
            'Address suggestions are unavailable. You can still enter the address manually.';
      });
    } finally {
      if (mounted &&
          revision == _addressRevision &&
          _addressController.text.trim() == query) {
        setState(() => _isSearchingAddress = false);
      }
    }
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    if (!suggestion.hasValidCoordinates) return;
    _searchDebounce?.cancel();
    setState(() {
      _addressController.text = suggestion.address;
      _cityController.text = suggestion.city;
      _postalCodeController.text = suggestion.postalCode;
      _countryController.text = suggestion.country;
      _addressRevision++;
      _streetController.text = suggestion.street;
      _areaController.text = suggestion.area;
      _landmarkController.text = suggestion.landmark;
      _stateController.text = suggestion.state;
      _latitude = suggestion.latitude;
      _longitude = suggestion.longitude;
      _searchBiasLatitude = suggestion.latitude;
      _searchBiasLongitude = suggestion.longitude;
      _suggestions = const [];
      _isSearchingAddress = false;
      _searchMessage = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _cityController = TextEditingController();
    _postalCodeController = TextEditingController();
    _countryController = TextEditingController();
    _addressFocusNode.addListener(_ensureAddressFieldVisible);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final initialRevision = _addressRevision;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || initialRevision != _addressRevision) return;
    final fallbackPhoneNumber = prefs.getString('phoneNumber') ?? '';

    // If editing an existing address
    final existingAddress = widget.address;
    if (existingAddress != null) {
      _addressController.text = existingAddress.addressLine;
      _phoneNumberController.text = existingAddress.phoneNumber;
      _cityController.text = existingAddress.city;
      _postalCodeController.text = existingAddress.postalCode;
      _countryController.text = existingAddress.country;
      _streetController.text = existingAddress.street;
      _areaController.text = existingAddress.area;
      _landmarkController.text = existingAddress.landmark;
      _stateController.text = existingAddress.state;
      _isDefault = existingAddress.isDefault;
      _latitude = existingAddress.latitude;
      _longitude = existingAddress.longitude;
      _searchBiasLatitude = existingAddress.latitude;
      _searchBiasLongitude = existingAddress.longitude;
      return;
    }

    if (fallbackPhoneNumber.isNotEmpty) {
      _phoneNumberController.text = fallbackPhoneNumber;
    }

    // If adding a new address from geolocation
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
      _searchBiasLatitude = widget.initialLatitude;
      _searchBiasLongitude = widget.initialLongitude;
      setState(() {
        _isLoading = true;
      });
      final revision = _addressRevision;
      try {
        final resolvedAddress =
            await AddressResolutionService.resolveFromCoordinates(
              widget.initialLatitude!,
              widget.initialLongitude!,
            );

        if (!mounted || revision != _addressRevision) return;
        _streetController.text = resolvedAddress.street;
        _areaController.text = resolvedAddress.area;
        _landmarkController.text = resolvedAddress.landmark;
        _stateController.text = resolvedAddress.state;
        _addressController.text = resolvedAddress.addressLine;
        _cityController.text = resolvedAddress.city;
        _postalCodeController.text = resolvedAddress.postalCode;
        _countryController.text = resolvedAddress.country;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Your location is selected. Please complete the address details.',
              ),
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
    _searchDebounce?.cancel();
    _suggestionsScrollController.dispose();
    _addressFocusNode.dispose();
    _addressController.dispose();
    _phoneNumberController.dispose();
    for (final controller in [
      _streetController,
      _areaController,
      _landmarkController,
      _stateController,
    ]) {
      controller.dispose();
    }
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      final revision = _addressRevision;
      if (_latitude == null || _longitude == null) {
        setState(() => _isLoading = true);
        try {
          final query = [
            _addressController.text.trim(),
            _cityController.text.trim(),
            _postalCodeController.text.trim(),
            _countryController.text.trim(),
          ].where((part) => part.isNotEmpty).join(', ');
          final locations = await locationFromAddress(
            query,
          ).timeout(const Duration(seconds: 10));
          if (!mounted || revision != _addressRevision) return;
          if (locations.isNotEmpty &&
              validDeliveryCoordinates(
                locations.first.latitude,
                locations.first.longitude,
              )) {
            _latitude = locations.first.latitude;
            _longitude = locations.first.longitude;
          }
        } catch (_) {
          // The user receives one concise, actionable message below.
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }

      if (!mounted || revision != _addressRevision) return;
      if (!validDeliveryCoordinates(_latitude, _longitude)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'We could not locate that address. Check it or use your current location.',
              ),
            ),
          );
        }
        return;
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted || revision != _addressRevision) return;
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

      if (!validDeliveryCoordinates(_latitude, _longitude)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid delivery location.'),
          ),
        );
        return;
      }
      final addressData = {
        'street': _streetController.text.trim(),
        'area': _areaController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'state': _stateController.text.trim(),
        'address': _addressController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'country': _countryController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
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
          leading: const VisibleBackButton(),
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
                          key: _addressFieldKey,
                          controller: _addressController,
                          focusNode: _addressFocusNode,
                          onChanged: _onAddressChanged,
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
                        if (_isSearchingAddress)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 224),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: deepNavyBlue.withValues(alpha: 0.2),
                              ),
                            ),
                            child: RawScrollbar(
                              controller: _suggestionsScrollController,
                              thumbVisibility: true,
                              thumbColor: const Color(0xFFCBD5E1),
                              radius: const Radius.circular(8),
                              thickness: 3,
                              child: ListView.separated(
                                controller: _suggestionsScrollController,
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final suggestion = _suggestions[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.location_on_outlined,
                                      color: deepNavyBlue,
                                    ),
                                    title: Text(
                                      suggestion.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _selectSuggestion(suggestion),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (_searchMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _searchMessage!,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _phoneNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Delivery Phone Number',
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
                              Icons.phone_outlined,
                              color: deepNavyBlue,
                            ),
                          ),
                          cursorColor: deepNavyBlue,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return null;
                            }
                            final pattern = RegExp(r'^(?:\+?234|0)[789]\d{9}$');
                            return pattern.hasMatch(trimmed)
                                ? null
                                : 'Enter a valid Nigerian phone number';
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _cityController,
                          onChanged: _invalidateCoordinates,
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
                          onChanged: _invalidateCoordinates,
                          decoration: InputDecoration(
                            labelText: 'Postal Code (optional)',
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
                          validator: (_) => null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _countryController,
                          onChanged: _invalidateCoordinates,
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
                        for (final entry
                            in <MapEntry<String, TextEditingController>>[
                              MapEntry('Street (optional)', _streetController),
                              MapEntry('Area (optional)', _areaController),
                              MapEntry(
                                'State (where available)',
                                _stateController,
                              ),
                              MapEntry(
                                'Landmark / instructions (optional)',
                                _landmarkController,
                              ),
                            ]) ...[
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: entry.value,
                            decoration: InputDecoration(labelText: entry.key),
                            onChanged: _invalidateCoordinates,
                          ),
                        ],
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
