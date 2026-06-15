import 'package:flutter/material.dart';

/// Type scale ported from SBTypography (SF text styles mapped to point sizes).
class SBTypography {
  SBTypography._();

  static const String _family = '.SF Pro Text';

  static TextStyle _style(double size, FontWeight weight,
          {double? height}) =>
      TextStyle(
        fontFamily: _family,
        fontFamilyFallback: const ['SF Pro Text', 'Roboto'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        decoration: TextDecoration.none,
      );

  // MARK: - Display (largeTitle heavy)
  static final TextStyle display1 = _style(34, FontWeight.w800);
  static final TextStyle display2 = _style(34, FontWeight.w800);

  // MARK: - Heading
  static final TextStyle heading1 = _style(34, FontWeight.bold);
  static final TextStyle heading2 = _style(24, FontWeight.bold);
  static final TextStyle heading3 = _style(20, FontWeight.bold);

  // MARK: - Title
  static final TextStyle titleLarge = _style(22, FontWeight.w600);
  static final TextStyle titleMedium = _style(17, FontWeight.w600);
  static final TextStyle titleSmall = _style(15, FontWeight.w600);

  // MARK: - Body
  static final TextStyle bodyLarge = _style(20, FontWeight.w400);
  static final TextStyle bodyMedium = _style(17, FontWeight.w400);
  static final TextStyle bodySmall = _style(16, FontWeight.w400);

  // MARK: - Label
  static final TextStyle labelLarge = _style(17, FontWeight.w600);
  static final TextStyle labelMedium = _style(16, FontWeight.w600);
  static final TextStyle labelSmall = _style(12, FontWeight.w600);

  // MARK: - Caption (caption2 medium)
  static final TextStyle caption = _style(11, FontWeight.w500);

  /// Equivalent of `.sbScaledFont(size:weight:)`.
  static TextStyle scaled(double size,
          {FontWeight weight = FontWeight.w400}) =>
      _style(size, weight);
}
