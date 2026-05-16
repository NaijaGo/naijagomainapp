import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const String _draftKey = 'naijago_subscription_draft';

  final _money = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  List<_SubscriptionPlan> _plans = const [
    _SubscriptionPlan(
      id: 'student',
      name: 'Students',
      price: 10000,
      deliveries: 7,
      minimumOrderValue: 4000,
      deliveryScope: 'Same zone only',
      validHours: '9AM - 6PM',
      benefits: [
        'Free delivery within your zone',
        'Built for weekly essentials',
      ],
      accent: Color(0xFF16A34A),
    ),
    _SubscriptionPlan(
      id: 'standard',
      name: 'Standard',
      price: 20000,
      deliveries: 15,
      minimumOrderValue: 8000,
      deliveryScope: 'Same zone only',
      validHours: '9AM - 6PM',
      benefits: ['Priority delivery', 'More monthly free deliveries'],
      accent: Color(0xFF2563EB),
    ),
    _SubscriptionPlan(
      id: 'premium',
      name: 'Premium',
      price: 50000,
      deliveries: 20,
      minimumOrderValue: 15000,
      deliveryScope: 'Within city errands',
      validHours: '9AM - 6PM',
      benefits: [
        'Priority delivery and exclusive deals',
        'Errand requests within your city',
      ],
      accent: Color(0xFF7C3AED),
    ),
  ];

  final Map<String, List<String>> _preferenceGroups = const {
    'Food': ['Fast Food', 'Local Food', 'Snacks', 'Drinks'],
    'Shopping': [
      'Groceries',
      'Gadgets',
      'Fashion',
      'Health & Pharmacy',
      'Home Essentials',
    ],
    'Delivery style': ['Urgent Delivery', 'Cheap Deals', 'Premium Quality'],
  };

  String _selectedPlanId = 'standard';
  final Set<String> _selectedPreferences = {
    'Groceries',
    'Fast Food',
    'Cheap Deals',
  };
  bool _isSaving = false;
  bool _isActivating = false;
  bool _isLoadingRemote = true;
  double _walletBalance = 0;
  String? _savedMessage;

  _SubscriptionPlan get _selectedPlan =>
      _plans.firstWhere((plan) => plan.id == _selectedPlanId);

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadRemoteSubscription();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final planId = decoded['planId']?.toString();
      final preferences = (decoded['preferences'] as List? ?? [])
          .map((item) => item.toString())
          .toSet();

      if (!mounted) return;
      setState(() {
        if (_plans.any((plan) => plan.id == planId)) {
          _selectedPlanId = planId!;
        }
        if (preferences.isNotEmpty) {
          _selectedPreferences
            ..clear()
            ..addAll(preferences);
        }
        _savedMessage = 'Saved setup found. Payment activation is pending.';
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _saveDraft() async {
    if (_selectedPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one preference.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final token = await _getToken();
    if (token != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/subscriptions/setup'),
          headers: _authHeaders(token),
          body: jsonEncode(_subscriptionPayload()),
        );

        final data = _decodeMap(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(data['message'] ?? 'Failed to save setup.');
        }
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'planId': _selectedPlan.id,
        'planName': _selectedPlan.name,
        'price': _selectedPlan.price,
        'deliveries': _selectedPlan.deliveries,
        'minimumOrderValue': _selectedPlan.minimumOrderValue,
        'preferences': _selectedPreferences.toList()..sort(),
        'status': 'payment_pending',
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _savedMessage =
          '${_selectedPlan.name} setup saved. Payment activation is next.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Subscription setup saved. Payment activation is pending.',
        ),
      ),
    );
  }

  Future<void> _activateWithWallet() async {
    if (_selectedPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one preference.')),
      );
      return;
    }

    final token = await _getToken();
    if (!mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to activate subscription.'),
        ),
      );
      return;
    }

    setState(() => _isActivating = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/subscriptions/activate-wallet'),
        headers: _authHeaders(token),
        body: jsonEncode(_subscriptionPayload()),
      );

      final data = _decodeMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['message'] ?? 'Failed to activate subscription.');
      }

      await _persistLocalDraft(status: 'active');
      if (!mounted) return;
      setState(() {
        _walletBalance = _parseDouble(data['userWalletBalance']);
        _savedMessage =
            data['message']?.toString() ??
            '${_selectedPlan.name} subscription activated.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_savedMessage!)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  Future<void> _loadRemoteSubscription() async {
    final token = await _getToken();
    if (token == null) {
      if (mounted) setState(() => _isLoadingRemote = false);
      return;
    }

    try {
      final plansResponse = await http.get(
        Uri.parse('$baseUrl/api/subscriptions/plans'),
        headers: _authHeaders(token),
      );
      if (plansResponse.statusCode == 200) {
        final data = _decodeMap(plansResponse.body);
        final plans = (data['plans'] as List? ?? [])
            .whereType<Map>()
            .map(
              (item) =>
                  _SubscriptionPlan.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        if (plans.isNotEmpty && mounted) {
          setState(() => _plans = plans);
        }
      }

      final statusResponse = await http.get(
        Uri.parse('$baseUrl/api/subscriptions/me'),
        headers: _authHeaders(token),
      );
      if (statusResponse.statusCode == 200) {
        final data = _decodeMap(statusResponse.body);
        final subscription = Map<String, dynamic>.from(
          (data['subscription'] as Map?) ?? const {},
        );
        final planId = subscription['planId']?.toString();
        final preferences = (subscription['preferences'] as List? ?? [])
            .map((item) => item.toString())
            .toSet();

        if (mounted) {
          setState(() {
            _walletBalance = _parseDouble(data['userWalletBalance']);
            if (_plans.any((plan) => plan.id == planId)) {
              _selectedPlanId = planId!;
            }
            if (preferences.isNotEmpty) {
              _selectedPreferences
                ..clear()
                ..addAll(preferences);
            }
            final status = subscription['status']?.toString() ?? 'inactive';
            if (status == 'active') {
              final remaining = subscription['deliveriesRemaining'] ?? 0;
              _savedMessage =
                  'Active plan: ${subscription['planName'] ?? _selectedPlan.name}. $remaining free deliveries remaining.';
            } else if (status == 'payment_pending') {
              _savedMessage = 'Setup saved. Payment activation is pending.';
            }
          });
        }
      }
    } catch (_) {
      // Keep the screen usable with bundled plan data if the backend is offline.
    } finally {
      if (mounted) setState(() => _isLoadingRemote = false);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _subscriptionPayload() => {
    'planId': _selectedPlan.id,
    'preferences': _selectedPreferences.toList()..sort(),
  };

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _persistLocalDraft({required String status}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'planId': _selectedPlan.id,
        'planName': _selectedPlan.name,
        'price': _selectedPlan.price,
        'deliveries': _selectedPlan.deliveries,
        'minimumOrderValue': _selectedPlan.minimumOrderValue,
        'preferences': _selectedPreferences.toList()..sort(),
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.softGrey,
      appBar: AppBar(
        title: const Text('NaijaGo Subscription'),
        backgroundColor: AppTheme.cardWhite,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _isLoadingRemote
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  _buildHero(color),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Choose a monthly plan'),
                  const SizedBox(height: 10),
                  ..._plans.map(_buildPlanCard),
                  const SizedBox(height: 18),
                  _buildSectionTitle('Personalize your experience'),
                  const SizedBox(height: 10),
                  ..._preferenceGroups.entries.map(_buildPreferenceGroup),
                  const SizedBox(height: 18),
                  _buildRulesPanel(),
                  const SizedBox(height: 18),
                  _buildSummaryPanel(),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: (_isSaving || _isActivating) ? null : _saveDraft,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save setup'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isSaving || _isActivating)
                    ? null
                    : _activateWithWallet,
                icon: _isActivating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  _isActivating
                      ? 'Activating...'
                      : 'Activate with wallet (${_money.format(_selectedPlan.price)})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(ColorScheme color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(height: 12),
          const Text(
            'Free deliveries, priority service, and smarter recommendations.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pick a plan, tell us what you like, and NaijaGo will tailor shopping and delivery benefits around you.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          if (_savedMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Text(
                _savedMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(_SubscriptionPlan plan) {
    final isSelected = plan.id == _selectedPlanId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selectedPlanId = plan.id),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? plan.accent : AppTheme.borderGrey,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        color: AppTheme.secondaryBlack,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? plan.accent : AppTheme.mutedText,
                  ),
                ],
              ),
              Text(
                '${_money.format(plan.price)}/month',
                style: TextStyle(
                  color: plan.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PlanPill('${plan.deliveries} free deliveries'),
                  _PlanPill(
                    'Min order ${_money.format(plan.minimumOrderValue)}',
                  ),
                  _PlanPill(plan.deliveryScope),
                  _PlanPill(plan.validHours),
                ],
              ),
              const SizedBox(height: 10),
              ...plan.benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: plan.accent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(
                            color: AppTheme.mutedText,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceGroup(MapEntry<String, List<String>> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.key,
            style: const TextStyle(
              color: AppTheme.secondaryBlack,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.value.map((preference) {
              final selected = _selectedPreferences.contains(preference);
              return FilterChip(
                label: Text(preference),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedPreferences.add(preference);
                    } else {
                      _selectedPreferences.remove(preference);
                    }
                  });
                },
                selectedColor: AppTheme.accentBlue.withValues(alpha: 0.14),
                checkmarkColor: AppTheme.accentBlue,
                side: BorderSide(
                  color: selected ? AppTheme.accentBlue : AppTheme.borderGrey,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesPanel() {
    const rules = [
      'Free delivery applies only within your allowed zone or city scope.',
      'Free delivery only applies while monthly delivery balance remains.',
      'Minimum order value must be met before delivery fee is waived.',
      'Benefits apply during valid operating hours.',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery rules',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: Color(0xFF92400E),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    final plan = _selectedPlan;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected setup',
            style: TextStyle(
              color: AppTheme.secondaryBlack,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Plan', value: plan.name),
          _SummaryRow(label: 'Monthly fee', value: _money.format(plan.price)),
          _SummaryRow(
            label: 'Free deliveries',
            value: '${plan.deliveries} per month',
          ),
          _SummaryRow(
            label: 'Preferences',
            value: _selectedPreferences.isEmpty
                ? 'None selected'
                : (_selectedPreferences.toList()..sort()).join(', '),
          ),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Wallet', value: _money.format(_walletBalance)),
          _SummaryRow(
            label: 'Backend',
            value: _isLoadingRemote ? 'Syncing...' : 'Connected',
          ),
          const SizedBox(height: 10),
          const Text(
            'Wallet activation debits your NaijaGo wallet and starts a 30-day delivery counter.',
            style: TextStyle(color: AppTheme.mutedText, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.secondaryBlack,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final int deliveries;
  final int minimumOrderValue;
  final String deliveryScope;
  final String validHours;
  final List<String> benefits;
  final Color accent;

  const _SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.deliveries,
    required this.minimumOrderValue,
    required this.deliveryScope,
    required this.validHours,
    required this.benefits,
    required this.accent,
  });

  factory _SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? 'standard';
    final validHours = json['validHours'] is Map
        ? Map<String, dynamic>.from(json['validHours'] as Map)
        : const <String, dynamic>{};
    final start = validHours['start']?.toString() ?? '09:00';
    final end = validHours['end']?.toString() ?? '18:00';

    return _SubscriptionPlan(
      id: id,
      name: json['name']?.toString() ?? 'Standard',
      price: (json['price'] as num?)?.toInt() ?? 0,
      deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
      minimumOrderValue: (json['minimumOrderValue'] as num?)?.toInt() ?? 0,
      deliveryScope:
          json['deliveryScopeLabel']?.toString() ??
          json['deliveryScope']?.toString() ??
          '',
      validHours: '$start - $end',
      benefits: (json['benefits'] as List? ?? [])
          .map((benefit) => benefit.toString())
          .toList(),
      accent: switch (id) {
        'student' => const Color(0xFF16A34A),
        'premium' => const Color(0xFF7C3AED),
        _ => const Color(0xFF2563EB),
      },
    );
  }
}

class _PlanPill extends StatelessWidget {
  final String label;

  const _PlanPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.softGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.secondaryBlack,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.secondaryBlack,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
