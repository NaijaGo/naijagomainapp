class ReferralSummary {
  static const String _publicReferralHost = 'naijagoapp.com';
  static const String _publicReferralPath = '/signup';

  final String inviterName;
  final String referralCode;
  final String? referralLink;
  final int totalInvites;
  final int successfulInvites;
  final int pendingInvites;
  final double totalEarned;
  final double rewardPerReferral;
  final List<ReferralInviteActivity> recentInvites;
  final bool isFallback;

  const ReferralSummary({
    required this.inviterName,
    required this.referralCode,
    required this.referralLink,
    required this.totalInvites,
    required this.successfulInvites,
    required this.pendingInvites,
    required this.totalEarned,
    required this.rewardPerReferral,
    required this.recentInvites,
    required this.isFallback,
  });

  String get appReferralLink =>
      'naijago://app/signup?ref=${Uri.encodeComponent(referralCode.trim())}';

  String get webReferralLink => Uri.https(
    _publicReferralHost,
    _publicReferralPath,
    <String, String>{'ref': referralCode.trim()},
  ).toString();

  String get shareLink {
    final trimmedLink = referralLink?.trim();
    if (trimmedLink != null && trimmedLink.isNotEmpty) {
      final parsed = Uri.tryParse(trimmedLink);
      if (parsed != null && parsed.hasScheme) {
        return trimmedLink;
      }
    }
    return webReferralLink;
  }

  String get shareMessage {
    final trimmedName = inviterName.trim();
    final intro = trimmedName.isEmpty
        ? 'Join me on NaijaGo.'
        : '$trimmedName invited you to join NaijaGo.';
    final codeInstruction = 'Use referral code $referralCode when you sign up.';
    return '$intro $codeInstruction Sign up here: $shareLink';
  }
}

class ReferralInviteActivity {
  final String name;
  final String contactHint;
  final String status;
  final double rewardAmount;
  final DateTime? invitedAt;

  const ReferralInviteActivity({
    required this.name,
    required this.contactHint,
    required this.status,
    required this.rewardAmount,
    required this.invitedAt,
  });

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (contactHint.trim().isNotEmpty) {
      return contactHint.trim();
    }
    return 'Invitation sent';
  }

  String get normalizedStatus {
    final value = status.trim();
    return value.isEmpty ? 'Pending' : value;
  }

  bool get isSuccessful {
    final value = normalizedStatus.toLowerCase();
    return value.contains('success') ||
        value.contains('complete') ||
        value.contains('joined') ||
        value.contains('reward') ||
        value.contains('verified') ||
        value.contains('converted');
  }

  bool get isPending {
    final value = normalizedStatus.toLowerCase();
    return value.contains('pending') ||
        value.contains('sent') ||
        value.contains('invite') ||
        value.contains('waiting');
  }
}
