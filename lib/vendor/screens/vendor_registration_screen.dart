import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../services/address_resolution_service.dart';
import '../../services/location_access_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

const Color _vendorNavy = Color(0xFF03024C);
const Color _vendorBlue = Color(0xFF0D2E91);
const Color _vendorMint = Color(0xFFB7FFD4);
const Color _vendorSoftText = Color(0xFFD9E4F6);

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _alternatePhoneController =
      TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _formattedAddressController =
      TextEditingController();

  double? _businessLocationLatitude;
  double? _businessLocationLongitude;
  String? _selectedGender;
  final List<String> _selectedCategories = [];
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  bool _isLocating = false;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _categoryOptions = [
    'Supermarkets',
    'Boutiques',
    'Phone Accessories',
    'Health and Pharmacies',
    'Electronics',
    'Fashion',
    'Food & Beverages',
    'Services',
    'Automotive',
    'Books & Stationery',
    'Home & Kitchen',
    'Sports & Outdoors',
    'Toys & Games',
    'Pet Supplies',
    'Art & Crafts',
    'Jewelry',
    'Beauty & Personal Care',
    'Baby Products',
    'Industrial & Scientific',
    'Musical Instruments',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _alternatePhoneController.dispose();
    _businessNameController.dispose();
    _formattedAddressController.dispose();
    super.dispose();
  }

  Future<void> _getRealBusinessLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      final locationAccess = await LocationAccessService.ensureAccess();
      if (!locationAccess.granted) {
        setState(() {
          _errorMessage = locationAccess.message;
        });
        if (mounted) {
          await LocationAccessService.presentIssue(context, locationAccess);
        }
        return;
      }

      await LocationAccessService.requestPreciseLocationIfNeeded();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationAccessService.currentLocationSettings(),
      );

      final resolvedAddress =
          await AddressResolutionService.resolveFromCoordinates(
            position.latitude,
            position.longitude,
          );

      setState(() {
        _businessLocationLatitude = position.latitude;
        _businessLocationLongitude = position.longitude;
        _formattedAddressController.text = resolvedAddress.formattedAddress;
      });
      _showSnack('Business location captured successfully.');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
      debugPrint('Location error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _submitVendorRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      setState(() {
        _errorMessage = 'You must accept the Vendor Agreement.';
      });
      return;
    }

    if (_selectedCategories.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one business category.';
      });
      return;
    }

    if (_businessLocationLatitude == null ||
        _businessLocationLongitude == null ||
        _formattedAddressController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide your business location.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Authentication token not found. Please log in again.';
        });
      }
      return;
    }

    final requestBody = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'alternatePhoneNumber': _alternatePhoneController.text.trim(),
      'gender': _selectedGender,
      'businessName': _businessNameController.text.trim(),
      'businessCategories': _selectedCategories,
      'termsAccepted': _termsAccepted,
      'businessLocation': {
        'latitude': _businessLocationLatitude,
        'longitude': _businessLocationLongitude,
        'formattedAddress': _formattedAddressController.text.trim(),
      },
    };

    try {
      final url = Uri.parse('$baseUrl/api/vendor/request');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message =
            responseData['message']?.toString() ??
            'Vendor request submitted successfully!';
        setState(() {
          _successMessage = message;
        });
        _showSnack(message);
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage =
              responseData['message']?.toString() ??
              'Failed to submit vendor request.';
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'An error occurred: $e. Please ensure the backend is available.';
      });
      debugPrint('Vendor request network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showTermsAndConditions() {
    final todayDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final agreement =
        '''
VENDOR AGREEMENT

This Vendor Agreement is made on $todayDate.

BETWEEN:
NAIJAGO APP LTD with RC No: 8704653 situated at Efab Queens Estate, Gwarinpa, Abuja.

AND:
[Vendor Name / RC No. will be captured from form data] situated at [Vendor Location will be captured from form data] ("Vendor").

BACKGROUND

a. NaijaGo operates a technology platform consisting of a website and mobile application which facilitates the marketing and sale of products and services from vendors to customers.
b. The Vendor is engaged in the business of selling products and/or services and wishes to utilize the Platform to market and sell its products and services.
c. The Parties now wish to set forth the terms and conditions under which the Vendor shall utilize the Platform.

IT IS HEREBY AGREED AS FOLLOWS:

1. DEFINITIONS
a. "Bimp Service" means the feature on the Platform that allows Customers to request and receive real-time products and services employed by the Vendor.
b. "Customer" means any end-user who places an Order via the Platform.
c. "Order" means a request for Products or Services placed by a Customer through the Platform.
d. "Products" means the goods offered for sale by the Vendor on the Platform.
e. "Services" means the Bimp Service and any other services offered by the Vendor.

2. APPOINTMENT AND LISTING
a. NaijaGo hereby grants the Vendor a non-exclusive, non-transferable right to display, market, and sell its Products and Services on the Platform during the term of this Agreement.
b. The Vendor grants NaijaGo the right to use its trademarks, logos, and product images for the purpose of marketing and promotion on the Platform.

3. VENDOR OBLIGATIONS AND WARRANTIES
The Vendor warrants that:
a. It holds all necessary licenses, permits, and approvals, including for pharmacists a valid PCN license, to sell its Products and provide its Services in Nigeria.
b. All Products are genuine, safe, not expired, and conform to all applicable descriptions and quality standards.
c. It will respond to a Bimp Service notification within sixty (60) seconds of the alert and provide professional, diligent, and compliant consultancy services.
d. It will process and prepare Orders for dispatch within the agreed Service Level Agreement provided by NaijaGo.
e. It is solely responsible for the accuracy, quality, and legality of the Products and Services it lists.

4. FINANCIAL TERMS
a. Commission: NaijaGo will charge a commission of 15% of the Gross Sale Price of each Order fulfilled.
b. Payment to Vendor: NaijaGo shall remit payment to the Vendor for completed Orders, less the commission, immediately after successful delivery to the Customer.
c. Taxes: Each party is responsible for its own taxes arising from this Agreement.

5. DATA PROTECTION AND INTELLECTUAL PROPERTY
a. Both parties agree to comply with the Nigeria Data Protection Act (NDPA), 2023. The Vendor shall treat all Customer data as confidential.
b. All intellectual property rights in the Platform, including the Bimp technology and feature, remain the sole and exclusive property of NaijaGo.

6. LIMITATION OF LIABILITY AND INDEMNITY
a. NaijaGo's role is limited to providing the Platform. NaijaGo is not a party to the contract of sale and shall not be liable for the quality, safety, or legality of the Vendor's Products or Services.
b. The Vendor shall indemnify and hold NaijaGo harmless against all claims, losses, damages, and expenses arising from the Vendor's breach of this Agreement.

7. TERM AND TERMINATION
a. This Agreement shall commence on the effective date and continue for a period of one (1) year, thereafter automatically renewing.
b. Either party may terminate with thirty (30) days written notice.
c. NaijaGo may suspend the Vendor's account or terminate this Agreement immediately for breaches of the Vendor obligations or data protection clauses.

8. GOVERNING LAW AND DISPUTE RESOLUTION
a. This Agreement shall be governed by and construed in accordance with the laws of the Federal Republic of Nigeria.
b. Disputes shall be referred to a single arbitrator in accordance with the Arbitration and Conciliation Act. The seat of arbitration shall be Abuja.
''';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.borderGrey,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _vendorNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: _vendorNavy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Vendor Agreement',
                          style: TextStyle(
                            color: AppTheme.secondaryBlack,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: SelectableText(
                      agreement,
                      style: const TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontSize: 13.5,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.secondaryBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.mutedText),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppTheme.mutedText, fontSize: 14),
      hintStyle: const TextStyle(color: AppTheme.mutedText, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.dangerRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.dangerRed, width: 1.4),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_vendorNavy, _vendorBlue, AppTheme.primaryNavy],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -16,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _vendorMint.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: _vendorMint,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'NaijaGo Seller Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Bring your business to customers across Nigeria',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This is a vendor onboarding flow, separate from customer sign up. Submit your business details, verify your location, and request seller approval.',
                style: TextStyle(
                  color: _vendorSoftText,
                  fontSize: 14.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _HeroPill(
                    icon: Icons.badge_outlined,
                    label: 'Business identity',
                  ),
                  _HeroPill(
                    icon: Icons.location_on_outlined,
                    label: 'Location verification',
                  ),
                  _HeroPill(
                    icon: Icons.approval_outlined,
                    label: 'Seller review',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSection() {
    return _SectionCard(
      icon: Icons.badge_outlined,
      title: 'Account Owner',
      subtitle: 'Tell us who will manage this vendor account.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;

          final firstNameField = TextFormField(
            controller: _firstNameController,
            decoration: _inputDecoration(
              label: 'First name',
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
          );

          final lastNameField = TextFormField(
            controller: _lastNameController,
            decoration: _inputDecoration(
              label: 'Last name',
              icon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
          );

          final genderField = DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration:
                _inputDecoration(
                  label: 'Gender',
                  icon: Icons.wc_rounded,
                ).copyWith(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
            dropdownColor: Colors.white,
            items: _genderOptions.map((gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedGender = newValue;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select your gender';
              }
              return null;
            },
          );

          if (wide) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: firstNameField),
                    const SizedBox(width: 14),
                    Expanded(child: lastNameField),
                  ],
                ),
                const SizedBox(height: 14),
                genderField,
                const SizedBox(height: 14),
                TextFormField(
                  controller: _alternatePhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    label: 'Alternative phone number',
                    icon: Icons.phone_outlined,
                    hint: 'Optional contact number for buyers and support',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return null;
                    }
                    final pattern = RegExp(r'^(?:\+?234|0)[789]\d{9}$');
                    if (!pattern.hasMatch(trimmed)) {
                      return 'Enter a valid Nigerian phone number';
                    }
                    return null;
                  },
                ),
              ],
            );
          }

          return Column(
            children: [
              firstNameField,
              const SizedBox(height: 14),
              lastNameField,
              const SizedBox(height: 14),
              genderField,
              const SizedBox(height: 14),
              TextFormField(
                controller: _alternatePhoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  label: 'Alternative phone number',
                  icon: Icons.phone_outlined,
                  hint: 'Optional contact number for buyers and support',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  final pattern = RegExp(r'^(?:\+?234|0)[789]\d{9}$');
                  if (!pattern.hasMatch(trimmed)) {
                    return 'Enter a valid Nigerian phone number';
                  }
                  return null;
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBusinessSection() {
    final hasLocation =
        _businessLocationLatitude != null && _businessLocationLongitude != null;

    return _SectionCard(
      icon: Icons.store_mall_directory_outlined,
      title: 'Business Profile',
      subtitle:
          'Set the public business name customers will recognize on NaijaGo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _businessNameController,
            decoration: _inputDecoration(
              label: 'Business name',
              icon: Icons.storefront_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your business name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Business location',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use your current business location so nearby customers can discover your store accurately.',
            style: TextStyle(
              color: AppTheme.mutedText,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _formattedAddressController,
            readOnly: true,
            decoration: _inputDecoration(
              label: 'Verified address',
              icon: Icons.location_on_outlined,
              hint: 'Tap the button below to capture business location',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a business address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLocating ? null : _getRealBusinessLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(
                    _isLocating
                        ? 'Capturing location...'
                        : 'Use current location',
                  ),
                ),
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFAF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accentGreen.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verified coordinates: ${_businessLocationLatitude!.toStringAsFixed(5)}, ${_businessLocationLongitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return _SectionCard(
      icon: Icons.grid_view_rounded,
      title: 'Business Categories',
      subtitle:
          'Choose every category that matches what your business actually sells.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _selectedCategories.isEmpty
                  ? 'No categories selected yet.'
                  : '${_selectedCategories.length} category${_selectedCategories.length == 1 ? '' : 'ies'} selected.',
              style: const TextStyle(
                color: AppTheme.secondaryBlack,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categoryOptions.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.12),
                checkmarkColor: AppTheme.primaryNavy,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryNavy
                      : AppTheme.secondaryBlack,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryNavy.withValues(alpha: 0.22)
                      : AppTheme.borderGrey,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementSection() {
    return _SectionCard(
      icon: Icons.verified_user_outlined,
      title: 'Vendor Agreement',
      subtitle:
          'Review the seller terms before sending your onboarding request.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (newValue) {
                    setState(() {
                      _termsAccepted = newValue ?? false;
                    });
                  },
                  activeColor: AppTheme.primaryNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'I have read and agree to the NaijaGo Vendor Agreement, platform obligations, and seller verification requirements.',
                      style: TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showTermsAndConditions,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Read vendor agreement'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required IconData icon,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitSection() {
    final hasLocation =
        _businessLocationLatitude != null && _businessLocationLongitude != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to submit?',
            style: TextStyle(
              color: AppTheme.secondaryBlack,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Owner details, business identity, verified location, and category coverage all feed into your seller review.',
            style: TextStyle(
              color: AppTheme.mutedText,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(
                label: _selectedCategories.isEmpty
                    ? 'Categories pending'
                    : '${_selectedCategories.length} categories selected',
                isComplete: _selectedCategories.isNotEmpty,
              ),
              _SummaryChip(
                label: hasLocation ? 'Location verified' : 'Location pending',
                isComplete: hasLocation,
              ),
              _SummaryChip(
                label: _termsAccepted
                    ? 'Agreement accepted'
                    : 'Agreement pending',
                isComplete: _termsAccepted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitVendorRequest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.storefront_outlined),
              label: Text(
                _isSubmitting
                    ? 'Submitting request...'
                    : 'Request vendor approval',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _vendorNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This vendor flow is separate from customer registration and is reviewed before your store goes live.',
            style: TextStyle(
              color: AppTheme.mutedText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.secondaryBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Vendor onboarding'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 18),
                    if (_errorMessage != null)
                      _buildStatusBanner(
                        backgroundColor: AppTheme.dangerRed.withValues(
                          alpha: 0.08,
                        ),
                        borderColor: AppTheme.dangerRed.withValues(alpha: 0.18),
                        textColor: AppTheme.dangerRed,
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                      ),
                    if (_successMessage != null)
                      _buildStatusBanner(
                        backgroundColor: AppTheme.accentGreen.withValues(
                          alpha: 0.10,
                        ),
                        borderColor: AppTheme.accentGreen.withValues(
                          alpha: 0.18,
                        ),
                        textColor: AppTheme.accentGreen,
                        icon: Icons.check_circle_outline_rounded,
                        message: _successMessage!,
                      ),
                    _buildOwnerSection(),
                    const SizedBox(height: 16),
                    _buildBusinessSection(),
                    const SizedBox(height: 16),
                    _buildCategoriesSection(),
                    const SizedBox(height: 16),
                    _buildAgreementSection(),
                    const SizedBox(height: 18),
                    _buildSubmitSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _vendorNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _vendorNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _vendorMint),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final bool isComplete;

  const _SummaryChip({required this.label, required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppTheme.accentGreen : AppTheme.mutedText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isComplete ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle_outline : Icons.schedule_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
