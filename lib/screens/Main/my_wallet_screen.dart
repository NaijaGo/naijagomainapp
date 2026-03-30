// lib/screens/Main/my_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';
import 'withdrawal_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tech_glow_background.dart';

// Color constants
const Color deepNavyBlue = AppTheme.primaryNavy;
const Color greenYellow = Colors.white;
const Color whiteBackground = Colors.white;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color borderGrey = AppTheme.borderGrey;
const Color mutedText = AppTheme.mutedText;
const Color softGrey = AppTheme.softGrey;
const Color brandSoftText = Color(0xFFF4F8FF);
const Color brandMutedText = Color(0xFFD5E0F2);

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  double _userWalletBalance = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _amountController = TextEditingController();

  // New state variables for saved bank details and password
  List<Map<String, String>> _savedBankCredentials = [];
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletBalance() async {
    _setLoading(true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _setError('Authentication token not found. Please log in again.');
      _setLoading(false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: _authHeaders(token),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['user'] ?? data;
        if (userData.containsKey('userWalletBalance')) {
          final user = User.fromJson(userData);
          _setBalance(user.userWalletBalance);
        } else {
          _setError('User data is missing the wallet balance field.');
          debugPrint('API response missing wallet balance: ${response.body}');
        }
      } else {
        final data = jsonDecode(response.body);
        _setError(data['message'] ?? 'Failed to fetch wallet balance.');
      }
    } catch (e) {
      _setError('Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _verifyTransactionOnBackend(String transactionRef) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _showSnack('Authentication token not found. Please log in again.');
      return;
    }

    try {
      _showSnack('Verifying payment. Please wait...');
      debugPrint('Sending transaction reference to backend: $transactionRef');
      final response = await http.post(
        Uri.parse('$baseUrl/api/wallet/verify-payment'),
        headers: _authHeaders(token),
        body: jsonEncode({'transactionRef': transactionRef}),
      );

      if (response.statusCode == 200) {
        await Future.delayed(const Duration(seconds: 1));
        await _fetchWalletBalance();
        _showSnack(
          'Payment verified and wallet credited! Your balance has been updated.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Unknown error occurred.';
        _showSnack('Verification failed: $errorMessage');
        debugPrint(
          'Verification failed with status code ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      _showSnack('An error occurred while communicating with the server.');
      debugPrint('Error verifying transaction: $e');
    }
  }

  Future<void> _handleFlutterwaveTopUp() async {
    if (!mounted) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('Please enter a valid amount');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    String userEmail = '';

    if (userJson != null) {
      final userData = jsonDecode(userJson);
      userEmail = userData['email'] ?? '';
    }

    if (userEmail.isEmpty) {
      _showSnack('User email not found. Please log in again.');
      return;
    }

    final publicKey = dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? '';
    if (publicKey.isEmpty) {
      _showSnack('Flutterwave public key not set in .env');
      return;
    }

    final bool isTestMode =
        (dotenv.env['FLUTTERWAVE_TEST_MODE'] ?? 'true') == 'true';
    final txRef = 'FLW_${const Uuid().v4()}';

    final flutterwave = Flutterwave(
      publicKey: publicKey,
      currency: 'NGN',
      redirectUrl: 'https://your-redirect-url.com',
      txRef: txRef,
      amount: amount.toString(),
      customer: Customer(name: 'NaijaGo User', email: userEmail),
      paymentOptions: 'card, ussd, banktransfer',
      customization: Customization(title: 'NaijaGo Wallet Top Up'),
      isTestMode: isTestMode,
    );

    try {
      if (!mounted) return;
      final ChargeResponse response = await flutterwave.charge(context);

      if (response.success == true) {
        _amountController.clear();
        await _verifyTransactionOnBackend(txRef);
      } else {
        _showSnack('Payment cancelled or failed');
      }
    } catch (e) {
      _showSnack('Payment error: $e');
      debugPrint('Payment error: $e');
    }
  }

  void _showTopUpDialog() {
    _showCustomDialog(
      title: 'Top Up Wallet',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter the amount you wish to add to your wallet.',
            style: TextStyle(color: deepNavyBlue),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Amount (₦)'),
          ),
        ],
      ),
      confirmText: 'Pay with Flutterwave',
      onConfirm: _handleFlutterwaveTopUp,
    );
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCredentialsJson = prefs.getStringList('saved_bank_credentials');
    if (savedCredentialsJson != null) {
      setState(() {
        _savedBankCredentials = savedCredentialsJson
            .map((e) => Map<String, String>.from(jsonDecode(e)))
            .toList();
      });
    }
  }

  void _showAddPaymentMethodDialog() {
    _showCustomDialog(
      title: 'Add Payment Method',
      content: const Text(
        'Adding and managing payment methods will be available soon!',
        style: TextStyle(color: deepNavyBlue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'My Wallet & Payments',
            style: TextStyle(color: brandSoftText),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: brandSoftText),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: whiteBackground),
              )
            : _errorMessage != null
            ? _buildErrorUI()
            : _buildWalletUI(),
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: whiteBackground, size: 50),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: whiteBackground, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchWalletBalance,
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavyBlue,
                foregroundColor: whiteBackground,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _walletBalanceCard(),
          const SizedBox(height: 35),
          _linkedPaymentMethodsCard(),
          const SizedBox(height: 35),
          _transactionHistoryCard(),
        ],
      ),
    );
  }

  Widget _walletBalanceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderGrey),
      ),
      color: whiteBackground,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Wallet Balance',
              style: TextStyle(
                color: mutedText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '₦${_userWalletBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: deepNavyBlue,
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    'Top Up',
                    Icons.add_circle_outline,
                    _showTopUpDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    'Withdraw',
                    Icons.remove_circle_outline,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WithdrawScreen(
                            userWalletBalance: _userWalletBalance,
                            savedBankCredentials: _savedBankCredentials,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkedPaymentMethodsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: borderGrey),
      ),
      color: whiteBackground,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.credit_card, color: deepNavyBlue),
            title: const Text(
              'No payment methods linked yet.',
              style: TextStyle(
                color: secondaryBlack,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Add a card or bank account for faster checkouts.',
              style: const TextStyle(color: mutedText),
            ),
          ),
          const Divider(color: borderGrey),
          ListTile(
            leading: const Icon(Icons.add_card, color: deepNavyBlue),
            title: const Text(
              'Add New Payment Method',
              style: TextStyle(
                color: secondaryBlack,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: deepNavyBlue,
            ),
            onTap: _showAddPaymentMethodDialog,
          ),
        ],
      ),
    );
  }

  Widget _transactionHistoryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: borderGrey),
      ),
      color: whiteBackground,
      child: ListTile(
        leading: const Icon(Icons.history, color: deepNavyBlue),
        title: const Text(
          'View all your transactions',
          style: TextStyle(color: secondaryBlack, fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: deepNavyBlue,
        ),
        onTap: () => _showSnack('Transaction history coming soon!'),
      ),
    );
  }

  void _setLoading(bool value) => setState(() => _isLoading = value);
  void _setError(String message) => setState(() => _errorMessage = message);
  void _setBalance(double balance) =>
      setState(() => _userWalletBalance = balance);

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: mutedText),
    filled: true,
    fillColor: softGrey,
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: borderGrey),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: deepNavyBlue, width: 1.4),
      borderRadius: BorderRadius.circular(10),
    ),
  );

  ElevatedButton _actionButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: whiteBackground),
      label: Text(text, style: const TextStyle(color: whiteBackground)),
      style: ElevatedButton.styleFrom(
        backgroundColor: deepNavyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showCustomDialog({
    required String title,
    required Widget content,
    String? confirmText,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: whiteBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          title,
          style: const TextStyle(
            color: secondaryBlack,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
          ),
          if (confirmText != null && onConfirm != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavyBlue,
                foregroundColor: whiteBackground,
              ),
              child: Text(confirmText),
            ),
        ],
      ),
    );
  }
}
