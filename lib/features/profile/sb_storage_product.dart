/// App Store storage subscription tiers. Port of SBStorageProduct (UI level).
enum SBStorageProduct {
  gb15('storage_15gb_monthly'),
  gb25('storage_25gb_monthly'),
  gb50('storage_50gb_monthly'),
  pro('pro_75gb_monthly');

  const SBStorageProduct(this.code);

  final String code;

  int get gigabytes => switch (this) {
        SBStorageProduct.gb15 => 15,
        SBStorageProduct.gb25 => 25,
        SBStorageProduct.gb50 || SBStorageProduct.pro => 50,
      };

  int get monthlyMC => this == SBStorageProduct.pro ? 500 : 0;

  int get rank => switch (this) {
        SBStorageProduct.gb15 => 1,
        SBStorageProduct.gb25 => 2,
        SBStorageProduct.gb50 => 3,
        SBStorageProduct.pro => 4,
      };

  int get bonusBytes => gigabytes * 1024 * 1024 * 1024;

  String get gbLabel =>
      this == SBStorageProduct.pro ? 'Pro · +50 GB + 500 MC' : '+$gigabytes GB';

  String get displayName => switch (this) {
        SBStorageProduct.gb15 => '15 GB',
        SBStorageProduct.gb25 => '25 GB',
        SBStorageProduct.gb50 => '50 GB',
        SBStorageProduct.pro => 'Pro',
      };

  String get fallbackPriceLabel => switch (this) {
        SBStorageProduct.gb15 => '40 TL/ay',
        SBStorageProduct.gb25 => '60 TL/ay',
        SBStorageProduct.gb50 => '110 TL/ay',
        SBStorageProduct.pro => '500 TL/ay',
      };

  String get tagline => switch (this) {
        SBStorageProduct.gb15 => 'Ek kaynak ve çıktılar için rahat alan.',
        SBStorageProduct.gb25 =>
          'Düzenli çalışan öğrenciler için bol alan.',
        SBStorageProduct.gb50 =>
          'Yoğun arşiv ve üretim için en geniş alan.',
        SBStorageProduct.pro => 'Aylık 500 MC + 50 GB; en kapsamlı paket.',
      };

  String get icon => switch (this) {
        SBStorageProduct.gb15 => 'externaldrive',
        SBStorageProduct.gb25 => 'externaldrive.fill',
        SBStorageProduct.gb50 => 'internaldrive.fill',
        SBStorageProduct.pro => 'crown.fill',
      };

  static SBStorageProduct? fromCode(String code) {
    for (final product in SBStorageProduct.values) {
      if (product.code == code) return product;
    }
    return null;
  }
}

/// MC coin pack shown in the store. UI-level port of MedasiCoinPackage.
class MedasiCoinPackage {
  const MedasiCoinPackage({
    required this.code,
    required this.title,
    required this.description,
    required this.coin,
    required this.priceCents,
    required this.priceLabel,
    this.currencyDisplay = 'TL',
  });

  final String code;
  final String title;
  final String description;
  final int coin;
  final int priceCents;
  final String priceLabel;
  final String currencyDisplay;

  // Canonical MedasiCoin packages (codes + coins + prices) mirror the live
  // `store_products` catalogue and the iOS submission runbook
  // (tr.com.medasi.sourcebase.mc_10/mc_20/mc_50). On Google Play create
  // consumable products with the same IDs (mc_10 / mc_20 / mc_50). Live prices
  // still override these from the backend; these are the offline fallback.
  static const fallbackPackages = [
    MedasiCoinPackage(
      code: 'mc_10',
      title: '10 MC Paketi',
      description: 'Küçük üretimler ve hızlı tekrarlar için.',
      coin: 10,
      priceCents: 4000,
      priceLabel: '40,00 TL',
    ),
    MedasiCoinPackage(
      code: 'mc_20',
      title: '20 MC Paketi',
      description: 'Düzenli kullanım için orta seviye paket.',
      coin: 20,
      priceCents: 6500,
      priceLabel: '65,00 TL',
    ),
    MedasiCoinPackage(
      code: 'mc_50',
      title: '50 MC Paketi',
      description: 'Yoğun üretim dönemleri için en geniş paket.',
      coin: 50,
      priceCents: 17999,
      priceLabel: '179,99 TL',
    ),
  ];
}
