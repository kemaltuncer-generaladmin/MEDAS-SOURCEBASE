import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/ecosystem_setup_redirector.dart';
import '../../core/sb_external_links.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';

/// Port of SettingsView ("Tüm Ayarlar").
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _appearance = 'system';
  bool _sourceNotifications = true;
  bool _generationNotifications = true;
  bool _compactCards = false;

  static const _appearances = [
    ('system', 'Sistem'),
    ('light', 'Açık'),
    ('dark', 'Koyu'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceStore>().loadWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        leading: BackButton(color: SBColors.blue),
      ),
      body: SBPageBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBPageHeader(
                title: 'Ayarlar',
                subtitle:
                    'Hesap, görünüm, bildirim ve uygulama bilgilerini yönetebilirsin.',
                primaryIcon: 'questionmark.circle',
                onPrimary: () => router.navigate(
                    AppRoute(AppRouteKind.profileMenu, {'destination': 'help'})),
              ),
              const SizedBox(height: SBSpacing.lg),
              _settingsGroup('Hesap', [
                _actionRow(
                  icon: 'person',
                  title: 'Profil bilgileri',
                  detail: 'Branş, hedef ve çalışma profilini MedAsi kurulumunda düzenle.',
                  onTap: () => openEcosystemSetupEdit(),
                ),
                _divider(),
                _actionRow(
                  icon: 'creditcard',
                  title: 'MC üretim kredisi',
                  detail:
                      'Kaynak tabanlı üretim bakiyesi ve paketleri görüntüle.',
                  onTap: () => router.navigate(AppRoute.store),
                ),
              ]),
              const SizedBox(height: SBSpacing.lg),
              _settingsGroup('Görünüm', [
                _toggleRow(
                  title: 'Kompakt kart yoğunluğu',
                  detail: 'Uzun listelerde daha sıkı kart aralığı kullan.',
                  value: _compactCards,
                  onChanged: (v) => setState(() => _compactCards = v),
                ),
                _divider(),
                Row(
                  children: [
                    _iconTile('moon.stars'),
                    const SizedBox(width: SBSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tema',
                              style: SBTypography.labelSmall
                                  .copyWith(color: SBColors.navy)),
                          const SizedBox(height: 3),
                          Text('Görünüm tercihleri bu cihazda uygulanır.',
                              style: SBTypography.caption
                                  .copyWith(color: SBColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SBSpacing.sm),
                _appearancePicker(),
              ]),
              const SizedBox(height: SBSpacing.lg),
              _settingsGroup('Bildirimler', [
                _toggleRow(
                  title: 'Kaynak işleme',
                  detail:
                      'Yükleme ve metin çıkarma durumları için bildirim al.',
                  value: _sourceNotifications,
                  onChanged: (v) => setState(() => _sourceNotifications = v),
                ),
                _divider(),
                _toggleRow(
                  title: 'Üretim tamamlanınca',
                  detail: 'Kart, soru ve özet tamamlanınca haber ver.',
                  value: _generationNotifications,
                  onChanged: (v) =>
                      setState(() => _generationNotifications = v),
                ),
              ]),
              const SizedBox(height: SBSpacing.lg),
              _settingsGroup('Depolama', [
                Row(
                  children: [
                    Expanded(
                      child: SBMetricTile(
                          icon: 'doc.text',
                          value: '${store.allFiles.length}',
                          label: 'Kaynak',
                          tint: SBColors.blue),
                    ),
                    const SizedBox(width: SBSpacing.sm),
                    Expanded(
                      child: SBMetricTile(
                          icon: 'rectangle.stack',
                          value: '${store.workspace.collections.length}',
                          label: 'Koleksiyon',
                          tint: SBColors.purple),
                    ),
                  ],
                ),
                const SizedBox(height: SBSpacing.sm),
                SBNotice(
                  icon: 'internaldrive',
                  message:
                      'Drive kaynakların, çalışmaların ve koleksiyonların burada özetlenir.',
                  tint: SBColors.cyan,
                ),
              ]),
              const SizedBox(height: SBSpacing.lg),
              _settingsGroup('Yasal', [
                _legalLinkRow('hand.raised', 'Gizlilik Politikası',
                    SBExternalLinks.privacyUrl),
                _divider(),
                _legalLinkRow('doc.text', 'Kullanım Koşulları',
                    SBExternalLinks.termsUrl),
              ]),
              const SizedBox(height: SBSpacing.lg),
              _settingsGroup('Yardım ve Hakkında', [
                _actionRow(
                  icon: 'questionmark.circle',
                  title: 'Yardım',
                  detail:
                      'Kaynak yükleme, üretim ve MC kullanımı için kısa notlar.',
                  onTap: () => router.navigate(AppRoute(
                      AppRouteKind.profileMenu, {'destination': 'help'})),
                ),
                _divider(),
                _actionRow(
                  icon: 'info.circle',
                  title: 'SourceBase hakkında',
                  detail:
                      'Medasi ekosistemi için kaynak tabanlı öğrenme alanı.',
                  onTap: () => router.navigate(AppRoute(
                      AppRouteKind.profileMenu, {'destination': 'about'})),
                ),
              ]),
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        SBCard(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Divider(color: SBColors.softLine, height: SBSpacing.lg);

  Widget _iconTile(String icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: SBColors.selectedBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: SBIcon(icon, size: 18, color: SBColors.blue),
    );
  }

  Widget _appearancePicker() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SBColors.field,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final (value, title) in _appearances)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _appearance = value),
                child: AnimatedContainer(
                  duration: SBMotion.easeDuration,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _appearance == value
                        ? SBColors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: _appearance == value
                        ? [
                            BoxShadow(
                              color: SBColors.navy.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(title,
                      style: SBTypography.labelSmall
                          .copyWith(color: SBColors.navy)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) {
    return SBPressable(
      onTap: onTap,
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        SBTypography.labelSmall.copyWith(color: SBColors.navy)),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.caption.copyWith(color: SBColors.muted),
                ),
              ],
            ),
          ),
          SBIcon('chevron.right', size: 13, color: SBColors.softText),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String detail,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      SBTypography.labelSmall.copyWith(color: SBColors.navy)),
              const SizedBox(height: 3),
              Text(detail,
                  style: SBTypography.caption.copyWith(color: SBColors.muted)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: SBColors.blue),
      ],
    );
  }

  Widget _legalLinkRow(String icon, String title, String url) {
    final store = context.read<WorkspaceStore>();
    return SBPressable(
      onTap: () async {
        final ok = await SBExternalLinks.open(url);
        if (!ok) store.toast('$title açılamadı.');
      },
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text(title,
                style:
                    SBTypography.labelSmall.copyWith(color: SBColors.navy)),
          ),
          SBIcon('arrow.up.right', size: 12, color: SBColors.softText),
        ],
      ),
    );
  }
}
