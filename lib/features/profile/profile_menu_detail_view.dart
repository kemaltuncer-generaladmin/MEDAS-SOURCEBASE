import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/session_store.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';

enum ProfileMenuDestination {
  security,
  appearance,
  notifications,
  storage,
  privacySupport,
  help,
  about,
  deleteAccount;

  String get title => switch (this) {
        ProfileMenuDestination.security => 'Güvenlik ve Şifre',
        ProfileMenuDestination.appearance => 'Görünüm',
        ProfileMenuDestination.notifications => 'Bildirimler',
        ProfileMenuDestination.storage => 'Depolama',
        ProfileMenuDestination.privacySupport => 'Gizlilik ve Destek',
        ProfileMenuDestination.help => 'Yardım',
        ProfileMenuDestination.about => 'SourceBase Hakkında',
        ProfileMenuDestination.deleteAccount => 'Hesap Silme',
      };

  String get subtitle => switch (this) {
        ProfileMenuDestination.security =>
          'Şifre yenileme ve oturum güvenliği işlemlerini yönetebilirsin.',
        ProfileMenuDestination.appearance =>
          'Uygulama görünümünü ve ekran yoğunluğunu seçebilirsin.',
        ProfileMenuDestination.notifications =>
          'Hangi çalışma olaylarında bildirim almak istediğini belirle.',
        ProfileMenuDestination.storage =>
          'Drive alanındaki kaynak ve koleksiyonlarını görüntüleyebilirsin.',
        ProfileMenuDestination.privacySupport =>
          'Veri tercihlerini düzenle ve destek bilgilerine ulaş.',
        ProfileMenuDestination.help =>
          'En sık kullanılan SourceBase akışlarına hızlıca ulaş.',
        ProfileMenuDestination.about =>
          'SourceBase sürümü ve ürün kapsamını görüntüleyebilirsin.',
        ProfileMenuDestination.deleteAccount =>
          'Hesap silme isteğinin durumunu yönetebilirsin.',
      };
}

/// Port of ProfileMenuDetailView.
class ProfileMenuDetailView extends StatefulWidget {
  const ProfileMenuDetailView({super.key, required this.destination});

  final String destination;

  @override
  State<ProfileMenuDetailView> createState() => _ProfileMenuDetailViewState();
}

class _ProfileMenuDetailViewState extends State<ProfileMenuDetailView> {
  String _appearance = 'system';
  bool _compactCards = false;
  bool _sourceNotifications = true;
  bool _generationNotifications = true;
  bool _studyNotifications = false;
  bool _analyticsSharing = false;
  (bool, String)? _notice; // (isSuccess, message)
  bool _isRequestingDeletion = false;
  String _supportTopic = 'Yükleme ve dosya işleme';
  final _supportEmail = TextEditingController();
  final _supportMessage = TextEditingController();
  bool _isSubmittingSupport = false;

  ProfileMenuDestination get _destination => ProfileMenuDestination.values
      .firstWhere((d) => d.name == widget.destination,
          orElse: () => ProfileMenuDestination.help);

