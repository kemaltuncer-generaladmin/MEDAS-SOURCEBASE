import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../sourcebase_api_client.dart';
import 'sb_billing_models.dart';

/// Native in-app billing — Google Play only. The verified Play purchase token
/// is redeemed server-side (`redeem_play_purchase` / `redeem_play_subscription`)
/// which validates it against the Google Play Developer API and grants the
/// shared MedasiCoin / storage entitlement. On any non-Android platform this
/// reports unavailable so the store falls back to the live web checkout.
final _SBBillingManager _manager = _SBBillingManager();

Future<bool> isAvailable() => _manager.available();

Future<SBBillingOutcome> buy({
  required String productId,
  required bool isSubscription,
}) =>
    _manager.buy(productId: productId, isSubscription: isSubscription);

Future<void> restore() => _manager.restore();

class _SBBillingManager {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<SBBillingOutcome>> _pending = {};
  final Set<String> _subscriptionProducts = {};

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _ensureListening() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (_) {},
    );
  }

  Future<bool> available() async {
    if (!_isAndroid) return false;
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<SBBillingOutcome> buy({
    required String productId,
    required bool isSubscription,
  }) async {
    if (!_isAndroid) return SBBillingOutcome.unavailable;
    if (!await available()) return SBBillingOutcome.unavailable;
    _ensureListening();

    final ProductDetailsResponse response =
        await _iap.queryProductDetails({productId});
    if (response.error != null) {
      return SBBillingOutcome(SBBillingStatus.error,
          message: 'Ürün bilgisi alınamadı: ${response.error!.message}');
    }
    if (response.productDetails.isEmpty) {
      return const SBBillingOutcome(SBBillingStatus.notFound,
          message: 'Ürün mağazada bulunamadı. Lütfen daha sonra dene.');
    }

    final product = response.productDetails.first;
    final completer = Completer<SBBillingOutcome>();
    _pending[productId] = completer;
    if (isSubscription) _subscriptionProducts.add(productId);

    final param = PurchaseParam(productDetails: product);
    try {
      if (isSubscription) {
        await _iap.buyNonConsumable(purchaseParam: param);
      } else {
        await _iap.buyConsumable(purchaseParam: param);
      }
    } catch (error) {
      _pending.remove(productId);
      return SBBillingOutcome(SBBillingStatus.error,
          message: 'Satın alma başlatılamadı: $error');
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending.remove(productId);
        return const SBBillingOutcome(SBBillingStatus.pending,
            message:
                'Satın alma işleniyor. Tamamlanınca bakiyene yansıyacak.');
      },
    );
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          _resolve(purchase.productID,
              const SBBillingOutcome(SBBillingStatus.cancelled));
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          _resolve(
            purchase.productID,
            SBBillingOutcome(SBBillingStatus.error,
                message: purchase.error?.message ?? 'Satın alma tamamlanamadı.'),
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(purchase);
          break;
      }
    }
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    final isSub = _subscriptionProducts.contains(purchase.productID);
    try {
      final result = await SourceBaseApiClient.shared.redeemPlayPurchase(
        productId: purchase.productID,
        purchaseToken: purchase.verificationData.serverVerificationData,
        isSubscription: isSub,
      );
      final balance = _asDouble(result['wallet_balance']);
      _resolve(
        purchase.productID,
        SBBillingOutcome(SBBillingStatus.success,
            message: 'Satın alma tamamlandı.', walletBalance: balance),
      );
    } catch (error) {
      _resolve(
        purchase.productID,
        SBBillingOutcome(SBBillingStatus.error,
            message: error is SourceBaseApiException
                ? error.message
                : 'Satın alma doğrulanamadı. Destek ile iletişime geç.'),
      );
    } finally {
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _resolve(String productId, SBBillingOutcome outcome) {
    final completer = _pending.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }

  Future<void> restore() async {
    if (!_isAndroid) return;
    _ensureListening();
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
