import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Result of a purchase or restore attempt.
class PurchaseResult {
  final bool isSuccess;
  final bool isCancelled;
  final bool isError;
  final String? errorMessage;

  const PurchaseResult._({
    required this.isSuccess,
    required this.isCancelled,
    required this.isError,
    this.errorMessage,
  });

  factory PurchaseResult.success() => const PurchaseResult._(
        isSuccess: true,
        isCancelled: false,
        isError: false,
      );

  factory PurchaseResult.cancelled() => const PurchaseResult._(
        isSuccess: false,
        isCancelled: true,
        isError: false,
      );

  factory PurchaseResult.error(String message) => PurchaseResult._(
        isSuccess: false,
        isCancelled: false,
        isError: true,
        errorMessage: message,
      );
}

/// Singleton service that manages in-app subscription state via RevenueCat.
///
/// Exposes [isPremium] which mirrors the `premium` entitlement on RevenueCat
/// and notifies listeners whenever the subscription state changes.
class PremiumService extends ChangeNotifier {
  PremiumService._internal();
  static final PremiumService _instance = PremiumService._internal();
  static PremiumService get instance => _instance;
  factory PremiumService() => _instance;

  // ---- RevenueCat API keys ---------------------------------------------------
  // Replace with real keys from the RevenueCat dashboard before shipping.
  static const String _androidApiKey = 'goog_YOUR_ANDROID_KEY';
  static const String _iosApiKey = 'appl_YOUR_IOS_KEY';

  // ---- Product identifiers ---------------------------------------------------
  static const String monthlyProductId = 'speedtype_premium_monthly';
  static const String yearlyProductId = 'speedtype_premium_yearly';
  static const String _entitlementId = 'premium';

  bool _isPremium = false;
  bool _initialized = false;
  CustomerInfo? _customerInfo;

  /// Whether the current user has an active premium subscription.
  bool get isPremium => _isPremium;

  /// The latest [CustomerInfo] snapshot from RevenueCat, if any.
  CustomerInfo? get customerInfo => _customerInfo;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Configure RevenueCat with the platform-specific API key, log in the
  /// current Firebase user (if any), load [CustomerInfo] and subscribe to
  /// updates.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Purchases.setLogLevel(
        kReleaseMode ? LogLevel.warn : LogLevel.debug,
      );

      final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      // Identify the user to RevenueCat via their Firebase uid so purchases
      // travel with the account across devices.
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        try {
          await Purchases.logIn(firebaseUser.uid);
        } catch (e) {
          debugPrint('PremiumService: logIn failed: $e');
        }
      }

      await refreshPremiumStatus();

      Purchases.addCustomerInfoUpdateListener((CustomerInfo info) {
        _updateFromCustomerInfo(info);
      });
    } catch (e) {
      debugPrint('PremiumService: initialize failed: $e');
    }
  }

  /// Refresh the premium status by fetching the latest [CustomerInfo].
  Future<void> refreshPremiumStatus() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _updateFromCustomerInfo(info);
    } catch (e) {
      debugPrint('PremiumService: refreshPremiumStatus failed: $e');
    }
  }

  void _updateFromCustomerInfo(CustomerInfo info) {
    _customerInfo = info;
    final active = info.entitlements.active[_entitlementId];
    final newValue = active != null && active.isActive;
    if (newValue != _isPremium) {
      _isPremium = newValue;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase flows
  // ---------------------------------------------------------------------------

  /// Purchase the monthly subscription.
  Future<PurchaseResult> purchaseMonthly() => _purchase(monthlyProductId);

  /// Purchase the yearly subscription.
  Future<PurchaseResult> purchaseYearly() => _purchase(yearlyProductId);

  Future<PurchaseResult> _purchase(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        return PurchaseResult.error('No offerings available');
      }

      Package? target;
      for (final package in current.availablePackages) {
        if (package.storeProduct.identifier == productId ||
            package.storeProduct.identifier.startsWith(productId)) {
          target = package;
          break;
        }
      }

      if (target == null) {
        return PurchaseResult.error('Package not found: $productId');
      }

      final result = await Purchases.purchasePackage(target);
      final entitlement = result.entitlements.active[_entitlementId];
      final unlocked = entitlement != null && entitlement.isActive;

      _updateFromCustomerInfo(result);

      if (unlocked) {
        return PurchaseResult.success();
      }
      return PurchaseResult.error('Entitlement not active after purchase');
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled();
      }
      debugPrint('PremiumService: purchase error: ${e.message}');
      return PurchaseResult.error(e.message ?? 'Unknown purchase error');
    } catch (e) {
      debugPrint('PremiumService: purchase failed: $e');
      return PurchaseResult.error(e.toString());
    }
  }

  /// Restore previous purchases for the current user.
  Future<PurchaseResult> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _updateFromCustomerInfo(info);
      if (_isPremium) {
        return PurchaseResult.success();
      }
      return PurchaseResult.error('No active subscription to restore');
    } on PlatformException catch (e) {
      debugPrint('PremiumService: restore error: ${e.message}');
      return PurchaseResult.error(e.message ?? 'Restore failed');
    } catch (e) {
      debugPrint('PremiumService: restore failed: $e');
      return PurchaseResult.error(e.toString());
    }
  }
}
