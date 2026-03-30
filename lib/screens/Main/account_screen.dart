import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Added
import '../../constants.dart';
// Import your main.dart file to access the ThemeChanger and SettingsScreen classes
// import '../../admin/screens/admin_panel_screen.dart'; // Import for Admin Panel
// Import LoginScreen
import 'my_orders_screen.dart'; // Import MyOrdersScreen
import 'saved_items_screen.dart'; // Import SavedItemsScreen
import 'delivery_addresses_screen.dart'; // Import DeliveryAddressesScreen
import 'edit_profile_screen.dart'; // Import EditProfileScreen
import 'my_wallet_screen.dart'; // Import MyWalletScreen
import 'reviews_ratings_screen.dart'; // NEW: Import ReviewsRatingsScreen
import 'dispute_list_screen.dart';
import 'faq_screen.dart';
import 'referral_screen.dart';
import 'vendor_my_products_screen.dart';
import '../../screens/vendor/orders_recived_screen.dart.dart';
import 'pharmacist_dashboard.dart'; // ✅ Import PharmacistDashboard
import '../../widgets/pharmacy_ui.dart';
import '../../widgets/tech_glow_background.dart';

// Define your color constants (consistent with vendor registration)
const Color deepNavyBlue = Color(0xFF03024C);
const Color greenYellow = Color(0xFFADFF2F);
const Color white = Colors.white;
const Color lightGray = Color(
  0xFFF5F5F5,
); // Adding a light gray for subtle backgrounds if needed

