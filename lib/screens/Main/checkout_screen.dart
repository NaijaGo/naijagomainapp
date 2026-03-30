import 'dart:async'; // Added for timeouts
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../models/address.dart';
import '../../providers/cart_provider.dart';
import '../../services/location_access_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

// =========================================================================
// Backend-driven Order Summary Models
// =========================================================================

class ShipmentSummary {
  final String vendorName;
  final double subtotal;
  final double shippingPrice;
  final double platformFee;
  final List<Map<String, dynamic>> items;
  final String vendorId;
  final double vendorLatitude;
  final double vendorLongitude;

  ShipmentSummary({
    required this.vendorName,
    required this.subtotal,
    required this.shippingPrice,
    required this.platformFee,
    required this.items,
    required this.vendorId,
    required this.vendorLatitude,
    required this.vendorLongitude,
  });

  factory ShipmentSummary.fromJson(Map<String, dynamic> json) {
    return ShipmentSummary(
      vendorName: json['vendorName'] as String? ?? 'Unknown Vendor',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      shippingPrice: (json['shippingPrice'] as num?)?.toDouble() ?? 0.0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0.0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      vendorId: json['vendorId'] as String? ?? '',
      vendorLatitude:
          (json['vendorLocation']?['latitude'] as num?)?.toDouble() ?? 0.0,
      vendorLongitude:
          (json['vendorLocation']?['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorName': vendorName,
      'subtotal': subtotal,
      'shippingPrice': shippingPrice,
      'platformFee': platformFee,
      'items': items,
      'vendor': vendorId,
      'vendorLocation': {
        'latitude': vendorLatitude,
        'longitude': vendorLongitude,
      },
    };
  }
}

class FullOrderSummary {
  final double totalSubtotal;
  final double totalShippingPrice;
  final double totalPlatformFees;
  final double taxPrice;
  final double totalPrice;
  final List<ShipmentSummary> shipmentSummaries;

  FullOrderSummary({
    required this.totalSubtotal,
    required this.totalShippingPrice,
    required this.totalPlatformFees,
    required this.taxPrice,
    required this.totalPrice,
    required this.shipmentSummaries,
  });

  factory FullOrderSummary.fromJson(Map<String, dynamic> json) {
    return FullOrderSummary(
      totalSubtotal: (json['totalSubtotal'] as num?)?.toDouble() ?? 0.0,
      totalShippingPrice:
          (json['totalShippingPrice'] as num?)?.toDouble() ?? 0.0,
      totalPlatformFees: (json['totalPlatformFees'] as num?)?.toDouble() ?? 0.0,
      taxPrice: (json['taxPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      shipmentSummaries:
          (json['shipmentSummaries'] as List<dynamic>?)
              ?.map((e) => ShipmentSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// =========================================================================
// CheckoutScreen State
// =========================================================================

class CheckoutScreen extends StatefulWidget {
  final VoidCallback onOrderSuccess;

  const CheckoutScreen({required this.onOrderSuccess, super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  bool _useSavedAddress = false;
  Address? _selectedAddress;
  List<Address> _userAddresses = [];

  bool _addressSelectedOrFetched = false;

  String? _selectedPaymentMethod = 'Card';

  double _walletBalance = 0.0;

  bool _isLoading = false;
  bool _isSummaryLoading = false;
  bool _isPlacingOrder = false; // Prevent double-tap
  bool _isProcessingPayment = false; // Track payment processing

  String? _errorMessage;
  String? _successMessage;

  double? _userLatitude;
  double? _userLongitude;

  FullOrderSummary? _fullOrderSummary;
  bool _isSummaryCalculated = false;

  // Lock to prevent concurrent location fetching
  bool _isFetchingLocation = false;
  // Lock to prevent concurrent summary fetching
  bool _isFetchingSummary = false;

  @override
  void initState() {
    super.initState();
    _fetchAddressesAndWallet();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  String _formatPriceWithCommas(double price) {
    final formatter = NumberFormat('#,##0.00', 'en_NG');
    return '₦${formatter.format(price)}';
  }

  Future<void> _fetchAddressesAndWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    if (_isLoading) return; // Prevent multiple concurrent calls

    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/auth/me'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addressesJson = data['deliveryAddresses'] as List<dynamic>? ?? [];
        final wallet = (data['userWalletBalance'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          _userAddresses = addressesJson
              .map((json) => Address.fromJson(json))
              .toList();
          _walletBalance = wallet;

          if (_userAddresses.isNotEmpty) {
            _selectedAddress = _userAddresses.firstWhere(
              (addr) => addr.isDefault == true,
              orElse: () => _userAddresses.first,
            );
            _useSavedAddress = true;
            _addressSelectedOrFetched = true;
          }
        });

        await _ensureUserLocation(shouldFetchSummary: true);
      } else {
        _showSnackBar('Failed to load profile');
      }
    } catch (e) {
      _showSnackBar('Network error loading profile');
      debugPrint('Profile fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrderSummary() async {
    if (!_addressSelectedOrFetched || _isSummaryLoading || _isFetchingSummary) {
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) {
      return;
    }

    setState(() {
      _isSummaryLoading = true;
      _isFetchingSummary = true;
      _isSummaryCalculated = false;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _showSnackBar('Authentication token not found.');
      setState(() {
        _isSummaryLoading = false;
        _isFetchingSummary = false;
      });
      return;
    }

    try {
      final orderItems = cartProvider.items.values
          .map((item) => item.toJson())
          .toList();

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/orders/summary'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'cartItems': orderItems,
              'shippingAddress': _useSavedAddress
                  ? _selectedAddress!.toJson()
                  : {
                      'address': _addressController.text.trim(),
                      'city': _cityController.text.trim(),
                      'postalCode': _postalCodeController.text.trim(),
                      'country': _countryController.text.trim(),
                    },
              'userLocation': {
                'latitude': _userLatitude,
                'longitude': _userLongitude,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = _safeJson(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _fullOrderSummary = FullOrderSummary.fromJson(responseData);
          _isSummaryCalculated = true;
        });
        debugPrint(
          '✅ Summary fetched: Total ₦${_fullOrderSummary?.totalPrice ?? 0}',
        );
      } else {
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Failed to calculate delivery fees';
        });
        debugPrint(
          'Summary fetch failed: ${response.statusCode} - $_errorMessage',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error calculating fees: $e');
      debugPrint('Summary fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSummaryLoading = false;
          _isFetchingSummary = false;
        });
      }
    }
  }

  // Future<void> _fetchCurrentLocation() async {
  //   if (_isFetchingLocation) return; // Prevent concurrent location fetching

  //   setState(() {
  //     _isFetchingLocation = true;
  //     _isLoading = true;
  //   });

  //   try {
  //     setState(() {
  //       _useSavedAddress = false;
  //       _selectedAddress = null;
  //       _addressSelectedOrFetched = false;
  //       _isSummaryCalculated = false;
  //       _fullOrderSummary = null;
  //     });

  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();
  //       if (permission == LocationPermission.denied) {
  //         _showSnackBar('Location permissions denied.');
  //         return;
  //       }
  //     }

  //     if (permission == LocationPermission.deniedForever) {
  //       _showSnackBar('Location permissions permanently denied.');
  //       return;
  //     }

  //     Position position = await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.high,
  //     ).timeout(const Duration(seconds: 15));

  //     List<Placemark> placemarks = await placemarkFromCoordinates(
  //       position.latitude,
  //       position.longitude,
  //     ).timeout(const Duration(seconds: 10));

  //     if (placemarks.isEmpty) throw Exception('No address found');

  //     final place = placemarks.first;

  //     // _addressController.text = '${place.street ?? ''}, ${place.subLocality ?? ''}';
  //     // _cityController.text = place.locality ?? '';
  //     // _postalCodeController.text = place.postalCode ?? '';
  //     // _countryController.text = place.country ?? '';

  //     // Improved address building – better handling for iOS incomplete data
  //     final addressParts = <String>[];

  //     if (place.thoroughfare?.isNotEmpty == true) {
  //       addressParts.add(place.thoroughfare!);
  //     }
  //     if (place.subThoroughfare?.isNotEmpty == true) {
  //       addressParts.add(place.subThoroughfare!);
  //     }
  //     if (place.subLocality?.isNotEmpty == true) {
  //       addressParts.add(place.subLocality!);
  //     }
  //     if (addressParts.isEmpty && place.street?.isNotEmpty == true) {
  //       addressParts.add(place.street!);
  //     }

  //     _addressController.text = addressParts.join(', ').trim();

  //     if (_addressController.text.isEmpty || _addressController.text == ',') {
  //       _addressController.text = place.locality != null
  //           ? 'Area in ${place.locality}'
  //           : 'Current Location';
  //     }

  //     _cityController.text = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '';

  //     _postalCodeController.text = place.postalCode ?? '';

  //     _countryController.text = place.country ?? place.isoCountryCode ?? 'Nigeria';

  //     // Optional: iOS-specific hint to user

  //     if (Platform.isIOS) {
  //       _showSnackBar(
  //         'Location loaded — please verify address & postal code (iOS data can be limited)',
  //         isError: false,
  //       );
  //       debugPrint('Platform is iOS');
  //     }

  //     if(Platform.isAndroid) {
  //       _showSnackBar(
  //         'Location loaded — please verify address & postal code (iOS data can be limited)',
  //         isError: false,
  //       );
  //       debugPrint('Platform is Android');
  //     }

  //     setState(() {
  //       _addressSelectedOrFetched = true;
  //       _userLatitude = position.latitude;
  //       _userLongitude = position.longitude;
  //     });

  //     _showSnackBar('Location fetched successfully! Calculating delivery fee...');
  //     await _fetchOrderSummary();
  //   } catch (e) {
  //     _showSnackBar('Failed to get current location: $e');
  //     debugPrint('Current location error: $e');
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //         _isFetchingLocation = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return; // Prevent concurrent location fetching

    setState(() {
      _isFetchingLocation = true;
      _isLoading = true;
    });

    try {
      setState(() {
        _useSavedAddress = false;
        _selectedAddress = null;
        _addressSelectedOrFetched = false;
        _isSummaryCalculated = false;
        _fullOrderSummary = null;
      });

      final locationAccess = await LocationAccessService.ensureAccess();
      if (!locationAccess.granted) {
        if (mounted) {
          await LocationAccessService.presentIssue(context, locationAccess);
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationAccessService.currentLocationSettings(),
      ).timeout(const Duration(seconds: 15));

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isEmpty) throw Exception('No address found');

      final place = placemarks.first;

      // ────────────────────────────────────────────────────────────────
      // IMPROVED ADDRESS BUILDING – replaces your old 4 lines
      final addressParts = <String>[];

      if (place.thoroughfare?.isNotEmpty == true) {
        addressParts.add(place.thoroughfare!);
      }
      if (place.subThoroughfare?.isNotEmpty == true) {
        addressParts.add(place.subThoroughfare!);
      }
      if (place.subLocality?.isNotEmpty == true) {
        addressParts.add(place.subLocality!);
      }
      if (addressParts.isEmpty && place.street?.isNotEmpty == true) {
        addressParts.add(place.street!);
      }

      _addressController.text = addressParts.join(', ').trim();

      if (_addressController.text.isEmpty || _addressController.text == ',') {
        _addressController.text = place.locality != null
            ? 'Area in ${place.locality}'
            : 'Current Location';
      }

      _cityController.text =
          place.locality ??
          place.subAdministrativeArea ??
          place.administrativeArea ??
          '';

      _postalCodeController.text = place.postalCode ?? '';

      _countryController.text =
          place.country ?? place.isoCountryCode ?? 'Nigeria';

      // iOS-specific hint (only show on iPhone — Android usually has good data)
      if (Platform.isIOS) {
        _showSnackBar(
          'Location loaded — please verify address & postal code (iOS data can be limited)',
          isError: false,
        );
      }

      setState(() {
        _addressSelectedOrFetched = true;
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });

      _showSnackBar(
        'Location fetched successfully! Calculating delivery fee...',
      );
      await _fetchOrderSummary();
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
      debugPrint('Current location error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _launchSupportUri(Uri uri, String failureMessage) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar(failureMessage, isError: true);
      }
    } catch (_) {
      _showSnackBar(failureMessage, isError: true);
    }
  }

  Future<void> _openWhatsAppSupport() async {
    await _launchSupportUri(
      Uri.parse(customerSupportWhatsAppUrl),
      'Unable to open WhatsApp support right now.',
    );
  }

  Future<void> _callCustomerSupport() async {
    await _launchSupportUri(
      Uri(scheme: 'tel', path: customerSupportPhoneNumber),
      'Unable to start a support call right now.',
    );
  }

  Future<bool> _ensureUserLocation({bool shouldFetchSummary = false}) async {
    if (_userLatitude != null && _userLongitude != null) {
      if (shouldFetchSummary && !_isFetchingSummary) {
        await _fetchOrderSummary();
      }
      return true;
    }

    if (_useSavedAddress && _selectedAddress != null) {
      try {
        final addressStr =
            '${_selectedAddress!.fullAddress}, ${_selectedAddress!.city}, ${_selectedAddress!.country}';
        final locations = await locationFromAddress(
          addressStr,
        ).timeout(const Duration(seconds: 10));
        if (locations.isNotEmpty) {
          setState(() {
            _userLatitude = locations.first.latitude;
            _userLongitude = locations.first.longitude;
          });
          if (shouldFetchSummary && !_isFetchingSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (e) {
        debugPrint('Saved address geocoding failed: $e');
      }
    }

    final builtAddress =
        '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_countryController.text.trim()}';
    if (builtAddress.trim().isNotEmpty) {
      try {
        final locations = await locationFromAddress(
          builtAddress,
        ).timeout(const Duration(seconds: 10));
        if (locations.isNotEmpty) {
          setState(() {
            _userLatitude = locations.first.latitude;
            _userLongitude = locations.first.longitude;
          });
          if (shouldFetchSummary && !_isFetchingSummary) {
            await _fetchOrderSummary();
          }
          return true;
        }
      } catch (e) {
        debugPrint('Manual address geocoding failed: $e');
      }
    }

    return false;
  }

  // Validate all conditions before allowing order placement
  bool _validateOrderPlacement() {
    if (_isLoading || _isPlacingOrder || _isProcessingPayment) {
      return false;
    }

    if (!_addressSelectedOrFetched) {
      _showSnackBar('Please select your address', isError: true);
      return false;
    }

    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method', isError: true);
      return false;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) {
      _showSnackBar('Your cart is empty', isError: true);
      return false;
    }

    if (!_isSummaryCalculated || _fullOrderSummary == null) {
      _showSnackBar('Please wait for delivery fee calculation', isError: true);
      return false;
    }

    // if (_selectedPaymentMethod == 'Wallet Balance' && _walletBalance < _fullOrderSummary!.totalPrice) {
    //   _showSnackBar('Insufficient wallet balance', isError: true);
    //   return false;
    // }

    // FIX: Check for 'Wallet' not 'Wallet Balance'
    if (_selectedPaymentMethod == 'Wallet' &&
        _walletBalance < _fullOrderSummary!.totalPrice) {
      _showSnackBar('Insufficient wallet balance', isError: true);
      return false;
    }

    return true;
  }

  // Future<void> _placeOrder() async {
  //   // Prevent any concurrent order placement
  //   if (!_validateOrderPlacement()) {
  //     return;
  //   }

  //   setState(() {
  //     _isPlacingOrder = true;
  //     _isProcessingPayment = true;
  //     _isLoading = true;
  //     _errorMessage = null;
  //     _successMessage = null;
  //   });

  //   try {
  //     // Ensure coordinates are available
  //     final hasCoords = await _ensureUserLocation();
  //     if (!hasCoords) {
  //       throw Exception('Failed to determine delivery coordinates');
  //     }

  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('jwt_token');
  //     if (token == null) throw Exception('Authentication token not found');

  //     final cartProvider = Provider.of<CartProvider>(context, listen: false);
  //     final orderItems = cartProvider.items.values.map((item) => item.toJson()).toList();

  //     if (orderItems.any((i) => i['vendor'] == null)) {
  //       throw Exception('Missing vendor info in cart');
  //     }

  //     final summary = _fullOrderSummary!;
  //     final totalPrice = summary.totalPrice;

  //     final requestBody = {
  //       'orderItems': orderItems,
  //       'shippingAddress': _useSavedAddress
  //           ? _selectedAddress!.toJson()
  //           : {
  //               'address': _addressController.text.trim(),
  //               'city': _cityController.text.trim(),
  //               'postalCode': _postalCodeController.text.trim(),
  //               'country': _countryController.text.trim(),
  //             },
  //       'paymentMethod': _selectedPaymentMethod,
  //       'totalShippingPrice': summary.totalShippingPrice,
  //       'totalPlatformFees': summary.totalPlatformFees,
  //       'taxPrice': summary.taxPrice,
  //       'totalPrice': totalPrice,
  //       'userLocation': {
  //         'latitude': _userLatitude,
  //         'longitude': _userLongitude,
  //       },
  //       'shipmentSummaries': summary.shipmentSummaries.map((s) => s.toJson()).toList(),
  //     };

  //     // Create the order first
  //     final createOrderUrl = Uri.parse('$baseUrl/api/orders');
  //     final createOrderResp = await http.post(
  //       createOrderUrl,
  //       headers: {
  //         'Content-Type': 'application/json; charset=UTF-8',
  //         'Authorization': 'Bearer $token',
  //       },
  //       body: jsonEncode(requestBody),
  //     );

  //     final createOrderData = _safeJson(createOrderResp.body);

  //     if (createOrderResp.statusCode != 201) {
  //       _errorMessage = createOrderData['message'] ?? 'Failed to place order';
  //       _showSnackBar(_errorMessage!, isError: true);
  //       return;
  //     }

  //     final orderId = createOrderData['_id'] as String?;
  //     if (orderId == null) throw Exception('No order ID received');

  //     // Handle payment based on selected method
  //     if (_selectedPaymentMethod == 'Wallet') {
  //       final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay/wallet');
  //       final payResp = await http.put(
  //         payUrl,
  //         headers: {
  //           'Content-Type': 'application/json; charset=UTF-8',
  //           'Authorization': 'Bearer $token',
  //         },
  //       );

  //       if (payResp.statusCode == 200) {
  //         _successMessage = 'Order placed using Wallet!';
  //         cartProvider.clearCart();
  //         await _fetchAddressesAndWallet();
  //         _showSnackBar(_successMessage!);
  //         widget.onOrderSuccess();
  //         if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  //       } else {
  //         final payData = _safeJson(payResp.body);
  //         _errorMessage = payData['message'] ?? 'Wallet payment failed';
  //         _showSnackBar(_errorMessage!, isError: true);
  //       }
  //     } else {
  //       // External payment (Flutterwave)
  //       final userEmail = prefs.getString('email') ?? 'customer@example.com';
  //       final fullName = prefs.getString('fullName') ?? 'Test User';
  //       final phone = prefs.getString('phoneNumber') ?? '08012345678';

  //       final paymentService = PaymentService();
  //       final chargeResponse = await paymentService.startFlutterwavePayment(
  //         context: context,
  //         amount: totalPrice,
  //         email: userEmail,
  //         name: fullName,
  //         phoneNumber: phone,
  //       );

  //       if (chargeResponse == null) {
  //         _errorMessage = 'Payment not initiated or cancelled';
  //         _showSnackBar(_errorMessage!, isError: true);
  //         return;
  //       }

  //       final fwStatus = (chargeResponse.status ?? '').toLowerCase();

  //       if (fwStatus == 'cancelled') {
  //         _errorMessage = 'Payment cancelled by user';
  //         _showSnackBar(_errorMessage!);
  //         return;
  //       }

  //       if (fwStatus != 'success') {
  //         // Use the fixed helper method
  //         final processorMsg = _getProcessorMessage(chargeResponse);
  //         _errorMessage = 'Payment failed: $processorMsg';
  //         _showSnackBar(_errorMessage!, isError: true);
  //         debugPrint('Flutterwave failure: $processorMsg | Full response: ${chargeResponse.toJson()}');
  //         return;
  //       }

  //       // Use txRef (preferred) or fallback to transactionId
  //       final paymentRef = chargeResponse.txRef ?? chargeResponse.transactionId;

  //       if (paymentRef == null || paymentRef.isEmpty) {
  //         _errorMessage = 'Missing transaction reference';
  //         _showSnackBar(_errorMessage!, isError: true);
  //         return;
  //       }

  //       // Confirm payment with backend
  //       final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
  //       final payResp = await http.put(
  //         payUrl,
  //         headers: {
  //           'Content-Type': 'application/json; charset=UTF-8',
  //           'Authorization': 'Bearer $token',
  //         },
  //         body: jsonEncode({
  //           'transaction_id': paymentRef,
  //           'status': chargeResponse.status,
  //           'update_time': DateTime.now().toIso8601String(),
  //           'email_address': userEmail,
  //         }),
  //       );

  //       if (payResp.statusCode == 200) {
  //         _successMessage = 'Order placed and paid!';
  //         cartProvider.clearCart();
  //         _showSnackBar(_successMessage!);
  //         widget.onOrderSuccess();
  //         if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  //       } else {
  //         final payData = _safeJson(payResp.body);
  //         _errorMessage = payData['message'] ?? 'Payment confirmation failed';
  //         _showSnackBar(_errorMessage!, isError: true);
  //         debugPrint('Backend confirmation failed: ${payResp.statusCode} - ${payResp.body}');
  //       }
  //     }
  //   } catch (e, stack) {
  //     _errorMessage = 'Error: $e';
  //     _showSnackBar('Failed to place order. Try again.', isError: true);
  //     debugPrint('Place order error: $e\n$stack');
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //         _isPlacingOrder = false;
  //         _isProcessingPayment = false;
  //       });
  //     }
  //   }
  // }

  // ... (everything above _placeOrder remains 100% unchanged)

  Future<void> _placeOrder() async {
    // Prevent any concurrent order placement
    if (!_validateOrderPlacement()) {
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _isProcessingPayment = true;
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Ensure coordinates are available
      final hasCoords = await _ensureUserLocation();
      if (!hasCoords) {
        throw Exception('Failed to determine delivery coordinates');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Authentication token not found');
      if (!mounted) return;

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final orderItems = cartProvider.items.values
          .map((item) => item.toJson())
          .toList();

      if (orderItems.any((i) => i['vendor'] == null)) {
        throw Exception('Missing vendor info in cart');
      }

      final summary = _fullOrderSummary!;
      final totalPrice = summary.totalPrice;

      final requestBody = {
        'orderItems': orderItems,
        'shippingAddress': _useSavedAddress
            ? _selectedAddress!.toJson()
            : {
                'address': _addressController.text.trim(),
                'city': _cityController.text.trim(),
                'postalCode': _postalCodeController.text.trim(),
                'country': _countryController.text.trim(),
              },
        'paymentMethod': _selectedPaymentMethod,
        'totalShippingPrice': summary.totalShippingPrice,
        'totalPlatformFees': summary.totalPlatformFees,
        'taxPrice': summary.taxPrice,
        'totalPrice': totalPrice,
        'userLocation': {
          'latitude': _userLatitude,
          'longitude': _userLongitude,
        },
        'shipmentSummaries': summary.shipmentSummaries
            .map((s) => s.toJson())
            .toList(),
      };

      // Create the order first
      final createOrderUrl = Uri.parse('$baseUrl/api/orders');
      final createOrderResp = await http.post(
        createOrderUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      final createOrderData = _safeJson(createOrderResp.body);

      if (createOrderResp.statusCode != 201) {
        _errorMessage = createOrderData['message'] ?? 'Failed to place order';
        _showSnackBar(_errorMessage!, isError: true);
        return;
      }

      final orderId = createOrderData['_id'] as String?;
      if (orderId == null) throw Exception('No order ID received');

      // Handle payment based on selected method
      if (_selectedPaymentMethod == 'Wallet') {
        final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay/wallet');
        final payResp = await http.put(
          payUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
        );

        if (payResp.statusCode == 200) {
          _successMessage = 'Order placed using Wallet!';
          cartProvider.clearCart();
          await _fetchAddressesAndWallet();
          _showSnackBar(_successMessage!);
          widget.onOrderSuccess();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          final payData = _safeJson(payResp.body);
          _errorMessage = payData['message'] ?? 'Wallet payment failed';
          _showSnackBar(_errorMessage!, isError: true);
        }
      } else {
        // External payment (Flutterwave)
        final userEmail = prefs.getString('email') ?? 'customer@example.com';
        final fullName = prefs.getString('fullName') ?? 'Test User';
        final phone = prefs.getString('phoneNumber') ?? '08012345678';

        final paymentService = PaymentService();
        if (!mounted) return;
        final chargeResponse = await paymentService.startFlutterwavePayment(
          context: context,
          amount: totalPrice,
          email: userEmail,
          name: fullName,
          phoneNumber: phone,
        );

        if (chargeResponse == null) {
          _errorMessage = 'Payment not initiated or cancelled';
          _showSnackBar(_errorMessage!, isError: true);
          return;
        }

        final txRef = chargeResponse.txRef;

        if (txRef == null || txRef.trim().isEmpty) {
          _errorMessage =
              'Missing transaction reference – likely cancelled early';
          _showSnackBar(_errorMessage!, isError: true);
          debugPrint(
            'No txRef → full ChargeResponse: ${chargeResponse.toJson()}',
          );
          return;
        }

        // Log what we actually got from Flutterwave client-side
        debugPrint(
          'Flutterwave client response → txRef: $txRef | status: ${chargeResponse.status ?? "—"} | success: ${chargeResponse.success ?? "—"} | full: ${chargeResponse.toJson()}',
        );

        // Always try to confirm with backend when we have txRef
        final paymentRef = txRef; // prefer txRef — more reliable from client

        final payUrl = Uri.parse('$baseUrl/api/orders/$orderId/pay');
        final payResp = await http.put(
          payUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'transaction_id': paymentRef,
            'status': chargeResponse.status ?? 'unknown_from_client',
            'update_time': DateTime.now().toIso8601String(),
            'email_address': userEmail,
          }),
        );

        if (payResp.statusCode == 200) {
          // ────────────────────────────────────────────────────────────────
          // PRODUCTION CHANGE: more honest / cautious message
          // ────────────────────────────────────────────────────────────────
          _successMessage =
              'Order created — payment confirmation in progress. You will be notified shortly.';
          cartProvider.clearCart();
          _showSnackBar(_successMessage!);
          widget.onOrderSuccess();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          final payData = _safeJson(payResp.body);
          _errorMessage = payData['message'] ?? 'Payment confirmation failed';
          _showSnackBar(_errorMessage!, isError: true);
          debugPrint(
            'Backend confirmation failed: ${payResp.statusCode} - ${payResp.body}',
          );
        }
      }
    } catch (e, stack) {
      _errorMessage = 'Error: $e';
      _showSnackBar('Failed to place order. Try again.', isError: true);
      debugPrint('Place order error: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlacingOrder = false;
          _isProcessingPayment = false;
        });
      }
    }
  }

  // ... (rest of the file remains 100% unchanged)

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final FullOrderSummary? currentSummary = _fullOrderSummary;

    return Scaffold(
      backgroundColor: AppTheme.softGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.secondaryBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checkout',
              style: TextStyle(
                color: AppTheme.secondaryBlack,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Confirm delivery, payment and your final total',
              style: TextStyle(
                color: AppTheme.mutedText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh summary',
            onPressed:
                (_isLoading || _isFetchingSummary || !_addressSelectedOrFetched)
                ? null
                : () => _ensureUserLocation(shouldFetchSummary: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.borderGrey.withValues(alpha: 0.7),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAddressSection(),
                  const SizedBox(height: AppSpacing.md),
                  _buildPaymentSection(),
                  const SizedBox(height: AppSpacing.md),
                  _buildSupportSection(),
                  const SizedBox(height: AppSpacing.md),
                  _buildOrderSummarySection(currentSummary, cartProvider),
                  if (cartProvider.itemCount == 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildNoticeCard(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your cart is empty',
                      message:
                          'Add products from the cart page before placing an order.',
                      accentColor: AppTheme.primaryNavy,
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildNoticeCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Something needs attention',
                      message: _errorMessage!,
                      accentColor: AppTheme.dangerRed,
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildNoticeCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Checkout updated',
                      message: _successMessage!,
                      accentColor: AppTheme.accentGreen,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildCheckoutBar(cartProvider, currentSummary),
    );
  }

  Widget _buildFullSummaryCard(
    FullOrderSummary summary,
    CartProvider cartProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppTheme.primaryNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppTheme.primaryNavy.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cartProvider.itemCount} item${cartProvider.itemCount == 1 ? '' : 's'} in this order',
                      style: const TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.shipmentSummaries.length} vendor shipment${summary.shipmentSummaries.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatPriceWithCommas(summary.totalPrice),
                style: const TextStyle(
                  color: AppTheme.primaryNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
        if (summary.shipmentSummaries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Delivery breakdown',
            style: TextStyle(
              color: AppTheme.secondaryBlack,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...summary.shipmentSummaries.map(
            (shipment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildShipmentSummaryCard(shipment),
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Divider(height: 24),
        _buildSummaryRow(
          'Items subtotal',
          _formatPriceWithCommas(summary.totalSubtotal),
        ),
        _buildSummaryRow(
          'Delivery fees',
          _formatPriceWithCommas(summary.totalShippingPrice),
        ),
        if (summary.taxPrice > 0)
          _buildSummaryRow('Tax', _formatPriceWithCommas(summary.taxPrice)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: AppTheme.primaryNavy,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _buildTotalRow(
            'Grand total',
            _formatPriceWithCommas(summary.totalPrice),
          ),
        ),
      ],
    );
  }

  Widget _buildShipmentSummaryCard(ShipmentSummary shipment) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppTheme.primaryNavy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipment.vendorName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondaryBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shipment.items.length} item${shipment.items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSummaryRow(
            'Item subtotal',
            _formatPriceWithCommas(shipment.subtotal),
          ),
          _buildSummaryRow(
            'Delivery fee',
            _formatPriceWithCommas(shipment.shippingPrice),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryBlack,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<Address?> _showAddressSelectionDialog() async {
    if (_userAddresses.isEmpty) {
      _showSnackBar('No saved addresses.');
      return null;
    }

    return showDialog<Address>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text(
          'Select delivery address',
          style: TextStyle(
            color: AppTheme.secondaryBlack,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _userAddresses.length,
            itemBuilder: (context, index) {
              final address = _userAddresses[index];
              final bool isSelected = _selectedAddress?.id == address.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Navigator.pop(context, address),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryNavy.withValues(alpha: 0.05)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryNavy
                            : AppTheme.borderGrey,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address.name.isNotEmpty
                                    ? address.name
                                    : 'Saved address',
                                style: const TextStyle(
                                  color: AppTheme.secondaryBlack,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address.fullAddress,
                                style: const TextStyle(
                                  color: AppTheme.mutedText,
                                  height: 1.45,
                                ),
                              ),
                              if (address.phoneNumber.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  address.phoneNumber,
                                  style: const TextStyle(
                                    color: AppTheme.secondaryBlack,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: isSelected
                              ? AppTheme.primaryNavy
                              : AppTheme.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery address',
            subtitle: 'Choose where this order should be sent.',
            trailing: _buildStatusChip(
              label: _addressSelectedOrFetched ? 'Ready' : 'Required',
              color: _addressSelectedOrFetched
                  ? AppTheme.accentGreen
                  : AppTheme.dangerRed,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final currentLocationButton = _buildAddressActionButton(
                title: 'Use current location',
                subtitle: 'Detect your delivery point automatically',
                icon: Icons.my_location_rounded,
                selected: !_useSavedAddress && _addressSelectedOrFetched,
                onPressed: (_isLoading || _isFetchingLocation)
                    ? null
                    : _fetchCurrentLocation,
              );

              final savedAddressButton = _buildAddressActionButton(
                title: 'Choose saved address',
                subtitle: 'Pick from the addresses already on your account',
                icon: Icons.location_on_outlined,
                selected: _useSavedAddress && _selectedAddress != null,
                onPressed: (_isLoading || _isFetchingLocation)
                    ? null
                    : () async {
                        _addressController.clear();
                        _cityController.clear();
                        _postalCodeController.clear();
                        _countryController.clear();

                        final selected = await _showAddressSelectionDialog();
                        if (selected != null && mounted) {
                          setState(() {
                            _selectedAddress = selected;
                            _useSavedAddress = true;
                            _addressSelectedOrFetched = true;
                          });
                          await _ensureUserLocation(shouldFetchSummary: true);
                        }
                      },
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: currentLocationButton,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: savedAddressButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: currentLocationButton),
                  const SizedBox(width: 12),
                  Expanded(child: savedAddressButton),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isFetchingLocation) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 14),
          ],
          _buildActiveAddressCard(),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final bool walletShortfall =
        _isSummaryCalculated &&
        _fullOrderSummary != null &&
        _walletBalance < _fullOrderSummary!.totalPrice;

    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.payments_outlined,
            title: 'Payment method',
            subtitle: 'Pick the option you want to use for this checkout.',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPaymentOptionCard(
            value: 'Card',
            title: 'Card payment',
            subtitle: 'Pay securely with your debit or credit card.',
            icon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 12),
          _buildPaymentOptionCard(
            value: 'Bank Transfer',
            title: 'Bank transfer',
            subtitle: 'Complete payment directly from your bank account.',
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 12),
          _buildPaymentOptionCard(
            value: 'Wallet',
            title: 'Wallet balance',
            subtitle:
                'Available balance: ${_formatPriceWithCommas(_walletBalance)}',
            helperText: walletShortfall
                ? 'Your wallet balance is below the current order total.'
                : 'Use your NaijaGo wallet for a faster checkout.',
            icon: Icons.account_balance_wallet_outlined,
            warning: walletShortfall,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.support_agent_rounded,
            title: 'Need help before you pay?',
            subtitle:
                'Reach customer support if you need help with delivery, payment, or checkout questions.',
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final whatsappButton = _buildSupportActionButton(
                title: 'WhatsApp support',
                subtitle: 'Chat with support directly from your phone.',
                icon: Icons.chat_bubble_outline_rounded,
                accentColor: const Color(0xFF25D366),
                onPressed: () => _openWhatsAppSupport(),
              );

              final callButton = _buildSupportActionButton(
                title: 'Call support',
                subtitle: 'Speak with support before placing this order.',
                icon: Icons.call_outlined,
                accentColor: AppTheme.primaryNavy,
                onPressed: () => _callCustomerSupport(),
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: whatsappButton),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: callButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: whatsappButton),
                  const SizedBox(width: 12),
                  Expanded(child: callButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummarySection(
    FullOrderSummary? currentSummary,
    CartProvider cartProvider,
  ) {
    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Order summary',
            subtitle: 'Review delivery fees and your final payable amount.',
            trailing: _isSummaryCalculated && currentSummary != null
                ? _buildStatusChip(
                    label: 'Updated',
                    color: AppTheme.primaryNavy,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isSummaryLoading)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.10),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Calculating delivery fees and your final total...',
                      style: TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_isSummaryCalculated && currentSummary != null)
            _buildFullSummaryCard(currentSummary, cartProvider)
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.primaryNavy,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Choose a delivery address to calculate the final amount.',
                          style: TextStyle(
                            color: AppTheme.secondaryBlack,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Items subtotal',
                    _formatPriceWithCommas(cartProvider.totalAmount),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Delivery fees and any extra charges will appear here once the address is confirmed.',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(
    CartProvider cartProvider,
    FullOrderSummary? currentSummary,
  ) {
    final bool isBusy = _isLoading || _isPlacingOrder || _isProcessingPayment;
    final bool canPlaceOrder =
        !isBusy &&
        cartProvider.itemCount > 0 &&
        _addressSelectedOrFetched &&
        _isSummaryCalculated &&
        _selectedPaymentMethod != null;

    final String helperText;
    if (cartProvider.itemCount == 0) {
      helperText = 'Add items to your cart to continue.';
    } else if (!_addressSelectedOrFetched) {
      helperText = 'Choose a delivery address to continue.';
    } else if (_isSummaryLoading) {
      helperText = 'Updating your delivery estimate...';
    } else if (!_isSummaryCalculated) {
      helperText = 'Your final total appears after delivery is calculated.';
    } else if (_selectedPaymentMethod == null) {
      helperText = 'Select a payment method to place this order.';
    } else {
      helperText = 'Everything looks good. You can place the order.';
    }

    final double total = currentSummary?.totalPrice ?? cartProvider.totalAmount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSummary == null ? 'Estimated total' : 'Total',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryBlack,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        helperText,
                        style: const TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatPriceWithCommas(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: canPlaceOrder ? _placeOrder : null,
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  isBusy ? 'Processing...' : 'Place Order',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primaryNavy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryBlack,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAddressActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: selected ? AppTheme.primaryNavy : Colors.white,
        foregroundColor: selected ? Colors.white : AppTheme.secondaryBlack,
        side: BorderSide(
          color: selected ? AppTheme.primaryNavy : AppTheme.borderGrey,
        ),
        minimumSize: const Size.fromHeight(74),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.16)
                  : AppTheme.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : AppTheme.primaryNavy,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.secondaryBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.82)
                        : AppTheme.mutedText,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.secondaryBlack,
        side: BorderSide(color: accentColor.withValues(alpha: 0.24)),
        minimumSize: const Size.fromHeight(74),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAddressCard() {
    final bool hasSavedAddress = _useSavedAddress && _selectedAddress != null;
    final bool hasLiveAddress = _joinTextParts([
      _addressController.text,
      _cityController.text,
      _countryController.text,
    ]).isNotEmpty;

    if (!hasSavedAddress && !hasLiveAddress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No delivery address selected yet',
              style: TextStyle(
                color: AppTheme.secondaryBlack,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Use your current location or choose one of your saved addresses to unlock delivery pricing.',
              style: TextStyle(
                color: AppTheme.mutedText,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final String eyebrow = hasSavedAddress
        ? (_selectedAddress!.isDefault
              ? 'Default saved address'
              : 'Saved address')
        : 'Current location';
    final String title = hasSavedAddress
        ? (_selectedAddress!.name.isNotEmpty
              ? _selectedAddress!.name
              : 'Delivery destination')
        : 'Detected from your device';
    final String primaryLine = hasSavedAddress
        ? (_selectedAddress!.addressLine.isNotEmpty
              ? _selectedAddress!.addressLine
              : _selectedAddress!.fullAddress)
        : (_addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : 'Current location selected');
    final String secondaryLine = hasSavedAddress
        ? _joinTextParts([
            _selectedAddress!.city,
            _selectedAddress!.state,
            _selectedAddress!.postalCode,
            _selectedAddress!.country,
          ])
        : _joinTextParts([
            _cityController.text,
            _postalCodeController.text,
            _countryController.text,
          ], separator: ' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasSavedAddress
                      ? Icons.location_on_outlined
                      : Icons.my_location_rounded,
                  color: AppTheme.primaryNavy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        color: AppTheme.primaryNavy,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(
                label: hasSavedAddress ? 'Saved' : 'Live',
                color: AppTheme.primaryNavy,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            primaryLine,
            style: const TextStyle(
              color: AppTheme.secondaryBlack,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (secondaryLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              secondaryLine,
              style: const TextStyle(
                color: AppTheme.mutedText,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          if (hasSavedAddress && _selectedAddress!.phoneNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _selectedAddress!.phoneNumber,
              style: const TextStyle(
                color: AppTheme.secondaryBlack,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    String? helperText,
    bool warning = false,
  }) {
    final bool selected = _selectedPaymentMethod == value;
    final bool disabled = _isLoading || _isPlacingOrder || _isProcessingPayment;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: disabled
          ? null
          : () => setState(() => _selectedPaymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryNavy.withValues(alpha: 0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? AppTheme.primaryNavy
                : warning
                ? AppTheme.dangerRed.withValues(alpha: 0.45)
                : AppTheme.borderGrey,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryNavy.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected
                    ? AppTheme.primaryNavy
                    : AppTheme.secondaryBlack,
                size: 20,
              ),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (helperText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      helperText,
                      style: TextStyle(
                        color: warning
                            ? AppTheme.dangerRed
                            : AppTheme.secondaryBlack,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppTheme.primaryNavy : AppTheme.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard({
    required IconData icon,
    required String title,
    required String message,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _joinTextParts(List<String?> values, {String separator = ', '}) {
    return values
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(separator);
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('Warning: Failed to decode JSON: $body');
      return {};
    }
  }
}
