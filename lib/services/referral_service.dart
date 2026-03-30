import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/referral_summary.dart';
import '../models/user.dart';

class ReferralService {
  static const List<String> _referralPaths = <String>[
    '/api/referrals/summary',
    '/api/referrals',
    '/api/referral/summary',
  ];

  Future<ReferralSummary> fetchReferralSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final cachedUser = _readCachedUser(prefs);
    Map<String, dynamic>? liveUserPayload;
    User? user = cachedUser;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeMap(response.body);
        liveUserPayload = _extractUserPayload(decoded);
        user = User.fromJson(liveUserPayload);
      }
    } catch (_) {
      // Fall back to locally cached user data if the profile request fails.
    }

    if (user == null) {
      throw Exception('Unable to load your referral details right now.');
    }

    if (liveUserPayload != null) {
      final embeddedPayload = _composeReferralPayload(liveUserPayload);
      if (_hasReferralFields(embeddedPayload)) {
        return _buildSummaryFromPayload(embeddedPayload, user);
      }
    }

    for (final path in _referralPaths) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token),
        );

        if (response.statusCode == 200) {
          final payload = _composeReferralPayload(_decodeMap(response.body));
          return _buildSummaryFromPayload(payload, user);
        }

        if (response.statusCode == 404) {
          continue;
        }
      } catch (_) {
        // Try the next known endpoint before falling back.
      }
    }

    return _buildFallbackSummary(user);
  }

  Map<String, String> _headers(String token) => <String, String>{
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  User? _readCachedUser(SharedPreferences prefs) {
    final rawUser = prefs.getString('user');
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map) {
        return User.fromJson(
          decoded.map(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      // Ignore malformed cached user payloads.
    }

    return null;
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _extractUserPayload(Map<String, dynamic> decoded) {
    final directUser = decoded['user'];
    if (directUser is Map<String, dynamic>) {
      return directUser;
    }
    if (directUser is Map) {
      return directUser.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }
    return decoded;
  }

  Map<String, dynamic> _composeReferralPayload(Map<String, dynamic> source) {
    final composed = <String, dynamic>{}..addAll(source);

    for (final key in <String>[
      'data',
      'summary',
      'stats',
      'referral',
      'referralSummary',
    ]) {
      final nested = source[key];
      if (nested is Map<String, dynamic>) {
        composed.addAll(nested);
      } else if (nested is Map) {
        composed.addAll(
          nested.map(
            (dynamic nestedKey, dynamic value) =>
                MapEntry<String, dynamic>(nestedKey.toString(), value),
          ),
        );
      }
    }

    return composed;
  }

  bool _hasReferralFields(Map<String, dynamic> payload) {
    const keys = <String>[
      'referralCode',
      'inviteCode',
      'refCode',
      'referralLink',
      'inviteLink',
      'shareLink',
      'totalInvites',
      'totalReferrals',
      'successfulInvites',
      'successfulReferrals',
      'pendingInvites',
      'pendingReferrals',
      'totalEarned',
      'earnedAmount',
      'recentInvites',
      'recentReferrals',
      'invites',
      'referrals',
    ];

    return keys.any(payload.containsKey);
  }

  ReferralSummary _buildSummaryFromPayload(
    Map<String, dynamic> payload,
    User user,
  ) {
    final recentInvites = _readList(payload, const <String>[
      'recentInvites',
      'recentReferrals',
      'invites',
      'referrals',
    ]).map(_parseInviteActivity).whereType<ReferralInviteActivity>().toList();

    final computedSuccessfulCount = recentInvites
        .where((invite) => invite.isSuccessful)
        .length;
    final totalInvites = _readInt(payload, const <String>[
      'totalInvites',
      'totalReferrals',
      'referralCount',
    ], fallback: recentInvites.length);
    final successfulInvites = _readInt(payload, const <String>[
      'successfulInvites',
      'successfulReferrals',
      'completedReferrals',
      'convertedReferrals',
    ], fallback: computedSuccessfulCount);
    final pendingInvites = _readInt(payload, const <String>[
      'pendingInvites',
      'pendingReferrals',
    ], fallback: math.max(totalInvites - successfulInvites, 0));

    return ReferralSummary(
      inviterName: _buildInviterName(user),
      referralCode: _readString(payload, const <String>[
        'referralCode',
        'inviteCode',
        'refCode',
      ], fallback: _buildFallbackCode(user)),
      referralLink: _readOptionalString(payload, const <String>[
        'referralLink',
        'inviteLink',
        'shareLink',
      ]),
      totalInvites: totalInvites,
      successfulInvites: successfulInvites,
      pendingInvites: pendingInvites,
      totalEarned: _readDouble(payload, const <String>[
        'totalEarned',
        'earnedAmount',
        'rewardEarned',
        'totalRewards',
      ]),
      rewardPerReferral: _readDouble(payload, const <String>[
        'rewardPerReferral',
        'bonusPerReferral',
        'referralReward',
        'rewardAmount',
      ]),
      recentInvites: recentInvites,
      isFallback: false,
    );
  }

  ReferralSummary _buildFallbackSummary(User user) {
    return ReferralSummary(
      inviterName: _buildInviterName(user),
      referralCode: _buildFallbackCode(user),
      referralLink: null,
      totalInvites: 0,
      successfulInvites: 0,
      pendingInvites: 0,
      totalEarned: 0,
      rewardPerReferral: 0,
      recentInvites: const <ReferralInviteActivity>[],
      isFallback: true,
    );
  }

  ReferralInviteActivity? _parseInviteActivity(dynamic rawInvite) {
    if (rawInvite is String) {
      return ReferralInviteActivity(
        name: rawInvite,
        contactHint: '',
        status: 'Pending',
        rewardAmount: 0,
        invitedAt: null,
      );
    }

    if (rawInvite is! Map) {
      return null;
    }

    final invite = rawInvite.map(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    final email = _readOptionalString(invite, const <String>[
      'email',
      'emailAddress',
    ]);
    final phone = _readOptionalString(invite, const <String>[
      'phoneNumber',
      'phone',
      'mobile',
    ]);
    final contactHint = _maskContact(email, phone);

    return ReferralInviteActivity(
      name: _readString(invite, const <String>[
        'name',
        'fullName',
        'displayName',
        'firstName',
      ], fallback: contactHint.isEmpty ? 'Invitation sent' : contactHint),
      contactHint: contactHint,
      status: _readString(invite, const <String>[
        'status',
        'state',
      ], fallback: 'Pending'),
      rewardAmount: _readDouble(invite, const <String>[
        'rewardAmount',
        'earnedAmount',
        'bonus',
        'reward',
      ]),
      invitedAt: _readDate(invite, const <String>[
        'invitedAt',
        'createdAt',
        'joinedAt',
        'updatedAt',
      ]),
    );
  }

  String _buildInviterName(User user) {
    final fullName = '${user.firstName} ${user.lastName}'.trim();
    return fullName.isEmpty ? 'A NaijaGo member' : fullName;
  }

  String _buildFallbackCode(User user) {
    final seedName = '${user.firstName}${user.lastName}'
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final seedId = (user.id.isNotEmpty ? user.id : user.email)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final prefixSource = seedName.isEmpty ? 'NAIJAGO' : seedName;
    final prefix = prefixSource.length > 6
        ? prefixSource.substring(0, 6)
        : prefixSource.padRight(6, 'X');
    final suffix = seedId.length > 4
        ? seedId.substring(seedId.length - 4)
        : seedId.padLeft(4, '0');

    return '$prefix$suffix';
  }

  String _readString(
    Map<String, dynamic> payload,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  String? _readOptionalString(Map<String, dynamic> payload, List<String> keys) {
    final value = _readString(payload, keys);
    return value.isEmpty ? null : value;
  }

  int _readInt(
    Map<String, dynamic> payload,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = payload[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String && value.trim().isNotEmpty) {
        final cleaned = value.replaceAll(',', '').trim();
        final parsed = int.tryParse(cleaned);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }

  double _readDouble(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final cleaned = value.replaceAll(',', '').trim();
        final parsed = double.tryParse(cleaned);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  DateTime? _readDate(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      final parsed = _parseDate(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is Map && value.containsKey(r'$date')) {
      final rawDate = value[r'$date'];
      if (rawDate is String) {
        return DateTime.tryParse(rawDate);
      }
    }
    return null;
  }

  List<dynamic> _readList(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is List) {
        return value;
      }
    }
    return const <dynamic>[];
  }

  String _maskContact(String? email, String? phone) {
    if (email != null && email.isNotEmpty) {
      final parts = email.split('@');
      if (parts.length == 2) {
        final local = parts.first;
        if (local.length <= 2) {
          return email;
        }
        final maskLength = math.max(local.length - 2, 1);
        final maskedCharacters = List<String>.filled(maskLength, '*').join();
        final maskedLocal = '${local.substring(0, 2)}$maskedCharacters';
        return '$maskedLocal@${parts.last}';
      }
      return email;
    }

    if (phone != null && phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\s+'), '');
      if (digits.length <= 4) {
        return digits;
      }
      return '${digits.substring(0, 3)}****${digits.substring(digits.length - 2)}';
    }

    return '';
  }
}