  @override
  void initState() {
    super.initState();
    if (_destination == ProfileMenuDestination.storage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<WorkspaceStore>().loadWorkspace();
      });
    }
  }

  @override
  void dispose() {
    _supportEmail.dispose();
    _supportMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = context.read<AppRouter>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(_destination.title,
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      body: SBPageBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SBSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SBPageHeader(
                  title: _destination.title, subtitle: _destination.subtitle),
              const SizedBox(height: SBSpacing.lg),
              if (_notice != null) ...[
                SBNotice(
                  icon: _notice!.$1
                      ? 'checkmark.circle'
                      : 'exclamationmark.triangle',
                  message: _notice!.$2,
                  tint: _notice!.$1 ? SBColors.green : SBColors.red,
                ),
                const SizedBox(height: SBSpacing.lg),
              ],
              _detailContent(router),
              const SizedBox(height: 156),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailContent(AppRouter router) {
    switch (_destination) {
      case ProfileMenuDestination.security:
        return _securityContent();
      case ProfileMenuDestination.appearance:
        return _appearanceContent();
      case ProfileMenuDestination.notifications:
        return _notificationsContent();
      case ProfileMenuDestination.storage:
        return _storageContent(router);
      case ProfileMenuDestination.privacySupport:
        return _privacyContent(router);
      case ProfileMenuDestination.help:
        return _helpContent(router);
      case ProfileMenuDestination.about:
        return _aboutContent();
      case ProfileMenuDestination.deleteAccount:
        return _deleteAccountContent();
    }
  }

  Widget _securityContent() {
    final session = context.watch<SessionStore>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard('Aktif Hesap', [
          ('E-posta',
              session.email.isEmpty ? 'Oturum e-postası yok' : session.email),
          ('Oturum', 'Aktif'),
        ]),
        const SizedBox(height: SBSpacing.lg),
        SBNotice(
          icon: 'key',
          message:
              'Şifre yenileme bağlantısı kayıtlı e-posta adresine gönderilir.',
          tint: SBColors.blue,
        ),
        const SizedBox(height: SBSpacing.lg),
        SBButton(
          'Şifre Yenileme Bağlantısı Gönder',
          icon: 'envelope',
          fullWidth: true,
          onPressed: () async {
            final session = context.read<SessionStore>();
            await session.sendPasswordReset(email: session.email);
            if (mounted) {
              setState(() => _notice = (
                    true,
                    'Şifre yenileme bağlantısı e-posta adresine gönderildi.'
                  ));
            }
          },
        ),
        const SizedBox(height: SBSpacing.md),
        SBButton(
          'Oturumu kapat',
          icon: 'door.right.to.left.open',
          variant: SBButtonVariant.secondary,
          fullWidth: true,
          onPressed: _confirmSignOut,
        ),
      ],
    );
  }

  Widget _appearanceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsCard([
          Text('Tema',
              style: SBTypography.labelSmall.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.sm),
          _appearancePicker(),
          Divider(color: SBColors.softLine, height: SBSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text('Kompakt kart yoğunluğu',
                    style: SBTypography.labelSmall
                        .copyWith(color: SBColors.navy)),
              ),
              Switch(
                value: _compactCards,
                onChanged: (v) => setState(() => _compactCards = v),
                activeThumbColor: SBColors.blue,
              ),
            ],
          ),
        ]),
        const SizedBox(height: SBSpacing.lg),
        SBNotice(
          icon: 'paintpalette',
          message:
              'Tema ve kart yoğunluğu tercihlerin bu cihazda saklanır.',
          tint: SBColors.purple,
        ),
      ],
    );
  }

  Widget _appearancePicker() {
    const appearances = [
      ('system', 'Sistem'),
      ('light', 'Açık'),
      ('dark', 'Koyu'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SBColors.field,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final (value, title) in appearances)
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

  Widget _notificationsContent() {
    return _settingsCard([
      _preferenceToggle(
        'Kaynak işleme',
        'Yükleme ve metin çıkarma durumları için bildirim al.',
        _sourceNotifications,
        (v) => setState(() => _sourceNotifications = v),
      ),
      Divider(color: SBColors.softLine, height: SBSpacing.lg),
      _preferenceToggle(
        'Üretim tamamlanınca',
        'Kart, soru ve özet tamamlanınca haber ver.',
        _generationNotifications,
        (v) => setState(() => _generationNotifications = v),
      ),
      Divider(color: SBColors.softLine, height: SBSpacing.lg),
      _preferenceToggle(
        'Çalışma hatırlatmaları',
        'Planlanan çalışma akışları için hatırlatma al.',
        _studyNotifications,
        (v) => setState(() => _studyNotifications = v),
      ),
    ]);
  }

  Widget _storageContent(AppRouter router) {
    final store = context.watch<WorkspaceStore>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: SBSpacing.lg),
        _settingsCard([
          _navigationRow('arrow.up.doc', 'Yüklemeleri Görüntüle',
              () => router.navigate(AppRoute.uploads)),
          Divider(color: SBColors.softLine, height: SBSpacing.lg),
          _navigationRow('rectangle.stack', 'Koleksiyonları Görüntüle',
              () => router.navigate(AppRoute.collections)),
        ]),
      ],
    );
  }

  Widget _privacyContent(AppRouter router) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsCard([
          _preferenceToggle(
            'Anonim kullanım verileri',
            'Ürün geliştirme için cihazdaki tercih durumunu sakla.',
            _analyticsSharing,
            (v) => setState(() => _analyticsSharing = v),
          ),
        ]),
        const SizedBox(height: SBSpacing.lg),
        SBNotice(
          icon: 'lock.shield',
          message:
              'Dosya, profil ve üretim kredisi bilgileri oturum sahibi kullanıcıya ait çalışma alanında gösterilir. Ödeme onayı olmadan bakiye eklenmez.',
          tint: SBColors.green,
        ),
        const SizedBox(height: SBSpacing.lg),
        _navigationRow(
            'questionmark.circle',
            'Yardım Akışını Aç',
            () => router.navigate(AppRoute(
                AppRouteKind.profileMenu, {'destination': 'help'}))),
      ],
    );
  }

  Widget _helpContent(AppRouter router) {
    const topics = [
      'Yükleme ve dosya işleme',
      'Üretim çalışmaları',
      'Ödeme ve paketler',
      'Profil ve hesap',
      'Diğer',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsCard([
          Text('Sık Sorulan Sorular',
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.sm),
          _faqRow('PDF yükledim, neden işleniyor görünüyor?',
              "Metin çıkarımı bitince kaynak hazır olur. Taranmış PDF'lerde daha net dosya gerekebilir."),
          _faqRow('Üretilen sorular nerede çözülür?',
              'Soru hazır olunca Koleksiyonlar veya Kuyruk ekranından çözüm ekranına geçebilirsin.'),
          _faqRow('PDF dosyasını nereden alırım?',
              'Sınav özeti, algoritma, karşılaştırma ve zihin haritası çalışma ekranlarında PDF dışa aktarımı bulunur.'),
          _faqRow('MC paketleri nasıl yüklenir?',
              'Paket ekranında güvenli ödeme sayfası açılır; onay sonrası MC bakiyesi profilinde görünür.'),
        ]),
        const SizedBox(height: SBSpacing.lg),
        _settingsCard([
          Text('Destek Formu',
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _supportTopic,
            items: [
              for (final topic in topics)
                DropdownMenuItem(value: topic, child: Text(topic)),
            ],
            onChanged: (topic) =>
                setState(() => _supportTopic = topic ?? _supportTopic),
            style: SBTypography.bodySmall.copyWith(color: SBColors.navy),
            decoration: InputDecoration(
              filled: true,
              fillColor: SBColors.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: SBSpacing.sm),
          _supportField(_supportEmail, 'E-posta', 1),
          const SizedBox(height: SBSpacing.sm),
          _supportField(_supportMessage, 'Mesajını yaz', 5),
          const SizedBox(height: SBSpacing.md),
          SBButton(
            _isSubmittingSupport ? 'Gönderiliyor...' : 'Formu Gönder',
            icon: 'paperplane',
            isLoading: _isSubmittingSupport,
            fullWidth: true,
            onPressed: _submitSupport,
          ),
        ]),
        const SizedBox(height: SBSpacing.lg),
        _settingsCard([
          _navigationRow('arrow.up.doc', 'Kaynak Yüklemelerini Aç',
              () => router.navigate(AppRoute.uploads)),
          Divider(color: SBColors.softLine, height: SBSpacing.lg),
          _navigationRow('wand.and.stars', 'Üretim İçin Kaynak Seç',
              () => router.navigate(AppRoute.sourcePicker)),
          Divider(color: SBColors.softLine, height: SBSpacing.lg),
          _navigationRow('creditcard', 'MC Paketlerini Görüntüle',
              () => router.navigate(AppRoute.store)),
        ]),
      ],
    );
  }

  Widget _aboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard('Uygulama Bilgisi', const [
          ('Ürün', 'SourceBase'),
          ('Sürüm', '1.0'),
          ('Alan', 'Medasi öğrenme ekosistemi'),
        ]),
        const SizedBox(height: SBSpacing.lg),
        SBNotice(
          icon: 'info.circle',
          message:
              'SourceBase, kaynaklarını çalışma materyaline dönüştürür. Drive, Kuyruk ve Koleksiyonlar aynı çalışma alanında çalışır.',
          tint: SBColors.blue,
        ),
        const SizedBox(height: SBSpacing.lg),
        _settingsCard([
          Text('Neler yapar?',
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.sm),
          _aboutBullet(
              'PDF, PPTX, DOCX, PPT ve DOC kaynaklarını ders-bölüm düzeninde saklar.'),
          _aboutBullet(
              'Flashcard, soru, sınav sabahı özeti, akış, tablo ve zihin haritası üretir.'),
          _aboutBullet(
              'Hazır çalışmalar Koleksiyonlar ve çalışma ekranlarında açılır.'),
        ]),
      ],
    );
  }

  Widget _deleteAccountContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SBNotice(
          icon: 'exclamationmark.triangle',
          message:
              'Hesap silme talebi geri alınamaz. Profil, Drive verilerin, çalışma materyallerin ve üretim kredisi kayıtların silme sürecine alınır.',
          tint: SBColors.warning,
        ),
        const SizedBox(height: SBSpacing.lg),
        SBNotice(
          icon: 'info.circle',
          message:
              'Talep iletildikten sonra otomatik olarak çıkış yapılır. Hesap silme süreci kayıtlı e-posta adresine bildirilir.',
          tint: SBColors.blue,
        ),
        const SizedBox(height: SBSpacing.lg),
        SBButton(
          _isRequestingDeletion
              ? 'Talep Gönderiliyor...'
              : 'Hesap Silme Talebi Gönder',
          icon: 'trash',
          variant: SBButtonVariant.secondary,
          isLoading: _isRequestingDeletion,
          fullWidth: true,
          onPressed: _confirmDeletion,
        ),
      ],
    );
  }

  // MARK: - Shared building blocks

  Widget _infoCard(String title, List<(String, String)> rows) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
          const SizedBox(height: SBSpacing.md),
          for (final (label, value) in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(label,
                      style: SBTypography.bodySmall
                          .copyWith(color: SBColors.muted)),
                ),
                Expanded(
                  child: Text(value,
                      style: SBTypography.bodySmall
                          .copyWith(color: SBColors.navy)),
                ),
              ],
            ),
            const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _preferenceToggle(String title, String detail, bool value,
      ValueChanged<bool> onChanged) {
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

  Widget _navigationRow(String icon, String title, VoidCallback onTap) {
    return SBPressable(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: SBColors.selectedBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: SBIcon(icon, size: 18, color: SBColors.blue),
          ),
          const SizedBox(width: SBSpacing.md),
          Expanded(
            child: Text(title,
                style:
                    SBTypography.labelSmall.copyWith(color: SBColors.navy)),
          ),
          SBIcon('chevron.right', size: 13, color: SBColors.softText),
        ],
      ),
    );
  }

  Widget _faqRow(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SBSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style: SBTypography.labelSmall.copyWith(color: SBColors.navy)),
          const SizedBox(height: 4),
          Text(answer,
              style: SBTypography.caption
                  .copyWith(color: SBColors.muted, height: 1.3)),
        ],
      ),
    );
  }

  Widget _aboutBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SBSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                  color: SBColors.blue, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          Expanded(
            child: Text(text,
                style:
                    SBTypography.bodySmall.copyWith(color: SBColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _supportField(
      TextEditingController controller, String hint, int maxLines) {
    return Container(
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: SBTypography.bodyMedium.copyWith(color: SBColors.navy),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SBTypography.bodyMedium.copyWith(color: SBColors.softText),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }

  // MARK: - Actions

  Future<void> _submitSupport() async {
    if (_isSubmittingSupport) return;
    setState(() => _isSubmittingSupport = true);
    final store = context.read<WorkspaceStore>();
    final ok = await store.submitSupportForm(
      topic: _supportTopic,
      email: _supportEmail.text,
      message: _supportMessage.text,
    );
    if (!mounted) return;
    setState(() {
      _isSubmittingSupport = false;
      _notice = ok
          ? (true, 'Destek talebin iletildi. En kısa sürede dönüş yapılır.')
          : (false, 'Destek formu gönderilemedi. Tekrar dene.');
      if (ok) {
        _supportMessage.clear();
      }
    });
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Oturumu kapat'),
        content: const Text('Devam etmek için yeniden giriş yapman gerekir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final session = context.read<SessionStore>();
              final router = context.read<AppRouter>();
              await session.signOut();
              router.reset(AppRoute.login);
            },
            child: Text('Oturumu kapat',
                style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletion() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesap Silme Talebi'),
        content: const Text(
            'Hesabın ve çalışma alanın silme sürecine alınır. Oturumun kapatılır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              setState(() => _isRequestingDeletion = true);
              final store = context.read<WorkspaceStore>();
              final session = context.read<SessionStore>();
              final router = context.read<AppRouter>();
              final ok = await store.requestAccountDeletion();
              if (ok) {
                await session.signOut();
                router.reset(AppRoute.login);
              }
              if (mounted) {
                setState(() => _isRequestingDeletion = false);
              }
            },
            child: Text('Talebi Gönder ve Çıkış Yap',
                style: TextStyle(color: SBColors.red)),
          ),
        ],
      ),
    );
  }
}
