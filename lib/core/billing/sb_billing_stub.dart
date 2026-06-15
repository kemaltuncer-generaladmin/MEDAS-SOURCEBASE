import 'sb_billing_models.dart';

/// Web / unsupported-platform implementation: native billing is not available,
/// so the store falls back to the live web checkout flow.
Future<bool> isAvailable() async => false;

Future<SBBillingOutcome> buy({
  required String productId,
  required bool isSubscription,
}) async =>
    SBBillingOutcome.unavailable;

Future<void> restore() async {}
