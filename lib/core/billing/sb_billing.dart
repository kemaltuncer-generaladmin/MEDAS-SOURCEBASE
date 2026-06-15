import 'sb_billing_models.dart';
import 'sb_billing_stub.dart'
    if (dart.library.io) 'sb_billing_native.dart' as impl;

export 'sb_billing_models.dart';

/// Platform-agnostic entry point for in-app billing. On Android this drives
/// Google Play Billing (with server-side redemption); on web / other platforms
/// it reports unavailable so callers fall back to the live web checkout.
class SBBilling {
  SBBilling._();

  static Future<bool> isAvailable() => impl.isAvailable();

  static Future<SBBillingOutcome> buy({
    required String productId,
    bool isSubscription = false,
  }) =>
      impl.buy(productId: productId, isSubscription: isSubscription);

  static Future<void> restore() => impl.restore();
}
