import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'dart:async'; // Import for Timer

import '../../constants.dart';

const Color deepNavyBlue = Color(0xFF001F54);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Color(0xFFFFFFFF);

class WithdrawScreen extends StatefulWidget {
  final double userWalletBalance;
  final List<Map<String, String>> savedBankCredentials;

  const WithdrawScreen({
    super.key,
    required this.userWalletBalance,
    required this.savedBankCredentials,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController accountNameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  // ✅ FIX: Declare a Future variable to hold the result of _fetchBanks().
  late Future<List<Map<String, String>>> _banksFuture;

  String? selectedBankName;
  String? selectedBankCode;
  bool saveCredentials = false;
  final formKey = GlobalKey<FormState>();

  // OTP state
  int otpSecondsRemaining = 0;
  bool otpCountdownActive = false;
  bool otpRequested = false;
  Timer? _otpTimer;

  List<Map<String, String>> savedBankCredentials = [];

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Initialize the Future here so it's called only once.
    _banksFuture = _fetchBanks();
    _loadSavedBankCredentials();
  }

  Future<void> _loadSavedBankCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final storedBanks = prefs.getStringList('saved_banks') ?? [];
    setState(() {
      savedBankCredentials =
          storedBanks.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveBankCredentials(Map<String, String> creds) async {
    // Check for duplicates before adding
    final isDuplicate = savedBankCredentials.any((e) =>
        e['account_number'] == creds['account_number'] &&
        e['bank_code'] == creds['bank_code']);

    if (!isDuplicate) {
      savedBankCredentials.add(creds);
      final prefs = await SharedPreferences.getInstance();
      final encoded = savedBankCredentials.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList('saved_banks', encoded);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<Map<String, String>>> _fetchBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        _showSnack('Authorization failed. Please log in.');
        return [];
      }

      final response = await http.get(
          Uri.parse('$baseUrl/api/wallet/banks'),
          headers: _authHeaders(token));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['banks'] as List;
        return data
            .map<Map<String, String>>((b) => {
                  'name': b['name'].toString(),
                  'code': b['code'].toString(),
                })
            .toList();
      }
      
      _showSnack('Failed to load banks: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error fetching banks: $e');
      // Show a snack bar on network error
      if (mounted) {
        _showSnack('Network error loading banks.');
      }
      return [];
    }
  }

  Future<Map<String, String>?> _showBankSelectionDialog(
      List<Map<String, String>> banks) async {
    TextEditingController searchController = TextEditingController();
    List<Map<String, String>> filteredBanks = List.from(banks);

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterBanks(String query) {
              setDialogState(() {
                filteredBanks = banks
                    .where((b) =>
                        b['name']!.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              });
            }

            return AlertDialog(
              title: const Text('Select Bank'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search bank',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: filterBanks,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredBanks.length,
                        itemBuilder: (context, index) {
                          final bank = filteredBanks[index];
                          return ListTile(
                            title: Text(bank['name']!),
                            onTap: () => Navigator.pop(context, bank),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void startOtpCountdown() {
    setState(() {
      otpSecondsRemaining = 300;
      otpRequested = true;
      otpCountdownActive = true;
    });
    // Cancel any existing timer before starting a new one
    _otpTimer?.cancel(); 
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (otpSecondsRemaining <= 0) {
        timer.cancel();
        setState(() {
          otpCountdownActive = false;
          otpRequested = false;
        });
      } else {
        setState(() {
          otpSecondsRemaining--;
        });
      }
    });
  }

  String formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: whiteBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: deepNavyBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: deepNavyBlue.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

Future<void> _requestOtp() async {
  if (otpSecondsRemaining > 0) return;

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    _showSnack('Please log in again.');
    return;
  }

  try {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/wallet/request-otp'),
      headers: _authHeaders(token),
      // No body needed — your backend doesn't require it
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      _showSnack(body['message'] ?? 'OTP sent to your email.');
      startOtpCountdown();
    } else {
      // IMPROVED: Show the actual server error message
      try {
        final body = jsonDecode(resp.body);
        final serverMsg = body['message'] ?? 'Server error (${resp.statusCode})';
        _showSnack(serverMsg);
        debugPrint('OTP request failed: $serverMsg (Status: ${resp.statusCode}) - Body: ${resp.body}');
      } catch (e) {
        // If body is not JSON
        _showSnack('Server error: ${resp.statusCode}');
        debugPrint('OTP request failed - Status: ${resp.statusCode} - Raw body: ${resp.body}');
      }
    }
  } catch (e) {
    _showSnack('Network error requesting OTP.');
    debugPrint('OTP network error: $e');
  }
}

  Future<void> _handleWithdrawal() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedBankCode == null) {
      _showSnack('Please select a bank.');
      return;
    }

    // Input validation
    final acct = accountNumberController.text.trim();
    final name = accountNameController.text.trim();
    final amountText = amountController.text.trim();
    final amount = double.tryParse(amountText);
    final password = _passwordController.text.trim();
    final otpValue = otpController.text.trim();

    if (amount == null || amount <= 0 || amount > widget.userWalletBalance) {
      _showSnack('Please enter a valid amount.');
      return;
    }
    if (password.isEmpty) {
      _showSnack('Please enter your password.');
      return;
    }
    if (otpValue.length != 6) {
      _showSnack('Please enter the 6-digit OTP.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      _showSnack('Please log in again.');
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/wallet/withdraw'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'bank_code': selectedBankCode!,
          'account_number': acct,
          'amount': amount,
          'account_name': name,
          'password': password,
          'wallet_type': 'user',
          'otp': otpValue,
        }),
      );

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        _showSnack(body['message'] ?? 'Withdrawal successful.');
        if (saveCredentials) {
          await _saveBankCredentials({
            'bank_name': selectedBankName ?? '',
            'bank_code': selectedBankCode!,
            'account_number': acct,
            'account_name': name,
          });
        }
      } else {
        _showSnack(body['message'] ?? 'Withdrawal failed.');
      }
    } catch (e) {
      _showSnack('Network error during withdrawal.');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    accountNumberController.dispose();
    accountNameController.dispose();
    amountController.dispose();
    otpController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
        backgroundColor: deepNavyBlue,
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        // ✅ FIX: Use the stored Future instead of calling the function directly.
        future: _banksFuture, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading banks...'));
          }
          
          if (snapshot.hasError) {
             // Handle network errors or other exceptions more gracefully
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Error loading banks.', style: TextStyle(color: Colors.red)),
                    Text('Details: ${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          final banks = snapshot.data ?? [];
          if (banks.isEmpty) {
            return const Center(child: Text('Failed to load banks. Check connection.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saved accounts
                  if (savedBankCredentials.isNotEmpty)
                    sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saved Accounts',
                              style: TextStyle(
                                  color: deepNavyBlue,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Map<String, String>>(
                            decoration: _inputDecoration('Choose saved account'),
                            items: savedBankCredentials.map((creds) {
                              return DropdownMenuItem(
                                value: creds,
                                child: Text(
                                  '${creds['bank_name']} — ${creds['account_number']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (creds) {
                              if (creds != null) {
                                accountNumberController.text =
                                    creds['account_number']!;
                                accountNameController.text =
                                    creds['account_name']!;
                                selectedBankName = creds['bank_name']!;
                                selectedBankCode = creds['bank_code']!;
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                  // Bank picker
                  sectionCard(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final result = await _showBankSelectionDialog(banks);
                        if (result != null) {
                          setState(() {
                            selectedBankName = result['name'];
                            selectedBankCode = result['code'];
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedBankName ?? 'Select a bank',
                                style: TextStyle(
                                    color: selectedBankName == null
                                        ? Colors.grey
                                        : deepNavyBlue,
                                    fontSize: 15),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down,
                                color: deepNavyBlue),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Account details
                  sectionCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: accountNumberController,
                          decoration: _inputDecoration('Account Number'),
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Only allow digits
                          validator: (value) {
                            if (value == null || value.length != 10) {
                              return 'Account number must be 10 digits.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: accountNameController,
                          decoration: _inputDecoration('Account Name'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Account name is required.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  // Amount + Save credentials
                  sectionCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: amountController,
                          decoration: _inputDecoration('Amount (₦)')
                              .copyWith(prefixText: '₦ '),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                           inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');
                            if (amount == null ||
                                amount <= 0 ||
                                amount > widget.userWalletBalance) {
                              return 'Enter a valid amount (Max: ₦${widget.userWalletBalance.toStringAsFixed(2)}).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Only show the "Save bank details" checkbox if no accounts are saved yet
                        if (savedBankCredentials.isEmpty)
                          Row(
                            children: [
                              Checkbox(
                                value: saveCredentials,
                                onChanged: (value) =>
                                    setState(() => saveCredentials = value ?? false),
                                activeColor: greenYellow,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                  child: Text('Save bank details for next time',
                                      style: TextStyle(color: deepNavyBlue))),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Password + OTP
                  sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          decoration: _inputDecoration('Your Password'),
                          obscureText: true,
                          validator: (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Password is required.'
                                  : null,
                        ),
                        const SizedBox(height: 12),

                        // OTP Row
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: otpController,
                                enabled: otpRequested,
                                decoration: _inputDecoration('OTP (6 digits)'),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 6,
                                validator: (value) {
                                  // Simplified validation to only check if the field is empty or not 6 digits
                                  if (otpRequested && (value == null || value.length != 6)) {
                                    return 'OTP must be 6 digits.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                onPressed:
                                    otpSecondsRemaining > 0 ? null : _requestOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      otpSecondsRemaining > 0 ? Colors.grey : greenYellow,
                                  foregroundColor: deepNavyBlue,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  otpSecondsRemaining > 0
                                      ? formatDuration(otpSecondsRemaining)
                                      : 'Request OTP',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          otpRequested && otpSecondsRemaining > 0
                              ? 'OTP will expire in ${formatDuration(otpSecondsRemaining)}'
                              : 'Request an OTP to receive the 6-digit code via email',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Withdraw Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleWithdrawal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenYellow,
                        foregroundColor: deepNavyBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Withdraw'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

