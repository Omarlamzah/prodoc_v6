import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/api_providers.dart';

/// Signup page where clients use the referral link (must match Next.js route).
const String _kReferralSignupBaseUrl = 'https://prodoc.ma/reserve_mon_platform';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  bool _loadingCode = true;
  bool _loadingHistory = true;
  bool _applying = false;
  bool _validating = false;
  Map<String, dynamic>? _myCode;
  Map<String, dynamic>? _history;
  String? _errorCode;
  String? _errorHistory;

  final TextEditingController _applyCodeController = TextEditingController();
  bool? _codeValid;
  String? _referrerName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _applyCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingCode = true;
      _loadingHistory = true;
      _errorCode = null;
      _errorHistory = null;
    });

    final referralService = ref.read(referralServiceProvider);

    final codeResult = await referralService.getMyReferralCode();
    codeResult.when(
      success: (data) {
        if (mounted) {
          setState(() {
            _myCode = data;
            _loadingCode = false;
            _errorCode = null;
          });
        }
      },
      failure: (msg) {
        if (mounted) {
          setState(() {
            _loadingCode = false;
            _errorCode = msg;
          });
        }
      },
    );

    final historyResult = await referralService.getReferralHistory();
    historyResult.when(
      success: (data) {
        if (mounted) {
          setState(() {
            _history = data;
            _loadingHistory = false;
            _errorHistory = null;
          });
        }
      },
      failure: (msg) {
        if (mounted) {
          setState(() {
            _loadingHistory = false;
            _errorHistory = msg;
          });
        }
      },
    );
  }

  Future<void> _validateCode(String code) async {
    if (code.length != 8) {
      setState(() {
        _codeValid = null;
        _referrerName = null;
      });
      return;
    }
    setState(() => _validating = true);
    final result = await ref.read(referralServiceProvider).validateReferralCode(code);
    if (!mounted) return;
    result.when(
      success: (data) {
        setState(() {
          _codeValid = data['valid'] == true;
          _referrerName = data['referrer_name']?.toString();
          _validating = false;
        });
      },
      failure: (_) {
        setState(() {
          _codeValid = false;
          _referrerName = null;
          _validating = false;
        });
      },
    );
  }

  Future<void> _applyCode() async {
    final code = _applyCodeController.text.trim().toUpperCase();
    if (code.length != 8 || _codeValid != true) return;
    setState(() => _applying = true);
    final result = await ref.read(referralServiceProvider).applyReferralCode(code);
    if (!mounted) return;
    result.when(
      success: (data) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Referral applied!'),
            backgroundColor: Colors.green,
          ),
        );
        _applyCodeController.clear();
        setState(() {
          _codeValid = null;
          _referrerName = null;
          _applying = false;
        });
        _loadData();
      },
      failure: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        setState(() => _applying = false);
      },
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)?.referralCodeCopied ?? 'Copied!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _referralShareUrl {
    final code = _myCode?['referral_code']?.toString() ?? '';
    if (code.isEmpty) return '';
    return '$_kReferralSignupBaseUrl?ref=$code';
  }

  void _shareReferral() {
    final url = _referralShareUrl;
    if (url.isEmpty) return;
    final code = _myCode?['referral_code']?.toString() ?? '';
    final loc = AppLocalizations.of(context);
    final message = (loc?.referralShareMessage ?? 'Use my referral code: %s')
        .replaceAll('%s', code);
    Share.share('$message $url');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc?.referralProgram ?? 'Referral Program',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadingCode || _loadingHistory ? null : _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // My referral code card
            _buildMyCodeCard(theme, loc),
            const SizedBox(height: 20),
            // Apply referral code (only show if no referral received yet)
            if (_history != null &&
                _history!['referral_received'] == null) ...[
              _buildApplyCard(theme, loc),
              const SizedBox(height: 20),
            ],
            // History
            _buildHistoryCard(theme, loc),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCodeCard(ThemeData theme, AppLocalizations? loc) {
    if (_loadingCode) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(loc?.loading ?? 'Loading...'),
              ],
            ),
          ),
        ),
      );
    }
    if (_errorCode != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text(_errorCode!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    final rewards = _myCode?['rewards'] as Map<String, dynamic>?;
    final stats = _myCode?['stats'] as Map<String, dynamic>?;
    final daysReferrer = rewards?['days_referrer'] ?? 120;
    final daysReferred = rewards?['days_referred'] ?? 90;
    final code = _myCode?['referral_code']?.toString() ?? '—';
    final url = _referralShareUrl; // https://prodoc.ma/reserve_mon_platform?ref=CODE

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  loc?.referralShareAndEarn ?? 'Share & Earn',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (loc?.referralYouEarnDays ?? 'You earn %s days').replaceAll('%s', '$daysReferrer'),
              style: GoogleFonts.poppins(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
            Text(
              (loc?.referralFriendGetsDays ?? 'Your friend gets %s days').replaceAll('%s', '$daysReferred'),
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Text(
              loc?.referralYourCode ?? 'Your referral code',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      code,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _copyToClipboard(code),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(url),
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: Text(loc?.referralCopyLink ?? 'Copy link'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _shareReferral,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(loc?.referralShare ?? 'Share'),
                ),
              ],
            ),
            if (stats != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatChip(
                    theme,
                    loc?.referralReferrals ?? 'Referrals',
                    '${stats['referrals_given'] ?? 0}',
                    Icons.people_rounded,
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    theme,
                    loc?.referralPendingDays ?? 'Pending days',
                    '${stats['pending_reward_days'] ?? 0}',
                    Icons.schedule_rounded,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyCard(ThemeData theme, AppLocalizations? loc) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_card_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  loc?.referralApplyCode ?? 'Apply referral code',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc?.referralHaveCode ?? 'Have a referral code? Enter it to get free subscription days.',
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _applyCodeController,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: loc?.referralEnterCode ?? 'Enter 8-character code',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _validating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _codeValid == true
                        ? Icon(Icons.check_circle_rounded, color: Colors.green.shade700)
                        : _codeValid == false && _applyCodeController.text.length == 8
                            ? Icon(Icons.cancel_rounded, color: theme.colorScheme.error)
                            : null,
              ),
              onChanged: (v) {
                setState(() {
                  _codeValid = null;
                  _referrerName = null;
                });
                if (v.length == 8) _validateCode(v);
              },
            ),
            if (_codeValid == true && _referrerName != null) ...[
              const SizedBox(height: 8),
              Text(
                '${loc?.referralValidCode ?? 'Valid code from'} $_referrerName',
                style: GoogleFonts.poppins(color: Colors.green.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _applying || _codeValid != true || _applyCodeController.text.length != 8
                    ? null
                    : _applyCode,
                icon: _applying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(_applying
                    ? (loc?.referralApplying ?? 'Applying...')
                    : (loc?.referralApplyCode ?? 'Apply code')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ThemeData theme, AppLocalizations? loc) {
    if (_loadingHistory) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(loc?.loading ?? 'Loading...'),
              ],
            ),
          ),
        ),
      );
    }
    if (_errorHistory != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text(_errorHistory!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final referralsGiven = _history?['referrals_given'] as List<dynamic>? ?? [];
    final referralReceived = _history?['referral_received'] as Map<String, dynamic>?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  loc?.referralHistory ?? 'Referral history',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (referralReceived != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc?.referralYouUsedCode ?? 'You used a referral code',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${loc?.referralReferredBy ?? 'From'}: ${referralReceived['referrer_tenant']?['name'] ?? '—'}',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    Text(
                      '${loc?.referralReward ?? 'Reward'}: ${referralReceived['reward_days'] ?? 0} ${loc?.referralDays ?? 'days'}',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              loc?.referralPeopleYouReferred ?? 'People you referred',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (referralsGiven.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    loc?.referralNoReferralsYet ?? 'No referrals yet. Share your code!',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...referralsGiven.map((r) {
                final map = r as Map<String, dynamic>;
                final tenant = map['referred_tenant'] as Map<String, dynamic>?;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                  ),
                  title: Text(tenant?['name']?.toString() ?? '—', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${map['reward_days'] ?? 0} ${loc?.referralDays ?? 'days'} • ${map['created_at'] ?? ''}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
