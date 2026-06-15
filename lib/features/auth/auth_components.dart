import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/sb_colors.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';

/// Branded header: a soft accent halo behind the SourceBase mark, with title
/// and subtitle. Used at the top of the auth + profile-setup screens.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    this.title = 'SourceBase',
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  double get _markSize => compact ? 60 : 76;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: _markSize * 1.9,
          height: _markSize * 1.9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: _markSize * 1.9,
                height: _markSize * 1.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SBColors.blue.withValues(alpha: 0.12),
                      blurRadius: 52,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              Container(
                width: _markSize,
                height: _markSize,
                decoration: BoxDecoration(
                  gradient: SBColors.brandGradient,
                  borderRadius: BorderRadius.circular(compact ? 18 : 22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SBColors.blue.withValues(alpha: 0.30),
                      blurRadius: 22,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: SBIcon(
                  'books.vertical.fill',
                  size: compact ? 26 : 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SBSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: (compact ? SBTypography.heading2 : SBTypography.display2)
              .copyWith(color: SBColors.navy),
        ),
        const SizedBox(height: SBSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: SBTypography.bodyMedium.copyWith(color: SBColors.muted),
        ),
      ],
    );
  }
}

/// Slim discipline chips that communicate SourceBase's multi-discipline value.
class AuthDisciplineChips extends StatelessWidget {
  const AuthDisciplineChips({super.key});

  static const _items = ['Veterinerlik', 'Tıp', 'Diş', 'Hemşirelik', 'Ebelik'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SBSpacing.sm,
      runSpacing: SBSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final item in _items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: SBColors.softBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item,
              style: SBTypography.labelSmall.copyWith(color: SBColors.blue),
            ),
          ),
      ],
    );
  }
}

class AuthAppConfig {
  const AuthAppConfig({
    required this.name,
    required this.shortName,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.soft,
    required this.description,
  });

  final String name;
  final String shortName;
  final String icon;
  final Color primary;
  final Color secondary;
  final Color soft;
  final String description;

  LinearGradient get gradient => LinearGradient(
    colors: [secondary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const qlinik = AuthAppConfig(
    name: 'Qlinik',
    shortName: 'Q',
    icon: 'stethoscope',
    primary: Color(0xFF00A884),
    secondary: Color(0xFF18D8C8),
    soft: Color(0xFFE8FFF9),
    description: 'Ölçüm',
  );

  static const praticase = AuthAppConfig(
    name: 'PratiCase',
    shortName: 'P',
    icon: 'cross.case.fill',
    primary: Color(0xFF5C4DFF),
    secondary: Color(0xFF9A5CFF),
    soft: Color(0xFFF1EEFF),
    description: 'Simülasyon',
  );

  static const sourcebase = AuthAppConfig(
    name: 'SourceBase',
    shortName: 'S',
    icon: 'books.vertical.fill',
    primary: Color(0xFF056BFF),
    secondary: Color(0xFF18C6E8),
    soft: Color(0xFFEAF6FF),
    description: 'Kaynak',
  );
}

const List<AuthAppConfig> _ecosystemApps = [
  AuthAppConfig.qlinik,
  AuthAppConfig.praticase,
  AuthAppConfig.sourcebase,
];

class CommonAuthScaffold extends StatelessWidget {
  const CommonAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.leading,
    this.app = AuthAppConfig.sourcebase,
    this.icon = 'sparkles',
    this.showCallout = true,
    this.maxFormWidth = 460,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final Widget? leading;
  final AuthAppConfig app;
  final String icon;
  final bool showCallout;
  final double maxFormWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 940;
          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 11, child: _AuthHeroPanel(app: app)),
                Expanded(
                  flex: 9,
                  child: _AuthFormSide(
                    app: app,
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    leading: leading,
                    showCallout: showCallout,
                    maxWidth: maxFormWidth,
                    footer: footer,
                    child: child,
                  ),
                ),
              ],
            );
          }

          return _AuthMobileShell(
            app: app,
            title: title,
            subtitle: subtitle,
            icon: icon,
            leading: leading,
            showCallout: showCallout,
            maxWidth: maxFormWidth,
            footer: footer,
            child: child,
          );
        },
      ),
    );
  }
}

