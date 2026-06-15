/// Outcome of an in-app purchase attempt, surfaced to the store UI.
enum SBBillingStatus { success, cancelled, pending, unavailable, notFound, error }

class SBBillingOutcome {
  const SBBillingOutcome(this.status, {this.message, this.walletBalance});

  final SBBillingStatus status;
  final String? message;
  final double? walletBalance;

  bool get isSuccess => status == SBBillingStatus.success;

  static const SBBillingOutcome unavailable = SBBillingOutcome(
    SBBillingStatus.unavailable,
    message: 'Bu cihazda mağaza içi satın alma kullanılamıyor.',
  );
}
