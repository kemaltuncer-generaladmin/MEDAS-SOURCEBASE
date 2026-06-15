import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/ecosystem_setup_redirector.dart';
import '../../core/session_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_effects.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';

class _SettingsItem {
  const _SettingsItem(this.icon, this.title, this.description, this.route,
      {this.opensEcosystemEdit = false});

  final String icon;
  final String title;
  final String description;
  final AppRoute route;

  /// When true the row opens the central ecosystem onboarding in edit mode
  /// instead of navigating to [route] (profile editing lives centrally).
  final bool opensEcosystemEdit;
}

/// Port of ProfileView ("Profil" tab).
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _isLoading = true;
  bool _isSigningOut = false;
  final double _walletBalance = 12.4;

  static final _settingsItems = [
    _SettingsItem('gearshape', 'Tüm Ayarlar',
        'Görünüm, bildirim, depolama ve kalite durumunu açabilirsin.',
        AppRoute.settings),
    _SettingsItem('person', 'Profil Bilgileri',
        'Branş, hedef ve çalışma profilini MedAsi kurulumunda düzenle.',
        AppRoute.profile, opensEcosystemEdit: true),
    _SettingsItem('lock.shield', 'Güvenlik ve Şifre',
        'Şifre yenileme ve oturum güvenliği bilgilerini görebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'security'})),
    _SettingsItem('paintpalette', 'Görünüm',
        'Tema ve ekran tercihlerini kontrol edebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'appearance'})),
    _SettingsItem('bell.badge', 'Bildirimler',
        'Yükleme ve üretim hatırlatmalarını yönetebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'notifications'})),
    _SettingsItem('internaldrive', 'Depolama',
        'Drive kullanımı ve kaynak durumunu görebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'storage'})),
    _SettingsItem('eye.slash', 'Gizlilik ve Destek',
        'Veri güvenliği ve resmi destek bilgilerini görebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'privacySupport'})),
    _SettingsItem('questionmark.circle', 'Yardım',
        'Kullanım ve destek notlarını açabilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'help'})),
    _SettingsItem('info.circle', 'SourceBase Hakkında',
        'Ürün kapsamını ve deneysel modu görebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'about'})),
    _SettingsItem('trash', 'Hesap Silme',
        'Hesap silme talebi durumunu kontrol edebilirsin.',
        AppRoute(AppRouteKind.profileMenu, {'destination': 'deleteAccount'})),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final router = context.read<AppRouter>();

    return SBPageBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SBSpacing.lg),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profil',
                  style: SBTypography.heading1.copyWith(color: SBColors.navy)),
              const SizedBox(height: SBSpacing.lg),
              if (_isLoading)
                const SBLoadingState(
                  icon: 'person.crop.circle',
                  title: 'Profil yükleniyor',
                  message:
                      'Hesap ve üretim kredisi bilgilerin hazırlanıyor...',
                )
              else ...[
                SBEntrance(index: 0, child: _profileHeader(session, router)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 2, child: _walletSection(router)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(index: 3, child: _settingsSection(router)),
                const SizedBox(height: SBSpacing.lg),
                SBEntrance(
                  index: 4,
                  child: SBButton(
                    _isSigningOut
                        ? 'Oturum kapatılıyor...'
                        : 'Oturumu kapat',
                    icon: 'door.right.to.left.open',
                    variant: SBButtonVariant.secondary,
                    isLoading: _isSigningOut,
                    fullWidth: true,
                    onPressed: _confirmSignOut,
                  ),
                ),
              ],
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(SessionStore session, AppRouter router) {
    return SBCard(
      radius: 20,
      borderColor: SBColors.blue.withValues(alpha: 0.12),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.heading3.copyWith(color: SBColors.navy),
                ),
                const SizedBox(height: SBSpacing.xs),
                Text(
                  session.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SBTypography.bodySmall.copyWith(color: SBColors.muted),
                ),
                const SizedBox(height: SBSpacing.xs),
                if (session.faculty.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SBColors.selectedBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SBIcon('graduationcap',
                            size: 12, color: SBColors.blue),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            session.faculty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SBTypography.caption
                                .copyWith(color: SBColors.navy),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              SBHaptics.tap();
              openEcosystemSetupEdit();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SBColors.selectedBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SBIcon('pencil', size: 18, color: SBColors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: SBColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const SBIcon('person.fill', size: 32, color: Colors.white),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration:
                  BoxDecoration(color: SBColors.blue, shape: BoxShape.circle),
              alignment: Alignment.center,
              child:
                  const SBIcon('camera.fill', size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletSection(AppRouter router) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Üretim kredisi',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        SBCommandCard(
          tint: SBColors.green,
          onTap: () => router.navigate(AppRoute.store),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SBIconTile(
                    icon: 'creditcard.fill',
                    tint: Color(0xFF12AE55),
                    size: 50,
                    radius: 14),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MC üretim kredisi',
                          style: SBTypography.labelSmall
                              .copyWith(color: SBColors.muted)),
                      const SizedBox(height: 4),
                      Text(
                        '${_walletBalance.toStringAsFixed(1).replaceAll('.', ',')} MC',
                        style: SBTypography.heading2
                            .copyWith(color: SBColors.navy),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: SBColors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsSection(AppRouter router) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ayarlar',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
        const SizedBox(height: SBSpacing.sm),
        SBCard(
          radius: 16,
          child: Column(
            children: [
              for (var i = 0; i < _settingsItems.length; i++) ...[
                _settingsRow(router, _settingsItems[i]),
                if (i < _settingsItems.length - 1)
                  Divider(color: SBColors.softLine, height: SBSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsRow(AppRouter router, _SettingsItem item) {
    return SBPressable(
      onTap: () => item.opensEcosystemEdit
          ? openEcosystemSetupEdit()
          : router.navigate(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SBSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: SBIcon(item.icon, size: 20, color: SBColors.blue),
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: SBTypography.labelSmall
                          .copyWith(color: SBColors.navy)),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SBTypography.caption.copyWith(color: SBColors.muted),
                  ),
                ],
              ),
            ),
            SBIcon('chevron.right', size: 14, color: SBColors.softText),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Oturumu kapat'),
        content: const Text(
            'Oturumunuzu kapatmak istediğinize emin misiniz? Devam etmek için yeniden giriş yapmanız gerekecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Sürdür'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              setState(() => _isSigningOut = true);
              final session = context.read<SessionStore>();
              final router = context.read<AppRouter>();
              await session.signOut();
              router.reset(AppRoute.login);
              if (mounted) setState(() => _isSigningOut = false);
            },
            child: Text('Oturumu kapat',
                style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }
}