class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AccountScreen({super.key, required this.onLogout});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;

  // User Profile Data
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phoneNumber = '';
  String _profilePicUrl =
      'https://placehold.co/100x100/CCCCCC/000000?text=User'; // Default placeholder
  bool _isPharmacist = false; // ⬅️ VARIABLE DECLARED

  // Buyer Specific Data
  double _userWalletBalance = 0.0;

  // Vendor Specific Data
  bool _isVendor = false;
  String _vendorStatus = 'none';
  int _totalProducts = 0;
  int _productsSold = 0;
  int _productsUnsold = 0;
  double _vendorWalletBalance = 0.0;
  double _appWalletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _launchSupportUri(Uri uri, String failureMessage) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSupportSnackBar(failureMessage);
      }
    } catch (_) {
      if (!mounted) return;
      _showSupportSnackBar(failureMessage);
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

  void _showSupportSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUserData(); // Refresh data when app resumes
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          // Common User Data
          _firstName = responseData['firstName'] ?? '';
          _lastName = responseData['lastName'] ?? '';
          _email = responseData['email'] ?? '';
          _phoneNumber = responseData['phoneNumber'] ?? '';

          final String? fetchedProfilePicPath = responseData['profilePicUrl'];
          if (fetchedProfilePicPath != null &&
              fetchedProfilePicPath.isNotEmpty) {
            if (fetchedProfilePicPath.startsWith('http')) {
              // If it's already a full URL (e.g., S3 link), use it as is.
              _profilePicUrl = fetchedProfilePicPath;
            } else {
              // If it's a relative path, prepend the base URL.
              // Use the URL AS-IS; do NOT append a new timestamp.
              _profilePicUrl = '$baseUrl$fetchedProfilePicPath';
            }
          } else {
            _profilePicUrl =
                'https://placehold.co/100x100/CCCCCC/000000?text=User';
          }

          _isPharmacist =
              responseData['isPharmacist'] ??
              false; // 🌟 PHARMACIST FIX APPLIED HERE

          // Buyer Specific Data
          _userWalletBalance =
              (responseData['userWalletBalance'] as num?)?.toDouble() ?? 0.0;

          // Vendor Specific Data
          _isVendor = responseData['isVendor'] ?? false;
          _vendorStatus = responseData['vendorStatus'] ?? 'none';
          _totalProducts = responseData['totalProducts'] ?? 0;
          _productsSold = responseData['productsSold'] ?? 0;
          _productsUnsold = responseData['productsUnsold'] ?? 0;
          _vendorWalletBalance =
              (responseData['vendorWalletBalance'] as num?)?.toDouble() ?? 0.0;
          _appWalletBalance =
              (responseData['appWalletBalance'] as num?)?.toDouble() ?? 0.0;
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage =
              responseData['message'] ?? 'Failed to fetch user data.';
        });
        if (response.statusCode == 401) {
          prefs.remove('jwt_token');
          // Optionally navigate to login screen
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'An error occurred: $e. Please check your network connection.';
      });
      debugPrint('Fetch user data network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAccountDeletion() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Account Permanently?'),
            content: const Text(
              'This action is irreversible. All your data, including profile info, orders, and saved items, will be permanently deleted. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !confirm) {
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting account...'),
        duration: Duration(seconds: 2),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final url = Uri.parse('$baseUrl/api/auth/delete-account');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully deleted.')),
        );
        // Log out the user and navigate to the login screen
        await _handleLogout();
      } else {
        final responseBody = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ??
                  'Failed to delete account. Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Check your network connection.'),
        ),
      );
      debugPrint('Error during account deletion: $e');
    }
  }

  Future<void> _handleLogout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    widget.onLogout();
  }

  // einsteinenginefordevs@gmail.com
  // // A static or global function that does nothing, as it's not needed for logout navigation
  // static void _emptyOnLoginSuccess() {
  // � // This function is intentionally left empty.
  // � // It fulfills the `required` callback for LoginScreen when navigating to it during logout,
  // � // but no actual login success action needs to occur from this navigation.
  // }

  @override
  Widget build(BuildContext context) {
    // Define your custom ColorScheme based on the provided colors
    final ColorScheme customColorScheme = const ColorScheme(
      primary:
          deepNavyBlue, // Dominant color for interactive elements, top app bar
      onPrimary: white, // Text and icons on top of primary color
      secondary: greenYellow, // Accent color for floating buttons, highlights
      onSecondary: deepNavyBlue, // Text and icons on top of secondary color
      surface: white, // Background for cards, sheets, elevated elements
      onSurface: deepNavyBlue, // Text and icons on top of background color
      error: Colors.red, // Error states
      onError: white, // Text and icons on top of error color
      brightness: Brightness.light, // Overall theme brightness
    );

    final color = customColorScheme; // Use your custom color scheme
    final panelDecoration = BoxDecoration(
      color: white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: white.withValues(alpha: 0.16)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
      ],
    );

    Widget buildShell(Widget body) {
      return TechGlowBackground(
        child: Scaffold(backgroundColor: Colors.transparent, body: body),
      );
    }

    if (_isLoading) {
      return buildShell(
        Center(child: CircularProgressIndicator(color: color.primary)),
      );
    }

    if (_errorMessage != null) {
      return buildShell(
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: panelDecoration,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: color.error, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: color.error, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color.primary,
                          foregroundColor: color.onPrimary,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return buildShell(
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: panelDecoration,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🧑 Profile Section
                  _buildProfileSection(color),
                  Divider(
                    height: 30,
                    thickness: 1,
                    color: color.onSurface.withValues(alpha: 0.2),
                  ),

                  // 🛍️ FOR BUYERS – Tabs or List Items (Always shown, but content changes)
                  _buildBuyerSection(color),
                  Divider(
                    height: 30,
                    thickness: 1,
                    color: color.onSurface.withValues(alpha: 0.2),
                  ),

                  // 🛒 FOR VENDORS – Show if user is a vendor
                  if (_isVendor && _vendorStatus == 'approved')
                    _buildVendorToolsSection(color)
                  else
                    _buildBecomeVendorCTA(color),
                  Divider(
                    height: 30,
                    thickness: 1,
                    color: color.onSurface.withValues(alpha: 0.2),
                  ),

                  // 🌟 FOR PHARMACISTS – Show if user is a pharmacist
                  if (_isPharmacist) _buildPharmacistToolsSection(color),
                  if (_isPharmacist)
                    Divider(
                      height: 30,
                      thickness: 1,
                      color: color.onSurface.withValues(alpha: 0.2),
                    ),

                  // ⚙️ COMMON TOOLS (For All Users)
                  _buildCommonToolsSection(color),
                  const SizedBox(height: 20),

                  // Log Out Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(
                        Icons.logout,
                        color: white,
                      ), // White icon for contrast on red
                      label: const Text(
                        'Log Out',
                        style: TextStyle(color: white, fontSize: 18),
                      ), // White text for contrast
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .red
                            .shade700, // Explicit red for logout action
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),

                  // --- ADD THIS NEW WIDGET HERE ---
                  const SizedBox(
                    height: 10,
                  ), // Add a small space between the two buttons
                  // Delete Account Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleAccountDeletion,
                      icon: Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red.shade700,
                      ),
                      label: Text(
                        'Delete Account',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 18,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.red.shade700, width: 2),
                      ),
                    ),
                  ),

                  // --- Unique Ideas (Placeholders for now) ---
                  const SizedBox(height: 40),
                  Text(
                    'Unique Ideas (Coming Soon):',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildComingSoonItem(color, '✅ Buyer–Seller Switch Toggle'),
                  _buildComingSoonItem(color, '📦 Live Order Map Tracker'),
                  _buildComingSoonItem(color, '🎉 Achievements/Badges'),
                  _buildComingSoonItem(color, '💬 Community Forum Link'),
                  _buildComingSoonItem(
                    color,
                    '📈 Quick Stats Card (for Vendors)',
                  ),
                  _buildComingSoonItem(color, '🔔 Smart Alerts'),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for Sections ---

  Widget _buildProfileSection(ColorScheme color) {
    return Column(
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: color.surface, // Fallback background for avatar
            child: ClipOval(
              child: SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: _profilePicUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: color.primary),
                  ),
                  errorWidget: (context, url, error) {
                    return Icon(
                      Icons.person,
                      size: 60,
                      color: color.onSurface.withValues(alpha: 0.5),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$_firstName $_lastName',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color.onSurface, // Use onBackground for main text
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _email,
          style: TextStyle(
            fontSize: 16,
            color: color.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          _phoneNumber,
          style: TextStyle(
            fontSize: 16,
            color: color.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final bool? result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
              if (result == true) {
                _fetchUserData(); // Refresh AccountScreen data after profile is updated
              }
            },
            icon: Icon(Icons.edit, color: color.primary),
            label: Text('Edit Profile', style: TextStyle(color: color.primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: color.primary,
              ), // Border matches primary color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerSection(ColorScheme color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buyer Tools',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.primary,
          ),
        ),
        const SizedBox(height: 10),
        _buildAccountListItem(
          context,
          color,
          Icons.shopping_bag_outlined,
          'My Orders',
          'Track all current & past orders',
          () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.favorite_outline,
          'Saved Items (Wishlist)',
          'Easily revisit products you liked',
          () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.account_balance_wallet_outlined,
          'My Wallet / Payment Methods',
          'Wallet balance: ₦${_userWalletBalance.toStringAsFixed(2)}',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MyWalletScreen()),
            );
            _fetchUserData(); // Refresh account data after returning from wallet screen
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.location_on_outlined,
          'Delivery Addresses',
          'Manage your shipping locations',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DeliveryAddressesScreen(),
              ),
            );
            _fetchUserData(); // Refresh account data after returning from addresses screen
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.star_outline,
          'Reviews & Ratings',
          'View products you reviewed',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ReviewsRatingsScreen(),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.assignment_return_outlined,
          'Returns & Disputes',
          'View initiated return requests',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DisputeListScreen(),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.help_outline,
          'Help Center',
          'FAQs, live chat, contact support',
          () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const FAQScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildVendorToolsSection(ColorScheme color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vendor Tools',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.primary,
          ),
        ),
        const SizedBox(height: 10),
        _buildAccountListItem(
          context,
          color,
          Icons.inventory_2_outlined,
          'My Products',
          'View/manage inventory ($_totalProducts total, $_productsUnsold unsold)',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const VendorMyProductsScreen(),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.receipt_long_outlined,
          'Orders Received',
          'View buyer orders ($_productsSold products sold)',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const OrdersRecivedScreen(),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.payments_outlined,
          'Earnings Dashboard',
          'Vendor Wallet: ₦${_vendorWalletBalance.toStringAsFixed(2)} | App Wallet: ₦${_appWalletBalance.toStringAsFixed(2)}',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Earnings Dashboard functionality coming soon!'),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.campaign_outlined,
          'Promotions & Ads',
          'Promote a product, view ad performance',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Promotions & Ads functionality coming soon!'),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.store_outlined,
          'Store Profile',
          'Edit store logo, bio, name',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Store Profile functionality coming soon!'),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.message_outlined,
          'Messages from Buyers',
          'Buyer inquiries or complaints',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Messages from Buyers functionality coming soon!',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 🌟 NEW HELPER METHOD FOR PHARMACIST DASHBOARD
  Widget _buildPharmacistToolsSection(ColorScheme color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pharmacy Workspace',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.primary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PharmacyUi.deepNavy, PharmacyUi.teal],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: PharmacyUi.deepNavy.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PharmacistDashboard(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Care Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Pharmacist dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Handle live consultation requests, jump into patient chats, and manage pharmacy support from one workspace.',
                      style: TextStyle(color: Color(0xFFE6FBF4), height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Icon(
                          Icons.medical_services_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Open the workspace',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBecomeVendorCTA(ColorScheme color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Become a Vendor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.primary,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: color.surface, // Card background color
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want to sell your products on NaijaGo?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Register as a vendor to list your products and manage your sales.',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vendor Registration coming soon!'),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.store_mall_directory_outlined,
                      color: color.onPrimary,
                    ),
                    label: Text(
                      'Register as Vendor',
                      style: TextStyle(color: color.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonToolsSection(ColorScheme color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Tools',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.primary,
          ),
        ),
        const SizedBox(height: 10),
        _buildAccountListItem(
          context,
          color,
          Icons.notifications_none,
          'Notification Settings',
          'Manage your notification preferences',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notification Settings functionality coming soon!',
                ),
              ),
            );
          },
        ),
        // ✅ The Dark Mode Toggle now navigates to the SettingsScreen
        _buildAccountListItem(
          context,
          color,
          Icons.brightness_4_outlined,
          'Dark Mode Toggle',
          'Switch between light and dark themes',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This Feature is Coming Soon')),
            );
          },
          // � � () {
          // � // Navigate to the SettingsScreen class, which is defined in main.dart
          // � Navigator.of(context).push(
          // � � MaterialPageRoute(builder: (context) => const SettingsScreen()),
          // � );
          // },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.language_outlined,
          'Language & Region',
          'Change app language and region settings',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Language & Region functionality coming soon!'),
              ),
            );
          },
        ),
        _buildAccountListItem(
          context,
          color,
          Icons.share_outlined,
          'Invite a Friend',
          'Share NaijaGo with your friends',
          () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ReferralScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildCustomerSupportCard(color),
      ],
    );
  }

  Widget _buildCustomerSupportCard(ColorScheme color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      color: color.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: color.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Support',
                        style: TextStyle(
                          color: color.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reach us faster on WhatsApp or place a direct call.',
                        style: TextStyle(
                          color: color.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final whatsappButton = OutlinedButton.icon(
                  onPressed: () => _openWhatsAppSupport(),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color.primary,
                    side: BorderSide(
                      color: color.primary.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );

                final callButton = ElevatedButton.icon(
                  onPressed: () => _callCustomerSupport(),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.primary,
                    foregroundColor: color.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: whatsappButton),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: callButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: whatsappButton),
                    const SizedBox(width: 10),
                    Expanded(child: callButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper for consistent list item styling
  Widget _buildAccountListItem(
    BuildContext context,
    ColorScheme color,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      color: color.surface, // Card background color
      child: ListTile(
        leading: Icon(icon, color: color.primary, size: 28), // Icon color
        title: Text(
          title,
          style: TextStyle(color: color.onSurface, fontWeight: FontWeight.w600),
        ), // Title text color
        subtitle: Text(
          subtitle,
          style: TextStyle(color: color.onSurface.withValues(alpha: 0.7)),
        ), // Subtitle text color
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: color.onSurface.withValues(alpha: 0.5),
        ), // Arrow icon color
        onTap: onTap,
      ),
    );
  }

  Widget _buildComingSoonItem(ColorScheme color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: greenYellow,
          ), // Checkmark icon color
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: color.onSurface.withValues(alpha: 0.8),
              ), // Text color
            ),
          ),
        ],
      ),
    );
  }
}