class _AuthFormSide extends StatelessWidget {
  const _AuthFormSide({
    required this.app,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.leading,
    required this.showCallout,
    required this.maxWidth,
    required this.child,
    required this.footer,
  });

  final AuthAppConfig app;
  final String title;
  final String subtitle;
  final String icon;
  final Widget? leading;
  final bool showCallout;
  final double maxWidth;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7FAFF),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SBSpacing.xxxl,
              vertical: SBSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _AuthFormCard(
                app: app,
                title: title,
                subtitle: subtitle,
                icon: icon,
                leading: leading,
                showCallout: showCallout,
                footer: footer,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthMobileShell extends StatelessWidget {
  const _AuthMobileShell({
    required this.app,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.leading,
    required this.showCallout,
    required this.maxWidth,
    required this.child,
    required this.footer,
  });

  final AuthAppConfig app;
  final String title;
  final String subtitle;
  final String icon;
  final Widget? leading;
  final bool showCallout;
  final double maxWidth;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth <= 360;
        final shortHeight = constraints.maxHeight <= 700;
        final dense = compactWidth || shortHeight;
        final horizontalPadding = compactWidth ? 10.0 : SBSpacing.lg;
        final topPadding = shortHeight ? SBSpacing.sm : SBSpacing.xl;
        final bottomPadding = math.max(
          20.0,
          media.viewInsets.bottom + (shortHeight ? 16 : 32),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            _AuthAnimatedBackground(app: app),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _AuthFormCard(
                      app: app,
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                      leading: leading,
                      showCallout: showCallout,
                      footer: footer,
                      dense: dense,
                      compactWidth: compactWidth,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel({required this.app});

  final AuthAppConfig app;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [app.secondary, app.primary, const Color(0xFF11206E)],
              stops: const [0, 0.58, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const _HeroPattern(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthEcosystemLogo(app: app, compact: false, onDark: true),
                const Spacer(),
                Text(
                  'Tek hesap, tıbbın üç gücü.',
                  style: SBTypography.scaled(
                    46,
                    weight: FontWeight.w800,
                  ).copyWith(color: Colors.white, height: 1.06),
                ),
                const SizedBox(height: SBSpacing.lg),
                Text(
                  'MedAsi hesabınla Qlinik, PratiCase ve SourceBase arasında güvenli biçimde geçiş yap.',
                  style: SBTypography.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 34),
                Wrap(
                  spacing: SBSpacing.md,
                  runSpacing: SBSpacing.md,
                  children: const [
                    _HeroFeatureTile(
                      icon: 'lock.shield',
                      title: 'Güvenli',
                      text: 'Tek MedAsi hesabı',
                    ),
                    _HeroFeatureTile(
                      icon: 'bolt.fill',
                      title: 'Hızlı',
                      text: 'Saniyeler içinde erişim',
                    ),
                    _HeroFeatureTile(
                      icon: 'stethoscope',
                      title: 'Hekim odaklı',
                      text: 'Sağlık bilimlerine özel',
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                _EcosystemAppRail(active: app),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPattern extends StatefulWidget {
  const _HeroPattern();

  @override
  State<_HeroPattern> createState() => _HeroPatternState();
}

class _HeroPatternState extends State<_HeroPattern>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _AuthPatternPainter(_controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuthPatternPainter extends CustomPainter {
  const _AuthPatternPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final points = [
      Offset(
        size.width * (0.18 + 0.03 * math.sin(t * math.pi * 2)),
        size.height * 0.14,
      ),
      Offset(
        size.width * 0.82,
        size.height * (0.22 + 0.04 * math.cos(t * math.pi * 2)),
      ),
      Offset(
        size.width * (0.28 + 0.04 * math.cos(t * math.pi * 2)),
        size.height * 0.82,
      ),
    ];
    final radii = [size.width * 0.30, size.width * 0.24, size.width * 0.28];
    for (var i = 0; i < points.length; i++) {
      paint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.18 - i * 0.035),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: points[i], radius: radii[i]));
      canvas.drawCircle(points[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(_AuthPatternPainter oldDelegate) => oldDelegate.t != t;
}

class _AuthAnimatedBackground extends StatefulWidget {
  const _AuthAnimatedBackground({required this.app});

  final AuthAppConfig app;

  @override
  State<_AuthAnimatedBackground> createState() =>
      _AuthAnimatedBackgroundState();
}

class _AuthAnimatedBackgroundState extends State<_AuthAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6FBFF), Color(0xFFEFF6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _AuthMobileBackgroundPainter(
            t: _controller.value,
            app: widget.app,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuthMobileBackgroundPainter extends CustomPainter {
  const _AuthMobileBackgroundPainter({required this.t, required this.app});

  final double t;
  final AuthAppConfig app;

  @override
  void paint(Canvas canvas, Size size) {
    final maxSide = size.longestSide;
    final centers = [
      Offset(
        size.width * (0.18 + 0.08 * math.sin(t * math.pi * 2)),
        size.height * 0.14,
      ),
      Offset(
        size.width * 0.86,
        size.height * (0.30 + 0.08 * math.cos(t * math.pi * 2)),
      ),
      Offset(
        size.width * (0.22 + 0.06 * math.cos(t * math.pi * 2)),
        size.height * 0.86,
      ),
    ];
    final colors = [app.secondary, app.primary, const Color(0xFF7C3AED)];
    for (var i = 0; i < centers.length; i++) {
      final radius = maxSide * (i == 1 ? 0.34 : 0.42);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: i == 1 ? 0.18 : 0.14),
            colors[i].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centers[i], radius: radius));
      canvas.drawCircle(centers[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuthMobileBackgroundPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.app != app;
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.app,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.leading,
    required this.showCallout,
    required this.child,
    required this.footer,
    this.dense = false,
    this.compactWidth = false,
  });

  final AuthAppConfig app;
  final String title;
  final String subtitle;
  final String icon;
  final Widget? leading;
  final bool showCallout;
  final Widget child;
  final Widget? footer;
  final bool dense;
  final bool compactWidth;

  @override
  Widget build(BuildContext context) {
    final padding = compactWidth ? 16.0 : (dense ? 18.0 : SBSpacing.xxl);
    final sectionGap = dense ? SBSpacing.lg : SBSpacing.xxl;
    final titleGap = dense ? SBSpacing.md : SBSpacing.xl;
    final calloutGap = dense ? SBSpacing.md : SBSpacing.lg;
    final footerGap = dense ? SBSpacing.lg : SBSpacing.xl;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(dense ? 22 : 28),
        border: Border.all(color: const Color(0xFFE6EDF7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1B44).withValues(alpha: 0.11),
            blurRadius: dense ? 22 : 34,
            offset: Offset(0, dense ? 14 : 22),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[
            Align(alignment: Alignment.centerLeft, child: leading!),
            SizedBox(height: dense ? SBSpacing.sm : SBSpacing.lg),
          ],
          AuthEcosystemLogo(app: app, compact: true),
          SizedBox(height: titleGap),
          _AuthTitleBlock(
            app: app,
            icon: icon,
            title: title,
            subtitle: subtitle,
            dense: dense,
          ),
          if (showCallout) ...[
            SizedBox(height: calloutGap),
            EcosystemCallout(app: app),
          ],
          SizedBox(height: sectionGap),
          child,
          if (footer != null) ...[SizedBox(height: footerGap), footer!],
        ],
      ),
    );
  }
}

class _AuthTitleBlock extends StatelessWidget {
  const _AuthTitleBlock({
    required this.app,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dense,
  });

  final AuthAppConfig app;
  final String icon;
  final String title;
  final String subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final iconSize = dense ? 44.0 : 50.0;

    return Column(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: app.gradient,
            borderRadius: BorderRadius.circular(dense ? 14 : 16),
            boxShadow: [
              BoxShadow(
                color: app.primary.withValues(alpha: 0.28),
                blurRadius: dense ? 12 : 18,
                offset: Offset(0, dense ? 6 : 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: SBIcon(icon, size: dense ? 19 : 22, color: Colors.white),
        ),
        SizedBox(height: dense ? SBSpacing.sm : SBSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: SBTypography.scaled(
            dense ? 22 : 24,
            weight: FontWeight.bold,
          ).copyWith(color: const Color(0xFF0C1E45), height: 1.1),
        ),
        const SizedBox(height: SBSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: SBTypography.scaled(
            dense ? 15 : 16,
          ).copyWith(color: const Color(0xFF667493), height: 1.35),
        ),
      ],
    );
  }
}

class AuthEcosystemLogo extends StatelessWidget {
  const AuthEcosystemLogo({
    super.key,
    required this.app,
    this.compact = false,
    this.onDark = false,
  });

  final AuthAppConfig app;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 40.0 : 54.0;
    final textColor = onDark ? Colors.white : const Color(0xFF0C1E45);
    final mutedColor = onDark
        ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF667493);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandMark(
            size: markSize,
            label: 'M',
            gradient: const LinearGradient(
              colors: [Color(0xFF111B47), Color(0xFF056BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          Transform.translate(
            offset: Offset(compact ? -8 : -10, 0),
            child: _BrandMark(
              size: markSize,
              icon: app.icon,
              label: app.shortName,
              gradient: app.gradient,
            ),
          ),
          SizedBox(width: compact ? 0 : SBSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? app.name : 'MedAsi + ${app.name}',
                style:
                    (compact
                            ? SBTypography.labelMedium
                            : SBTypography.titleMedium)
                        .copyWith(color: textColor),
              ),
              Text(
                'MedAsi Ekosistemi',
                style: SBTypography.caption.copyWith(color: mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.size,
    required this.gradient,
    this.icon,
    required this.label,
  });

  final double size;
  final LinearGradient gradient;
  final String? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1B44).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: icon == null
          ? Text(
              label,
              style: SBTypography.scaled(
                size * 0.42,
                weight: FontWeight.w800,
              ).copyWith(color: Colors.white),
            )
          : SBIcon(icon!, size: size * 0.34, color: Colors.white),
    );
  }
}

class EcosystemCallout extends StatefulWidget {
  const EcosystemCallout({super.key, required this.app});

  final AuthAppConfig app;

  @override
  State<EcosystemCallout> createState() => _EcosystemCalloutState();
}

class _EcosystemCalloutState extends State<EcosystemCallout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
          lowerBound: 0.96,
          upperBound: 1,
        )
        ..forward()
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width <= 360;

    return ScaleTransition(
      scale: _controller,
      child: Container(
        padding: EdgeInsets.all(compact ? SBSpacing.sm : SBSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.app.soft, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          border: Border.all(color: widget.app.primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 30 : 34,
              height: compact ? 30 : 34,
              decoration: BoxDecoration(
                gradient: widget.app.gradient,
                borderRadius: BorderRadius.circular(compact ? 10 : 12),
              ),
              alignment: Alignment.center,
              child: SBIcon(
                'sparkles',
                size: compact ? 13 : 15,
                color: Colors.white,
              ),
            ),
            SizedBox(width: compact ? SBSpacing.sm : SBSpacing.md),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: SBTypography.scaled(compact ? 14 : 16).copyWith(
                    color: const Color(0xFF45526F),
                    height: compact ? 1.25 : 1.32,
                  ),
                  children: [
                    TextSpan(
                      text: 'MedAsi Ailesine Hoş Geldiniz\n',
                      style: SBTypography.scaled(
                        compact ? 14 : 16,
                        weight: FontWeight.w600,
                      ).copyWith(color: const Color(0xFF0C1E45)),
                    ),
                    const TextSpan(text: 'Tek hesabınızla '),
                    TextSpan(
                      text: 'Qlinik, PratiCase ve SourceBase',
                      style: SBTypography.scaled(
                        compact ? 14 : 16,
                        weight: FontWeight.w600,
                      ).copyWith(color: widget.app.primary),
                    ),
                    const TextSpan(
                      text:
                          ' uygulamalarının tamamına saniyeler içinde ulaşırsınız.',
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
}

class _HeroFeatureTile extends StatelessWidget {
  const _HeroFeatureTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final String icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SBIcon(icon, size: 20, color: Colors.white),
          const SizedBox(height: SBSpacing.sm),
          Text(
            title,
            style: SBTypography.labelMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: SBTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _EcosystemAppRail extends StatelessWidget {
  const _EcosystemAppRail({required this.active});

  final AuthAppConfig active;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SBSpacing.sm,
      runSpacing: SBSpacing.sm,
      children: [
        for (final app in _ecosystemApps)
          _EcosystemAppChip(app: app, isActive: app.name == active.name),
      ],
    );
  }
}

class _EcosystemAppChip extends StatelessWidget {
  const _EcosystemAppChip({required this.app, required this.isActive});

  final AuthAppConfig app;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SBSpacing.md,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: isActive ? 0.0 : 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: app.gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              app.shortName,
              style: SBTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: SBSpacing.sm),
          Text(
            app.name,
            style: SBTypography.labelSmall.copyWith(
              color: isActive ? const Color(0xFF0C1E45) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthSelectField extends StatelessWidget {
  const AuthSelectField({
    super.key,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String icon;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width <= 360;

    return Container(
      height: compact ? 52 : 56,
      padding: EdgeInsets.only(
        left: compact ? SBSpacing.md : SBSpacing.lg,
        right: SBSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: const Color(0xFFE4ECF8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: SBIcon(
              icon,
              size: compact ? 17 : 18,
              color: AuthAppConfig.sourcebase.primary,
            ),
          ),
          SizedBox(width: compact ? SBSpacing.sm : SBSpacing.md),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                hint: Text(
                  hint,
                  style: SBTypography.bodyMedium.copyWith(
                    color: const Color(0xFF8A96AD),
                  ),
                ),
                icon: SBIcon(
                  'chevron.down',
                  size: 17,
                  color: const Color(0xFF8A96AD),
                ),
                items: [
                  for (final item in items)
                    DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SBTypography.bodyMedium.copyWith(
                          color: const Color(0xFF0C1E45),
                        ),
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPasswordStrength extends StatelessWidget {
  const AuthPasswordStrength({super.key, required this.password});

  final String password;

  int get _score {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score;
  }

  String get _label => switch (_score) {
    0 || 1 => 'Zayıf',
    2 => 'Orta',
    3 => 'Güçlü',
    _ => 'Çok güçlü',
  };

  Color get _color => switch (_score) {
    0 || 1 => SBColors.red,
    2 => SBColors.warning,
    3 => SBColors.blue,
    _ => SBColors.green,
  };

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < _score ? _color : const Color(0xFFE3EBF7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: SBSpacing.xs),
        Text(
          'Şifre gücü: $_label',
          style: SBTypography.caption.copyWith(color: _color),
        ),
      ],
    );
  }
}

/// Tactile pill for single-select options (class year, goal).
class SBSelectPill extends StatelessWidget {
  const SBSelectPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.lg,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? SBColors.primaryGradient : null,
          color: isSelected ? null : SBColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? Colors.transparent : SBColors.line,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: SBColors.blue.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: SBTypography.labelMedium.copyWith(
            color: isSelected ? Colors.white : SBColors.navy,
          ),
        ),
      ),
    );
  }
}

/// Selectable discipline card (icon + label) for the profile-setup grid.
class SBDisciplineCard extends StatelessWidget {
  const SBDisciplineCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SBSpacing.lg),
        decoration: BoxDecoration(
          color: SBColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? SBColors.blue : SBColors.softLine,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: SBColors.navy.withValues(alpha: isSelected ? 0.10 : 0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: isSelected ? SBColors.primaryGradient : null,
                color: isSelected ? null : SBColors.softBlue,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: SBIcon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : SBColors.blue,
              ),
            ),
            const SizedBox(height: SBSpacing.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.labelMedium.copyWith(color: SBColors.navy),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labeled section wrapper used in the profile-setup form.
class SBFieldSection extends StatelessWidget {
  const SBFieldSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final String icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SBIcon(icon, size: 14, color: SBColors.blue),
            const SizedBox(width: SBSpacing.xs),
            Text(
              title,
              style: SBTypography.labelMedium.copyWith(color: SBColors.navy),
            ),
          ],
        ),
        const SizedBox(height: SBSpacing.sm),
        child,
      ],
    );
  }
}

/// Shared focused input container used across the auth flow
/// (port of `fieldContainer(icon:isFocused:)`).
class AuthFieldContainer extends StatefulWidget {
  const AuthFieldContainer({
    super.key,
    required this.icon,
    required this.hint,
    required this.controller,
    this.isSecure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmit,
    this.onChanged,
  });

  final String icon;
  final String hint;
  final TextEditingController controller;
  final bool isSecure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmit;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthFieldContainer> createState() => _AuthFieldContainerState();
}

class _AuthFieldContainerState extends State<AuthFieldContainer> {
  final FocusNode _focusNode = FocusNode();
  bool _isSecureVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final compact = MediaQuery.of(context).size.width <= 360;

    return Container(
      height: compact ? 52 : 56,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? SBSpacing.md : SBSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isFocused ? SBColors.fieldFocus : SBColors.field,
        borderRadius: BorderRadius.circular(compact ? 11 : 12),
        border: Border.all(
          color: isFocused
              ? SBColors.blue.withValues(alpha: 0.7)
              : SBColors.line,
          width: isFocused ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: SBIcon(
              widget.icon,
              size: compact ? 17 : 18,
              color: isFocused ? SBColors.blue : SBColors.muted,
            ),
          ),
          SizedBox(width: compact ? SBSpacing.sm : SBSpacing.md),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.isSecure && !_isSecureVisible,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: (_) => widget.onSubmit?.call(),
              onChanged: widget.onChanged,
              style: SBTypography.bodyMedium.copyWith(color: SBColors.navy),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: SBTypography.bodyMedium.copyWith(
                  color: SBColors.softText,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (widget.isSecure)
            GestureDetector(
              onTap: () => setState(() => _isSecureVisible = !_isSecureVisible),
              child: SizedBox(
                width: compact ? 40 : 44,
                height: 44,
                child: Center(
                  child: SBIcon(
                    _isSecureVisible ? 'eye.slash' : 'eye',
                    size: compact ? 17 : 18,
                    color: SBColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Success message block shared by auth screens.
class AuthSuccessMessage extends StatelessWidget {
  const AuthSuccessMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.greenBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SBIcon('checkmark.circle.fill', size: 17, color: SBColors.green),
          const SizedBox(width: SBSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: SBTypography.bodySmall.copyWith(color: SBColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded panel surface shared by the auth forms.
class AuthPanel extends StatelessWidget {
  const AuthPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SBSpacing.xl),
      decoration: BoxDecoration(
        color: SBColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SBColors.softLine),
        boxShadow: [
          BoxShadow(
            color: SBColors.navy.withValues(alpha: 0.075),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
