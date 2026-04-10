import 'package:flutter/material.dart';

import '../../core/services/premium_service.dart';
import '../../core/theme/app_colors.dart';

/// Full screen paywall presenting the SpeedType Premium upsell and handling
/// monthly / yearly purchase flows via [PremiumService].
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const Color _gold = Color(0xFFFFD700);
  static const Color _goldDark = Color(0xFFB8860B);

  bool _isPurchasing = false;
  String? _pendingPlan;

  Future<void> _handlePurchase({required bool yearly}) async {
    if (_isPurchasing) return;
    setState(() {
      _isPurchasing = true;
      _pendingPlan = yearly ? 'yearly' : 'monthly';
    });

    final result = yearly
        ? await PremiumService.instance.purchaseYearly()
        : await PremiumService.instance.purchaseMonthly();

    if (!mounted) return;
    setState(() {
      _isPurchasing = false;
      _pendingPlan = null;
    });

    if (result.isSuccess) {
      _showSnack('Welcome to SpeedType Premium!');
      Navigator.of(context).pop(true);
    } else if (result.isCancelled) {
      // Silent cancel - no feedback needed.
    } else {
      _showSnack(result.errorMessage ?? 'Purchase failed. Please try again.');
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);
    final result = await PremiumService.instance.restorePurchases();
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (result.isSuccess) {
      _showSnack('Purchases restored successfully.');
      Navigator.of(context).pop(true);
    } else {
      _showSnack(result.errorMessage ?? 'No purchases to restore.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Gold gradient header fade
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 260,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _gold,
                      _goldDark,
                      AppColors.background,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // Scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 72,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SpeedType Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unlock the full typing experience',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildComparisonCard(),

                  const SizedBox(height: 28),

                  _buildPlanButton(
                    title: 'Yearly',
                    price: '19,99 €',
                    subtitle: 'Save 45% - Best Value',
                    highlighted: true,
                    onTap: () => _handlePurchase(yearly: true),
                    loading: _isPurchasing && _pendingPlan == 'yearly',
                  ),
                  const SizedBox(height: 12),
                  _buildPlanButton(
                    title: 'Monthly',
                    price: '2,99 €',
                    subtitle: 'Billed monthly',
                    highlighted: false,
                    onTap: () => _handlePurchase(yearly: false),
                    loading: _isPurchasing && _pendingPlan == 'monthly',
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _isPurchasing ? null : _handleRestore,
                      child: const Text(
                        'Restore Purchase',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Subscriptions automatically renew at the end of each '
                    'billing period unless cancelled at least 24 hours before '
                    'the end of the current period. You can manage and cancel '
                    'your subscription anytime in your account settings on '
                    'the App Store or Google Play. By continuing you agree '
                    'to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Close button top-right
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black26,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isPurchasing ? null : () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Comparison table
  // ---------------------------------------------------------------------------

  Widget _buildComparisonCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceVariant, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          _buildComparisonRow('No Ads', free: false, premium: true),
          _buildComparisonRow('2× XP forever', free: false, premium: true),
          _buildComparisonRow('Premium themes', free: false, premium: true),
          _buildComparisonRow('Early access features', free: false, premium: true),
          _buildComparisonRow(
            'Streak freezes',
            freeLabel: '1 / month',
            premiumLabel: 'Unlimited',
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label, {
    bool? free,
    bool? premium,
    String? freeLabel,
    String? premiumLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: freeLabel != null
                  ? Text(
                      freeLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Icon(
                      free == true ? Icons.check_circle : Icons.close,
                      color: free == true
                          ? AppColors.success
                          : AppColors.textMuted,
                      size: 20,
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: premiumLabel != null
                  ? Text(
                      premiumLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(
                      premium == true ? Icons.check_circle : Icons.close,
                      color: premium == true ? _gold : AppColors.textMuted,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Plan buttons
  // ---------------------------------------------------------------------------

  Widget _buildPlanButton({
    required String title,
    required String price,
    required String subtitle,
    required bool highlighted,
    required VoidCallback onTap,
    required bool loading,
  }) {
    final Color bg =
        highlighted ? _gold : AppColors.surface;
    final Color fg =
        highlighted ? Colors.black : AppColors.textPrimary;
    final Color subFg = highlighted
        ? Colors.black87
        : AppColors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      elevation: highlighted ? 8 : 2,
      shadowColor: highlighted ? _gold.withOpacity(0.4) : Colors.black45,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: highlighted
                ? null
                : Border.all(color: AppColors.surfaceVariant, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              else
                Text(
                  price,
                  style: TextStyle(
                    color: fg,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
