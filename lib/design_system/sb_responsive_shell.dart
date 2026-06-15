import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'sb_colors.dart';

/// Scroll behaviour that lets desktop/web users drag-scroll with a mouse or
/// trackpad (not just the wheel), and shows a slim scrollbar. Without this,
/// Flutter web disables pointer dragging on scroll views.
class SBScrollBehavior extends MaterialScrollBehavior {
  const SBScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Keep the app feeling native on phones; show a scrollbar on wide views.
    if (MediaQuery.of(context).size.width > _SBResponsiveBreakpoints.phone) {
      return Scrollbar(controller: details.controller, child: child);
    }
    return child;
  }
}

class _SBResponsiveBreakpoints {
  static const double phone = 600;
}

/// Wraps the whole app. On wide viewports (desktop browsers) it centres the
/// UI inside a clean phone-width frame instead of stretching the mobile
/// layout edge-to-edge; on phones it is a no-op. Drop into `MaterialApp.builder`.
class SBResponsiveShell extends StatelessWidget {
  const SBResponsiveShell({super.key, required this.child});

  final Widget child;

  static const double frameWidth = 480;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= _SBResponsiveBreakpoints.phone) return child;

    final gutter = SBColors.isDark
        ? const Color(0xFF02030A)
        : const Color(0xFFC9D4E8);

    return ColoredBox(
      color: gutter,
      child: Center(
        child: Container(
          width: frameWidth,
          height: media.size.height,
          decoration: BoxDecoration(
            color: SBColors.page,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: SBColors.isDark ? 0.6 : 0.22),
                blurRadius: 48,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(frameWidth, media.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
