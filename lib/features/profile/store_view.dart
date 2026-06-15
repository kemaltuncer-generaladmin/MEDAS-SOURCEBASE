import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billing/sb_billing.dart';
import '../../core/sb_external_links.dart';
import '../../core/sourcebase_api_client.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import 'sb_storage_product.dart';

/// Port of StoreView ("MC Paketleri") backed by live product and wallet data.
class StoreView extends StatefulWidget {
  const StoreView({super.key});

  @override
  State<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<StoreView> {
  List<MedasiCoinPackage> _packages = [];
  double? _walletBalance;
  String? _walletStatusMessage;
  bool _isLoading = true;
  String? _buyingPackageCode;
  String? _purchaseStatusPackageCode;
  String? _buyInfo;
  bool _isRestoring = false;
  (bool, String)? _restoreNotice;
  SBStorageProduct? _activeStoragePlan;
  String? _buyingStorageCode;
  String? _storageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStoreData());
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);
    final store = context.read<WorkspaceStore>();
    await store.loadWorkspace();
    final client = SourceBaseApiClient.shared;
    final packages = await _loadPackages(client);
    final walletSnapshot = await _loadWallet(client);
    final activeStoragePlan = _storagePlanFromStatus(store.storageStatus);
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _walletBalance = walletSnapshot.$1;
      _walletStatusMessage = walletSnapshot.$2;
      _activeStoragePlan = activeStoragePlan;
      _storageInfo = store.storageStatus.plans.isEmpty
          ? null
          : 'Aktif plan: ${activeStoragePlan?.displayName ?? store.storageStatus.plans.first.productCode}';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(
          'MC Paketleri',
          style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
        ),
      ),
      body: SBPageBackground(
        child: RefreshIndicator(
          onRefresh: _loadStoreData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(SBSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _premiumHeroCard(),
                const SizedBox(height: SBSpacing.lg),
                _walletSummarySection(),
                const SizedBox(height: SBSpacing.lg),
                _storageSection(store),
                const SizedBox(height: SBSpacing.lg),
                if (_isLoading)
                  const SBLoadingState(
                    icon: 'storefront',
                    title: 'Paketler yükleniyor',
                    message: 'MC üretim kredisi paketleri hazırlanıyor...',
                  )
                else if (_packages.isEmpty)
                  SBErrorState(
                    title: 'Paketler yüklenemedi',
                    message:
                        'Paketler şu anda alınamadı. Biraz sonra tekrar deneyebilirsin.',
                    actionLabel: 'Tekrar dene',
                    onAction: _loadStoreData,
                  )
                else ...[
                  Text(
                    'Paketler',
                    style: SBTypography.titleMedium.copyWith(
                      color: SBColors.navy,
                    ),
                  ),
                  const SizedBox(height: SBSpacing.md),
                  for (final package in _packages) ...[
                    _packageTile(package),
                    const SizedBox(height: SBSpacing.md),
                  ],
                  _restoreSection(),
                ],
                _legalFooter(),
                const SizedBox(height: 156),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _premiumHeroCard() {
    return SBCard(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(SBSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: SBColors.selectedBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'MC Paketleri',
                    style: SBTypography.caption.copyWith(color: SBColors.blue),
                  ),
                ),
                const Spacer(),
                SBIcon('creditcard', size: 24, color: SBColors.blue),
              ],
            ),
            const SizedBox(height: SBSpacing.md),
            Text(
              'MC üretim kredisi',
              style: SBTypography.heading2.copyWith(color: SBColors.navy),
            ),
            const SizedBox(height: SBSpacing.md),
            Text(
              'Çalışmalar MC ile hazırlanır. Paket satın alarak üretim bakiyeni artırabilirsin.',
              style: SBTypography.bodyMedium.copyWith(
                color: SBColors.muted,
                height: 1.25,
              ),
            ),
            Divider(color: SBColors.softLine, height: SBSpacing.xl),
            Row(
              children: [
                _metricInfo('creditcard', 'Güvenli', 'Ödeme'),
                _metricInfo('shield.checkered', 'Güvenli', 'Ödeme'),
                _metricInfo('iphone', 'iOS', 'Platform'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricInfo(String icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SBIcon(icon, size: 12, color: SBColors.blue),
              const SizedBox(width: 4),
              Text(
                label,
                style: SBTypography.caption.copyWith(color: SBColors.softText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: SBTypography.labelSmall.copyWith(color: SBColors.navy),
          ),
        ],
      ),
    );
  }

  Widget _walletSummarySection() {
    return SBCard(
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MC bakiyesi',
                    style: SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _walletBalance != null
                        ? '${_walletBalance!.toStringAsFixed(1).replaceAll('.', ',')} MC'
                        : 'Bakiye alınamadı',
                    style: _walletBalance != null
                        ? SBTypography.heading2.copyWith(color: SBColors.navy)
                        : SBTypography.titleMedium.copyWith(
                            color: SBColors.softText,
                          ),
                  ),
                  if (_walletStatusMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _walletStatusMessage!,
                      style: SBTypography.caption.copyWith(
                        color: _walletBalance != null
                            ? SBColors.muted
                            : SBColors.orange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: _loadStoreData,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: SBColors.selectedBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SBIcon('arrow.clockwise', size: 13, color: SBColors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Yenile',
                      style: SBTypography.labelSmall.copyWith(
                        color: SBColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - Storage section

  Widget _storageSection(WorkspaceStore store) {
    final status = store.storageStatus;

    return SBCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIcon(
                'externaldrive.badge.plus',
                size: 18,
                color: SBColors.blue,
              ),
              const SizedBox(width: SBSpacing.sm),
              Text(
                'Depolama',
                style: SBTypography.titleSmall.copyWith(color: SBColors.navy),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          _storageUsageBar(status),
          const SizedBox(height: SBSpacing.md),
          Text(
            'Aylık abonelikle depolama kotanı artır. Tek plan aktif olur. Yükseltme hemen geçerli olur; düşürme ve iptal mağaza kuralı gereği mevcut dönem sonunda devreye girer, o zamana kadar şu anki paketin devam eder.',
            style: SBTypography.caption.copyWith(color: SBColors.muted),
          ),
          const SizedBox(height: SBSpacing.md),
          for (final product in SBStorageProduct.values) ...[
            _storageTile(product),
            const SizedBox(height: SBSpacing.sm),
          ],
          if (_activeStoragePlan != null)
            GestureDetector(
              onTap: () async {
                final ok =
                    await SBExternalLinks.open(SBExternalLinks.webStoreUrl);
                if (!ok && mounted) {
                  context
                      .read<WorkspaceStore>()
                      .toast('Abonelik sayfası açılamadı.');
                }
              },
              child: Row(
                children: [
                  SBIcon('gearshape', size: 13, color: SBColors.blue),
                  const SizedBox(width: SBSpacing.xs),
                  Text(
                    'Aboneliği yönet',
                    style: SBTypography.labelSmall.copyWith(
                      color: SBColors.blue,
                    ),
                  ),
                ],
              ),
            ),
          if (_storageInfo != null) ...[
            const SizedBox(height: SBSpacing.sm),
            Text(
              _storageInfo!,
              style: SBTypography.caption.copyWith(color: SBColors.green),
            ),
          ],
        ],
      ),
    );
  }

  Widget _storageUsageBar(SBStorageStatus status) {
    final barColor = status.isOverQuota
        ? SBColors.red
        : (status.isNearlyFull ? SBColors.orange : SBColors.blue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_byteString(status.usedBytes)} / ${_byteString(status.totalBytes)}',
                style: SBTypography.labelMedium.copyWith(color: SBColors.navy),
              ),
            ),
            if (status.bonusBytes > 0)
              Text(
                '+${_byteString(status.bonusBytes)} abonelik',
                style: SBTypography.caption.copyWith(color: SBColors.green),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: status.usedFraction,
            minHeight: 8,
            backgroundColor: SBColors.field,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        if (status.isOverQuota) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBIcon(
                'exclamationmark.triangle.fill',
                size: 12,
                color: SBColors.red,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Kotan aşıldı. Mevcut dosyaların korunur ama yeni yükleme için plan yükselt veya dosya sil.',
                  style: SBTypography.caption.copyWith(color: SBColors.red),
                ),
              ),
            ],
          ),
        ] else if (status.isNearlyFull) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBIcon(
                'exclamationmark.circle',
                size: 12,
                color: SBColors.orange,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Depolaman neredeyse doldu. Plan yükselterek yer açabilirsin.',
                  style: SBTypography.caption.copyWith(color: SBColors.orange),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _storageTile(SBStorageProduct product) {
    final isBuying = _buyingStorageCode == product.code;
    final active = _activeStoragePlan;
    final isCurrent = active == product;
    final isUpgrade = active != null && product.rank > active.rank;
    final actionLabel = active == null
        ? product.fallbackPriceLabel
        : (isUpgrade ? 'Yükselt' : 'Düşür');
    final tint = isCurrent ? SBColors.green : SBColors.blue;

    return Container(
      padding: const EdgeInsets.all(SBSpacing.sm),
      decoration: BoxDecoration(
        color: SBColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? SBColors.green.withValues(alpha: 0.55)
              : SBColors.softLine,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: SBIcon(product.icon, size: 20, color: tint),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${product.gbLabel} / ay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.titleSmall.copyWith(
                          color: SBColors.navy,
                        ),
                      ),
                    ),
                    if (!isCurrent) ...[
                      const SizedBox(width: SBSpacing.xs),
                      Text(
                        product.fallbackPriceLabel,
                        style: SBTypography.caption.copyWith(
                          color: SBColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isCurrent ? 'Yenileme: 8 Tem 2026' : product.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(
                    color: isCurrent ? SBColors.green : SBColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SBColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Mevcut plan',
                style: SBTypography.labelSmall.copyWith(color: SBColors.green),
              ),
            )
          else
            SBButton(
              actionLabel,
              variant: isUpgrade || active == null
                  ? SBButtonVariant.primary
                  : SBButtonVariant.secondary,
              size: SBButtonSize.small,
              isLoading: isBuying,
              onPressed: () {
                if (active != null && !isUpgrade) {
                  _confirmDowngrade(product);
                } else {
                  _purchaseStorage(product);
                }
              },
            ),
        ],
      ),
    );
  }

  void _confirmDowngrade(SBStorageProduct product) {
    final current = _activeStoragePlan?.displayName ?? 'Mevcut paketin';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paketi düşür'),
        content: Text(
          '$current paketinden ${product.displayName} paketine geçiyorsun. '
          'Mağaza kuralı gereği bu değişiklik mevcut dönem sonunda uygulanır; '
          'o zamana kadar $current paketin devam eder. Şimdi ödeme alınmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _purchaseStorage(product, isDowngrade: true);
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseStorage(
    SBStorageProduct product, {
    bool isDowngrade = false,
  }) async {
    setState(() => _buyingStorageCode = product.code);

    // Prefer native Google Play Billing; fall back to the live web store.
    if (await SBBilling.isAvailable()) {
      final outcome =
          await SBBilling.buy(productId: product.code, isSubscription: true);
      if (!mounted) return;
      setState(() {
        _buyingStorageCode = null;
        _storageInfo = _billingMessage(outcome, product.displayName);
      });
      if (outcome.isSuccess) await _loadStoreData();
      return;
    }

    final opened = await SBExternalLinks.open(SBExternalLinks.webStoreUrl);
    if (!mounted) return;
    setState(() {
      _buyingStorageCode = null;
      _storageInfo = opened
          ? 'Depolama abonelikleri canlı web mağazasında yönetilir. '
              'Açılan sayfadan ${product.displayName} planını tamamlayabilirsin.'
          : 'Web mağazası açılamadı. Lütfen tekrar dene.';
    });
    if (opened) await _loadStoreData();
  }

  String _billingMessage(SBBillingOutcome outcome, String label) {
    switch (outcome.status) {
      case SBBillingStatus.success:
        return '$label tamamlandı. Bakiyen/kotaların güncellendi.';
      case SBBillingStatus.cancelled:
        return 'Satın alma iptal edildi.';
      case SBBillingStatus.pending:
        return outcome.message ?? 'Satın alma işleniyor.';
      case SBBillingStatus.notFound:
        return outcome.message ?? 'Ürün mağazada bulunamadı.';
      case SBBillingStatus.unavailable:
      case SBBillingStatus.error:
        return outcome.message ?? 'Satın alma tamamlanamadı.';
    }
  }

  // MARK: - Packages

  Widget _packageTile(MedasiCoinPackage package) {
    final isBuying = _buyingPackageCode == package.code;
    final hasStatus = _purchaseStatusPackageCode == package.code;
    final isBestValue = package.coin >= 200;
    final priceUnit = package.coin > 0 && package.priceCents > 0
        ? package.priceCents / 100.0 / package.coin
        : null;

    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBestValue) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SBColors.blue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sık kullanılan',
                          style: SBTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: SBSpacing.xs),
                    ],
                    Text(
                      package.title,
                      style: SBTypography.titleMedium.copyWith(
                        color: SBColors.navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: SBSpacing.xs),
                    Text(
                      package.description,
                      style: SBTypography.bodySmall.copyWith(
                        color: SBColors.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: SBColors.selectedBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, size: 16, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Text(
            package.priceLabel,
            style: SBTypography.heading2.copyWith(
              color: SBColors.navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _packageChip('toll', '${package.coin} MC'),
              if (priceUnit != null)
                _packageChip(
                  'tag',
                  '${priceUnit.toStringAsFixed(2)} ${package.currencyDisplay}/MC',
                ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          _packageFeature('Ödeme güvenli sayfada işlenir'),
          const SizedBox(height: SBSpacing.sm),
          _packageFeature('Onaylandığında MC bakiyene eklenir'),
          if (hasStatus && _buyInfo != null) ...[
            const SizedBox(height: SBSpacing.md),
            _paymentNotice('checkmark.circle', SBColors.green, _buyInfo!),
          ],
          const SizedBox(height: SBSpacing.md),
          SBButton(
            isBuying ? 'Onay bekleniyor...' : '${package.coin} MC satın al',
            icon: 'bag',
            variant: SBButtonVariant.primary,
            isLoading: isBuying,
            fullWidth: true,
            onPressed: () => _startPurchase(package),
          ),
        ],
      ),
    );
  }

  Widget _packageChip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: SBColors.selectedBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SBIcon(icon, size: 12, color: SBColors.navy),
          const SizedBox(width: 5),
          Text(
            label,
            style: SBTypography.labelSmall.copyWith(color: SBColors.navy),
          ),
        ],
      ),
    );
  }

  Widget _packageFeature(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: SBColors.selectedBlue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SBIcon('checkmark', size: 10, color: SBColors.blue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: SBTypography.bodySmall.copyWith(
              color: SBColors.navy,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentNotice(String icon, Color color, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SBIcon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: SBTypography.bodySmall.copyWith(
                color: SBColors.navy,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restoreSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _restorePurchases,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SBSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRestoring)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(SBColors.blue),
                    ),
                  )
                else
                  SBIcon(
                    'arrow.counterclockwise',
                    size: 14,
                    color: SBColors.blue,
                  ),
                const SizedBox(width: SBSpacing.sm),
                Text(
                  _isRestoring
                      ? 'Geri yükleniyor...'
                      : 'Satın almalarımı geri yükle',
                  style: SBTypography.labelSmall.copyWith(color: SBColors.blue),
                ),
              ],
            ),
          ),
        ),
        if (_restoreNotice != null)
          _paymentNotice(
            _restoreNotice!.$1
                ? 'checkmark.circle'
                : 'exclamationmark.triangle',
            _restoreNotice!.$1 ? SBColors.green : SBColors.red,
            _restoreNotice!.$2,
          ),
      ],
    );
  }

  Widget _legalFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: SBSpacing.sm),
      child: Column(
        children: [
          Text(
            'Abonelikler otomatik yenilenir. Dönem bitiminden en az 24 saat önce iptal edilmezse aynı fiyattan yenilenir; aboneliğini web mağazası hesap ayarlarından yönetebilir veya iptal edebilirsin.',
            textAlign: TextAlign.center,
            style: SBTypography.caption.copyWith(color: SBColors.softText),
          ),
          const SizedBox(height: SBSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Kullanım Koşulları',
                style: SBTypography.labelSmall.copyWith(color: SBColors.blue),
              ),
              Text(
                ' · ',
                style: SBTypography.labelSmall.copyWith(
                  color: SBColors.softText,
                ),
              ),
              Text(
                'Gizlilik Politikası',
                style: SBTypography.labelSmall.copyWith(color: SBColors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<MedasiCoinPackage>> _loadPackages(
    SourceBaseApiClient client,
  ) async {
    final attempts = [
      (
        schema: null,
        table: 'store_products',
        filterKey: 'is_active',
        filterValue: 'eq.true',
      ),
      (
        schema: null,
        table: 'products',
        filterKey: 'status',
        filterValue: 'eq.published',
      ),
      (
        schema: 'sourcebase',
        table: 'store_products',
        filterKey: 'is_active',
        filterValue: 'eq.true',
      ),
      (
        schema: 'sourcebase',
        table: 'products',
        filterKey: 'status',
        filterValue: 'eq.published',
      ),
    ];

    for (final attempt in attempts) {
      try {
        final rows = await client.selectRows(
          attempt.table,
          schema: attempt.schema,
          query: {'select': '*', attempt.filterKey: attempt.filterValue},
        );
        final products =
            rows
                .map(_packageFromRow)
                .where((product) => product.code.isNotEmpty && product.coin > 0)
                .toList()
              ..sort((a, b) {
                final aRank = a.coin;
                final bRank = b.coin;
                return aRank.compareTo(bRank);
              });
        if (products.isNotEmpty) return products;
      } catch (_) {}
    }
    return const [];
  }

  Future<(double?, String?)> _loadWallet(SourceBaseApiClient client) async {
    try {
      final user = client.currentUser;
      if (user == null || user.id.isEmpty) {
        return (null, 'Oturum doğrulanamadı');
      }

      final profiles = await client.selectRows(
        'profiles',
        query: {
          'select':
              'wallet_balance,medasicoin_balance,coin_balance,credit_balance',
          'id': 'eq.${user.id}',
        },
      );
      if (profiles.isNotEmpty) {
        final row = profiles.first;
        final balance = _firstDouble(row, const [
          'wallet_balance',
          'medasicoin_balance',
          'coin_balance',
          'credit_balance',
        ]);
        if (balance != null) return (balance, null);
      }

      final entitlements = await client.selectRows(
        'wallet_entitlements',
        query: {
          'select': 'remaining_coin_amount',
          'user_id': 'eq.${user.id}',
          'status': 'eq.active',
          'expires_at': 'gt.${DateTime.now().toUtc().toIso8601String()}',
        },
      );
      final balance = entitlements.fold<double>(0, (sum, row) {
        final value = _firstDouble(row, const ['remaining_coin_amount']) ?? 0;
        return sum + value;
      });
      return (balance, null);
    } catch (_) {
      return (null, 'Bakiye alınamadı');
    }
  }

  SBStorageProduct? _storagePlanFromStatus(SBStorageStatus status) {
    for (final plan in status.plans.reversed) {
      final product = SBStorageProduct.fromCode(plan.productCode);
      if (product != null) return product;
    }
    return null;
  }

  MedasiCoinPackage _packageFromRow(Map<String, dynamic> row) {
    final code =
        _firstString(row, const ['code', 'product_code', 'slug']) ?? '';
    final coin =
        _firstInt(row, const [
          'coins',
          'coin',
          'coin_amount',
          'amount',
          'mc_amount',
          'medasicoin_amount',
        ]) ??
        0;
    final priceCents =
        _firstInt(row, const ['price_cents', 'unit_amount']) ??
        _priceAsCents(row['price']) ??
        0;
    final title =
        _firstString(row, const ['title', 'name']) ??
        '${coin > 0 ? coin : ''} MC Paket'.trim();
    final description =
        _firstString(row, const ['description']) ??
        'MC onaylı ödeme sonrası hesabınıza eklenir.';
    return MedasiCoinPackage(
      code: code,
      title: title,
      description: description,
      coin: coin,
      priceCents: priceCents,
      priceLabel: _priceLabel(priceCents),
      currencyDisplay: 'TL',
    );
  }

  String _priceLabel(int priceCents) {
    if (priceCents <= 0) return 'Fiyat alınamadı';
    final amount = priceCents / 100.0;
    final formatted = amount.remainder(1) == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$formatted TL';
  }

  int? _priceAsCents(dynamic value) {
    if (value is int) return value;
    if (value is num) return (value * 100).round();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return (parsed * 100).round();
    }
    return null;
  }

  String? _firstString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _firstDouble(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _startPurchase(MedasiCoinPackage package) async {
    setState(() {
      _buyingPackageCode = package.code;
      _purchaseStatusPackageCode = null;
      _buyInfo = null;
    });
    try {
      // Prefer native Google Play Billing on Android.
      if (await SBBilling.isAvailable()) {
        final outcome = await SBBilling.buy(
            productId: package.code, isSubscription: false);
        if (!mounted) return;
        setState(() {
          _purchaseStatusPackageCode = package.code;
          _buyInfo = _billingMessage(outcome, '${package.coin} MC');
        });
        if (outcome.isSuccess) await _loadStoreData();
        return;
      }

      final result = await SourceBaseApiClient.shared.purchaseMedasiCoin(
        productCode: package.code,
      );
      if (!mounted) return;
      final checkoutUrl = result['checkout_url']?.toString() ?? '';
      if (checkoutUrl.isNotEmpty) {
        final opened = await SBExternalLinks.open(checkoutUrl);
        if (!mounted) return;
        setState(() {
          _purchaseStatusPackageCode = package.code;
          _buyInfo = opened
              ? 'Ödeme sayfası açıldı. Ödeme sonrası MC bakiyene eklenir.'
              : 'Ödeme bağlantısı açılamadı. Web mağazasından deneyebilirsin.';
        });
      } else {
        setState(() {
          _purchaseStatusPackageCode = package.code;
          _buyInfo = 'Satın alma talebi işlendi.';
        });
      }
      await _loadStoreData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _purchaseStatusPackageCode = package.code;
        _buyInfo = error is SourceBaseApiException
            ? error.message
            : 'Satın alma tamamlanamadı.';
      });
    } finally {
      if (mounted) {
        setState(() => _buyingPackageCode = null);
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _restoreNotice = null;
    });
    try {
      if (await SBBilling.isAvailable()) {
        await SBBilling.restore();
      }
      await _loadStoreData();
      if (!mounted) return;
      setState(() {
        _restoreNotice = (
          true,
          'Bakiyen ve aboneliklerin hesabından yeniden eşitlendi.',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoreNotice = (false, 'Satın alma eşitlemesi şu anda alınamadı.');
      });
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  String _byteString(int bytes) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} GB';
    }
    return '${(bytes / mb).round()} MB';
  }
}
