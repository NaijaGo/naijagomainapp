import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/referral_summary.dart';
import '../../services/referral_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tech_glow_background.dart';

const Color whiteBackground = Colors.white;
const Color brandSoftText = Color(0xFFF4F8FF);
const Color brandMutedText = Color(0xFFD5E0F2);
const Color highlightGreen = Color(0xFF61F3AE);

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _referralService = ReferralService();
  final NumberFormat _wholeCurrencyFormatter = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );
  final NumberFormat _decimalCurrencyFormatter = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  bool _isLoading = true;
  String? _errorMessage;
  ReferralSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadReferralSummary();
  }

  Future<void> _loadReferralSummary({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final summary = await _referralService.fetchReferralSummary();
      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      final message = _formatErrorMessage(error);
      if (!mounted) {
        return;
      }

      if (!showLoader && _summary != null) {
        _showSnack(message);
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechGlowBackground(
      showCommerceIcons: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Referral Program',
            style: TextStyle(color: brandSoftText),
          ),
          iconTheme: const IconThemeData(color: brandSoftText),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: whiteBackground),
              )
            : _summary == null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: () => _loadReferralSummary(showLoader: false),
                color: AppTheme.primaryNavy,
                backgroundColor: whiteBackground,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _buildHeroCard(_summary!),
                    const SizedBox(height: 18),
                    if (_summary!.isFallback) ...[
                      _buildNoticeCard(),
                      const SizedBox(height: 18),
                    ],
                    _buildStatsGrid(_summary!),
                    const SizedBox(height: 18),
                    _buildCodeCard(_summary!),
                    const SizedBox(height: 18),
                    _buildHowItWorksCard(_summary!),
                    const SizedBox(height: 18),
                    _buildRecentActivityCard(_summary!),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Pull down to refresh your referral activity.',
                        style: TextStyle(
                          color: brandMutedText.withValues(alpha: 0.88),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildSurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 52,
                color: AppTheme.dangerRed,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage ?? 'Unable to load referral details right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.secondaryBlack,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _loadReferralSummary(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(ReferralSummary summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepNavy,
            AppTheme.primaryNavy,
            const Color(0xFF0E7C66),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.group_add_outlined,
                  color: whiteBackground,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite friends to NaijaGo',
                      style: TextStyle(
                        color: whiteBackground,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.isFallback
                          ? 'Your invite code is ready to share right away. Reward totals will start appearing here as live referral data becomes available.'
                          : 'Track your invites, conversions, and rewards from one polished dashboard.',
                      style: TextStyle(
                        color: brandMutedText.withValues(alpha: 0.96),
                        fontSize: 14.2,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.rewardPerReferral > 0) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                '${_formatCurrency(summary.rewardPerReferral)} per successful referral',
                style: const TextStyle(
                  color: whiteBackground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroMetric(
                label: 'Successful',
                value: '${summary.successfulInvites}',
              ),
              _buildHeroMetric(
                label: 'Total earned',
                value: _formatCurrency(summary.totalEarned),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _inviteViaSms,
              style: ElevatedButton.styleFrom(
                backgroundColor: whiteBackground,
                foregroundColor: AppTheme.deepNavy,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Invite via SMS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: brandMutedText.withValues(alpha: 0.92),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: whiteBackground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return _buildSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: highlightGreen.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.info_outline, color: AppTheme.primaryNavy),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sharing is live',
                  style: TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your invite code is ready to use now. This screen will automatically show live referral counts and rewards once the backend provides those metrics.',
                  style: TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ReferralSummary summary) {
    final items = <_ReferralStat>[
      _ReferralStat(
        label: 'Invites sent',
        value: '${summary.totalInvites}',
        icon: Icons.send_outlined,
        accent: AppTheme.accentBlue,
      ),
      _ReferralStat(
        label: 'Joined',
        value: '${summary.successfulInvites}',
        icon: Icons.verified_outlined,
        accent: highlightGreen,
      ),
      _ReferralStat(
        label: 'Pending',
        value: '${summary.pendingInvites}',
        icon: Icons.timelapse_outlined,
        accent: const Color(0xFFF59E0B),
      ),
      _ReferralStat(
        label: 'Earned',
        value: _formatCurrency(summary.totalEarned),
        icon: Icons.payments_outlined,
        accent: const Color(0xFF10B981),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final cardWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) =>
                    SizedBox(width: cardWidth, child: _buildStatCard(item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_ReferralStat item) {
    return _buildSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(ReferralSummary summary) {
    return _buildSectionCard(
      title: 'Your referral code',
      subtitle:
          'Share this code with friends so they can use it during sign-up.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.softGrey,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: SelectableText(
              summary.referralCode,
              style: const TextStyle(
                color: AppTheme.primaryNavy,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildActionRow(
            primaryButton: ElevatedButton.icon(
              onPressed: _copyCode,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy code'),
            ),
            secondaryButton: OutlinedButton.icon(
              onPressed: _copyInviteText,
              icon: const Icon(Icons.content_paste_go_outlined),
              label: const Text('Copy invite text'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.softGrey.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Referral link',
                  style: TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  summary.shareLink,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _copyReferralLink,
                  icon: const Icon(Icons.link_outlined),
                  label: const Text('Copy link'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite message preview',
                  style: TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.shareMessage,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard(ReferralSummary summary) {
    return _buildSectionCard(
      title: 'How it works',
      subtitle: 'A simple flow your users can understand in seconds.',
      child: Column(
        children: [
          _buildStepTile(
            step: '1',
            title: 'Share your code',
            description:
                'Copy your code, use the ready-made invite text, or send it directly by SMS.',
          ),
          const SizedBox(height: 12),
          _buildStepTile(
            step: '2',
            title: 'Your friend signs up',
            description:
                'They create their account on NaijaGo and apply your referral code during registration.',
          ),
          const SizedBox(height: 12),
          _buildStepTile(
            step: '3',
            title: 'Track rewards here',
            description: summary.rewardPerReferral > 0
                ? 'Each successful referral can unlock ${_formatCurrency(summary.rewardPerReferral)} in rewards, and this screen will keep your totals updated.'
                : 'This dashboard keeps your invite progress, reward totals, and recent activity in one place.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile({
    required String step,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softGrey,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: whiteBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(ReferralSummary summary) {
    return _buildSectionCard(
      title: 'Recent referral activity',
      subtitle:
          'Keep an eye on who has joined and which invites are still pending.',
      child: summary.recentInvites.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.softGrey,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    color: AppTheme.mutedText,
                    size: 42,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No referrals yet',
                    style: TextStyle(
                      color: AppTheme.secondaryBlack,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Start sharing your invite code and your referral activity will appear here automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: summary.recentInvites
                  .take(6)
                  .map(_buildInviteTile)
                  .toList(),
            ),
    );
  }

  Widget _buildInviteTile(ReferralInviteActivity invite) {
    final subtitleParts = <String>[
      if (invite.contactHint.isNotEmpty &&
          invite.contactHint != invite.displayName)
        invite.contactHint,
      _formatInviteDate(invite.invitedAt),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softGrey,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                invite.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.displayName,
                  style: const TextStyle(
                    color: AppTheme.secondaryBlack,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitleParts.join('  •  '),
                  style: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 12.8,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusChip(invite.normalizedStatus),
              ],
            ),
          ),
          if (invite.rewardAmount > 0) ...[
            const SizedBox(width: 12),
            Text(
              _formatCurrency(invite.rewardAmount),
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final value = status.toLowerCase();
    Color backgroundColor = const Color(0xFFEFF6FF);
    Color textColor = AppTheme.accentBlue;

    if (value.contains('success') ||
        value.contains('complete') ||
        value.contains('joined') ||
        value.contains('reward') ||
        value.contains('verified')) {
      backgroundColor = highlightGreen.withValues(alpha: 0.14);
      textColor = const Color(0xFF0E8A61);
    } else if (value.contains('pending') ||
        value.contains('sent') ||
        value.contains('invite')) {
      backgroundColor = const Color(0xFFFFF7E8);
      textColor = const Color(0xFFB7791F);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.secondaryBlack,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: whiteBackground.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildActionRow({
    required Widget primaryButton,
    required Widget secondaryButton,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: primaryButton),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: secondaryButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primaryButton),
            const SizedBox(width: 12),
            Expanded(child: secondaryButton),
          ],
        );
      },
    );
  }

  Future<void> _copyCode() async {
    final code = _summary?.referralCode;
    if (code == null || code.isEmpty) {
      return;
    }

    await _copyToClipboard(code, 'Referral code copied.');
  }

  Future<void> _copyInviteText() async {
    final text = _summary?.shareMessage;
    if (text == null || text.isEmpty) {
      return;
    }

    await _copyToClipboard(text, 'Invite text copied.');
  }

  Future<void> _copyReferralLink() async {
    final link = _summary?.shareLink;
    if (link == null || link.isEmpty) {
      return;
    }

    await _copyToClipboard(link, 'Referral link copied.');
  }

  Future<void> _inviteViaSms() async {
    final summary = _summary;
    if (summary == null) {
      return;
    }

    final smsUri = Uri.parse(
      'sms:?body=${Uri.encodeComponent(summary.shareMessage)}',
    );

    try {
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _copyToClipboard(
          summary.shareMessage,
          'SMS app unavailable. Invite text copied instead.',
        );
      }
    } catch (_) {
      await _copyToClipboard(
        summary.shareMessage,
        'SMS app unavailable. Invite text copied instead.',
      );
    }
  }

  Future<void> _copyToClipboard(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showSnack(message);
  }

  String _formatCurrency(double amount) {
    if (amount % 1 == 0) {
      return _wholeCurrencyFormatter.format(amount);
    }
    return _decimalCurrencyFormatter.format(amount);
  }

  String _formatInviteDate(DateTime? date) {
    if (date == null) {
      return 'Awaiting signup';
    }
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _formatErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReferralStat {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _ReferralStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
}
